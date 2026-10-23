import 'package:flutter/material.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/core/device_setup_store.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/org_timezone.dart';
import 'package:pos_tablet/core/utils/customer_identity.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/presentation/widgets/credit/credit_collect_payment_dialog.dart';
import 'package:pos_tablet/presentation/widgets/credit/credit_schedule_repayment_dialog.dart';
import 'package:pos_tablet/presentation/widgets/credit/customer_advance_dialog.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_tablet/presentation/widgets/pos_brand_logo.dart';

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
  List<StoreCreditRecord> _credits = [];
  List<StoreCreditRepaymentRecord> _repayments = [];
  List<StoreCustomerLedgerEntry> _ledger = [];
  List<StoreCreditInstallmentRecord> _installments = [];
  List<StoreScheduledCreditRepayment> _scheduled = [];
  double _advanceBalance = 0;
  double? _creditLimitMax;
  bool _creditLimitIsCustomer = false;
  bool _creditLimitHardBlock = false;
  int _creditNetDays = 14;
  String _identityLabel = '';
  bool _isSupplierAccount = false;
  double _totalAdvances = 0;

  String get _advanceLabel {
    final isTamil = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('ta');
    return isTamil ? 'முன்பணம்' : 'Advance';
  }

  String get _purchaseCreditLabel {
    final isTamil = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('ta');
    return isTamil ? 'கொள்முதல் கடன்' : 'Purchase Credit';
  }

  String get _purchaseRepaymentLabel {
    final isTamil = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('ta');
    return isTamil ? 'கொள்முதல் திருப்பிச் செலுத்தல்' : 'Purchase Repayment';
  }

  String get _appliedLabel {
    final isTamil = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('ta');
    return isTamil ? 'பயன்படுத்தப்பட்டது' : 'Applied';
  }

  String get _creditsSectionTitle {
    final isTamil = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('ta');
    if (_isSupplierAccount) {
      return isTamil ? 'கொள்முதல் கடன்கள்' : 'Purchase Credits';
    }
    return context.l10n.creditsCreditSales;
  }

  String get _displayName => widget.customerName.trim().isEmpty
      ? context.l10n.commonCustomer
      : widget.customerName.trim();

  double get _creditSoFar =>
      _credits.fold<double>(0, (sum, row) => sum + row.amount);

  double get _repaid =>
      _credits.fold<double>(0, (sum, row) => sum + row.paidAmount);

  double get _outstanding =>
      _credits.fold<double>(0, (sum, row) => sum + row.outstandingAmount);

  double get _accountBalance => _outstanding - _advanceBalance;

  double get _creditUsedRatio {
    final limit = _creditLimitMax;
    if (limit == null || limit <= 0) return 0;
    final used = _accountBalance > 0 ? _accountBalance : 0.0;
    return (used / limit).clamp(0.0, 1.0);
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
      final directoryCustomer = await controller.loadCustomerById(
        widget.customerId,
      );
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
      final advanceBalance = await controller.loadCustomerAdvanceBalance(
        widget.customerId,
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
        _advanceBalance = advanceBalance;
        _isSupplierAccount = directoryCustomer?.role == 'supplier';
        _totalAdvances = repayments
            .where(_isAdvanceRepayment)
            .fold<double>(0, (sum, row) => sum + row.totalAmount);
        _creditLimitMax = (customerLimit != null && customerLimit > 0)
            ? customerLimit
            : storeLimit;
        _creditLimitIsCustomer = customerLimit != null && customerLimit > 0;
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

  Future<void> _collect({
    int? preferCreditId,
    double? outstandingOverride,
  }) async {
    final outstanding =
        outstandingOverride ?? (_accountBalance > 0 ? _accountBalance : 0.0);
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

  Future<void> _addAdvance() async {
    final result = await showDialog<CustomerAdvanceResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomerAdvanceDialog(
        customerName: _displayName,
        accountBalance: _accountBalance,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await getIt<UiStoreController>().recordCustomerAdvance(
        customerId: widget.customerId,
        amount: result.amount,
        paymentMode: result.paymentMode,
        referenceId: result.referenceId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.customerAdvanceRecorded),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
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
            context.l10n.creditsScheduledFor(
              PosCurrency.format(result.amount),
              result.dueDateIso,
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
          content: Text(context.l10n.errorScheduleFailed(error.toString())),
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
          title: Text(context.l10n.creditsCancelScheduleTitle),
          content: Text(
            context.l10n.creditsCancelScheduleBody(
              PosCurrency.format(schedule.amount),
              schedule.dueDate,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.actionKeep),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.creditsCancelScheduleAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await getIt<UiStoreController>().cancelScheduledCreditRepayment(
        schedule.id,
      );
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.creditsCancelFailed(error.toString())),
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
            context.l10n.creditsCollectedScheduled(
              PosCurrency.format(result.amount),
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

  Future<void> _voidRepayment(StoreCreditRepaymentRecord repayment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.creditsVoidRepaymentTitle),
          content: Text(
            context.l10n.creditsVoidRepaymentBody(
              PosCurrency.format(repayment.totalAmount),
              _shortDate(repayment.paidOn),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.commonVoid),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    try {
      await getIt<UiStoreController>().voidCreditRepayment(
        repaymentId: repayment.id,
        reason: context.l10n.creditsVoidedOnPos,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.creditsRepaymentVoided)),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.errorVoidFailed(error.toString())),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  String? get _orgTimezoneName {
    try {
      return getIt<UiStoreController>().orgTimezoneName;
    } catch (_) {
      return null;
    }
  }

  String _shortDate(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '-';
    // Date-only values (due dates) are calendar days; instants use org time.
    final parsed = value.length > 10
        ? OrgTimezone.tryParseWallClock(value, _orgTimezoneName)
        : DateTime.tryParse(value);
    if (parsed == null) {
      return value.length >= 10 ? value.substring(0, 10) : value;
    }
    return '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
  }

  bool _isAdvanceRepayment(StoreCreditRepaymentRecord repayment) {
    return repayment.localId.startsWith('customer-advance') ||
        (repayment.advanceAmount > 0.0001 &&
            repayment.allocatedAmount <= 0.0001);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: PosBrandTitle(
          child: Text(
          context.l10n.creditsCreditAccount,
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.actionRefresh,
            onPressed: _loading ? null : _load,
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
                    TextButton(
                      onPressed: _load,
                      child: Text(context.l10n.actionRetry),
                    ),
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
                      style: FontUtility.body.copyWith(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard(
                            context.l10n.commonBalanceDue,
                            PosCurrency.format(_accountBalance),
                            _accountBalance > 0.0001
                                ? const Color(0xFFFF512F)
                                : _accountBalance < -0.0001
                                ? Colors.green.shade700
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _metricCard(
                            _isSupplierAccount
                                ? _purchaseCreditLabel
                                : context.l10n.creditsCreditSoFar,
                            PosCurrency.format(_creditSoFar),
                            const Color(0xFF4A00E0),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _metricCard(
                            context.l10n.creditsRepaid,
                            PosCurrency.format(_repaid),
                            Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _metricCard(
                            'Advances',
                            PosCurrency.format(_totalAdvances),
                            Colors.teal.shade700,
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
                            onPressed: _accountBalance > 0.0001
                                ? _collect
                                : null,
                            icon: const Icon(Icons.payments_outlined),
                            label: Text(context.l10n.creditsCollectPayment),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _addAdvance,
                            icon: const Icon(Icons.add_card_rounded),
                            label: Text(context.l10n.customerAdvanceAdd),
                          ),
                          OutlinedButton.icon(
                            onPressed: _scheduleRepayment,
                            icon: const Icon(Icons.event_available_rounded),
                            label: Text(context.l10n.creditsScheduleRepayment),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionCard(
                      title: context.l10n.creditsUpcoming,
                      child: _scheduled.isEmpty
                          ? _emptyInline(context.l10n.creditsNoUpcoming)
                          : Column(
                              children: [
                                for (final schedule in _scheduled)
                                  _scheduledRow(schedule),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      title: context.l10n.commonLedger,
                      child: _ledger.isEmpty
                          ? _emptyInline(context.l10n.creditsNoLedger)
                          : Column(
                              children: [
                                for (final entry in _ledger) _ledgerRow(entry),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      title: _creditsSectionTitle,
                      child: _credits.isEmpty
                          ? _emptyInline(context.l10n.creditsNoCreditSales)
                          : Column(
                              children: [
                                for (final credit in _credits)
                                  _creditSaleRow(credit),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      title: context.l10n.creditsPaymentSchedules,
                      child: _installments.isEmpty
                          ? _emptyInline(context.l10n.creditsNoSchedules)
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
                                        '${context.l10n.creditsCreditNumber(credit.id.toString())}'
                                        '${credit.dueDate == null || credit.dueDate!.isEmpty ? '' : ' · ${context.l10n.commonDueValue(credit.dueDate!)}'}',
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
                      title: context.l10n.dashboardRepayments,
                      child: _repayments.isEmpty
                          ? _emptyInline(context.l10n.creditsNoRepaymentsYet)
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
    final used = _accountBalance > 0 ? _accountBalance : 0.0;
    final remaining = hasLimit ? (limit - used).clamp(0.0, limit) : 0.0;
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
                      ? context.l10n.creditsCustomerLimit
                      : context.l10n.creditsStoreSettings,
                  style: FontUtility.subheading.copyWith(fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      (_creditLimitHardBlock
                              ? const Color(0xFFB71C1C)
                              : const Color(0xFF4A00E0))
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _creditLimitHardBlock
                      ? context.l10n.creditsHardBlock
                      : context.l10n.creditsWarnOnly,
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
          if (hasLimit) ...[
            const SizedBox(height: 12),
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
                        context.l10n.creditsCreditLimit,
                        style: FontUtility.body.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.creditsMaxAmount(
                          PosCurrency.format(limit),
                        ),
                        style: FontUtility.heading.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.creditsUsedAvailable(
                          PosCurrency.format(used),
                          PosCurrency.format(remaining),
                        ),
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
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _settingChip(
                context.l10n.creditsLimit,
                hasLimit
                    ? PosCurrency.format(limit)
                    : context.l10n.creditsNotSet,
              ),
              _settingChip(
                context.l10n.creditsNetTerms,
                context.l10n.creditsNetTermsDays(_creditNetDays),
              ),
              _settingChip(
                context.l10n.creditsOverLimit,
                _creditLimitHardBlock
                    ? context.l10n.creditsBlocked
                    : context.l10n.creditsAllowedWarn,
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
                  PosCurrency.format(schedule.amount),
                  style: FontUtility.subheading.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${context.l10n.commonDueValue(schedule.dueDate)}'
                  '${schedule.isOverdue ? ' · ${context.l10n.commonOverdue.toLowerCase()}' : ''}',
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
            child: Text(context.l10n.actionCancel),
          ),
          const SizedBox(width: 4),
          FilledButton.tonal(
            onPressed: () => _collectScheduled(schedule),
            child: Text(context.l10n.creditsCollect),
          ),
        ],
      ),
    );
  }

  Widget _ledgerRow(StoreCustomerLedgerEntry entry) {
    final isCredit = entry.entryType == StoreCustomerLedgerEntryType.credit;
    final repayment = isCredit
        ? null
        : _repayments.where((row) => row.id == entry.entryId).firstOrNull;
    final isAdvanceRepayment =
        repayment != null && _isAdvanceRepayment(repayment);
    final title = isCredit
        ? (entry.orderId == null
              ? (_isSupplierAccount
                    ? _purchaseCreditLabel
                    : context.l10n.creditsCreditSalePlain)
              : (_isSupplierAccount
                    ? '$_purchaseCreditLabel · ${context.l10n.commonOrderLabel} ${entry.orderId}'
                    : context.l10n.creditsCreditSaleOrder('${entry.orderId}')))
        : isAdvanceRepayment
        ? _advanceLabel
        : _isSupplierAccount
        ? _purchaseRepaymentLabel
        : context.l10n.creditsRepaymentMode(
            (entry.paymentMode ?? '-').toUpperCase(),
          );
    final amountColor = isCredit
        ? const Color(0xFFFF512F)
        : Colors.green.shade700;
    final amountPrefix = isCredit ? '+' : '-';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FontUtility.subheading.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_shortDate(entry.timestamp)}'
                  '${!isCredit && !isAdvanceRepayment && _isSupplierAccount ? ' · ${(entry.paymentMode ?? '-').toUpperCase()}' : ''}'
                  '${entry.referenceId == null || entry.referenceId!.isEmpty ? '' : ' · ${entry.referenceId}'}'
                  '${entry.deleted ? ' · ${context.l10n.creditsLedgerVoided}' : ''}',
                  style: FontUtility.body.copyWith(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$amountPrefix${PosCurrency.format(entry.amount)}',
            style: FontUtility.heading.copyWith(
              fontSize: 15,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _creditSaleRow(StoreCreditRecord credit) {
    final title = _isSupplierAccount
        ? '$_purchaseCreditLabel · ${context.l10n.commonOrderLabel} ${credit.orderId}'
        : context.l10n.creditsCreditOrderLine(
            credit.id.toString(),
            credit.orderId.toString(),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FontUtility.subheading.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_shortDate(credit.createdOn)}'
                  '${credit.dueDate == null || credit.dueDate!.isEmpty ? '' : ' · ${context.l10n.commonDueValue(credit.dueDate!)}'}'
                  ' · ${credit.settled ? context.l10n.commonSettled : context.l10n.commonOpen}',
                  style: FontUtility.body.copyWith(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                if (_isSupplierAccount && credit.paidAmount > 0.0001) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${_advanceLabel} ${context.l10n.commonOfAmount(PosCurrency.format(credit.paidAmount))} ${_appliedLabel.toLowerCase()}',
                    style: FontUtility.body.copyWith(
                      fontSize: 12,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                PosCurrency.format(credit.outstandingAmount),
                style: FontUtility.heading.copyWith(
                  fontSize: 15,
                  color: credit.settled
                      ? Colors.green.shade700
                      : const Color(0xFFFF512F),
                ),
              ),
              Text(
                context.l10n.commonOfAmount(PosCurrency.format(credit.amount)),
                style: FontUtility.body.copyWith(
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
              if (!credit.settled) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => _collect(
                    preferCreditId: credit.id,
                    outstandingOverride: credit.outstandingAmount,
                  ),
                  child: Text(context.l10n.creditsCollect),
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
              '${inst.overdue ? context.l10n.commonOverdueSuffix : ''}'
              ' · ${inst.status}',
              style: FontUtility.body.copyWith(
                fontSize: 13,
                color: inst.overdue ? Colors.red.shade700 : Colors.black54,
              ),
            ),
          ),
          Text(
            PosCurrency.format(inst.outstandingAmount),
            style: FontUtility.heading.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _repaymentRow(StoreCreditRepaymentRecord repayment) {
    final voided = repayment.deleted;
    final isAdvance = _isAdvanceRepayment(repayment);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${PosCurrency.format(repayment.totalAmount)} · ${isAdvance ? _advanceLabel : repayment.paymentMode.toUpperCase()}',
                  style: FontUtility.subheading.copyWith(
                    fontSize: 14,
                    decoration: voided ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_shortDate(repayment.paidOn)}'
                  '${isAdvance ? ' · ${repayment.paymentMode.toUpperCase()}' : ''}'
                  '${repayment.referenceId == null || repayment.referenceId!.isEmpty ? '' : ' · ${repayment.referenceId}'}'
                  '${voided ? ' · ${context.l10n.creditsLedgerVoided}' : ''}',
                  style: FontUtility.body.copyWith(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (!voided)
            TextButton(
              onPressed: () => _voidRepayment(repayment),
              child: Text(
                context.l10n.commonVoid,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
        ],
      ),
    );
  }
}
