import 'dart:convert';

import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Politika enum'ları
// ---------------------------------------------------------------------------

enum SexDiscrimination {
  /// Dişi/erkek fotoğraftan güvenilir şekilde ayırt edilebilir.
  reliable,

  /// Yalnızca tüy görünümü veya mevsimsel değişimden tahmin edilebilir.
  seasonalOrPlumage,

  /// Bu türde görsel cinsiyet ayrımı güvenilir değil (DNA / uzman gerekli).
  unreliable;
}

enum AgeDiscrimination {
  /// Yaşam evresi fotoğraftan güvenilir şekilde ayırt edilebilir.
  reliable,

  /// Yalnızca mevsimsel tüy değişimiyle ayırt edilebilir.
  seasonal,

  /// Fotoğraftan ayırt etmek güç.
  hard;
}

// ---------------------------------------------------------------------------
// Politika sınıfı
// ---------------------------------------------------------------------------

class SpeciesSexAgePolicy {
  const SpeciesSexAgePolicy({
    required this.sexDiscrimination,
    required this.ageDiscrimination,
    this.minSexConfidence = 0.60,
    this.minAgeConfidence = 0.50,
    this.ageTerminology,
  });

  /// Varsayılan politika — bilinmeyen türler için.
  const SpeciesSexAgePolicy.defaultPolicy()
      : sexDiscrimination = SexDiscrimination.unreliable,
        ageDiscrimination = AgeDiscrimination.hard,
        minSexConfidence = 0.70,
        minAgeConfidence = 0.60,
        ageTerminology = null;

  final SexDiscrimination sexDiscrimination;
  final AgeDiscrimination ageDiscrimination;

  /// Bu türde cinsiyet tahmini için minimum kabul edilebilir skor.
  final double minSexConfidence;

  /// Bu türde yaşam evresi tahmini için minimum kabul edilebilir skor.
  final double minAgeConfidence;

  /// Türe özgü yaşam evresi terimleri. Null ise varsayılan etiketler kullanılır.
  final Map<AgeCategory, String>? ageTerminology;

  /// Cinsiyet tahmini gösterilebilir mi?
  bool get canShowSex => sexDiscrimination != SexDiscrimination.unreliable;

  /// Kullanıcıya uyarı gösterilmeli mi?
  bool get showSexWarning =>
      sexDiscrimination == SexDiscrimination.seasonalOrPlumage;

  factory SpeciesSexAgePolicy.fromJson(Map<String, dynamic> json) {
    final Map<AgeCategory, String>? terminology = _parseTerminology(
      json['ageTerminology'] as Map<String, dynamic>?,
    );
    return SpeciesSexAgePolicy(
      sexDiscrimination: _parseSexDiscrimination(
        json['sexDiscrimination'] as String?,
      ),
      ageDiscrimination: _parseAgeDiscrimination(
        json['ageDiscrimination'] as String?,
      ),
      minSexConfidence:
          (json['minSexConfidence'] as num?)?.toDouble() ?? 0.60,
      minAgeConfidence:
          (json['minAgeConfidence'] as num?)?.toDouble() ?? 0.50,
      ageTerminology: terminology,
    );
  }

  static SexDiscrimination _parseSexDiscrimination(String? value) =>
      switch (value) {
        'reliable' => SexDiscrimination.reliable,
        'seasonalOrPlumage' => SexDiscrimination.seasonalOrPlumage,
        _ => SexDiscrimination.unreliable,
      };

  static AgeDiscrimination _parseAgeDiscrimination(String? value) =>
      switch (value) {
        'reliable' => AgeDiscrimination.reliable,
        'seasonal' => AgeDiscrimination.seasonal,
        _ => AgeDiscrimination.hard,
      };

  static Map<AgeCategory, String>? _parseTerminology(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null) return null;
    final Map<AgeCategory, String> result = {};
    for (final MapEntry<String, dynamic> entry in raw.entries) {
      final AgeCategory? cat = switch (entry.key) {
        'chick' => AgeCategory.chick,
        'juvenile' => AgeCategory.juvenile,
        'adult' => AgeCategory.adult,
        _ => null,
      };
      if (cat != null) result[cat] = entry.value as String;
    }
    return result.isEmpty ? null : result;
  }
}

// ---------------------------------------------------------------------------
// Politika deposu
// ---------------------------------------------------------------------------

class SpeciesSexAgePolicyStore {
  SpeciesSexAgePolicyStore._(this._policies);

  final Map<String, SpeciesSexAgePolicy> _policies;

  static const String _assetPath = 'assets/species_traits.json';
  static SpeciesSexAgePolicyStore? _instance;

  static Future<SpeciesSexAgePolicyStore> load() async {
    if (_instance != null) return _instance!;
    try {
      final String raw = await rootBundle.loadString(_assetPath);
      final Map<String, dynamic> json =
          jsonDecode(raw) as Map<String, dynamic>;
      final Map<String, SpeciesSexAgePolicy> policies = {
        for (final MapEntry<String, dynamic> entry in json.entries)
          entry.key: SpeciesSexAgePolicy.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      };
      _instance = SpeciesSexAgePolicyStore._(policies);
    } catch (_) {
      // Asset yüklenemezse boş depo döner, her tür varsayılan politika alır.
      _instance = SpeciesSexAgePolicyStore._({});
    }
    return _instance!;
  }

  /// [speciesId] için politika döner; bulunamazsa varsayılan politika.
  SpeciesSexAgePolicy forSpecies(String speciesId) =>
      _policies[speciesId] ?? const SpeciesSexAgePolicy.defaultPolicy();

  /// Test ve mock için boş depo.
  factory SpeciesSexAgePolicyStore.empty() =>
      SpeciesSexAgePolicyStore._({});
}
