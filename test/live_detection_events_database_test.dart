import 'package:drift/native.dart';
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
      predictionMethod: 'timeline-v1',
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
      latitude: 41.0082,
      longitude: 28.9784,
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
    expect(
      events.single.temporalContext,
      'Gece etkinliği · yumuşak ağırlık %85',
    );

    await database.deleteLiveSession(sessionId);
    expect(await database.eventsForLiveSession(sessionId), isEmpty);
  });
}
