import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firbird/audio/audio_evidence_assessment.dart';
import 'package:firbird/audio/audio_evidence_clip_policy.dart';
import 'package:firbird/app/audio_spectrogram.dart';
import 'package:firbird/app/app_bar_help_button.dart';
import 'package:firbird/app/bird_detection_card.dart';
import 'package:firbird/app/media_player_controller.dart';
import 'package:firbird/detection/detection_record.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:firbird/audio/wav_clip_extractor.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String> resolveExistingAudioPath(String? rawPath) async {
  if (rawPath == null || rawPath.trim().isEmpty) return '';
  final String trimmed = rawPath.trim();
  if (File(trimmed).existsSync()) return trimmed;

  final String fileName = path.basename(trimmed);
  try {
    final Directory appDocs = await getApplicationDocumentsDirectory();
    final String docsPath = path.join(appDocs.path, fileName);
    if (File(docsPath).existsSync()) return docsPath;

    final Directory tempDir = await getTemporaryDirectory();
    final String tempPath = path.join(tempDir.path, fileName);
    if (File(tempPath).existsSync()) return tempPath;
  } catch (_) {}

  return trimmed;
}

class PlaybackDetection {
  const PlaybackDetection({
    required this.speciesId,
    required this.turkishName,
    required this.scientificName,
    required this.startMs,
    required this.endMs,
    required this.modelConfidence,
    this.repeatedHits = 1,
    this.repetitionSupportPerHit = 0,
    this.regionalSupport,
    this.temporalContext,
    this.thumbnailUrl,
    this.detectedAt,
    this.latitude,
    this.longitude,
    this.modelVersion,
    this.statusCategory,
    this.audioEvidence,
    this.audioReviewVerdict,
  });

  final String speciesId;
  final String turkishName;
  final String scientificName;
  final int startMs;
  final int endMs;
  final double modelConfidence;
  final int repeatedHits;
  final int repetitionSupportPerHit;
  final String? regionalSupport;
  final String? temporalContext;
  final String? thumbnailUrl;
  final DateTime? detectedAt;
  final double? latitude;
  final double? longitude;
  final String? modelVersion;
  final SpeciesStatusCategory? statusCategory;
  final AudioEvidenceAssessment? audioEvidence;
  final AudioReviewVerdict? audioReviewVerdict;

  DetectionRecord toDetectionRecord(
    String filePath, {
    AudioReviewVerdict? audioReviewVerdict,
  }) {
    DateTime resolvedAt = detectedAt ?? DateTime.now();
    if (detectedAt == null) {
      try {
        resolvedAt = File(
          filePath,
        ).lastModifiedSync().add(Duration(milliseconds: startMs));
      } catch (_) {}
    }
    return DetectionRecord(
      id: '$filePath|$speciesId|$startMs',
      speciesId: speciesId,
      turkishName: turkishName,
      scientificName: scientificName,
      modelConfidence: modelConfidence,
      detectedAt: resolvedAt,
      source: DetectionSource.replay,
      statusCategory:
          statusCategory ??
          SpeciesStatusHelper.getCategory(scientificName: scientificName),
      modelVersion: modelVersion ?? 'BirdNET replay',
      thumbnailUrl: thumbnailUrl,
      audioUri: filePath,
      audioStartMs: startMs,
      audioEndMs: endMs,
      latitude: latitude,
      longitude: longitude,
      repeatedHits: repeatedHits,
      repetitionSupportPerHit: repetitionSupportPerHit,
      audioEvidence: audioEvidence,
      audioReviewVerdict: audioReviewVerdict ?? this.audioReviewVerdict,
      regionalSupport: regionalSupport,
      temporalContext: temporalContext,
    );
  }
}

List<PlaybackDetection> collapsePlaybackDetectionsBySpecies(
  Iterable<PlaybackDetection> detections,
) {
  final Map<String, PlaybackDetection> unique = <String, PlaybackDetection>{};
  for (final PlaybackDetection candidate in detections) {
    final String key = candidate.scientificName.trim().toLowerCase();
    final PlaybackDetection? current = unique[key];
    if (current == null || _isBetterSpeciesEvidence(candidate, current)) {
      unique[key] = candidate;
    }
  }
  return unique.values.toList(growable: false);
}

