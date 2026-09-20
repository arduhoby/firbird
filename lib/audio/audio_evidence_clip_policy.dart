abstract final class AudioEvidenceClipPolicy {
  static const int modelWindowMs = 3000;
  static const int evidenceContextMs = 10000;

  /// Returns the exact three-second PCM window evaluated by the live model.
  ///
  /// A persisted detection can span several overlapping model windows. Human
  /// review deliberately starts with the first window instead of adding broad
  /// context that can hide the detected sound among unrelated noise.
  static ({int startMs, int endMs}) modelWindow({
    required int detectionStartMs,
    required int durationMs,
  }) {
    final int safeDuration = durationMs > 0
        ? durationMs
        : (detectionStartMs + modelWindowMs).clamp(1000, 1 << 31);
    final int start = detectionStartMs.clamp(0, safeDuration);
    final int end = (start + modelWindowMs).clamp(start, safeDuration);
    return (startMs: start, endMs: end);
  }

  /// Returns the shareable evidence context around a detection moment.
  ///
  /// Playback remains the exact three-second inference window. Saved and
  /// shared evidence includes up to ten seconds before and after its start;
  /// only the recording boundaries may shorten that context.
  static ({int startMs, int endMs}) evidenceWindow({
    required int detectionStartMs,
    required int durationMs,
  }) {
    final int safeDuration = durationMs.clamp(0, 1 << 31);
    final int anchor = detectionStartMs.clamp(0, safeDuration);
    return (
      startMs: (anchor - evidenceContextMs).clamp(0, safeDuration),
      endMs: (anchor + evidenceContextMs).clamp(0, safeDuration),
    );
  }
}
