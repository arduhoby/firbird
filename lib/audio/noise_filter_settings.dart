import 'package:shared_preferences/shared_preferences.dart';

/// Preset noise-filter profiles selectable from the settings screen.
enum NoiseFilterPreset {
  off,
  wind,
  water,
  forest,
  custom,
}

extension NoiseFilterPresetLabel on NoiseFilterPreset {
  String get label {
    return switch (this) {
      NoiseFilterPreset.off => 'Kapalı',
      NoiseFilterPreset.wind => '🌬️ Rüzgar',
      NoiseFilterPreset.water => '💧 Dere/Su',
      NoiseFilterPreset.forest => '🌿 Orman',
      NoiseFilterPreset.custom => 'Özel',
    };
  }
}

/// Immutable settings object for the real-time noise filter chain.
///
/// [enabled]         Master on/off switch.
/// [preset]          Active preset (custom = manually adjusted sliders).
/// [windCutoffHz]    High-pass filter cutoff frequency in Hz (100–2000).
/// [waterReduction]  Spectral-subtraction strength 0.0–1.0 (maps to α 1–4).
/// [gainMultiplier]  Post-filter RMS gain boost 0.5–3.0.
class NoiseFilterSettings {
  const NoiseFilterSettings({
    this.enabled = false,
    this.preset = NoiseFilterPreset.off,
    this.windCutoffHz = 500,
    this.waterReduction = 0.0,
    this.gainMultiplier = 1.0,
  });

  final bool enabled;
  final NoiseFilterPreset preset;
  final double windCutoffHz;
  final double waterReduction;
  final double gainMultiplier;

  // ── Preset factory constructors ──────────────────────────────────────────

  /// Wind noise: strong HPF, no spectral subtraction.
  static const NoiseFilterSettings presetWind = NoiseFilterSettings(
    enabled: true,
    preset: NoiseFilterPreset.wind,
    windCutoffHz: 1000,
    waterReduction: 0.0,
    gainMultiplier: 1.0,
  );

  /// Stream / water noise: mild HPF + heavy spectral subtraction.
  static const NoiseFilterSettings presetWater = NoiseFilterSettings(
    enabled: true,
    preset: NoiseFilterPreset.water,
    windCutoffHz: 300,
    waterReduction: 0.8,
    gainMultiplier: 1.2,
  );

  /// Forest (mixed): moderate HPF + mild spectral subtraction.
  static const NoiseFilterSettings presetForest = NoiseFilterSettings(
    enabled: true,
    preset: NoiseFilterPreset.forest,
    windCutoffHz: 500,
    waterReduction: 0.4,
    gainMultiplier: 1.0,
  );

  static const NoiseFilterSettings off = NoiseFilterSettings(
    enabled: false,
    preset: NoiseFilterPreset.off,
  );

  // ── Persistence ──────────────────────────────────────────────────────────

  static const String _kEnabled = 'noise_filter_enabled';
  static const String _kPreset = 'noise_filter_preset';
  static const String _kCutoff = 'noise_filter_cutoff_hz';
  static const String _kWater = 'noise_filter_water';
  static const String _kGain = 'noise_filter_gain';

  static Future<NoiseFilterSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool enabled = prefs.getBool(_kEnabled) ?? false;
    final int presetIndex = prefs.getInt(_kPreset) ?? 0;
    final double cutoff = prefs.getDouble(_kCutoff) ?? 500;
    final double water = prefs.getDouble(_kWater) ?? 0.0;
    final double gain = prefs.getDouble(_kGain) ?? 1.0;
    return NoiseFilterSettings(
      enabled: enabled,
      preset: NoiseFilterPreset.values[presetIndex.clamp(
        0,
        NoiseFilterPreset.values.length - 1,
      )],
      windCutoffHz: cutoff.clamp(100, 2000),
      waterReduction: water.clamp(0.0, 1.0),
      gainMultiplier: gain.clamp(0.5, 3.0),
    );
  }

  Future<void> save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
    await prefs.setInt(_kPreset, preset.index);
    await prefs.setDouble(_kCutoff, windCutoffHz);
    await prefs.setDouble(_kWater, waterReduction);
    await prefs.setDouble(_kGain, gainMultiplier);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  NoiseFilterSettings copyWith({
    bool? enabled,
    NoiseFilterPreset? preset,
    double? windCutoffHz,
    double? waterReduction,
    double? gainMultiplier,
  }) {
    return NoiseFilterSettings(
      enabled: enabled ?? this.enabled,
      preset: preset ?? this.preset,
      windCutoffHz: windCutoffHz ?? this.windCutoffHz,
      waterReduction: waterReduction ?? this.waterReduction,
      gainMultiplier: gainMultiplier ?? this.gainMultiplier,
    );
  }

  /// Spectral subtraction oversubtraction factor α (1.0 – 4.0).
  double get spectralAlpha => 1.0 + waterReduction * 3.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoiseFilterSettings &&
          enabled == other.enabled &&
          preset == other.preset &&
          windCutoffHz == other.windCutoffHz &&
          waterReduction == other.waterReduction &&
          gainMultiplier == other.gainMultiplier;

  @override
  int get hashCode => Object.hash(
    enabled,
    preset,
    windCutoffHz,
    waterReduction,
    gainMultiplier,
  );
}
