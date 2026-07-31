import 'package:firbird/inference/bird_inference_engine.dart';

enum DetectionSource { live, audioFile, photo, replay }

enum DetectionVerdict { correct, incorrect }

enum EvidenceDirection { supports, weakens, neutral, unavailable }

class DetectionEvidenceFactor {
  const DetectionEvidenceFactor({
    required this.id,
    required this.title,
    required this.detail,
    required this.direction,
    required this.points,
    required this.sourceLabel,
  });

  final String id;
  final String title;
  final String detail;
  final EvidenceDirection direction;
  final int points;
  final String sourceLabel;
}

class DetectionEvidenceBundle {
  const DetectionEvidenceBundle({
    required this.modelScore,
    required this.contextAdjustment,
    required this.finalScore,
    required this.algorithmVersion,
    required this.factors,
  });

  final int modelScore;
  final int contextAdjustment;
  final int finalScore;
  final String algorithmVersion;
  final List<DetectionEvidenceFactor> factors;

  String get confidenceLabel => switch (finalScore) {
    >= 80 => 'Güçlü kanıt',
    >= 60 => 'Destekleniyor',
    >= 40 => 'Dikkatle değerlendir',
    _ => 'Zayıf / çelişkili kanıt',
  };
}

class DetectionRecord {
  const DetectionRecord({
    required this.id,
    required this.speciesId,
    required this.turkishName,
    required this.scientificName,
    required this.modelConfidence,
    required this.detectedAt,
    required this.source,
    required this.statusCategory,
    this.modelVersion,
    this.thumbnailUrl,
    this.audioUri,
    this.audioStartMs,
    this.audioEndMs,
    this.latitude,
    this.longitude,
    this.repeatedHits = 1,
    this.repetitionSupportPerHit = 0,
    this.evidence,
    this.verdict,
  });

  final String id;
  final String speciesId;
  final String turkishName;
  final String scientificName;
  final double modelConfidence;
  final DateTime detectedAt;
  final DetectionSource source;
  final SpeciesStatusCategory statusCategory;
  final String? modelVersion;
  final String? thumbnailUrl;
  final String? audioUri;
  final int? audioStartMs;
  final int? audioEndMs;
  final double? latitude;
  final double? longitude;
  final int repeatedHits;
  final int repetitionSupportPerHit;
  final DetectionEvidenceBundle? evidence;
  final DetectionVerdict? verdict;

  DetectionRecord copyWith({
    DetectionEvidenceBundle? evidence,
    DetectionVerdict? verdict,
  }) => DetectionRecord(
    id: id,
    speciesId: speciesId,
    turkishName: turkishName,
    scientificName: scientificName,
    modelConfidence: modelConfidence,
    detectedAt: detectedAt,
    source: source,
    statusCategory: statusCategory,
    modelVersion: modelVersion,
    thumbnailUrl: thumbnailUrl,
    audioUri: audioUri,
    audioStartMs: audioStartMs,
    audioEndMs: audioEndMs,
    latitude: latitude,
    longitude: longitude,
    repeatedHits: repeatedHits,
    repetitionSupportPerHit: repetitionSupportPerHit,
    evidence: evidence ?? this.evidence,
    verdict: verdict ?? this.verdict,
  );
}
