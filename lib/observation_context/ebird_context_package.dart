import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

/// Offline eBird context data prepared outside the mobile application.
///
/// The API token is deliberately not part of this model or package format.
class EbirdContextPackage {
  const EbirdContextPackage({
    required this.manifest,
    required this.hotspots,
    required this.recentObservations,
  });

  static Future<EbirdContextPackage> load(Directory directory) async {
    final Map<String, dynamic> manifestJson = await _readObject(
      File(path.join(directory.path, 'manifest.json')),
    );
    final EbirdContextManifest manifest = EbirdContextManifest.fromJson(
      manifestJson,
    );
    final List<dynamic> hotspotJson = await _readList(
      File(path.join(directory.path, manifest.hotspotsFile)),
    );
    final List<dynamic> observationJson = await _readList(
      File(path.join(directory.path, manifest.recentObservationsFile)),
    );
    return EbirdContextPackage.fromJsonDocuments(
      manifestJson: manifestJson,
      hotspotJson: hotspotJson,
      observationJson: observationJson,
    );
  }

  factory EbirdContextPackage.fromJsonStrings({
    required String manifest,
    required String hotspots,
    required String recentObservations,
  }) {
    return EbirdContextPackage.fromJsonDocuments(
      manifestJson: _asObject(jsonDecode(manifest)),
      hotspotJson: _asList(jsonDecode(hotspots), 'hotspots'),
      observationJson: _asList(
        jsonDecode(recentObservations),
        'recent observations',
      ),
    );
  }

  factory EbirdContextPackage.fromJsonDocuments({
    required Map<String, dynamic> manifestJson,
    required List<dynamic> hotspotJson,
    required List<dynamic> observationJson,
  }) {
    final EbirdContextManifest manifest = EbirdContextManifest.fromJson(
      manifestJson,
    );
    final List<EbirdHotspot> hotspots = hotspotJson
        .map((dynamic value) => EbirdHotspot.fromJson(_asObject(value)))
        .toList(growable: false);
    final List<EbirdRecentObservation> observations = observationJson
        .map(
          (dynamic value) => EbirdRecentObservation.fromJson(_asObject(value)),
        )
        .toList(growable: false);

    if (hotspots.length != manifest.hotspotCount) {
      throw const FormatException('Hotspot count does not match manifest.');
    }
    if (observations.length != manifest.recentObservationCount) {
      throw const FormatException(
        'Recent observation count does not match manifest.',
      );
    }
    return EbirdContextPackage(
      manifest: manifest,
      hotspots: hotspots,
      recentObservations: observations,
    );
  }

  final EbirdContextManifest manifest;
  final List<EbirdHotspot> hotspots;
  final List<EbirdRecentObservation> recentObservations;
}

class EbirdContextManifest {
  const EbirdContextManifest({
    required this.schemaVersion,
    required this.packageId,
    required this.version,
    required this.regionCode,
    required this.generatedAt,
    required this.lookbackDays,
    required this.hotspotCount,
    required this.recentObservationCount,
    required this.hotspotsFile,
    required this.recentObservationsFile,
    required this.sources,
  });

  factory EbirdContextManifest.fromJson(Map<String, dynamic> json) {
    final int schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion != 1) {
      throw FormatException(
        'Unsupported eBird context schema: $schemaVersion.',
      );
    }
    final String regionCode = _requiredString(json, 'regionCode');
    if (regionCode != 'TR') {
      throw FormatException('Expected TR region, got $regionCode.');
    }
    final Map<String, dynamic> files = _asObject(json['files']);
    final Map<String, dynamic> counts = _asObject(json['counts']);
    return EbirdContextManifest(
      schemaVersion: schemaVersion,
      packageId: _requiredString(json, 'packageId'),
      version: _requiredString(json, 'version'),
      regionCode: regionCode,
      generatedAt: DateTime.parse(_requiredString(json, 'generatedAt')).toUtc(),
      lookbackDays: _requiredInt(json, 'lookbackDays'),
      hotspotCount: _requiredInt(counts, 'hotspots'),
      recentObservationCount: _requiredInt(counts, 'recentObservations'),
      hotspotsFile: _requiredString(_asObject(files['hotspots']), 'name'),
      recentObservationsFile: _requiredString(
        _asObject(files['recentObservations']),
        'name',
      ),
      sources: (json['sources'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic value) => EbirdContextSource.fromJson(_asObject(value)))
          .toList(growable: false),
    );
  }

  final int schemaVersion;
  final String packageId;
  final String version;
  final String regionCode;
  final DateTime generatedAt;
  final int lookbackDays;
  final int hotspotCount;
  final int recentObservationCount;
  final String hotspotsFile;
  final String recentObservationsFile;
  final List<EbirdContextSource> sources;
}

