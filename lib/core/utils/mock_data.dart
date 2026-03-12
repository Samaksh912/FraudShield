import '../../shared/models/risk_result.dart';
import '../../shared/models/alert.dart';
import '../../shared/models/transaction.dart';

// All mock data matches frontend_mock_responses.json exactly.
// Scores are 0.0–1.0 (raw API values). Use scorePercent getter for display.
// Replace these with real HTTP calls to /v1/score, /v1/alerts, /v1/health.
class MockData {
  // --- Dashboard KPI snapshots (computed from scenario data) ---
  static const Map<String, dynamic> dashboardStats = {
    'total_today': 12847,
    'fraud_detected': 142,
    'fraud_rate': 1.11,
    'avg_risk_score': 23.4, // 0–1 scale
    'alerts_open': 3,         // matches alerts_response.items count
    'model_accuracy': 97.2,
  };

  // --- 7-day fraud trend ---
  static const List<Map<String, dynamic>> fraudTrend = [
    {'day': 'Mon', 'transactions': 9400,  'fraud': 98},
    {'day': 'Tue', 'transactions': 10200, 'fraud': 115},
    {'day': 'Wed', 'transactions': 11800, 'fraud': 134},
    {'day': 'Thu', 'transactions': 10900, 'fraud': 121},
    {'day': 'Fri', 'transactions': 13200, 'fraud': 158},
    {'day': 'Sat', 'transactions': 14800, 'fraud': 172},
    {'day': 'Sun', 'transactions': 12847, 'fraud': 142},
  ];

  // --- Domain split ---
  static const Map<String, double> domainSplit = {
    'UPI (PaySim)': 58.4,
    'Card (IEEE-CIS)': 41.6,
  };

  // --- Risk distribution ---
  static const List<Map<String, dynamic>> riskDistribution = [
    {'label': 'Low (0–30)',     'count': 9820, 'color': 'safe'},
    {'label': 'Medium (31–60)', 'count': 2105, 'color': 'suspicious'},
    {'label': 'High (61–85)',   'count': 780,  'color': 'fraud'},
    {'label': 'Critical (86+)', 'count': 142,  'color': 'fraudDim'},
  ];

  // --- Recent transactions (table) ---
  // domain field now matches contract strings "paysim" / "ieee_cis"
  static List<Transaction> get transactions => [
    Transaction(id: 'txn_1001',      domain: 'paysim',    type: 'TRANSFER',   amount: 125000.0, currency: 'INR', sender: 'C123', receiver: 'C456',          timestamp: DateTime.now().subtract(const Duration(minutes: 3)),  riskScore: 0.864, level: 'high'),
    Transaction(id: 'txn_card_2001', domain: 'ieee_cis',  type: 'PURCHASE',   amount: 68.5,    currency: 'USD', sender: 'card1_13926', receiver: 'W',       timestamp: DateTime.now().subtract(const Duration(minutes: 7)),  riskScore: 0.931, level: 'high'),
    Transaction(id: 'txn_1002',      domain: 'paysim',    type: 'PAYMENT',    amount: 950.0,   currency: 'INR', sender: 'C777', receiver: 'M123',            timestamp: DateTime.now().subtract(const Duration(minutes: 12)), riskScore: 0.11,  level: 'low'),
    Transaction(id: 'txn_card_2002', domain: 'ieee_cis',  type: 'PURCHASE',   amount: 149.99,  currency: 'USD', sender: 'card1_2755', receiver: 'W',         timestamp: DateTime.now().subtract(const Duration(minutes: 20)), riskScore: 0.58,  level: 'medium'),
    Transaction(id: 'txn_1003',      domain: 'paysim',    type: 'TRANSFER',   amount: 5800.0,  currency: 'INR', sender: 'C901', receiver: 'C220',            timestamp: DateTime.now().subtract(const Duration(minutes: 28)), riskScore: 0.09,  level: 'low'),
    Transaction(id: 'txn_card_2003', domain: 'ieee_cis',  type: 'WITHDRAWAL', amount: 3420.0,  currency: 'USD', sender: 'card1_1188', receiver: 'MID_2290', timestamp: DateTime.now().subtract(const Duration(minutes: 35)), riskScore: 0.47,  level: 'medium'),
    Transaction(id: 'txn_1004',      domain: 'paysim',    type: 'CASH_OUT',   amount: 15000.0, currency: 'INR', sender: 'C990', receiver: 'M773',            timestamp: DateTime.now().subtract(const Duration(minutes: 42)), riskScore: 0.78,  level: 'high'),
    Transaction(id: 'txn_card_2004', domain: 'ieee_cis',  type: 'PURCHASE',   amount: 220.0,   currency: 'USD', sender: 'card1_3312', receiver: 'MID_0042', timestamp: DateTime.now().subtract(const Duration(minutes: 50)), riskScore: 0.07,  level: 'low'),
  ];

