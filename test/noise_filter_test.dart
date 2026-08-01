import 'dart:math' as math;
import 'dart:typed_data';

import 'package:firbird/audio/fft_util.dart';
import 'package:firbird/audio/noise_filter.dart';
import 'package:firbird/audio/noise_filter_settings.dart';
import 'package:test/test.dart';

/// Generates a synthetic PCM-16 mono buffer at [sampleRate] Hz containing
/// a pure sine wave at [frequency] Hz with amplitude [amplitude] (0.0–1.0).
Uint8List _sinePcm16({
  required double frequency,
  required double sampleRate,
  required double amplitude,
  required int samples,
}) {
  final Uint8List out = Uint8List(samples * 2);
  final ByteData bd = ByteData.sublistView(out);
  for (int i = 0; i < samples; i++) {
    final double v = amplitude * math.sin(2 * math.pi * frequency * i / sampleRate);
    bd.setInt16(i * 2, (v * 32767).round().clamp(-32768, 32767), Endian.little);
  }
  return out;
}

double _rms(Uint8List pcm16) {
  final int n = pcm16.length ~/ 2;
  if (n == 0) return 0;
  final ByteData bd = ByteData.sublistView(pcm16);
  double sum = 0;
  for (int i = 0; i < n; i++) {
    final double s = bd.getInt16(i * 2, Endian.little) / 32768.0;
    sum += s * s;
  }
  return math.sqrt(sum / n);
}

void main() {
  group('NoiseFilterSettings presets', () {
    test('wind preset has HPF cutoff 1000 Hz and no water reduction', () {
      expect(NoiseFilterSettings.presetWind.windCutoffHz, equals(1000));
      expect(NoiseFilterSettings.presetWind.waterReduction, equals(0.0));
      expect(NoiseFilterSettings.presetWind.enabled, isTrue);
    });

    test('water preset has low HPF cutoff and high water reduction', () {
      expect(NoiseFilterSettings.presetWater.windCutoffHz, lessThan(500));
      expect(NoiseFilterSettings.presetWater.waterReduction, greaterThan(0.5));
      expect(NoiseFilterSettings.presetWater.enabled, isTrue);
    });

    test('forest preset is intermediate', () {
      expect(NoiseFilterSettings.presetForest.windCutoffHz, greaterThan(200));
      expect(NoiseFilterSettings.presetForest.windCutoffHz, lessThan(1000));
      expect(NoiseFilterSettings.presetForest.waterReduction, greaterThan(0));
      expect(NoiseFilterSettings.presetForest.waterReduction, lessThan(0.8));
    });

    test('off preset is disabled', () {
      expect(NoiseFilterSettings.off.enabled, isFalse);
    });

    test('spectralAlpha maps water reduction 0→1 to alpha 1→4', () {
      expect(
        NoiseFilterSettings.off.copyWith(waterReduction: 0.0).spectralAlpha,
        closeTo(1.0, 0.01),
      );
      expect(
        NoiseFilterSettings.off.copyWith(waterReduction: 1.0).spectralAlpha,
        closeTo(4.0, 0.01),
      );
    });
  });

  group('FftUtil round-trip', () {
    test('FFT followed by IFFT reconstructs the original signal', () {
      final List<double> real =
          List<double>.generate(512, (i) => math.sin(2 * math.pi * i / 32));
      final List<double> imag = List<double>.filled(512, 0);
      final List<double> original = List<double>.from(real);

      FftUtil.fft(real, imag);
      FftUtil.ifft(real, imag);

      for (int i = 0; i < 512; i++) {
        expect(real[i], closeTo(original[i], 1e-9));
      }
    });
  });

  group('NoiseFilter.apply', () {
    final NoiseFilter filter = NoiseFilter();

    test('returns original bytes when filter is disabled', () {
      final Uint8List pcm =
          _sinePcm16(frequency: 1000, sampleRate: 48000, amplitude: 0.5, samples: 4096);
      final Uint8List result = filter.apply(pcm, NoiseFilterSettings.off);
      expect(identical(result, pcm), isTrue);
    });

    test('HPF at 2000 Hz attenuates 100 Hz tone significantly', () {
      filter.reset();
      final settings = NoiseFilterSettings(
        enabled: true,
        windCutoffHz: 2000,
        waterReduction: 0,
        gainMultiplier: 1.0,
      );
      // 100 Hz tone — should be strongly attenuated
      final Uint8List lowFreq = _sinePcm16(
        frequency: 100,
        sampleRate: 48000,
        amplitude: 0.8,
        samples: 48000 * 3,
      );
      final double rmsBefore = _rms(lowFreq);
      final Uint8List filtered = filter.apply(lowFreq, settings);
      final double rmsAfter = _rms(filtered);
      expect(rmsAfter, lessThan(rmsBefore * 0.1));
    });

    test('HPF at 500 Hz passes 4000 Hz tone with minimal attenuation', () {
      filter.reset();
      final settings = NoiseFilterSettings(
        enabled: true,
        windCutoffHz: 500,
        waterReduction: 0,
        gainMultiplier: 1.0,
      );
      final Uint8List highFreq = _sinePcm16(
        frequency: 4000,
        sampleRate: 48000,
        amplitude: 0.5,
        samples: 48000 * 3,
      );
      final double rmsBefore = _rms(highFreq);
      final Uint8List filtered = filter.apply(highFreq, settings);
      final double rmsAfter = _rms(filtered);
      // Should retain at least 70% of RMS energy
      expect(rmsAfter, greaterThan(rmsBefore * 0.7));
    });

    test('water reduction with broadband noise reduces RMS after adaptation', () {
      filter.reset();
      final settings = NoiseFilterSettings(
        enabled: true,
        windCutoffHz: 100, // minimal HPF
        waterReduction: 0.9,
        gainMultiplier: 1.0,
      );
      // White noise approximation: use Random for broadband content
      final int n = 48000 * 3;
      final Uint8List noise = Uint8List(n * 2);
      final ByteData bd = ByteData.sublistView(noise);
      final rng = math.Random(42);
      for (int i = 0; i < n; i++) {
        final double v = (rng.nextDouble() - 0.5) * 0.6;
        bd.setInt16(i * 2, (v * 32767).round().clamp(-32768, 32767), Endian.little);
      }
      final double rmsBefore = _rms(noise);

      // Warm up the noise floor with many passes so minimum statistics adapts
      for (int i = 0; i < 8; i++) {
        filter.apply(noise, settings);
      }
      final Uint8List filtered = filter.apply(noise, settings);
      final double rmsAfter = _rms(filtered);

      // After full adaptation, spectral subtraction must reduce energy
      expect(rmsAfter, lessThan(rmsBefore),
          reason: 'Spectral subtraction should reduce broadband noise RMS. '
              'Before: $rmsBefore, After: $rmsAfter');
    });
  });
}
