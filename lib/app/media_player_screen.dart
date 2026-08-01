import 'dart:io';

import 'package:file_picker/file_picker.dart';
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

  DetectionRecord toDetectionRecord(String filePath) {
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
    );
  }
}

class PlaybackSession {
  const PlaybackSession({
    required this.filePath,
    required this.displayName,
    required this.detections,
    this.rareSpeciesCount = 0,
  });

  final String filePath;
  final String displayName;
  final List<PlaybackDetection> detections;
  final int rareSpeciesCount;
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
  List<List<double>> _spectrogram = const <List<double>>[];
  String? _loadError;

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
      if (mounted) setState(() => _spectrogram = const <List<double>>[]);
      return;
    }

    final String resolvedPath = await resolveExistingAudioPath(
      session.filePath,
    );
    final PlaybackSession activeSession = PlaybackSession(
      filePath: resolvedPath,
      displayName: session.displayName,
      detections: session.detections,
      rareSpeciesCount: session.rareSpeciesCount,
    );

    _session = activeSession;
    _controller.attach(resolvedPath);

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

  int? _highlightedIndex(List<PlaybackDetection> detections) {
    if (!_controller.isPlaying || _controller.isPaused || detections.isEmpty) {
      return null;
    }
    for (int i = 0; i < detections.length; i++) {
      final PlaybackDetection detection = detections[i];
      if (_controller.positionMs >= detection.startMs - 800 &&
          _controller.positionMs <= detection.endMs + 800) {
        return i;
      }
    }
    return null;
  }

  String _time(int milliseconds) {
    final int seconds = milliseconds ~/ 1000;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _saveClip() async {
    final PlaybackSession? session = _session;
    if (session == null || session.filePath.isEmpty) return;
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
        startMs: _controller.clipStartMs,
        endMs: _controller.clipEndMs,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Klip kaydedilemedi: $e')),
      );
    }
  }

  Future<void> _shareClip() async {
    final PlaybackSession? session = _session;
    if (session == null || session.filePath.isEmpty) return;
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
        startMs: _controller.clipStartMs,
        endMs: _controller.clipEndMs,
        outputPath: outPath,
      );

      await _shareWavPath(outPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Klip paylaşılamadı: $e')),
      );
    }
  }

  Future<void> _shareWavPath(String wavPath) async {
    await Share.shareXFiles(
      <XFile>[XFile(wavPath, mimeType: 'audio/wav')],
      text: 'FirBird 3 Kuş Sesi Klipi',
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final ThemeData theme = Theme.of(context);
        final PlaybackSession? session = _session;
        final List<PlaybackDetection> detections =
            session?.detections ?? const <PlaybackDetection>[];
        final int? highlightedIndex = _highlightedIndex(detections);
        final List<SpectrogramMarker> markers = detections
            .map(
              (PlaybackDetection item) => SpectrogramMarker(
                position: _controller.durationMs > 0
                    ? item.startMs / _controller.durationMs
                    : 0,
                label: item.turkishName,
              ),
            )
            .toList(growable: false);

        return Scaffold(
          appBar: AppBar(
            title: Text(session?.displayName ?? 'Ses oynatıcı'),
            actions: const <Widget>[AppBarHelpButton()],
          ),
          body: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                child: Column(
                  children: <Widget>[
                    Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        ScrollableAudioSpectrogram(
                          columns: _spectrogram,
                          markers: markers,
                          durationMs: _controller.durationMs,
                          playbackPosition: _controller.durationMs > 0
                              ? _controller.positionMs / _controller.durationMs
                              : null,
                          onSeek: _controller.durationMs == 0
                              ? null
                              : (double value) => _controller.seek(
                                  (_controller.durationMs * value).round(),
                                ),
                          height: 220,
                          secondsPerScreen: 30.0,
                        ),
                        if (session != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton.filledTonal(
                                tooltip: 'Önceki kuş sesi',
                                onPressed: detections.isEmpty
                                    ? null
                                    : () => _controller.jumpTo(
                                        detections.map((item) => item.startMs),
                                        next: false,
                                      ),
                                icon: const Icon(Icons.skip_previous_rounded),
                              ),
                              IconButton.filled(
                                tooltip:
                                    _controller.isPlaying &&
                                        !_controller.isPaused
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
                                    : () => _controller.jumpTo(
                                        detections.map((item) => item.startMs),
                                        next: true,
                                      ),
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
                          _time(_controller.durationMs),
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
              if (_loadError != null || _controller.error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_loadError ?? _controller.error!),
                ),
              if ((session?.rareSpeciesCount ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      avatar: const Icon(Icons.notification_important_outlined),
                      label: Text(
                        '${session!.rareSpeciesCount} nadir tür tespiti',
                      ),
                    ),
                  ),
                ),
              if (_controller.isClipMode)
                Container(
                  color: theme.colorScheme.primaryContainer,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.content_cut,
                        size: 20,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Klip Modu: ${_time(_controller.clipStartMs)} – ${_time(_controller.clipEndMs)}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Klip Kaydet',
                        icon: const Icon(Icons.download_rounded),
                        onPressed: _saveClip,
                      ),
                      IconButton(
                        tooltip: 'Klip Paylaş',
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
              if (detections.isEmpty)
                Expanded(
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
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: detections.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (BuildContext context, int index) {
                      final PlaybackDetection item = detections[index];
                      return BirdDetectionCard(
                        record: item.toDetectionRecord(session!.filePath),
                        isHighlighted: highlightedIndex == index,
                        onSeek: () {
                          final int duration = _controller.durationMs;
                          final int start = (item.startMs - 10000).clamp(0, duration > 0 ? duration : 0);
                          final int end = (item.endMs + 10000).clamp(start + 1000, duration > 0 ? duration : start + 20000);
                          _controller.playClip(clipStartMs: start, clipEndMs: end);
                        },
                      );
                    },
                  ),
                ),
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
      },
    );
  }
}
