import 'package:flutter/material.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/utils/customer_identity.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/presentation/screens/credit_account_detail_screen.dart';
import 'package:pos_tablet/presentation/screens/credits_screen.dart';
import 'package:pos_tablet/presentation/screens/order_details_screen.dart';
import 'package:pos_tablet/presentation/screens/order_list_screen.dart';
import 'package:pos_tablet/presentation/screens/order_payments_screen.dart';

/// Directory customer profile: identity, credit balance, and history shortcuts.
class CustomerProfileScreen extends StatefulWidget {
  final StoreCustomer customer;

  const CustomerProfileScreen({super.key, required this.customer});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  static const Color _primary = Color(0xFF4A00E0);

  bool _loading = true;
  String? _error;

  double _outstanding = 0;
  double _creditTotal = 0;
  double _repaid = 0;
  int _orderCount = 0;
  int _paymentCount = 0;

  List<StoreOrderSummary> _recentOrders = const [];
  List<StoreCreditRecord> _recentCredits = const [];
  List<StoreCreditRepaymentRecord> _recentPayments = const [];
  int _creditCount = 0;

  StoreCustomer get _customer => widget.customer;

  String get _displayName {
    final name = _customer.name.trim();
    return name.isEmpty ? 'Customer' : name;
  }

  String get _roleLabel {
    switch (_customer.role) {
      case 'business_customer':
        return 'Business';
      case 'retail_customer':
        return 'Retail';
      default:
        return _customer.role.isEmpty ? 'Customer' : _customer.role;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _normalizeCustomerId(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('user_')) return raw;
    if (int.tryParse(raw) != null) return 'user_$raw';
    return raw;
  }

  bool _orderMatches(StoreOrderSummary order) {
    final wanted = _normalizeCustomerId(_customer.customerId);
    final orderId = _normalizeCustomerId(order.customerUniqueId ?? '');
    if (wanted.isNotEmpty && orderId.isNotEmpty && wanted == orderId) {
      return true;
    }
    final phone = _customer.phone.trim();
    if (phone.isNotEmpty && order.mobile.trim() == phone) return true;
    final email = _customer.email.trim().toLowerCase();
    if (email.isNotEmpty &&
        order.customerEmail.trim().toLowerCase() == email) {
      return true;
    }
    return false;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = getIt<UiStoreController>();
      final customerId = _customer.customerId;

      final results = await Future.wait([
        controller.loadOrders(),
        controller.loadCreditRecords(customerId: customerId),
        controller.loadCreditRepayments(customerId: customerId),
      ]);

      final allOrders = results[0] as List<StoreOrderSummary>;
      final credits = results[1] as List<StoreCreditRecord>;
      final repayments = results[2] as List<StoreCreditRepaymentRecord>;

      final orders = allOrders.where(_orderMatches).toList(growable: false)
        ..sort((a, b) {
          final aAt = DateTime.tryParse(a.createdOn ?? '') ?? DateTime(1970);
          final bAt = DateTime.tryParse(b.createdOn ?? '') ?? DateTime(1970);
          return bAt.compareTo(aAt);
        });

      final sortedCredits = List<StoreCreditRecord>.from(credits)
        ..sort((a, b) {
          final aAt = DateTime.tryParse(a.createdOn) ?? DateTime(1970);
          final bAt = DateTime.tryParse(b.createdOn) ?? DateTime(1970);
          return bAt.compareTo(aAt);
        });

      final sortedPayments = List<StoreCreditRepaymentRecord>.from(repayments)
        ..sort((a, b) {
          final aAt = DateTime.tryParse(a.createdOn) ?? DateTime(1970);
          final bAt = DateTime.tryParse(b.createdOn) ?? DateTime(1970);
          return bAt.compareTo(aAt);
        });

      if (!mounted) return;
      setState(() {
        _recentOrders = orders.take(5).toList(growable: false);
        _recentCredits = sortedCredits.take(5).toList(growable: false);
        _recentPayments = sortedPayments.take(5).toList(growable: false);
        _orderCount = orders.length;
        _creditCount = sortedCredits.length;
        _paymentCount = sortedPayments.length;
        _creditTotal =
            sortedCredits.fold<double>(0, (sum, row) => sum + row.amount);
        _repaid =
            sortedCredits.fold<double>(0, (sum, row) => sum + row.paidAmount);
        _outstanding = sortedCredits.fold<double>(
          0,
          (sum, row) => sum + row.outstandingAmount,
        );
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

  Future<void> _openOrders() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderListScreen(
          customerId: _customer.customerId,
          customerName: _displayName,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openCreditAccount() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreditAccountDetailScreen(
          customerId: _customer.customerId,
          customerName: _displayName,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openCreditList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreditsScreen(
          customerId: _customer.customerId,
          customerName: _displayName,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openOrder(StoreOrderSummary order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(orderId: order.orderId),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openOrderPayments(StoreOrderSummary order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderPaymentsScreen(
          orderId: order.orderId,
          orderLabel: order.customerName.isEmpty
              ? 'Order #${order.orderId}'
              : order.customerName,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Customer profile',
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
          ),
        ],
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
                          textAlign: TextAlign.center,
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
                        _buildHeaderCard(),
                        const SizedBox(height: 16),
                        _buildBalanceCard(),
                        const SizedBox(height: 16),
                        _buildQuickLinks(),
                        const SizedBox(height: 24),
                        _sectionTitle(
                          'Order history',
                          count: _orderCount,
                          onViewAll: _openOrders,
                        ),
                        const SizedBox(height: 10),
                        _buildOrdersSection(),
                        const SizedBox(height: 24),
                        _sectionTitle(
                          'Credit history',
                          count: _creditCount,
                          onViewAll: _openCreditList,
                        ),
                        const SizedBox(height: 10),
                        _buildCreditsSection(),
                        const SizedBox(height: 24),
                        _sectionTitle(
                          'Payments',
                          count: _paymentCount,
                          onViewAll: _openCreditAccount,
                        ),
                        const SizedBox(height: 10),
                        _buildPaymentsSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final initial =
        _displayName.isNotEmpty ? _displayName.substring(0, 1).toUpperCase() : '?';
    final contact = [
      if (_customer.phone.trim().isNotEmpty) _customer.phone.trim(),
      if (_customer.email.trim().isNotEmpty) _customer.email.trim(),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  style: FontUtility.heading.copyWith(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 6),
                if (contact.isNotEmpty)
                  Text(
                    contact,
                    style: FontUtility.body.copyWith(color: Colors.white70),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(_roleLabel),
                    if (_customer.usrRegNum.trim().isNotEmpty)
                      _chip(_customer.usrRegNum.trim())
                    else if (_customer.customerId.isNotEmpty)
                      _chip(
                        displayCustomerIdentity(customerId: _customer.customerId),
                      ),
                    if (_customer.status.isNotEmpty) _chip(_customer.status),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: FontUtility.body.copyWith(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Credit account',
            style: FontUtility.subheading.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  'Balance due',
                  _outstanding,
                  emphasize: true,
                ),
              ),
              Expanded(child: _metricTile('Credit so far', _creditTotal)),
              Expanded(child: _metricTile('Repaid', _repaid)),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _openCreditAccount,
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: const Text('Open credit account'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, double amount, {bool emphasize = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FontUtility.body.copyWith(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: FontUtility.subheading.copyWith(
            fontSize: 18,
            color: emphasize && amount > 0.0001
                ? Colors.red.shade700
                : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickLinks() {
    return Row(
      children: [
        Expanded(
          child: _linkButton(
            icon: Icons.receipt_long_rounded,
            label: 'Orders',
            onTap: _openOrders,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _linkButton(
            icon: Icons.credit_score_rounded,
            label: 'Credits',
            onTap: _openCreditList,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _linkButton(
            icon: Icons.payments_rounded,
            label: 'Payments',
            onTap: _openCreditAccount,
          ),
        ),
      ],
    );
  }

  Widget _linkButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: _primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: FontUtility.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(
    String title, {
    required int count,
    required VoidCallback onViewAll,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: FontUtility.subheading.copyWith(fontSize: 17),
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          child: Text(count > 0 ? 'View all ($count)' : 'View all'),
        ),
      ],
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Text(
        message,
        style: FontUtility.body.copyWith(color: Colors.black54),
      ),
    );
  }

  Widget _buildOrdersSection() {
    if (_recentOrders.isEmpty) {
      return _emptyBox('No orders for this customer yet.');
    }
    return Column(
      children: [
        for (final order in _recentOrders) ...[
          _historyTile(
            title: 'Order #${order.orderId}',
            subtitle:
                '${order.orderType.isEmpty ? 'Order' : order.orderType} · ${order.paymentStatus}',
            trailing: '\$${(order.finalValue != 0 ? order.finalValue : order.total).toStringAsFixed(2)}',
            onTap: () => _openOrder(order),
            actionLabel: 'Pay',
            onAction: () => _openOrderPayments(order),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildCreditsSection() {
    if (_recentCredits.isEmpty) {
      return _emptyBox('No credit sales for this customer yet.');
    }
    return Column(
      children: [
        for (final credit in _recentCredits) ...[
          _historyTile(
            title: 'Credit #${credit.id}',
            subtitle:
                'Outstanding \$${credit.outstandingAmount.toStringAsFixed(2)}',
            trailing: '\$${credit.amount.toStringAsFixed(2)}',
            onTap: _openCreditAccount,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildPaymentsSection() {
    if (_recentPayments.isEmpty) {
      return _emptyBox('No credit payments recorded yet.');
    }
    return Column(
      children: [
        for (final payment in _recentPayments) ...[
          _historyTile(
            title: payment.paymentMode.isEmpty
                ? 'Payment #${payment.id}'
                : payment.paymentMode,
            subtitle: payment.createdOn,
            trailing: '\$${payment.totalAmount.toStringAsFixed(2)}',
            onTap: _openCreditAccount,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _historyTile({
    required String title,
    required String subtitle,
    required String trailing,
    required VoidCallback onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FontUtility.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: FontUtility.body.copyWith(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                trailing,
                style: FontUtility.body.copyWith(fontWeight: FontWeight.w700),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ] else
                const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
