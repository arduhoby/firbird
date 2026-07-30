import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class MediaPlaybackGateway {
  Future<void> play(String filePath);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seekTo(int positionMs);
  Future<void> setVolume(double volume);
  Future<({int positionMs, int durationMs})> position();
}

class MethodChannelMediaPlaybackGateway implements MediaPlaybackGateway {
  MethodChannelMediaPlaybackGateway({MethodChannel? channel})
    : _channel = channel ?? _mediaChannel;

  static const MethodChannel _mediaChannel = MethodChannel(
    'org.firbird3.app/media_player',
  );

  final MethodChannel _channel;

  @override
  Future<void> play(String filePath) async {
    try {
      await _channel.invokeMethod<void>('play', <String, dynamic>{
        'path': filePath,
      });
    } on PlatformException {
      // Compatibility with native builds that still expose the former method.
      await _channel.invokeMethod<void>('playLooping', <String, dynamic>{
        'path': filePath,
      });
    }
  }

  @override
  Future<void> pause() => _channel.invokeMethod<void>('pause');

  @override
  Future<void> resume() => _channel.invokeMethod<void>('resume');

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  Future<void> seekTo(int positionMs) => _channel.invokeMethod<void>(
    'seekTo',
    <String, dynamic>{'positionMs': positionMs},
  );

  @override
  Future<void> setVolume(double volume) => _channel.invokeMethod<void>(
    'setVolume',
    <String, dynamic>{'volume': volume},
  );

  @override
  Future<({int positionMs, int durationMs})> position() async {
    final dynamic result = await _channel.invokeMethod<dynamic>('position');
    if (result is! Map) return (positionMs: 0, durationMs: 0);
    return (
      positionMs: (result['positionMs'] as num?)?.toInt() ?? 0,
      durationMs: (result['durationMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class MediaPlayerController extends ChangeNotifier {
  MediaPlayerController({MediaPlaybackGateway? gateway})
    : _gateway = gateway ?? MethodChannelMediaPlaybackGateway();

  final MediaPlaybackGateway _gateway;
  Timer? _pollTimer;
  String? _filePath;
  bool _isPlaying = false;
  bool _isPaused = false;
  int _positionMs = 0;
  int _durationMs = 0;
  double _gain = 1;
  String? _error;
  bool _disposed = false;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  int get positionMs => _positionMs;
  int get durationMs => _durationMs;
  double get gain => _gain;
  String? get error => _error;

  void attach(String? filePath) {
    if (_filePath == filePath) return;
    _filePath = filePath;
    _positionMs = 0;
    _durationMs = 0;
    _error = null;
    notifyListeners();
  }

  Future<void> toggle() async {
    if (_filePath == null) return;
    try {
      if (_isPlaying) {
        if (_isPaused) {
          await _gateway.resume();
        } else {
          await _gateway.pause();
        }
        _isPaused = !_isPaused;
        _notify();
        return;
      }
      await _gateway.play(_filePath!);
      await _gateway.setVolume(_gain);
      _isPlaying = true;
      _isPaused = false;
      _error = null;
      _notify();
      _startPolling();
    } on PlatformException catch (error) {
      _error = 'Ses oynatılamadı: ${error.message ?? error.code}';
      _notify();
    }
  }

  Future<void> stop() async {
    _pollTimer?.cancel();
    try {
      await _gateway.stop();
    } on PlatformException catch (error) {
      _error = 'Oynatma durdurulamadı: ${error.message ?? error.code}';
    }
    _isPlaying = false;
    _isPaused = false;
    _positionMs = 0;
    _notify();
  }

  Future<void> seek(int positionMs) async {
    if (_filePath == null) return;
    await _gateway.seekTo(positionMs);
    _positionMs = positionMs;
    _notify();
  }

  Future<void> setGain(double value) async {
    _gain = value;
    _notify();
    if (_isPlaying) await _gateway.setVolume(value);
  }

  Future<void> jumpTo(Iterable<int> points, {required bool next}) async {
    final List<int> sorted = points.toSet().toList()..sort();
    if (sorted.isEmpty) return;
    final int target = next
        ? sorted.firstWhere(
            (int point) => point > _positionMs + 500,
            orElse: () => sorted.first,
          )
        : sorted.lastWhere(
            (int point) => point < _positionMs - 500,
            orElse: () => sorted.first,
          );
    if (!_isPlaying) await toggle();
    await seek(target);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 350), (_) async {
      try {
        final state = await _gateway.position();
        if (_disposed) return;
        _positionMs = state.positionMs;
        _durationMs = state.durationMs;
        _notify();
        // Native preparation may briefly report not-playing. Completion is
        // decided only from a real duration and the current position.
        if (_isPlaying &&
            !_isPaused &&
            _durationMs > 0 &&
            _positionMs >= _durationMs - 250) {
          await stop();
        }
      } on PlatformException catch (error) {
        _error = 'Oynatma bilgisi alınamadı: ${error.message ?? error.code}';
        _notify();
      }
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    unawaited(_gateway.stop());
    super.dispose();
  }
}
