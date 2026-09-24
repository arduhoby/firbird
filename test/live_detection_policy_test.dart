import 'package:firbird/inference/live_detection_policy.dart';
import 'package:firbird/observation_context/regional_observation_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not show a five-percent unsupported regional candidate', () {
    final LiveDetectionDecision decision = evaluateLiveDetection(
      score: 0.05,
      hits: 3,
      isRare: false,
      regionalSupport: RegionalSupportLevel.none,
      configuredMinimum: 0,
    );

    expect(decision.accepted, isFalse);
    expect(decision.minimumScore, 0.25);
  });

  test(
    'accepts a highly confident Saka even without regional observations',
    () {
      final LiveDetectionDecision decision = evaluateLiveDetection(
        score: 0.998,
        hits: 1,
        isRare: false,
        regionalSupport: RegionalSupportLevel.none,
        configuredMinimum: 0,
      );

      expect(decision.accepted, isTrue);
    },
  );

  test(
    'repeated evidence can display a candidate without regional records',
    () {
      final LiveDetectionDecision decision = evaluateLiveDetection(
        score: 0.51,
        hits: 3,
        isRare: false,
        regionalSupport: RegionalSupportLevel.none,
        configuredMinimum: 0,
      );

      expect(decision.accepted, isTrue);
      expect(decision.instantScore, 0.90);
    },
  );

  test('unsupported candidates still require enough score and windows', () {
    for (final bool isRare in <bool>[false, true]) {
      final double floor = isRare ? 0.35 : 0.25;
      LiveDetectionDecision decide(
        double score,
        int hits, {
        double minimum = 0,
      }) => evaluateLiveDetection(
        score: score,
        hits: hits,
        isRare: isRare,
        regionalSupport: RegionalSupportLevel.none,
        configuredMinimum: minimum,
      );

      expect(decide(floor, 3).accepted, isTrue);
      expect(decide(floor - 0.01, 3).accepted, isFalse);
      expect(decide(0.51, 2).accepted, isFalse);
      expect(decide(0.51, 3, minimum: 0.60).accepted, isFalse);
    }
  });

  test('accepts a repeated candidate with strong regional support', () {
    final LiveDetectionDecision decision = evaluateLiveDetection(
      score: 0.10,
      hits: 2,
      isRare: false,
      regionalSupport: RegionalSupportLevel.strong,
      configuredMinimum: 0,
    );

    expect(decision.accepted, isTrue);
  });

  test('does not hide a highly confident call because of time weighting', () {
    final LiveDetectionDecision decision = evaluateLiveDetection(
      score: 0.96,
      hits: 1,
      isRare: false,
      regionalSupport: RegionalSupportLevel.none,
      configuredMinimum: 0,
      temporalMultiplier: 0.50,
    );

    expect(decision.temporalScore, 0.48);
    expect(decision.accepted, isTrue);
  });
}
