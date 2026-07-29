import 'dart:math' as math;

enum SolarPhase {
  daylight,
  civilTwilight,
  nauticalTwilight,
  astronomicalTwilight,
  night,
  unavailable,
}

enum BirdActivityProfile { nocturnal, flexible, diurnal, unknown }

class TemporalDetectionContext {
  const TemporalDetectionContext({
    required this.phase,
    required this.profile,
    required this.confidenceMultiplier,
  });

  final SolarPhase phase;
  final BirdActivityProfile profile;
  final double confidenceMultiplier;

  bool get isAvailable => phase != SolarPhase.unavailable;
  bool get hasSpeciesProfile => profile != BirdActivityProfile.unknown;

  String get activityLabel {
    final String label = switch (profile) {
      BirdActivityProfile.nocturnal => 'gececi',
      BirdActivityProfile.flexible => 'gece de ötebilir',
      BirdActivityProfile.diurnal => 'gündüzcül',
      BirdActivityProfile.unknown => '',
    };
    if (label.isEmpty || confidenceMultiplier >= 0.99) return label;
    return '$label · %${(confidenceMultiplier * 100).round()}';
  }

  String get compactLabel {
    final String phaseLabel = switch (phase) {
      SolarPhase.daylight => 'G\u00FCnd\u00FCz',
      SolarPhase.civilTwilight => 'Sivil alacakaranl\u0131k',
      SolarPhase.nauticalTwilight ||
      SolarPhase.astronomicalTwilight => 'Alacakaranl\u0131k',
      SolarPhase.night => 'Gece',
      SolarPhase.unavailable => 'Ba\u011Flam yok',
    };
    final String profileLabel = switch (profile) {
      BirdActivityProfile.nocturnal => 'gececil',
      BirdActivityProfile.flexible => 'gece \u00F6tebilir',
      BirdActivityProfile.diurnal => 'g\u00FCnd\u00FCzc\u00FCl',
      BirdActivityProfile.unknown => '',
    };
    if (!hasSpeciesProfile || confidenceMultiplier >= 0.99) {
      return '$phaseLabel${profileLabel.isEmpty ? '' : ' · $profileLabel'}';
    }
    return '$phaseLabel · $profileLabel · %${(confidenceMultiplier * 100).round()}';
  }

  String get displayLabel {
    if (!isAvailable) return 'Zaman ba\u011Flam\u0131 yok';
    final String phaseLabel = switch (phase) {
      SolarPhase.daylight => 'G\u00FCne\u015F durumu: g\u00FCnd\u00FCz',
      SolarPhase.civilTwilight =>
        'G\u00FCne\u015F durumu: sivil alacakaranl\u0131k',
      SolarPhase.nauticalTwilight =>
        'G\u00FCne\u015F durumu: denizcilik alacakaranl\u0131\u011F\u0131',
      SolarPhase.astronomicalTwilight =>
        'G\u00FCne\u015F durumu: astronomik alacakaranl\u0131k',
      SolarPhase.night => 'G\u00FCne\u015F durumu: gece',
      SolarPhase.unavailable => 'Zaman ba\u011Flam\u0131 yok',
    };
    final String profileLabel = switch (profile) {
      BirdActivityProfile.nocturnal => 't\u00FCr gececil',
      BirdActivityProfile.flexible => 't\u00FCr gece de \u00F6tebilir',
      BirdActivityProfile.diurnal => 't\u00FCr g\u00FCnd\u00FCzc\u00FCl',
      BirdActivityProfile.unknown => '',
    };
    if (!hasSpeciesProfile) return phaseLabel;
    if (confidenceMultiplier >= 0.99) return '$phaseLabel · $profileLabel';
    return '$phaseLabel · $profileLabel · yumu\u015Fak a\u011F\u0131rl\u0131k %${(confidenceMultiplier * 100).round()}';
  }
}

