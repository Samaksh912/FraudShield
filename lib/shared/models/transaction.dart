// Transaction row model for the transactions table.
// domain: "paysim" | "ieee_cis"  (matches API contract strings)
// riskScore: 0.0–1.0             (raw API value)
// level: "low" | "medium" | "high" (from risk.level)
class Transaction {
  final String id;
  final String domain;   // "paysim" or "ieee_cis"
  final String type;     // TRANSFER, PAYMENT, CASH_OUT, PURCHASE, etc.
  final double amount;
  final String currency; // INR, USD
  final String sender;
  final String receiver;
  final DateTime timestamp;
  final double riskScore; // 0.0–1.0
  final String level;     // "low" | "medium" | "high"

  const Transaction({
    required this.id,
    required this.domain,
    required this.type,
    required this.amount,
    required this.currency,
    required this.sender,
    required this.receiver,
    required this.timestamp,
    required this.riskScore,
    required this.level,
  });

  String get domainLabel => domain == 'paysim' ? 'UPI' : 'CARD';

  // Convert 0–1 to 0–100 integer for progress bar display
  int get riskPercent => (riskScore * 100).round();

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      domain: json['domain'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      sender: json['sender'] as String,
      receiver: json['receiver'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      riskScore: (json['risk_score'] as num).toDouble(),
      level: json['level'] as String,
    );
  }
}