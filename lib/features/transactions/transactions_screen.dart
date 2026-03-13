import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/provider/transactions_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/transaction.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/status_badge.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _search = '';
  String? _levelFilter;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TransactionsProvider>();
      if (provider.state == TransactionsLoadState.idle) {
        provider.loadTransactions();
      }
    });
  }

  List<Transaction> _filteredTx(List<Transaction> all) {
    final domainFilter = [null, 'paysim', 'ieee_cis'][_tabs.index];
    return all.where((tx) {
      final matchDomain = domainFilter == null || tx.domain == domainFilter;
      final matchSearch = _search.isEmpty ||
          tx.id.toLowerCase().contains(_search.toLowerCase()) ||
          tx.sender.toLowerCase().contains(_search.toLowerCase()) ||
          tx.receiver.toLowerCase().contains(_search.toLowerCase());
      final matchLevel = _levelFilter == null || tx.level == _levelFilter;
      return matchDomain && matchSearch && matchLevel;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/transactions',
      pageTitle: 'Transactions',
      child: Consumer<TransactionsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final txs = _filteredTx(provider.transactions);
          return Column(
            children: [
              _buildToolbar(txs.length),
              Expanded(child: _buildTable(txs)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildToolbar(int resultCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      color: AppColors.surface,
      child: Column(
        children: [
          TabBar(
            controller: _tabs,
            onTap: (_) => setState(() {}),
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: AppTheme.sans(size: 13, weight: FontWeight.w600),
            unselectedLabelStyle: AppTheme.sans(size: 13),
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'UPI (paysim)'),
              Tab(text: 'Card (ieee_cis)'),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            SizedBox(
              width: 280,
              height: 36,
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: AppTheme.mono(size: 13),
                decoration: const InputDecoration(
                  hintText: 'Search by ID, sender, receiver...',
                  prefixIcon: Icon(Icons.search, size: 16, color: AppColors.textMuted),
                  contentPadding: EdgeInsets.symmetric(vertical: 0),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ...[null, 'high', 'medium', 'low'].map((l) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(l == null ? 'All' : l.toUpperCase()),
                selected: _levelFilter == l,
                onSelected: (_) => setState(() => _levelFilter = l),
                labelStyle: AppTheme.mono(
                  size: 10,
                  color: _levelFilter == l
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
                backgroundColor: AppColors.card,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                side: BorderSide(
                  color: _levelFilter == l ? AppColors.primary : AppColors.border,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            )),
            const Spacer(),
            Text(
              '$resultCount results',
              style: AppTheme.mono(size: 12, color: AppColors.textSecondary),
            ),
          ]),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTable(List<Transaction> txs) {
    if (txs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text('No transactions found',
              style: AppTheme.sans(size: 15, color: AppColors.textSecondary)),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border, width: 2)),
            ),
            child: Row(
              children: ['ID', 'Domain', 'Type', 'Amount', 'Sender', 'Receiver', 'Score', 'Level', 'Time']
                  .asMap()
                  .entries
                  .map((e) => _buildColumnCell(e.value, _getColumnFlex(e.key), isHeader: true))
                  .toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: txs.length,
              itemBuilder: (context, index) {
                return _HoverTxRow(
                  tx: txs[index],
                  isLast: index == txs.length - 1,
                  flexFns: _getColumnFlex,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int _getColumnFlex(int index) {
    const flexes = [12, 8, 10, 15, 16, 16, 10, 10, 14];
    return flexes[index];
  }

  Widget _buildColumnCell(String text, int flex, {bool isHeader = false}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          text,
          style: isHeader
              ? AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textSecondary)
              : AppTheme.sans(size: 13, color: AppColors.textPrimary),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _HoverTxRow extends StatefulWidget {
  final Transaction tx;
  final bool isLast;
  final int Function(int) flexFns;

  const _HoverTxRow({required this.tx, required this.isLast, required this.flexFns});

  @override
  _HoverTxRowState createState() => _HoverTxRowState();
}

class _HoverTxRowState extends State<_HoverTxRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final amtFmt = NumberFormat('#,##0.00');
    final timeFmt = DateFormat('MMM d, HH:mm');
    final isHighRisk = widget.tx.level == 'high';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _isHovered
              ? AppColors.primary.withValues(alpha: 0.05)
              : (isHighRisk ? AppColors.fraudDim.withValues(alpha: 0.1) : Colors.transparent),
          border: Border(
            left: BorderSide(
              color: _isHovered ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
            bottom: widget.isLast ? BorderSide.none : const BorderSide(color: AppColors.border),
          ),
        ),
        child: InkWell(
          onTap: () {},
          child: Row(
            children: [
              _cell(widget.tx.id, 0, mono: true),
              _widgetCell(StatusBadge.domainStr(widget.tx.domain), 1),
              _cell(widget.tx.type, 2, size: 11),
              _cell('${widget.tx.currency} ${amtFmt.format(widget.tx.amount)}', 3, mono: true),
              _cell(widget.tx.sender, 4, muted: true),
              _cell(widget.tx.receiver, 5, muted: true),
              _riskCell(widget.tx.riskPercent, widget.tx.riskScore, 6),
              _widgetCell(StatusBadge.level(widget.tx.level), 7),
              _cell(timeFmt.format(widget.tx.timestamp), 8, muted: true, size: 11),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(String text, int index, {bool mono = false, bool muted = false, double size = 13}) =>
      Expanded(
        flex: widget.flexFns(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            text,
            style: mono
                ? AppTheme.mono(size: size, color: muted ? AppColors.textSecondary : AppColors.textPrimary)
                : AppTheme.sans(size: size, color: muted ? AppColors.textSecondary : AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );

  Widget _widgetCell(Widget child, int index) => Expanded(
    flex: widget.flexFns(index),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Align(alignment: Alignment.centerLeft, child: child),
    ),
  );

  Widget _riskCell(int riskPercent, double rawScore, int index) {
    final color = rawScore >= 0.70
        ? AppColors.fraud
        : rawScore >= 0.40
            ? AppColors.suspicious
            : AppColors.safe;
    return Expanded(
      flex: widget.flexFns(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Text('$riskPercent', style: AppTheme.mono(size: 13, weight: FontWeight.w700, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: _isHovered
                    ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rawScore,
                  minHeight: 6,
                  backgroundColor: AppColors.bg,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

