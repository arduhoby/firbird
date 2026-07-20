import 'dart:async';

import 'package:firbird/inference/contextual_reranker.dart';

class ImageInput {
  const ImageInput({required this.uri});

  final String uri;
}

class IdentificationContext {
  const IdentificationContext({this.countryCode, this.observationDate});

  final String? countryCode;
  final DateTime? observationDate;
}

class BirdBoundingBox {
  const BirdBoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

class CandidateSpeciesSet {
  const CandidateSpeciesSet(this.speciesIds);

  final List<String> speciesIds;
}

class SpeciesPrediction {
  const SpeciesPrediction({
    required this.speciesId,
    required this.turkishName,
    required this.scientificName,
    required this.englishName,
    required this.score,
    this.alternativeNames = const <String>[],
    this.thumbnailUrl,
    this.ornitoId,
    this.originLabel,
  });

  final String speciesId;
  final String turkishName;
  final String scientificName;
  final String englishName;
  final double score;
  final List<String> alternativeNames;
  final String? thumbnailUrl;
  final String? ornitoId;
  final String? originLabel;

  SpeciesPrediction copyWith({double? score}) {
    return SpeciesPrediction(
      speciesId: speciesId,
      turkishName: turkishName,
      scientificName: scientificName,
      englishName: englishName,
      score: score ?? this.score,
      alternativeNames: alternativeNames,
      thumbnailUrl: thumbnailUrl,
      ornitoId: ornitoId,
      originLabel: originLabel,
    );
  }
}

class ObservationContext {
  const ObservationContext({this.countryCode, this.date, this.hasLocation});

  final String? countryCode;
  final DateTime? date;
  final bool? hasLocation;
}

class InferenceResult {
  const InferenceResult({
    required this.predictions,
    required this.modelVersion,
    required this.locationAffectedResult,
    required this.dateAffectedResult,
    this.sourceImageUri,
  });

  final List<SpeciesPrediction> predictions;
  final String modelVersion;
  final bool locationAffectedResult;
  final bool dateAffectedResult;
  final String? sourceImageUri;
}

class IdentificationRequest {
  const IdentificationRequest({required this.image, required this.context});

  final ImageInput image;
  final IdentificationContext context;
}

class ModelInformation {
  const ModelInformation({
    required this.identifier,
    required this.version,
    required this.isMock,
  });

  final String identifier;
  final String version;
  final bool isMock;
}

abstract interface class BirdInferenceEngine {
  Future<InferenceResult> identify(
    ImageInput image,
    IdentificationContext context,
  );

  Future<void> warmUp();

  Future<ModelInformation> getModelInformation();

  Future<void> dispose();
}

abstract interface class BirdDetector {
  Future<List<BirdBoundingBox>> detect(ImageInput image);
}

abstract interface class BirdClassifier {
  Future<List<SpeciesPrediction>> classify(
    ImageInput image,
    CandidateSpeciesSet candidates,
  );
}

abstract interface class PredictionReranker {
  Future<List<SpeciesPrediction>> rerank(
    List<SpeciesPrediction> predictions,
    ObservationContext context,
  );
}

class MockBirdInferenceEngine implements BirdInferenceEngine {
  static const List<SpeciesPrediction> _mockPredictions = <SpeciesPrediction>[
    SpeciesPrediction(
      speciesId: 'carduelis-carduelis',
      turkishName: 'Saka',
      scientificName: 'Carduelis carduelis',
      englishName: 'European goldfinch',
      score: 0.91,
    ),
    SpeciesPrediction(
      speciesId: 'chloris-chloris',
      turkishName: 'Florya',
      scientificName: 'Chloris chloris',
      englishName: 'European greenfinch',
      score: 0.74,
    ),
    SpeciesPrediction(
      speciesId: 'serinus-serinus',
      turkishName: 'Karabaşlı iskete',
      scientificName: 'Serinus serinus',
      englishName: 'European serin',
      score: 0.61,
    ),
    SpeciesPrediction(
      speciesId: 'fringilla-coelebs',
      turkishName: 'İspinoz',
      scientificName: 'Fringilla coelebs',
      englishName: 'Common chaffinch',
      score: 0.48,
    ),
    SpeciesPrediction(
      speciesId: 'passer-domesticus',
      turkishName: 'Ev serçesi',
      scientificName: 'Passer domesticus',
      englishName: 'House sparrow',
      score: 0.35,
    ),
  ];

  bool _isWarmedUp = false;
  final ContextualReranker _reranker = ContextualReranker(
    priors: const SpeciesPriorStore.turkeySample(),
  );

  @override
  Future<void> warmUp() async {
    if (_isWarmedUp) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _isWarmedUp = true;
  }

  @override
  Future<InferenceResult> identify(
    ImageInput image,
    IdentificationContext context,
  ) async {
    await warmUp();
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final List<SpeciesPrediction> reranked = await _reranker.rerank(
      _mockPredictions,
      ObservationContext(
        countryCode: context.countryCode,
        date: context.observationDate,
        hasLocation: context.countryCode != null,
      ),
    );
    return InferenceResult(
      predictions: reranked,
      modelVersion: 'mock-v1',
      locationAffectedResult: context.countryCode != null,
      dateAffectedResult: context.observationDate != null,
      sourceImageUri: image.uri,
    );
  }

  @override
  Future<ModelInformation> getModelInformation() {
    return Future<ModelInformation>.value(
      const ModelInformation(
        identifier: 'firbird-mock',
        version: '1.0.0',
        isMock: true,
      ),
    );
  }

  @override
  Future<void> dispose() async {}
}