class EbirdContextSource {
  const EbirdContextSource({
    required this.name,
    required this.endpoint,
    required this.fetchedAt,
    required this.recordCount,
  });

  factory EbirdContextSource.fromJson(Map<String, dynamic> json) {
    final dynamic endpointValue = json['endpoint'] ?? json['endpointTemplate'];
    if (endpointValue is! String || endpointValue.trim().isEmpty) {
      throw const FormatException(
        'A source must include endpoint or endpointTemplate.',
      );
    }
    return EbirdContextSource(
      name: _requiredString(json, 'name'),
      endpoint: endpointValue,
      fetchedAt: DateTime.parse(_requiredString(json, 'fetchedAt')).toUtc(),
      recordCount: _requiredInt(json, 'recordCount'),
    );
  }

  final String name;
  final String endpoint;
  final DateTime fetchedAt;
  final int recordCount;
}

class EbirdHotspot {
  const EbirdHotspot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.subnational1Code,
    this.latestObservationAt,
    this.allTimeSpeciesCount,
  });

  factory EbirdHotspot.fromJson(Map<String, dynamic> json) {
    final double latitude = _requiredDouble(json, 'latitude');
    final double longitude = _requiredDouble(json, 'longitude');
    _validateCoordinates(latitude, longitude);
    final String? latest = json['latestObservationAt'] as String?;
    return EbirdHotspot(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      latitude: latitude,
      longitude: longitude,
      subnational1Code: json['subnational1Code'] as String?,
      latestObservationAt: latest == null ? null : DateTime.parse(latest),
      allTimeSpeciesCount: (json['allTimeSpeciesCount'] as num?)?.toInt(),
    );
  }

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? subnational1Code;
  final DateTime? latestObservationAt;
  final int? allTimeSpeciesCount;
}

class EbirdRecentObservation {
  const EbirdRecentObservation({
    required this.speciesCode,
    required this.scientificName,
    required this.commonName,
    required this.locationId,
    required this.locationName,
    required this.observedAt,
    required this.latitude,
    required this.longitude,
    this.count,
    required this.reviewed,
  });

  factory EbirdRecentObservation.fromJson(Map<String, dynamic> json) {
    final double latitude = _requiredDouble(json, 'latitude');
    final double longitude = _requiredDouble(json, 'longitude');
    _validateCoordinates(latitude, longitude);
    return EbirdRecentObservation(
      speciesCode: _requiredString(json, 'speciesCode'),
      scientificName: _requiredString(json, 'scientificName'),
      commonName: _requiredString(json, 'commonName'),
      locationId: _requiredString(json, 'locationId'),
      locationName: _requiredString(json, 'locationName'),
      observedAt: DateTime.parse(_requiredString(json, 'observedAt')),
      latitude: latitude,
      longitude: longitude,
      count: (json['count'] as num?)?.toInt(),
      reviewed: json['reviewed'] as bool? ?? false,
    );
  }

  final String speciesCode;
  final String scientificName;
  final String commonName;
  final String locationId;
  final String locationName;
  final DateTime observedAt;
  final double latitude;
  final double longitude;
  final int? count;
  final bool reviewed;
}

Future<Map<String, dynamic>> _readObject(File file) async =>
    _asObject(jsonDecode(await file.readAsString()));

Future<List<dynamic>> _readList(File file) async {
  final dynamic value = jsonDecode(await file.readAsString());
  return _asList(value, file.path);
}

List<dynamic> _asList(dynamic value, String name) {
  if (value is! List<dynamic>) {
    throw FormatException('$name must contain a JSON array.');
  }
  return value;
}

Map<String, dynamic> _asObject(dynamic value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object.');
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final dynamic value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final dynamic value = json[key];
  if (value is! num) throw FormatException('$key must be a number.');
  return value.toInt();
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final dynamic value = json[key];
  if (value is! num) throw FormatException('$key must be a number.');
  return value.toDouble();
}

void _validateCoordinates(double latitude, double longitude) {
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    throw const FormatException('Invalid geographic coordinates.');
  }
}
