import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/font_utility.dart';
import '../../core/controllers/ui_store_controller.dart';
import '../../core/cart_draft_store.dart';
import '../../core/currency_format.dart';
import '../../core/device_settings_store.dart';
import '../../core/device_setup_store.dart';
import '../../bloc/cart/cart_bloc.dart';
import '../../bloc/cart/cart_state.dart';
import '../../bloc/cart/cart_event.dart';
import '../widgets/billing/billing_items_table.dart';
import '../widgets/billing/billing_summary_card.dart';
import '../widgets/billing/calculation_input_section.dart';
import '../widgets/billing/order_add_payment_dialog.dart';
import '../widgets/customer_select_sheet.dart';
import 'invoice_screen.dart';
import 'order_create_screen.dart';

class _TenderLine {
  final String paymentMethod;
  final String paymentLabel;
  final double amount;
  final String? referenceId;
  final int? creditDueInDays;
  final int? creditInstallmentCount;
  final String? creditInstallmentCadence;

  const _TenderLine({
    required this.paymentMethod,
    required this.paymentLabel,
    required this.amount,
    this.referenceId,
    this.creditDueInDays,
    this.creditInstallmentCount,
    this.creditInstallmentCadence,
  });
}

class _CreditCheckoutChoice {
  final int? dueInDays;
  final int? installmentCount;
  final String? installmentCadence;

  const _CreditCheckoutChoice({
    this.dueInDays,
    this.installmentCount,
    this.installmentCadence,
  });
}

enum _WalletPayAction { complete, addPayment }

enum RightPanelMode { payment, discount, tax, tips }

class BillingSummaryScreen extends StatefulWidget {
  final OrderCreateScreenArgs orderArgs;

  const BillingSummaryScreen({
    super.key,
    required this.orderArgs,
  });

  @override
  State<BillingSummaryScreen> createState() => _BillingSummaryScreenState();
}

class _BillingSummaryScreenState extends State<BillingSummaryScreen> {
  RightPanelMode _rightPanelMode = RightPanelMode.payment;
  bool _isCheckingOut = false;
  bool _walletsLoading = true;
  String? _walletsError;
  List<StoreWalletRecord> _wallets = const [];
  final List<_TenderLine> _tenders = [];
  StoreWalletRecord? _selectedWallet;
  final TextEditingController _tenderAmountController = TextEditingController();
  List<double> _denominations = DeviceSettingsStore.parseCashDenominations(
    DeviceSettingsStore.defaultCashDenominations,
  );
  String? _customerUniqueId;
  String? _customerName;
  String? _customerPhone;
  String? _customerEmail;

