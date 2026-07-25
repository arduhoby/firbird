import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firbird/app/audio_spectrogram.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlaybackDetection {
  const PlaybackDetection({
    required this.turkishName,
    required this.scientificName,
    required this.startSeconds,
    required this.confidence,
    this.count = 1,
  });

  final String turkishName;
  final String scientificName;
  final int startSeconds;
  final int confidence;
  final int count;

  factory PlaybackDetection.fromHistory({
    required String turkishName,
    required String scientificName,
    required String confidenceText,
    String? predictionMethod,
  }) {
    final List<String> parts = confidenceText.split('·');
    final int confidence = int.tryParse(
          parts.first.replaceAll('%', '').trim(),
        ) ??
        0;
    final RegExpMatch? time = RegExp(r'(\d+):(\d+)').firstMatch(
      parts.length > 1 ? parts.last : '',
    );
    final int seconds = time == null
        ? 0
        : (int.parse(time.group(1)!) * 60 + int.parse(time.group(2)!));
    final int count = int.tryParse(
          (predictionMethod ?? '').replaceFirst('count:', ''),
        ) ??
        1;
    return PlaybackDetection(
      turkishName: turkishName,
      scientificName: scientificName,
      startSeconds: seconds,
      confidence: confidence,
      count: count,
    );
  }
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
      final spectrum = await WavSpectrogram.analyze(filePath, maxColumns: 240);
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
      await _channel.invokeMethod<void>('play', <String, dynamic>{'path': _filePath});
      await _channel.invokeMethod<void>('setVolume', <String, dynamic>{'volume': _gain});
      if (mounted) setState(() { _isPlaying = true; _paused = false; });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 350), (_) async {
        final data = await _channel.invokeMethod<dynamic>('position');
        if (!mounted || data is! Map) return;
        final int position = (data['positionMs'] as num?)?.toInt() ?? 0;
        final int duration = (data['durationMs'] as num?)?.toInt() ?? 0;
        setState(() { _positionMs = position; _durationMs = duration; });
        if (duration > 0 && position >= duration - 250) await _stop();
      });
    } on PlatformException {
      if (mounted) setState(() => _error = 'Ses oynatılamadı.');
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _channel.invokeMethod<void>('stop');
    if (mounted) setState(() { _isPlaying = false; _paused = false; _positionMs = 0; });
  }

  Future<void> _seek(int positionMs) async {
    await _channel.invokeMethod<void>('seekTo', <String, dynamic>{'positionMs': positionMs});
    if (mounted) setState(() => _positionMs = positionMs);
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
    final theme = Theme.of(context);
    final markers = widget.detections.map((item) => SpectrogramMarker(
      position: _durationMs > 0 ? item.startSeconds * 1000 / _durationMs : 0,
      label: item.turkishName,
    )).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Canlı oturum kaydı')),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          child: Column(children: [
            Stack(alignment: Alignment.center, children: [
              AudioSpectrogram(
                columns: _spectrogram,
                markers: markers,
                playbackPosition: _durationMs > 0 ? _positionMs / _durationMs : null,
                onSeek: _durationMs == 0 ? null : (value) => _seek((_durationMs * value).round()),
                height: 150,
              ),
              if (_filePath != null)
                IconButton.filled(
                  onPressed: _togglePlayback,
                  iconSize: 38,
                  icon: Icon(_isPlaying && !_paused ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Text(_time(_positionMs), style: theme.textTheme.labelSmall),
              const Spacer(),
              Text(_fileName ?? 'Ses dosyası seçin', overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
              const Spacer(),
              Text(_time(_durationMs), style: theme.textTheme.labelSmall),
            ]),
          ]),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
        if (widget.detections.isEmpty)
          Expanded(child: Center(child: FilledButton.icon(onPressed: _chooseFile, icon: const Icon(Icons.folder_open), label: const Text('Ses dosyası seç'))))
        else Expanded(child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: widget.detections.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = widget.detections[index];
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _seek(item.startSeconds * 1000),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.45))),
                child: Row(children: [
                  Icon(Icons.graphic_eq, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.turkishName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text(item.scientificName, style: theme.textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic)),
                    if (item.count > 1) Text('${item.count}× duyuldu', style: theme.textTheme.labelSmall),
                  ])),
                  Text('${(item.startSeconds ~/ 60).toString().padLeft(2, '0')}:${(item.startSeconds % 60).toString().padLeft(2, '0')}', style: theme.textTheme.labelLarge),
                ]),
              ),
            );
          },
        )),
      ]),
    );
  }
}
