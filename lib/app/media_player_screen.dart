import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firbird/app/audio_spectrogram.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlaybackDetection {
  const PlaybackDetection({
    required this.turkishName,
    required this.scientificName,
    required this.startMs,
    required this.endMs,
    required this.confidence,
    this.regionalSupport,
    this.temporalContext,
    this.thumbnailUrl,
  });

  final String turkishName;
  final String scientificName;
  final int startMs;
  final int endMs;
  final int confidence;
  final String? regionalSupport;
  final String? temporalContext;
  final String? thumbnailUrl;
}

class MediaPlayerScreen extends StatefulWidget {
  const MediaPlayerScreen({
    super.key,
    this.initialPath,
    this.initialName,
    this.detections = const <PlaybackDetection>[],
  });

  final String? initialPath;
  final String? initialName;
  final List<PlaybackDetection> detections;

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel(
    'org.firbird3.app/media_player',
  );
  Timer? _timer;
  String? _filePath;
  String? _fileName;
  bool _isPlaying = false;
  bool _paused = false;
  int _positionMs = 0;
  int _durationMs = 0;
  double _gain = 1.0;
  String? _error;
  List<List<double>> _spectrogram = const <List<double>>[];

  /// Şu an oynatma pozisyonuna denk gelen detection indexi
  int? get _highlightedIndex {
    if (!_isPlaying || _paused || widget.detections.isEmpty) return null;
    for (int i = 0; i < widget.detections.length; i++) {
      final PlaybackDetection d = widget.detections[i];
      if (_positionMs >= d.startMs - 800 && _positionMs <= d.endMs + 800) {
        return i;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialPath != null) {
      _load(widget.initialPath!, widget.initialName ?? 'Canlı ses kaydı');
    }
  }

  Future<void> _load(String filePath, String name) async {
    try {
      final spectrum = await WavSpectrogram.analyze(
        filePath,
        maxColumns: 240,
        columnsPerSecond: 8,
      );
      if (!mounted) return;
      setState(() {
        _filePath = filePath;
        _fileName = name;
        _spectrogram = spectrum;
        _error = null;
        _positionMs = 0;
        _durationMs = 0;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Ses dosyası açılamadı.');
    }
  }

  Future<void> _chooseFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final file = result?.files.single;
    if (file?.path != null) await _load(file!.path!, file.name);
  }

  Future<void> _togglePlayback() async {
    if (_filePath == null) return;
    if (_isPlaying) {
      await _channel.invokeMethod<void>(_paused ? 'resume' : 'pause');
      if (mounted) setState(() => _paused = !_paused);
      return;
    }
    try {
      await _channel.invokeMethod<void>('play', <String, dynamic>{
        'path': _filePath,
      });
      await _channel.invokeMethod<void>('setVolume', <String, dynamic>{
        'volume': _gain,
      });
      if (mounted) {
        setState(() {
          _isPlaying = true;
          _paused = false;
        });
      }
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 350), (_) async {
        final data = await _channel.invokeMethod<dynamic>('position');
        if (!mounted || data is! Map) return;
        final int position = (data['positionMs'] as num?)?.toInt() ?? 0;
        final int duration = (data['durationMs'] as num?)?.toInt() ?? 0;
        setState(() {
          _positionMs = position;
          _durationMs = duration;
        });
        if (duration > 0 && position >= duration - 250) await _stop();
      });
    } on PlatformException {
      if (mounted) setState(() => _error = 'Ses oynatılamadı.');
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _channel.invokeMethod<void>('stop');
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _paused = false;
        _positionMs = 0;
      });
    }
  }

  Future<void> _seek(int positionMs) async {
    await _channel.invokeMethod<void>('seekTo', <String, dynamic>{
      'positionMs': positionMs,
    });
    if (mounted) setState(() => _positionMs = positionMs);
  }

  Future<void> _setGain(double value) async {
    setState(() => _gain = value);
    if (_isPlaying) {
      await _channel.invokeMethod<void>('setVolume', <String, dynamic>{
        'volume': value,
      });
    }
  }

  Future<void> _jumpToDetection({required bool next}) async {
    if (widget.detections.isEmpty) return;
    final List<int> points =
        widget.detections
            .map((PlaybackDetection item) => item.startMs)
            .toSet()
            .toList()
          ..sort();
    final int target = next
        ? points.firstWhere(
            (int point) => point > _positionMs + 500,
            orElse: () => points.first,
          )
        : points.lastWhere(
            (int point) => point < _positionMs - 500,
            orElse: () => points.first,
          );
    if (!_isPlaying) await _togglePlayback();
    await _seek(target);
  }

  String _time(int ms) {
    final int seconds = ms ~/ 1000;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _channel.invokeMethod<void>('stop');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? highlightedIdx = _highlightedIndex;
    final List<SpectrogramMarker> markers = widget.detections
        .map(
          (PlaybackDetection item) => SpectrogramMarker(
            position: _durationMs > 0 ? item.startMs / _durationMs : 0,
            label: item.turkishName,
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Canlı oturum kaydı')),
      body: Column(
        children: <Widget>[
          // ── Spektrogram + Kontroller ───────────────────────────────
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
                      playbackPosition: _durationMs > 0
                          ? _positionMs / _durationMs
                          : null,
                      onSeek: _durationMs == 0
                          ? null
                          : (value) => _seek((_durationMs * value).round()),
                      height: 220,
                      pixelsPerColumn: 4.0,
                    ),
                    if (_filePath != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton.filledTonal(
                            tooltip: 'Önceki kuş sesi',
                            onPressed: widget.detections.isEmpty
                                ? null
                                : () => _jumpToDetection(next: false),
                            icon: const Icon(Icons.skip_previous_rounded),
                          ),
                          IconButton.filled(
                            onPressed: _togglePlayback,
                            iconSize: 38,
                            icon: Icon(
                              _isPlaying && !_paused
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Sonraki kuş sesi',
                            onPressed: widget.detections.isEmpty
                                ? null
                                : () => _jumpToDetection(next: true),
                            icon: const Icon(Icons.skip_next_rounded),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Text(_time(_positionMs), style: theme.textTheme.labelSmall),
                    const Spacer(),
                    Text(
                      _fileName ?? 'Ses dosyası seçin',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                    const Spacer(),
                    Text(_time(_durationMs), style: theme.textTheme.labelSmall),
                  ],
                ),
                Row(
                  children: <Widget>[
                    const Icon(Icons.volume_down_rounded, size: 18),
                    Expanded(
                      child: Slider(
                        min: 0.5,
                        max: 4.0,
                        divisions: 14,
                        value: _gain,
                        label: '%${(_gain * 100).round()}',
                        onChanged: _setGain,
                      ),
                    ),
                    SizedBox(
                      width: 54,
                      child: Text(
                        '%${(_gain * 100).round()}',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),

          // ── Kuş Listesi ───────────────────────────────────────────
          if (widget.detections.isEmpty)
            Expanded(
              child: Center(
                child: FilledButton.icon(
                  onPressed: _chooseFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Ses dosyası seç'),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemCount: widget.detections.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (BuildContext context, int index) {
                  final PlaybackDetection item = widget.detections[index];
                  final bool isHighlighted = highlightedIdx == index;
                  return _PlaybackDetectionTile(
                    item: item,
                    isHighlighted: isHighlighted,
                    onTap: () => _seek(item.startMs),
                    timeLabel:
                        '${_time(item.startMs)}–${_time(item.endMs)}',
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Kuş Kartı — LiveAudioRecordingScreen ile aynı görünüm ────────────────────

class _PlaybackDetectionTile extends StatelessWidget {
  const _PlaybackDetectionTile({
    required this.item,
    required this.isHighlighted,
    required this.onTap,
    required this.timeLabel,
  });

  final PlaybackDetection item;
  final bool isHighlighted;
  final VoidCallback onTap;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color borderColor = isHighlighted
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
    final Color bgColor = isHighlighted
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
        : theme.colorScheme.surface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: isHighlighted ? 2.0 : 1.0,
        ),
        boxShadow: isHighlighted
            ? <BoxShadow>[
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              // Thumbnail
              _PlayerThumbnail(url: item.thumbnailUrl),
              const SizedBox(width: 12),
              // Bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.turkishName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isHighlighted
                            ? theme.colorScheme.primary
                            : null,
                      ),
                    ),
                    Text(
                      item.scientificName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        _SmallBadge(
                          label: '%${item.confidence}',
                          color: _confidenceColor(item.confidence, theme),
                        ),
                        if (item.regionalSupport != null)
                          _SmallBadge(
                            label: item.regionalSupport!,
                            color: theme.colorScheme.secondary,
                          ),
                        if (item.temporalContext != null)
                          _SmallBadge(
                            label: item.temporalContext!,
                            color: theme.colorScheme.tertiary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Zaman aralığı + atla
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    timeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.play_circle_outline,
                    size: 20,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _confidenceColor(int confidence, ThemeData theme) {
    if (confidence >= 75) return Colors.green.shade600;
    if (confidence >= 50) return Colors.orange.shade700;
    return Colors.red.shade600;
  }
}

class _PlayerThumbnail extends StatelessWidget {
  const _PlayerThumbnail({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.flutter_dash_outlined, size: 24),
    );
    if (url == null || url!.isEmpty) {
      return ClipRRect(borderRadius: BorderRadius.circular(10), child: fallback);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url!,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}
