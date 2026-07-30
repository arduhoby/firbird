import 'dart:convert';

import 'package:flutter/services.dart';

class SpeciesCatalogEntry {
  const SpeciesCatalogEntry({
    required this.speciesId,
    required this.scientificName,
    required this.turkishName,
    required this.englishName,
    required this.occurrence,
    required this.ornitoId,
    required this.imageUrl,
  });

  final String speciesId;
  final String scientificName;
  final String turkishName;
  final String englishName;
  final String occurrence;
  final String? ornitoId;
  final String? imageUrl;
}

class SpeciesCatalog {
  SpeciesCatalog._(this._bySpeciesId, this._byScientificName);

  factory SpeciesCatalog.fromJson(Map<String, dynamic> source) {
    final List<dynamic> candidates =
        source['species'] as List<dynamic>? ??
        source['candidates'] as List<dynamic>? ??
        const <dynamic>[];
    final Map<String, SpeciesCatalogEntry> bySpeciesId =
        <String, SpeciesCatalogEntry>{};
    final Map<String, SpeciesCatalogEntry> byScientificName =
        <String, SpeciesCatalogEntry>{};

    for (final dynamic item in candidates) {
      if (item is! Map<String, dynamic>) continue;
      final String scientificName = (item['scientificName'] as String? ?? '')
          .trim();
      if (scientificName.isEmpty) continue;
      final String speciesId = normalizeSpeciesId(scientificName);
      final SpeciesCatalogEntry entry = SpeciesCatalogEntry(
        speciesId: speciesId,
        scientificName: scientificName,
        turkishName: (item['turkishName'] as String? ?? scientificName).trim(),
        englishName: (item['englishName'] as String? ?? scientificName).trim(),
        occurrence: (item['occurrence'] as String? ?? '').trim(),
        ornitoId: _nonEmpty(item['ornitoId'] as String?),
        imageUrl: _nonEmpty(item['imageUrl'] as String?),
      );
      bySpeciesId[speciesId] = entry;
      byScientificName[normalizeScientificName(scientificName)] = entry;
    }
    return SpeciesCatalog._(bySpeciesId, byScientificName);
  }

  final Map<String, SpeciesCatalogEntry> _bySpeciesId;
  final Map<String, SpeciesCatalogEntry> _byScientificName;

  List<SpeciesCatalogEntry> get entries =>
      List<SpeciesCatalogEntry>.unmodifiable(_bySpeciesId.values);

  static String normalizeSpeciesId(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  static String normalizeScientificName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  SpeciesCatalogEntry? find({String? speciesId, String? scientificName}) {
    final String normalizedId = normalizeSpeciesId(speciesId ?? '');
    if (normalizedId.isNotEmpty) {
      final SpeciesCatalogEntry? match = _bySpeciesId[normalizedId];
      if (match != null) return match;
    }
    final String normalizedName = normalizeScientificName(scientificName ?? '');
    return normalizedName.isEmpty ? null : _byScientificName[normalizedName];
  }

  static String? _nonEmpty(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}

class SpeciesCatalogRepository {
  SpeciesCatalogRepository._();

  static final SpeciesCatalogRepository instance = SpeciesCatalogRepository._();

  Future<SpeciesCatalog>? _catalogFuture;

  Future<SpeciesCatalog> get catalog =>
      _catalogFuture ??= _loadBundledCatalog();

  Future<String?> imageUrlFor({
    String? speciesId,
    String? scientificName,
    String? preferredUrl,
  }) async {
    final String direct = preferredUrl?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final SpeciesCatalogEntry? entry = (await catalog).find(
      speciesId: speciesId,
      scientificName: scientificName,
    );
    return entry?.imageUrl;
  }

  Future<SpeciesCatalog> _loadBundledCatalog() async {
    final String content = (await rootBundle.loadString(
      'assets/audio_catalog/turkey-birdnet-v1.json',
    )).replaceAll('\uFEFF', '');
    return SpeciesCatalog.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }
}
