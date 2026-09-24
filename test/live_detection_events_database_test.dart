import 'package:drift/native.dart';
import 'package:firbird/audio/audio_evidence_assessment.dart';
import 'package:firbird/data/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores and deletes an exact live detection timeline', () async {
    final AppDatabase database = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );
    addTearDown(database.close);

    const String sessionId = 'live_123';
    await database.addIdentification(
      speciesId: 'carduelis-carduelis',
      turkishName: 'Saka',
      scientificName: 'Carduelis carduelis',
      confidence: '%99',
      modelVersion: 'BirdNET',
      packageId: sessionId,
      speciesStatus: 'localOrMigratory',
      modelConfidence: 0.73,
      repeatedHits: 4,
      predictionMethod: 'aggregate-v1',
    );
    await database.addLiveDetectionEvent(
      sessionId: sessionId,
      speciesId: 'carduelis-carduelis',
      turkishName: 'Saka',
      scientificName: 'Carduelis carduelis',
      confidence: 0.99,
      startMs: 1250,
      endMs: 4250,
      detectedAt: DateTime.utc(2026, 7, 30, 8, 15),
      regionalSupport: 'strong',
      speciesStatus: 'localOrMigratory',
      latitude: 41.0082,
      longitude: 28.9784,
      audioEvidence: const AudioEvidenceAssessment(
        level: AudioEvidenceLevel.strong,
        foregroundDbfs: -24,
        noiseFloorDbfs: -48,
        contrastDb: 24,
        peakDbfs: -8,
        clippedFraction: 0,
      ),
      audioReviewVerdict: AudioReviewVerdict.inaudible,
      temporalContext: 'Gece etkinliği · yumuşak ağırlık %85',
    );

    final List<LiveDetectionEvent> events = await database.eventsForLiveSession(
      sessionId,
    );
    expect(events, hasLength(1));
    expect(events.single.startMs, 1250);
    expect(events.single.endMs, 4250);
    expect(events.single.scientificName, 'Carduelis carduelis');
    expect(events.single.detectedAt?.toUtc(), DateTime.utc(2026, 7, 30, 8, 15));
    expect(events.single.latitude, 41.0082);
    expect(events.single.longitude, 28.9784);
    expect(events.single.speciesStatus, 'localOrMigratory');
    expect(events.single.audioEvidenceLevel, AudioEvidenceLevel.strong.name);
    expect(events.single.audioReviewVerdict, AudioReviewVerdict.inaudible.name);
    expect(events.single.audioContrastDb, 24);
    expect(
      events.single.temporalContext,
      'Gece etkinliği · yumuşak ağırlık %85',
    );
    await database.updateLiveSpeciesAudioReview(
      sessionId: sessionId,
      speciesId: 'carduelis-carduelis',
      verdict: AudioReviewVerdict.audible,
    );
    final LiveDetectionEvent reviewed = (await database.eventsForLiveSession(
      sessionId,
    )).single;
    expect(reviewed.audioReviewVerdict, AudioReviewVerdict.audible.name);
    final List<IdentificationRecord> summaries = await database
        .watchHistory()
        .first;
    expect(summaries.single.modelConfidence, 0.73);
    expect(summaries.single.repeatedHits, 4);

    await database.deleteLiveSession(sessionId);
    expect(await database.eventsForLiveSession(sessionId), isEmpty);
  });
}
