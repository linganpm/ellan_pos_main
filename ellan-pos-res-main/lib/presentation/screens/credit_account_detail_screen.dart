import 'package:flutter/material.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/device_setup_store.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/utils/customer_identity.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/presentation/widgets/credit/credit_collect_payment_dialog.dart';
import 'package:pos_tablet/presentation/widgets/credit/credit_schedule_repayment_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreditAccountDetailScreen extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CreditAccountDetailScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CreditAccountDetailScreen> createState() =>
      _CreditAccountDetailScreenState();
}

class _CreditAccountDetailScreenState extends State<CreditAccountDetailScreen> {
  bool _loading = true;
  String? _error;
  List<StoreCreditRecord> _credits = const [];
  List<StoreCreditRepaymentRecord> _repayments = const [];
  List<StoreCustomerLedgerEntry> _ledger = const [];
  List<StoreCreditInstallmentRecord> _installments = const [];
  List<StoreScheduledCreditRepayment> _scheduled = const [];
  double? _creditLimitMax;
  bool _creditLimitIsCustomer = false;
  bool _creditLimitHardBlock = false;
  int _creditNetDays = 14;
  String _identityLabel = '';

  String get _displayName =>
      widget.customerName.trim().isEmpty ? 'Customer' : widget.customerName.trim();

  double get _creditSoFar =>
      _credits.fold<double>(0, (sum, row) => sum + row.amount);

  double get _repaid =>
      _credits.fold<double>(0, (sum, row) => sum + row.paidAmount);

  double get _outstanding =>
      _credits.fold<double>(0, (sum, row) => sum + row.outstandingAmount);

