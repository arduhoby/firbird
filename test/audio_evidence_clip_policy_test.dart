import 'package:firbird/audio/audio_evidence_clip_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plays the exact three-second model window', () {
    expect(
      AudioEvidenceClipPolicy.modelWindow(
        detectionStartMs: 10000,
        durationMs: 30000,
      ),
      (startMs: 10000, endMs: 13000),
    );
  });

  test('clamps the model window to the recording end', () {
    expect(
      AudioEvidenceClipPolicy.modelWindow(
        detectionStartMs: 7000,
        durationMs: 8000,
      ),
      (startMs: 7000, endMs: 8000),
    );
  });

  test('saves ten seconds before and after the detection', () {
    expect(
      AudioEvidenceClipPolicy.evidenceWindow(
        detectionStartMs: 20000,
        durationMs: 60000,
      ),
      (startMs: 10000, endMs: 30000),
    );
  });

  test('only recording boundaries shorten evidence context', () {
    expect(
      AudioEvidenceClipPolicy.evidenceWindow(
        detectionStartMs: 4000,
        durationMs: 60000,
      ),
      (startMs: 0, endMs: 14000),
    );
    expect(
      AudioEvidenceClipPolicy.evidenceWindow(
        detectionStartMs: 57000,
        durationMs: 60000,
      ),
      (startMs: 47000, endMs: 60000),
    );
  });
}
