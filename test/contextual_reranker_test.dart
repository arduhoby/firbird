import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:firbird/inference/contextual_reranker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const List<SpeciesPrediction> predictions = <SpeciesPrediction>[
    SpeciesPrediction(
      speciesId: 'visual-first',
      turkishName: 'Birinci',
      scientificName: 'First species',
      englishName: 'First',
      score: 0.8,
    ),
    SpeciesPrediction(
      speciesId: 'context-first',
      turkishName: 'İkinci',
      scientificName: 'Second species',
      englishName: 'Second',
      score: 0.7,
    ),
  ];

  test('unknown location and date preserve visual ordering', () async {
    final ContextualReranker reranker = ContextualReranker(priors: _priors);

    final List<SpeciesPrediction> result = await reranker.rerank(
      predictions,
      const ObservationContext(),
    );

    expect(result.first.speciesId, 'visual-first');
  });

  test('geographic prior reranks but does not remove candidates', () async {
    final ContextualReranker reranker = ContextualReranker(
      priors: _priors,
      geographicWeight: 1,
    );

    final List<SpeciesPrediction> result = await reranker.rerank(
      predictions,
      const ObservationContext(countryCode: 'TR'),
    );

    expect(result.first.speciesId, 'context-first');
    expect(result, hasLength(2));
  });
}

const SpeciesPriorStore _priors = SpeciesPriorStore(
  geographic: <String, Map<String, double>>{
    'visual-first': <String, double>{'TR': 0.1},
    'context-first': <String, double>{'TR': 1},
  },
  seasonal: <String, Map<int, double>>{},
  habitat: <String, Map<String, double>>{},
);
