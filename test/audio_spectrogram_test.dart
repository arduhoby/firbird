import 'dart:typed_data';

import 'package:firbird/app/audio_spectrogram.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completed spectrogram honors columns per second', () {
    const int sampleRate = 48000;
    final Uint8List tenSeconds = Uint8List(sampleRate * 10 * 2);

    final List<List<double>> columns = WavSpectrogram.analyzePcm16(
      tenSeconds,
      sampleRate: sampleRate,
      maxColumns: 24000,
      columnsPerSecond: 8,
    );

    expect(columns.length, inInclusiveRange(79, 81));
  });
}
