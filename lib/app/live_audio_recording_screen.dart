import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:firbird/data/app_database.dart';
import 'package:firbird/inference/audio_inference_engine.dart';
import 'package:firbird/inference/bird_inference_engine.dart';

class LiveDetectionEntry {
  LiveDetectionEntry({
    required this.prediction,
    required this.firstDetectedAt,
    required this.lastDetectedAt,
    this.detectionCount = 1,
  });

  final SpeciesPrediction prediction;
  final DateTime firstDetectedAt;
  DateTime lastDetectedAt;
  int detectionCount;
}

class LiveAudioRecordingScreen extends ConsumerStatefulWidget {
  const LiveAudioRecordingScreen({super.key});

  @override
  ConsumerState<LiveAudioRecordingScreen> createState() => _LiveAudioRecordingScreenState();
}

class _LiveAudioRecordingScreenState extends ConsumerState<LiveAudioRecordingScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  AudioInferenceEngine? _audioEngine;

  bool _isRecording = false;
  bool _isSegmentRecording = false;
  bool _isEngineReady = false;
  bool _isSessionEnded = false;
  String _statusText = 'Model yükleniyor...';
  int _secondsRecorded = 0;
  int _segmentCount = 0;
  Timer? _clockTimer;
  Timer? _segmentTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  String? _savedFilePath;
  DateTime? _sessionStartTime;

  // Full-session WAV recorder (for saving)
  final AudioRecorder _fullSessionRecorder = AudioRecorder();
  String? _fullSessionPath;

  double _currentDb = -60.0;
  final List<double> _waveformBars = List<double>.filled(16, 0.1);
  final List<LiveDetectionEntry> _detectedSpeciesList = <LiveDetectionEntry>[];

  /// Loaded from settings — minimum confidence to show in live table (0.0 = all)
  double _liveMinScore = 0.0;

  @override
  void initState() {
    super.initState();
    _initAndStart();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _segmentTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _audioRecorder.dispose();
    _fullSessionRecorder.dispose();
    super.dispose();
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

      // Load live detection min score from settings
      _liveMinScore = await ref.read(appDatabaseProvider).liveDetectionMinScore();

      // Initialize and warm up the audio engine first
      final Directory targetDir = await getApplicationDocumentsDirectory();
      final String modelPath = path.join(targetDir.path, 'firbird_test_model', 'birdnet.onnx');
      final String labelsPath = path.join(targetDir.path, 'firbird_test_model', 'birdnet_labels.txt');
      _audioEngine = AudioInferenceEngine(modelPath: modelPath, labelsPath: labelsPath);

      if (mounted) setState(() => _statusText = 'Model hazırlanıyor (62 MB)...');
      try {
        await _audioEngine!.warmUp();
      } catch (e) {
        debugPrint('AudioEngine warmUp failed: $e');
        if (mounted) setState(() => _statusText = 'Model yüklenemedi: $e');
        return;
      }

      if (!mounted) return;

      // Start full-session recording (for saving at end)
      final Directory tempDir = await getTemporaryDirectory();
      _fullSessionPath = path.join(tempDir.path, 'live_full_${DateTime.now().millisecondsSinceEpoch}.wav');
      await _fullSessionRecorder.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 48000, numChannels: 1),
        path: _fullSessionPath!,
      );

      // Amplitude listener for equalizer
      _amplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen((amp) {
        if (mounted) {
          final double db = amp.current;
          final double normalized = ((db + 50) / 50).clamp(0.08, 1.0);
          setState(() {
            _currentDb = db;
            _waveformBars.removeAt(0);
            _waveformBars.add(normalized);
          });
        }
      });

      setState(() {
        _isRecording = true;
        _isEngineReady = true;
        _sessionStartTime = DateTime.now();
        _statusText = 'Ortam dinleniyor...';
      });

      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _secondsRecorded++);
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
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 48000, numChannels: 1),
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

      // Immediately start next segment (parallel to analysis)
      if (_isRecording && mounted) {
        _startNextSegment();
      }

      // Analyze the completed segment
      await _analyzeSegment(filePath);

      // Clean up temp segment file
      try {
        final File f = File(filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    } catch (e) {
      debugPrint('Segment stop/analyze error: $e');
      _isSegmentRecording = false;
      if (_isRecording && mounted) _startNextSegment();
    }
  }

  Future<void> _analyzeSegment(String filePath) async {
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

      for (final SpeciesPrediction pred in result.predictions) {
        // Apply minimum confidence filter from settings
        if (pred.score < _liveMinScore) continue;
        if (pred.score < 0.05) continue; // absolute floor
        // Skip domestic poultry
        if (pred.scientificName.toLowerCase().contains('gallus gallus')) continue;

        final int existingIdx = _detectedSpeciesList.indexWhere(
          (item) =>
              item.prediction.speciesId == pred.speciesId ||
              item.prediction.scientificName.toLowerCase() == pred.scientificName.toLowerCase(),
        );

        if (existingIdx != -1) {
          // Already in list — update count and time, bubble to top
          final LiveDetectionEntry existing = _detectedSpeciesList.removeAt(existingIdx);
          existing.lastDetectedAt = now;
          existing.detectionCount++;
          _detectedSpeciesList.insert(0, existing);
          listChanged = true;
        } else {
          // New species — insert at top
          _detectedSpeciesList.insert(
            0,
            LiveDetectionEntry(
              prediction: pred,
              firstDetectedAt: now,
              lastDetectedAt: now,
            ),
          );
          listChanged = true;
        }
      }

      if (listChanged && mounted) setState(() {});
    } catch (e) {
      debugPrint('Segment inference error: $e');
    } finally {
      if (mounted) {
        final bool hasSound = _currentDb > -45.0;
        setState(() => _statusText = hasSound ? '🎙️ Ses algılandı' : 'Dinleniyor...');
      }
    }
  }

  Future<void> _stopSession() async {
    _clockTimer?.cancel();
    _segmentTimer?.cancel();
    _amplitudeSubscription?.cancel();

    setState(() {
      _isRecording = false;
      _statusText = 'Oturum kaydediliyor...';
    });

    try {
      // Stop segment recorder if active
      if (_isSegmentRecording) {
        try { await _audioRecorder.stop(); } catch (_) {}
        _isSegmentRecording = false;
      }

      // Stop full session recorder
      final String? finalPath = await _fullSessionRecorder.stop();
      if (finalPath == null || !mounted) {
        setState(() => _isSessionEnded = true);
        return;
      }

      // Save with auto-name
      final String timeStr = DateFormat('dd MMMM HH.mm', 'tr_TR').format(DateTime.now());
      String newFileName;
      if (_detectedSpeciesList.isNotEmpty) {
        final List<String> names = _detectedSpeciesList.take(3).map((e) => e.prediction.turkishName).toList();
        newFileName = '${names.join(', ')} - $timeStr.wav';
      } else {
        newFileName = 'Canlı Ses Kaydı - $timeStr.wav';
      }

      final Directory appDocs = await getApplicationDocumentsDirectory();
      final String destPath = path.join(appDocs.path, newFileName);
      await File(finalPath).copy(destPath);

      // Update last detection times with session end
      final DateTime sessionEnd = DateTime.now();
      for (final entry in _detectedSpeciesList) {
        if (entry.lastDetectedAt.isAfter(sessionEnd)) {
          entry.lastDetectedAt = sessionEnd;
        }
      }

      // Save each detected species to history
      if (_detectedSpeciesList.isNotEmpty) {
        final bool historyEnabled = await ref.read(appDatabaseProvider).isHistoryEnabled();
        if (historyEnabled) {
          // Use session start timestamp as shared group key
          final String sessionId = 'live_${(_sessionStartTime ?? DateTime.now()).millisecondsSinceEpoch}';
          final String sessionLabel = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(_sessionStartTime ?? DateTime.now());
          for (final entry in _detectedSpeciesList) {
            final String timeRange = _relativeTimeRange(entry);
            await ref.read(appDatabaseProvider).addIdentification(
              speciesId: entry.prediction.speciesId,
              turkishName: entry.prediction.turkishName,
              scientificName: entry.prediction.scientificName,
              confidence: '%${(entry.prediction.score * 100).round()} · $timeRange',
              modelVersion: '🎙️ Canlı Oturum · $sessionLabel',
              imageUri: destPath,
              packageId: sessionId,
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isSessionEnded = true;
        _savedFilePath = destPath;
        _statusText = 'Oturum tamamlandı';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isSessionEnded = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt hatası: $e')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasSound = _currentDb > -45.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canlı Ses Tespit Modu'),
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
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: hasSound ? 64 : 56,
                          height: hasSound ? 64 : 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasSound
                                ? Colors.green.withValues(alpha: 0.3)
                                : theme.colorScheme.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        Icon(
                          _isSessionEnded ? Icons.mic_off : Icons.mic,
                          color: _isEngineReady
                              ? (hasSound ? Colors.green : theme.colorScheme.primary)
                              : theme.colorScheme.error,
                          size: 28,
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _formatDuration(_secondsRecorded),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: [const FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (!_isSessionEnded && _isEngineReady)
                                hasSound
                                    ? const Icon(Icons.graphic_eq, color: Colors.green, size: 20)
                                    : const Icon(Icons.mic_none, color: Colors.grey, size: 18),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _statusText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: (hasSound || !_isEngineReady) ? FontWeight.bold : FontWeight.normal,
                              color: _isEngineReady
                                  ? (hasSound ? Colors.green : theme.colorScheme.onSurfaceVariant)
                                  : theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Equalizer bars
                SizedBox(
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(_waveformBars.length, (i) {
                      final val = _waveformBars[i];
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: 6,
                        height: 36 * val,
                        decoration: BoxDecoration(
                          color: val > 0.4
                              ? Colors.green
                              : val > 0.2
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
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
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
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
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      children: [
                        // Table header
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'TÜR',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onPrimaryContainer,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'ZAMAN ARALIĞI',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onPrimaryContainer,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    'TAH. ORAN',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onPrimaryContainer,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Table rows
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _detectedSpeciesList.length,
                            separatorBuilder: (context, _) => Divider(
                              height: 1,
                              color: theme.colorScheme.outlineVariant,
                            ),
                            itemBuilder: (context, index) {
                              final item = _detectedSpeciesList[index];
                              final pred = item.prediction;
                              final int pct = (pred.score * 100).round();
                              final Color pctColor = pct >= 70
                                  ? Colors.green
                                  : pct >= 40
                                      ? Colors.orange
                                      : Colors.red;

                              return Container(
                                color: index.isEven
                                    ? theme.colorScheme.surface
                                    : theme.colorScheme.surfaceContainerLowest,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pred.turkishName,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              pred.scientificName,
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                            if (item.detectionCount > 1)
                                              Text(
                                                '${item.detectionCount}× duyuldu',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          _relativeTimeRange(item),
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            fontFeatures: [const FontFeature.tabularFigures()],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 72,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: pctColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
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
                              );
                            },
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
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.close),
                          label: const Text('Kapat'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () {
                            if (_savedFilePath != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Kaydedildi: ${path.basename(_savedFilePath!)}'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Kaydedildi ✓'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
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
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
