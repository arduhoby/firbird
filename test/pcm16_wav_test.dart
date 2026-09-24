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

  test('scales PCM16 samples using applyPcm16Gain', () {
    final ByteData pcm = ByteData(4);
    pcm.setInt16(0, 1000, Endian.little);
    pcm.setInt16(2, -2000, Endian.little);

    final Uint8List scaled = applyPcm16Gain(pcm.buffer.asUint8List(), 2.0);
    final ByteData result = ByteData.sublistView(scaled);

    expect(result.getInt16(0, Endian.little), 2000);
    expect(result.getInt16(2, Endian.little), -4000);
  });

  test('normalizes low level PCM16 samples using normalizePcm16Gain', () {
    final ByteData pcm = ByteData(2);
    // Peak = 3276 (~ -20 dBFS)
    pcm.setInt16(0, 3276, Endian.little);

    final Uint8List normalized = normalizePcm16Gain(
      pcm.buffer.asUint8List(),
      targetPeakFraction: 0.7071, // ~23170 peak (~ -3 dBFS)
    );
    final ByteData result = ByteData.sublistView(normalized);
    final int newPeak = result.getInt16(0, Endian.little);

    expect(newPeak, closeTo(23170, 100));
  });

  test('normalizes with default 0.95 target and ignores transient outlier clicks', () {
    // 1000 samples: 999 quiet samples at 500, 1 stray click at 20000
    final ByteData pcm = ByteData(2000);
    for (int i = 0; i < 999; i++) {
      pcm.setInt16(i * 2, 500, Endian.little);
    }
    pcm.setInt16(999 * 2, 20000, Endian.little);

    final Uint8List normalized = normalizePcm16Gain(pcm.buffer.asUint8List());
    final ByteData result = ByteData.sublistView(normalized);

    // Without robust estimation, gain would be (31129 / 20000) = 1.55x -> 500 becomes 775.
    // With robust estimation, gain targets 500 up to max 16x -> 500 becomes 8000!
    final int quietSampleResult = result.getInt16(0, Endian.little);
    expect(quietSampleResult, greaterThan(5000));
  });
}


