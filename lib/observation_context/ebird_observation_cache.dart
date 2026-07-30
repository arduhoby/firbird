import 'dart:convert';
import 'dart:io';

import 'package:firbird/observation_context/ebird_context_package.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class EbirdObservationSnapshot {
  const EbirdObservationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.fetchedAt,
    required this.observations,
  });

  final double latitude;
  final double longitude;
  final int radiusKm;
  final DateTime fetchedAt;
  final List<EbirdRecentObservation> observations;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': 1,
    'source': 'eBird API v2',
    'query': <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'radiusKm': radiusKm,
      'daysBack': 30,
    },
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'observations': observations
        .map((EbirdRecentObservation item) => item.toJson())
        .toList(growable: false),
  };

  factory EbirdObservationSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported eBird cache schema.');
    }
    final Map<String, dynamic> query = json['query'] as Map<String, dynamic>;
    final List<dynamic> observations = json['observations'] as List<dynamic>;
    return EbirdObservationSnapshot(
      latitude: (query['latitude'] as num).toDouble(),
      longitude: (query['longitude'] as num).toDouble(),
      radiusKm: (query['radiusKm'] as num).toInt(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      observations: observations
          .whereType<Map<String, dynamic>>()
          .map(EbirdRecentObservation.fromJson)
          .toList(growable: false),
    );
  }
}

class EbirdObservationCache {
  EbirdObservationCache({Future<Directory> Function()? directoryLoader})
    : _directoryLoader = directoryLoader ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryLoader;

  Future<File> _file() async => File(
    path.join((await _directoryLoader()).path, 'ebird_nearby_snapshot_v1.json'),
  );

  Future<EbirdObservationSnapshot?> load() async {
    final File file = await _file();
    if (!await file.exists()) return null;
    try {
      return EbirdObservationSnapshot.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// One active nearby snapshot is kept. A successful refresh replaces the
  /// previous snapshot; API credentials are never written to this file.
  Future<void> replace(EbirdObservationSnapshot snapshot) async {
    final File file = await _file();
    final File staging = File('${file.path}.new');
    await staging.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
    if (await file.exists()) await file.delete();
    await staging.rename(file.path);
  }
}