bool _isBetterSpeciesEvidence(
  PlaybackDetection candidate,
  PlaybackDetection current,
) {
  if (candidate.audioReviewVerdict != null &&
      current.audioReviewVerdict == null) {
    return true;
  }
  if (candidate.audioReviewVerdict == null &&
      current.audioReviewVerdict != null) {
    return false;
  }
  final int candidatePriority = candidate.audioEvidence?.priority ?? -1;
  final int currentPriority = current.audioEvidence?.priority ?? -1;
  if (candidatePriority != currentPriority) {
    return candidatePriority > currentPriority;
  }
  return candidate.modelConfidence > current.modelConfidence;
}

class PlaybackSession {
  const PlaybackSession({
    required this.filePath,
    required this.displayName,
    required this.detections,
    this.rareSpeciesCount = 0,
    this.onAudioReview,
  });

  final String filePath;
  final String displayName;
  final List<PlaybackDetection> detections;
  final int rareSpeciesCount;
  final Future<void> Function(
    PlaybackDetection detection,
    AudioReviewVerdict verdict,
  )?
  onAudioReview;
}

class MediaPlayerScreen extends StatefulWidget {
  const MediaPlayerScreen({
    super.key,
    this.session,
    this.onClose,
    this.onSaveCopy,
  });

  final PlaybackSession? session;
  final VoidCallback? onClose;
  final Future<void> Function()? onSaveCopy;

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen>
    with WidgetsBindingObserver {
  late final MediaPlayerController _controller;
  PlaybackSession? _session;
  final Map<String, AudioReviewVerdict> _audioReviews =
      <String, AudioReviewVerdict>{};
  List<List<double>> _spectrogram = const <List<double>>[];
  String? _loadError;
  int _timelineDurationMs = 0;
  int? _selectedDetectionIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MediaPlayerController();
    _setSession(widget.session);
  }

