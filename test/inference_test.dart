import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock inference returns five ordered predictions', () async {
    final MockBirdInferenceEngine engine = MockBirdInferenceEngine();

    final InferenceResult result = await engine.identify(
      const ImageInput(uri: 'test-image'),
      const IdentificationContext(countryCode: 'TR'),
    );

    expect(result.predictions, hasLength(5));
    expect(result.predictions.first.turkishName, 'Saka');
    expect(
      result.predictions.first.score,
      greaterThan(result.predictions[1].score),
    );
    expect(result.locationAffectedResult, isTrue);
    expect(result.dateAffectedResult, isFalse);
  });
}
