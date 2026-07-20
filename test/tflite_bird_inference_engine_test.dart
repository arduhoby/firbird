import 'package:firbird/inference/tflite_bird_inference_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports a clear error when no TFLite asset is configured', () async {
    final TfliteBirdInferenceEngine engine = TfliteBirdInferenceEngine(
      assetPath: 'assets/models/missing.tflite',
      modelId: 'test-model',
      modelVersion: '0.0.0',
    );

    expect(engine.warmUp(), throwsA(isA<ModelNotAvailableException>()));
  });
}
