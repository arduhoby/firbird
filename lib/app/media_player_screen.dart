import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MediaPlayerScreen extends StatefulWidget {
  const MediaPlayerScreen({super.key});

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('org.firbird3.app/media_player');
  String? _fileName;
  bool _isPlaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  Future<void> _chooseAndPlay() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    final String? path = result?.files.single.path;
    if (path == null) return;
    try {
      await _channel.invokeMethod<void>('playLooping', <String, String>{'path': path});
      if (!mounted) return;
      setState(() {
        _fileName = result!.files.single.name;
        _isPlaying = true;
        _error = null;
      });
    } on PlatformException {
      if (mounted) setState(() => _error = 'Ses dosyası oynatılamadı.');
    }
  }

  Future<void> _stop() async {
    await _channel.invokeMethod<void>('stop');
    if (mounted) setState(() => _isPlaying = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.invokeMethod<void>('stop');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Ses oynatıcı'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              await _stop();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(_isPlaying ? Icons.repeat_rounded : Icons.music_note_rounded,
                    size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 18),
                Text(_fileName ?? 'Telefondan bir ses dosyası seçin.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Seçilen ses sürekli çalar. FirBird 3 arka plana geçtiğinde otomatik durur.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
                if (_error != null) Padding(
                  padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 24),
                FilledButton.icon(onPressed: _chooseAndPlay, icon: const Icon(Icons.folder_open_outlined), label: Text(_isPlaying ? 'Başka ses seç' : 'Ses dosyası seç')),
                if (_isPlaying) ...<Widget>[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: _stop, icon: const Icon(Icons.stop_circle_outlined), label: const Text('Durdur')),
                ],
              ],
            ),
          ),
        ),
      );
}