/// Offline solar elevation approximation based on the NOAA solar calculation
/// equations. The device clock supplies the instant; the date and GPS
/// coordinates determine the real local sunrise, sunset, and twilight.
SolarPhase solarPhaseAt({
  required DateTime moment,
  required double latitude,
  required double longitude,
}) {
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude.abs() > 90 ||
      longitude.abs() > 180) {
    return SolarPhase.unavailable;
  }
  final DateTime utc = moment.toUtc();
  final double julianDay = utc.millisecondsSinceEpoch / 86400000 + 2440587.5;
  final double daysSinceJ2000 = julianDay - 2451545.0;
  final double julianDayAtMidnight = (julianDay - 0.5).floor() + 0.5;
  final double daysAtMidnight = julianDayAtMidnight - 2451545.0;
  final double meanLongitude = _normaliseDegrees(
    280.46 + 0.9856474 * daysSinceJ2000,
  );
  final double meanAnomaly = _normaliseDegrees(
    357.528 + 0.9856003 * daysSinceJ2000,
  );
  final double eclipticLongitude =
      meanLongitude +
      1.915 * math.sin(_radians(meanAnomaly)) +
      0.020 * math.sin(_radians(2 * meanAnomaly));
  final double obliquity = 23.439 - 0.0000004 * daysSinceJ2000;
  final double declination = math.asin(
    math.sin(_radians(obliquity)) * math.sin(_radians(eclipticLongitude)),
  );
  final double utcHours = utc.hour + utc.minute / 60 + utc.second / 3600;
  final double siderealHours =
      6.697375 + 0.0657098242 * daysAtMidnight + 1.00273790935 * utcHours;
  final double rightAscension = math.atan2(
    math.cos(_radians(obliquity)) * math.sin(_radians(eclipticLongitude)),
    math.cos(_radians(eclipticLongitude)),
  );
  final double localSiderealAngle = _radians(
    _normaliseDegrees(siderealHours * 15 + longitude),
  );
  final double hourAngle = _normaliseRadians(
    localSiderealAngle - rightAscension,
  );
  final double latitudeRadians = _radians(latitude);
  final double elevation =
      math.asin(
        math.sin(latitudeRadians) * math.sin(declination) +
            math.cos(latitudeRadians) *
                math.cos(declination) *
                math.cos(hourAngle),
      ) *
      180 /
      math.pi;

  if (elevation >= 0) return SolarPhase.daylight;
  if (elevation >= -6) return SolarPhase.civilTwilight;
  if (elevation >= -12) return SolarPhase.nauticalTwilight;
  if (elevation >= -18) return SolarPhase.astronomicalTwilight;
  return SolarPhase.night;
}

TemporalDetectionContext temporalContextForSpecies({
  required String scientificName,
  required DateTime moment,
  double? latitude,
  double? longitude,
}) {
  if (latitude == null || longitude == null) {
    return const TemporalDetectionContext(
      phase: SolarPhase.unavailable,
      profile: BirdActivityProfile.unknown,
      confidenceMultiplier: 1,
    );
  }
  final SolarPhase phase = solarPhaseAt(
    moment: moment,
    latitude: latitude,
    longitude: longitude,
  );
  final BirdActivityProfile profile = _activityProfileFor(scientificName);
  final double multiplier = switch ((profile, phase)) {
    (_, SolarPhase.unavailable) => 1,
    (BirdActivityProfile.nocturnal, SolarPhase.daylight) => 0.55,
    (BirdActivityProfile.nocturnal, SolarPhase.civilTwilight) => 0.85,
    (BirdActivityProfile.nocturnal, _) => 1,
    (BirdActivityProfile.flexible, SolarPhase.night) => 0.85,
    (BirdActivityProfile.flexible, SolarPhase.astronomicalTwilight) => 0.90,
    (BirdActivityProfile.flexible, _) => 1,
    (BirdActivityProfile.diurnal, SolarPhase.night) => 0.50,
    (BirdActivityProfile.diurnal, SolarPhase.astronomicalTwilight) => 0.60,
    (BirdActivityProfile.diurnal, SolarPhase.nauticalTwilight) => 0.75,
    (BirdActivityProfile.diurnal, SolarPhase.civilTwilight) => 0.90,
    (BirdActivityProfile.diurnal, _) => 1,
    (BirdActivityProfile.unknown, _) => 1,
  };
  return TemporalDetectionContext(
    phase: phase,
    profile: profile,
    confidenceMultiplier: multiplier,
  );
}

BirdActivityProfile _activityProfileFor(String scientificName) {
  final String name = scientificName.trim().toLowerCase();
  const Set<String> nocturnalGenera = <String>{
    'tyto',
    'bubo',
    'strix',
    'otus',
    'athene',
    'asio',
    'caprimulgus',
  };
  const Set<String> diurnalGenera = <String>{
    'dendrocopos',
    'dryobates',
    'picus',
    'jynx',
    'accipiter',
    'aquila',
    'buteo',
    'falco',
    'circaetus',
    'circus',
    'elanus',
    'hieraaetus',
    'milvus',
    'neophron',
    'pernis',
    'carduelis',
    'chloris',
    'fringilla',
    'linaria',
    'serinus',
    'spinus',
  };
  final String genus = name.split(RegExp(r'\s+')).first;
  if (nocturnalGenera.contains(genus)) return BirdActivityProfile.nocturnal;
  if (diurnalGenera.contains(genus)) return BirdActivityProfile.diurnal;
  if (name == 'luscinia megarhynchos' ||
      name == 'erithacus rubecula' ||
      name == 'phoenicurus ochruros' ||
      genus == 'acrocephalus') {
    return BirdActivityProfile.flexible;
  }
  return BirdActivityProfile.unknown;
}

double _radians(double degrees) => degrees * math.pi / 180;
double _normaliseDegrees(double degrees) => (degrees % 360 + 360) % 360;
double _normaliseRadians(double radians) =>
    (radians + math.pi) % (2 * math.pi) - math.pi;
