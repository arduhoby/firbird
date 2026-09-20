import 'dart:math' as math;
import 'dart:typed_data';

import 'package:firbird/audio/audio_evidence_assessment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('separates a strong audible event from a quiet machine-only signal', () {
    final AudioEvidenceAssessment strong = AudioEvidenceEvaluator.evaluatePcm16(
      _pcmWithEvent(backgroundAmplitude: 80, eventAmplitude: 12000),
    );
    final AudioEvidenceAssessment quiet = AudioEvidenceEvaluator.evaluatePcm16(
      _pcmWithEvent(backgroundAmplitude: 4, eventAmplitude: 40),
    );

    expect(strong.level, AudioEvidenceLevel.strong);
    expect(strong.priority, greaterThan(quiet.priority));
    expect(strong.contrastDb, greaterThan(6));
    expect(quiet.level, AudioEvidenceLevel.machineOnly);
  });

  test('bestOf preserves the strongest evidence across repeated events', () {
    final AudioEvidenceAssessment quiet = AudioEvidenceEvaluator.evaluatePcm16(
      _pcmWithEvent(backgroundAmplitude: 4, eventAmplitude: 40),
    );
    final AudioEvidenceAssessment review = AudioEvidenceEvaluator.evaluatePcm16(
      _pcmWithEvent(backgroundAmplitude: 80, eventAmplitude: 900),
    );

    expect(quiet.bestOf(review), same(review));
  });
}

Uint8List _pcmWithEvent({
  required int backgroundAmplitude,
  required int eventAmplitude,
}) {
  const int sampleRate = 48000;
  const int seconds = 3;
  final ByteData output = ByteData(sampleRate * seconds * 2);
  for (int index = 0; index < sampleRate * seconds; index++) {
    final bool inEvent = index >= sampleRate && index < sampleRate * 2;
    final int amplitude = inEvent ? eventAmplitude : backgroundAmplitude;
    final int sample =
        (math.sin(index * 2 * math.pi * 2500 / sampleRate) * amplitude).round();
    output.setInt16(index * 2, sample, Endian.little);
  }
  return output.buffer.asUint8List();
}
