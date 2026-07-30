import 'package:firbird/app/media_player_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'one controller owns play pause seek gain and detection jumps',
    () async {
      final _FakeGateway gateway = _FakeGateway();
      final MediaPlayerController controller = MediaPlayerController(
        gateway: gateway,
      );
      addTearDown(controller.dispose);

      controller.attach('session.wav');
      await controller.toggle();
      expect(controller.isPlaying, isTrue);
      expect(gateway.playedPath, 'session.wav');

      await controller.toggle();
      expect(controller.isPaused, isTrue);
      expect(gateway.pauseCalls, 1);

      await controller.toggle();
      expect(controller.isPaused, isFalse);
      expect(gateway.resumeCalls, 1);

      await controller.seek(2000);
      await controller.jumpTo(<int>[1000, 5000, 9000], next: true);
      expect(controller.positionMs, 5000);
      expect(gateway.seekPositions, <int>[2000, 5000]);

      await controller.setGain(2.5);
      expect(controller.gain, 2.5);
      expect(gateway.volumes.last, 2.5);
    },
  );
}

class _FakeGateway implements MediaPlaybackGateway {
  String? playedPath;
  int pauseCalls = 0;
  int resumeCalls = 0;
  final List<int> seekPositions = <int>[];
  final List<double> volumes = <double>[];

  @override
  Future<void> play(String filePath) async => playedPath = filePath;

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> resume() async => resumeCalls++;

  @override
  Future<void> stop() async {}

  @override
  Future<void> seekTo(int positionMs) async => seekPositions.add(positionMs);

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<({int durationMs, int positionMs})> position() async =>
      (positionMs: 0, durationMs: 10000);
}
