import 'dart:convert';
import 'dart:io';

import 'package:firbird/detection/detection_record.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class DetectionFeedbackSummary {
  const DetectionFeedbackSummary({
    required this.confirmedCount,
    required this.rejectedCount,
  });

  final int confirmedCount;
  final int rejectedCount;
}

class DetectionFeedbackRepository {
  DetectionFeedbackRepository({Future<Directory> Function()? directoryLoader})
    : _directoryLoader = directoryLoader ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryLoader;

  Future<File> _file() async => File(
    path.join((await _directoryLoader()).path, 'detection_feedback_v1.json'),
  );

  Future<void> record(
    DetectionRecord detection,
    DetectionVerdict verdict,
  ) async {
    final File file = await _file();
    final List<Map<String, dynamic>> entries = await _readEntries(file);
    entries.removeWhere(
      (Map<String, dynamic> item) => item['detectionId'] == detection.id,
    );
    entries.add(<String, dynamic>{
      'detectionId': detection.id,
      'speciesId': detection.speciesId,
      'scientificName': detection.scientificName,
      'detectedAt': detection.detectedAt.toUtc().toIso8601String(),
      'recordedAt': DateTime.now().toUtc().toIso8601String(),
      'source': detection.source.name,
      'verdict': verdict.name,
    });
    await file.writeAsString(jsonEncode(entries), flush: true);
  }

  Future<DetectionFeedbackSummary> summaryFor(String scientificName) async {
    final List<Map<String, dynamic>> entries = await _readEntries(
      await _file(),
    );
    final String key = scientificName.trim().toLowerCase();
    int confirmed = 0;
    int rejected = 0;
    for (final Map<String, dynamic> entry in entries) {
      if ((entry['scientificName'] as String? ?? '').toLowerCase() != key) {
        continue;
      }
      if (entry['verdict'] == DetectionVerdict.correct.name) confirmed++;
      if (entry['verdict'] == DetectionVerdict.incorrect.name) rejected++;
    }
    return DetectionFeedbackSummary(
      confirmedCount: confirmed,
      rejectedCount: rejected,
    );
  }

  Future<List<Map<String, dynamic>>> _readEntries(File file) async {
    if (!await file.exists()) return <Map<String, dynamic>>[];
    try {
      final dynamic decoded = jsonDecode(await file.readAsString());
      return (decoded as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList(growable: true);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
