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
}