  // --- /v1/alerts response items (from frontend_mock_responses.json) ---
  static List<FraudAlert> get alerts => [
    FraudAlert(
      alertId: 'alrt_9c3b',
      type: 'suspicious_transaction',
      priority: 'high',
      status: 'open',
      recommendedAction: 'step_up_verification',
      domain: 'paysim',
      transactionId: 'txn_1001',
      riskScore: 0.864,
      signalMessage: 'Velocity spike: transfer amount unusually large relative to sender balance',
      timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
    ),
    FraudAlert(
      alertId: 'alrt_41ad',
      type: 'suspicious_transaction',
      priority: 'high',
      status: 'open',
      recommendedAction: 'block_and_review',
      domain: 'ieee_cis',
      transactionId: 'txn_card_2001',
      riskScore: 0.931,
      signalMessage: 'New device detected; email domain mismatch flagged',
      timestamp: DateTime.now().subtract(const Duration(minutes: 7)),
    ),
    FraudAlert(
      alertId: 'alrt_77bf',
      type: 'suspicious_transaction',
      priority: 'medium',
      status: 'open',
      recommendedAction: 'manual_review',
      domain: 'ieee_cis',
      transactionId: 'txn_card_2002',
      riskScore: 0.58,
      signalMessage: 'Entity velocity above normal; amount 1.9x above median',
      timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
    ),
  ];

  // --- Health response (from frontend_mock_responses.json) ---
  static const Map<String, dynamic> healthResponse = {
    'status': 'ok',
    'engine_version': '0.1.0',
    'domains': {
      'paysim': {'mode': 'model_plus_rules', 'artifact_version': 'v1'},
      'ieee_cis': {'mode': 'heuristic_only', 'artifact_version': null},
    },
  };

  // --- Score screen demo results (4 scenarios from mock_responses.json) ---

  // scenario: paysim_high_risk_review
  static RiskResult get paySimHighRisk => RiskResult(
    requestId: '4f1db8e3-4741-41d8-8df4-5ab7f8a9d901',
    transactionId: 'txn_1001',
    domain: 'paysim',
    level: RiskLevel.high,
    score: 0.864,
    decision: RiskDecision.review,
    confidence: 0.82,
    scores: const ScoreBreakdown(
      heuristic: 0.88,
      supervised: 0.91,
      anomaly: null,
      fusionVersion: 'default_v1',
    ),
    signals: const [
      RiskSignal(
        code: 'HIGH_AMOUNT_TO_BALANCE_RATIO',
        severity: SignalSeverity.high,
        value: 0.8333,
        threshold: 0.7,
        message: 'Transfer amount is unusually large relative to sender balance.',
      ),
      RiskSignal(
        code: 'NEW_BENEFICIARY',
        severity: SignalSeverity.medium,
        value: 1,
        threshold: 1,
        message: 'Sender is transacting with a new beneficiary.',
      ),
    ],
    topReasons: const [
      'Large transfer relative to available balance',
      'New sender-beneficiary pair',
      'Sender activity is elevated in the last 24 hours',
    ],
    featureContributions: const [
      FeatureContribution(feature: 'amount_to_orig_balance_ratio', value: 0.8333, impact: 0.31),
      FeatureContribution(feature: 'sender_dest_pair_novelty',     value: 1,      impact: 0.27),
      FeatureContribution(feature: 'sender_txn_count_24h',         value: 6,      impact: 0.18),
    ],
    features: const {
      'type_risk_flag': 1,
      'amount_to_orig_balance_ratio': 0.8333,
      'orig_balance_consistency_error': 0.0,
      'sender_txn_count_24h': 6,
      'sender_amount_zscore_7d': 2.9,
      'sender_dest_pair_novelty': 1,
    },
    alerts: const [
      EmbeddedAlert(
        alertId: 'alrt_9c3b',
        type: 'suspicious_transaction',
        priority: AlertPriority.high,
        status: AlertStatus.open,
        recommendedAction: 'step_up_verification',
      ),
    ],
    transactionSummary: const TransactionSummary(
        amount: 125000.0, currency: 'INR', channel: 'upi'),
    model: const ModelInfo(
      artifactVersion: 'v1',
      mode: ModelMode.model_plus_rules,
      engineVersion: '0.1.0',
    ),
    latencyMs: 24,
  );

