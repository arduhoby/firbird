import 'dart:math' as math;

import 'package:firbird/detection/algorithm_settings.dart';
import 'package:firbird/detection/detection_feedback_repository.dart';
import 'package:firbird/detection/detection_record.dart';
import 'package:firbird/inference/temporal_detection_context.dart';
import 'package:firbird/observation_context/ebird_context_package.dart';
import 'package:firbird/observation_context/ebird_observation_cache.dart';

class DetectionEvidenceService {
  DetectionEvidenceService({
    AlgorithmSettingsRepository? settingsRepository,
    DetectionFeedbackRepository? feedbackRepository,
    EbirdObservationCache? observationCache,
  }) : settingsRepository = settingsRepository ?? AlgorithmSettingsRepository(),
       feedbackRepository = feedbackRepository ?? DetectionFeedbackRepository(),
       observationCache = observationCache ?? EbirdObservationCache();

  final AlgorithmSettingsRepository settingsRepository;
  final DetectionFeedbackRepository feedbackRepository;
  final EbirdObservationCache observationCache;

  Future<DetectionRecord> enrich(DetectionRecord record) async {
    final AlgorithmSettings settings = await settingsRepository.load();
    final DetectionFeedbackSummary feedback = await feedbackRepository
        .summaryFor(record.scientificName);
    final EbirdObservationSnapshot? snapshot = await observationCache.load();
    final List<DetectionEvidenceFactor> factors = <DetectionEvidenceFactor>[];

    factors.add(
      DetectionEvidenceFactor(
        id: 'model',
        title: 'Ses modeli',
        detail:
            'Model bu ses ile ${record.turkishName} arasında %${(record.modelConfidence * 100).round()} benzerlik hesapladı. Tek başına kesin teşhis değildir.',
        direction: EvidenceDirection.neutral,
        points: 0,
        sourceLabel: record.modelVersion ?? 'Cihaz içi ses modeli',
      ),
    );

    final TemporalDetectionContext temporal = temporalContextForSpecies(
      scientificName: record.scientificName,
      moment: record.detectedAt,
      latitude: record.latitude,
      longitude: record.longitude,
    );
    final int timePoints = temporal.confidenceMultiplier < 0.7
        ? -settings.timeMismatchPenalty
        : temporal.confidenceMultiplier < 0.99
        ? -(settings.timeMismatchPenalty / 2).round()
        : 0;
    factors.add(
      DetectionEvidenceFactor(
        id: 'time',
        title: 'Saat ve etkinlik',
        detail: temporal.isAvailable
            ? temporal.displayLabel
            : 'Konum olmadığı için güneş ve etkinlik saati değerlendirilemedi.',
        direction: !temporal.isAvailable || !temporal.hasSpeciesProfile
            ? EvidenceDirection.unavailable
            : timePoints < 0
            ? EvidenceDirection.weakens
            : EvidenceDirection.neutral,
        points: timePoints,
        sourceLabel: 'Cihaz saati · güneş konumu · tür etkinlik profili',
      ),
    );

    final List<EbirdRecentObservation> nearby = _nearbySpeciesObservations(
      record,
      snapshot,
    );
    final List<EbirdRecentObservation> sameTime = nearby
        .where(
          (EbirdRecentObservation item) =>
              _circularHourDifference(
                item.observedAt.toLocal(),
                record.detectedAt.toLocal(),
              ) <=
              2,
        )
        .toList(growable: false);
    final int nearbyPoints = sameTime.length >= 2
        ? settings.nearbySameTimeSupport
        : sameTime.length == 1
        ? (settings.nearbySameTimeSupport / 2).round()
        : 0;
    factors.add(
      DetectionEvidenceFactor(
        id: 'nearby_time',
        title: 'Yakındaki aynı saat kayıtları',
        detail: snapshot == null
            ? 'Kullanıcı henüz güncel bir eBird çevre verisi indirmedi.'
            : record.latitude == null || record.longitude == null
            ? 'Tespit konumu olmadığı için indirilen eBird verisiyle mesafe karşılaştırılamadı.'
            : sameTime.isEmpty
            ? '${snapshot.radiusKm} km verisinde bu türe ait ±2 saat aralığında kayıt bulunamadı.'
            : '${snapshot.radiusKm} km çevrede ±2 saat aralığında ${sameTime.length} varlık kaydı bulundu. Bu kayıtlar kuşun ses çıkardığını değil, o saatte gözlendiğini gösterir.',
        direction: nearbyPoints > 0
            ? EvidenceDirection.supports
            : snapshot == null
            ? EvidenceDirection.unavailable
            : EvidenceDirection.neutral,
        points: nearbyPoints,
        sourceLabel: snapshot == null
            ? 'eBird verisi yok'
            : 'eBird API · ${_ageLabel(snapshot.fetchedAt)}',
      ),
    );

    final int seasonalCount = nearby
        .where(
          (EbirdRecentObservation item) =>
              _season(item.observedAt.month) ==
              _season(record.detectedAt.month),
        )
        .length;
    final int seasonPoints = seasonalCount > 0 ? settings.seasonSupport : 0;
    factors.add(
      DetectionEvidenceFactor(
        id: 'season',
        title: 'Mevsim uyumu',
        detail: snapshot == null
            ? 'Mevsim karşılaştırması için güncel çevre verisi yok.'
            : seasonalCount > 0
            ? 'Yakın çevrede aynı mevsime ait $seasonalCount kayıt bulundu.'
            : 'İndirilen yakın çevre verisinde aynı mevsime ait kayıt bulunamadı; bu yokluk kanıtı değildir.',
        direction: seasonPoints > 0
            ? EvidenceDirection.supports
            : snapshot == null
            ? EvidenceDirection.unavailable
            : EvidenceDirection.neutral,
        points: seasonPoints,
        sourceLabel: 'eBird gözlem tarihleri',
      ),
    );

    final int devicePoints = feedback.confirmedCount > feedback.rejectedCount
        ? settings.deviceConfirmedSupport
        : feedback.rejectedCount > feedback.confirmedCount
        ? -settings.deviceRejectedPenalty
        : 0;
    factors.add(
      DetectionEvidenceFactor(
        id: 'device_history',
        title: 'Bu cihazdaki doğrulamalar',
        detail:
            '${feedback.confirmedCount} doğru, ${feedback.rejectedCount} yanlış kullanıcı değerlendirmesi kayıtlı.',
        direction: devicePoints > 0
            ? EvidenceDirection.supports
            : devicePoints < 0
            ? EvidenceDirection.weakens
            : EvidenceDirection.neutral,
        points: devicePoints,
        sourceLabel: 'FirBird cihaz hafızası',
      ),
    );

    final int adjustment = factors.fold<int>(
      0,
      (int total, DetectionEvidenceFactor item) => total + item.points,
    );
    final int modelScore = (record.modelConfidence * 100).round().clamp(0, 100);
    final int finalScore = (modelScore + adjustment).clamp(0, 100);
    return record.copyWith(
      evidence: DetectionEvidenceBundle(
        modelScore: modelScore,
        contextAdjustment: adjustment,
        finalScore: finalScore,
        algorithmVersion: AlgorithmSettings.version,
        factors: factors,
      ),
    );
  }

