// RiskResult — mirrors /v1/score response contract exactly.
// score, heuristic, supervised, anomaly are all 0.0–1.0 (not 0–100).

// risk.decision enum: allow | review | block
enum RiskDecision { allow, review, block }

// risk.level enum: low | medium | high
enum RiskLevel { low, medium, high }

// signal.severity enum: low | medium | high
enum SignalSeverity { low, medium, high }

// alert.priority enum: low | medium | high
enum AlertPriority { low, medium, high }

// alert.status enum: open | resolved | dismissed
enum AlertStatus { open, resolved, dismissed }

// model.mode enum: heuristic_only | model_plus_rules
enum ModelMode { heuristic_only, model_plus_rules }

// One signal row (from response.signals[])
class RiskSignal {
  final String code;
  final SignalSeverity severity;
  final double value;
  final double threshold;
  final String message;

  const RiskSignal({
    required this.code,
    required this.severity,
    required this.value,
    required this.threshold,
    required this.message,
  });

  factory RiskSignal.fromJson(Map<String, dynamic> json) {
    return RiskSignal(
      code: json['code'] as String,
      severity: SignalSeverity.values.firstWhere(
        (e) => e.name == json['severity'], orElse: () => SignalSeverity.low),
      value: (json['value'] as num).toDouble(),
      threshold: (json['threshold'] as num).toDouble(),
      message: json['message'] as String,
    );
  }
}

// One feature_contribution row (from response.explanations.feature_contributions[])
class FeatureContribution {
  final String feature;
  final double value;
  final double impact; // positive = pushed score up, negative = pushed score down

  const FeatureContribution({
    required this.feature,
    required this.value,
    required this.impact,
  });

  factory FeatureContribution.fromJson(Map<String, dynamic> json) {
    return FeatureContribution(
      feature: json['feature'] as String,
      value: (json['value'] as num).toDouble(),
      impact: (json['impact'] as num).toDouble(),
    );
  }
}

// One alert embedded in the score response (from response.alerts[])
class EmbeddedAlert {
  final String alertId;
  final String type;
  final AlertPriority priority;
  final AlertStatus status;
  final String recommendedAction;

  const EmbeddedAlert({
    required this.alertId,
    required this.type,
    required this.priority,
    required this.status,
    required this.recommendedAction,
  });

  factory EmbeddedAlert.fromJson(Map<String, dynamic> json) {
    return EmbeddedAlert(
      alertId: json['alert_id'] as String,
      type: json['type'] as String,
      priority: AlertPriority.values.firstWhere(
        (e) => e.name == json['priority'], orElse: () => AlertPriority.low),
      status: AlertStatus.values.firstWhere(
        (e) => e.name == json['status'], orElse: () => AlertStatus.open),
      recommendedAction: json['recommended_action'] as String,
    );
  }
}

// scores sub-object (heuristic / supervised / anomaly breakdown)
class ScoreBreakdown {
  final double heuristic;
  final double? supervised;   // null when model not loaded
  final double? anomaly;      // null when anomaly model not loaded
  final String fusionVersion;

  const ScoreBreakdown({
    required this.heuristic,
    this.supervised,
    this.anomaly,
    required this.fusionVersion,
  });

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return ScoreBreakdown(
      heuristic: (json['heuristic'] as num).toDouble(),
      supervised: json['supervised'] != null ? (json['supervised'] as num).toDouble() : null,
      anomaly: json['anomaly'] != null ? (json['anomaly'] as num).toDouble() : null,
      fusionVersion: json['fusion_version'] as String? ?? 'default_v1',
    );
  }
}

// model sub-object
class ModelInfo {
  final String artifactVersion;
  final ModelMode mode;
  final String engineVersion;

  const ModelInfo({
    required this.artifactVersion,
    required this.mode,
    required this.engineVersion,
  });

  String get modeLabel => mode == ModelMode.heuristic_only
      ? 'Heuristic Only' : 'Model + Rules';

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      artifactVersion: json['artifact_version'] as String? ?? 'v1',
      mode: json['mode'] == 'model_plus_rules' ? ModelMode.model_plus_rules : ModelMode.heuristic_only,
      engineVersion: json['engine_version'] as String? ?? '0.1.0',
    );
  }
}

// transaction_summary sub-object
class TransactionSummary {
  final double amount;
  final String currency;
  final String channel;
  final String? productCode;
  final String? cardNetwork;
  final String? fundingType;

