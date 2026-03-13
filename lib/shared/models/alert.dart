// lib/shared/models/alert.dart
// Matches /v1/alerts API contract exactly.
// Added: fromJson (for real HTTP parsing) + copyWith (for Gemini enrichment).

class FraudAlert {
  final String alertId;
  final String type;
  final String priority;          // "low" | "medium" | "high"
  final String status;            // "open" | "resolved" | "dismissed"
  final String recommendedAction; // "manual_review" | "block_and_review" | "step_up_verification"
  final String domain;            // "paysim" | "ieee_cis"
  final String transactionId;
  final double riskScore;         // 0.0–1.0 raw
  final String? signalMessage;    // UI-only: AI-generated reason (from Gemini)
  final DateTime? timestamp;      // UI-only: populated on fetch

  const FraudAlert({
    required this.alertId,
    required this.type,
    required this.priority,
    required this.status,
    required this.recommendedAction,
    required this.domain,
    required this.transactionId,
    required this.riskScore,
    this.signalMessage,
    this.timestamp,
  });

  // ── Convenience getters ───────────────────────────────────────────────────
  bool get isOpen => status == 'open';
  int get riskPercent => (riskScore * 100).round();

  // ── Deserialize from /v1/alerts response item ─────────────────────────────
  factory FraudAlert.fromJson(Map<String, dynamic> json) {
    return FraudAlert(
      alertId: json['alert_id'] as String,
      type: json['type'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      recommendedAction: json['recommended_action'] as String,
      domain: json['domain'] as String,
      transactionId: json['transaction_id'] as String,
      riskScore: (json['risk_score'] as num).toDouble(),
      // These two are UI-only; the API does not return them.
      // timestamp defaults to now so the list renders immediately.
      signalMessage: null,
      timestamp: DateTime.now(),
    );
  }

  // ── Immutable update (used by GeminiService to attach signalMessage) ──────
  FraudAlert copyWith({
    String? signalMessage,
    DateTime? timestamp,
  }) {
    return FraudAlert(
      alertId: alertId,
      type: type,
      priority: priority,
      status: status,
      recommendedAction: recommendedAction,
      domain: domain,
      transactionId: transactionId,
      riskScore: riskScore,
      signalMessage: signalMessage ?? this.signalMessage,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}