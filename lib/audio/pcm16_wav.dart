import 'dart:math' as math;
import 'dart:typed_data';

class Pcm16WavData {
  const Pcm16WavData({
    required this.pcmBytes,
    required this.sampleRate,
    required this.channels,
  });

  final Uint8List pcmBytes;
  final int sampleRate;
  final int channels;
}

Uint8List pcm16WavHeader({
  required int pcmByteLength,
  int sampleRate = 48000,
  int channels = 1,
}) {
  const int bitsPerSample = 16;
  final int blockAlign = channels * bitsPerSample ~/ 8;
  final int byteRate = sampleRate * blockAlign;
  final ByteData header = ByteData(44);

  void ascii(int offset, String value) {
    for (int index = 0; index < value.length; index++) {
      header.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcmByteLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, blockAlign, Endian.little);
  header.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, pcmByteLength, Endian.little);
  return header.buffer.asUint8List();
}

Uint8List buildPcm16Wav(
  Uint8List pcmBytes, {
  int sampleRate = 48000,
  int channels = 1,
}) {
  final BytesBuilder output = BytesBuilder(copy: false)
    ..add(
      pcm16WavHeader(
        pcmByteLength: pcmBytes.length,
        sampleRate: sampleRate,
        channels: channels,
      ),
    )
    ..add(pcmBytes);
  return output.takeBytes();
}

/// Reads PCM16 data by walking RIFF chunks instead of assuming a 44-byte WAV
/// header. This supports valid WAV files containing LIST/JUNK metadata chunks.
Pcm16WavData? parsePcm16Wav(Uint8List bytes) {
  if (bytes.length < 12 ||
      _ascii(bytes, 0, 4) != 'RIFF' ||
      _ascii(bytes, 8, 4) != 'WAVE') {
    return null;
  }

  final ByteData data = ByteData.sublistView(bytes);
  int audioFormat = 0;
  int channels = 0;
  int sampleRate = 0;
  int bitsPerSample = 0;
  int? dataOffset;
  int? dataLength;
  int offset = 12;

  while (offset + 8 <= bytes.length) {
    final String chunkId = _ascii(bytes, offset, 4);
    final int chunkLength = data.getUint32(offset + 4, Endian.little);
    final int payloadOffset = offset + 8;
    if (payloadOffset + chunkLength > bytes.length) break;

    if (chunkId == 'fmt ' && chunkLength >= 16) {
      audioFormat = data.getUint16(payloadOffset, Endian.little);
      channels = data.getUint16(payloadOffset + 2, Endian.little);
      sampleRate = data.getUint32(payloadOffset + 4, Endian.little);
      bitsPerSample = data.getUint16(payloadOffset + 14, Endian.little);
    } else if (chunkId == 'data') {
      dataOffset = payloadOffset;
      dataLength = chunkLength;
      break;
    }

    offset = payloadOffset + chunkLength + (chunkLength.isOdd ? 1 : 0);
  }

  if (audioFormat != 1 ||
      bitsPerSample != 16 ||
      channels < 1 ||
      sampleRate < 1 ||
      dataOffset == null ||
      dataLength == null) {
    return null;
  }

  return Pcm16WavData(
    pcmBytes: Uint8List.sublistView(bytes, dataOffset, dataOffset + dataLength),
    sampleRate: sampleRate,
    channels: channels,
  );
}

String _ascii(Uint8List bytes, int offset, int length) =>
    String.fromCharCodes(bytes.sublist(offset, offset + length));

/// Scales 16-bit PCM little-endian audio samples by [gainMultiplier].
/// Samples above 30000 amplitude use smooth soft-saturation to avoid harsh clipping.
Uint8List applyPcm16Gain(Uint8List pcmBytes, double gainMultiplier) {
  if (gainMultiplier == 1.0 || pcmBytes.length < 2) return pcmBytes;
  final int sampleCount = pcmBytes.length ~/ 2;
  final ByteData src = ByteData.sublistView(pcmBytes);
  final Uint8List outBytes = Uint8List(sampleCount * 2);
  final ByteData dst = ByteData.sublistView(outBytes);

  for (int i = 0; i < sampleCount; i++) {
    final int sample = src.getInt16(i * 2, Endian.little);
    final double scaled = sample * gainMultiplier;
    final int result;
    if (scaled > 30000) {
      final double excess = scaled - 30000;
      result = (30000 + 2767 * (excess / (excess + 2767))).round().clamp(-32768, 32767);
    } else if (scaled < -30000) {
      final double excess = -scaled - 30000;
      result = (-30000 - 2767 * (excess / (excess + 2767))).round().clamp(-32768, 32767);
    } else {
      result = scaled.round().clamp(-32768, 32767);
    }
    dst.setInt16(i * 2, result, Endian.little);
  }

  return outBytes;
}

/// Normalizes 16-bit PCM little-endian audio samples so that the effective peak amplitude
/// reaches [targetPeakFraction] (default 0.95 ≈ -0.45 dBFS for clear, loud audibility).
///
/// Uses robust 99.9th percentile estimation across samples so single stray transient clicks
/// (e.g. phone touch, tap) do not suppress the amplification of faint bird calls.
/// A [maxGainMultiplier] safeguard (default 16.0 = +24 dB) prevents excessive noise floor amplification.
Uint8List normalizePcm16Gain(
  Uint8List pcmBytes, {
  double targetPeakFraction = 0.95,
  double maxGainMultiplier = 16.0,
}) {
  if (pcmBytes.length < 2) return pcmBytes;
  final int sampleCount = pcmBytes.length ~/ 2;
  final ByteData src = ByteData.sublistView(pcmBytes);

  // 1. Build an amplitude histogram to find robust peak (99.9th percentile) and absolute peak
  final Int32List hist = Int32List(32769);
  int absPeak = 0;

  for (int i = 0; i < sampleCount; i++) {
    final int sample = src.getInt16(i * 2, Endian.little).abs();
    if (sample > absPeak) absPeak = sample;
    hist[sample > 32768 ? 32768 : sample]++;
  }

  if (absPeak <= 0) return pcmBytes; // Silence — do not alter

  // Find 99.9th percentile amplitude
  final int targetCount = math.max(1, (sampleCount * 0.999).ceil());
  int accumulated = 0;
  int robustPeak = absPeak;
  for (int bin = 0; bin <= 32768; bin++) {
    accumulated += hist[bin];
    if (accumulated >= targetCount) {
      robustPeak = math.max(bin, 1);
      break;
    }
  }

  final double currentFraction = robustPeak / 32768.0;
  if (currentFraction >= targetPeakFraction && absPeak / 32768.0 >= targetPeakFraction) {
    return pcmBytes;
  }

  final double requiredGain = (targetPeakFraction / currentFraction).clamp(
    1.0,
    maxGainMultiplier,
  );
  if (requiredGain <= 1.001) return pcmBytes;

  return applyPcm16Gain(pcmBytes, requiredGain);
}

