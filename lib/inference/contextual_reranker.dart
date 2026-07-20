import 'dart:math' as math;

import 'package:firbird/inference/bird_inference_engine.dart';

class SpeciesPriorStore {
  const SpeciesPriorStore({
    required this.geographic,
    required this.seasonal,
    required this.habitat,
  });

  const SpeciesPriorStore.turkeySample()
    : geographic = const <String, Map<String, double>>{
        'carduelis-carduelis': <String, double>{'TR': 0.9},
        'chloris-chloris': <String, double>{'TR': 0.8},
        'serinus-serinus': <String, double>{'TR': 0.65},
        'fringilla-coelebs': <String, double>{'TR': 0.75},
        'passer-domesticus': <String, double>{'TR': 0.95},
      },
      seasonal = const <String, Map<int, double>>{
        'carduelis-carduelis': <int, double>{1: 0.8, 7: 0.9},
        'chloris-chloris': <int, double>{1: 0.85, 7: 0.85},
        'serinus-serinus': <int, double>{1: 0.55, 7: 0.75},
        'fringilla-coelebs': <int, double>{1: 0.8, 7: 0.65},
        'passer-domesticus': <int, double>{1: 0.95, 7: 0.95},
      },
      habitat = const <String, Map<String, double>>{};

  final Map<String, Map<String, double>> geographic;
  final Map<String, Map<int, double>> seasonal;
  final Map<String, Map<String, double>> habitat;
}

class ContextualReranker implements PredictionReranker {
  const ContextualReranker({
    required this.priors,
    this.visualWeight = 1,
    this.geographicWeight = 0.35,
    this.seasonalWeight = 0.25,
    this.habitatWeight = 0.15,
  });

  final SpeciesPriorStore priors;
  final double visualWeight;
  final double geographicWeight;
  final double seasonalWeight;
  final double habitatWeight;

  @override
  Future<List<SpeciesPrediction>> rerank(
    List<SpeciesPrediction> predictions,
    ObservationContext context,
  ) {
    final List<SpeciesPrediction> reranked =
        predictions
            .map(
              (SpeciesPrediction prediction) =>
                  prediction.copyWith(score: _score(prediction, context)),
            )
            .toList()
          ..sort(
            (SpeciesPrediction left, SpeciesPrediction right) =>
                right.score.compareTo(left.score),
          );
    return Future<List<SpeciesPrediction>>.value(reranked);
  }

  double _score(SpeciesPrediction prediction, ObservationContext context) {
    final double visual = _safe(prediction.score);
    final double geographic = context.countryCode == null
        ? 1
        : _safe(
            priors.geographic[prediction.speciesId]?[context.countryCode] ?? 1,
          );
    final double seasonal = context.date == null
        ? 1
        : _safe(
            priors.seasonal[prediction.speciesId]?[context.date!.month] ?? 1,
          );

    final double logScore =
        visualWeight * math.log(visual) +
        geographicWeight * math.log(geographic) +
        seasonalWeight * math.log(seasonal);
    return math.exp(logScore);
  }

  double _safe(double value) => value.clamp(0.0001, 1);
}
