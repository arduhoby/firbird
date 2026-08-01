import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'noise_filter_settings.dart';

/// Async notifier that loads [NoiseFilterSettings] from SharedPreferences and
/// exposes mutations. Both the settings screen and the live-recording screen
/// watch this provider so changes are immediately reflected without a restart.
class NoiseFilterNotifier extends AsyncNotifier<NoiseFilterSettings> {
  @override
  Future<NoiseFilterSettings> build() => NoiseFilterSettings.load();

  /// Persists [settings] and updates the state immediately.
  /// Named [save] to avoid shadowing the Riverpod base-class [update] method.
  Future<void> save(NoiseFilterSettings settings) async {
    state = AsyncData(settings);
    await settings.save();
  }

  Future<void> toggleEnabled() async {
    final NoiseFilterSettings current =
        state.value ?? NoiseFilterSettings.off;
    await save(current.copyWith(enabled: !current.enabled));
  }

  Future<void> applyPreset(NoiseFilterPreset preset) async {
    final NoiseFilterSettings next = switch (preset) {
      NoiseFilterPreset.wind => NoiseFilterSettings.presetWind,
      NoiseFilterPreset.water => NoiseFilterSettings.presetWater,
      NoiseFilterPreset.forest => NoiseFilterSettings.presetForest,
      NoiseFilterPreset.off => NoiseFilterSettings.off,
      NoiseFilterPreset.custom =>
        (state.value ?? NoiseFilterSettings.off).copyWith(
          preset: NoiseFilterPreset.custom,
        ),
    };
    await save(next);
  }

  Future<void> setWindCutoff(double hz) async {
    final NoiseFilterSettings current =
        state.value ?? NoiseFilterSettings.off;
    await save(
      current.copyWith(windCutoffHz: hz, preset: NoiseFilterPreset.custom),
    );
  }

  Future<void> setWaterReduction(double value) async {
    final NoiseFilterSettings current =
        state.value ?? NoiseFilterSettings.off;
    await save(
      current.copyWith(waterReduction: value, preset: NoiseFilterPreset.custom),
    );
  }

  Future<void> setGain(double value) async {
    final NoiseFilterSettings current =
        state.value ?? NoiseFilterSettings.off;
    await save(
      current.copyWith(gainMultiplier: value, preset: NoiseFilterPreset.custom),
    );
  }
}

final AsyncNotifierProvider<NoiseFilterNotifier, NoiseFilterSettings>
noiseFilterProvider =
    AsyncNotifierProvider<NoiseFilterNotifier, NoiseFilterSettings>(
  NoiseFilterNotifier.new,
);
