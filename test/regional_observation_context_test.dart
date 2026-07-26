import 'package:firbird/observation_context/ebird_context_package.dart';
import 'package:firbird/observation_context/regional_observation_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final EbirdContextPackage package = EbirdContextPackage(
    manifest: EbirdContextManifest(
      schemaVersion: 1,
      packageId: 'turkey-ebird-context',
      version: '2026.07.26',
      regionCode: 'TR',
      generatedAt: DateTime.utc(2026, 7, 26, 12),
      lookbackDays: 30,
      hotspotCount: 3,
      recentObservationCount: 2,
      hotspotsFile: 'hotspots.json',
      recentObservationsFile: 'recent_observations.json',
      sources: const <EbirdContextSource>[],
    ),
    hotspots: const <EbirdHotspot>[
      EbirdHotspot(
        id: 'near',
        name: 'Yakın Nokta',
        latitude: 40.000,
        longitude: 29.050,
      ),
      EbirdHotspot(
        id: 'middle',
        name: 'Orta Nokta',
        latitude: 40.000,
        longitude: 29.250,
      ),
      EbirdHotspot(
        id: 'far',
        name: 'Uzak Nokta',
        latitude: 40.000,
        longitude: 30.000,
      ),
    ],
    recentObservations: <EbirdRecentObservation>[
      EbirdRecentObservation(
        speciesCode: 'barswa',
        scientificName: 'Hirundo rustica',
        commonName: 'Barn Swallow',
        locationId: 'near',
        locationName: 'Yakın Nokta',
        observedAt: DateTime.utc(2026, 7, 24, 9),
        latitude: 40.000,
        longitude: 29.050,
        count: 3,
        reviewed: true,
      ),
      EbirdRecentObservation(
        speciesCode: 'eucdov',
        scientificName: 'Streptopelia decaocto',
        commonName: 'Eurasian Collared-Dove',
        locationId: 'far',
        locationName: 'Uzak Nokta',
        observedAt: DateTime.utc(2026, 7, 25, 9),
        latitude: 40.000,
        longitude: 30.000,
        reviewed: false,
      ),
    ],
  );

  final RegionalObservationContextEngine engine =
      RegionalObservationContextEngine(package);

  test('sorts hotspots by distance and respects radius', () {
    final List<NearbyHotspot> nearby = engine.nearbyHotspots(
      latitude: 40,
      longitude: 29,
      radiusKm: 50,
    );

    expect(nearby.map((NearbyHotspot item) => item.hotspot.id), <String>[
      'near',
      'middle',
    ]);
    expect(nearby.first.distanceKm, closeTo(4.26, 0.2));
  });

  test('returns strong recent support for a nearby matching species', () {
    final RegionalSpeciesContext context = engine.contextForSpecies(
      scientificName: 'hirundo RUSTICA',
      latitude: 40,
      longitude: 29,
      radiusKm: 20,
      now: DateTime.utc(2026, 7, 26, 12),
    );

    expect(context.supportLevel, RegionalSupportLevel.strong);
    expect(context.evidence, hasLength(1));
    expect(context.nearestHotspot?.hotspot.id, 'near');
    expect(context.sourceGeneratedAt, DateTime.utc(2026, 7, 26, 12));
  });

  test('does not turn an out-of-radius observation into support', () {
    final RegionalSpeciesContext context = engine.contextForSpecies(
      scientificName: 'Streptopelia decaocto',
      latitude: 40,
      longitude: 29,
      radiusKm: 20,
      now: DateTime.utc(2026, 7, 26, 12),
    );

    expect(context.supportLevel, RegionalSupportLevel.none);
    expect(context.evidence, isEmpty);
  });

  test('calculates a known approximate distance', () {
    final double distance = RegionalObservationContextEngine.distanceKm(
      41.0082,
      28.9784,
      40.7654,
      29.9408,
    );

    expect(distance, closeTo(85, 3));
  });
}