  const TransactionSummary({
    required this.amount,
    required this.currency,
    required this.channel,
    this.productCode,
    this.cardNetwork,
    this.fundingType,
  });

  factory TransactionSummary.fromJson(Map<String, dynamic> json) {
    return TransactionSummary(
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      channel: json['channel'] as String,
      productCode: json['product_code'] as String?,
      cardNetwork: json['card_network'] as String?,
      fundingType: json['funding_type'] as String?,
    );
  }
}

// Root response object for /v1/score
class RiskResult {
  final String requestId;
  final String transactionId;
  final String domain;            // "paysim" or "ieee_cis"
  final RiskLevel level;          // low | medium | high
  final double score;             // 0.0–1.0
  final RiskDecision decision;    // allow | review | block
  final double confidence;        // 0.0–1.0
  final ScoreBreakdown scores;
  final List<RiskSignal> signals;
  final List<String> topReasons;
  final List<FeatureContribution> featureContributions;
  final Map<String, dynamic> features; // domain-specific feature map
  final List<EmbeddedAlert> alerts;
  final TransactionSummary transactionSummary;
  final ModelInfo model;
  final int latencyMs;

  const RiskResult({
    required this.requestId,
    required this.transactionId,
    required this.domain,
    required this.level,
    required this.score,
    required this.decision,
    required this.confidence,
    required this.scores,
    required this.signals,
    required this.topReasons,
    required this.featureContributions,
    required this.features,
    required this.alerts,
    required this.transactionSummary,
    required this.model,
    required this.latencyMs,
  });

  // Display helpers
  String get decisionLabel {
    switch (decision) {
      case RiskDecision.allow:  return 'ALLOWED';
      case RiskDecision.review: return 'REVIEW';
      case RiskDecision.block:  return 'BLOCKED';
    }
  }

  // Convert 0–1 score to 0–100 integer for display
  int get scorePercent => (score * 100).round();

  String get domainLabel =>
      domain == 'paysim' ? 'UPI / PaySim' : 'Card / IEEE-CIS';

  factory RiskResult.fromJson(Map<String, dynamic> json) {
    return RiskResult(
      requestId: json['request_id'] as String? ?? '',
      transactionId: json['transaction_id'] as String? ?? '',
      domain: json['domain'] as String,
      level: RiskLevel.values.firstWhere(
        (e) => e.name == (json['level'] ?? json['risk']?['level']),
        orElse: () => RiskLevel.low),
      score: (json['score'] as num? ?? json['risk']?['score'] as num? ?? 0).toDouble(),
      decision: RiskDecision.values.firstWhere(
        (e) => e.name == (json['decision'] ?? json['risk']?['decision']),
        orElse: () => RiskDecision.allow),
      confidence: (json['confidence'] as num? ?? 0).toDouble(),
      scores: json['scores'] != null
          ? ScoreBreakdown.fromJson(json['scores'] as Map<String, dynamic>)
          : const ScoreBreakdown(heuristic: 0, fusionVersion: 'default_v1'),
      signals: (json['signals'] as List<dynamic>? ?? [])
          .map((s) => RiskSignal.fromJson(s as Map<String, dynamic>))
          .toList(),
      topReasons: (json['top_reasons'] as List<dynamic>? ??
                   json['explanations']?['top_reasons'] as List<dynamic>? ?? [])
          .map((r) => r as String)
          .toList(),
      featureContributions: (json['feature_contributions'] as List<dynamic>? ??
                              json['explanations']?['feature_contributions'] as List<dynamic>? ?? [])
          .map((f) => FeatureContribution.fromJson(f as Map<String, dynamic>))
          .toList(),
      features: json['features'] as Map<String, dynamic>? ?? {},
      alerts: (json['alerts'] as List<dynamic>? ?? [])
          .map((a) => EmbeddedAlert.fromJson(a as Map<String, dynamic>))
          .toList(),
      transactionSummary: json['transaction_summary'] != null
          ? TransactionSummary.fromJson(json['transaction_summary'] as Map<String, dynamic>)
          : const TransactionSummary(amount: 0, currency: '', channel: ''),
      model: json['model'] != null
          ? ModelInfo.fromJson(json['model'] as Map<String, dynamic>)
          : const ModelInfo(artifactVersion: 'v1', mode: ModelMode.heuristic_only, engineVersion: '0.1.0'),
      latencyMs: json['latency_ms'] as int? ?? 0,
    );
  }
}