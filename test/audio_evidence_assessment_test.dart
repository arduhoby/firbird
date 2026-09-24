import 'dart:math' as math;
import 'dart:typed_data';

import 'package:firbird/audio/audio_evidence_assessment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DC-biased headset flatline is measured as near silence', () {
    final ByteData data = ByteData(48000 * 3 * 2);
    for (int i = 0; i < data.lengthInBytes ~/ 2; i++) {
      data.setInt16(i * 2, 68 + (i.isEven ? 2 : -2), Endian.little);
    }
    final Uint8List pcm = data.buffer.asUint8List();
    final Uint8List original = Uint8List.fromList(pcm);
    final result = AudioEvidenceEvaluator.evaluatePcm16(pcm);
    expect(result.foregroundDbfs, lessThan(-80));
    expect(result.peakDbfs, lessThan(-80));
    expect(result.level, AudioEvidenceLevel.machineOnly);
    expect(result.hasSignal, isFalse);
    expect(pcm, orderedEquals(original));
  });

  test('constant DC offset does not change audible evidence', () {
    final Uint8List pcm = _pcmWithEvent(
      backgroundAmplitude: 80,
      eventAmplitude: 12000,
    );
    final before = AudioEvidenceEvaluator.evaluatePcm16(pcm);
    final ByteData data = ByteData.sublistView(pcm);
    for (int i = 0; i < pcm.length; i += 2) {
      data.setInt16(i, data.getInt16(i, Endian.little) + 2000, Endian.little);
    }
    final after = AudioEvidenceEvaluator.evaluatePcm16(pcm);
    expect(after.foregroundDbfs, closeTo(before.foregroundDbfs, 0.01));
    expect(after.noiseFloorDbfs, closeTo(before.noiseFloorDbfs, 0.01));
    expect(after.peakDbfs, closeTo(before.peakDbfs, 0.01));
  });

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
    expect(quiet.hasSignal, isTrue);
    expect(strong.hasSignal, isTrue);
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
