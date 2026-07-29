import 'dart:math' as math;

import 'package:firbird/observation_context/regional_observation_context.dart';

class LiveDetectionDecision {
  const LiveDetectionDecision({
    required this.accepted,
    required this.isProvisional,
    required this.minimumScore,
    required this.instantScore,
    required this.requiredHits,
    required this.temporalScore,
  });

  final bool accepted;
  final bool isProvisional;
  final double minimumScore;
  final double instantScore;
  final int requiredHits;
  final double temporalScore;
}

/// A conservative display gate. BirdNET's raw probability remains visible in
/// logs, while the user-facing list requires temporal and regional support.
LiveDetectionDecision evaluateLiveDetection({
  required double score,
  required int hits,
  required bool isRare,
  required RegionalSupportLevel? regionalSupport,
  required double configuredMinimum,
  double temporalMultiplier = 1,
}) {
  final double temporalScore = score * temporalMultiplier.clamp(0.0, 1.0);
  final double baseMinimum = switch (regionalSupport) {
    RegionalSupportLevel.strong ||
    RegionalSupportLevel.moderate => isRare ? 0.15 : 0.08,
    RegionalSupportLevel.weak => isRare ? 0.20 : 0.12,
    RegionalSupportLevel.none => isRare ? 0.35 : 0.25,
    null => isRare ? 0.20 : 0.12,
  };
  final double instantScore = switch (regionalSupport) {
    RegionalSupportLevel.strong => isRare ? 0.82 : 0.75,
    RegionalSupportLevel.moderate => isRare ? 0.85 : 0.78,
    RegionalSupportLevel.weak => isRare ? 0.88 : 0.82,
    RegionalSupportLevel.none => isRare ? 0.92 : 0.90,
    null => isRare ? 0.88 : 0.82,
  };
  final int requiredHits = regionalSupport == RegionalSupportLevel.none ? 3 : 2;
  final double minimumScore = math.max(configuredMinimum, baseMinimum);
  // Repeated local evidence may be quieter than a single clean recording.
  // Keep a small floor for it, while leaving unsupported species behind the
  // strong-score gate above.
  final double repeatedEvidenceMinimum = switch (regionalSupport) {
    RegionalSupportLevel.strong || RegionalSupportLevel.moderate => 0.05,
    RegionalSupportLevel.weak || null => 0.08,
    RegionalSupportLevel.none => baseMinimum,
  };
  final double acceptedEvidenceMinimum = math.max(
    configuredMinimum,
    repeatedEvidenceMinimum,
  );
  // A strong raw model score is always allowed through. Time is a soft prior,
  // never a hard filter that can erase an unusual but well-supported call.
  final bool hasEnoughEvidence =
      score >= instantScore ||
      (regionalSupport != RegionalSupportLevel.none && hits >= requiredHits);
  // A familiar, non-rare local species at the expected time is useful to
  // show immediately, but is explicitly marked until a second window agrees.
  final bool isProvisional =
      !isRare &&
      (regionalSupport == RegionalSupportLevel.strong ||
          regionalSupport == RegionalSupportLevel.moderate) &&
      temporalMultiplier >= 0.95 &&
      hits < requiredHits &&
      temporalScore >= math.max(configuredMinimum, 0.05);
  return LiveDetectionDecision(
    accepted:
        score >= instantScore ||
        (temporalScore >= acceptedEvidenceMinimum && hasEnoughEvidence) ||
        isProvisional,
    isProvisional: isProvisional,
    minimumScore: minimumScore,
    instantScore: instantScore,
    requiredHits: requiredHits,
    temporalScore: temporalScore,
  );
}