  Future<DetectionRecord> recordVerdict(
    DetectionRecord record,
    DetectionVerdict verdict,
  ) async {
    await feedbackRepository.record(record, verdict);
    return enrich(record.copyWith(verdict: verdict));
  }

  List<EbirdRecentObservation> _nearbySpeciesObservations(
    DetectionRecord record,
    EbirdObservationSnapshot? snapshot,
  ) {
    final double? latitude = record.latitude;
    final double? longitude = record.longitude;
    if (snapshot == null || latitude == null || longitude == null) {
      return const <EbirdRecentObservation>[];
    }
    final String species = record.scientificName.trim().toLowerCase();
    return snapshot.observations
        .where(
          (EbirdRecentObservation item) =>
              item.scientificName.trim().toLowerCase() == species &&
              _distanceKm(latitude, longitude, item.latitude, item.longitude) <=
                  snapshot.radiusKm,
        )
        .toList(growable: false);
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371;
    final double dLat = _radians(lat2 - lat1);
    final double dLon = _radians(lon2 - lon1);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _radians(double value) => value * math.pi / 180;

  int _circularHourDifference(DateTime a, DateTime b) {
    final int minutesA = a.hour * 60 + a.minute;
    final int minutesB = b.hour * 60 + b.minute;
    final int raw = (minutesA - minutesB).abs();
    return math.min(raw, 1440 - raw) ~/ 60;
  }

  int _season(int month) {
    if (month == 12 || month <= 2) return 0;
    if (month <= 5) return 1;
    if (month <= 8) return 2;
    return 3;
  }

  String _ageLabel(DateTime fetchedAt) {
    final int days = DateTime.now().difference(fetchedAt.toLocal()).inDays;
    return days <= 0 ? 'bugün indirildi' : '$days gün önce indirildi';
  }
}
