import 'package:firbird/inference/temporal_detection_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const double istanbulLatitude = 41.0082;
  const double istanbulLongitude = 28.9784;

  test('classifies İstanbul summer noon and midnight from solar position', () {
    expect(
      solarPhaseAt(
        moment: DateTime.utc(2026, 7, 26, 12),
        latitude: istanbulLatitude,
        longitude: istanbulLongitude,
      ),
      SolarPhase.daylight,
    );
    expect(
      solarPhaseAt(
        moment: DateTime.utc(2026, 7, 26, 19, 55),
        latitude: istanbulLatitude,
        longitude: istanbulLongitude,
      ),
      SolarPhase.night,
    );
  });

  test('keeps night singers above ordinary diurnal priors at night', () {
    final TemporalDetectionContext nightingale = temporalContextForSpecies(
      scientificName: 'Luscinia megarhynchos',
      moment: DateTime.utc(2026, 7, 26),
      latitude: istanbulLatitude,
      longitude: istanbulLongitude,
    );
    final TemporalDetectionContext woodpecker = temporalContextForSpecies(
      scientificName: 'Dendrocopos major',
      moment: DateTime.utc(2026, 7, 26),
      latitude: istanbulLatitude,
      longitude: istanbulLongitude,
    );

    expect(
      nightingale.confidenceMultiplier,
      greaterThan(woodpecker.confidenceMultiplier),
    );
    expect(woodpecker.confidenceMultiplier, greaterThan(0));
  });

  test('does not change confidence when GPS context is unavailable', () {
    final TemporalDetectionContext context = temporalContextForSpecies(
      scientificName: 'Dendrocopos major',
      moment: DateTime.utc(2026, 7, 26),
    );
    expect(context.phase, SolarPhase.unavailable);
    expect(context.confidenceMultiplier, 1);
  });

  test(
    'recognises Saka as a diurnal species without filtering it at night',
    () {
      final TemporalDetectionContext saka = temporalContextForSpecies(
        scientificName: 'Carduelis carduelis',
        moment: DateTime.utc(2026, 7, 26),
        latitude: istanbulLatitude,
        longitude: istanbulLongitude,
      );

      expect(saka.profile, BirdActivityProfile.diurnal);
      expect(saka.confidenceMultiplier, 0.50);
    },
  );
}
