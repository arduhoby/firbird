import 'dart:io';

import 'package:firbird/detection/algorithm_settings.dart';
import 'package:firbird/detection/detection_evidence_service.dart';
import 'package:firbird/detection/detection_feedback_repository.dart';
import 'package:firbird/detection/detection_record.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:firbird/observation_context/ebird_context_package.dart';
import 'package:firbird/observation_context/ebird_observation_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory directory;
  late EbirdObservationCache cache;
  late DetectionFeedbackRepository feedback;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    directory = await Directory.systemTemp.createTemp('firbird_evidence_test_');
    cache = EbirdObservationCache(directoryLoader: () async => directory);
    feedback = DetectionFeedbackRepository(
      directoryLoader: () async => directory,
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('nearby refresh persists and replaces the active snapshot', () async {
    await cache.replace(
      EbirdObservationSnapshot(
        latitude: 41,
        longitude: 29,
        radiusKm: 20,
        fetchedAt: DateTime.utc(2026, 7, 1),
        observations: <EbirdRecentObservation>[_observation('first', 41, 29)],
      ),
    );
    await cache.replace(
      EbirdObservationSnapshot(
        latitude: 41.1,
        longitude: 29.1,
        radiusKm: 50,
        fetchedAt: DateTime.utc(2026, 7, 2),
        observations: <EbirdRecentObservation>[
          _observation('second', 41.1, 29.1),
        ],
      ),
    );

    final EbirdObservationSnapshot? restored = await cache.load();
    expect(restored, isNotNull);
    expect(restored!.radiusKm, 50);
    expect(restored.observations, hasLength(1));
    expect(restored.observations.single.locationId, 'second');
  });

  test(
    'feedback survives reload and a repeated decision replaces itself',
    () async {
      final DetectionRecord record = _record();
      await feedback.record(record, DetectionVerdict.correct);
      await feedback.record(record, DetectionVerdict.incorrect);

      final DetectionFeedbackRepository reopened = DetectionFeedbackRepository(
        directoryLoader: () async => directory,
      );
      final DetectionFeedbackSummary summary = await reopened.summaryFor(
        record.scientificName,
      );
      expect(summary.confirmedCount, 0);
      expect(summary.rejectedCount, 1);
    },
  );

  test('owl evidence exposes every point contribution', () async {
    final DateTime moment = DateTime.utc(2026, 7, 15, 9);
    await cache.replace(
      EbirdObservationSnapshot(
        latitude: 41,
        longitude: 29,
        radiusKm: 20,
        fetchedAt: moment,
        observations: <EbirdRecentObservation>[
          _observation('one', 41.01, 29.01, observedAt: moment),
          _observation('two', 41.02, 29.02, observedAt: moment),
        ],
      ),
    );
    final DetectionEvidenceService service = DetectionEvidenceService(
      settingsRepository: AlgorithmSettingsRepository(),
      feedbackRepository: feedback,
      observationCache: cache,
    );

    final DetectionRecord enriched = await service.enrich(
      _record(detectedAt: moment, repeatedHits: 3),
    );
    final Map<String, int> points = <String, int>{
      for (final DetectionEvidenceFactor factor in enriched.evidence!.factors)
        factor.id: factor.points,
    };

    expect(points['time'], -30);
    expect(points['nearby_time'], 30);
    expect(points['season'], 10);
    expect(points['repeated_detection'], 8);
    expect(points['device_history'], 0);
    expect(enriched.evidence!.modelScore, 50);
    expect(enriched.evidence!.finalScore, 68);
  });
}

DetectionRecord _record({DateTime? detectedAt, int repeatedHits = 1}) =>
    DetectionRecord(
      id: 'owl-detection',
      speciesId: 'athene-noctua',
      turkishName: 'Kukumav',
      scientificName: 'Athene noctua',
      modelConfidence: 0.50,
      detectedAt: detectedAt ?? DateTime.utc(2026, 7, 15, 9),
      source: DetectionSource.live,
      statusCategory: SpeciesStatusCategory.localOrMigratory,
      latitude: 41,
      longitude: 29,
      repeatedHits: repeatedHits,
    );

EbirdRecentObservation _observation(
  String locationId,
  double latitude,
  double longitude, {
  DateTime? observedAt,
}) => EbirdRecentObservation(
  speciesCode: 'litowl1',
  scientificName: 'Athene noctua',
  commonName: 'Little Owl',
  turkishName: 'Kukumav',
  locationId: locationId,
  locationName: 'Test noktası',
  observedAt: observedAt ?? DateTime.utc(2026, 7, 15, 9),
  latitude: latitude,
  longitude: longitude,
  count: 1,
  reviewed: true,
  isLive: true,
);
