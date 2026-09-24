import 'package:firbird/app/bird_detection_card.dart';
import 'package:firbird/app/media_player_screen.dart';
import 'package:firbird/audio/audio_evidence_assessment.dart';
import 'package:firbird/detection/detection_record.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'daylight owl stays non-green until human approval in live and replay',
    (WidgetTester tester) async {
      for (final DetectionSource source in <DetectionSource>[
        DetectionSource.live,
        DetectionSource.replay,
      ]) {
        for (final (AudioReviewVerdict?, DetectionVerdict?) approval
            in <(AudioReviewVerdict?, DetectionVerdict?)>[
              (null, null),
              (AudioReviewVerdict.audible, null),
              (null, DetectionVerdict.correct),
            ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: BirdDetectionCard(
                  record: _record(
                    source: source,
                    speciesId: 'aegolius-funereus',
                    turkishName: 'Paçalı Baykuş',
                    scientificName: 'Aegolius funereus',
                    audioReviewVerdict: approval.$1,
                    verdict: approval.$2,
                    latitude: 41.0082,
                    longitude: 28.9784,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final AnimatedContainer card = tester.widget<AnimatedContainer>(
            find
                .descendant(
                  of: find.byType(BirdDetectionCard),
                  matching: find.byType(AnimatedContainer),
                )
                .first,
          );
          final BoxDecoration decoration = card.decoration! as BoxDecoration;
          final Color border = decoration.border!.top.color;
        if (approval.$1 == AudioReviewVerdict.audible ||
            approval.$2 == DetectionVerdict.correct) {
          expect(border, Colors.green);
          expect(find.text('Saat dışı · onay bekliyor'), findsNothing);
        } else {
          expect(border, isNot(Colors.green));
          expect(find.text('Saat dışı · onay bekliyor'), findsOneWidget);
            expect(
              decoration.gradient!.colors.first,
              isNot(
                Theme.of(
                  tester.element(find.byType(BirdDetectionCard)),
                ).colorScheme.primaryContainer,
              ),
            );
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'unsupported detections ask for review in live and replay cards',
    (WidgetTester tester) async {
      for (final source in <DetectionSource>[
        DetectionSource.live,
        DetectionSource.replay,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BirdDetectionCard(
                record: _record(regionalSupport: 'none', source: source),
                onAudioReview: (_) async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('yakın kayıt yok — dinleyerek doğrula'),
          findsOneWidget,
        );
        expect(find.text('Bu kuş'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('deck changes birds vertically and approves with a right swipe', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    AudioReviewVerdict? reviewed;
    int focused = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BirdDetectionDeck(
            records: <DetectionRecord>[
              _record(),
              _record(
                speciesId: 'corvus-corax',
                turkishName: 'Kuzgun',
                scientificName: 'Corvus corax',
              ),
              _record(
                speciesId: 'carduelis-carduelis',
                turkishName: 'Saka',
                scientificName: 'Carduelis carduelis',
              ),
              _record(
                speciesId: 'otus-scops',
                turkishName: 'İshakkuşu',
                scientificName: 'Otus scops',
              ),
              _record(
                speciesId: 'nycticorax-nycticorax',
                turkishName: 'Gece Balıkçılı',
                scientificName: 'Nycticorax nycticorax',
              ),
            ],
            focusedIndex: focused,
            height: 500,
            onFocusChanged: (int index) => focused = index,
            onAudioReview: (int _, AudioReviewVerdict verdict) async {
              reviewed = verdict;
            },
          ),
        ),
      ),
    );

    List<BirdDetectionCard> cards() => tester
        .widgetList<BirdDetectionCard>(find.byType(BirdDetectionCard))
        .toList(growable: false);
    expect(
      cards().where((BirdDetectionCard card) => card.isExpanded),
      hasLength(1),
    );
    expect(
      cards().where((BirdDetectionCard card) => !card.isExpanded),
      hasLength(4),
    );
    final Rect focusBounds = tester.getRect(
      find.byKey(const ValueKey<String>('detection-expanded-0')),
    );
    final List<Rect> neighbors = [
      for (int index = 1; index < 5; index++)
        tester.getRect(find.byKey(ValueKey<String>('detection-row-$index'))),
    ];
    expect(
      neighbors.where((rect) => rect.bottom <= focusBounds.top),
      hasLength(2),
    );
    expect(
      neighbors.where((rect) => rect.top >= focusBounds.bottom),
      hasLength(2),
    );
    expect(
      neighbors.every((rect) => rect.top >= 0 && rect.bottom <= 500),
      isTrue,
    );
    await tester.drag(
      find.byKey(const ValueKey<String>('detection-expanded-0')),
      const Offset(180, 0),
    );
    await tester.pumpAndSettle();

    expect(reviewed, AudioReviewVerdict.audible);
    expect(focused, 1);
    expect(
      cards().where((BirdDetectionCard card) => card.isExpanded),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);

    await tester.fling(
      find.byKey(const ValueKey<String>('detection-expanded-1')),
      const Offset(0, 220),
      800,
    );
    await tester.pump(const Duration(milliseconds: 100));

    final Transform moving = tester.widget<Transform>(
      find.byKey(const ValueKey<String>('deck-transform-0')),
    );
    expect(moving.transform.entry(3, 2), isNot(0));
    await tester.pumpAndSettle();

    expect(focused, 0);
    expect(
      cards().where((BirdDetectionCard card) => card.isExpanded),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);

    // Reuse the same deck in the tighter space left by live recording controls.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BirdDetectionDeck(
            height: 400,
            records: List.generate(
              5,
              (index) => _record(speciesId: 'bird-$index'),
            ),
            onSeek: (_) {},
            onAudioReview: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'only the expanded detection exposes playback and review actions',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BirdDetectionCard(
              record: _record(audioReviewVerdict: AudioReviewVerdict.inaudible),
              isExpanded: false,
              onToggleExpanded: () {},
              onSeek: () {},
              onAudioReview: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Serçe'), findsOneWidget);
      expect(find.text('Bu kuş değil'), findsOneWidget);
      expect(find.byType(ColorFiltered), findsOneWidget);
      expect(find.byTooltip('Tespit anını dinle'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BirdDetectionCard(
              record: _record(),
              isExpanded: true,
              onToggleExpanded: () {},
              onSeek: () {},
              onAudioReview: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Tespit anını dinle'), findsOneWidget);
      expect(find.text('Bu kuş'), findsOneWidget);
      expect(find.text('Emin değilim'), findsOneWidget);
      expect(find.text('Bu kuş değil'), findsOneWidget);
    },
  );

  test(
    'player keeps one row per species and selects its strongest evidence',
    () {
      final List<PlaybackDetection> result =
          collapsePlaybackDetectionsBySpecies(<PlaybackDetection>[
            _playback(
              startMs: 0,
              confidence: 0.8,
              evidenceLevel: AudioEvidenceLevel.machineOnly,
            ),
            _playback(
              startMs: 3000,
              confidence: 0.6,
              evidenceLevel: AudioEvidenceLevel.strong,
            ),
            _playback(
              startMs: 6000,
              confidence: 0.7,
              evidenceLevel: AudioEvidenceLevel.review,
              scientificName: 'Corvus corax',
            ),
          ]);

      expect(result, hasLength(2));
      expect(result.first.startMs, 3000);
    },
  );
}

DetectionRecord _record({
  String regionalSupport = 'moderate',
  DetectionSource source = DetectionSource.replay,
  AudioReviewVerdict? audioReviewVerdict,
  DetectionVerdict? verdict,
  String speciesId = 'passer-domesticus',
  String turkishName = 'Serçe',
  String scientificName = 'Passer domesticus',
  double? latitude,
  double? longitude,
}) => DetectionRecord(
  id: speciesId,
  speciesId: speciesId,
  turkishName: turkishName,
  scientificName: scientificName,
  modelConfidence: 0.8,
  detectedAt: DateTime(2026, 9, 20, 12),
  source: source,
  statusCategory: SpeciesStatusCategory.localOrMigratory,
  latitude: latitude,
  longitude: longitude,
  audioReviewVerdict: audioReviewVerdict,
  verdict: verdict,
  regionalSupport: regionalSupport,
  temporalContext: 'Bu mevsimde yakın çevrede kayda alınmış.',
);

PlaybackDetection _playback({
  required int startMs,
  required double confidence,
  required AudioEvidenceLevel evidenceLevel,
  String scientificName = 'Passer domesticus',
}) => PlaybackDetection(
  speciesId: scientificName,
  turkishName: scientificName,
  scientificName: scientificName,
  startMs: startMs,
  endMs: startMs + 3000,
  modelConfidence: confidence,
  audioEvidence: AudioEvidenceAssessment(
    level: evidenceLevel,
    foregroundDbfs: -20,
    noiseFloorDbfs: -40,
    contrastDb: 20,
    peakDbfs: -10,
    clippedFraction: 0,
  ),
);
