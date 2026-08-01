import 'dart:math' as math;
import 'dart:typed_data';

import 'package:firbird/audio/fft_util.dart';
import 'package:firbird/audio/noise_filter_settings.dart';

/// Real-time noise filter chain applied to 48 kHz mono PCM-16 audio buffers
/// before they are fed into the BirdNET ONNX model.
///
/// The chain has three stages:
///   1. Biquad IIR High-Pass Filter  — removes low-frequency wind noise.
///   2. Spectral Subtraction         — removes broadband noise (water/stream).
///   3. RMS Gain Normalization       — boosts faint bird calls.
///
/// A single [NoiseFilter] instance should be created per live-recording
/// session and disposed afterwards (it holds a noise-floor estimate that
/// adapts over time).
class NoiseFilter {
  NoiseFilter();

  // ── Internal state ────────────────────────────────────────────────────────

  final _BiquadHpf _hpf = _BiquadHpf();
  final _SpectralSubtractor _spectral = _SpectralSubtractor();

  double _lastCutoff = -1;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Applies the configured filter chain to [pcm16] (raw little-endian PCM-16
  /// at 48 kHz mono) and returns a new, filtered [Uint8List].
  ///
  /// If [settings.enabled] is false the original [pcm16] is returned unchanged
  /// (zero allocation).
  Uint8List apply(Uint8List pcm16, NoiseFilterSettings settings) {
    if (!settings.enabled) return pcm16;

    final Float64List samples = _pcm16ToFloat64(pcm16);

    // Stage 1: High-pass filter (wind)
    if (settings.windCutoffHz > 0) {
      if (_lastCutoff != settings.windCutoffHz) {
        _hpf.configure(settings.windCutoffHz, 48000);
        _lastCutoff = settings.windCutoffHz;
      }
      _hpf.process(samples);
    }

    // Stage 2: Spectral subtraction (water / broadband)
    if (settings.waterReduction > 0.0) {
      _spectral.process(samples, alpha: settings.spectralAlpha);
    }

    // Stage 3: RMS gain normalization
    if (settings.gainMultiplier != 1.0) {
      _rmsNormalize(samples, settings.gainMultiplier);
    }

    return _float64ToPcm16(samples);
  }

  /// Resets the adaptive noise-floor state. Call when starting a new
  /// recording session.
  void reset() {
    _hpf.reset();
    _spectral.reset();
    _lastCutoff = -1;
  }

  // ── Conversion helpers ────────────────────────────────────────────────────

  static Float64List _pcm16ToFloat64(Uint8List pcm16) {
    final int n = pcm16.length ~/ 2;
    final ByteData bd = ByteData.sublistView(pcm16);
    final Float64List out = Float64List(n);
    for (int i = 0; i < n; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  static Uint8List _float64ToPcm16(Float64List samples) {
    final Uint8List out = Uint8List(samples.length * 2);
    final ByteData bd = ByteData.sublistView(out);
    for (int i = 0; i < samples.length; i++) {
      final int v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      bd.setInt16(i * 2, v, Endian.little);
    }
    return out;
  }

  static void _rmsNormalize(Float64List samples, double targetMultiplier) {
    if (samples.isEmpty) return;
    double sumSq = 0;
    for (final double s in samples) {
      sumSq += s * s;
    }
    final double rms = math.sqrt(sumSq / samples.length);
    if (rms < 1e-9) return; // silence — no boost
    // Scale so that gain = targetMultiplier but clamp to avoid clipping
    final double gain = (targetMultiplier / rms * 0.1).clamp(0.1, 4.0);
    for (int i = 0; i < samples.length; i++) {
      samples[i] = (samples[i] * gain).clamp(-1.0, 1.0);
    }
  }
}

// ── Stage 1: Biquad High-Pass Filter ─────────────────────────────────────────
//
// Direct Form II Transposed 2nd-order IIR filter.
// Q = 1/√2 ≈ 0.7071 (Butterworth maximally flat response).

class _BiquadHpf {
  double _b0 = 0, _b1 = 0, _b2 = 0;
  double _a1 = 0, _a2 = 0;
  double _z1 = 0, _z2 = 0;

  void configure(double cutoffHz, double sampleRate) {
    const double q = 0.7071; // Butterworth
    final double w0 = 2 * math.pi * cutoffHz / sampleRate;
    final double cosW0 = math.cos(w0);
    final double alpha = math.sin(w0) / (2 * q);
    final double a0inv = 1.0 / (1 + alpha);

    _b0 = ((1 + cosW0) / 2) * a0inv;
    _b1 = -(1 + cosW0) * a0inv;
    _b2 = _b0;
    _a1 = -2 * cosW0 * a0inv;
    _a2 = (1 - alpha) * a0inv;
  }

  void process(Float64List samples) {
    for (int i = 0; i < samples.length; i++) {
      final double x = samples[i];
      final double y = _b0 * x + _z1;
      _z1 = _b1 * x - _a1 * y + _z2;
      _z2 = _b2 * x - _a2 * y;
      samples[i] = y;
    }
  }

  void reset() {
    _z1 = 0;
    _z2 = 0;
  }
}

// ── Stage 2: Spectral Subtraction ─────────────────────────────────────────────
//
// Overlap-add spectral subtraction with adaptive noise floor estimation.
//
//   |S(k)|² = max( |X(k)|² − α · |N(k)|²,  β² · |X(k)|² )
//
// where α is the oversubtraction factor (1–4, set from waterReduction slider)
// and β = 0.05 is the spectral floor that preserves residual bird harmonics.
//
// The noise estimate |N(k)|² is the running minimum of the power spectrum over
// the last [_historyFrames] frames, updated every frame.

class _SpectralSubtractor {
  static const int _fftSize = 512;
  static const int _hop = 256;
  static const double _beta = 0.05; // spectral floor coefficient
  static const int _historyFrames = 30; // ~1.6 s at hop=256 / 48 kHz

  final Float64List _noiseFloor = Float64List(_fftSize >> 1);
  // Circular history of power spectra for minimum tracking
  final List<Float64List> _history = List<Float64List>.generate(
    _historyFrames,
    (_) => Float64List(_fftSize >> 1),
  );
  int _historyIndex = 0;
  int _framesProcessed = 0;

  // Pre-allocated working buffers (avoids GC pressure in the audio loop)
  final List<double> _real = List<double>.filled(_fftSize, 0);
  final List<double> _imag = List<double>.filled(_fftSize, 0);

  void process(Float64List samples, {required double alpha}) {
    final int half = _fftSize >> 1;
    // Overlap-add output accumulator (same length as input)
    final Float64List output = Float64List(samples.length);
    final Float64List window = _hannWindow(_fftSize);

    int frameStart = 0;
    while (frameStart + _fftSize <= samples.length) {
      // Windowed frame → FFT
      for (int i = 0; i < _fftSize; i++) {
        _real[i] = samples[frameStart + i] * window[i];
        _imag[i] = 0;
      }
      FftUtil.fft(_real, _imag);

      // Power spectrum of this frame
      final Float64List power = Float64List(half);
      for (int k = 0; k < half; k++) {
        power[k] = _real[k] * _real[k] + _imag[k] * _imag[k];
      }

      // Update noise floor history and compute minimum estimate
      _history[_historyIndex] = power;
      _historyIndex = (_historyIndex + 1) % _historyFrames;
      _framesProcessed++;

      final int validFrames = math.min(_framesProcessed, _historyFrames);
      for (int k = 0; k < half; k++) {
        double minPow = _history[0][k];
        for (int f = 1; f < validFrames; f++) {
          if (_history[f][k] < minPow) minPow = _history[f][k];
        }
        _noiseFloor[k] = minPow;
      }

      // Spectral subtraction: apply gain to each bin
      for (int k = 0; k < half; k++) {
        final double signal2 = power[k];
        final double noise2 = _noiseFloor[k];
        final double floor2 = _beta * _beta * signal2;
        final double enhanced2 = math.max(signal2 - alpha * noise2, floor2);
        // Gain = sqrt(enhanced / signal) applied to complex spectrum
        final double gain =
            signal2 > 1e-30 ? math.sqrt(enhanced2 / signal2) : 1.0;
        _real[k] *= gain;
        _imag[k] *= gain;
        // Mirror bins
        if (k > 0 && k < half) {
          _real[_fftSize - k] *= gain;
          _imag[_fftSize - k] *= gain;
        }
      }

      // IFFT → overlap-add
      FftUtil.ifft(_real, _imag);
      for (int i = 0; i < _fftSize; i++) {
        final int outIdx = frameStart + i;
        if (outIdx < output.length) {
          output[outIdx] += _real[i] * window[i];
        }
      }

      frameStart += _hop;
    }

    // Hann window with 50% overlap satisfies the COLA condition (sum = 1.0),
    // so no additional scaling is required after overlap-add.
    const double olaScale = 1.0;
    for (int i = 0; i < output.length; i++) {
      samples[i] = (output[i] * olaScale).clamp(-1.0, 1.0);
    }
  }

  void reset() {
    _framesProcessed = 0;
    _historyIndex = 0;
    _noiseFloor.fillRange(0, _noiseFloor.length, 0);
    for (final Float64List f in _history) {
      f.fillRange(0, f.length, 0);
    }
  }

  static final Map<int, Float64List> _windowCache = {};
  static Float64List _hannWindow(int size) {
    return _windowCache.putIfAbsent(size, () {
      final Float64List w = Float64List(size);
      for (int i = 0; i < size; i++) {
        w[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (size - 1));
      }
      return w;
    });
  }
}
