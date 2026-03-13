// lib/core/services/api_service.dart
// Centralized HTTP client for all backend endpoints.
// baseUrl should point to your FastAPI proxy (main.py).

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../shared/models/alert.dart';
import '../../shared/models/transaction.dart';
import '../../shared/models/risk_result.dart';

class ApiService {
  // ── Update this to your backend device's IP:port ──────────────────────────
  static const String baseUrl = 'http://localhost:8001';

  // ── Headers ───────────────────────────────────────────────────────────────
  static const _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  // ═══════════════════════════════════════════════════════
  // GET /v1/alerts
  // ═══════════════════════════════════════════════════════
  static Future<List<FraudAlert>> fetchAlerts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/alerts'),
      headers: _jsonHeaders,
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = body['items'] as List<dynamic>;
      return items.map((item) {
        final map = item as Map<String, dynamic>;
        final alert = FraudAlert.fromJson(map);
        final aiReason = map['ai_reason'] as String?;
        return aiReason != null
            ? alert.copyWith(signalMessage: aiReason)
            : alert;
      }).toList();
    }
    throw Exception('GET /v1/alerts failed — ${response.statusCode}');
  }

  // ═══════════════════════════════════════════════════════
  // GET /v1/transactions
  // ═══════════════════════════════════════════════════════
  static Future<List<Transaction>> fetchTransactions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/transactions'),
      headers: _jsonHeaders,
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = body['items'] as List<dynamic>;
      return items
          .map((item) =>
              Transaction.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception('GET /v1/transactions failed — ${response.statusCode}');
  }

  // ═══════════════════════════════════════════════════════
  // GET /v1/dashboard
  // ═══════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> fetchDashboard() async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/dashboard'),
      headers: _jsonHeaders,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('GET /v1/dashboard failed — ${response.statusCode}');
  }

  // ═══════════════════════════════════════════════════════
  // POST /v1/score
  // ═══════════════════════════════════════════════════════
  static Future<RiskResult> scoreTransaction(
      Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/score'),
      headers: _jsonHeaders,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return RiskResult.fromJson(body);
    }
    throw Exception('POST /v1/score failed — ${response.statusCode}');
  }

  // ═══════════════════════════════════════════════════════
  // GET /v1/analytics
  // ═══════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> fetchAnalytics() async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/analytics'),
      headers: _jsonHeaders,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('GET /v1/analytics failed — ${response.statusCode}');
  }

  // ═══════════════════════════════════════════════════════
  // GET /v1/health
  // ═══════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> fetchHealth() async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/health'),
      headers: _jsonHeaders,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('GET /v1/health failed — ${response.statusCode}');
  }
}

