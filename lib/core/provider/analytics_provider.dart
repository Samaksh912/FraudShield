// lib/core/provider/analytics_provider.dart
// Fetches model metrics and feature importance from /v1/analytics.
// Falls back to MockData on error.

import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../utils/mock_data.dart';

enum AnalyticsLoadState { idle, loading, loaded, error }

class AnalyticsProvider extends ChangeNotifier {
  AnalyticsLoadState _state = AnalyticsLoadState.idle;
  String? _errorMessage;

  Map<String, Map<String, dynamic>> _modelMetrics = {};
  Map<String, List<Map<String, dynamic>>> _featureImportance = {};

  AnalyticsLoadState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == AnalyticsLoadState.loading;
  bool get hasData => _state == AnalyticsLoadState.loaded;

  Map<String, Map<String, dynamic>> get modelMetrics => _modelMetrics;
  Map<String, List<Map<String, dynamic>>> get featureImportance =>
      _featureImportance;

  Future<void> loadAnalytics() async {
    if (_state == AnalyticsLoadState.loading) return;
    _state = AnalyticsLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await ApiService.fetchAnalytics();

      final rawMetrics =
          data['model_metrics'] as Map<String, dynamic>? ?? {};
      _modelMetrics = rawMetrics.map((k, v) =>
          MapEntry(k, Map<String, dynamic>.from(v as Map)));

      final rawFeatures =
          data['feature_importance'] as Map<String, dynamic>? ?? {};
      _featureImportance = rawFeatures.map((k, v) => MapEntry(
          k,
          (v as List<dynamic>)
              .map((f) => Map<String, dynamic>.from(f as Map))
              .toList()));

      _state = AnalyticsLoadState.loaded;
    } catch (e) {
      // Fallback to mock data
      _modelMetrics = MockData.modelMetrics;
      _featureImportance = MockData.featureImportance;
      _errorMessage = e.toString();
      _state = AnalyticsLoadState.loaded;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    _state = AnalyticsLoadState.idle;
    await loadAnalytics();
  }
}
