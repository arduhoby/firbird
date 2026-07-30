import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AlgorithmSettings {
  const AlgorithmSettings({
    required this.timeMismatchPenalty,
    required this.nearbySameTimeSupport,
    required this.seasonSupport,
    required this.deviceConfirmedSupport,
    required this.deviceRejectedPenalty,
  });

  static const String version = 'evidence-v1';
  static const AlgorithmSettings defaults = AlgorithmSettings(
    timeMismatchPenalty: 30,
    nearbySameTimeSupport: 30,
    seasonSupport: 10,
    deviceConfirmedSupport: 15,
    deviceRejectedPenalty: 25,
  );

  final int timeMismatchPenalty;
  final int nearbySameTimeSupport;
  final int seasonSupport;
  final int deviceConfirmedSupport;
  final int deviceRejectedPenalty;

  AlgorithmSettings copyWith({
    int? timeMismatchPenalty,
    int? nearbySameTimeSupport,
    int? seasonSupport,
    int? deviceConfirmedSupport,
    int? deviceRejectedPenalty,
  }) => AlgorithmSettings(
    timeMismatchPenalty: timeMismatchPenalty ?? this.timeMismatchPenalty,
    nearbySameTimeSupport: nearbySameTimeSupport ?? this.nearbySameTimeSupport,
    seasonSupport: seasonSupport ?? this.seasonSupport,
    deviceConfirmedSupport:
        deviceConfirmedSupport ?? this.deviceConfirmedSupport,
    deviceRejectedPenalty: deviceRejectedPenalty ?? this.deviceRejectedPenalty,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'timeMismatchPenalty': timeMismatchPenalty,
    'nearbySameTimeSupport': nearbySameTimeSupport,
    'seasonSupport': seasonSupport,
    'deviceConfirmedSupport': deviceConfirmedSupport,
    'deviceRejectedPenalty': deviceRejectedPenalty,
  };

  factory AlgorithmSettings.fromJson(Map<String, dynamic> json) =>
      AlgorithmSettings(
        timeMismatchPenalty:
            (json['timeMismatchPenalty'] as num?)?.toInt() ??
            defaults.timeMismatchPenalty,
        nearbySameTimeSupport:
            (json['nearbySameTimeSupport'] as num?)?.toInt() ??
            defaults.nearbySameTimeSupport,
        seasonSupport:
            (json['seasonSupport'] as num?)?.toInt() ?? defaults.seasonSupport,
        deviceConfirmedSupport:
            (json['deviceConfirmedSupport'] as num?)?.toInt() ??
            defaults.deviceConfirmedSupport,
        deviceRejectedPenalty:
            (json['deviceRejectedPenalty'] as num?)?.toInt() ??
            defaults.deviceRejectedPenalty,
      );
}

class AlgorithmSettingsRepository {
  AlgorithmSettingsRepository({Future<SharedPreferences> Function()? loader})
    : _loader = loader ?? SharedPreferences.getInstance;

  static const String _storageKey = 'detection_algorithm_settings_v1';
  final Future<SharedPreferences> Function() _loader;

  Future<AlgorithmSettings> load() async {
    final String? raw = (await _loader()).getString(_storageKey);
    if (raw == null) return AlgorithmSettings.defaults;
    try {
      return AlgorithmSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return AlgorithmSettings.defaults;
    }
  }

  Future<void> save(AlgorithmSettings settings) async {
    await (await _loader()).setString(
      _storageKey,
      jsonEncode(settings.toJson()),
    );
  }

  Future<void> reset() => save(AlgorithmSettings.defaults);
}