  @override
  void didUpdateWidget(covariant MediaPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) _setSession(widget.session);
  }

  Future<void> _setSession(PlaybackSession? session) async {
    if (session == null) {
      _session = null;
      _controller.attach(null);
      if (mounted) {
        setState(() {
          _spectrogram = const <List<double>>[];
          _timelineDurationMs = 0;
          _selectedDetectionIndex = null;
        });
      }
      return;
    }

    final String resolvedPath = await resolveExistingAudioPath(
      session.filePath,
    );
    final PlaybackSession activeSession = PlaybackSession(
      filePath: resolvedPath,
      displayName: session.displayName,
      detections: collapsePlaybackDetectionsBySpecies(session.detections),
      rareSpeciesCount: session.rareSpeciesCount,
      onAudioReview: session.onAudioReview,
    );

    _session = activeSession;
    _controller.attach(resolvedPath);
    _timelineDurationMs = WavClipExtractor.durationMsFromPath(resolvedPath);
    _selectedDetectionIndex = activeSession.detections.isEmpty ? null : 0;

    if (resolvedPath.isNotEmpty && !File(resolvedPath).existsSync()) {
      if (!mounted || _session != activeSession) return;
      setState(
        () => _loadError =
            'Ses dosyası bulunamadı: ${path.basename(resolvedPath)}',
      );
      return;
    }

    try {
      final List<List<double>> spectrum = await WavSpectrogram.analyze(
        resolvedPath,
        maxColumns: 24000,
        columnsPerSecond: 8,
      );
      if (!mounted || _session != activeSession) return;
      setState(() {
        _spectrogram = spectrum;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted || _session != activeSession) return;
      setState(() => _loadError = 'Ses dosyası açılamadı: $error');
    }
  }

  Future<void> _chooseFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    final PlatformFile? file = result?.files.single;
    if (file?.path == null) return;
    await _setSession(
      PlaybackSession(
        filePath: file!.path!,
        displayName: file.name,
        detections: const <PlaybackDetection>[],
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _playDetection(int index) async {
    final PlaybackSession? session = _session;
    if (session == null || index < 0 || index >= session.detections.length) {
      return;
    }
    final PlaybackDetection detection = session.detections[index];
    if (mounted) setState(() => _selectedDetectionIndex = index);
    final int durationMs = _timelineDurationMs > 0
        ? _timelineDurationMs
        : _controller.durationMs;
    final ({int startMs, int endMs}) clip = AudioEvidenceClipPolicy.modelWindow(
      detectionStartMs: detection.startMs,
      durationMs: durationMs,
    );
    await _controller.playClip(
      clipStartMs: clip.startMs,
      clipEndMs: clip.endMs,
    );
  }

  Future<void> _jumpDetection({required bool next}) async {
    final List<PlaybackDetection> detections =
        _session?.detections ?? const <PlaybackDetection>[];
    if (detections.isEmpty) return;
    final int current = _selectedDetectionIndex ?? 0;
    final int target = next
        ? (current + 1) % detections.length
        : (current - 1 + detections.length) % detections.length;
    await _playDetection(target);
  }

  String _audioReviewKey(String filePath, PlaybackDetection detection) =>
      '$filePath|${detection.speciesId}|${detection.startMs}';

  Future<void> _setAudioReview(
    PlaybackSession session,
    PlaybackDetection detection,
    AudioReviewVerdict verdict,
  ) async {
    final String key = _audioReviewKey(session.filePath, detection);
    setState(() => _audioReviews[key] = verdict);
    try {
      await session.onAudioReview?.call(detection, verdict);
    } catch (error) {
      if (!mounted) return;
      setState(() => _audioReviews.remove(key));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ses değerlendirmesi kaydedilemedi: $error')),
      );
    }
  }

  String _time(int milliseconds) {
    final int seconds = milliseconds ~/ 1000;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }

  ({int startMs, int endMs})? _selectedEvidenceWindow() {
    final PlaybackSession? session = _session;
    final int? index = _selectedDetectionIndex;
    if (session == null ||
        index == null ||
        index < 0 ||
        index >= session.detections.length) {
      return null;
    }
    final int durationMs = _timelineDurationMs > 0
        ? _timelineDurationMs
        : _controller.durationMs;
    return AudioEvidenceClipPolicy.evidenceWindow(
      detectionStartMs: session.detections[index].startMs,
      durationMs: durationMs,
    );
  }

  Future<void> _saveClip() async {
    final PlaybackSession? session = _session;
    final ({int startMs, int endMs})? evidence = _selectedEvidenceWindow();
    if (session == null || session.filePath.isEmpty || evidence == null) return;
    try {
      final Directory docsDir = await getApplicationDocumentsDirectory();
      final Directory clipDir = Directory(path.join(docsDir.path, 'Clips'));
      if (!clipDir.existsSync()) clipDir.createSync(recursive: true);

      final String timestampStr = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final String fileName = 'klip_$timestampStr.wav';
      final String outPath = path.join(clipDir.path, fileName);

      await WavClipExtractor.extract(
        session.filePath,
        startMs: evidence.startMs,
        endMs: evidence.endMs,
        outputPath: outPath,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Klip kaydedildi: $fileName'),
          action: SnackBarAction(
            label: 'Paylaş',
            onPressed: () => _shareWavPath(outPath),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Klip kaydedilemedi: $e')));
    }
  }

  Future<void> _shareClip() async {
    final PlaybackSession? session = _session;
    final ({int startMs, int endMs})? evidence = _selectedEvidenceWindow();
    if (session == null || session.filePath.isEmpty || evidence == null) return;
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String timestampStr = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final String fileName = 'firbird_klip_$timestampStr.wav';
      final String outPath = path.join(tempDir.path, fileName);

      await WavClipExtractor.extract(
        session.filePath,
        startMs: evidence.startMs,
        endMs: evidence.endMs,
        outputPath: outPath,
      );

      await _shareWavPath(outPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Klip paylaşılamadı: $e')));
    }
  }

  Future<void> _shareWavPath(String wavPath) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(wavPath, mimeType: 'audio/wav')],
        text: 'firbird4 Kuş Sesi Klipi',
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PlaybackSession? session = _session;
    final List<PlaybackDetection> detections =
        session?.detections ?? const <PlaybackDetection>[];
    final int durationMs = _timelineDurationMs > 0
        ? _timelineDurationMs
        : _controller.durationMs;
    final List<SpectrogramMarker> markers = detections
        .map(
          (PlaybackDetection item) => SpectrogramMarker(
            position: durationMs > 0 ? item.startMs / durationMs : 0,
            label: item.turkishName,
          ),
        )
        .toList(growable: false);
    final int? selectedIndex =
        _selectedDetectionIndex != null &&
            _selectedDetectionIndex! < detections.length
        ? _selectedDetectionIndex
        : null;
    final List<DetectionRecord> detectionRecords = detections
        .map((PlaybackDetection item) {
          final AudioReviewVerdict? reviewVerdict =
              _audioReviews[_audioReviewKey(session!.filePath, item)] ??
              item.audioReviewVerdict;
          return item.toDetectionRecord(
            session.filePath,
            audioReviewVerdict: reviewVerdict,
          );
        })
        .toList(growable: false);
    final Widget staticSpectrogram = ScrollableAudioSpectrogram(
      columns: _spectrogram,
      markers: markers,
      durationMs: durationMs > 0 ? durationMs : null,
      playbackPositionListenable: _controller.playbackProgress,
      onSeek: durationMs <= 0
          ? null
          : (double value) => _controller.seek((durationMs * value).round()),
      height: 60,
      secondsPerScreen: 30.0,
    );

    final Widget detectionBody = detections.isEmpty
        ? Expanded(
            child: Center(
              child: session == null
                  ? FilledButton.icon(
                      onPressed: _chooseFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Ses dosyası seç'),
                    )
                  : const Text('Bu oturumda kuş tespiti bulunmuyor.'),
            ),
          )
        : Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: BirdDetectionDeck(
                      records: detectionRecords,
                      focusedIndex: selectedIndex ?? 0,
                      height: constraints.maxHeight,
                      onFocusChanged: (int index) =>
                          setState(() => _selectedDetectionIndex = index),
                      onSeek: _playDetection,
                      onAudioReview: session!.onAudioReview == null
                          ? null
                          : (int index, AudioReviewVerdict verdict) =>
                                _setAudioReview(
                                  session,
                                  detections[index],
                                  verdict,
                                ),
                    ),
                  ),
            ),
          );

    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(session?.displayName ?? 'Ses oynatıcı'),
        actions: const <Widget>[AppBarHelpButton()],
      ),
      body: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.55,
            ),
            child: AnimatedBuilder(
              animation: _controller,
              child: staticSpectrogram,
              builder: (BuildContext context, Widget? spectrogram) => Column(
                children: <Widget>[
                  Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      spectrogram!,
                      if (session != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton.filledTonal(
                              tooltip: 'Önceki kuş sesi',
                              onPressed: detections.isEmpty
                                  ? null
                                  : () => _jumpDetection(next: false),
                              icon: const Icon(Icons.skip_previous_rounded),
                            ),
                            IconButton.filled(
                              tooltip:
                                  _controller.isPlaying && !_controller.isPaused
                                  ? 'Duraklat'
                                  : 'Oynat',
                              onPressed: _controller.toggle,
                              iconSize: 38,
                              icon: Icon(
                                _controller.isPlaying && !_controller.isPaused
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Sonraki kuş sesi',
                              onPressed: detections.isEmpty
                                  ? null
                                  : () => _jumpDetection(next: true),
                              icon: const Icon(Icons.skip_next_rounded),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Text(
                        _time(_controller.positionMs),
                        style: theme.textTheme.labelSmall,
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          session?.displayName ?? 'Ses dosyası seçin',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _time(
                          _controller.durationMs > 0
                              ? _controller.durationMs
                              : durationMs,
                        ),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.volume_down_rounded, size: 18),
                      Expanded(
                        child: Slider(
                          min: 0.5,
                          max: 4,
                          divisions: 14,
                          value: _controller.gain,
                          label: '%${(_controller.gain * 100).round()}',
                          onChanged: _controller.setGain,
                        ),
                      ),
                      SizedBox(
                        width: 54,
                        child: Text(
                          '%${(_controller.gain * 100).round()}',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, _) {
              final String? error = _loadError ?? _controller.error;
              return error == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(error),
                    );
            },
          ),
          if ((session?.rareSpeciesCount ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: const Icon(Icons.notification_important_outlined),
                  label: Text('${session!.rareSpeciesCount} nadir tür tespiti'),
                ),
              ),
            ),
          AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, _) => !_controller.isClipMode
                ? const SizedBox.shrink()
                : Container(
                    color: theme.colorScheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.graphic_eq,
                          size: 20,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Modelin dinlediği 3 saniye: '
                            '${_time(_controller.clipStartMs)} – '
                            '${_time(_controller.clipEndMs)}\n'
                            'Kaydet / paylaş: 10 sn öncesi + 10 sn sonrası',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Klibi kaydet',
                          icon: const Icon(Icons.download_rounded),
                          onPressed: _saveClip,
                        ),
                        IconButton(
                          tooltip: 'Klibi paylaş',
                          icon: const Icon(Icons.share_rounded),
                          onPressed: _shareClip,
                        ),
                        IconButton(
                          tooltip: 'Klip Modundan Çık',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _controller.clearClipMode,
                        ),
                      ],
                    ),
                  ),
          ),
          detectionBody,
          if (widget.onClose != null || widget.onSaveCopy != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: <Widget>[
                    if (widget.onClose != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close),
                          label: const Text('Kapat'),
                        ),
                      ),
                    if (widget.onClose != null && widget.onSaveCopy != null)
                      const SizedBox(width: 12),
                    if (widget.onSaveCopy != null)
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: widget.onSaveCopy,
                          icon: const Icon(Icons.save_alt_outlined),
                          label: const Text('Farklı adla kaydet'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
