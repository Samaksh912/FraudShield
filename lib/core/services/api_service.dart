// lib/core/services/api_service.dart
// Updated: reads the ai_reason field the Python backend now attaches.
// No Gemini calls from Flutter anymore — the backend handles that entirely.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../shared/models/alert.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8001'; // Update with your backend's IP and port

  static Future<List<FraudAlert>> fetchAlerts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/alerts'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = body['items'] as List<dynamic>;
      return items.map((item) {
        final map = item as Map<String, dynamic>;
        final alert = FraudAlert.fromJson(map);
        // ai_reason is injected by the Python backend (via Gemini)
        final aiReason = map['ai_reason'] as String?;
        return aiReason != null ? alert.copyWith(signalMessage: aiReason) : alert;
      }).toList();
    }
    throw Exception('GET /v1/alerts failed — ${response.statusCode}');
  }
}