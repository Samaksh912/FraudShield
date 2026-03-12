import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/mock_data.dart';
import '../../../shared/models/risk_result.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/status_badge.dart';

class ScoreScreen extends StatefulWidget {
  const ScoreScreen({super.key});
  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  // Active domain: "paysim" | "ieee_cis"
  String _domain = 'paysim';
  bool _loading  = false;
  RiskResult? _result;

  // --- PaySim payload fields (required by contract) ---
  final _psAmount       = TextEditingController(text: '125000');
  final _psNameOrig     = TextEditingController(text: 'C123');
  final _psNameDest     = TextEditingController(text: 'C456');
  final _psOldBal       = TextEditingController(text: '150000');
  final _psNewBal       = TextEditingController(text: '25000');
  final _psStep         = TextEditingController(text: '278');
  String _psType        = 'TRANSFER';
  final _psTypes        = ['TRANSFER', 'PAYMENT', 'CASH_OUT', 'DEBIT', 'CASH_IN'];

  // --- IEEE-CIS payload fields (required + key optionals by contract) ---
  final _ieAmount       = TextEditingController(text: '68.5');
  final _ieCard1        = TextEditingController(text: '13926');
  final _ieAddr1        = TextEditingController(text: '315');
  final _ieAddr2        = TextEditingController(text: '87');
  final _iePEmail       = TextEditingController(text: 'gmail.com');
  final _ieREmail       = TextEditingController(text: 'hotmail.com');
  final _ieDT           = TextEditingController(text: '86400');
  String _ieProductCD   = 'W';
  String _ieDeviceType  = 'mobile';
  String _ieCard4       = 'visa';
  String _ieCard6       = 'credit';
  final _productCDs     = ['W', 'H', 'C', 'S', 'R'];
  final _deviceTypes    = ['mobile', 'desktop'];
  final _cardNetworks   = ['visa', 'mastercard', 'discover', 'amex'];
  final _fundingTypes   = ['credit', 'debit'];

