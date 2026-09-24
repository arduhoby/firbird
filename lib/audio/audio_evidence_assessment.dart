import 'dart:math' as math;
import 'dart:typed_data';

enum AudioEvidenceLevel { strong, review, machineOnly }

enum AudioReviewVerdict { audible, uncertain, inaudible }

AudioReviewVerdict? audioReviewVerdictFromName(String? name) =>
    AudioReviewVerdict.values
        .where((AudioReviewVerdict value) => value.name == name)
        .firstOrNull;

class AudioEvidenceAssessment {
  const AudioEvidenceAssessment({
    required this.level,
    required this.foregroundDbfs,
    required this.noiseFloorDbfs,
    required this.contrastDb,
    required this.peakDbfs,
    required this.clippedFraction,
  });

  final AudioEvidenceLevel level;
  final double foregroundDbfs;
  final double noiseFloorDbfs;
  final double contrastDb;
  final double peakDbfs;
  final double clippedFraction;

  bool get isPotentiallyAudible => level != AudioEvidenceLevel.machineOnly;
  // Reject only near-flat PCM; weak but real events still enter the review path.
  bool get hasSignal => foregroundDbfs > -80 || peakDbfs > -65;
  int get priority => _levelRank(level);

  AudioEvidenceAssessment bestOf(AudioEvidenceAssessment other) {
    final int levelComparison = _levelRank(other.level) - _levelRank(level);
    if (levelComparison > 0) return other;
    if (levelComparison < 0) return this;
    if (other.foregroundDbfs > foregroundDbfs) return other;
    if (other.foregroundDbfs < foregroundDbfs) return this;
    return other.contrastDb > contrastDb ? other : this;
  }

  static AudioEvidenceAssessment? fromStored({
    required String? level,
    required double? foregroundDbfs,
    required double? noiseFloorDbfs,
    required double? contrastDb,
    double? peakDbfs,
    double? clippedFraction,
  }) {
    final AudioEvidenceLevel? parsedLevel = AudioEvidenceLevel.values
        .where((AudioEvidenceLevel value) => value.name == level)
        .firstOrNull;
    if (parsedLevel == null ||
        foregroundDbfs == null ||
        noiseFloorDbfs == null ||
        contrastDb == null) {
      return null;
    }
    return AudioEvidenceAssessment(
      level: parsedLevel,
      foregroundDbfs: foregroundDbfs,
      noiseFloorDbfs: noiseFloorDbfs,
      contrastDb: contrastDb,
      peakDbfs: peakDbfs ?? foregroundDbfs,
      clippedFraction: clippedFraction ?? 0,
    );
  }

  static int _levelRank(AudioEvidenceLevel value) => switch (value) {
    AudioEvidenceLevel.machineOnly => 0,
    AudioEvidenceLevel.review => 1,
    AudioEvidenceLevel.strong => 2,
  };
}

/// Measures recording audibility only. Species identity still requires model
/// evidence and independent human review.
abstract final class AudioEvidenceEvaluator {
  static AudioEvidenceAssessment evaluatePcm16(
    Uint8List pcm16, {
    int sampleRate = 48000,
  }) {
    if (pcm16.length < 2 || sampleRate <= 0) {
      return const AudioEvidenceAssessment(
        level: AudioEvidenceLevel.machineOnly,
        foregroundDbfs: -120,
        noiseFloorDbfs: -120,
        contrastDb: 0,
        peakDbfs: -120,
        clippedFraction: 0,
      );
    }

    final ByteData bytes = ByteData.sublistView(pcm16);
    final int sampleCount = pcm16.length ~/ 2;
    final int frameSamples = math.max(1, sampleRate ~/ 20);
    final List<double> frameLevels = <double>[];
    int clippedSamples = 0;
    double peak = 0;
    double sampleSum = 0;
    for (int index = 0; index < sampleCount; index++) {
      sampleSum += bytes.getInt16(index * 2, Endian.little);
    }
    // A microphone's DC bias is not audible sound. Measure AC amplitude without
    // altering the original PCM that is saved as evidence.
    final double dcOffset = sampleSum / sampleCount;

    for (
      int frameStart = 0;
      frameStart < sampleCount;
      frameStart += frameSamples
    ) {
      final int frameEnd = math.min(sampleCount, frameStart + frameSamples);
      double sumSquares = 0;
      for (int index = frameStart; index < frameEnd; index++) {
        final int sample = bytes.getInt16(index * 2, Endian.little);
        final double centered = sample - dcOffset;
        peak = math.max(peak, centered.abs());
        if (sample.abs() >= 32760) clippedSamples++;
        sumSquares += centered * centered;
      }
      final int length = frameEnd - frameStart;
      final double rms = length == 0 ? 0 : math.sqrt(sumSquares / length);
      frameLevels.add(_dbfs(rms));
    }

    frameLevels.sort();
    final double noiseFloor = _percentile(frameLevels, 0.20);
    final double foreground = _percentile(frameLevels, 0.90);
    final double contrast = math.max(0, foreground - noiseFloor);
    final double peakDbfs = _dbfs(peak.toDouble());
    final double clippedFraction = clippedSamples / sampleCount;

    AudioEvidenceLevel level;
    if (foreground >= -32 && (contrast >= 6 || foreground >= -26)) {
      level = AudioEvidenceLevel.strong;
    } else if (foreground >= -52 && (contrast >= 3 || foreground >= -42)) {
      level = AudioEvidenceLevel.review;
    } else {
      level = AudioEvidenceLevel.machineOnly;
    }
    if (clippedFraction >= 0.01 && level == AudioEvidenceLevel.strong) {
      level = AudioEvidenceLevel.review;
    }

    return AudioEvidenceAssessment(
      level: level,
      foregroundDbfs: foreground,
      noiseFloorDbfs: noiseFloor,
      contrastDb: contrast,
      peakDbfs: peakDbfs,
      clippedFraction: clippedFraction,
    );
  }

  static double _dbfs(double amplitude) => amplitude <= 0
      ? -120
      : (20 * math.log(amplitude / 32768) / math.ln10).clamp(-120, 0);

  static double _percentile(List<double> sorted, double fraction) {
    if (sorted.isEmpty) return -120;
    final int index = ((sorted.length - 1) * fraction).round();
    return sorted[index];
  }
}
