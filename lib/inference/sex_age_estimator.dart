import 'dart:math' as math;
import 'dart:typed_data';

import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:firbird/inference/species_sex_age_policy.dart';

// ---------------------------------------------------------------------------
// Estimator arayüzü
// ---------------------------------------------------------------------------

/// Görsel özelliklerden cinsiyet & yaşam evresi tahmini yapan soyut arayüz.
/// Gerçek model geldiğinde bu arayüzü implement eden yeni bir sınıf yazılır.
abstract interface class SexAgeEstimator {
  /// [imageFeatures]: ONNX'ten gelen L2-normalize edilmiş görsel embedding.
  /// [speciesId]: tahmin edilen tür ID'si.
  /// [policy]: türe özgü cinsiyet/yaşam evresi politikası.
  SexAgePrediction? estimate({
    required String speciesId,
    required Float32List imageFeatures,
    required SpeciesSexAgePolicy policy,
  });
}

// ---------------------------------------------------------------------------
// Kural tabanlı placeholder estimator
// ---------------------------------------------------------------------------

/// Gerçek model hazır olana kadar kullanılan kural tabanlı tahminci.
///
/// Davranış kuralları:
/// - Politika [SexDiscrimination.unreliable] ise null döner (UI gizlenir).
/// - Diğer durumlarda speciesId hash'ini seed olarak kullanarak
///   deterministik ama makul görünen skorlar üretir.
/// - Yöntem her zaman [PredictionMethod.bioclip2] olarak etiketlenir;
///   gerçek model entegre edildiğinde bu değişmez, sadece skorlar gerçek olur.
class PlaceholderSexAgeEstimator implements SexAgeEstimator {
  const PlaceholderSexAgeEstimator();

  @override
  SexAgePrediction? estimate({
    required String speciesId,
    required Float32List imageFeatures,
    required SpeciesSexAgePolicy policy,
  }) {
    final bool isSexUnreliable =
        policy.sexDiscrimination == SexDiscrimination.unreliable;

    final int seed = speciesId.codeUnits.fold(0, (a, b) => a ^ b);
    final math.Random rng = math.Random(seed);

    final SexPrediction sex = isSexUnreliable
        ? const SexPrediction(
            scores: <SexCategory, double>{SexCategory.unknown: 1.0},
            method: PredictionMethod.zeroShot,
          )
        : _estimateSex(rng, policy);

    final AgePrediction age = _estimateAge(rng, policy);

    // Çelişki kontrolü: Yavru + net cinsiyet tahmini çelişebilir.
    final bool conflict = age.displayCategory == AgeCategory.chick &&
        sex.displayCategory != SexCategory.unknown &&
        !isSexUnreliable;

    return SexAgePrediction(
      sex: sex,
      age: age,
      conflictWarning: conflict,
      isSexUnreliable: isSexUnreliable,
    );
  }


  SexPrediction _estimateSex(math.Random rng, SpeciesSexAgePolicy policy) {
    // Seasonsal türlerde belirsizlik daha yüksek
    final double uncertainty =
        policy.sexDiscrimination == SexDiscrimination.seasonalOrPlumage
            ? 0.30
            : 0.15;

    final double femaleFraction = 0.45 + rng.nextDouble() * 0.30;
    final double maleFraction = (1 - femaleFraction) * (1 - uncertainty);
    final double unknownFraction = (1 - femaleFraction) * uncertainty;

    return SexPrediction(
      scores: {
        SexCategory.female: femaleFraction,
        SexCategory.male: maleFraction,
        SexCategory.unknown: unknownFraction,
      },
      method: PredictionMethod.zeroShot,
    );
  }

  AgePrediction _estimateAge(math.Random rng, SpeciesSexAgePolicy policy) {
    final double adultBase =
        policy.ageDiscrimination == AgeDiscrimination.hard ? 0.55 : 0.70;
    final double adult = adultBase + rng.nextDouble() * 0.15;
    final double remaining = 1 - adult;
    final double juvenile = remaining * 0.65;
    final double chick = remaining * 0.35;

    return AgePrediction(
      scores: {
        AgeCategory.adult: adult,
        AgeCategory.juvenile: juvenile,
        AgeCategory.chick: chick,
        AgeCategory.unknown: 0.0,
      },
      method: PredictionMethod.zeroShot,
      terminology: policy.ageTerminology,
    );
  }
}
