import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import 'package:firbird/inference/contextual_reranker.dart';
import 'package:firbird/inference/onnx_bird_inference_engine.dart';

// ---------------------------------------------------------------------------
// Kuş Türü Durum Kategorileri (Yerel/Göçmen, Nadir, Bölge Dışı)
// ---------------------------------------------------------------------------

enum SpeciesStatusCategory {
  /// Yerel ve Göçmen Kuşlar -> Yeşil çerçeve
  localOrMigratory,

  /// Nadir Kuşlar -> Kırmızı çerçeve
  rare,

  /// Bölge Dışı / Olması Zor Kuşlar -> Gri çerçeve
  outOfRegion,
}

extension SpeciesStatusCategoryX on SpeciesStatusCategory {
  Color get borderColor => switch (this) {
        SpeciesStatusCategory.localOrMigratory => Colors.green,
        SpeciesStatusCategory.rare => Colors.red,
        SpeciesStatusCategory.outOfRegion => Colors.grey,
      };

  String get label => switch (this) {
        SpeciesStatusCategory.localOrMigratory => 'Yerel / Göçmen',
        SpeciesStatusCategory.rare => 'Nadir Tür',
        SpeciesStatusCategory.outOfRegion => 'Bölge Dışı / Zor',
      };
}

class SpeciesStatusHelper {
  static Map<String, String>? _occurrenceMap;

  static Future<void> loadOccurrences() async {
    if (_occurrenceMap != null) return;
    try {
      final Directory dir = await OnnxBirdInferenceEngine.ensureTurkeyPackageInstalled();
      final File file = File(path.join(dir.path, 'candidates.json'));
      if (await file.exists()) {
        final Map<String, dynamic> json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final List<dynamic> candidates = json['candidates'] as List<dynamic>;
        _occurrenceMap = {};
        for (final c in candidates) {
          final map = c as Map<String, dynamic>;
          final sci = (map['scientificName'] as String).toLowerCase();
          final occ = map['occurrence'] as String? ?? '';
          _occurrenceMap![sci] = occ;
        }
      }
    } catch (e) {
      debugPrint('Error loading candidates occurrence map: $e');
    }
  }

  static SpeciesStatusCategory getCategory({
    String? originLabel,
    String? scientificName,
  }) {
    if (originLabel != null && originLabel.isNotEmpty) {
      final String label = originLabel.toLowerCase();
      if (label.contains('nadir') || label.contains('accidental')) {
        return SpeciesStatusCategory.rare;
      }
      if (label.contains('düzenli') ||
          label.contains('göçmen') ||
          label.contains('yerleşik') ||
          label.contains('resident') ||
          label.contains('regular-or-migratory')) {
        return SpeciesStatusCategory.localOrMigratory;
      }
      if (label.contains('dünya') || label.contains('balkan') || label.contains('bölge dışı')) {
        return SpeciesStatusCategory.outOfRegion;
      }
    }

    if (scientificName != null) {
      final String sciLower = scientificName.toLowerCase();
      if (_occurrenceMap != null) {
        final String? occ = _occurrenceMap![sciLower];
        if (occ == 'accidental') return SpeciesStatusCategory.rare;
        if (occ == 'regular-or-migratory' || occ == 'resident') {
          return SpeciesStatusCategory.localOrMigratory;
        }
        if (occ != null && occ.isNotEmpty) return SpeciesStatusCategory.outOfRegion;
      }
    }

    return SpeciesStatusCategory.outOfRegion;
  }
}

// ---------------------------------------------------------------------------
// Cinsiyet & Yaşam Evresi
// ---------------------------------------------------------------------------

enum SexCategory {
  female,
  male,
  unknown;

  String get label => switch (this) {
        SexCategory.female => 'Dişi',
        SexCategory.male => 'Erkek',
        SexCategory.unknown => 'Belirsiz',
      };
}

enum AgeCategory {
  chick,
  juvenile,
  adult,
  unknown;

  String defaultLabel() => switch (this) {
        AgeCategory.chick => 'Yavru',
        AgeCategory.juvenile => 'Genç',
        AgeCategory.adult => 'Yetişkin',
        AgeCategory.unknown => 'Belirsiz',
      };
}