  double get _creditUsedRatio {
    final limit = _creditLimitMax;
    if (limit == null || limit <= 0) return 0;
    return (_outstanding / limit).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = getIt<UiStoreController>();
      final directoryCustomer =
          await controller.loadCustomerById(widget.customerId);
      final account = await controller.loadCreditAccount(widget.customerId);
      final credits = await controller.loadCreditRecords(
        customerId: widget.customerId,
      );
      final repayments = await controller.loadCreditRepayments(
        customerId: widget.customerId,
      );
      final ledger = await controller.loadCustomerCreditLedger(
        customerId: widget.customerId,
      );
      final installments = await controller.loadCreditInstallments();
      final scheduled = await controller.loadScheduledCreditRepayments(
        customerId: widget.customerId,
      );
      final creditIds = credits.map((row) => row.id).toSet();
      final scopedInstallments = installments
          .where((row) => creditIds.contains(row.creditId))
          .toList(growable: false);
      final prefs = getIt<SharedPreferences>();
      final setupStore = DeviceSetupStore(prefs);
      final identity = displayCustomerIdentity(
        regNum: directoryCustomer?.usrRegNum,
        customerId: widget.customerId,
        email: directoryCustomer?.email,
      );
      // Prefer per-customer limit from synced credit account; fall back to
      // store-wide credit_settings for older servers / unset accounts.
      final customerLimit = account?.creditLimitAmount;
      final storeLimit = setupStore.creditLimitAmount;
      if (!mounted) return;
      setState(() {
        _credits = credits;
        _repayments = repayments;
        _ledger = ledger;
        _installments = scopedInstallments;
        _scheduled = scheduled;
        _creditLimitMax = (customerLimit != null && customerLimit > 0)
            ? customerLimit
            : storeLimit;
        _creditLimitIsCustomer =
            customerLimit != null && customerLimit > 0;
        _creditLimitHardBlock = setupStore.creditLimitHardBlock;
        _creditNetDays = setupStore.creditNetDays;
        _identityLabel = identity;
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

  Future<void> _collect({int? preferCreditId, double? outstandingOverride}) async {
    final outstanding = outstandingOverride ?? _outstanding;
    if (outstanding <= 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing outstanding for this customer.')),
      );
      return;
    }

    final result = await showDialog<CreditCollectPaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreditCollectPaymentDialog(
        customerName: _displayName,
        outstanding: outstanding,
      ),
    );
    if (result == null || !mounted) return;

    try {
      await getIt<UiStoreController>().collectCreditPayment(
        customerId: widget.customerId,
        amount: result.amount,
        paymentMode: result.paymentMode,
        referenceId: result.referenceId,
        preferCreditId: preferCreditId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Collected \$${result.amount.toStringAsFixed(2)} via ${result.paymentMode}',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Collect failed: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _scheduleRepayment() async {
    final result = await showDialog<CreditScheduleRepaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreditScheduleRepaymentDialog(
        customerName: _displayName,
        suggestedAmount: _outstanding > 0 ? _outstanding : null,
      ),
    );
    if (result == null || !mounted) return;

    try {
      await getIt<UiStoreController>().scheduleCreditRepayment(
        customerId: widget.customerId,
        amount: result.amount,
        dueDate: result.dueDateIso,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Scheduled \$${result.amount.toStringAsFixed(2)} for ${result.dueDateIso}',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Schedule failed: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _cancelSchedule(StoreScheduledCreditRepayment schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel scheduled repayment'),
          content: Text(
            'Cancel \$${schedule.amount.toStringAsFixed(2)} due ${schedule.dueDate}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel schedule'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await getIt<UiStoreController>()
          .cancelScheduledCreditRepayment(schedule.id);
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cancel failed: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _collectScheduled(StoreScheduledCreditRepayment schedule) async {
    final result = await showDialog<CreditCollectPaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreditCollectPaymentDialog(
        customerName: _displayName,
        outstanding: schedule.amount,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await getIt<UiStoreController>().collectScheduledCreditRepayment(
        scheduleId: schedule.id,
        paymentMode: result.paymentMode,
        referenceId: result.referenceId,
        amount: result.amount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Collected scheduled \$${result.amount.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Collect failed: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _voidRepayment(StoreCreditRepaymentRecord repayment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Void repayment'),
          content: Text(
            'Void \$${repayment.totalAmount.toStringAsFixed(2)} '
            'paid on ${_shortDate(repayment.paidOn)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Void'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    try {
      await getIt<UiStoreController>().voidCreditRepayment(
        repaymentId: repayment.id,
        reason: 'Voided on POS tablet',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Repayment voided.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Void failed: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  String _shortDate(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value.length >= 10 ? value.substring(0, 10) : value;
    return '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Credit account',
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4A00E0)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          style: FontUtility.body.copyWith(color: Colors.red),
                        ),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          _displayName,
                          style: FontUtility.heading.copyWith(fontSize: 26),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _identityLabel.isNotEmpty
                              ? _identityLabel
                              : widget.customerId,
                          style: FontUtility.body
                              .copyWith(fontSize: 13, color: Colors.black54),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _metricCard(
                                'Outstanding',
                                '\$${_outstanding.toStringAsFixed(2)}',
                                const Color(0xFFFF512F),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _metricCard(
                                'Credit so far',
                                '\$${_creditSoFar.toStringAsFixed(2)}',
                                const Color(0xFF4A00E0),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _metricCard(
                                'Repaid',
                                '\$${_repaid.toStringAsFixed(2)}',
                                Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _creditLimitCard(),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed:
                                    _outstanding > 0.0001 ? _collect : null,
                                icon: const Icon(Icons.payments_outlined),
                                label: const Text('Collect payment'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _scheduleRepayment,
                                icon: const Icon(Icons.event_available_rounded),
                                label: const Text('Schedule repayment'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _sectionCard(
                          title: 'Upcoming repayments',
                          child: _scheduled.isEmpty
                              ? _emptyInline(
                                  'No upcoming repayments scheduled.',
                                )
                              : Column(
                                  children: [
                                    for (final schedule in _scheduled)
                                      _scheduledRow(schedule),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                        _sectionCard(
                          title: 'Ledger',
                          child: _ledger.isEmpty
                              ? _emptyInline('No ledger activity yet.')
                              : Column(
                                  children: [
                                    for (final entry in _ledger)
                                      _ledgerRow(entry),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                        _sectionCard(
                          title: 'Credit sales',
                          child: _credits.isEmpty
                              ? _emptyInline('No credit sales for this customer.')
                              : Column(
                                  children: [
                                    for (final credit in _credits)
                                      _creditSaleRow(credit),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                        _sectionCard(
                          title: 'Payment schedules',
                          child: _installments.isEmpty
                              ? _emptyInline(
                                  'No installment schedules on this account.',
                                )
                              : Column(
                                  children: [
                                    for (final credit in _credits.where(
                                      (c) => _installments.any(
                                        (i) => i.creditId == c.id,
                                      ),
                                    )) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4,
                                          bottom: 8,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Credit #${credit.id}'
                                            '${credit.dueDate == null || credit.dueDate!.isEmpty ? '' : ' · final due ${credit.dueDate}'}',
                                            style: FontUtility.body.copyWith(
                                              color: Colors.black54,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                      for (final inst in _installments.where(
                                        (i) => i.creditId == credit.id,
                                      ))
                                        _installmentRow(inst),
                                    ],
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                        _sectionCard(
                          title: 'Repayments',
                          child: _repayments.isEmpty
                              ? _emptyInline('No repayments recorded yet.')
                              : Column(
                                  children: [
                                    for (final repayment in _repayments)
                                      _repaymentRow(repayment),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _creditLimitCard() {
    final limit = _creditLimitMax;
    final hasLimit = limit != null && limit > 0;
    final used = _outstanding;
    final remaining =
        hasLimit ? (limit - used).clamp(0.0, limit) : 0.0;
    final ratio = hasLimit ? _creditUsedRatio : 0.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _creditLimitIsCustomer
                      ? 'Customer credit limit'
                      : 'Store credit settings',
                  style: FontUtility.subheading.copyWith(fontSize: 15),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (_creditLimitHardBlock
                          ? const Color(0xFFB71C1C)
                          : const Color(0xFF4A00E0))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _creditLimitHardBlock ? 'Hard block' : 'Warn only',
                  style: FontUtility.body.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _creditLimitHardBlock
                        ? const Color(0xFFB71C1C)
                        : const Color(0xFF4A00E0),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasLimit)
            Text(
              'No credit limit for this customer. Set credit_limit_amount on '
              'Store/CustomerCredit/Account/<id>/ (or store defaults on '
              'Store/CustomerCredit/Settings/), then sync credits.',
              style: FontUtility.body.copyWith(
                fontSize: 13,
                color: Colors.black54,
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: ratio,
                          strokeWidth: 8,
                          backgroundColor: const Color(0xFFEEF1F6),
                          color: ratio >= 0.9
                              ? const Color(0xFFB71C1C)
                              : ratio >= 0.7
                                  ? const Color(0xFFFF8A00)
                                  : const Color(0xFF4A00E0),
                        ),
                      ),
                      Text(
                        '${(ratio * 100).round()}%',
                        style: FontUtility.subheading.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credit limit',
                        style:
                            FontUtility.body.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Max \$${limit.toStringAsFixed(2)}',
                        style: FontUtility.heading.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Used \$${used.toStringAsFixed(2)} · Available \$${remaining.toStringAsFixed(2)}',
                        style: FontUtility.body.copyWith(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFEEF1F6),
                          color: ratio >= 0.9
                              ? const Color(0xFFB71C1C)
                              : ratio >= 0.7
                                  ? const Color(0xFFFF8A00)
                                  : const Color(0xFF4A00E0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _settingChip(
                'Limit',
                hasLimit
                    ? '\$${limit.toStringAsFixed(2)}'
                    : 'Not set',
              ),
              _settingChip('Net terms', '$_creditNetDays days'),
              _settingChip(
                'Over-limit',
                _creditLimitHardBlock ? 'Blocked' : 'Allowed (warn)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settingChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label · ',
              style: FontUtility.body.copyWith(
                fontSize: 11,
                color: Colors.black45,
              ),
            ),
            TextSpan(
              text: value,
              style: FontUtility.body.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, Color color) {
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

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: FontUtility.subheading.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _emptyInline(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: FontUtility.body.copyWith(color: Colors.black54),
      ),
    );
  }

  Widget _scheduledRow(StoreScheduledCreditRepayment schedule) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$${schedule.amount.toStringAsFixed(2)}',
                  style: FontUtility.subheading.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Due ${schedule.dueDate}'
                  '${schedule.isOverdue ? ' · overdue' : ''}',
                  style: FontUtility.body.copyWith(
                    fontSize: 12,
                    color: schedule.isOverdue
                        ? Colors.red.shade700
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _cancelSchedule(schedule),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 4),
          FilledButton.tonal(
            onPressed: () => _collectScheduled(schedule),
            child: const Text('Collect'),
          ),
        ],
      ),
    );
  }

  Widget _ledgerRow(StoreCustomerLedgerEntry entry) {
    final isCredit = entry.entryType == StoreCustomerLedgerEntryType.credit;
    final title = isCredit
        ? 'Credit sale${entry.orderId == null ? '' : ' · Order #${entry.orderId}'}'
        : 'Repayment · ${(entry.paymentMode ?? '-').toUpperCase()}';
    final amountColor =
        isCredit ? const Color(0xFFFF512F) : Colors.green.shade700;
    final amountPrefix = isCredit ? '+' : '-';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FontUtility.subheading.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '${_shortDate(entry.timestamp)}'
                  '${entry.referenceId == null || entry.referenceId!.isEmpty ? '' : ' · ${entry.referenceId}'}'
                  '${entry.deleted ? ' · voided' : ''}',
                  style: FontUtility.body
                      .copyWith(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Text(
            '$amountPrefix\$${entry.amount.toStringAsFixed(2)}',
            style: FontUtility.heading.copyWith(fontSize: 15, color: amountColor),
          ),
        ],
      ),
    );
  }

  Widget _creditSaleRow(StoreCreditRecord credit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Credit #${credit.id} · Order #${credit.orderId}',
                  style: FontUtility.subheading.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_shortDate(credit.createdOn)}'
                  '${credit.dueDate == null || credit.dueDate!.isEmpty ? '' : ' · due ${credit.dueDate}'}'
                  ' · ${credit.settled ? 'Settled' : 'Open'}',
                  style: FontUtility.body
                      .copyWith(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${credit.outstandingAmount.toStringAsFixed(2)}',
                style: FontUtility.heading.copyWith(
                  fontSize: 15,
                  color: credit.settled
                      ? Colors.green.shade700
                      : const Color(0xFFFF512F),
                ),
              ),
              Text(
                'of \$${credit.amount.toStringAsFixed(2)}',
                style: FontUtility.body
                    .copyWith(fontSize: 12, color: Colors.black45),
              ),
              if (!credit.settled) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => _collect(
                    preferCreditId: credit.id,
                    outstandingOverride: credit.outstandingAmount,
                  ),
                  child: const Text('Collect'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _installmentRow(StoreCreditInstallmentRecord inst) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('#${inst.sequence}', style: FontUtility.subheading),
          ),
          Expanded(
            child: Text(
              '${inst.dueDate ?? '-'}'
              '${inst.overdue ? ' · overdue' : ''}'
              ' · ${inst.status}',
              style: FontUtility.body.copyWith(
                fontSize: 13,
                color: inst.overdue ? Colors.red.shade700 : Colors.black54,
              ),
            ),
          ),
          Text(
            '\$${inst.outstandingAmount.toStringAsFixed(2)}',
            style: FontUtility.heading.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _repaymentRow(StoreCreditRepaymentRecord repayment) {
    final voided = repayment.deleted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$${repayment.totalAmount.toStringAsFixed(2)} · ${repayment.paymentMode.toUpperCase()}',
                  style: FontUtility.subheading.copyWith(
                    fontSize: 14,
                    decoration: voided ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_shortDate(repayment.paidOn)}'
                  '${repayment.referenceId == null || repayment.referenceId!.isEmpty ? '' : ' · ${repayment.referenceId}'}'
                  '${voided ? ' · voided' : ''}',
                  style: FontUtility.body
                      .copyWith(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (!voided)
            TextButton(
              onPressed: () => _voidRepayment(repayment),
              child: Text(
                'Void',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
        ],
      ),
    );
  }
}
