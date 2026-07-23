import 'dart:io';

import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:flutter/services.dart';

class ModelNotAvailableException implements Exception {
  const ModelNotAvailableException(this.message);

  final String message;
}

class TfliteBirdInferenceEngine implements BirdInferenceEngine {
  TfliteBirdInferenceEngine({
    required this.assetPath,
    required this.modelId,
    required this.modelVersion,
  });

  final String assetPath;
  final String modelId;
  final String modelVersion;
  bool _isDisposed = false;
  bool _isWarmedUp = false;
  static const MethodChannel _channel = MethodChannel(
    'org.firbird3.app/inference',
  );

  @override
  List<SpeciesPrediction> get candidateSpecies => const <SpeciesPrediction>[];

  @override
  Future<void> warmUp() async {
    if (_isDisposed) {
      throw const ModelNotAvailableException(
        'The inference engine is disposed.',
      );
    }
    if (!Platform.isAndroid) {
      throw const ModelNotAvailableException('Only Android is supported yet.');
    }
    await _channel.invokeMethod<void>('warmUp');
    _isWarmedUp = true;
  }

  @override
  Future<InferenceResult> identify(
    ImageInput image,
    IdentificationContext context,
  ) async {
    await warmUp();
    try {
      final List<Object?>? raw = await _channel.invokeListMethod<Object?>(
        'identify',
        <String, Object?>{'imagePath': image.uri, 'topK': 5},
      );
      if (raw == null || raw.isEmpty) {
        throw const ModelNotAvailableException(
          'Model did not return a result.',
        );
      }
      return InferenceResult(
        predictions: raw.map(_predictionFromPlatform).toList(),
        modelVersion: modelVersion,
        locationAffectedResult: context.countryCode != null,
        dateAffectedResult: context.observationDate != null,
        sourceImageUri: image.uri,
      );
    } on PlatformException catch (error) {
      throw ModelNotAvailableException(error.message ?? 'LiteRT failed.');
    }
  }

  @override
  Future<ModelInformation> getModelInformation() {
    return Future<ModelInformation>.value(
      ModelInformation(
        identifier: modelId,
        version: modelVersion,
        isMock: false,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    if (_isWarmedUp && Platform.isAndroid) {
      await _channel.invokeMethod<void>('dispose');
    }
  }

  SpeciesPrediction _predictionFromPlatform(Object? value) {
    final Map<Object?, Object?> map = value! as Map<Object?, Object?>;
    final List<String> names = (map['label']! as String)
        .split(',')
        .map((String name) => name.trim())
        .where((String name) => name.isNotEmpty)
        .toList();
    final String englishName = names.first;
    final String? scientificName = names
        .skip(1)
        .cast<String?>()
        .firstWhere(_looksScientific, orElse: () => null);
    final List<String> alternativeNames = names
        .skip(1)
        .where((String name) => name != scientificName)
        .toList();
    return SpeciesPrediction(
      speciesId: englishName.toLowerCase().replaceAll(
        RegExp('[^a-z0-9]+'),
        '-',
      ),
      turkishName: _turkishName(englishName),
      scientificName: scientificName ?? 'ImageNet sinifi',
      englishName: englishName,
      score: (map['score']! as num).toDouble(),
      alternativeNames: alternativeNames,
    );
  }

  bool _looksScientific(String? value) {
    if (value == null) return false;
    return RegExp(r'^[A-Z][a-z]+\s+[a-z-]+$').hasMatch(value);
  }

  String _turkishName(String label) => switch (label.toLowerCase()) {
    'emberiza citrinella' => 'Sari cinti',
    'emberiza schoeniclus' => 'Bataklik cintisi',
    'emberiza calandra' => 'Tarla cintisi',
    'passer domesticus' => 'Ev sercesi',
    'passer montanus' => 'Agac sercesi',
    'carduelis carduelis' => 'Saka',
    'goldfinch' => 'Saka',
    'house finch' => 'Ev ispinozu',
    'brambling' => 'Dag ispinozu',
    'junco' => 'Junko',
    _ => label,
  };
}
