// FraudAlert — mirrors /v1/alerts response item shape.
// priority is low | medium | high (no "critical" in contract).
// status is open | resolved | dismissed.
// domain is the string "paysim" or "ieee_cis".
// riskScore is 0.0–1.0 from the API.

// Re-export enums from risk_result to avoid duplicating them.
// AlertPriority, AlertStatus are defined in risk_result.dart.
export 'risk_result.dart'
    show AlertPriority, AlertStatus, RiskLevel, SignalSeverity;

class FraudAlert {
  final String alertId;           // alert_id from API
  final String type;              // e.g. "suspicious_transaction"
  final String priority;          // "low" | "medium" | "high"
  final String status;            // "open" | "resolved" | "dismissed"
  final String recommendedAction; // e.g. "step_up_verification"
  final String domain;            // "paysim" | "ieee_cis"
  final String transactionId;
  final double riskScore;         // 0.0–1.0

  // UI-only fields (not from API — set locally for demo)
  final String? signalMessage;    // optional human-readable reason line
  final DateTime? timestamp;      // set client-side for ordering

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

  // Display helpers
  String get priorityLabel => priority.toUpperCase();
  int get riskPercent => (riskScore * 100).round();
  String get domainLabel =>
      domain == 'paysim' ? 'UPI' : 'CARD';
  bool get isOpen => status == 'open';
}