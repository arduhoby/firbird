import 'dart:typed_data';

import 'package:firbird/audio/pcm16_wav.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips PCM16 through a WAV container', () {
    final Uint8List pcm = Uint8List.fromList(<int>[0, 0, 255, 127, 0, 128]);
    final Pcm16WavData? parsed = parsePcm16Wav(buildPcm16Wav(pcm));

    expect(parsed, isNotNull);
    expect(parsed!.sampleRate, 48000);
    expect(parsed.channels, 1);
    expect(parsed.pcmBytes, orderedEquals(pcm));
  });

  test('finds PCM data after an additional RIFF metadata chunk', () {
    final Uint8List pcm = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final Uint8List normal = buildPcm16Wav(pcm);
    final BytesBuilder builder = BytesBuilder(copy: false)
      ..add(normal.sublist(0, 36))
      ..add('JUNK'.codeUnits)
      ..add(<int>[4, 0, 0, 0])
      ..add(<int>[9, 8, 7, 6])
      ..add(normal.sublist(36));
    final Uint8List withMetadata = builder.takeBytes();
    ByteData.sublistView(
      withMetadata,
    ).setUint32(4, withMetadata.length - 8, Endian.little);

    final Pcm16WavData? parsed = parsePcm16Wav(withMetadata);
    expect(parsed, isNotNull);
    expect(parsed!.pcmBytes, orderedEquals(pcm));
  });
}