  // Picks the matching mock result so demo feels realistic per domain + scenario
  void _score() async {
    setState(() { _loading = true; _result = null; });
    await Future.delayed(const Duration(milliseconds: 1200));
    final result = _domain == 'paysim'
        ? (double.tryParse(_psAmount.text) ?? 0) > 50000
        ? MockData.paySimHighRisk
        : MockData.paySimLowRisk
        : (double.tryParse(_ieAmount.text) ?? 0) > 100
        ? MockData.ieeeMediumRisk
        : MockData.ieeeHighRisk;
    setState(() { _loading = false; _result = result; });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/score',
      pageTitle: 'Score Transaction',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: _buildForm()),
          const SizedBox(width: 24),
          Expanded(flex: 3, child: _result == null
              ? _buildEmptyResult()
              : _buildResultPanel(_result!)),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------------ FORM
  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Transaction Payload', style: AppTheme.sans(size: 16, weight: FontWeight.w700)),
        Text('Matches /v1/score request contract', style: AppTheme.sans(
            size: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 20),

        // Domain toggle
        _sectionLabel('Domain'),
        const SizedBox(height: 6),
        Row(children: [
          _domainBtn('paysim',   'UPI (PaySim)'),
          const SizedBox(width: 8),
          _domainBtn('ieee_cis', 'Card (IEEE-CIS)'),
        ]),
        const SizedBox(height: 20),

        // Domain-specific fields
        if (_domain == 'paysim') ..._buildPaySimFields()
        else ..._buildIEEEFields(),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _score,
            icon: _loading
                ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.radar_outlined, size: 18),
            label: Text(_loading ? 'Analyzing...' : 'Analyze Risk'),
          ),
        ),
      ]),
    );
  }

  // PaySim fields — required: step, type, nameOrig, nameDest, oldbalanceOrg
  List<Widget> _buildPaySimFields() => [
    _field('Amount (₹)', _psAmount, hint: '125000', prefix: '₹'),
    _dropdown('Transaction Type', _psTypes, _psType,
            (v) => setState(() => _psType = v!)),
    _field('Sender ID (nameOrig)', _psNameOrig, hint: 'C123'),
    _field('Receiver ID (nameDest)', _psNameDest, hint: 'C456'),
    _field('Sender Balance Before (oldbalanceOrg)', _psOldBal, hint: '150000'),
    _field('Sender Balance After (newbalanceOrig)', _psNewBal, hint: '25000'),
    _field('Simulation Step', _psStep, hint: '278', keyboard: TextInputType.number),
  ];

  // IEEE-CIS fields — required: TransactionDT, TransactionAmt, ProductCD, card1, addr1, addr2
  List<Widget> _buildIEEEFields() => [
    _field('Transaction Amount (USD)', _ieAmount, hint: '68.5', prefix: '\$'),
    _dropdown('Product Code (ProductCD)', _productCDs, _ieProductCD,
            (v) => setState(() => _ieProductCD = v!)),
    _dropdown('Card Network (card4)', _cardNetworks, _ieCard4,
            (v) => setState(() => _ieCard4 = v!)),
    _dropdown('Funding Type (card6)', _fundingTypes, _ieCard6,
            (v) => setState(() => _ieCard6 = v!)),
    _field('Card ID (card1)', _ieCard1, hint: '13926', keyboard: TextInputType.number),
    _field('Billing Zip (addr1)', _ieAddr1, hint: '315', keyboard: TextInputType.number),
    _field('Country Code (addr2)', _ieAddr2, hint: '87', keyboard: TextInputType.number),
    _field('Purchaser Email Domain (P_emaildomain)', _iePEmail, hint: 'gmail.com'),
    _field('Recipient Email Domain (R_emaildomain)', _ieREmail, hint: 'hotmail.com'),
    _dropdown('Device Type', _deviceTypes, _ieDeviceType,
            (v) => setState(() => _ieDeviceType = v!)),
    _field('Transaction DT', _ieDT, hint: '86400', keyboard: TextInputType.number),
  ];

  // ---------------------------------------------------------- RESULT PANEL
  Widget _buildEmptyResult() => Container(
    height: 480,
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.radar_outlined, size: 56, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text('Risk score will appear here',
            style: AppTheme.sans(size: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Text('Fill the form and click Analyze Risk',
            style: AppTheme.sans(size: 13, color: AppColors.textMuted)),
      ]),
    ),
  );

  Widget _buildResultPanel(RiskResult r) {
    final scoreColor = r.level == RiskLevel.high ? AppColors.fraud
        : r.level == RiskLevel.medium ? AppColors.suspicious : AppColors.safe;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scoreColor.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header bar
        _panelHeader(r, scoreColor),
        const Divider(height: 1, color: AppColors.border),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Big score + decision
            _scoreGauge(r, scoreColor),
            const SizedBox(height: 20),

            // ── Scores breakdown (heuristic / supervised / anomaly)
            _scoresBreakdown(r),
            const SizedBox(height: 20),

            // ── Signals
            if (r.signals.isNotEmpty) ...[
              _sectionHeader('Triggered Signals', Icons.warning_amber_outlined),
              const SizedBox(height: 10),
              ...r.signals.map((s) => _signalRow(s)),
              const SizedBox(height: 20),
            ],

            // ── Top reasons (explanations)
            _sectionHeader('Why this score?', Icons.lightbulb_outline),
            const SizedBox(height: 10),
            ...r.topReasons.map((reason) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(margin: const EdgeInsets.only(top: 6),
                    width: 5, height: 5,
                    decoration: BoxDecoration(color: scoreColor, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(reason, style: AppTheme.sans(
                    size: 13, color: AppColors.textSecondary))),
              ]),
            )),
            const SizedBox(height: 20),

            // ── Feature contributions waterfall
            _sectionHeader('Feature Contributions', Icons.bar_chart_outlined),
            const SizedBox(height: 10),
            ...r.featureContributions.map((fc) => _featureContributionRow(fc)),
            const SizedBox(height: 20),

            // ── Raw features table (domain-specific)
            _sectionHeader('Raw Feature Values', Icons.table_chart_outlined),
            const SizedBox(height: 10),
            _featuresTable(r.features),
            const SizedBox(height: 20),

            // ── Transaction summary
            _sectionHeader('Transaction Summary', Icons.receipt_outlined),
            const SizedBox(height: 10),
            _txSummaryGrid(r),
            const SizedBox(height: 20),

            // ── Model info + latency footer
            _modelFooter(r),
          ]),
        ),
      ]),
    );
  }

  Widget _panelHeader(RiskResult r, Color scoreColor) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    child: Row(children: [
      Text('Risk Analysis', style: AppTheme.sans(size: 15, weight: FontWeight.w700)),
      const SizedBox(width: 10),
      StatusBadge.domainStr(r.domain),
      const Spacer(),
      StatusBadge.decision(r.decision.name),
      const SizedBox(width: 8),
      Text('${r.latencyMs}ms', style: AppTheme.mono(size: 11, color: AppColors.textMuted)),
    ]),
  );

  Widget _scoreGauge(RiskResult r, Color color) {
    // Animate the progress bar fill for a satisfying reveal
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: r.score),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Center(
            child: Column(children: [
              // Glowing Percentage
              Container(
                decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.15),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ]
                ),
                child: Text('${(value * 100).toInt()}', style: AppTheme.mono(
                    size: 72, weight: FontWeight.w700, color: color, letterSpacing: -2)),
              ),
              Text('RISK SCORE  (raw: ${value.toStringAsFixed(3)})', style: AppTheme.mono(
                  size: 11, color: AppColors.textSecondary, weight: FontWeight.w600)),
              const SizedBox(height: 16),

              // Glowing Progress Bar
              SizedBox(
                width: double.infinity,
                height: 8,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: value,
                      backgroundColor: AppColors.bg,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Badges
              Row(mainAxisSize: MainAxisSize.min, children: [
                StatusBadge.level(r.level.name),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.analytics_outlined, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Confidence: ${(r.confidence * 100).toStringAsFixed(0)}%',
                          style: AppTheme.mono(size: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ]),
            ]),
          );
        }
    );
  }
  Widget _scoresBreakdown(RiskResult r) {
    final s = r.scores;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Score Breakdown', style: AppTheme.sans(
            size: 12, weight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Row(children: [
          _scoreChip('Heuristic',  s.heuristic, AppColors.primary),
          const SizedBox(width: 8),
          _scoreChip('Supervised', s.supervised, const Color(0xFF8B5CF6)),
          const SizedBox(width: 8),
          _scoreChip('Anomaly',    s.anomaly,    AppColors.suspicious),
        ]),
        const SizedBox(height: 8),
        Text('Fusion: ${s.fusionVersion}', style: AppTheme.mono(
            size: 10, color: AppColors.textMuted)),
      ]),
    );
  }

  Widget _scoreChip(String label, double? val, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text(
          val != null ? val.toStringAsFixed(2) : '—',
          style: AppTheme.mono(size: 16, weight: FontWeight.w700,
              color: val != null ? color : AppColors.textMuted),
        ),
        Text(label, style: AppTheme.sans(size: 10, color: AppColors.textSecondary)),
      ]),
    ),
  );

  Widget _signalRow(RiskSignal s) {
    final color = s.severity == SignalSeverity.high ? AppColors.fraud
        : s.severity == SignalSeverity.medium ? AppColors.suspicious : AppColors.safe;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(s.code, style: AppTheme.mono(size: 11, weight: FontWeight.w600, color: color)),
          const Spacer(),
          Text('value: ${s.value}  threshold: ${s.threshold}',
              style: AppTheme.mono(size: 10, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 4),
        Text(s.message, style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _featureContributionRow(FeatureContribution fc) {
    final isPositive = fc.impact >= 0;
    final color = isPositive ? AppColors.fraud : AppColors.safe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(flex: 3, child: Text(fc.feature,
            style: AppTheme.mono(size: 11, color: AppColors.textSecondary))),
        Text(fc.value.toStringAsFixed(4), style: AppTheme.mono(
            size: 11, color: AppColors.textPrimary)),
        const SizedBox(width: 12),
        Container(
          width: 60, height: 4,
          decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fc.impact.abs().clamp(0, 1),
            child: Container(
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${isPositive ? '+' : ''}${(fc.impact * 100).toStringAsFixed(0)}%',
            style: AppTheme.mono(size: 11, color: color)),
      ]),
    );
  }

  // Key-value grid of domain-specific feature values
  Widget _featuresTable(Map<String, dynamic> features) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: features.entries.map((e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(e.key, style: AppTheme.mono(
              size: 11, color: AppColors.textSecondary))),
          Text(e.value.toString(), style: AppTheme.mono(
              size: 11, weight: FontWeight.w600)),
        ]),
      )).toList(),
    ),
  );

  Widget _txSummaryGrid(RiskResult r) {
    final s = r.transactionSummary;
    final items = [
      ('Amount', '${s.amount} ${s.currency}'),
      ('Channel', s.channel.toUpperCase()),
      if (s.productCode != null) ('Product Code', s.productCode!),
      if (s.cardNetwork != null) ('Card Network', s.cardNetwork!),
      if (s.fundingType != null) ('Funding Type', s.fundingType!),
    ];
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.$1, style: AppTheme.sans(size: 10, color: AppColors.textMuted)),
          Text(item.$2, style: AppTheme.mono(size: 13, weight: FontWeight.w600)),
        ]),
      )).toList(),
    );
  }

  Widget _modelFooter(RiskResult r) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(children: [
      Icon(Icons.memory_outlined, size: 14, color: AppColors.textMuted),
      const SizedBox(width: 8),
      Text(r.model.modeLabel, style: AppTheme.mono(size: 11, color: AppColors.textSecondary)),
      const SizedBox(width: 12),
      Text('artifact: ${r.model.artifactVersion}', style: AppTheme.mono(
          size: 11, color: AppColors.textMuted)),
      const SizedBox(width: 12),
      Text('engine: ${r.model.engineVersion}', style: AppTheme.mono(
          size: 11, color: AppColors.textMuted)),
      const Spacer(),
      Text('${r.latencyMs} ms', style: AppTheme.mono(
          size: 12, weight: FontWeight.w600, color: AppColors.primary)),
    ]),
  );

  // ---------------------------------------------------------------- HELPERS
  Widget _domainBtn(String id, String label) {
    final active = _domain == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _domain = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? AppColors.primary : AppColors.border),
          ),
          child: Center(child: Text(label, style: AppTheme.sans(
              size: 13,
              weight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppColors.primary : AppColors.textSecondary))),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {
    String? hint, String? prefix,
    TextInputType keyboard = TextInputType.text,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel(label),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: AppTheme.mono(size: 13),
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix != null ? '$prefix ' : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    ]),
  );

  Widget _dropdown(String label, List<String> items, String value, ValueChanged<String?> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel(label),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: value,
            dropdownColor: AppColors.surface,
            style: AppTheme.mono(size: 13),
            isDense: true,
            decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: items.map((t) => DropdownMenuItem(
              value: t,
              child: Text(t, style: AppTheme.mono(size: 13)),
            )).toList(),
            onChanged: onChanged,
          ),
        ]),
      );

  Widget _sectionLabel(String text) => Text(text,
      style: AppTheme.sans(size: 12, weight: FontWeight.w500, color: AppColors.textSecondary));

  Widget _sectionHeader(String text, IconData icon) => Row(children: [
    Icon(icon, size: 14, color: AppColors.primary),
    const SizedBox(width: 6),
    Text(text, style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
  ]);
}

