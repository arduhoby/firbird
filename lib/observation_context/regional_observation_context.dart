import 'dart:math' as math;

import 'package:firbird/observation_context/ebird_context_package.dart';

enum RegionalSupportLevel { none, weak, moderate, strong }

class NearbyHotspot {
  const NearbyHotspot({required this.hotspot, required this.distanceKm});

  final EbirdHotspot hotspot;
  final double distanceKm;
}

class RegionalObservationEvidence {
  const RegionalObservationEvidence({
    required this.observation,
    required this.distanceKm,
    required this.ageDays,
  });

  final EbirdRecentObservation observation;
  final double distanceKm;
  final int ageDays;
}

class RegionalSpeciesContext {
  const RegionalSpeciesContext({
    required this.scientificName,
    required this.radiusKm,
    required this.supportLevel,
    required this.nearbyHotspots,
    required this.evidence,
    required this.sourceGeneratedAt,
  });

  final String scientificName;
  final int radiusKm;
  final RegionalSupportLevel supportLevel;
  final List<NearbyHotspot> nearbyHotspots;
  final List<RegionalObservationEvidence> evidence;
  final DateTime sourceGeneratedAt;

  NearbyHotspot? get nearestHotspot =>
      nearbyHotspots.isEmpty ? null : nearbyHotspots.first;

  bool get hasRecentSupport => evidence.isNotEmpty;
}

/// Performs all location and species matching locally against an offline
/// context package. It does not make network requests.
class RegionalObservationContextEngine {
  const RegionalObservationContextEngine(this.package);

  final EbirdContextPackage package;

  List<NearbyHotspot> nearbyHotspots({
    required double latitude,
    required double longitude,
    required int radiusKm,
  }) {
    _validateCenter(latitude, longitude);
    final double safeRadius = radiusKm.clamp(1, 50).toDouble();
    final List<NearbyHotspot> matches =
        package.hotspots
            .map(
              (EbirdHotspot hotspot) => NearbyHotspot(
                hotspot: hotspot,
                distanceKm: distanceKm(
                  latitude,
                  longitude,
                  hotspot.latitude,
                  hotspot.longitude,
                ),
              ),
            )
            .where((NearbyHotspot item) => item.distanceKm <= safeRadius)
            .toList(growable: false)
          ..sort(
            (NearbyHotspot left, NearbyHotspot right) =>
                left.distanceKm.compareTo(right.distanceKm),
          );
    return matches;
  }

  RegionalSpeciesContext contextForSpecies({
    required String scientificName,
    required double latitude,
    required double longitude,
    required int radiusKm,
    DateTime? now,
  }) {
    final int safeRadius = radiusKm.clamp(1, 50);
    final DateTime reference = (now ?? DateTime.now()).toUtc();
    final String normalizedName = scientificName.trim().toLowerCase();
    final List<RegionalObservationEvidence> evidence =
        package.recentObservations
            .where(
              (EbirdRecentObservation observation) =>
                  observation.scientificName.trim().toLowerCase() ==
                  normalizedName,
            )
            .map((EbirdRecentObservation observation) {
              final double distance = distanceKm(
                latitude,
                longitude,
                observation.latitude,
                observation.longitude,
              );
              final Duration age = reference.difference(
                observation.observedAt.toUtc(),
              );
              return RegionalObservationEvidence(
                observation: observation,
                distanceKm: distance,
                ageDays: math.max(0, age.inDays),
              );
            })
            .where(
              (RegionalObservationEvidence item) =>
                  item.distanceKm <= safeRadius &&
                  item.ageDays <= package.manifest.lookbackDays,
            )
            .toList(growable: false)
          ..sort((
            RegionalObservationEvidence left,
            RegionalObservationEvidence right,
          ) {
            final int distanceOrder = left.distanceKm.compareTo(
              right.distanceKm,
            );
            if (distanceOrder != 0) return distanceOrder;
            return left.ageDays.compareTo(right.ageDays);
          });

    return RegionalSpeciesContext(
      scientificName: scientificName,
      radiusKm: safeRadius,
      supportLevel: _supportLevel(evidence),
      nearbyHotspots: nearbyHotspots(
        latitude: latitude,
        longitude: longitude,
        radiusKm: safeRadius,
      ),
      evidence: evidence,
      sourceGeneratedAt: package.manifest.generatedAt,
    );
  }

  RegionalSupportLevel _supportLevel(
    List<RegionalObservationEvidence> evidence,
  ) {
    if (evidence.isEmpty) return RegionalSupportLevel.none;
    final RegionalObservationEvidence best = evidence.first;
    if (best.distanceKm <= 10 && best.ageDays <= 7) {
      return RegionalSupportLevel.strong;
    }
    if (best.distanceKm <= 20 && best.ageDays <= 30) {
      return RegionalSupportLevel.moderate;
    }
    return RegionalSupportLevel.weak;
  }

  static double distanceKm(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const double earthRadiusKm = 6371.0088;
    final double lat1 = _radians(latitude1);
    final double lat2 = _radians(latitude2);
    final double deltaLat = _radians(latitude2 - latitude1);
    final double deltaLon = _radians(longitude2 - longitude1);
    final double a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  static void _validateCenter(double latitude, double longitude) {
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Invalid center coordinates.');
    }
  }
}
