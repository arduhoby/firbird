import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
  bool _isAnalyzing = false;
  int _secondsRecorded = 0;
  Timer? _timer;
  Timer? _analysisTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  String? _recordingPath;

  double _currentDb = -60.0;
  final List<double> _waveformBars = List<double>.filled(16, 0.1);

  final List<LiveDetectionEntry> _detectedSpeciesList = <LiveDetectionEntry>[];

  @override
  void initState() {
    super.initState();
    _startLiveRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _analysisTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startLiveRecording() async {
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

      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = path.join(
        tempDir.path,
        'live_session_${DateTime.now().millisecondsSinceEpoch}.wav',
      );

      final Directory targetDir = await getApplicationDocumentsDirectory();
      final String modelPath = path.join(targetDir.path, 'firbird_test_model', 'birdnet.onnx');
      final String labelsPath = path.join(targetDir.path, 'firbird_test_model', 'birdnet_labels.txt');
      _audioEngine = AudioInferenceEngine(modelPath: modelPath, labelsPath: labelsPath);
      await _audioEngine!.warmUp();

      // Use WAV format for real-time stream readability without file locks
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 48000,
          numChannels: 1,
        ),
        path: tempPath,
      );

      // Amplitude listener for live visual equalizer & audio detection
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

      if (!mounted) return;

      setState(() {
        _isRecording = true;
        _recordingPath = tempPath;
        _secondsRecorded = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _secondsRecorded++;
          });
        }
      });

      // Analyze rolling live WAV audio every 3 seconds
      _analysisTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        _runLiveInference();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Canlı kayıt başlatılamadı: $e')),
        );
      }
    }
  }

  Future<void> _runLiveInference() async {
    if (_recordingPath == null || _isAnalyzing || _audioEngine == null) return;
    final File currentFile = File(_recordingPath!);
    if (!await currentFile.exists() || await currentFile.length() < 20000) return;

    setState(() => _isAnalyzing = true);

    try {
      final InferenceResult result = await _audioEngine!.identify(
        ImageInput(uri: currentFile.path),
        IdentificationContext(
          countryCode: 'TR',
          observationDate: DateTime.now(),
        ),
      );

      if (result.predictions.isNotEmpty && mounted) {
        final DateTime now = DateTime.now();
        bool listChanged = false;

        for (final SpeciesPrediction pred in result.predictions) {
          // Sensitivity threshold for live detection (10%)
          if (pred.score < 0.10) continue;

          // Filter non-birds or poultry if needed (e.g. Gallus gallus)
          if (pred.scientificName.toLowerCase().contains('gallus gallus')) continue;

          final int existingIdx = _detectedSpeciesList.indexWhere(
            (item) => item.prediction.speciesId == pred.speciesId ||
                      item.prediction.scientificName.toLowerCase() == pred.scientificName.toLowerCase(),
          );

          if (existingIdx != -1) {
            final LiveDetectionEntry existing = _detectedSpeciesList[existingIdx];
            existing.lastDetectedAt = now;
            existing.detectionCount++;
            listChanged = true;
          } else {
            // New species detected in session!
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

        if (listChanged && mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Live inference exception: $e');
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _stopAndSaveSession() async {
    _timer?.cancel();
    _analysisTimer?.cancel();
    _amplitudeSubscription?.cancel();

    try {
      final String? finalPath = await _audioRecorder.stop();
      if (finalPath == null || !mounted || _audioEngine == null) return;

      // Final analysis pass
      final InferenceResult finalResult = await _audioEngine!.identify(
        ImageInput(uri: finalPath),
        IdentificationContext(
          countryCode: 'TR',
          observationDate: DateTime.now(),
        ),
      );

      // Auto-name file with detected species names
      final String timeStr = DateFormat('dd MMMM HH.mm', 'tr_TR').format(DateTime.now());
      String newFileName;

      if (_detectedSpeciesList.isNotEmpty) {
        final List<String> names = _detectedSpeciesList
            .take(3)
            .map((e) => e.prediction.turkishName)
            .toList();
        newFileName = '${names.join(", ")} - $timeStr.wav';
      } else if (finalResult.predictions.isNotEmpty && finalResult.predictions.first.score > 0.10) {
        newFileName = '${finalResult.predictions.first.turkishName} - $timeStr.wav';
      } else {
        newFileName = 'Canlı Ses Kaydı - $timeStr.wav';
      }

      final Directory appDocs = await getApplicationDocumentsDirectory();
      final String destPath = path.join(appDocs.path, newFileName);
      await File(finalPath).copy(destPath);

      if (!mounted) return;

      final List<SpeciesPrediction> combinedPredictions = _detectedSpeciesList.isNotEmpty
          ? _detectedSpeciesList.map((e) => e.prediction).toList()
          : finalResult.predictions;

      final InferenceResult sessionResult = InferenceResult(
        predictions: combinedPredictions,
        modelVersion: 'BirdNET-ONNX-v2.4 (Canlı Oturum)',
        locationAffectedResult: false,
        dateAffectedResult: false,
        sourceImageUri: destPath,
        sexAge: finalResult.sexAge,
      );

      context.pushReplacement('/result', extra: sessionResult);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt kaydedilemedi: $e')),
        );
      }
    }
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
          // Dynamic Equalizer & Listening Header Bar
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
                          Icons.mic,
                          color: hasSound ? Colors.green : theme.colorScheme.primary,
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
                              if (_isAnalyzing)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else if (hasSound)
                                const Icon(Icons.graphic_eq, color: Colors.green, size: 20)
                              else
                                const Icon(Icons.mic_none, color: Colors.grey, size: 18),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isAnalyzing
                                ? 'Canlı analiz yapılıyor...'
                                : hasSound
                                    ? '🎙️ Ses Algılandı! (Analiz ediliyor)'
                                    : 'Ortam dinleniyor... (Sessiz)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: hasSound ? FontWeight.bold : FontWeight.normal,
                              color: hasSound ? Colors.green : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Real-time Visualizer Equalizer Bar Graph
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

          const SizedBox(height: 16),

          // Live Detected Species List Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CANLI TESPİT EDİLEN TÜRLER',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  '${_detectedSpeciesList.length} Kuş',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

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
                            'Kuş sesleri bekleniyor...',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ötüş veya çağrı sesi duyulduğunda canlı listede otomatik belirecektir.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _detectedSpeciesList.length,
                    itemBuilder: (context, index) {
                      final item = _detectedSpeciesList[index];
                      final pred = item.prediction;
                      final timeStr = DateFormat('HH:mm:ss').format(item.lastDetectedAt);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: index == 0 ? 3 : 1,
                        color: index == 0
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surface,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: index == 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondaryContainer,
                            foregroundColor: index == 0 ? Colors.white : theme.colorScheme.onSecondaryContainer,
                            child: const Icon(Icons.flutter_dash),
                          ),
                          title: Text(
                            pred.turkishName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: index == 0 ? theme.colorScheme.onPrimaryContainer : null,
                            ),
                          ),
                          subtitle: Text(
                            '${pred.scientificName} · %${(pred.score * 100).toInt()} doğruluk',
                            style: TextStyle(
                              fontSize: 12,
                              color: index == 0
                                  ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                                  : null,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                timeStr,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${item.detectionCount}x duyuldu',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
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

          // Bottom Action Panel
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
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isRecording ? _stopAndSaveSession : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Oturumu Bitir & İncele'),
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
