import 'package:firbird/observation_context/ebird_context_package.dart';
import 'package:firbird/observation_context/ebird_observation_cache.dart';
import 'package:flutter/services.dart';

class EbirdObservationData {
  const EbirdObservationData({
    required this.hotspots,
    required this.observations,
    this.snapshot,
  });

  final List<EbirdHotspot> hotspots;
  final List<EbirdRecentObservation> observations;
  final EbirdObservationSnapshot? snapshot;
}

/// Canonical source for the bundled Türkiye archive plus the latest nearby
/// eBird download. Maps, evidence scoring and species details reuse this data.
class EbirdObservationRepository {
  EbirdObservationRepository({
    EbirdObservationCache? cache,
    AssetBundle? assetBundle,
  }) : _cache = cache ?? EbirdObservationCache(),
       _assetBundle = assetBundle ?? rootBundle;

  final EbirdObservationCache _cache;
  final AssetBundle _assetBundle;

  Future<EbirdObservationData> load() async {
    final EbirdContextPackage package = EbirdContextPackage.fromJsonStrings(
      manifest: await _assetBundle.loadString(
        'assets/ebird_context/manifest.json',
      ),
      hotspots: await _assetBundle.loadString(
        'assets/ebird_context/hotspots.json',
      ),
      recentObservations: await _assetBundle.loadString(
        'assets/ebird_context/recent_observations.json',
      ),
    );
    final EbirdObservationSnapshot? snapshot = await _cache.load();
    final List<EbirdRecentObservation> observations = snapshot == null
        ? package.recentObservations
        : mergeObservations(package.recentObservations, snapshot.observations);
    return EbirdObservationData(
      hotspots: _includeObservationLocations(package.hotspots, observations),
      observations: observations,
      snapshot: snapshot,
    );
  }

  static List<EbirdHotspot> _includeObservationLocations(
    List<EbirdHotspot> hotspots,
    List<EbirdRecentObservation> observations,
  ) {
    final Map<String, EbirdHotspot> byId = <String, EbirdHotspot>{
      for (final EbirdHotspot hotspot in hotspots) hotspot.id: hotspot,
    };
    for (final EbirdRecentObservation observation in observations) {
      byId.putIfAbsent(
        observation.locationId,
        () => EbirdHotspot(
          id: observation.locationId,
          name: observation.locationName,
          latitude: observation.latitude,
          longitude: observation.longitude,
          latestObservationAt: observation.observedAt,
        ),
      );
    }
    return byId.values.toList(growable: false);
  }

  static List<EbirdRecentObservation> mergeObservations(
    List<EbirdRecentObservation> archived,
    List<EbirdRecentObservation> live,
  ) {
    final Map<String, EbirdRecentObservation> archivedBySpecies =
        <String, EbirdRecentObservation>{
          for (final EbirdRecentObservation observation in archived)
            _mergeKey(observation): observation,
        };
    final List<EbirdRecentObservation> resolvedLive = live
        .map((EbirdRecentObservation observation) {
          if (observation.observerName?.trim().isNotEmpty == true) {
            return observation;
          }
          final EbirdRecentObservation? archivedObservation =
              archivedBySpecies[_mergeKey(observation)];
          if (archivedObservation?.observerName?.trim().isNotEmpty != true) {
            return observation;
          }
          return observation.copyWith(
            observerName: archivedObservation!.observerName,
            observerIdentityFromArchive: true,
          );
        })
        .toList(growable: false);
    final Set<String> liveKeys = resolvedLive.map(_mergeKey).toSet();
    return <EbirdRecentObservation>[
      ...archived.where(
        (EbirdRecentObservation observation) =>
            !liveKeys.contains(_mergeKey(observation)),
      ),
      ...resolvedLive,
    ];
  }

  static String _mergeKey(EbirdRecentObservation observation) =>
      '${observation.locationId}|${observation.scientificName.toLowerCase()}';
}
