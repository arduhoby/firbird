import 'dart:io';
import 'dart:typed_data';

/// Extracts a time-range clip from a WAV file and writes it to [outputPath].
///
/// The WAV file must be PCM 16-bit (standard format produced by FirBird's
/// live-recording pipeline).  No external native library is required – the
/// entire operation is performed in pure Dart using byte-level slice maths.
///
/// Returns the resolved [outputPath] on success.
abstract final class WavClipExtractor {
  /// Reads [sourceWavPath], slices the samples between [startMs] and [endMs],
  /// writes a valid WAV file to [outputPath], and returns [outputPath].
  ///
  /// Throws a [WavClipException] if the source file cannot be read or does not
  /// carry a recognised PCM WAV header.
  static Future<String> extract(
    String sourceWavPath, {
    required int startMs,
    required int endMs,
    required String outputPath,
  }) async {
    assert(startMs >= 0, 'startMs must be non-negative');
    assert(endMs > startMs, 'endMs must be greater than startMs');

    final File sourceFile = File(sourceWavPath);
    if (!sourceFile.existsSync()) {
      throw WavClipException('Source file not found: $sourceWavPath');
    }

    final Uint8List bytes = await sourceFile.readAsBytes();
    if (bytes.length < 44) {
      throw WavClipException('File too small to be a valid WAV: $sourceWavPath');
    }

    // ── Parse WAV header ────────────────────────────────────────────────────
    final ByteData hdr = ByteData.sublistView(bytes, 0, 44);

    // RIFF identifier
    if (bytes[0] != 0x52 || bytes[1] != 0x49 || // 'RI'
        bytes[2] != 0x46 || bytes[3] != 0x46) {  // 'FF'
      throw WavClipException('Not a RIFF file: $sourceWavPath');
    }
    // WAVE identifier
    if (bytes[8] != 0x57 || bytes[9] != 0x41 || // 'WA'
        bytes[10] != 0x56 || bytes[11] != 0x45) { // 'VE'
      throw WavClipException('Not a WAVE file: $sourceWavPath');
    }

    final int audioFormat = hdr.getUint16(20, Endian.little);
    if (audioFormat != 1) {
      throw WavClipException(
        'Only PCM (format=1) is supported; found format=$audioFormat',
      );
    }

    final int numChannels = hdr.getUint16(22, Endian.little);
    final int sampleRate = hdr.getInt32(24, Endian.little);
    final int bitsPerSample = hdr.getUint16(34, Endian.little);

    if (sampleRate <= 0 || numChannels <= 0 || bitsPerSample <= 0) {
      throw WavClipException('Invalid WAV parameters in header');
    }

    final int bytesPerSample = bitsPerSample ~/ 8;
    final int bytesPerFrame = numChannels * bytesPerSample;
    final int bytesPerMs = (sampleRate * bytesPerFrame) ~/ 1000;

    // The 44-byte header is standard; skip 'data' chunk search for simplicity
    // (FirBird's WAV files always use the canonical 44-byte layout).
    const int dataOffset = 44;
    final int totalDataBytes = bytes.length - dataOffset;

    // Clamp to actual data range
    final int startByte = (startMs * bytesPerMs).clamp(0, totalDataBytes);
    final int endByte = (endMs * bytesPerMs).clamp(startByte, totalDataBytes);
    // Align to frame boundary
    final int alignedStart = (startByte ~/ bytesPerFrame) * bytesPerFrame;
    final int alignedEnd = (endByte ~/ bytesPerFrame) * bytesPerFrame;
    final int clipDataBytes = alignedEnd - alignedStart;

    if (clipDataBytes <= 0) {
      throw WavClipException(
        'Clip range [$startMs ms – $endMs ms] yields no audio data',
      );
    }

    // ── Build output WAV ────────────────────────────────────────────────────
    final int totalOutputBytes = 44 + clipDataBytes;
    final Uint8List out = Uint8List(totalOutputBytes);
    final ByteData outHdr = ByteData.sublistView(out, 0, 44);

    // ChunkID "RIFF"
    out[0] = 0x52; out[1] = 0x49; out[2] = 0x46; out[3] = 0x46;
    // ChunkSize
    outHdr.setUint32(4, totalOutputBytes - 8, Endian.little);
    // Format "WAVE"
    out[8] = 0x57; out[9] = 0x41; out[10] = 0x56; out[11] = 0x45;
    // Subchunk1ID "fmt "
    out[12] = 0x66; out[13] = 0x6D; out[14] = 0x74; out[15] = 0x20;
    // Subchunk1Size = 16 for PCM
    outHdr.setUint32(16, 16, Endian.little);
    // AudioFormat = 1 (PCM)
    outHdr.setUint16(20, 1, Endian.little);
    // NumChannels
    outHdr.setUint16(22, numChannels, Endian.little);
    // SampleRate
    outHdr.setUint32(24, sampleRate, Endian.little);
    // ByteRate = SampleRate × NumChannels × BitsPerSample/8
    outHdr.setUint32(28, sampleRate * bytesPerFrame, Endian.little);
    // BlockAlign = NumChannels × BitsPerSample/8
    outHdr.setUint16(32, bytesPerFrame, Endian.little);
    // BitsPerSample
    outHdr.setUint16(34, bitsPerSample, Endian.little);
    // Subchunk2ID "data"
    out[36] = 0x64; out[37] = 0x61; out[38] = 0x74; out[39] = 0x61;
    // Subchunk2Size
    outHdr.setUint32(40, clipDataBytes, Endian.little);

    // Copy PCM samples
    out.setRange(
      44,
      44 + clipDataBytes,
      bytes,
      dataOffset + alignedStart,
    );

    await File(outputPath).writeAsBytes(out, flush: true);
    return outputPath;
  }

  /// Returns the duration of a WAV file in milliseconds by reading the header.
  /// Returns 0 if the file cannot be parsed.
  static int durationMsFromPath(String wavPath) {
    try {
      final File f = File(wavPath);
      if (!f.existsSync()) return 0;
      final RandomAccessFile raf = f.openSync();
      try {
        if (raf.lengthSync() < 44) return 0;
        raf.setPositionSync(0);
        final Uint8List hdrBytes = raf.readSync(44);
        final ByteData hdr = ByteData.sublistView(hdrBytes);
        final int sampleRate = hdr.getInt32(24, Endian.little);
        final int numChannels = hdr.getUint16(22, Endian.little);
        final int bitsPerSample = hdr.getUint16(34, Endian.little);
        if (sampleRate <= 0 || numChannels <= 0 || bitsPerSample <= 0) {
          return 0;
        }
        final int bytesPerFrame = numChannels * (bitsPerSample ~/ 8);
        final int dataBytes = raf.lengthSync() - 44;
        final int frames = dataBytes ~/ bytesPerFrame;
        return (frames * 1000) ~/ sampleRate;
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return 0;
    }
  }
}

/// Thrown when [WavClipExtractor] encounters an unrecoverable error.
class WavClipException implements Exception {
  const WavClipException(this.message);
  final String message;
  @override
  String toString() => 'WavClipException: $message';
}
