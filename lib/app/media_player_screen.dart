import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MediaPlayerScreen extends StatefulWidget {
  const MediaPlayerScreen({super.key, this.initialPath, this.initialName});

  final String? initialPath;
  final String? initialName;

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel(
    'org.firbird3.app/media_player',
  );
  Timer? _timer;
  String? _fileName;
  bool _isPlaying = false;
  bool _paused = false;
  int _positionMs = 0;
  int _durationMs = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialPath != null) {
      _play(widget.initialPath!, widget.initialName ?? 'Canlı ses kaydı');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  Future<void> _chooseAndPlay() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final file = result?.files.single;
    if (file?.path == null) return;
    await _play(file!.path!, file.name);
  }

  Future<void> _play(String filePath, String name) async {
    try {
      await _channel.invokeMethod<void>('play', <String, dynamic>{
        'path': filePath,
      });
      if (!mounted) return;
      setState(() {
        _fileName = name;
        _isPlaying = true;
        _paused = false;
        _error = null;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 400), (_) async {
        final data = await _channel.invokeMethod<dynamic>('position');
        if (!mounted || data is! Map) return;
        setState(() {
          _positionMs = (data['positionMs'] as num?)?.toInt() ?? 0;
          _durationMs = (data['durationMs'] as num?)?.toInt() ?? 0;
        });
      });
    } on PlatformException catch (e) {
      if (mounted)
        setState(() => _error = 'Ses dosyası oynatılamadı: ${e.message ?? ''}');
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _channel.invokeMethod<void>('stop');
    if (mounted)
      setState(() {
        _isPlaying = false;
        _paused = false;
      });
  }

  Future<void> _togglePause() async {
    await _channel.invokeMethod<void>(_paused ? 'resume' : 'pause');
    if (mounted) setState(() => _paused = !_paused);
  }

  String _time(int ms) {
    final seconds = ms ~/ 1000;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _channel.invokeMethod<void>('stop');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ses oynatıcı')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPlaying ? Icons.volume_up_rounded : Icons.music_note_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              _fileName ?? 'Bir ses dosyası seçin.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!),
              ),
            if (_isPlaying) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(_time(_positionMs)),
                  Expanded(
                    child: Slider(
                      min: 0,
                      max: (_durationMs > 0 ? _durationMs : 1).toDouble(),
                      value: _positionMs
                          .clamp(0, _durationMs > 0 ? _durationMs : 1)
                          .toDouble(),
                      onChanged: _durationMs == 0
                          ? null
                          : (value) => _channel.invokeMethod<void>('seekTo', {
                              'positionMs': value.round(),
                            }),
                    ),
                  ),
                  Text(_time(_durationMs)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    onPressed: _togglePause,
                    icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Durdur'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _chooseAndPlay,
              icon: const Icon(Icons.folder_open),
              label: const Text('Ses dosyası seç'),
            ),
          ],
        ),
      ),
    ),
  );
}
