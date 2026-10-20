import 'package:flutter/material.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/presentation/screens/credit_account_detail_screen.dart';
import 'package:pos_tablet/presentation/screens/scheduled_payments_screen.dart';
import 'package:pos_tablet/presentation/widgets/credit/credit_collect_payment_dialog.dart';
import 'package:pos_tablet/presentation/widgets/customer_select_sheet.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import 'package:pos_tablet/core/currency_format.dart';

enum _CreditSortMode { highest, longPending }

class CreditsScreen extends StatefulWidget {
  /// When set, the list is scoped to this customer (from customer profile).
  final String? customerId;
  final String? customerName;

  const CreditsScreen({super.key, this.customerId, this.customerName});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  List<StoreCustomerCreditSummary> _summaries = const [];
  List<StoreCreditRecord> _records = const [];
  List<StoreCreditRepaymentRecord> _repayments = const [];
  bool _loading = true;
  String? _error;
  bool _outstandingOnly = false;
  _CreditSortMode _sortMode = _CreditSortMode.highest;
  final TextEditingController _searchController = TextEditingController();

  String get _scopedCustomerId => (widget.customerId ?? '').trim();

  bool get _isCustomerScoped => _scopedCustomerId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final name = (widget.customerName ?? '').trim();
    if (name.isNotEmpty) {
      _searchController.text = name;
    }
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = getIt<UiStoreController>();
      final summaries = await controller.loadCreditSummaries(
        sortBy: _sortMode == _CreditSortMode.longPending
            ? StoreCreditCustomerSortBy.pending
            : StoreCreditCustomerSortBy.amount,
        descending: _sortMode != _CreditSortMode.longPending,
      );
      final records = await controller.loadCreditRecords();
      final repayments = await controller.loadCreditRepayments();
      if (!mounted) return;
      setState(() {
        _summaries = summaries;
        _records = records;
        _repayments = repayments;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _setSortMode(_CreditSortMode mode) async {
    if (_sortMode == mode) return;
    setState(() => _sortMode = mode);
    await _load();
  }

  int _creditAgeDays(StoreCreditRecord credit, DateTime now) {
    if (credit.settled || credit.outstandingAmount <= 0.0001) return -1;
    final due = credit.dueDate?.trim();
    final raw = (due != null && due.isNotEmpty) ? due : credit.createdOn.trim();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return 0;
    return now.difference(parsed.toLocal()).inDays;
  }

  bool _isAdvanceRepayment(StoreCreditRepaymentRecord repayment) {
    return repayment.localId.startsWith('customer-advance') ||
        (repayment.advanceAmount > 0.0001 &&
            repayment.allocatedAmount <= 0.0001);
  }

  Map<String, double> get _advanceTotalsByCustomer {
    final totals = <String, double>{};
    for (final repayment in _repayments.where(_isAdvanceRepayment)) {
      totals.update(
        repayment.customerId,
        (value) => value + repayment.totalAmount,
        ifAbsent: () => repayment.totalAmount,
      );
    }
    return totals;
  }

  Map<String, double> get _advanceBalanceByCustomer {
    final balances = <String, double>{};
    for (final repayment in _repayments) {
      balances.update(
        repayment.customerId,
        (value) => value + repayment.advanceAmount,
        ifAbsent: () => repayment.advanceAmount,
      );
    }
    return balances;
  }

  double _netBalanceFor(StoreCustomerCreditSummary row) {
    final advance = _advanceBalanceByCustomer[row.customerId] ?? 0;
    return row.totalOutstandingAmount - advance;
  }

  /// Cumulative outstanding aged at least [minDays] (30+, 60+, 90+).
  double _agingAtLeast(int minDays) {
    final now = DateTime.now();
    return _records.fold<double>(0, (sum, credit) {
      final age = _creditAgeDays(credit, now);
      if (age < minDays) return sum;
      return sum + credit.outstandingAmount;
    });
  }

  int? _pendingDaysFor(StoreCustomerCreditSummary row) {
    final raw = row.oldestOutstandingOn?.trim();
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return DateTime.now().difference(parsed.toLocal()).inDays;
  }

  List<StoreCustomerCreditSummary> get _filteredSummaries {
    final query = _searchController.text.trim().toLowerCase();
    final scopedId = _normalizeCustomerId(_scopedCustomerId);
    return _summaries
        .where((row) {
          if (scopedId.isNotEmpty &&
              _normalizeCustomerId(row.customerId) != scopedId) {
            return false;
          }
          if (_outstandingOnly && _netBalanceFor(row) <= 0.0001) {
            return false;
          }
          if (query.isEmpty) return true;
          final name = row.customerName.toLowerCase();
          final id = row.customerId.toLowerCase();
          return name.contains(query) || id.contains(query);
        })
        .toList(growable: false);
  }

  String _normalizeCustomerId(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('user_')) return raw;
    if (int.tryParse(raw) != null) return 'user_$raw';
    return raw;
  }

  Future<void> _openCollectPayment({
    required String customerId,
    required String customerName,
    required double outstanding,
    int? preferCreditId,
  }) async {
    if (outstanding <= 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.creditsNothingOutstanding)),
      );
      return;
    }

    final result = await showDialog<CreditCollectPaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreditCollectPaymentDialog(
        customerName: customerName,
        outstanding: outstanding,
      ),
    );
    if (result == null || !mounted) return;

    try {
      final controller = getIt<UiStoreController>();
      await controller.collectCreditPayment(
        customerId: customerId,
        amount: result.amount,
        paymentMode: result.paymentMode,
        referenceId: result.referenceId,
        preferCreditId: preferCreditId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.creditsCollectedVia(
              PosCurrency.format(result.amount),
              result.paymentMode,
            ),
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.errorCollectFailed(error.toString())),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _openAccount(StoreCustomerCreditSummary row) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreditAccountDetailScreen(
          customerId: row.customerId,
          customerName: row.customerName,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openOrAddCreditAccount() async {
    final selected = await showCustomerSelectSheet(
      context,
      title: context.l10n.commonOpenCreditAccount,
      confirmLabel: context.l10n.commonOpenCreditAccount,
    );
    if (selected == null || !mounted) return;

    final customerId = selected.customerUniqueId.trim();
    if (customerId.isEmpty) return;

    final customerName = selected.name.trim().isEmpty
        ? context.l10n.commonCustomer
        : selected.name.trim();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreditAccountDetailScreen(
          customerId: customerId,
          customerName: customerName,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = _summaries.fold<double>(
      0,
      (sum, row) => sum + _netBalanceFor(row),
    );
    final aging30 = _agingAtLeast(30);
    final aging60 = _agingAtLeast(60);
    final aging90 = _agingAtLeast(90);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isCustomerScoped
              ? context.l10n.creditsCustomerScopedTitle(
                  (widget.customerName ?? '').trim().isEmpty
                      ? context.l10n.commonCustomer
                      : widget.customerName!.trim(),
                )
              : context.l10n.commonCredit,
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.commonOpenCreditAccount,
            onPressed: _openOrAddCreditAccount,
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Color(0xFF4A00E0),
            ),
          ),
          IconButton(
            tooltip: context.l10n.actionRefresh,
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4A00E0)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.withValues(alpha: 0.2),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScheduledPaymentsScreen(),
                        ),
                      ).then((_) => _load());
                    },
                    icon: const Icon(Icons.event_note_rounded),
                    label: Text(context.l10n.creditsSchedulePayments),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      foregroundColor: const Color(0xFF4A00E0),
                      side: const BorderSide(color: Color(0xFF4A00E0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _summaryChip(
                            context.l10n.commonBalanceDue,
                            PosCurrency.format(outstanding),
                            outstanding > 0.0001
                                ? const Color(0xFFFF512F)
                                : outstanding < -0.0001
                                ? Colors.green.shade700
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryChip(
                            '30+',
                            PosCurrency.format(aging30),
                            const Color(0xFFFF8A00),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryChip(
                            '60+',
                            PosCurrency.format(aging60),
                            const Color(0xFFE65100),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryChip(
                            '90+',
                            PosCurrency.format(aging90),
                            const Color(0xFFB71C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: context.l10n.creditsSearchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: Text(context.l10n.creditsOutstandingOnly),
                    selected: _outstandingOnly,
                    onSelected: (value) {
                      setState(() => _outstandingOnly = value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    context.l10n.creditsSort,
                    style: FontUtility.body.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(width: 10),
                  _sortButton(
                    label: context.l10n.creditsSortHighest,
                    selected: _sortMode == _CreditSortMode.highest,
                    onTap: () => _setSortMode(_CreditSortMode.highest),
                  ),
                  const SizedBox(width: 8),
                  _sortButton(
                    label: context.l10n.creditsSortLongPending,
                    selected: _sortMode == _CreditSortMode.longPending,
                    onTap: () => _setSortMode(_CreditSortMode.longPending),
                  ),
                  const Spacer(),
                  Text(
                    context.l10n.creditsAccountCount(_filteredSummaries.length),
                    style: FontUtility.body.copyWith(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF4A00E0).withValues(alpha: 0.15),
      labelStyle: FontUtility.body.copyWith(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: selected ? const Color(0xFF4A00E0) : Colors.black87,
      ),
      side: BorderSide(
        color: selected
            ? const Color(0xFF4A00E0)
            : Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: FontUtility.body.copyWith(color: Colors.black54)),
          const SizedBox(height: 8),
          Text(
            value,
            style: FontUtility.heading.copyWith(fontSize: 20, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: FontUtility.body.copyWith(color: Colors.red)),
            TextButton(onPressed: _load, child: Text(context.l10n.actionRetry)),
          ],
        ),
      );
    }

    final rows = _filteredSummaries;
    if (_summaries.isEmpty) {
      return _empty(context.l10n.creditsNoAccountsYet);
    }
    if (rows.isEmpty) {
      return _empty(context.l10n.creditsNoAccountsMatch);
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = rows[index];
        final netBalance = _netBalanceFor(row);
        final canCollect = netBalance > 0.0001;
        final advances = _advanceTotalsByCustomer[row.customerId] ?? 0;
        final name = row.customerName.trim().isEmpty
            ? context.l10n.commonCustomer
            : row.customerName;
        final pendingDays = _pendingDaysFor(row);
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openAccount(row),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(
                      0xFFFF512F,
                    ).withValues(alpha: 0.12),
                    child: Text(
                      name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFFF512F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: FontUtility.subheading.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            '${row.creditCount} ${context.l10n.creditsCreditSales}',
                            '${context.l10n.creditsCreditSoFar} ${PosCurrency.format(row.totalCreditAmount)}',
                            'Advances ${PosCurrency.format(advances)}',
                            '${context.l10n.creditsRepaid} ${PosCurrency.format(row.totalPaidAmount)}',
                            if (pendingDays != null)
                              '${context.l10n.commonPending}: ${pendingDays}d',
                          ].join(' · '),
                          style: FontUtility.body.copyWith(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        PosCurrency.format(netBalance),
                        style: FontUtility.heading.copyWith(
                          fontSize: 18,
                          color: netBalance > 0.0001
                              ? const Color(0xFFFF512F)
                              : netBalance < -0.0001
                              ? Colors.green.shade700
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.commonBalanceDue,
                        style: FontUtility.body.copyWith(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: canCollect
                            ? () => _openCollectPayment(
                                customerId: row.customerId,
                                customerName: row.customerName,
                                outstanding: netBalance,
                              )
                            : null,
                        child: Text(context.l10n.creditsCollect),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _empty(String message) {
    return Center(
      child: Text(
        message,
        style: FontUtility.body.copyWith(color: Colors.black54),
        textAlign: TextAlign.center,
      ),
    );
  }
}
