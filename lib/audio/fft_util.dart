import 'dart:math' as math;
import 'dart:typed_data';

/// Canonical 512-point Cooley-Tukey FFT used by both the audio spectrogram
/// and the noise filter. No other file may duplicate this implementation.
///
/// All functions operate on caller-allocated [Float64List] buffers so no
/// intermediate allocations occur in the inner processing loop.
class FftUtil {
  FftUtil._();

  /// In-place Cooley-Tukey radix-2 DIT FFT.
  /// [real] and [imag] must have the same power-of-two length.
  static void fft(List<double> real, List<double> imag) {
    final int n = real.length;
    assert(n == imag.length && (n & (n - 1)) == 0, 'FFT size must be power of 2');

    // Bit-reversal permutation
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        double tr = real[i];
        real[i] = real[j];
        real[j] = tr;
        tr = imag[i];
        imag[i] = imag[j];
        imag[j] = tr;
      }
    }

    // Butterfly stages
    for (int len = 2; len <= n; len <<= 1) {
      final double angle = -2 * math.pi / len;
      final double wLenR = math.cos(angle);
      final double wLenI = math.sin(angle);
      for (int i = 0; i < n; i += len) {
        double wr = 1;
        double wi = 0;
        for (int k = 0; k < len >> 1; k++) {
          final int even = i + k;
          final int odd = even + (len >> 1);
          final double vr = real[odd] * wr - imag[odd] * wi;
          final double vi = real[odd] * wi + imag[odd] * wr;
          final double ur = real[even];
          final double ui = imag[even];
          real[even] = ur + vr;
          imag[even] = ui + vi;
          real[odd] = ur - vr;
          imag[odd] = ui - vi;
          final double nextWr = wr * wLenR - wi * wLenI;
          wi = wr * wLenI + wi * wLenR;
          wr = nextWr;
        }
      }
    }
  }

  /// Inverse FFT (conjugate → FFT → conjugate → scale by 1/n).
  static void ifft(List<double> real, List<double> imag) {
    final int n = real.length;
    // Conjugate
    for (int i = 0; i < n; i++) {
      imag[i] = -imag[i];
    }
    fft(real, imag);
    // Conjugate and scale
    final double scale = 1.0 / n;
    for (int i = 0; i < n; i++) {
      real[i] *= scale;
      imag[i] = -imag[i] * scale;
    }
  }

  /// Computes the squared magnitude spectrum of the first [n/2] positive
  /// frequencies of an [n]-point FFT result.
  static Float64List powerSpectrum(List<double> real, List<double> imag) {
    final int half = real.length >> 1;
    final Float64List power = Float64List(half);
    for (int k = 0; k < half; k++) {
      power[k] = real[k] * real[k] + imag[k] * imag[k];
    }
    return power;
  }
}
