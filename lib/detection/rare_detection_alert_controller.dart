import 'dart:async';

import 'package:flutter/foundation.dart';

/// Owns rare-detection alert state for one listening session.
///
/// The detected set is never tied to list visibility, so scrolling a card out
/// of view cannot erase the session report. A verdict resolves the visual
/// alert but intentionally keeps the species in the report.
class RareDetectionAlertController extends ChangeNotifier {
  RareDetectionAlertController({
    this.interval = const Duration(seconds: 15),
    this.pulseDuration = const Duration(milliseconds: 900),
  });

  final Duration interval;
  final Duration pulseDuration;
  final Set<String> _detectedSpecies = <String>{};
  final Set<String> _unresolvedSpecies = <String>{};
  final Set<String> _resolvedSpecies = <String>{};
  Timer? _intervalTimer;
  Timer? _pulseTimer;
  bool _isPulseVisible = false;

  int get detectedSpeciesCount => _detectedSpecies.length;
  bool get isPulseVisible => _isPulseVisible;

  bool isUnresolved(String speciesKey) =>
      _unresolvedSpecies.contains(_normalize(speciesKey));

  void register(String speciesKey) {
    final String key = _normalize(speciesKey);
    if (key.isEmpty) return;
    final bool isNewDetection = _detectedSpecies.add(key);
    final bool isNewAlert =
        !_resolvedSpecies.contains(key) && _unresolvedSpecies.add(key);
    if (!isNewDetection && !isNewAlert) return;
    if (!isNewAlert) {
      notifyListeners();
      return;
    }
    _showPulse();
    _ensureTimer();
  }

  void resolve(String speciesKey) {
    final String key = _normalize(speciesKey);
    _resolvedSpecies.add(key);
    if (!_unresolvedSpecies.remove(key)) return;
    if (_unresolvedSpecies.isEmpty) {
      _intervalTimer?.cancel();
      _intervalTimer = null;
      _pulseTimer?.cancel();
      _pulseTimer = null;
      _isPulseVisible = false;
    }
    notifyListeners();
  }

  void _ensureTimer() {
    if (_intervalTimer != null || _unresolvedSpecies.isEmpty) return;
    _intervalTimer = Timer.periodic(interval, (_) => _showPulse());
  }

  void _showPulse() {
    _pulseTimer?.cancel();
    _isPulseVisible = true;
    notifyListeners();
    _pulseTimer = Timer(pulseDuration, () {
      _isPulseVisible = false;
      notifyListeners();
    });
  }

  String _normalize(String value) => value.trim().toLowerCase();

  @override
  void dispose() {
    _intervalTimer?.cancel();
    _pulseTimer?.cancel();
    super.dispose();
  }
}
