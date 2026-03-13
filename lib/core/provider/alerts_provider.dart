// lib/core/providers/alerts_provider.dart
// Single source of truth for live alerts data.
// Both DashboardScreen and AlertsScreen consume this provider.
//
// Load lifecycle:
//   idle    → loadAlerts() called →
//   loading → ApiService.fetchAlerts() + GeminiService.enrichAlerts() →
//   loaded  (or error if either throws)
//
// Re-entrant safe: a second loadAlerts() call while loading is a no-op.

import 'package:flutter/foundation.dart';
import '../../shared/models/alert.dart';
import '../services/api_service.dart';

enum AlertsLoadState { idle, loading, loaded, error }

class AlertsProvider extends ChangeNotifier {
  List<FraudAlert> _alerts      = [];
  AlertsLoadState  _state       = AlertsLoadState.idle;
  String?          _errorMessage;

  List<FraudAlert> get alerts       => List.unmodifiable(_alerts);
  AlertsLoadState  get state        => _state;
  String?          get errorMessage => _errorMessage;
  bool             get isLoading    => _state == AlertsLoadState.loading;
  bool             get hasData      => _state == AlertsLoadState.loaded;

  int get openCount => _alerts.where((a) => a.isOpen).length;

  Future<void> loadAlerts() async {
    if (_state == AlertsLoadState.loading) return;
    _state        = AlertsLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // ApiService.fetchAlerts() maps ai_reason → signalMessage server-side.
      // No Gemini call needed here — the backend already handled it.
      _alerts = await ApiService.fetchAlerts();
      _state  = AlertsLoadState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _state        = AlertsLoadState.error;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    _state = AlertsLoadState.idle;
    await loadAlerts();
  }
}