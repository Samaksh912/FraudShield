// lib/core/provider/dashboard_provider.dart
// Fetches dashboard KPIs, fraud trend, domain split, and risk distribution
// from /v1/dashboard. Falls back to MockData on error.

import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../utils/mock_data.dart';

enum DashboardLoadState { idle, loading, loaded, error }

class DashboardProvider extends ChangeNotifier {
  DashboardLoadState _state = DashboardLoadState.idle;
  String? _errorMessage;

  // KPI stats
  Map<String, dynamic> _stats = {};
  // 7-day fraud trend
  List<Map<String, dynamic>> _fraudTrend = [];
  // Domain split percentages
  Map<String, double> _domainSplit = {};
  // Risk distribution bands
  List<Map<String, dynamic>> _riskDistribution = [];

  DashboardLoadState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == DashboardLoadState.loading;
  bool get hasData => _state == DashboardLoadState.loaded;

  Map<String, dynamic> get stats => _stats;
  List<Map<String, dynamic>> get fraudTrend => _fraudTrend;
  Map<String, double> get domainSplit => _domainSplit;
  List<Map<String, dynamic>> get riskDistribution => _riskDistribution;

  Future<void> loadDashboard() async {
    if (_state == DashboardLoadState.loading) return;
    _state = DashboardLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await ApiService.fetchDashboard();

      _stats = {
        'total_today': data['total_today'] ?? 0,
        'fraud_detected': data['fraud_detected'] ?? 0,
        'fraud_rate': data['fraud_rate'] ?? 0.0,
        'avg_risk_score': data['avg_risk_score'] ?? 0.0,
        'alerts_open': data['alerts_open'] ?? 0,
        'model_accuracy': data['model_accuracy'] ?? 0.0,
      };

      _fraudTrend = (data['fraud_trend'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final rawSplit = data['domain_split'] as Map<String, dynamic>? ?? {};
      _domainSplit = rawSplit.map((k, v) => MapEntry(k, (v as num).toDouble()));

      _riskDistribution = (data['risk_distribution'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      _state = DashboardLoadState.loaded;
    } catch (e) {
      // Fallback to mock data on error so the UI is never empty
      _stats = MockData.dashboardStats;
      _fraudTrend = MockData.fraudTrend;
      _domainSplit = MockData.domainSplit;
      _riskDistribution = MockData.riskDistribution;
      _errorMessage = e.toString();
      _state = DashboardLoadState.loaded; // show fallback, not error state
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    _state = DashboardLoadState.idle;
    await loadDashboard();
  }
}