  // scenario: paysim_low_risk_allow
  static RiskResult get paySimLowRisk => RiskResult(
    requestId: '7ce8c6d5-35c0-4a69-b696-df25c0904742',
    transactionId: 'txn_1002',
    domain: 'paysim',
    level: RiskLevel.low,
    score: 0.11,
    decision: RiskDecision.allow,
    confidence: 0.90,
    scores: const ScoreBreakdown(
      heuristic: 0.12,
      supervised: null,
      anomaly: null,
      fusionVersion: 'default_v1',
    ),
    signals: const [],
    topReasons: const [
      'Transaction amount is consistent with recent sender behavior',
      'No high-risk transfer pattern detected',
      'No unusual beneficiary novelty signal triggered',
    ],
    featureContributions: const [
      FeatureContribution(feature: 'amount_to_orig_balance_ratio', value: 0.0112, impact: -0.1),
    ],
    features: const {
      'type_risk_flag': 0,
      'amount_to_orig_balance_ratio': 0.0112,
      'orig_balance_consistency_error': 0.0,
      'sender_txn_count_24h': 1,
      'sender_amount_zscore_7d': -0.4,
      'sender_dest_pair_novelty': 0,
    },
    alerts: const [],
    transactionSummary: const TransactionSummary(
        amount: 950.0, currency: 'INR', channel: 'upi'),
    model: const ModelInfo(
      artifactVersion: 'v1',
      mode: ModelMode.heuristic_only,
      engineVersion: '0.1.0',
    ),
    latencyMs: 11,
  );

  // scenario: ieee_cis_high_risk_block
  static RiskResult get ieeeHighRisk => RiskResult(
    requestId: '60bfb749-00c0-4d7c-9d54-baa8c7c86d95',
    transactionId: 'txn_card_2001',
    domain: 'ieee_cis',
    level: RiskLevel.high,
    score: 0.931,
    decision: RiskDecision.block,
    confidence: 0.87,
    scores: const ScoreBreakdown(
      heuristic: 0.86,
      supervised: 0.95,
      anomaly: 0.74,
      fusionVersion: 'default_v1',
    ),
    signals: const [
      RiskSignal(
        code: 'NEW_DEVICE_FOR_UID',
        severity: SignalSeverity.high,
        value: 1,
        threshold: 1,
        message: 'Transaction originates from a new device signature for this entity.',
      ),
      RiskSignal(
        code: 'EMAIL_DOMAIN_MISMATCH',
        severity: SignalSeverity.medium,
        value: 1,
        threshold: 1,
        message: 'Purchaser and recipient email domains do not match.',
      ),
    ],
    topReasons: const [
      'New device detected for this card-address entity',
      'Entity transaction velocity is elevated in the last 24 hours',
      'Email domain mismatch increased card-not-present risk',
    ],
    featureContributions: const [
      FeatureContribution(feature: 'new_device_for_uid',   value: 1,  impact: 0.34),
      FeatureContribution(feature: 'uid_txn_count_24h',    value: 11, impact: 0.24),
      FeatureContribution(feature: 'email_domain_mismatch', value: 1, impact: 0.17),
    ],
    features: const {
      'uid_prior_frequency': 0.0014,
      'amt_to_uid_median_ratio': 3.8,
      'uid_txn_count_24h': 11,
      'email_domain_mismatch': 1,
      'new_device_for_uid': 1,
      'identity_present': 1,
    },
    alerts: const [
      EmbeddedAlert(
        alertId: 'alrt_41ad',
        type: 'suspicious_transaction',
        priority: AlertPriority.high,
        status: AlertStatus.open,
        recommendedAction: 'block_and_review',
      ),
    ],
    transactionSummary: const TransactionSummary(
        amount: 68.5, currency: 'USD', channel: 'card',
        productCode: 'W', cardNetwork: 'visa', fundingType: 'credit'),
    model: const ModelInfo(
      artifactVersion: 'v1',
      mode: ModelMode.model_plus_rules,
      engineVersion: '0.1.0',
    ),
    latencyMs: 31,
  );

