import 'package:firbird/app/media_player_screen.dart';
import 'package:firbird/detection/detection_score_aggregate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overlapping windows update one event without inflating hit count', () {
    final DetectionScoreAggregate aggregate = DetectionScoreAggregate.first(
      0.42,
    ).updateCurrentEventPeak(0.68).updateCurrentEventPeak(0.50);

    expect(aggregate.independentEventCount, 1);
    expect(aggregate.averageConfidence, closeTo(0.68, 0.000001));
    expect(aggregate.bestEventScore, closeTo(0.68, 0.000001));
  });

  test('independent events use their arithmetic mean and capped support', () {
    final DetectionScoreAggregate aggregate = DetectionScoreAggregate.first(
      0.42,
    ).addIndependentEvent(0.70).addIndependentEvent(0.66);

    expect(aggregate.independentEventCount, 3);
    expect(aggregate.averageConfidence, closeTo(0.593333, 0.000001));
    expect(aggregate.averagePercent, 59);
    expect(aggregate.repetitionBonus(pointsPerAdditionalEvent: 4), 8);
    expect(aggregate.combinedPercent(pointsPerAdditionalEvent: 4), 67);
    expect(
      DetectionScoreAggregate.repetitionBonusFor(
        independentEventCount: 20,
        pointsPerAdditionalEvent: 4,
      ),
      20,
    );
  });

  test('history grouping and replay preserve the canonical aggregate', () {
    final Map<String, DetectionScoreAggregate> grouped =
        aggregateDetectionScores(const <DetectionScoreSample>[
          DetectionScoreSample(key: 'Passer domesticus', confidence: 0.42),
          DetectionScoreSample(key: 'passer DOMESTICUS', confidence: 0.70),
          DetectionScoreSample(key: 'Passer domesticus', confidence: 0.66),
        ]);
    final DetectionScoreAggregate aggregate = grouped['passer domesticus']!;
    final record = PlaybackDetection(
      speciesId: 'passer-domesticus',
      turkishName: 'Serçe',
      scientificName: 'Passer domesticus',
      startMs: 1000,
      endMs: 4000,
      modelConfidence: aggregate.averageConfidence,
      repeatedHits: aggregate.independentEventCount,
      repetitionSupportPerHit: 4,
    ).toDetectionRecord('session.wav');

    expect(record.modelConfidence, closeTo(0.593333, 0.000001));
    expect(record.repeatedHits, 3);
    expect(record.repetitionSupportPerHit, 4);
    expect(aggregate.combinedPercent(pointsPerAdditionalEvent: 4), 67);
  });
}