  @override
  void initState() {
    super.initState();
    _customerUniqueId = widget.orderArgs.customerUniqueId;
    _customerName = widget.orderArgs.name;
    _customerPhone = widget.orderArgs.phone;
    _customerEmail = widget.orderArgs.email;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadWallets();
        _loadDenominations();
      }
    });
  }

  Future<void> _loadDenominations() async {
    try {
      final store = await DeviceSettingsStore.open();
      if (!mounted) return;
      setState(() => _denominations = store.loadCashDenominations());
    } catch (_) {}
  }

  @override
  void dispose() {
    _tenderAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadWallets() async {
    setState(() {
      _walletsLoading = true;
      _walletsError = null;
    });
    try {
      final wallets = await context.read<UiStoreController>().loadWallets();
      if (!mounted) return;
      setState(() {
        _wallets = wallets;
        _walletsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _wallets = const [];
        _walletsLoading = false;
        _walletsError = error.toString();
      });
    }
  }

  IconData _iconForPaymentMode(String paymentMode) {
    switch (paymentMode) {
      case StoreOrderPaymentMode.card:
        return Icons.credit_card_rounded;
      case StoreOrderPaymentMode.online:
        return Icons.qr_code_scanner_rounded;
      case StoreOrderPaymentMode.credit:
        return Icons.account_balance_wallet_rounded;
      case StoreOrderPaymentMode.cash:
      default:
        return Icons.money_rounded;
    }
  }

  Future<bool> _creditLimitAllows({
    required double amountDue,
    required String? customerUniqueId,
    required DeviceSetupStore setupStore,
  }) async {
    final controller = context.read<UiStoreController>();
    final messenger = ScaffoldMessenger.of(context);
    double outstanding = 0;
    double? customerLimit;
    final customerId = customerUniqueId?.trim();
    if (customerId != null && customerId.isNotEmpty) {
      try {
        final account = await controller.loadCreditAccount(customerId);
        customerLimit = account?.creditLimitAmount;
        final records = await controller.loadCreditRecords(customerId: customerId);
        if (!mounted) return false;
        outstanding = records.fold<double>(
          0,
          (sum, row) => sum + row.outstandingAmount,
        );
      } catch (_) {
        // Offline lookup failed — still enforce hard block against this sale alone.
      }
    }

    final limit = (customerLimit != null && customerLimit > 0)
        ? customerLimit
        : setupStore.creditLimitAmount;
    if (limit == null || limit <= 0) return true;

    final projected = outstanding + amountDue;
    if (projected <= limit + 0.0001) return true;

    final message =
        'Credit limit ${PosCurrency.format(limit)} would be exceeded '
        '(outstanding ${PosCurrency.format(outstanding)} + '
        'this sale ${PosCurrency.format(amountDue)}).';

    if (setupStore.creditLimitHardBlock) {
      if (!mounted) return false;
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return false;
    }

    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Credit limit warning'),
        content: Text('$message\n\nContinue anyway?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  double _tenderTotal() =>
      _tenders.fold<double>(0, (sum, line) => sum + line.amount);

  double _remainingDue(double netTotal) {
    final remaining = netTotal - _tenderTotal();
    return remaining <= 0 ? 0 : double.parse(remaining.toStringAsFixed(2));
  }

  Future<bool> _ensureCreditCustomer({
    required double remaining,
  }) async {
    final existingId = _customerUniqueId?.trim();
    if (existingId != null && existingId.isNotEmpty) return true;

    final selected = await showCustomerSelectSheet(
      context,
      title: 'Customer for credit',
      subtitle:
          'Select or add the customer to put ${PosCurrency.format(remaining)} on their credit account.',
      confirmLabel: 'Use customer',
    );
    if (!mounted || selected == null) return false;
    setState(() {
      _customerUniqueId = selected.customerUniqueId;
      _customerName = selected.name;
      _customerPhone = selected.phone;
      _customerEmail = selected.email;
    });
    return true;
  }

  Future<_CreditCheckoutChoice?> _promptCreditPlan({
    required double remaining,
    String paymentLabel = 'Credit',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return null;
    final setupStore = DeviceSetupStore(prefs);
    final defaultNetDays = setupStore.creditNetDays;
    return showDialog<_CreditCheckoutChoice>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var mode = 'oneshot';
        var dueInDays = defaultNetDays;
        var installmentCount = 3;
        var cadence = 'weekly';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('$paymentLabel sale'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remaining on credit: ${PosCurrency.format(remaining)}',
                        style: FontUtility.body,
                      ),
                      const SizedBox(height: 16),
                      Text('Plan', style: FontUtility.subheading),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('One-shot'),
                            selected: mode == 'oneshot',
                            onSelected: (_) =>
                                setDialogState(() => mode = 'oneshot'),
                          ),
                          ChoiceChip(
                            label: const Text('Installments'),
                            selected: mode == 'installments',
                            onSelected: (_) =>
                                setDialogState(() => mode = 'installments'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (mode == 'oneshot') ...[
                        Text('Due date (optional)',
                            style: FontUtility.subheading),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final days in {
                                  0,
                                  7,
                                  14,
                                  30,
                                  defaultNetDays,
                                }.toList()
                                  ..sort())
                              ChoiceChip(
                                label: Text(days == 0 ? 'None' : 'Net $days'),
                                selected: dueInDays == days,
                                onSelected: (_) =>
                                    setDialogState(() => dueInDays = days),
                              ),
                          ],
                        ),
                      ] else ...[
                        Text('Payments', style: FontUtility.subheading),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final count in [2, 3, 4])
                              ChoiceChip(
                                label: Text('$count×'),
                                selected: installmentCount == count,
                                onSelected: (_) => setDialogState(
                                  () => installmentCount = count,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Frequency', style: FontUtility.subheading),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Weekly'),
                              selected: cadence == 'weekly',
                              onSelected: (_) =>
                                  setDialogState(() => cadence = 'weekly'),
                            ),
                            ChoiceChip(
                              label: const Text('Monthly'),
                              selected: cadence == 'monthly',
                              onSelected: (_) =>
                                  setDialogState(() => cadence = 'monthly'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      _CreditCheckoutChoice(
                        dueInDays: mode == 'oneshot' ? dueInDays : null,
                        installmentCount:
                            mode == 'installments' ? installmentCount : null,
                        installmentCadence:
                            mode == 'installments' ? cadence : null,
                      ),
                    );
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Converts remaining balance into a credit tender after customer + plan.
  Future<bool> _attachRemainingAsCredit({
    required double remaining,
  }) async {
    if (remaining <= 0.0001) return true;

    final ready = await _ensureCreditCustomer(remaining: remaining);
    if (!ready || !mounted) return false;

    final plan = await _promptCreditPlan(remaining: remaining);
    if (!mounted || plan == null) return false;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return false;
    final setupStore = DeviceSetupStore(prefs);
    final limitOk = await _creditLimitAllows(
      amountDue: remaining,
      customerUniqueId: _customerUniqueId,
      setupStore: setupStore,
    );
    if (!mounted || !limitOk) return false;

    setState(() {
      _tenders.add(
        _TenderLine(
          paymentMethod: StoreOrderPaymentMode.credit,
          paymentLabel: 'Credit',
          amount: double.parse(remaining.toStringAsFixed(2)),
          creditDueInDays: plan.dueInDays,
          creditInstallmentCount: plan.installmentCount,
          creditInstallmentCadence: plan.installmentCadence,
        ),
      );
    });
    return true;
  }

  Future<void> _saveDraft(BuildContext context, CartState state) async {
    if (_isCheckingOut || state.cartItems.isEmpty) return;
    setState(() => _isCheckingOut = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final cartBloc = context.read<CartBloc>();
    final controller = context.read<UiStoreController>();
    try {
      final orderId = await controller.saveDraftFromCart(
        items: state.cartItems
            .map(
              (item) => CheckoutLineItem(
                productId: item.product.id,
                productVariantId: item.product.id,
                quantity: item.quantity,
                unitPrice: item.product.price,
                lineTotal: item.totalPrice,
                itemName: item.product.name,
                addons: item.addons,
                sellUnitBaseQty: item.product.sellUnitBaseQty,
                sellUnitShort: item.product.sellUnitShort,
              ),
            )
            .toList(growable: false),
        orderType: (widget.orderArgs.orderTypeKey != null &&
                widget.orderArgs.orderTypeKey!.trim().isNotEmpty)
            ? widget.orderArgs.orderTypeKey!.trim()
            : widget.orderArgs.orderType,
        customerName: _customerName ?? widget.orderArgs.name,
        customerPhone: _customerPhone ?? widget.orderArgs.phone,
        customerEmail: _customerEmail ?? widget.orderArgs.email,
        customerUniqueId: _customerUniqueId ?? widget.orderArgs.customerUniqueId,
        tableId: widget.orderArgs.table,
        tipsAmount: state.tipsAmount,
        serviceTaxAmount: state.serviceTaxValue,
        discountAmount: state.discountValue,
        deliveryCharge: state.deliveryCharge,
      );
      if (!mounted) return;
      cartBloc.add(ClearCart());
      messenger.showSnackBar(
        SnackBar(content: Text('Draft order #$orderId saved.')),
      );
      navigator.popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save draft: $error')),
      );
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  Future<void> _completeCheckout(
    BuildContext context,
    CartState state, {
    bool allowBalanceDue = false,
  }) async {
    if (_isCheckingOut || state.cartItems.isEmpty) return;

    var remaining = _remainingDue(state.netTotal);
    if (_tenders.isEmpty && remaining > 0.0001 && !allowBalanceDue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one payment first.')),
      );
      return;
    }
    if (remaining > 0.0001 && !allowBalanceDue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Remaining ${PosCurrency.format(remaining)}. Add another payment or place with balance due.',
          ),
        ),
      );
      return;
    }

    // Remaining balance → customer credit account (select/create customer).
    if (remaining > 0.0001 && allowBalanceDue) {
      final attached = await _attachRemainingAsCredit(remaining: remaining);
      if (!attached || !mounted) return;
      remaining = _remainingDue(state.netTotal);
      if (remaining > 0.0001) return;
    }

    setState(() => _isCheckingOut = true);
    if (_tenders.isNotEmpty) {
      context.read<CartBloc>().add(
            SelectPaymentMethod(_tenders.first.paymentMethod),
          );
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final cartBloc = context.read<CartBloc>();
    final controller = context.read<UiStoreController>();
    final creditCustomerId = _customerUniqueId?.trim();

    try {
      final result = await controller.completeCheckout(
        items: state.cartItems
            .map(
              (item) => CheckoutLineItem(
                productId: item.product.id,
                productVariantId: item.product.id,
                quantity: item.quantity,
                unitPrice: item.product.price,
                lineTotal: item.totalPrice,
                itemName: item.product.name,
                addons: item.addons,
                sellUnitBaseQty: item.product.sellUnitBaseQty,
                sellUnitShort: item.product.sellUnitShort,
              ),
            )
            .toList(growable: false),
        payments: _tenders
            .map(
              (line) => CheckoutPaymentLine(
                paymentMethod: line.paymentMethod,
                amount: line.amount,
                referenceId: line.referenceId,
                creditDueInDays: line.creditDueInDays,
                creditInstallmentCount: line.creditInstallmentCount,
                creditInstallmentCadence: line.creditInstallmentCadence,
              ),
            )
            .toList(growable: false),
        orderType: (widget.orderArgs.orderTypeKey != null &&
                widget.orderArgs.orderTypeKey!.trim().isNotEmpty)
            ? widget.orderArgs.orderTypeKey!.trim()
            : widget.orderArgs.orderType,
        customerName: _customerName ?? widget.orderArgs.name,
        customerPhone: _customerPhone ?? widget.orderArgs.phone,
        customerEmail: _customerEmail ?? widget.orderArgs.email,
        customerUniqueId: creditCustomerId ?? widget.orderArgs.customerUniqueId,
        creditCustomerId: creditCustomerId,
        tableId: widget.orderArgs.table,
        tipsAmount: state.tipsAmount,
        serviceTaxAmount: state.serviceTaxValue,
        discountAmount: state.discountValue,
        deliveryCharge: state.deliveryCharge,
      );

      if (!mounted) return;

      final draftId = widget.orderArgs.draftId;
      if (draftId != null && draftId.isNotEmpty) {
        await CartDraftStore.delete(draftId);
      }

      final usedCredit = _tenders.any(
        (line) => line.paymentMethod == StoreOrderPaymentMode.credit,
      );
      final message = usedCredit
          ? 'Order #${result.orderId} — balance added to customer credit'
          : result.balanceDue > 0.0001
              ? 'Order #${result.orderId} placed with balance ${PosCurrency.format(result.balanceDue)}'
              : 'Order #${result.orderId} paid via ${result.paymentMode}';
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );

      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (navContext) => BlocProvider.value(
            value: cartBloc,
            child: InvoiceScreen(checkoutResult: result),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Checkout failed: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingOut = false);
      }
    }
  }

  Future<_WalletPayAction?> _chooseWalletPayAction({
    required String paymentLabel,
    required double remaining,
  }) {
    return showDialog<_WalletPayAction>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Remaining',
                    style: FontUtility.body.copyWith(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    PosCurrency.format(remaining),
                    style: FontUtility.heading.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4A00E0),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    paymentLabel,
                    style: FontUtility.subheading.copyWith(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(
                        dialogContext,
                        _WalletPayAction.complete,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A00E0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'COMPLETE',
                        style: FontUtility.heading.copyWith(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(
                        dialogContext,
                        _WalletPayAction.addPayment,
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'ADD PAYMENT',
                        style: FontUtility.heading.copyWith(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(
                      'Cancel',
                      style: FontUtility.subheading.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addPaymentFromWallet(
    BuildContext context,
    CartState state,
    StoreWalletRecord wallet,
  ) async {
    if (_isCheckingOut) return;

    final remaining = _remainingDue(state.netTotal);
    if (remaining <= 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order is already fully covered.')),
      );
      return;
    }

    final paymentMethod = wallet.paymentMode;
    final paymentLabel = wallet.label.trim().isEmpty
        ? wallet.paymentMode
        : wallet.label.trim();
    final isCredit = paymentMethod == StoreOrderPaymentMode.credit;

    int? creditDueInDays;
    int? creditInstallmentCount;
    String? creditInstallmentCadence;

    // Cash / Card / Online: pick Complete (finish now) or Add Payment (partial).
    if (!isCredit) {
      final action = await _chooseWalletPayAction(
        paymentLabel: paymentLabel,
        remaining: remaining,
      );
      if (!mounted || action == null) return;

      if (action == _WalletPayAction.complete) {
        setState(() {
          _tenders.add(
            _TenderLine(
              paymentMethod: paymentMethod,
              paymentLabel: paymentLabel,
              amount: double.parse(remaining.toStringAsFixed(2)),
            ),
          );
        });
        await _completeCheckout(context, state);
        return;
      }
      // Add Payment — fall through to amount dialog below.
    }

    if (isCredit) {
      final customerReady =
          await _ensureCreditCustomer(remaining: remaining);
      if (!customerReady || !mounted) return;
      final value = await _promptCreditPlan(
        remaining: remaining,
        paymentLabel: paymentLabel,
      );
      if (!mounted || value == null) return;
      creditDueInDays = value.dueInDays;
      creditInstallmentCount = value.installmentCount;
      creditInstallmentCadence = value.installmentCadence;
    }

    if (!mounted) return;
    final added = await showDialog<OrderAddPaymentResult>(
      context: this.context,
      barrierDismissible: false,
      builder: (_) => OrderAddPaymentDialog(
        remainingAmount: remaining,
        paymentMode: paymentMethod,
        paymentLabel: paymentLabel,
        title: 'Add payment',
        confirmLabel: 'Add payment',
      ),
    );
    if (!mounted || added == null) return;

    if (isCredit) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final setupStore = DeviceSetupStore(prefs);
      final limitCheck = await _creditLimitAllows(
        amountDue: added.amount,
        customerUniqueId: _customerUniqueId,
        setupStore: setupStore,
      );
      if (!mounted || !limitCheck) return;
    }

    setState(() {
      _tenders.add(
        _TenderLine(
          paymentMethod: added.paymentMode,
          paymentLabel: added.paymentLabel,
          amount: added.amount,
          referenceId: added.referenceId,
          creditDueInDays: creditDueInDays,
          creditInstallmentCount: creditInstallmentCount,
          creditInstallmentCadence: creditInstallmentCadence,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: _isCheckingOut ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Billing & Payment',
          style: FontUtility.heading.copyWith(fontSize: 20),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.withOpacity(0.2), height: 1.0),
        ),
      ),
      body: Stack(
        children: [
          BlocBuilder<CartBloc, CartState>(
            builder: (context, state) {
              if (state.cartItems.isEmpty) {
                return Center(
                  child: Text(
                    'No items to bill.',
                    style: FontUtility.heading.copyWith(color: Colors.grey),
                  ),
                );
              }

              return SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 48,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: _buildProductsColumn(state),
                      ),
                    ),
                    Container(
                      width: 1,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                    Expanded(
                      flex: 52,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                        child: _buildRightPanel(context, state),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_isCheckingOut)
            Container(
              color: Colors.black.withOpacity(0.25),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Completing checkout...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  ButtonStyle _actionButtonStyle() {
    return OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      foregroundColor: const Color(0xFF4A00E0),
      side: const BorderSide(color: Color(0xFF4A00E0), width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: FontUtility.subheading.copyWith(fontSize: 16),
    );
  }

  /// Left column: products hug the top; short carts stay compact, long carts scroll.
  Widget _buildProductsColumn(CartState state) {
    final itemCount = state.cartItems.length;
    final dense = itemCount <= 6;
    final productsTable = BillingItemsTable(
      items: state.cartItems,
      dense: dense,
    );
    final actionRow = Row(
      children: [
        Expanded(
          child: _squareActionCard(
            icon: Icons.percent_rounded,
            label: state.discounts.isEmpty
                ? 'Add Discount'
                : state.discounts.length == 1
                    ? state.discounts.first.title
                    : 'Discounts (${state.discounts.length})',
            active: state.discounts.isNotEmpty,
            onTap: _isCheckingOut
                ? null
                : () => setState(
                      () => _rightPanelMode = RightPanelMode.discount,
                    ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _squareActionCard(
            icon: Icons.receipt_long_rounded,
            label: state.serviceTaxPercentage > 0
                ? 'Tax ${state.serviceTaxPercentage.toStringAsFixed(0)}%'
                : 'Service Tax',
            active: state.serviceTaxPercentage > 0,
            onTap: _isCheckingOut
                ? null
                : () => setState(
                      () => _rightPanelMode = RightPanelMode.tax,
                    ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _squareActionCard(
            icon: Icons.volunteer_activism_rounded,
            label: state.tipsAmount > 0
                ? 'Tips ${PosCurrency.format(state.tipsAmount)}'
                : 'Add Tips',
            active: state.tipsAmount > 0,
            onTap: _isCheckingOut
                ? null
                : () => setState(
                      () => _rightPanelMode = RightPanelMode.tips,
                    ),
          ),
        ),
      ],
    );
    final summary = BillingSummaryCard(
      subTotal: state.subTotal,
      deliveryCharge: state.deliveryCharge,
      discounts: state.discounts,
      discountAmounts: {
        for (final d in state.discounts) d.id: state.amountForDiscount(d),
      },
      offerAppliedAmount: state.offerAppliedAmount,
      offerLabels: state.offerLabels,
      serviceTaxValue: state.serviceTaxValue,
      serviceTaxPercentage: state.serviceTaxPercentage,
      tipsAmount: state.tipsAmount,
      netTotal: state.netTotal,
    );

    if (dense) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          productsTable,
          const SizedBox(height: 14),
          actionRow,
          const Spacer(),
          summary,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                productsTable,
                const SizedBox(height: 14),
                actionRow,
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        summary,
      ],
    );
  }

  Widget _squareActionCard({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool active = false,
  }) {
    final color = active ? const Color(0xFF4A00E0) : Colors.black87;
    return Material(
      color: active
          ? const Color(0xFF4A00E0).withValues(alpha: 0.08)
          : const Color(0xFFF7F8FB),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? const Color(0xFF4A00E0)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FontUtility.subheading.copyWith(
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel(BuildContext context, CartState state) {
    switch (_rightPanelMode) {
      case RightPanelMode.discount:
        return _DiscountPanel(
          state: state,
          onDone: () => setState(() => _rightPanelMode = RightPanelMode.payment),
        );

      case RightPanelMode.tax:
        return Column(
          children: [
            CalculationInputSection(
              title: 'Apply Service Tax',
              placeholder: 'Enter tax percentage (1-100)',
              onApply: (val) {
                context.read<CartBloc>().add(ApplyServiceTax(val));
                setState(() => _rightPanelMode = RightPanelMode.payment);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Service Tax Applied')),
                );
              },
              onCancel: () {
                setState(() => _rightPanelMode = RightPanelMode.payment);
              },
            ),
            if (state.serviceTaxPercentage > 0) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  context.read<CartBloc>().add(RemoveServiceTax());
                  setState(() => _rightPanelMode = RightPanelMode.payment);
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: Text(
                  'Remove Existing Tax',
                  style: FontUtility.subheading.copyWith(color: Colors.red),
                ),
              )
            ]
          ],
        );

      case RightPanelMode.tips:
        return Column(
          children: [
            CalculationInputSection(
              title: 'Add Tips',
              placeholder: 'Enter tip amount',
              isAmount: true,
              onApply: (val) {
                context.read<CartBloc>().add(ApplyTips(val));
                setState(() => _rightPanelMode = RightPanelMode.payment);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tips Applied')),
                );
              },
              onCancel: () {
                setState(() => _rightPanelMode = RightPanelMode.payment);
              },
            ),
            if (state.tipsAmount > 0) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  context.read<CartBloc>().add(RemoveTips());
                  setState(() => _rightPanelMode = RightPanelMode.payment);
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: Text(
                  'Remove Tips',
                  style: FontUtility.subheading.copyWith(color: Colors.red),
                ),
              )
            ]
          ],
        );

      case RightPanelMode.payment:
        final remaining = _remainingDue(state.netTotal);
        final covered = _tenderTotal();
        final typedAmount =
            double.tryParse(_tenderAmountController.text.trim()) ?? 0;
        final change = typedAmount > remaining + 0.0001
            ? typedAmount - remaining
            : 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Remaining',
                      style: FontUtility.body.copyWith(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      PosCurrency.format(remaining),
                      style: FontUtility.heading.copyWith(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: remaining <= 0.0001
                            ? Colors.green.shade700
                            : const Color(0xFF4A00E0),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'To pay  ${PosCurrency.format(state.netTotal)}',
                            style: FontUtility.subheading.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          'Paid  ${PosCurrency.format(covered)}',
                          style: FontUtility.subheading.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (_tenders.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < _tenders.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${_tenders[i].paymentLabel}  ${PosCurrency.format(_tenders[i].amount)}',
                                        style: FontUtility.subheading
                                            .copyWith(fontSize: 13),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: _isCheckingOut
                                          ? null
                                          : () => setState(
                                                () => _tenders.removeAt(i),
                                              ),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 88,
                      child: _walletsLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _wallets.isEmpty
                              ? Center(
                                  child: Text(
                                    _walletsError ??
                                        'No payment methods configured.',
                                    style:
                                        FontUtility.body.copyWith(fontSize: 12),
                                  ),
                                )
                              : ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _wallets.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    final wallet = _wallets[index];
                                    final label = wallet.label.trim().isEmpty
                                        ? wallet.paymentMode
                                        : wallet.label.trim();
                                    final selected =
                                        _selectedWallet?.localId ==
                                            wallet.localId;
                                    return _WalletPayButton(
                                      label: label,
                                      icon: _iconForPaymentMode(
                                        wallet.paymentMode,
                                      ),
                                      selected: selected,
                                      onTap: _isCheckingOut ||
                                              remaining <= 0.0001
                                          ? null
                                          : () {
                                              setState(() {
                                                _selectedWallet = wallet;
                                                if (_tenderAmountController
                                                    .text
                                                    .trim()
                                                    .isEmpty) {
                                                  _tenderAmountController
                                                          .text =
                                                      remaining
                                                          .toStringAsFixed(2);
                                                }
                                              });
                                            },
                                    );
                                  },
                                ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final denom in _denominations)
                          _DenomButton(
                            label: PosCurrency.format(denom, decimals: 0),
                            onPressed: _isCheckingOut || remaining <= 0.0001
                                ? null
                                : () {
                                    setState(() {
                                      _tenderAmountController.text =
                                          denom.toStringAsFixed(2);
                                    });
                                  },
                          ),
                        _DenomButton(
                          label: 'Exact',
                          onPressed: _isCheckingOut || remaining <= 0.0001
                              ? null
                              : () {
                                  setState(() {
                                    _tenderAmountController.text =
                                        remaining.toStringAsFixed(2);
                                  });
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tenderAmountController,
                            enabled:
                                !_isCheckingOut && remaining > 0.0001,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: FontUtility.heading.copyWith(fontSize: 22),
                            decoration: InputDecoration(
                              prefixText: '${PosCurrency.symbol()} ',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: Material(
                            color: (_isCheckingOut ||
                                    remaining <= 0.0001 ||
                                    _selectedWallet == null ||
                                    typedAmount <= 0)
                                ? Colors.grey.shade300
                                : const Color(0xFF4A00E0),
                            borderRadius: BorderRadius.circular(14),
                            elevation: (_isCheckingOut ||
                                    remaining <= 0.0001 ||
                                    _selectedWallet == null ||
                                    typedAmount <= 0)
                                ? 0
                                : 3,
                            shadowColor: Colors.black.withValues(alpha: 0.25),
                            child: InkWell(
                              onTap: _isCheckingOut ||
                                      remaining <= 0.0001 ||
                                      _selectedWallet == null ||
                                      typedAmount <= 0
                                  ? null
                                  : () => _addInlineTender(
                                        context,
                                        state,
                                        remaining,
                                      ),
                              borderRadius: BorderRadius.circular(14),
                              child: Icon(
                                Icons.add_rounded,
                                size: 30,
                                color: (_isCheckingOut ||
                                        remaining <= 0.0001 ||
                                        _selectedWallet == null ||
                                        typedAmount <= 0)
                                    ? Colors.grey.shade600
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (change > 0.0001) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Change',
                              style: FontUtility.subheading.copyWith(
                                color: Colors.green.shade800,
                              ),
                            ),
                            Text(
                              PosCurrency.format(change),
                              style: FontUtility.heading.copyWith(
                                fontSize: 22,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: _isCheckingOut
                    ? null
                    : () => _completeCheckout(
                          context,
                          state,
                          allowBalanceDue: remaining > 0.0001,
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A00E0),
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  remaining <= 0.0001 ? 'COMPLETE' : 'PLACE WITH BALANCE',
                  style: FontUtility.heading.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
            if (_tenders.isEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isCheckingOut
                    ? null
                    : () => _completeCheckout(
                          context,
                          state,
                          allowBalanceDue: true,
                        ),
                child: const Text('Place full amount on credit'),
              ),
              TextButton(
                onPressed: _isCheckingOut
                    ? null
                    : () => _saveDraft(context, state),
                child: const Text('Save as Draft'),
              ),
            ],
          ],
        );
    }
  }

  Future<void> _addInlineTender(
    BuildContext context,
    CartState state,
    double remaining,
  ) async {
    final wallet = _selectedWallet;
    if (wallet == null) return;
    var amount = double.tryParse(_tenderAmountController.text.trim()) ?? 0;
    if (amount <= 0) return;
    // Cash may exceed remaining (change); other modes are capped to remaining.
    final isCash = wallet.paymentMode == StoreOrderPaymentMode.cash;
    if (!isCash && amount - remaining > 0.0001) {
      amount = remaining;
    }
    final applied = isCash
        ? (amount > remaining ? remaining : amount)
        : amount;
    if (applied <= 0.0001) return;

    final paymentMethod = wallet.paymentMode;
    final paymentLabel =
        wallet.label.trim().isEmpty ? wallet.paymentMode : wallet.label.trim();
    if (paymentMethod == StoreOrderPaymentMode.credit) {
      await _addPaymentFromWallet(context, state, wallet);
      return;
    }

    setState(() {
      _tenders.add(
        _TenderLine(
          paymentMethod: paymentMethod,
          paymentLabel: paymentLabel,
          amount: double.parse(applied.toStringAsFixed(2)),
        ),
      );
      final nextRemaining = _remainingDue(state.netTotal);
      _tenderAmountController.text =
          nextRemaining > 0.0001 ? nextRemaining.toStringAsFixed(2) : '';
    });
  }
}

class _DiscountPanel extends StatefulWidget {
  final CartState state;
  final VoidCallback onDone;

  const _DiscountPanel({required this.state, required this.onDone});

  @override
  State<_DiscountPanel> createState() => _DiscountPanelState();
}

class _DiscountPanelState extends State<_DiscountPanel> {
  final _titleController = TextEditingController(text: 'Discount');
  final _percentController = TextEditingController();
  String? _selectedItemSignature;
  bool _userEditedTitle = false;

  @override
  void dispose() {
    _titleController.dispose();
    _percentController.dispose();
    super.dispose();
  }

  void _onItemChanged(String? signature) {
    setState(() {
      _selectedItemSignature = signature;
      if (!_userEditedTitle) {
        if (signature == null) {
          _titleController.text = 'Discount';
        } else {
          final item = widget.state.cartItems.firstWhere(
            (c) => c.lineSignature == signature,
          );
          _titleController.text = '${item.product.name} -discount';
        }
      }
    });
  }

  void _apply() {
    final pct = double.tryParse(_percentController.text.trim());
    if (pct == null || pct <= 0 || pct > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a discount percentage between 1 and 100')),
      );
      return;
    }
    String? itemName;
    if (_selectedItemSignature != null) {
      for (final item in widget.state.cartItems) {
        if (item.lineSignature == _selectedItemSignature) {
          itemName = item.product.name;
          break;
        }
      }
    }
    final title = _titleController.text.trim().isEmpty
        ? (itemName == null ? 'Discount' : '$itemName -discount')
        : _titleController.text.trim();
    context.read<CartBloc>().add(
          ApplyDiscount(
            pct,
            title: title,
            targetLineSignature: _selectedItemSignature,
            targetItemName: itemName,
          ),
        );
    _percentController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "$title"')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Add Discount',
                  style: FontUtility.heading.copyWith(fontSize: 18),
                ),
              ),
              IconButton(
                onPressed: widget.onDone,
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Apply to',
            style: FontUtility.body.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _selectedItemSignature,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Entire order'),
              ),
              for (final item in state.cartItems)
                DropdownMenuItem<String?>(
                  value: item.lineSignature,
                  child: Text(
                    '${item.product.name} · ${PosCurrency.format(item.totalPrice)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _onItemChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            onChanged: (_) => _userEditedTitle = true,
            decoration: InputDecoration(
              labelText: 'Title',
              hintText: 'Discount',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _percentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Percentage',
              hintText: '1-100',
              suffixText: '%',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _apply,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A00E0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('ADD DISCOUNT'),
          ),
          if (state.discounts.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Applied discounts',
              style: FontUtility.subheading.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 8),
            for (final discount in state.discounts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(discount.title),
                subtitle: Text(
                  '${discount.percentage.toStringAsFixed(0)}% · '
                  '-${PosCurrency.format(state.amountForDiscount(discount))}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    context
                        .read<CartBloc>()
                        .add(RemoveDiscount(discountId: discount.id));
                  },
                ),
              ),
            TextButton(
              onPressed: () {
                context.read<CartBloc>().add(const RemoveDiscount());
              },
              child: Text(
                'Remove all discounts',
                style: FontUtility.subheading.copyWith(color: Colors.red),
              ),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: widget.onDone,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _WalletPayButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _WalletPayButton({
    required this.label,
    required this.icon,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF4A00E0) : Colors.white,
      elevation: selected ? 6 : 3,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 128,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFF4A00E0)
                  : Colors.grey.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: selected ? Colors.white : const Color(0xFF4A00E0),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FontUtility.subheading.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DenomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _DenomButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F0FF),
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            label,
            style: FontUtility.subheading.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4A00E0),
            ),
          ),
        ),
      ),
    );
  }
}
