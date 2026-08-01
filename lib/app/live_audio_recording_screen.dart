import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:firbird/audio/pcm16_wav.dart';
import 'package:firbird/audio/noise_filter.dart';
import 'package:firbird/audio/noise_filter_provider.dart';
import 'package:firbird/audio/noise_filter_settings.dart';
import 'package:firbird/app/app_drawer.dart';
import 'package:firbird/app/app_bar_help_button.dart';
import 'package:firbird/app/audio_spectrogram.dart';
import 'package:firbird/app/bird_detection_card.dart';
import 'package:firbird/app/detection_evidence_sheet.dart';
import 'package:firbird/app/media_player_screen.dart';
import 'package:firbird/app/nearby_birds_screen.dart';
import 'package:firbird/data/app_database.dart';
import 'package:firbird/detection/algorithm_settings.dart';
import 'package:firbird/detection/detection_record.dart';
import 'package:firbird/detection/detection_score_aggregate.dart';
import 'package:firbird/detection/rare_detection_alert_controller.dart';
import 'package:firbird/inference/audio_inference_engine.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:firbird/inference/live_detection_policy.dart';
import 'package:firbird/inference/temporal_detection_context.dart';
import 'package:firbird/observation_context/ebird_context_package.dart';
import 'package:firbird/observation_context/regional_observation_context.dart';

class LiveDetectionEntry {
  LiveDetectionEntry({
    required this.prediction,
    required this.scoreAggregate,
    required this.firstDetectedAt,
    required this.lastDetectedAt,
    this.regionalContext,
    this.temporalContext,
    this.isProvisional = false,
  });

  final SpeciesPrediction prediction;
  DetectionScoreAggregate scoreAggregate;
  final DateTime firstDetectedAt;
  DateTime lastDetectedAt;
  int get detectionCount => scoreAggregate.independentEventCount;
  RegionalSpeciesContext? regionalContext;
  TemporalDetectionContext? temporalContext;
  bool isProvisional;
}

class _DetectionMoment {
  _DetectionMoment({
    required this.prediction,
    required this.startedAt,
    required this.endedAt,
  });

  SpeciesPrediction prediction;
  final DateTime startedAt;
  DateTime endedAt;
}

enum _LiveSessionPhase { preparing, ready, starting, listening, ended, failed }

class LiveAudioRecordingScreen extends ConsumerStatefulWidget {
  const LiveAudioRecordingScreen({super.key});

  @override
  ConsumerState<LiveAudioRecordingScreen> createState() =>
      _LiveAudioRecordingScreenState();
}