enum PredictionMethod {
  /// BioCLIP-2 zero-shot text prompt benzerliği (mevcut yöntem).
  zeroShot,

  /// BioCLIP-2 tabanlı ince ayarlı model (gelecek).
  bioclip2,

  /// Kullanıcı "Uygun" dedi — model tahminini onayladı.
  userApproved,

  /// Kullanıcı düzeltti.
  userValidated,

  /// Birden fazla yöntem birleşimi.
  hybrid;

  String get label => switch (this) {
        PredictionMethod.zeroShot => 'BioCLIP 2 · metin benzerliği',
        PredictionMethod.bioclip2 => 'BioCLIP 2',
        PredictionMethod.userApproved => 'Kullanıcı onayladı',
        PredictionMethod.userValidated => 'Kullanıcı düzeltmesi',
        PredictionMethod.hybrid => 'Karma',
      };
}

class SexPrediction {
  const SexPrediction({
    required this.scores,
    required this.method,
  });

  /// Her cinsiyet için olasılık skoru (toplamı ~1.0).
  final Map<SexCategory, double> scores;
  final PredictionMethod method;

  SexCategory get displayCategory {
    final SexCategory best =
        scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final double bestScore = scores[best] ?? 0;
    if (best == SexCategory.unknown || bestScore < 0.60) {
      return SexCategory.unknown;
    }
    return best;
  }

  double get confidence => scores[displayCategory] ?? 0;
}

class AgePrediction {
  const AgePrediction({
    required this.scores,
    required this.method,
    this.terminology,
  });

  /// Her yaşam evresi için olasılık skoru (toplamı ~1.0).
  final Map<AgeCategory, double> scores;
  final PredictionMethod method;

  /// Türe özgü terim haritası (örn. 'Yavru', 'Tüy değişimi', 'Yetişkin').
  final Map<AgeCategory, String>? terminology;

  AgeCategory get displayCategory {
    final AgeCategory best =
        scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return best;
  }

  double get confidence => scores[displayCategory] ?? 0;

  String labelFor(AgeCategory category) =>
      terminology?[category] ?? category.defaultLabel();
}

class SexAgePrediction {
  const SexAgePrediction({
    required this.sex,
    required this.age,
    this.conflictWarning = false,
    this.isSexUnreliable = false,
  });

  final SexPrediction sex;
  final AgePrediction age;

  /// Cinsiyet ve yaşam evresi birbiriyle çelişiyorsa true.
  final bool conflictWarning;

  /// Bu tür için cinsiyet tahmini güvenilir değilse true.
  final bool isSexUnreliable;
}

// ---------------------------------------------------------------------------
// Görsel Girdi
// ---------------------------------------------------------------------------

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

  SpeciesStatusCategory get statusCategory => SpeciesStatusHelper.getCategory(
        originLabel: originLabel,
        scientificName: scientificName,
      );

  SpeciesPrediction copyWith({double? score, String? turkishName}) {
    return SpeciesPrediction(
      speciesId: speciesId,
      turkishName: turkishName ?? this.turkishName,
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
    this.sexAge,
    this.recordId,
  });

  final List<SpeciesPrediction> predictions;
  final String modelVersion;
  final bool locationAffectedResult;
  final bool dateAffectedResult;
  final String? sourceImageUri;
  final int? recordId;

  /// Cinsiyet & yaşam evresi tahmini. Model veya politika mevcut değilse null.
  final SexAgePrediction? sexAge;

  InferenceResult copyWith({
    int? recordId,
    List<SpeciesPrediction>? predictions,
    String? sourceImageUri,
  }) {
    return InferenceResult(
      predictions: predictions ?? this.predictions,
      modelVersion: modelVersion,
      locationAffectedResult: locationAffectedResult,
      dateAffectedResult: dateAffectedResult,
      sourceImageUri: sourceImageUri ?? this.sourceImageUri,
      sexAge: sexAge,
      recordId: recordId ?? this.recordId,
    );
  }
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
  /// Mevcut modeldeki (veya yüklü paketteki) tüm desteklenen türler.
  List<SpeciesPrediction> get candidateSpecies;

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
  @override
  List<SpeciesPrediction> get candidateSpecies => _mockPredictions;

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
