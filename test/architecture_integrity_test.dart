import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('media playback has one channel and one state machine', () async {
    final List<File> dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    final String allSource = dartFiles
        .map((File file) => file.readAsStringSync())
        .join('\n');

    expect(
      RegExp(r"org\.firbird3\.app/media_player").allMatches(allSource),
      hasLength(1),
      reason: 'Native media channel must only exist in the shared gateway.',
    );
    expect(allSource, isNot(contains('class _LivePlayer')));
    expect(allSource, isNot(contains('class _ReplayPlayer')));
    expect(allSource, isNot(contains('class _HistoryPlayer')));
    expect(allSource, isNot(contains('_LiveThumbnail')));
    expect(allSource, isNot(contains('_PlayerThumbnail')));
    expect(allSource, isNot(contains('_CandidateThumbnail')));
    expect(allSource, isNot(contains('class _BirdPhoto')));
  });

  test('all replay entry points use PlaybackSession and MediaPlayerScreen', () {
    final String routes = File('lib/app/firbird_app.dart').readAsStringSync();
    final String live = File(
      'lib/app/live_audio_recording_screen.dart',
    ).readAsStringSync();
    final String history = File(
      'lib/app/history_and_settings_screens.dart',
    ).readAsStringSync();

    expect(
      routes,
      contains('MediaPlayerScreen(session: state.extra as PlaybackSession?)'),
    );
    expect(live, contains('return MediaPlayerScreen('));
    expect(live, contains('session: completedSession'));
    expect(history, contains('extra: PlaybackSession('));
    expect(history, isNot(contains("c['speciesId']")));
  });

  test('bird lists use the shared BirdPhoto component', () {
    final String sharedCard = File(
      'lib/app/bird_detection_card.dart',
    ).readAsStringSync();
    final String nearby = File(
      'lib/app/nearby_birds_screen.dart',
    ).readAsStringSync();

    expect(sharedCard, contains('BirdPhoto('));
    expect(nearby, contains('BirdPhoto('));
  });

  test('hotspot map has one implementation for card and full screen', () {
    final String source = File(
      'lib/app/nearby_birds_screen.dart',
    ).readAsStringSync();

    expect(RegExp(r'class _HotspotMapCard\b').allMatches(source), hasLength(1));
    expect(
      RegExp(r'Future<void> showNearbyHotspotMapSheet\b').allMatches(source),
      hasLength(1),
    );
    expect(source, contains(": 'Haritayı tam ekran aç'"));
    expect(source, contains("? 'Haritayı küçült'"));
    expect(source, contains('Icons.fullscreen_exit'));
    expect(source, contains("tooltip: 'GPS konumuna dön'"));
    expect(source, contains("tooltip: 'Gözlem listesini kapat'"));
    expect(RegExp(r'class _NorthCompass\b').allMatches(source), hasLength(1));
    expect(
      RegExp(r'class _MapOverlaySurface\b').allMatches(source),
      hasLength(1),
    );
    expect(source, contains('_mapController.rotate(0)'));
    expect(source, isNot(contains('Duplicate block retained')));
  });

  test('live screen prepares first and starts only from microphone action', () {
    final String source = File(
      'lib/app/live_audio_recording_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_prepareSession();'));
    expect(source, contains('Future<void> _startListening()'));
    expect(source, contains('onPressed: _startListening'));
    expect(source, isNot(contains('_initAndStart')));
    expect(
      source.indexOf('Future<void> _startListening()'),
      lessThan(source.indexOf('await _audioRecorder.hasPermission()')),
    );
  });

  test('all audio entry points use the shared detection card', () {
    for (final String path in <String>[
      'lib/app/identification_screens.dart',
      'lib/app/live_audio_recording_screen.dart',
      'lib/app/media_player_screen.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('BirdDetectionCard('),
        reason: '$path must use the canonical audio detection card.',
      );
    }
    final String source = File(
      'lib/app/live_audio_recording_screen.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('_showRegionalEvidence')));
    expect(source, isNot(contains('class _EvidenceMetric')));
    expect(
      RegExp(r'class BirdDetectionCard\b')
          .allMatches(
            Directory('lib')
                .listSync(recursive: true)
                .whereType<File>()
                .where((File file) => file.path.endsWith('.dart'))
                .map((File file) => file.readAsStringSync())
                .join('\n'),
          )
          .length,
      1,
    );
  });

  test('species detail reuses the canonical nearby eBird data and map', () {
    final String detail = File(
      'lib/app/identification_screens.dart',
    ).readAsStringSync();

    expect(detail, contains('_NearbySpeciesObservationSection'));
    expect(detail, contains('EbirdObservationRepository().load()'));
    expect(detail, contains('showNearbyHotspotMapSheet('));
  });

  test('nearby eBird download status comes from the persisted snapshot', () {
    final String nearby = File(
      'lib/app/nearby_birds_screen.dart',
    ).readAsStringSync();

    expect(nearby, contains('_savedObservationSnapshot = data.snapshot'));
    expect(nearby, contains('_savedObservationSnapshot = snapshot'));
    expect(nearby, contains(r'km verisi $date tarihinde indirildi'));
    expect(nearby, contains("? 'yenile' : 'indir'"));
  });
}