  // scenario: ieee_cis_medium_risk_review
  static RiskResult get ieeeMediumRisk => RiskResult(
    requestId: 'c7a1ec64-3526-45cf-88d5-c4fb5e86b65d',
    transactionId: 'txn_card_2002',
    domain: 'ieee_cis',
    level: RiskLevel.medium,
    score: 0.58,
    decision: RiskDecision.review,
    confidence: 0.71,
    scores: const ScoreBreakdown(
      heuristic: 0.55,
      supervised: null,
      anomaly: 0.61,
      fusionVersion: 'default_v1',
    ),
    signals: const [
      RiskSignal(
        code: 'HIGH_UID_VELOCITY',
        severity: SignalSeverity.medium,
        value: 5,
        threshold: 4,
        message: 'Entity has elevated card activity in the last 24 hours.',
      ),
    ],
    topReasons: const [
      'Entity velocity is above normal',
      'Transaction amount is moderately above historical median',
      'Identity context is present but not strongly stabilizing',
    ],
    featureContributions: const [
      FeatureContribution(feature: 'uid_txn_count_24h',     value: 5,   impact: 0.22),
      FeatureContribution(feature: 'amt_to_uid_median_ratio', value: 1.9, impact: 0.19),
    ],
    features: const {
      'uid_prior_frequency': 0.015,
      'amt_to_uid_median_ratio': 1.9,
      'uid_txn_count_24h': 5,
      'email_domain_mismatch': 0,
      'new_device_for_uid': 0,
      'identity_present': 1,
    },
    alerts: const [
      EmbeddedAlert(
        alertId: 'alrt_77bf',
        type: 'suspicious_transaction',
        priority: AlertPriority.medium,
        status: AlertStatus.open,
        recommendedAction: 'manual_review',
      ),
    ],
    transactionSummary: const TransactionSummary(
        amount: 149.99, currency: 'USD', channel: 'card',
        productCode: 'W', cardNetwork: 'mastercard', fundingType: 'debit'),
    model: const ModelInfo(
      artifactVersion: 'v1',
      mode: ModelMode.heuristic_only,
      engineVersion: '0.1.0',
    ),
    latencyMs: 18,
  );

  // Analytics: model performance metrics
  static const Map<String, Map<String, dynamic>> modelMetrics = {
    'PaySim (UPI)':    {'precision': 97.8, 'recall': 96.2, 'f1': 97.0, 'pr_auc': 98.4, 'model': 'XGBoost'},
    'IEEE-CIS (Card)': {'precision': 95.1, 'recall': 93.8, 'f1': 94.4, 'pr_auc': 97.1, 'model': 'XGBoost + Anomaly'},
  };

  // Feature importance (top 6 per domain)
  static const Map<String, List<Map<String, dynamic>>> featureImportance = {
    'PaySim': [
      {'feature': 'amount_to_orig_balance_ratio', 'importance': 0.31},
      {'feature': 'sender_dest_pair_novelty',     'importance': 0.27},
      {'feature': 'sender_txn_count_24h',         'importance': 0.18},
      {'feature': 'sender_amount_zscore_7d',      'importance': 0.12},
      {'feature': 'orig_balance_consistency_error','importance': 0.07},
      {'feature': 'type_risk_flag',               'importance': 0.05},
    ],
    'IEEE-CIS': [
      {'feature': 'new_device_for_uid',      'importance': 0.34},
      {'feature': 'uid_txn_count_24h',       'importance': 0.24},
      {'feature': 'email_domain_mismatch',   'importance': 0.17},
      {'feature': 'amt_to_uid_median_ratio', 'importance': 0.13},
      {'feature': 'uid_prior_frequency',     'importance': 0.07},
      {'feature': 'identity_present',        'importance': 0.05},
    ],
  };
}