class _LiveAudioRecordingScreenState
    extends ConsumerState<LiveAudioRecordingScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  AudioInferenceEngine? _audioEngine;

  bool _isRecording = false;
  bool _isStoppingSession = false;
  bool _isEngineReady = false;
  bool _isSessionEnded = false;
  _LiveSessionPhase _sessionPhase = _LiveSessionPhase.preparing;
  String _statusText = 'Model yükleniyor...';
  int _secondsRecorded = 0;
  bool _tenMinuteCheckShown = false;
  Timer? _clockTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  Completer<void>? _audioStreamDone;
  IOSink? _sessionPcmSink;
  String? _sessionPcmPath;
  Future<void>? _analysisTask;
  bool _analysisPending = false;
  int _pendingWindowEndByte = 0;
  int _capturedPcmBytes = 0;
  int _nextAnalysisAtByte = _analysisWindowBytes;
  int _ringWriteOffset = 0;
  int _ringLength = 0;
  int _analysisWindowCount = 0;
  static const int _sampleRate = 48000;
  static const int _bytesPerSample = 2;
  static const int _bytesPerSecond = _sampleRate * _bytesPerSample;
  static const int _analysisWindowBytes = _bytesPerSecond * 3;
  static const int _analysisHopBytes = _bytesPerSecond;
  final Uint8List _pcmRingBuffer = Uint8List(_analysisWindowBytes);
  String? _savedFilePath;
  DateTime? _sessionStartTime;
  Position? _sessionPosition;
  RegionalObservationContextEngine? _observationContextEngine;
  int _observationRadiusKm = 20;
  String? _observationContextMessage;

  // A single PCM microphone stream feeds both the saved recording and the
  // rolling BirdNET analysis window. The recorder is never stopped between
  // model windows.
  static const MethodChannel _screenChannel = MethodChannel(
    'org.firbird3.app/screen',
  );
  static const MethodChannel _downloadsChannel = MethodChannel(
    'org.firbird3.app/downloads',
  );
  double _currentDb = -60.0;
  final List<List<double>> _spectrogramColumns = <List<double>>[];
  final List<LiveDetectionEntry> _detectedSpeciesList = <LiveDetectionEntry>[];
  final List<_DetectionMoment> _detectionMoments = <_DetectionMoment>[];
  final Set<String> _rejectedSpecies = <String>{};
  final Set<String> _confirmedSpecies = <String>{};
  final RareDetectionAlertController _rareAlerts =
      RareDetectionAlertController();
  final List<Set<String>> _recentCandidateWindows = <Set<String>>[];
  String? _highlightedSpeciesKey;
  Timer? _highlightTimer;

  /// Loaded from settings — minimum confidence to show in live table (0.0 = all)
  double _liveMinScore = 0.0;
  AlgorithmSettings _algorithmSettings = AlgorithmSettings.defaults;

  /// Real-time noise filter applied to every PCM analysis window before BirdNET.
  final NoiseFilter _noiseFilter = NoiseFilter();

  @override
  void initState() {
    super.initState();
    _rareAlerts.addListener(_onRareAlertChanged);
    _prepareSession();
  }

  void _onRareAlertChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // The native flag is process/window scoped, so always release it when the
    // live screen goes away, including an interrupted session.
    _setKeepScreenOn(false);
    _clockTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _audioStreamSubscription?.cancel();
    _sessionPcmSink?.close();
    _audioRecorder.dispose();
    _highlightTimer?.cancel();
    _rareAlerts
      ..removeListener(_onRareAlertChanged)
      ..dispose();
    _noiseFilter.reset();
    super.dispose();
  }

  Future<void> _setKeepScreenOn(bool enabled) async {
    try {
      await _screenChannel.invokeMethod<void>('setKeepScreenOn', <String, bool>{
        'enabled': enabled,
      });
    } catch (error) {
      debugPrint('Ekran a\u00e7\u0131k tutma durumu ayarlanamad\u0131: $error');
    }
  }

  Future<bool> _publishToDownloads({
    required String sourcePath,
    required String displayName,
  }) async {
    try {
      await _downloadsChannel.invokeMethod<String>(
        'publishWav',
        <String, String>{'sourcePath': sourcePath, 'displayName': displayName},
      );
      return true;
    } catch (error) {
      debugPrint('Kayıt Download/FirBird içine kopyalanamadı: $error');
      return false;
    }
  }

  void _markDetectionFeedback(
    SpeciesPrediction prediction,
    DateTime detectedAt,
  ) {
    final String key = prediction.scientificName.toLowerCase();
    _detectionMoments.add(
      _DetectionMoment(
        prediction: prediction,
        startedAt: detectedAt,
        endedAt: detectedAt.add(const Duration(seconds: 3)),
      ),
    );
    _highlightTimer?.cancel();
    _highlightedSpeciesKey = key;
    _highlightTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _highlightedSpeciesKey == key) {
        setState(() => _highlightedSpeciesKey = null);
      }
    });
  }

  void _extendLatestDetectionMoment(
    SpeciesPrediction prediction,
    DateTime detectedAt,
  ) {
    final String key = prediction.scientificName.toLowerCase();
    for (final _DetectionMoment moment in _detectionMoments.reversed) {
      if (moment.prediction.scientificName.toLowerCase() == key) {
        if (prediction.score > moment.prediction.score) {
          moment.prediction = prediction;
        }
        moment.endedAt = detectedAt.add(const Duration(seconds: 3));
        return;
      }
    }
  }

  Future<void> _saveRecordingWithName() async {
    final String? sourcePath = _savedFilePath;
    if (sourcePath == null || !await File(sourcePath).exists() || !mounted) {
      return;
    }
    final TextEditingController controller = TextEditingController();
    final String? requestedName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydı adlandır'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Kayıt adı',
            hintText: 'Örn. Vize sabah kuş sesleri',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
    final String safeName = (requestedName ?? '').trim().replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
    if (safeName.isEmpty) return;
    final String displayName = safeName.toLowerCase().endsWith('.wav')
        ? safeName
        : '$safeName.wav';
    final bool published = await _publishToDownloads(
      sourcePath: sourcePath,
      displayName: displayName,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            published
                ? 'Download/FirBird içine kaydedildi: $displayName'
                : 'Kayıt dışa aktarılamadı; uygulama içindeki kopya korundu.',
          ),
        ),
      );
    }
  }

  Future<void> _prepareSession() async {
    try {
      // Load occurrences for status categorization
      await SpeciesStatusHelper.loadOccurrences();

      // Load live detection min score from settings
      _liveMinScore = await ref
          .read(appDatabaseProvider)
          .liveDetectionMinScore();
      _observationRadiusKm = await ref
          .read(appDatabaseProvider)
          .observationContextRadiusKm();
      _algorithmSettings = await AlgorithmSettingsRepository().load();

      // Initialize and warm up the audio engine first
      final Directory targetDir = await getApplicationDocumentsDirectory();
      await _loadObservationContext(targetDir);
      final String modelPath = path.join(
        targetDir.path,
        'firbird_test_model',
        'birdnet.onnx',
      );
      final String labelsPath = path.join(
        targetDir.path,
        'firbird_test_model',
        'birdnet_labels.txt',
      );
      _audioEngine = AudioInferenceEngine(
        modelPath: modelPath,
        labelsPath: labelsPath,
      );

      if (mounted) {
        setState(() => _statusText = 'Model hazırlanıyor (62 MB)...');
      }
      try {
        await _audioEngine!.warmUp();
      } catch (e) {
        debugPrint('AudioEngine warmUp failed: $e');
        if (mounted) {
          setState(() {
            _sessionPhase = _LiveSessionPhase.failed;
            _statusText = 'Model yüklenemedi: $e';
          });
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _isEngineReady = true;
        _sessionPhase = _LiveSessionPhase.ready;
        _statusText = 'Mikrofona dokunarak dinlemeyi başlatın.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sessionPhase = _LiveSessionPhase.failed;
        _statusText = 'Canlı dinleme hazırlanamadı: $e';
      });
    }
  }

  Future<void> _startListening() async {
    if (_sessionPhase != _LiveSessionPhase.ready || !_isEngineReady) return;
    setState(() {
      _sessionPhase = _LiveSessionPhase.starting;
      _statusText = 'Mikrofon hazırlanıyor...';
    });
    try {
      final bool hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        setState(() {
          _sessionPhase = _LiveSessionPhase.ready;
          _statusText = 'Mikrofon izni verilmedi. Tekrar deneyin.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mikrofon izni verilmedi.')),
        );
        return;
      }

      // Konum ve mikrofon izinleri yalnızca kullanıcı dinlemeyi başlattığında
      // istenir; ekranı açmak tek başına kayıt başlatmaz.
      try {
        if (await Geolocator.isLocationServiceEnabled()) {
          LocationPermission locPerm = await Geolocator.checkPermission();
          if (locPerm == LocationPermission.denied) {
            locPerm = await Geolocator.requestPermission();
          }
          if (locPerm == LocationPermission.whileInUse ||
              locPerm == LocationPermission.always) {
            _sessionPosition = await Geolocator.getCurrentPosition();
          }
        }
      } catch (e) {
        debugPrint('Konum izni alınırken hata: $e');
      }

      // Amplitude listener for equalizer
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen((amp) {
            if (mounted) {
              final double db = amp.current;
              setState(() {
                _currentDb = db;
              });
            }
          });

      setState(() {
        _isRecording = true;
        _sessionPhase = _LiveSessionPhase.listening;
        _sessionStartTime = DateTime.now();
        _statusText = 'Ortam dinleniyor...';
      });
      await _setKeepScreenOn(true);

      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        bool showTenMinuteCheck = false;
        setState(() {
          _secondsRecorded = _capturedPcmBytes ~/ _bytesPerSecond;
          if (!_tenMinuteCheckShown && _secondsRecorded >= 10 * 60) {
            _tenMinuteCheckShown = true;
            showTenMinuteCheck = true;
          }
        });
        if (showTenMinuteCheck) unawaited(_showTenMinuteCheck());
      });

      await _startContinuousRecording();
    } catch (e) {
      _clockTimer?.cancel();
      _isRecording = false;
      await _setKeepScreenOn(false);
      if (mounted) {
        setState(() {
          _sessionPhase = _LiveSessionPhase.ready;
          _statusText = 'Dinleme başlatılamadı. Tekrar deneyin.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Canlı kayıt başlatılamadı: $e')),
        );
      }
    }
  }

  Future<void> _showTenMinuteCheck() async {
    if (!mounted || !_isRecording) return;

    bool timedOut = false;
    final Future<bool?> dialog = showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('10 dakika oldu'),
        content: const Text(
          'Canlı dinleme ve kayıt devam etsin mi? Bir dakika içinde seçim yapılmazsa kayıt devam eder.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Kaydı sonlandır'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Devam et'),
          ),
        ],
      ),
    );
    final bool? selection = await Future.any(<Future<bool?>>[
      dialog,
      Future<bool?>.delayed(const Duration(minutes: 1), () {
        timedOut = true;
        return null;
      }),
    ]);

    if (!mounted || !_isRecording) return;
    if (timedOut) {
      // The default is to continue. Close the prompt after one minute.
      Navigator.of(context, rootNavigator: true).maybePop();
      return;
    }
    if (selection == false) await _stopSession();
  }

  Future<void> _startContinuousRecording() async {
    final Directory tempDirectory = await getTemporaryDirectory();
    _sessionPcmPath = path.join(
      tempDirectory.path,
      'firbird_live_${DateTime.now().millisecondsSinceEpoch}.pcm',
    );
    _sessionPcmSink = File(_sessionPcmPath!).openWrite();
    final Stream<Uint8List> stream = await _audioRecorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
    );
    _audioStreamDone = Completer<void>();
    _audioStreamSubscription = stream.listen(
      _handlePcmChunk,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Continuous audio stream error: $error');
        if (!_audioStreamDone!.isCompleted) {
          _audioStreamDone!.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!_audioStreamDone!.isCompleted) _audioStreamDone!.complete();
      },
      cancelOnError: false,
    );
    if (mounted) setState(() => _statusText = 'Dinleniyor...');
  }

  void _handlePcmChunk(Uint8List chunk) {
    if (!_isRecording || chunk.length < _bytesPerSample) return;
    final int byteLength = chunk.length - (chunk.length % _bytesPerSample);
    final Uint8List pcm = byteLength == chunk.length
        ? chunk
        : Uint8List.sublistView(chunk, 0, byteLength);
    _sessionPcmSink?.add(pcm);
    _capturedPcmBytes += pcm.length;

    int sourceOffset = 0;
    while (sourceOffset < pcm.length) {
      final int copyLength = math.min(
        pcm.length - sourceOffset,
        _analysisWindowBytes - _ringWriteOffset,
      );
      _pcmRingBuffer.setRange(
        _ringWriteOffset,
        _ringWriteOffset + copyLength,
        pcm,
        sourceOffset,
      );
      _ringWriteOffset = (_ringWriteOffset + copyLength) % _analysisWindowBytes;
      _ringLength = math.min(_analysisWindowBytes, _ringLength + copyLength);
      sourceOffset += copyLength;
    }

    if (_ringLength == _analysisWindowBytes &&
        _capturedPcmBytes >= _nextAnalysisAtByte) {
      while (_nextAnalysisAtByte <= _capturedPcmBytes) {
        _nextAnalysisAtByte += _analysisHopBytes;
      }
      _pendingWindowEndByte = _capturedPcmBytes;
      _analysisPending = true;
      _analysisTask ??= _drainAnalysisWindows();
    }
  }

  Future<void> _drainAnalysisWindows() async {
    try {
      while (_analysisPending && _ringLength == _analysisWindowBytes) {
        _analysisPending = false;
        final int windowEndByte = _pendingWindowEndByte;
        final Uint8List pcmWindow = _snapshotPcmRing();
        final int windowStartByte = math.max(
          0,
          windowEndByte - _analysisWindowBytes,
        );
        await _analyzePcmWindow(
          pcmWindow,
          windowStart: Duration(
            microseconds:
                windowStartByte *
                Duration.microsecondsPerSecond ~/
                _bytesPerSecond,
          ),
        );
      }
    } finally {
      _analysisTask = null;
      if (_analysisPending && _isRecording) {
        _analysisTask = _drainAnalysisWindows();
      }
    }
  }

  Uint8List _snapshotPcmRing() {
    final Uint8List snapshot = Uint8List(_analysisWindowBytes);
    final int tailLength = _analysisWindowBytes - _ringWriteOffset;
    snapshot.setRange(0, tailLength, _pcmRingBuffer, _ringWriteOffset);
    if (_ringWriteOffset > 0) {
      snapshot.setRange(tailLength, _analysisWindowBytes, _pcmRingBuffer, 0);
    }
    return snapshot;
  }

  Future<void> _analyzePcmWindow(
    Uint8List pcmWindow, {
    required Duration windowStart,
  }) async {
    if (_audioEngine == null || !_isEngineReady) return;
    if (pcmWindow.length < _analysisWindowBytes) return;

    final List<List<double>> spectrum = WavSpectrogram.analyzePcm16(
      pcmWindow,
      sampleRate: _sampleRate,
      maxColumns: 24,
    );
    if (mounted && spectrum.isNotEmpty) {
      final bool firstWindow = _analysisWindowCount++ == 0;
      final int newColumnCount = firstWindow
          ? spectrum.length
          : math.min(8, spectrum.length);
      final List<List<double>> newColumns = spectrum.sublist(
        spectrum.length - newColumnCount,
      );
      setState(() {
        _spectrogramColumns.addAll(newColumns);
        if (_spectrogramColumns.length > 180) {
          _spectrogramColumns.removeRange(0, _spectrogramColumns.length - 180);
        }
      });
    }

    if (mounted) setState(() => _statusText = 'Analiz ediliyor...');

    try {
      // Apply real-time noise filter before model inference.
      final NoiseFilterSettings filterSettings =
          ref.read(noiseFilterProvider).value ?? NoiseFilterSettings.off;
      final Uint8List filteredPcm =
          _noiseFilter.apply(pcmWindow, filterSettings);

      final InferenceResult result = await _audioEngine!.identifyPcm16(
        filteredPcm,
        IdentificationContext(
          countryCode: 'TR',
          observationDate: DateTime.now(),
        ),
      );

      if (!mounted) return;

      final DateTime now = (_sessionStartTime ?? DateTime.now()).add(
        windowStart,
      );
      bool listChanged = false;
      final bool cicadaLike = _isCicadaLike(spectrum);

      final List<SpeciesPrediction> regional =
          result.predictions
              .where(
                (pred) =>
                    pred.statusCategory != SpeciesStatusCategory.outOfRegion &&
                    !pred.scientificName.toLowerCase().contains(
                      'gallus gallus',
                    ) &&
                    !(cicadaLike &&
                        pred.scientificName.toLowerCase() ==
                            'locustella fluviatilis') &&
                    !_rejectedSpecies.contains(
                      pred.scientificName.toLowerCase(),
                    ),
              )
              .toList()
            ..sort((a, b) => b.score.compareTo(a.score));

      final List<SpeciesPrediction> candidates = regional
          .take(8)
          .where((pred) => pred.score >= 0.03)
          .toList();
      final Set<String> windowKeys = candidates
          .map((pred) => pred.scientificName.toLowerCase())
          .toSet();
      _recentCandidateWindows.add(windowKeys);
      if (_recentCandidateWindows.length > 3) {
        _recentCandidateWindows.removeAt(0);
      }

      for (final SpeciesPrediction pred in candidates) {
        final bool isRare = pred.statusCategory == SpeciesStatusCategory.rare;
        final String candidateKey = pred.scientificName.toLowerCase();
        final int hits = _recentCandidateWindows
            .where((window) => window.contains(candidateKey))
            .length;
        final RegionalSpeciesContext? regionalContext = _regionalContextFor(
          pred,
        );
        final TemporalDetectionContext temporalContext =
            temporalContextForSpecies(
              scientificName: pred.scientificName,
              moment: now,
              latitude: _sessionPosition?.latitude,
              longitude: _sessionPosition?.longitude,
            );
        final LiveDetectionDecision decision = evaluateLiveDetection(
          score: pred.score,
          hits: hits,
          isRare: isRare,
          regionalSupport: regionalContext?.supportLevel,
          configuredMinimum: _liveMinScore,
          temporalMultiplier: temporalContext.confidenceMultiplier,
        );
        debugPrint(
          'Live candidate: ${pred.turkishName} score=${pred.score.toStringAsFixed(3)} '
          'hits=$hits required=${decision.requiredHits} '
          'min=${decision.minimumScore.toStringAsFixed(3)} '
          'temporal=${decision.temporalScore.toStringAsFixed(3)} '
          'regional=${regionalContext?.supportLevel.name ?? 'unknown'} '
          'provisional=${decision.isProvisional} '
          'time=${temporalContext.displayLabel} '
          'accepted=${decision.accepted}',
        );
        if (!decision.accepted) continue;
        if (isRare) _rareAlerts.register(candidateKey);

        final int existingIdx = _detectedSpeciesList.indexWhere(
          (item) =>
              item.prediction.speciesId == pred.speciesId ||
              item.prediction.scientificName.toLowerCase() ==
                  pred.scientificName.toLowerCase(),
        );

        if (existingIdx != -1) {
          // Already in list — update count and time, bubble to top
          final LiveDetectionEntry existing = _detectedSpeciesList.removeAt(
            existingIdx,
          );
          final bool sameAcousticEvent =
              now.difference(existing.lastDetectedAt).abs() <=
              const Duration(seconds: 3);
          existing.lastDetectedAt = now;
          if (sameAcousticEvent) {
            existing.scoreAggregate = existing.scoreAggregate
                .updateCurrentEventPeak(pred.score);
            _extendLatestDetectionMoment(pred, now);
          } else {
            existing.scoreAggregate = existing.scoreAggregate
                .addIndependentEvent(pred.score);
          }
          existing.regionalContext = regionalContext;
          existing.temporalContext = temporalContext;
          existing.isProvisional = decision.isProvisional;
          _detectedSpeciesList.insert(0, existing);
          if (!sameAcousticEvent) _markDetectionFeedback(pred, now);
          listChanged = true;
        } else {
          // New species — insert at top
          _detectedSpeciesList.insert(
            0,
            LiveDetectionEntry(
              prediction: pred,
              scoreAggregate: DetectionScoreAggregate.first(pred.score),
              firstDetectedAt: now,
              lastDetectedAt: now,
              regionalContext: regionalContext,
              temporalContext: temporalContext,
              isProvisional: decision.isProvisional,
            ),
          );
          _markDetectionFeedback(pred, now);
          listChanged = true;
        }
      }

      if (listChanged && mounted) setState(() {});
    } catch (e) {
      debugPrint('Continuous window inference error: $e');
    } finally {
      if (mounted) {
        final bool hasSound = _currentDb > -45.0;
        setState(
          () => _statusText = hasSound ? '🎙️ Ses algılandı' : 'Dinleniyor...',
        );
      }
    }
  }

  Future<void> _loadObservationContext(Directory documentsDirectory) async {
    final List<Directory> candidates = <Directory>[
      Directory(path.join(documentsDirectory.path, 'ebird_context')),
      Directory(path.join(documentsDirectory.path, 'FirBird', 'ebird_context')),
    ];
    for (final Directory directory in candidates) {
      if (!await File(path.join(directory.path, 'manifest.json')).exists()) {
        continue;
      }
      try {
        final EbirdContextPackage package = await EbirdContextPackage.load(
          directory,
        );
        _observationContextEngine = RegionalObservationContextEngine(package);
        _observationContextMessage = null;
        return;
      } catch (error) {
        debugPrint('eBird bağlam paketi açılamadı: $error');
        _observationContextMessage = 'Çevrimdışı gözlem paketi doğrulanamadı.';
      }
    }
    try {
      final EbirdContextPackage bundled = EbirdContextPackage.fromJsonStrings(
        manifest: await rootBundle.loadString(
          'assets/ebird_context/manifest.json',
        ),
        hotspots: await rootBundle.loadString(
          'assets/ebird_context/hotspots.json',
        ),
        recentObservations: await rootBundle.loadString(
          'assets/ebird_context/recent_observations.json',
        ),
      );
      _observationContextEngine = RegionalObservationContextEngine(bundled);
      _observationContextMessage = null;
      return;
    } catch (error) {
      debugPrint('Paketlenmiş eBird bağlamı açılamadı: $error');
    }
    _observationContextMessage ??=
        'Çevrimdışı eBird gözlem paketi henüz yüklenmedi.';
  }

  RegionalSpeciesContext? _regionalContextFor(SpeciesPrediction prediction) {
    final RegionalObservationContextEngine? engine = _observationContextEngine;
    final Position? position = _sessionPosition;
    if (engine == null || position == null) return null;
    return engine.contextForSpecies(
      scientificName: prediction.scientificName,
      latitude: position.latitude,
      longitude: position.longitude,
      radiusKm: _observationRadiusKm,
    );
  }

  LiveDetectionEntry? _entryForPrediction(SpeciesPrediction prediction) {
    final String key = prediction.scientificName.toLowerCase();
    for (final LiveDetectionEntry entry in _detectedSpeciesList) {
      if (entry.prediction.scientificName.toLowerCase() == key) return entry;
    }
    return null;
  }

  Future<void> _stopSession() async {
    if (_isStoppingSession) return;
    _isStoppingSession = true;
    _clockTimer?.cancel();
    _amplitudeSubscription?.cancel();
    await _setKeepScreenOn(false);

    setState(() {
      _statusText = 'Oturum kaydediliyor...';
    });

    try {
      try {
        await _audioRecorder.stop();
        await _audioStreamDone?.future.timeout(const Duration(seconds: 5));
      } catch (error) {
        debugPrint('Continuous audio stop warning: $error');
      }
      _isRecording = false;
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      await _sessionPcmSink?.flush();
      await _sessionPcmSink?.close();
      _sessionPcmSink = null;
      await _analysisTask;

      final String? pcmPath = _sessionPcmPath;
      final File? pcmFile = pcmPath == null ? null : File(pcmPath);
      final int pcmLength = pcmFile != null && await pcmFile.exists()
          ? await pcmFile.length()
          : 0;
      if (pcmFile == null || pcmLength < _bytesPerSample || !mounted) {
        setState(() {
          _isSessionEnded = true;
          _sessionPhase = _LiveSessionPhase.ended;
        });
        return;
      }

      // Save with auto-name
      final String timeStr = DateFormat(
        'dd MMMM HH.mm',
        'tr_TR',
      ).format(DateTime.now());
      String newFileName;
      if (_detectedSpeciesList.isNotEmpty) {
        final List<String> names = _detectedSpeciesList
            .take(3)
            .map((e) => e.prediction.turkishName)
            .toList();
        newFileName = '${names.join(', ')} - $timeStr.wav';
      } else {
        newFileName = 'Canlı Ses Kaydı - $timeStr.wav';
      }

      final Directory appDocs = await getApplicationDocumentsDirectory();
      final String destPath = path.join(appDocs.path, newFileName);
      await _writePcmFileAsWav(
        pcmFile: pcmFile,
        pcmLength: pcmLength,
        destination: destPath,
      );
      final List<List<double>> completedSpectrum = await WavSpectrogram.analyze(
        destPath,
        maxColumns: 240,
        columnsPerSecond: 8,
      );
      final bool publishedToDownloads = await _publishToDownloads(
        sourcePath: destPath,
        displayName: newFileName,
      );

      // Update last detection times with session end
      final DateTime sessionEnd = DateTime.now();
      for (final entry in _detectedSpeciesList) {
        if (entry.lastDetectedAt.isAfter(sessionEnd)) {
          entry.lastDetectedAt = sessionEnd;
        }
      }

      // Save each detected species to history
      if (_detectedSpeciesList.isNotEmpty) {
        final bool historyEnabled = await ref
            .read(appDatabaseProvider)
            .isHistoryEnabled();
        if (historyEnabled) {
          final AppDatabase database = ref.read(appDatabaseProvider);
          final DateTime sessionStart = _sessionStartTime ?? DateTime.now();
          final String sessionId =
              'live_${sessionStart.millisecondsSinceEpoch}';
          final String sessionLabel = DateFormat(
            'dd.MM.yyyy HH:mm',
            'tr_TR',
          ).format(sessionStart);
          for (final entry in _detectedSpeciesList) {
            final String timeRange = _relativeTimeRange(entry);
            final int combinedScore = entry.scoreAggregate.combinedPercent(
              pointsPerAdditionalEvent:
                  _algorithmSettings.repeatedDetectionSupport,
            );
            await database.addIdentification(
              speciesId: entry.prediction.speciesId,
              turkishName: entry.prediction.turkishName,
              scientificName: entry.prediction.scientificName,
              confidence: '%$combinedScore · $timeRange',
              modelVersion: '🎙️ Canlı Oturum · $sessionLabel',
              imageUri: destPath,
              packageId: sessionId,
              speciesStatus: entry.prediction.statusCategory.name,
              modelConfidence: entry.scoreAggregate.averageConfidence,
              repeatedHits: entry.scoreAggregate.independentEventCount,
              predictionMethod: 'aggregate-v1',
            );
          }

          final int recordingDurationMs =
              _capturedPcmBytes * 1000 ~/ _bytesPerSecond;
          for (final _DetectionMoment moment in _detectionMoments) {
            final int startMs = moment.startedAt
                .difference(sessionStart)
                .inMilliseconds
                .clamp(0, recordingDurationMs);
            final int endMs = moment.endedAt
                .difference(sessionStart)
                .inMilliseconds
                .clamp(startMs, recordingDurationMs);
            final LiveDetectionEntry? speciesEntry = _entryForPrediction(
              moment.prediction,
            );
            await database.addLiveDetectionEvent(
              sessionId: sessionId,
              speciesId: moment.prediction.speciesId,
              turkishName: moment.prediction.turkishName,
              scientificName: moment.prediction.scientificName,
              confidence: moment.prediction.score,
              startMs: startMs,
              endMs: endMs,
              detectedAt: moment.startedAt,
              regionalSupport: speciesEntry?.regionalContext?.supportLevel.name,
              temporalContext: speciesEntry?.temporalContext?.displayLabel,
              speciesStatus: moment.prediction.statusCategory.name,
              latitude: _sessionPosition?.latitude,
              longitude: _sessionPosition?.longitude,
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isSessionEnded = true;
        _sessionPhase = _LiveSessionPhase.ended;
        _savedFilePath = destPath;
        _spectrogramColumns
          ..clear()
          ..addAll(completedSpectrum);
        _statusText = publishedToDownloads
            ? 'Download/FirBird içine kaydedildi'
            : 'Oturum tamamlandı';
      });
      if (publishedToDownloads) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt Download/FirBird klasörüne kaydedildi.'),
          ),
        );
      }
      try {
        await pcmFile.delete();
      } catch (_) {}
    } catch (e) {
      _isRecording = false;
      if (mounted) {
        setState(() {
          _isSessionEnded = true;
          _sessionPhase = _LiveSessionPhase.ended;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kayıt hatası: $e')));
      }
    } finally {
      _isStoppingSession = false;
    }
  }

  Future<void> _writePcmFileAsWav({
    required File pcmFile,
    required int pcmLength,
    required String destination,
  }) async {
    final IOSink output = File(destination).openWrite();
    output.add(
      pcm16WavHeader(
        pcmByteLength: pcmLength,
        sampleRate: _sampleRate,
        channels: 1,
      ),
    );
    await output.addStream(pcmFile.openRead());
    await output.close();
  }

  String _relativeTime(DateTime dt) {
    final DateTime start = _sessionStartTime ?? dt;
    final int sec = dt.difference(start).inSeconds.clamp(0, 99999);
    final int m = sec ~/ 60;
    final int s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _relativeTimeRange(LiveDetectionEntry entry) {
    final String from = _relativeTime(entry.firstDetectedAt);
    final String to = _relativeTime(entry.lastDetectedAt);
    return from == to ? from : '$from – $to';
  }

  String _formatDuration(int seconds) {
    final int mins = seconds ~/ 60;
    final int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${(secs).toString().padLeft(2, '0')}';
  }

  String _sessionLocationText() {
    final Position? position = _sessionPosition;
    final String date = DateFormat(
      'd MMMM yyyy',
      'tr_TR',
    ).format(_sessionStartTime ?? DateTime.now());
    if (position == null && !_isRecording) {
      return '$date • Konum dinleme başlayınca alınacak';
    }
    if (position == null) return '$date • Konum alınamadı';
    return '$date • ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
  }

  /// Cicadas produce a persistent, high-frequency, narrow-band drone. This is
  /// deliberately conservative and only gates the known Locustella fluviatilis
  /// confusion case; real bird calls can still be detected beside insects.
  bool _isCicadaLike(List<List<double>> spectrum) {
    if (spectrum.length < 12) return false;
    final List<List<double>> audible = spectrum
        .where((column) => column.isNotEmpty && column.reduce(math.max) > 0.18)
        .toList();
    if (audible.length < spectrum.length * 0.82) return false;

    final List<int> peakBins = audible.map((column) {
      int peak = 0;
      for (int i = 1; i < column.length; i++) {
        if (column[i] > column[peak]) peak = i;
      }
      return peak;
    }).toList();
    final List<int> sorted = List<int>.from(peakBins)..sort();
    final int medianPeak = sorted[sorted.length ~/ 2];
    final double stableFraction =
        peakBins.where((bin) => (bin - medianPeak).abs() <= 1).length /
        peakBins.length;
    final double averagePeak =
        peakBins.reduce((a, b) => a + b) / peakBins.length;
    return averagePeak >= 25 && stableFraction >= 0.84;
  }

  List<SpectrogramMarker> _liveMarkers() {
    final DateTime? start = _sessionStartTime;
    if (start == null || _secondsRecorded <= 0) {
      return const <SpectrogramMarker>[];
    }
    final double visibleSpan = math.min(
      _secondsRecorded.toDouble(),
      _spectrogramColumns.length / 8,
    );
    final double visibleStart = _secondsRecorded - visibleSpan;
    return _detectionMoments
        .map((moment) {
          final String key = moment.prediction.scientificName.toLowerCase();
          final double second =
              moment.startedAt.difference(start).inMilliseconds / 1000;
          return SpectrogramMarker(
            position: (second - visibleStart) / math.max(visibleSpan, 1),
            label: moment.prediction.turkishName,
            confirmed: _confirmedSpecies.contains(key),
          );
        })
        .where((marker) => marker.position >= 0 && marker.position <= 1)
        .toList();
  }

  Future<bool?> _reviewDetection(LiveDetectionEntry entry) async {
    final DetectionVerdict? verdict = await showDetectionEvidenceSheet(
      context,
      _detectionRecordFor(entry),
    );
    if (verdict != null && mounted) _applyVerdict(entry, verdict);
    return false;
  }

  void _applyVerdict(LiveDetectionEntry entry, DetectionVerdict verdict) {
    final String key = entry.prediction.scientificName.toLowerCase();
    _rareAlerts.resolve(key);
    if (verdict == DetectionVerdict.correct) {
      setState(() {
        _confirmedSpecies.add(key);
        _rejectedSpecies.remove(key);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${entry.prediction.turkishName} doğru olarak işaretlendi.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _rejectedSpecies.add(key);
      _detectedSpeciesList.remove(entry);
    });
  }

  DetectionRecord _detectionRecordFor(LiveDetectionEntry entry) {
    final DateTime sessionStart = _sessionStartTime ?? entry.firstDetectedAt;
    final int startMs = math.max(
      0,
      entry.firstDetectedAt.difference(sessionStart).inMilliseconds,
    );
    final int endMs = math.max(
      startMs,
      entry.lastDetectedAt.difference(sessionStart).inMilliseconds + 3000,
    );
    return DetectionRecord(
      id: 'live|${sessionStart.millisecondsSinceEpoch}|${entry.prediction.speciesId}|$startMs',
      speciesId: entry.prediction.speciesId,
      turkishName: entry.prediction.turkishName,
      scientificName: entry.prediction.scientificName,
      modelConfidence: entry.scoreAggregate.averageConfidence,
      detectedAt: entry.firstDetectedAt,
      source: DetectionSource.live,
      statusCategory: entry.prediction.statusCategory,
      modelVersion: 'BirdNET canlı ses',
      thumbnailUrl: entry.prediction.thumbnailUrl,
      audioStartMs: startMs,
      audioEndMs: endMs,
      latitude: _sessionPosition?.latitude,
      longitude: _sessionPosition?.longitude,
      repeatedHits: entry.detectionCount,
      repetitionSupportPerHit: _algorithmSettings.repeatedDetectionSupport,
    );
  }

  PlaybackSession? _completedPlaybackSession() {
    final String? filePath = _savedFilePath;
    final DateTime? sessionStart = _sessionStartTime;
    if (filePath == null || sessionStart == null) return null;
    return PlaybackSession(
      filePath: filePath,
      displayName: path.basename(filePath),
      rareSpeciesCount: _rareAlerts.detectedSpeciesCount,
      detections: _detectionMoments
          .map((moment) {
            final int startMs = math.max(
              0,
              moment.startedAt.difference(sessionStart).inMilliseconds,
            );
            final int endMs = math.max(
              startMs,
              moment.endedAt.difference(sessionStart).inMilliseconds,
            );
            final LiveDetectionEntry? speciesEntry = _entryForPrediction(
              moment.prediction,
            );
            final DetectionScoreAggregate scoreAggregate =
                speciesEntry?.scoreAggregate ??
                DetectionScoreAggregate.first(moment.prediction.score);
            return PlaybackDetection(
              speciesId: moment.prediction.speciesId,
              turkishName: moment.prediction.turkishName,
              scientificName: moment.prediction.scientificName,
              startMs: startMs,
              endMs: endMs,
              modelConfidence: scoreAggregate.averageConfidence,
              repeatedHits: scoreAggregate.independentEventCount,
              repetitionSupportPerHit:
                  _algorithmSettings.repeatedDetectionSupport,
              regionalSupport: speciesEntry?.regionalContext?.supportLevel.name,
              temporalContext: speciesEntry?.temporalContext?.displayLabel,
              thumbnailUrl: moment.prediction.thumbnailUrl,
              detectedAt: moment.startedAt,
              latitude: _sessionPosition?.latitude,
              longitude: _sessionPosition?.longitude,
              modelVersion: 'BirdNET canlı ses',
              statusCategory: moment.prediction.statusCategory,
            );
          })
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PlaybackSession? completedSession = _completedPlaybackSession();
    if (_isSessionEnded && completedSession != null) {
      return MediaPlayerScreen(
        session: completedSession,
        onClose: () => context.pop(),
        onSaveCopy: _saveRecordingWithName,
      );
    }
    final theme = Theme.of(context);
    final bool hasSound = _currentDb > -45.0;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Canlı Ses Tespit Modu'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menü',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          const AppBarHelpButton(),
          IconButton(
            tooltip: _isRecording
                ? 'Harita (canlı dinleme devam eder)'
                : 'Yakındaki gözlem noktaları',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => showNearbyHotspotMapSheet(
              context,
              latitude: _sessionPosition?.latitude,
              longitude: _sessionPosition?.longitude,
            ),
          ),
          if (_detectedSpeciesList.isNotEmpty)
            Tooltip(
              message: '${_detectedSpeciesList.length} kuş türü tespit edildi',
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Badge(
                  label: Text('${_detectedSpeciesList.length}'),
                  child: const Icon(Icons.flutter_dash_outlined),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Equalizer Header ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AudioSpectrogram(
                      columns: _spectrogramColumns,
                      markers: _liveMarkers(),
                      liveCenter: true,
                      height: 128,
                    ),
                    if (_isRecording)
                      Positioned(
                        right: 10,
                        bottom: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: _statusText,
                                  child: Icon(
                                    hasSound ? Icons.mic : Icons.mic_none,
                                    color: hasSound
                                        ? Colors.greenAccent
                                        : Colors.white70,
                                    size: 15,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _formatDuration(_secondsRecorded),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _sessionLocationText(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Section Label ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    _sessionPhase == _LiveSessionPhase.ready
                        ? 'DİNLEMEYE HAZIR'
                        : _sessionPhase == _LiveSessionPhase.preparing ||
                              _sessionPhase == _LiveSessionPhase.starting
                        ? 'HAZIRLANIYOR'
                        : 'CANLI TESPİT',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 3,
                  child: Text(
                    _isRecording
                        ? '${_detectedSpeciesList.length} Kuş${_rareAlerts.detectedSpeciesCount > 0 ? ' · ${_rareAlerts.detectedSpeciesCount} nadir tür tespiti' : ''} · ${_formatDuration(_secondsRecorded)}'
                        : _statusText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Detection Table ───────────────────────────────────────
          Expanded(
            child: _detectedSpeciesList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_sessionPhase == _LiveSessionPhase.preparing ||
                              _sessionPhase == _LiveSessionPhase.starting)
                            const CircularProgressIndicator()
                          else if (_sessionPhase == _LiveSessionPhase.ready)
                            Semantics(
                              button: true,
                              label: 'Canlı dinlemeyi başlat',
                              child: IconButton.filled(
                                tooltip: 'Canlı dinlemeyi başlat',
                                onPressed: _startListening,
                                icon: const Icon(Icons.mic, size: 34),
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(72, 72),
                                ),
                              ),
                            )
                          else
                            Icon(
                              _sessionPhase == _LiveSessionPhase.failed
                                  ? Icons.error_outline
                                  : Icons.graphic_eq,
                              size: 64,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            _sessionPhase == _LiveSessionPhase.ready
                                ? 'Dinlemeyi başlatmak için mikrofona dokunun'
                                : _sessionPhase == _LiveSessionPhase.failed
                                ? 'Canlı dinleme hazırlanamadı'
                                : _isRecording
                                ? 'Kuş sesleri bekleniyor...'
                                : 'Model yükleniyor, lütfen bekleyin...',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (_sessionPhase == _LiveSessionPhase.ready)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Mikrofon ve konum izinleri bu dokunuştan sonra istenir.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          else if (_isRecording)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Kesintisiz ses, her saniye son 3 saniyelik pencerede analiz ediliyor.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          if (_sessionPhase == _LiveSessionPhase.failed) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _sessionPhase = _LiveSessionPhase.preparing;
                                  _statusText = 'Model yeniden hazırlanıyor...';
                                });
                                unawaited(_prepareSession());
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tekrar dene'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: Text(
                            'Son tespitler',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        // Table rows
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _detectedSpeciesList.length,
                            separatorBuilder: (context, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = _detectedSpeciesList[index];
                              final pred = item.prediction;
                              final bool isFreshDetection =
                                  _highlightedSpeciesKey ==
                                  pred.scientificName.toLowerCase();

                              return Dismissible(
                                key: ValueKey<String>(pred.scientificName),
                                direction: DismissDirection.startToEnd,
                                confirmDismiss: (_) => _reviewDetection(item),
                                background: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  padding: const EdgeInsets.only(left: 22),
                                  alignment: Alignment.centerLeft,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.fact_check_outlined),
                                      SizedBox(width: 8),
                                      Text('Doğrula'),
                                    ],
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  child: BirdDetectionCard(
                                    record: _detectionRecordFor(item),
                                    isHighlighted: isFreshDetection,
                                    isRareAlertActive: _rareAlerts.isUnresolved(
                                      pred.scientificName,
                                    ),
                                    isRareAlertPulse:
                                        _rareAlerts.isPulseVisible,
                                    onVerdict: (DetectionVerdict verdict) =>
                                        _applyVerdict(item, verdict),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Tablo Açıklama Notu (Küçük Fontlu)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                _buildLegendNoteItem(
                                  Colors.green,
                                  'Yerel / Göçmen',
                                ),
                                _buildLegendNoteItem(
                                  Colors.grey,
                                  'Bölge Dışı / Zor',
                                ),
                                _buildLegendNoteItem(
                                  Colors.blue,
                                  'Yeni / aktif tespit',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // ── Bottom Action Panel ───────────────────────────────────
          if (_isRecording || _isSessionEnded)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: _isSessionEnded
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => context.pop(),
                                icon: const Icon(Icons.close),
                                label: const Text('Kapat'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: _savedFilePath == null
                                    ? null
                                    : _saveRecordingWithName,
                                icon: const Icon(Icons.save_alt_outlined),
                                label: const Text('Farklı adla kaydet'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _stopSession,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Oturumu Bitir'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendNoteItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
