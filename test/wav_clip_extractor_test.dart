// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:firbird/audio/wav_clip_extractor.dart';

/// Writes a minimal 44-byte PCM WAV file with [numSamples] int16 samples at
/// [sampleRate] Hz and returns the path.
Future<String> _writeTempWav(
  String name, {
  int sampleRate = 48000,
  int numChannels = 1,
  int numSamples = 48000, // 1 second
}) async {
  final Directory tmp = Directory.systemTemp;
  final String filePath = '${tmp.path}/wav_clip_test_$name.wav';

  final int dataBytes = numSamples * numChannels * 2; // 16-bit
  final Uint8List bytes = Uint8List(44 + dataBytes);
  final ByteData bd = ByteData.sublistView(bytes);

  // RIFF header
  bytes[0] = 0x52; bytes[1] = 0x49; bytes[2] = 0x46; bytes[3] = 0x46;
  bd.setUint32(4, 36 + dataBytes, Endian.little);
  bytes[8] = 0x57; bytes[9] = 0x41; bytes[10] = 0x56; bytes[11] = 0x45;
  bytes[12] = 0x66; bytes[13] = 0x6D; bytes[14] = 0x74; bytes[15] = 0x20;
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little); // PCM
  bd.setUint16(22, numChannels, Endian.little);
  bd.setUint32(24, sampleRate, Endian.little);
  bd.setUint32(28, sampleRate * numChannels * 2, Endian.little);
  bd.setUint16(32, numChannels * 2, Endian.little);
  bd.setUint16(34, 16, Endian.little);
  bytes[36] = 0x64; bytes[37] = 0x61; bytes[38] = 0x74; bytes[39] = 0x61;
  bd.setUint32(40, dataBytes, Endian.little);

  // Fill with ramp signal so we can verify correct slice
  final ByteData samples = ByteData.sublistView(bytes, 44);
  for (int i = 0; i < numSamples * numChannels; i++) {
    samples.setInt16(i * 2, (i % 1000) * 32, Endian.little);
  }

  await File(filePath).writeAsBytes(bytes);
  return filePath;
}

void main() {
  group('WavClipExtractor', () {
    late String sourcePath;
    late String outputPath;

    setUp(() async {
      // 3-second mono 48kHz source
      sourcePath = await _writeTempWav('source', numSamples: 48000 * 3);
      outputPath = '${Directory.systemTemp.path}/wav_clip_test_out.wav';
    });

    tearDown(() {
      for (final String p in <String>[sourcePath, outputPath]) {
        try { File(p).deleteSync(); } catch (_) {}
      }
    });

    test('extract creates a valid WAV file', () async {
      await WavClipExtractor.extract(
        sourcePath,
        startMs: 0,
        endMs: 1000,
        outputPath: outputPath,
      );

      expect(File(outputPath).existsSync(), isTrue);
      final Uint8List out = await File(outputPath).readAsBytes();
      // Must start with RIFF...WAVE
      expect(String.fromCharCodes(out.sublist(0, 4)), equals('RIFF'));
      expect(String.fromCharCodes(out.sublist(8, 12)), equals('WAVE'));
    });

    test('extracted clip has correct approximate duration', () async {
      const int startMs = 500;
      const int endMs = 1500;
      await WavClipExtractor.extract(
        sourcePath,
        startMs: startMs,
        endMs: endMs,
        outputPath: outputPath,
      );

      final int durationMs =
          WavClipExtractor.durationMsFromPath(outputPath);
      // Allow ±50ms rounding tolerance
      expect(durationMs, greaterThanOrEqualTo(950));
      expect(durationMs, lessThanOrEqualTo(1050));
    });

    test('extracted clip is shorter than source', () async {
      await WavClipExtractor.extract(
        sourcePath,
        startMs: 500,
        endMs: 1500,
        outputPath: outputPath,
      );

      final int sourceDuration =
          WavClipExtractor.durationMsFromPath(sourcePath);
      final int clipDuration =
          WavClipExtractor.durationMsFromPath(outputPath);
      expect(clipDuration, lessThan(sourceDuration));
    });

    test('endMs clamped to file end when beyond source length', () async {
      await WavClipExtractor.extract(
        sourcePath,
        startMs: 2000,
        endMs: 9999, // beyond 3-second source
        outputPath: outputPath,
      );

      final int clipDuration =
          WavClipExtractor.durationMsFromPath(outputPath);
      // Should get ~1 second (2000–3000)
      expect(clipDuration, greaterThan(500));
      expect(clipDuration, lessThanOrEqualTo(1100));
    });

    test('throws WavClipException for missing file', () async {
      await expectLater(
        () => WavClipExtractor.extract(
          '/no/such/file.wav',
          startMs: 0,
          endMs: 1000,
          outputPath: outputPath,
        ),
        throwsA(isA<WavClipException>()),
      );
    });

    test('durationMsFromPath returns 0 for non-existent file', () {
      expect(
        WavClipExtractor.durationMsFromPath('/no/such/file.wav'),
        equals(0),
      );
    });

    test('stereo file extracts correctly', () async {
      final String stereoPath =
          await _writeTempWav('stereo', numChannels: 2, numSamples: 96000);
      try {
        await WavClipExtractor.extract(
          stereoPath,
          startMs: 0,
          endMs: 1000,
          outputPath: outputPath,
        );
        final int durationMs =
            WavClipExtractor.durationMsFromPath(outputPath);
        expect(durationMs, closeTo(1000, 50));
      } finally {
        try { File(stereoPath).deleteSync(); } catch (_) {}
      }
    });
  });
}
