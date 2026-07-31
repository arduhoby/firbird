import 'dart:math' as math;

/// Canonical model-score aggregation for repeated detections of one species.
///
/// Overlapping analysis windows belong to the current acoustic event and only
/// improve that event's representative peak. A genuinely new acoustic event
/// contributes one new value to the arithmetic mean.
class DetectionScoreAggregate {
  const DetectionScoreAggregate._({
    required this.independentEventCount,
    required this.scoreTotal,
    required this.currentEventPeak,
    required this.bestEventScore,
  });

  factory DetectionScoreAggregate.first(double confidence) {
    final double score = _safeConfidence(confidence);
    return DetectionScoreAggregate._(
      independentEventCount: 1,
      scoreTotal: score,
      currentEventPeak: score,
      bestEventScore: score,
    );
  }

  factory DetectionScoreAggregate.fromIndependentScores(
    Iterable<double> confidences,
  ) {
    final List<double> scores = confidences
        .map(_safeConfidence)
        .toList(growable: false);
    if (scores.isEmpty) {
      throw ArgumentError.value(
        confidences,
        'confidences',
        'En az bir bağımsız tespit skoru gerekir.',
      );
    }
    return DetectionScoreAggregate._(
      independentEventCount: scores.length,
      scoreTotal: scores.fold<double>(0, (total, score) => total + score),
      currentEventPeak: scores.last,
      bestEventScore: scores.reduce(math.max),
    );
  }

  final int independentEventCount;
  final double scoreTotal;
  final double currentEventPeak;
  final double bestEventScore;

  double get averageConfidence => scoreTotal / independentEventCount;

  int get averagePercent => (averageConfidence * 100).round().clamp(0, 100);

  DetectionScoreAggregate addIndependentEvent(double confidence) {
    final double score = _safeConfidence(confidence);
    return DetectionScoreAggregate._(
      independentEventCount: independentEventCount + 1,
      scoreTotal: scoreTotal + score,
      currentEventPeak: score,
      bestEventScore: math.max(bestEventScore, score),
    );
  }

  DetectionScoreAggregate updateCurrentEventPeak(double confidence) {
    final double score = _safeConfidence(confidence);
    if (score <= currentEventPeak) return this;
    return DetectionScoreAggregate._(
      independentEventCount: independentEventCount,
      scoreTotal: scoreTotal - currentEventPeak + score,
      currentEventPeak: score,
      bestEventScore: math.max(bestEventScore, score),
    );
  }

  int repetitionBonus({
    required int pointsPerAdditionalEvent,
    int maximumPoints = 20,
  }) => repetitionBonusFor(
    independentEventCount: independentEventCount,
    pointsPerAdditionalEvent: pointsPerAdditionalEvent,
    maximumPoints: maximumPoints,
  );

  int combinedPercent({
    required int pointsPerAdditionalEvent,
    int maximumRepetitionPoints = 20,
  }) => combinedPercentFor(
    averageConfidence: averageConfidence,
    independentEventCount: independentEventCount,
    pointsPerAdditionalEvent: pointsPerAdditionalEvent,
    maximumRepetitionPoints: maximumRepetitionPoints,
  );

  static int combinedPercentFor({
    required double averageConfidence,
    required int independentEventCount,
    required int pointsPerAdditionalEvent,
    int maximumRepetitionPoints = 20,
  }) =>
      ((_safeConfidence(averageConfidence) * 100).round() +
              repetitionBonusFor(
                independentEventCount: independentEventCount,
                pointsPerAdditionalEvent: pointsPerAdditionalEvent,
                maximumPoints: maximumRepetitionPoints,
              ))
          .clamp(0, 100);

  static int repetitionBonusFor({
    required int independentEventCount,
    required int pointsPerAdditionalEvent,
    int maximumPoints = 20,
  }) {
    if (independentEventCount <= 1 || pointsPerAdditionalEvent <= 0) return 0;
    return math.min(
      (independentEventCount - 1) * pointsPerAdditionalEvent,
      maximumPoints,
    );
  }

  static double _safeConfidence(double value) {
    if (!value.isFinite) return 0;
    return value.clamp(0.0, 1.0);
  }
}

class DetectionScoreSample {
  const DetectionScoreSample({required this.key, required this.confidence});

  final String key;
  final double confidence;
}

Map<String, DetectionScoreAggregate> aggregateDetectionScores(
  Iterable<DetectionScoreSample> samples,
) {
  final Map<String, List<double>> scoresByKey = <String, List<double>>{};
  for (final DetectionScoreSample sample in samples) {
    final String key = sample.key.trim().toLowerCase();
    if (key.isEmpty) continue;
    scoresByKey.putIfAbsent(key, () => <double>[]).add(sample.confidence);
  }
  return <String, DetectionScoreAggregate>{
    for (final MapEntry<String, List<double>> entry in scoresByKey.entries)
      entry.key: DetectionScoreAggregate.fromIndependentScores(entry.value),
  };
}
