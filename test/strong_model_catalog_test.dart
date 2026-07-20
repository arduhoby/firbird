import 'package:firbird/inference/strong_model_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the verified strong Turkey model descriptor', () {
    final StrongModelDescriptor descriptor = parseStrongModelDescriptor('''
      {"id":"turkey-bioclip2-int8","version":"0.1.0-preview","runtime":"onnx","modelUri":"https://example.test/model.onnx","modelBytes":306917008,"sha256":"abc","license":"MIT","candidateScope":"turkey-balkans-residents-and-regular-migrants","candidatePolicy":"Include regular migrants."}
    ''');

    expect(descriptor.runtime, 'onnx');
    expect(descriptor.modelBytes, 306917008);
    expect(
      descriptor.candidateScope,
      'turkey-balkans-residents-and-regular-migrants',
    );
    expect(descriptor.candidatePolicy, 'Include regular migrants.');
  });
}
