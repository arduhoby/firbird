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

  test('repetition alone cannot promote an unsupported regional candidate', () {
    final LiveDetectionDecision decision = evaluateLiveDetection(
      score: 0.51,
      hits: 3,
      isRare: false,
      regionalSupport: RegionalSupportLevel.none,
      configuredMinimum: 0,
    );

    expect(decision.accepted, isFalse);
    expect(decision.instantScore, 0.90);
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
