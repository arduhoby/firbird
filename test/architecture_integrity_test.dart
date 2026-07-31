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

  test('v0.8.5 does not advertise unavailable live age or call analysis', () {
    final String card = File(
      'lib/app/bird_detection_card.dart',
    ).readAsStringSync();
    final String evidence = File(
      'lib/app/detection_evidence_sheet.dart',
    ).readAsStringSync();
    final String settings = File(
      'lib/app/history_and_settings_screens.dart',
    ).readAsStringSync();

    expect(card, isNot(contains('Yaş grubu')));
    expect(card, isNot(contains('Çağrı şekli')));
    expect(card, contains("label: 'Nadir Tür'"));
    expect(evidence, isNot(contains("label: 'Çağrı şekli'")));
    expect(settings, isNot(contains('Kuş yaş grubu tespit edilsin mi?')));
    expect(settings, isNot(contains('Kuş ötüşü ayrımı tespit edilsin mi?')));
  });

  test('photo sex and age analysis remains available', () {
    final String identification = File(
      'lib/app/identification_screens.dart',
    ).readAsStringSync();
    final String database = File(
      'lib/data/app_database.dart',
    ).readAsStringSync();

    expect(identification, contains('class _SexAgeSection'));
    expect(identification, contains('sexAge: _currentResult.sexAge!'));
    expect(database, contains('TextColumn get sexCategory'));
    expect(database, contains('TextColumn get ageCategory'));
    expect(database, contains('updateCorrection('));
  });

  test('offline guide has one shared app bar entry point', () {
    final String helpButton = File(
      'lib/app/app_bar_help_button.dart',
    ).readAsStringSync();
    final String drawer = File('lib/app/app_drawer.dart').readAsStringSync();
    final String home = File('lib/app/firbird_app.dart').readAsStringSync();
    final String live = File(
      'lib/app/live_audio_recording_screen.dart',
    ).readAsStringSync();

    expect(helpButton, contains("context.push('/help')"));
    expect(drawer, contains("title: 'Kullanım Kılavuzu'"));
    expect(drawer, contains("_navigate(context, '/help')"));
    expect(home, contains('const AppBarHelpButton()'));
    expect(live, contains('const AppBarHelpButton()'));
  });

  test('repeated detection confidence has one canonical aggregate', () {
    final String aggregate = File(
      'lib/detection/detection_score_aggregate.dart',
    ).readAsStringSync();
    final String live = File(
      'lib/app/live_audio_recording_screen.dart',
    ).readAsStringSync();
    final String history = File(
      'lib/app/history_and_settings_screens.dart',
    ).readAsStringSync();
    final String evidence = File(
      'lib/detection/detection_evidence_service.dart',
    ).readAsStringSync();

    expect(aggregate, contains('class DetectionScoreAggregate'));
    expect(aggregate, contains('aggregateDetectionScores('));
    expect(live, contains('DetectionScoreAggregate.first(pred.score)'));
    expect(live, contains('.addIndependentEvent(pred.score)'));
    expect(history, contains('aggregateDetectionScores('));
    expect(evidence, contains('repetitionBonusFor('));
    expect(
      RegExp(r'class DetectionScoreAggregate\b')
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
