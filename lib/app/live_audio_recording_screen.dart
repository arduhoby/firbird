import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:firbird/app/app_drawer.dart';
import 'package:firbird/app/audio_spectrogram.dart';
import 'package:firbird/data/app_database.dart';
import 'package:firbird/inference/audio_inference_engine.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:firbird/observation_context/ebird_context_package.dart';
import 'package:firbird/observation_context/regional_observation_context.dart';

class LiveDetectionEntry {
  LiveDetectionEntry({
    required this.prediction,
    required this.firstDetectedAt,
    required this.lastDetectedAt,
    this.detectionCount = 1,
    this.regionalContext,
  });

  final SpeciesPrediction prediction;
  final DateTime firstDetectedAt;
  DateTime lastDetectedAt;
  int detectionCount;
  RegionalSpeciesContext? regionalContext;
}

class _DetectionMoment {
  const _DetectionMoment({required this.prediction, required this.detectedAt});

  final SpeciesPrediction prediction;
  final DateTime detectedAt;
}

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
  bool _isSegmentRecording = false;
  bool _isEngineReady = false;
  bool _isSessionEnded = false;
  String _statusText = 'Model yükleniyor...';
  int _secondsRecorded = 0;
  bool _tenMinuteCheckShown = false;
  int _segmentCount = 0;
  Timer? _clockTimer;
  Timer? _segmentTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  String? _savedFilePath;
  DateTime? _sessionStartTime;
  Position? _sessionPosition;
  RegionalObservationContextEngine? _observationContextEngine;
  int _observationRadiusKm = 20;
  String? _observationContextMessage;

  // The analyzed microphone segments are retained and merged into one WAV.
  // This avoids opening two simultaneous Android microphone recorders.
  final List<String> _sessionSegmentPaths = <String>[];
  static const MethodChannel _mediaChannel = MethodChannel(
    'org.firbird3.app/media_player',
  );
  static const MethodChannel _screenChannel = MethodChannel(
    'org.firbird3.app/screen',
  );
  static const MethodChannel _downloadsChannel = MethodChannel(
    'org.firbird3.app/downloads',
  );
  bool _isPlaybackActive = false;
  bool _isPlaybackPaused = false;
  double _playbackGain = 1.0;
  int _playbackPositionMs = 0;
  int _playbackDurationMs = 0;
  Timer? _playbackTimer;

  double _currentDb = -60.0;
  final List<List<double>> _spectrogramColumns = <List<double>>[];
  final List<LiveDetectionEntry> _detectedSpeciesList = <LiveDetectionEntry>[];
  final List<_DetectionMoment> _detectionMoments = <_DetectionMoment>[];
  final Set<String> _rejectedSpecies = <String>{};
  final Set<String> _confirmedSpecies = <String>{};
  final List<Set<String>> _recentCandidateWindows = <Set<String>>[];
  String? _highlightedSpeciesKey;
  Timer? _highlightTimer;

  /// Loaded from settings — minimum confidence to show in live table (0.0 = all)
  double _liveMinScore = 0.0;

  @override
  void initState() {
    super.initState();
    _initAndStart();
  }

  @override
  void dispose() {
    // The native flag is process/window scoped, so always release it when the
    // live screen goes away, including an interrupted session.
    _setKeepScreenOn(false);
    _clockTimer?.cancel();
    _segmentTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _audioRecorder.dispose();
    _playbackTimer?.cancel();
    _highlightTimer?.cancel();
    _stopPlayback();
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
      _DetectionMoment(prediction: prediction, detectedAt: detectedAt),
    );
    if (_detectionMoments.length > 24) _detectionMoments.removeAt(0);
    _highlightTimer?.cancel();
    _highlightedSpeciesKey = key;
    _highlightTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _highlightedSpeciesKey == key) {
        setState(() => _highlightedSpeciesKey = null);
      }
    });
  }

  Future<void> _stopPlayback() async {
    try {
      await _mediaChannel.invokeMethod<void>('stop');
    } catch (_) {}
    _playbackTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPlaybackActive = false;
        _isPlaybackPaused = false;
        _playbackPositionMs = 0;
      });
    }
  }

  void _startPlaybackPolling() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) async {
      try {
        final result = await _mediaChannel.invokeMethod<dynamic>('position');
        if (!mounted || result is! Map) return;
        final int position = (result['positionMs'] as num?)?.toInt() ?? 0;
        final int duration = (result['durationMs'] as num?)?.toInt() ?? 0;
        setState(() {
          _playbackPositionMs = position;
          _playbackDurationMs = duration;
        });
        // Android can briefly report isPlaying=false while preparing. Keep
        // the player alive until the actual recording duration is reached.
        if (_isPlaybackActive &&
            !_isPlaybackPaused &&
            duration > 0 &&
            position >= duration - 300) {
          await _stopPlayback();
        }
      } catch (_) {}
    });
  }

  Future<void> _togglePause() async {
    if (!_isPlaybackActive) {
      await _togglePlayback();
      return;
    }
    await _mediaChannel.invokeMethod<void>(
      _isPlaybackPaused ? 'resume' : 'pause',
    );
    if (mounted) setState(() => _isPlaybackPaused = !_isPlaybackPaused);
  }

  Future<void> _seekPlayback(int positionMs) async {
    await _mediaChannel.invokeMethod<void>('seekTo', <String, dynamic>{
      'positionMs': positionMs,
    });
    if (mounted) setState(() => _playbackPositionMs = positionMs);
  }

  Future<void> _jumpToDetection({required bool next}) async {
    if (_detectedSpeciesList.isEmpty) return;
    final List<int> points =
        _detectedSpeciesList
            .map(
              (entry) => entry.firstDetectedAt
                  .difference(_sessionStartTime ?? entry.firstDetectedAt)
                  .inMilliseconds,
            )
            .toList()
          ..sort();
    final int current = _playbackPositionMs;
    final int target = next
        ? (points.firstWhere(
            (point) => point > current + 1500,
            orElse: () => points.first,
          ))
        : (points.lastWhere(
            (point) => point < current - 1500,
            orElse: () => points.first,
          ));
    if (!_isPlaybackActive) await _togglePlayback();
    await _seekPlayback(target);
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

  String _formatPlaybackTime(int ms) {
    final int totalSeconds = (ms / 1000).floor();
    return '${(totalSeconds ~/ 60).toString().padLeft(2, '0')}:${(totalSeconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _togglePlayback() async {
    final String? filePath = _savedFilePath;
    if (filePath == null || !await File(filePath).exists()) return;
    if (_isPlaybackActive) {
      await _stopPlayback();
      return;
    }
    try {
      await _mediaChannel.invokeMethod<void>('play', <String, dynamic>{
        'path': filePath,
      });
      await _mediaChannel.invokeMethod<void>('setVolume', <String, dynamic>{
        'volume': _playbackGain,
      });
      if (mounted) {
        setState(() {
          _isPlaybackActive = true;
          _isPlaybackPaused = false;
        });
        _startPlaybackPolling();
      }
    } on PlatformException {
      // Older installed builds used the looping method name.
      await _mediaChannel.invokeMethod<void>('playLooping', <String, dynamic>{
        'path': filePath,
      });
      if (mounted) {
        setState(() {
          _isPlaybackActive = true;
          _isPlaybackPaused = false;
        });
        _startPlaybackPolling();
      }
    }
  }

  Future<void> _initAndStart() async {
    try {
      final bool hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mikrofon izni verilmedi.')),
          );
        }
        return;
      }

      // Request location permission for live audio detection session
      try {
        if (await Geolocator.isLocationServiceEnabled()) {
          LocationPermission locPerm = await Geolocator.checkPermission();
          if (locPerm == LocationPermission.denied) {
            locPerm = await Geolocator.requestPermission();
          }
          if (locPerm == LocationPermission.whileInUse ||
              locPerm == LocationPermission.always) {
            _sessionPosition = await Geolocator.getCurrentPosition();
            debugPrint('Canlı ses oturumu için konum izni alındı.');
          }
        }
      } catch (e) {
        debugPrint('Konum izni alınırken hata: $e');
      }

      // Load occurrences for status categorization
      await SpeciesStatusHelper.loadOccurrences();

      // Load live detection min score from settings
      _liveMinScore = await ref
          .read(appDatabaseProvider)
          .liveDetectionMinScore();
      _observationRadiusKm = await ref
          .read(appDatabaseProvider)
          .observationContextRadiusKm();

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
        if (mounted) setState(() => _statusText = 'Model yüklenemedi: $e');
        return;
      }

      if (!mounted) return;

      // Amplitude listener for equalizer
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
        _isEngineReady = true;
        _sessionStartTime = DateTime.now();
        _statusText = 'Ortam dinleniyor...';
      });
      await _setKeepScreenOn(true);

      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        bool showTenMinuteCheck = false;
        setState(() {
          _secondsRecorded++;
          if (!_tenMinuteCheckShown && _secondsRecorded >= 10 * 60) {
            _tenMinuteCheckShown = true;
            showTenMinuteCheck = true;
          }
        });
        if (showTenMinuteCheck) unawaited(_showTenMinuteCheck());
      });

      // Start first segment
      _startNextSegment();
    } catch (e) {
      if (mounted) {
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

  /// Segment-based recording: record 3s → stop → analyze → repeat
  Future<void> _startNextSegment() async {
    if (!_isRecording || !mounted) return;

    try {
      final Directory tempDir = await getTemporaryDirectory();
      _segmentCount++;
      final String segPath = path.join(
        tempDir.path,
        'seg_${_segmentCount}_${DateTime.now().millisecondsSinceEpoch}.wav',
      );

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 48000,
          numChannels: 1,
        ),
        path: segPath,
      );
      _isSegmentRecording = true;

      if (mounted) setState(() => _statusText = 'Dinleniyor...');

      // After 3 seconds, stop segment, analyze, then restart
      _segmentTimer = Timer(const Duration(seconds: 3), () async {
        if (!_isRecording || !mounted) return;
        await _stopAndAnalyzeSegment(segPath);
      });
    } catch (e) {
      debugPrint('Segment start error: $e');
      // Retry after a short delay
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _startNextSegment();
    }
  }

  Future<void> _stopAndAnalyzeSegment(String segPath) async {
    try {
      final String? stoppedPath = await _audioRecorder.stop();
      _isSegmentRecording = false;
      final String filePath = stoppedPath ?? segPath;
      if (await File(filePath).exists()) _sessionSegmentPaths.add(filePath);

      // Immediately start next segment (parallel to analysis)
      if (_isRecording && mounted) {
        _startNextSegment();
      }

      final List<List<double>> spectrum = await WavSpectrogram.analyze(
        filePath,
        maxColumns: 24,
      );
      if (mounted && spectrum.isNotEmpty) {
        setState(() {
          _spectrogramColumns.addAll(spectrum);
          if (_spectrogramColumns.length > 180) {
            _spectrogramColumns.removeRange(
              0,
              _spectrogramColumns.length - 180,
            );
          }
        });
      }

      // Analyze the completed segment
      await _analyzeSegment(filePath, spectrum: spectrum);

      // Segment files are removed after the final session WAV is merged.
    } catch (e) {
      debugPrint('Segment stop/analyze error: $e');
      _isSegmentRecording = false;
      if (_isRecording && mounted) _startNextSegment();
    }
  }

  Future<void> _analyzeSegment(
    String filePath, {
    List<List<double>> spectrum = const <List<double>>[],
  }) async {
    if (_audioEngine == null || !_isEngineReady) return;

    final File segFile = File(filePath);
    final int fileSize = await segFile.exists() ? await segFile.length() : 0;
    if (fileSize < 10000) {
      debugPrint('Segment too small ($fileSize bytes), skipping');
      return;
    }

    if (mounted) setState(() => _statusText = 'Analiz ediliyor...');

    try {
      final InferenceResult result = await _audioEngine!.identify(
        ImageInput(uri: filePath),
        IdentificationContext(
          countryCode: 'TR',
          observationDate: DateTime.now(),
        ),
      );

      if (!mounted) return;

      final DateTime now = DateTime.now();
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
          .take(3)
          .where((pred) => pred.score >= 0.06)
          .toList();
      final Set<String> windowKeys = candidates
          .map((pred) => pred.scientificName.toLowerCase())
          .toSet();
      _recentCandidateWindows.add(windowKeys);
      if (_recentCandidateWindows.length > 3) {
        _recentCandidateWindows.removeAt(0);
      }

      for (final SpeciesPrediction pred in candidates) {
        final double threshold =
            pred.statusCategory == SpeciesStatusCategory.rare ? 0.25 : 0.10;
        final double effectiveThreshold = math.max(_liveMinScore, threshold);
        final String candidateKey = pred.scientificName.toLowerCase();
        final int hits = _recentCandidateWindows
            .where((window) => window.contains(candidateKey))
            .length;
        debugPrint(
          'Live candidate: ${pred.turkishName} score=${pred.score.toStringAsFixed(3)} hits=$hits',
        );
        if (pred.score < effectiveThreshold ||
            (hits < 2 && pred.score < 0.35)) {
          continue;
        }

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
          existing.lastDetectedAt = now;
          existing.detectionCount++;
          existing.regionalContext = _regionalContextFor(pred);
          _detectedSpeciesList.insert(0, existing);
          _markDetectionFeedback(pred, now);
          listChanged = true;
        } else {
          // New species — insert at top
          _detectedSpeciesList.insert(
            0,
            LiveDetectionEntry(
              prediction: pred,
              firstDetectedAt: now,
              lastDetectedAt: now,
              regionalContext: _regionalContextFor(pred),
            ),
          );
          _markDetectionFeedback(pred, now);
          listChanged = true;
        }
      }

      if (listChanged && mounted) setState(() {});
    } catch (e) {
      debugPrint('Segment inference error: $e');
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

  Future<void> _stopSession() async {
    _clockTimer?.cancel();
    _segmentTimer?.cancel();
    _amplitudeSubscription?.cancel();
    await _setKeepScreenOn(false);

    setState(() {
      _isRecording = false;
      _statusText = 'Oturum kaydediliyor...';
    });

    try {
      // Stop segment recorder if active
      if (_isSegmentRecording) {
        try {
          await _audioRecorder.stop();
        } catch (_) {}
        _isSegmentRecording = false;
      }

      if (_sessionSegmentPaths.isEmpty || !mounted) {
        setState(() => _isSessionEnded = true);
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
      await _mergeWavSegments(_sessionSegmentPaths, destPath);
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
          // Use session start timestamp as shared group key
          final String sessionId =
              'live_${(_sessionStartTime ?? DateTime.now()).millisecondsSinceEpoch}';
          final String sessionLabel = DateFormat(
            'dd.MM.yyyy HH:mm',
            'tr_TR',
          ).format(_sessionStartTime ?? DateTime.now());
          for (final entry in _detectedSpeciesList) {
            final String timeRange = _relativeTimeRange(entry);
            await ref
                .read(appDatabaseProvider)
                .addIdentification(
                  speciesId: entry.prediction.speciesId,
                  turkishName: entry.prediction.turkishName,
                  scientificName: entry.prediction.scientificName,
                  confidence:
                      '%${(entry.prediction.score * 100).round()} · $timeRange',
                  modelVersion: '🎙️ Canlı Oturum · $sessionLabel',
                  imageUri: destPath,
                  packageId: sessionId,
                  predictionMethod: 'count:${entry.detectionCount}',
                );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isSessionEnded = true;
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
    } catch (e) {
      if (mounted) {
        setState(() => _isSessionEnded = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kayıt hatası: $e')));
      }
    }
  }

  Future<void> _mergeWavSegments(
    List<String> segmentPaths,
    String destination,
  ) async {
    final BytesBuilder pcm = BytesBuilder(copy: false);
    Uint8List? header;
    for (final segmentPath in segmentPaths) {
      final file = File(segmentPath);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      if (bytes.length <= 44) continue;
      header ??= Uint8List.fromList(bytes.sublist(0, 44));
      pcm.add(bytes.sublist(44));
    }
    if (header == null) throw StateError('Geçerli ses parçası bulunamadı.');
    final audio = pcm.takeBytes();
    final data = ByteData.sublistView(header);
    data.setUint32(4, 36 + audio.length, Endian.little);
    data.setUint32(40, audio.length, Endian.little);
    final output = BytesBuilder(copy: false)
      ..add(header)
      ..add(audio);
    await File(destination).writeAsBytes(output.takeBytes(), flush: true);
    for (final segmentPath in segmentPaths) {
      try {
        await File(segmentPath).delete();
      } catch (_) {}
    }
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
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _sessionLocationText() {
    final Position? position = _sessionPosition;
    final String date = DateFormat(
      'd MMMM yyyy',
      'tr_TR',
    ).format(_sessionStartTime ?? DateTime.now());
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
    final double visibleSpan = _isSessionEnded
        ? _secondsRecorded.toDouble()
        : math.min(_secondsRecorded.toDouble(), _spectrogramColumns.length / 8);
    final double visibleStart = _secondsRecorded - visibleSpan;
    return _detectionMoments
        .map((moment) {
          final String key = moment.prediction.scientificName.toLowerCase();
          final double second =
              moment.detectedAt.difference(start).inMilliseconds / 1000;
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
    final String key = entry.prediction.scientificName.toLowerCase();
    final bool? correct = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.prediction.turkishName),
        content: const Text('Bu kuş tahmini doğru mu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Doğru değil'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Doğru'),
          ),
        ],
      ),
    );
    if (correct == null || !mounted) return false;
    if (correct) {
      setState(() => _confirmedSpecies.add(key));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${entry.prediction.turkishName} doğru olarak işaretlendi.',
          ),
        ),
      );
      return false;
    }
    setState(() {
      _rejectedSpecies.add(key);
      _detectedSpeciesList.remove(entry);
    });
    return false;
  }

  double _combinedConfidence(LiveDetectionEntry entry) {
    final double modelScore = entry.prediction.score.clamp(0, 1);
    final RegionalSupportLevel level =
        entry.regionalContext?.supportLevel ?? RegionalSupportLevel.none;
    final double supportWeight = switch (level) {
      RegionalSupportLevel.none => 0,
      RegionalSupportLevel.weak => 0.03,
      RegionalSupportLevel.moderate => 0.08,
      RegionalSupportLevel.strong => 0.15,
    };
    return modelScore + ((1 - modelScore) * supportWeight);
  }

  Future<void> _showRegionalEvidence(LiveDetectionEntry entry) async {
    entry.regionalContext ??= _regionalContextFor(entry.prediction);
    if (!mounted) return;
    final RegionalSpeciesContext? regional = entry.regionalContext;
    final ThemeData theme = Theme.of(context);
    final int modelPct = (entry.prediction.score * 100).round();
    final int combinedPct = (_combinedConfidence(entry) * 100).round();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => FractionallySizedBox(
        heightFactor: 0.82,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: <Widget>[
            Row(
              children: <Widget>[
                _LiveThumbnail(url: entry.prediction.thumbnailUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.prediction.turkishName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        entry.prediction.scientificName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: _EvidenceMetric(
                    label: 'Ses modeli',
                    value: '%$modelPct',
                    icon: Icons.graphic_eq,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _EvidenceMetric(
                    label: 'Bölgesel destek',
                    value: _supportLabel(regional?.supportLevel),
                    icon: Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _EvidenceMetric(
                    label: 'Birleşik güven',
                    value: regional == null ? '—' : '%$combinedPct',
                    icon: Icons.fact_check_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (regional == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.info_outline),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _sessionPosition == null
                              ? 'Konum alınamadığı için bölgesel doğrulama yapılamadı.'
                              : (_observationContextMessage ??
                                    'Çevrimdışı gözlem verisi kullanılamıyor.'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...<Widget>[
              Text(
                '${regional.radiusKm} km içindeki güncel destek',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (regional.evidence.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Seçilen mesafede bu türe ait güncel eBird kaydı bulunamadı. Bu, türün bölgede bulunmadığı anlamına gelmez.',
                    ),
                  ),
                )
              else
                ...regional.evidence.map(
                  (RegionalObservationEvidence evidence) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.flutter_dash_outlined),
                      title: Text(evidence.observation.locationName),
                      subtitle: Text(
                        '${DateFormat('d MMMM yyyy HH:mm', 'tr_TR').format(evidence.observation.observedAt)}\n'
                        '${evidence.distanceKm.toStringAsFixed(1)} km · ${evidence.ageDays} gün önce',
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Yakındaki gözlem noktaları',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              if (regional.nearbyHotspots.isEmpty)
                const Text('Seçilen mesafede hotspot bulunamadı.')
              else
                ...regional.nearbyHotspots
                    .take(5)
                    .map(
                      (NearbyHotspot nearby) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(nearby.hotspot.name),
                        trailing: Text(
                          '${nearby.distanceKm.toStringAsFixed(1)} km',
                        ),
                      ),
                    ),
              const Divider(height: 28),
              Text(
                'Kaynak: eBird çevrimdışı güncel gözlem özeti\n'
                'Paket tarihi: ${DateFormat('d MMMM yyyy', 'tr_TR').format(regional.sourceGeneratedAt.toLocal())}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Birleşik güven, ses modeli ile güncel bölgesel desteğin açıklanabilir birleşimidir; tarihsel görülme sıklığı değildir.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _supportLabel(RegionalSupportLevel? level) => switch (level) {
    RegionalSupportLevel.strong => 'Güçlü',
    RegionalSupportLevel.moderate => 'Orta',
    RegionalSupportLevel.weak => 'Zayıf',
    RegionalSupportLevel.none => 'Kayıt yok',
    null => 'Veri yok',
  };

  @override
  Widget build(BuildContext context) {
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
          if (_detectedSpeciesList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                avatar: const Icon(Icons.flutter_dash, size: 16),
                label: Text('${_detectedSpeciesList.length} Tür'),
                backgroundColor: theme.colorScheme.primaryContainer,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Equalizer Header ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
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
                    _isSessionEnded
                        ? ScrollableAudioSpectrogram(
                            columns: _spectrogramColumns,
                            markers: _liveMarkers(),
                            playbackPosition: _playbackDurationMs > 0
                                ? _playbackPositionMs / _playbackDurationMs
                                : null,
                            onSeek: _playbackDurationMs > 0
                                ? (fraction) => _seekPlayback(
                                    (_playbackDurationMs * fraction).round(),
                                  )
                                : null,
                            height: 180,
                          )
                        : AudioSpectrogram(
                            columns: _spectrogramColumns,
                            markers: _liveMarkers(),
                            liveCenter: true,
                            height: 128,
                          ),
                    if (_isSessionEnded && _savedFilePath != null)
                      IconButton.filled(
                        tooltip: _isPlaybackActive && !_isPlaybackPaused
                            ? 'Duraklat'
                            : 'Oynat',
                        onPressed: _togglePause,
                        iconSize: 38,
                        icon: Icon(
                          _isPlaybackActive && !_isPlaybackPaused
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                    if (!_isSessionEnded)
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
                Text(
                  _isSessionEnded ? 'OTURUM ÖZETİ' : 'CANLI TESPİT',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  '${_detectedSpeciesList.length} Kuş · ${_formatDuration(_secondsRecorded)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
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
                          Icon(
                            Icons.graphic_eq,
                            size: 64,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isEngineReady
                                ? (_isSessionEnded
                                      ? 'Bu oturumda hiç tür tespit edilmedi.'
                                      : 'Kuş sesleri bekleniyor...')
                                : 'Model yükleniyor, lütfen bekleyin...',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (_isEngineReady && !_isSessionEnded)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Her 3 saniyede bir analiz yapılıyor.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
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
                              final int pct = (pred.score * 100).round();
                              final Color pctColor = pct >= 70
                                  ? Colors.green
                                  : pct >= 40
                                  ? Colors.orange
                                  : Colors.red;

                              final statusCat = pred.statusCategory;
                              final Color borderColor = statusCat.borderColor;
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
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _showRegionalEvidence(item),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isFreshDetection
                                          ? theme.colorScheme.primaryContainer
                                                .withValues(alpha: 0.72)
                                          : index.isEven
                                          ? theme.colorScheme.surface
                                          : theme
                                                .colorScheme
                                                .surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: borderColor,
                                        width: 1.8,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          _LiveThumbnail(
                                            url: pred.thumbnailUrl,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 4,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  pred.turkishName,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                Text(
                                                  pred.scientificName,
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                ),
                                                if (item.detectionCount > 1)
                                                  Text(
                                                    '${item.detectionCount}× duyuldu',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          Colors.green.shade700,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                const SizedBox(height: 4),
                                                _RegionalSupportBadge(
                                                  level: item
                                                      .regionalContext
                                                      ?.supportLevel,
                                                  contextAvailable:
                                                      _observationContextEngine !=
                                                          null &&
                                                      _sessionPosition != null,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              _relativeTimeRange(item),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontFeatures: [
                                                      const FontFeature.tabularFigures(),
                                                    ],
                                                  ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 58,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: pctColor.withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '%$pct',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: pctColor,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildLegendNoteItem(
                                  Colors.green,
                                  'Yerel / Göçmen',
                                ),
                                _buildLegendNoteItem(Colors.red, 'Nadir Tür'),
                                _buildLegendNoteItem(
                                  Colors.grey,
                                  'Bölge Dışı / Zor',
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
          Container(
            padding: const EdgeInsets.all(20),
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
                      // Playback lives in the spectrogram above; this old
                      // secondary player is hidden to prioritize the bird list.
                      // Kept out of the widget tree: playback controls are in
                      // the spectrogram so live and reopened sessions use one player.
                      // ignore: dead_code
                      if (false) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isPlaybackActive
                                    ? Icons.volume_up
                                    : Icons.audio_file_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Oturum kaydı hazır. Tespit edilen sesleri tekrar dinleyebilirsiniz.',
                                ),
                              ),
                              IconButton(
                                tooltip: _isPlaybackActive
                                    ? 'Durdur'
                                    : 'Kaydı dinle',
                                onPressed: _togglePlayback,
                                icon: Icon(
                                  _isPlaybackActive
                                      ? Icons.stop_circle
                                      : Icons.play_circle_fill,
                                ),
                                iconSize: 34,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _formatPlaybackTime(_playbackPositionMs),
                              style: theme.textTheme.labelSmall,
                            ),
                            Expanded(
                              child: Slider(
                                min: 0,
                                max:
                                    (_playbackDurationMs > 0
                                            ? _playbackDurationMs
                                            : 1)
                                        .toDouble(),
                                value: _playbackPositionMs
                                    .clamp(
                                      0,
                                      _playbackDurationMs > 0
                                          ? _playbackDurationMs
                                          : 1,
                                    )
                                    .toDouble(),
                                onChanged: _playbackDurationMs == 0
                                    ? null
                                    : (value) => _seekPlayback(value.round()),
                              ),
                            ),
                            Text(
                              _formatPlaybackTime(_playbackDurationMs),
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Önceki tespit',
                              onPressed: () => _jumpToDetection(next: false),
                              icon: const Icon(Icons.skip_previous_rounded),
                              iconSize: 30,
                            ),
                            IconButton.filled(
                              tooltip: _isPlaybackPaused
                                  ? 'Devam et'
                                  : 'Duraklat',
                              onPressed: _togglePause,
                              icon: Icon(
                                _isPlaybackPaused
                                    ? Icons.play_arrow
                                    : Icons.pause,
                              ),
                              iconSize: 28,
                            ),
                            IconButton(
                              tooltip: 'Sonraki tespit',
                              onPressed: () => _jumpToDetection(next: true),
                              icon: const Icon(Icons.skip_next_rounded),
                              iconSize: 30,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.volume_down, size: 18),
                            Expanded(
                              child: Slider(
                                min: 0.5,
                                max: 4.0,
                                divisions: 7,
                                value: _playbackGain,
                                label: '${(_playbackGain * 100).round()}%',
                                onChanged: (value) async {
                                  setState(() => _playbackGain = value);
                                  await _mediaChannel.invokeMethod<void>(
                                    'setVolume',
                                    <String, dynamic>{'volume': value},
                                  );
                                },
                              ),
                            ),
                            Text('${(_playbackGain * 100).round()}%'),
                            const Icon(Icons.volume_up, size: 18),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
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
                      onPressed: _isRecording ? _stopSession : null,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Oturumu Bitir'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
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

class _LiveThumbnail extends StatelessWidget {
  const _LiveThumbnail({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      width: 54,
      height: 54,
      color: Theme.of(context).colorScheme.secondaryContainer,
      alignment: Alignment.center,
      child: const Icon(Icons.flutter_dash_outlined),
    );
    if (url == null || url!.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: fallback,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url!,
        width: 54,
        height: 54,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _EvidenceMetric extends StatelessWidget {
  const _EvidenceMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _RegionalSupportBadge extends StatelessWidget {
  const _RegionalSupportBadge({
    required this.level,
    required this.contextAvailable,
  });

  final RegionalSupportLevel? level;
  final bool contextAvailable;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color, IconData icon) = !contextAvailable
        ? ('Bağlam yok', Colors.grey, Icons.location_off_outlined)
        : switch (level) {
            RegionalSupportLevel.strong => (
              'Bölgesel destek güçlü',
              Colors.green,
              Icons.verified_outlined,
            ),
            RegionalSupportLevel.moderate => (
              'Bölgesel destek orta',
              Colors.blue,
              Icons.location_on_outlined,
            ),
            RegionalSupportLevel.weak => (
              'Bölgesel destek zayıf',
              Colors.orange,
              Icons.location_on_outlined,
            ),
            RegionalSupportLevel.none ||
            null => ('Güncel kayıt yok', Colors.grey, Icons.help_outline),
          };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
