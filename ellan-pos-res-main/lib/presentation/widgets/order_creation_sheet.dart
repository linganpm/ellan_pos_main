import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/order_types_repository.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/l10n/app_localizations.dart';
import '../../core/utils/font_utility.dart';
import '../../bloc/order_creation/order_creation_bloc.dart';
import '../../bloc/order_creation/order_creation_event.dart';
import '../../bloc/order_creation/order_creation_state.dart';
import '../screens/order_create_screen.dart';

const _kAccent = Color(0xFF4A00E0);
const _kDefaultCustomerName = 'Guest';
const _kLastOrderTypeKey = 'posLastSelectedOrderType';

Future<void> showOrderCreationBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return BlocProvider(
        create: (_) => OrderCreationBloc(),
        child: const OrderCreationBottomSheet(),
      );
    },
  );
}

class OrderCreationBottomSheet extends StatefulWidget {
  const OrderCreationBottomSheet();

  @override
  State<OrderCreationBottomSheet> createState() =>
      _OrderCreationBottomSheetState();
}

class _OrderCreationBottomSheetState extends State<OrderCreationBottomSheet> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  List<CustomerHit> _searchHits = const [];
  bool _searching = false;
  bool _creatingCustomer = false;
  bool _saving = false;
  String? _formError;
  String? _searchError;
  List<PosOrderType> _orderTypes = OrderTypesRepository.defaults;
  PosOrderType? _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = _orderTypes.first;
    _restoreLastOrderType();
  }

  Future<void> _restoreLastOrderType() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_kLastOrderTypeKey)?.trim().toUpperCase();
    List<PosOrderType> types = OrderTypesRepository.defaults;
    try {
      final loaded = await getIt<UiStoreController>().loadOrderTypes();
      if (loaded.isNotEmpty) types = loaded;
    } catch (_) {}
    if (!mounted) return;

    PosOrderType selected = types.first;
    if (savedKey != null && savedKey.isNotEmpty) {
      for (final type in types) {
        if (type.key.toUpperCase() == savedKey) {
          selected = type;
          break;
        }
      }
    }

    setState(() {
      _orderTypes = types;
      _selectedType = selected;
    });
    context.read<OrderCreationBloc>().add(
      SelectOrderType(selected.isDineIn ? OrderType.dineIn : OrderType.pickup),
    );
  }

  void _selectType(PosOrderType type) {
    setState(() => _selectedType = type);
    context.read<OrderCreationBloc>().add(
      SelectOrderType(type.isDineIn ? OrderType.dineIn : OrderType.pickup),
    );
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kLastOrderTypeKey, type.key);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: FontUtility.body.copyWith(
        color: Colors.black38,
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF7F8FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD), width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD), width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kAccent, width: 2.5),
      ),
    );
  }

  IconData _iconForType(PosOrderType type) {
    final key = type.key.toUpperCase();
    if (key.contains('DINE')) return Icons.table_restaurant_rounded;
    if (key.contains('DELIV')) return Icons.delivery_dining_rounded;
    if (key.contains('PICK')) return Icons.takeout_dining_rounded;
    return Icons.receipt_long_rounded;
  }

  String _resolvedCustomerName(OrderCreationState state) {
    final name = state.pickupName.trim();
    if (name.isNotEmpty) return name;
    return _kDefaultCustomerName;
  }

  Future<void> _runCustomerSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchHits = const [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final controller = getIt<UiStoreController>();
      final rows = await controller.searchCustomers(trimmed);
      if (!mounted) return;
      setState(() {
        _searchHits = rows
            .map(
              (row) => CustomerHit(
                uniqueId: row.customerId,
                name: row.name,
                phone: row.phone,
                email: row.email,
                role: row.role,
              ),
            )
            .toList(growable: false);
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = error.toString();
        _searchHits = const [];
      });
    }
  }

  void _openCreateMode() {
    setState(() {
      _creatingCustomer = true;
      _formError = null;
      _searchHits = const [];
      _searchError = null;
    });
    final seed = _searchController.text.trim();
    if (seed.isNotEmpty && RegExp(r'^\d+$').hasMatch(seed)) {
      _phoneController.text = seed;
    } else if (seed.contains('@')) {
      _emailController.text = seed;
    } else if (seed.isNotEmpty) {
      _nameController.text = seed;
    }
  }

  void _closeCreateMode() {
    setState(() {
      _creatingCustomer = false;
      _formError = null;
      _nameController.clear();
      _phoneController.clear();
      _emailController.clear();
    });
  }

  void _selectCustomer(CustomerHit hit) {
    context.read<OrderCreationBloc>().add(
      SelectPickupCustomer(
        customerUniqueId: hit.uniqueId,
        name: hit.name.isEmpty ? _kDefaultCustomerName : hit.name,
        phone: hit.phone,
        email: hit.email ?? '',
      ),
    );
    _searchController.clear();
    setState(() {
      _searchHits = const [];
      _creatingCustomer = false;
      _formError = null;
    });
  }

  /// Creates a customer when the inline form is open; otherwise uses selection.
  Future<bool> _ensureCustomerReady(OrderCreationState state) async {
    if (!_creatingCustomer) return true;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      setState(() => _formError = context.l10n.customerEnterValidPhone);
      return false;
    }

    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final controller = getIt<UiStoreController>();
      final customer = await controller.createDirectoryCustomer(
        name: name.isEmpty ? _kDefaultCustomerName : name,
        phone: phone,
        email: email.isEmpty ? null : email,
      );
      if (!mounted) return false;
      if (customer == null) {
        setState(() {
          _saving = false;
          _formError = context.l10n.customerCouldNotSave;
        });
        return false;
      }
      context.read<OrderCreationBloc>().add(
        SelectPickupCustomer(
          customerUniqueId: customer.customerId,
          name: customer.name.isEmpty ? _kDefaultCustomerName : customer.name,
          phone: customer.phone,
          email: customer.email,
        ),
      );
      setState(() {
        _saving = false;
        _creatingCustomer = false;
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _saving = false;
        _formError = error.toString();
      });
      return false;
    }
  }

  Future<void> _continueWithCustomer(OrderCreationState state) async {
    final ready = await _ensureCustomerReady(state);
    if (!ready || !mounted) return;
    final latest = context.read<OrderCreationBloc>().state;
    final navigator = Navigator.of(context, rootNavigator: true);
    final args = OrderCreateScreenArgs(
      orderType: _selectedType?.label.isNotEmpty == true
          ? _selectedType!.label
          : 'Pickup',
      orderTypeKey: _selectedType?.key,
      name: _resolvedCustomerName(latest),
      phone: latest.pickupPhone,
      email: latest.pickupEmail,
      customerUniqueId: latest.customerUniqueId,
    );
    navigator.pop();
    await navigator.push(
      MaterialPageRoute(builder: (_) => OrderCreateScreen(args: args)),
    );
  }

  Future<void> _openDineInOrder(
    OrderCreationState state,
    String tableNumber,
  ) async {
    final ready = await _ensureCustomerReady(state);
    if (!ready || !mounted) return;
    final latest = context.read<OrderCreationBloc>().state;
    final navigator = Navigator.of(context, rootNavigator: true);
    final l10n = AppLocalizations.of(context)!;
    final args = OrderCreateScreenArgs(
      orderType: _selectedType?.label.isNotEmpty == true
          ? _selectedType!.label
          : 'DineIn',
      orderTypeKey: _selectedType?.key,
      name: _resolvedCustomerName(latest),
      phone: latest.pickupPhone,
      email: latest.pickupEmail,
      customerUniqueId: latest.customerUniqueId,
      floor: latest.selectedFloor == 'first'
          ? l10n.dineInFloorFirst
          : l10n.dineInFloorSecond,
      table: l10n.dineInTable(tableNumber),
    );
    navigator.pop();
    await navigator.push(
      MaterialPageRoute(builder: (_) => OrderCreateScreen(args: args)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 600;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Center(
        child: Container(
          width: isTablet ? 720 : screenWidth,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          margin: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.06,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.commonNewOrder,
                        style: FontUtility.heading.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: BlocBuilder<OrderCreationBloc, OrderCreationState>(
                    builder: (context, state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildOrderTypeCards(),
                          const SizedBox(height: 20),
                          _buildCustomerSection(context, state),
                          const SizedBox(height: 20),
                          if (_selectedType?.isDineIn == true)
                            _buildDineInFlow(context, state)
                          else
                            _buildPickupActions(context, state),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTypeCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = _orderTypes.length.clamp(1, 4);
        final gap = 10.0;
        final width = (constraints.maxWidth - gap * (count - 1)) / count;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final type in _orderTypes)
              SizedBox(
                width: width,
                child: _OrderTypeCard(
                  label: type.label,
                  icon: _iconForType(type),
                  selected: _selectedType?.key == type.key,
                  onTap: () => _selectType(type),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCustomerSection(BuildContext context, OrderCreationState state) {
    if (state.hasSelectedCustomer && !_creatingCustomer) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _kAccent.withValues(alpha: 0.28),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _kAccent.withValues(alpha: 0.12),
              child: const Icon(Icons.person_rounded, color: _kAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _resolvedCustomerName(state),
                    style: FontUtility.subheading.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  if (state.pickupPhone.isNotEmpty ||
                      state.pickupEmail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (state.pickupPhone.isNotEmpty) state.pickupPhone,
                        if (state.pickupEmail.isNotEmpty) state.pickupEmail,
                      ].join(' · '),
                      style: FontUtility.body.copyWith(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: context.l10n.actionChange,
              onPressed: () {
                context.read<OrderCreationBloc>().add(ClearPickupCustomer());
              },
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_creatingCustomer) ...[
          TextField(
            controller: _searchController,
            onChanged: (value) {
              Future<void>.delayed(const Duration(milliseconds: 250), () {
                if (!mounted) return;
                if (_searchController.text.trim() == value.trim()) {
                  _runCustomerSearch(value);
                }
              });
              setState(() {});
            },
            style: FontUtility.body.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            decoration: _fieldDecoration(
              hint: context.l10n.customerSearchHintFull,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchHits = []);
                      },
                    ),
                  IconButton(
                    tooltip: context.l10n.customersNew,
                    onPressed: _openCreateMode,
                    icon: const Icon(Icons.add_rounded, color: _kAccent),
                  ),
                ],
              ),
            ),
          ),
          if (_searchError != null) ...[
            const SizedBox(height: 8),
            Text(
              _searchError!,
              style: FontUtility.body.copyWith(color: Colors.red, fontSize: 12),
            ),
          ],
          if (_searchHits.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD0D5DD)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchHits.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final hit = _searchHits[index];
                  final displayName = hit.name.isEmpty
                      ? _kDefaultCustomerName
                      : hit.name;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: _kAccent.withValues(alpha: 0.12),
                      child: Text(
                        displayName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: _kAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      displayName,
                      style: FontUtility.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (hit.phone.trim().isNotEmpty) hit.phone,
                        if ((hit.email ?? '').trim().isNotEmpty)
                          hit.email!.trim(),
                      ].join(' · '),
                    ),
                    onTap: () => _selectCustomer(hit),
                  );
                },
              ),
            ),
          ],
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.customersNew,
                  style: FontUtility.subheading.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              TextButton(
                onPressed: _saving ? null : _closeCreateMode,
                child: Text(context.l10n.customersBackToSearch),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: FontUtility.body.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            decoration: _fieldDecoration(
              hint: context.l10n.customerNameOptional,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: FontUtility.body.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            decoration: _fieldDecoration(hint: context.l10n.commonPhone),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: FontUtility.body.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            decoration: _fieldDecoration(
              hint: context.l10n.customerEmailOptional,
            ),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 8),
            Text(
              _formError!,
              style: FontUtility.body.copyWith(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildPickupActions(BuildContext context, OrderCreationState state) {
    return Row(
      children: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(
            AppLocalizations.of(context)!.pickupCancelButton,
            style: FontUtility.button.copyWith(color: Colors.black54),
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _saving ? null : () => _continueWithCustomer(state),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _creatingCustomer
                        ? context.l10n.customerSaveContinue
                        : AppLocalizations.of(context)!.pickupAddButton,
                    style: FontUtility.button.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDineInFlow(BuildContext context, OrderCreationState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_formError != null && _creatingCustomer) ...[
          Text(
            _formError!,
            style: FontUtility.body.copyWith(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD0D5DD)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildFloorButton(
                  context,
                  title: AppLocalizations.of(context)!.dineInFloorFirst,
                  isSelected: state.selectedFloor == 'first',
                  onTap: () {
                    context.read<OrderCreationBloc>().add(
                      const SelectDineInFloor('first'),
                    );
                  },
                ),
              ),
              Expanded(
                child: _buildFloorButton(
                  context,
                  title: AppLocalizations.of(context)!.dineInFloorSecond,
                  isSelected: state.selectedFloor == 'second',
                  onTap: () {
                    context.read<OrderCreationBloc>().add(
                      const SelectDineInFloor('second'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: 10,
          itemBuilder: (context, index) {
            final tableNumber = '${index + 1}';
            final isSelected = state.selectedTable == tableNumber;

            return GestureDetector(
              onTap: _saving
                  ? null
                  : () => _openDineInOrder(state, tableNumber),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? _kAccent : const Color(0xFFF7F8FB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? _kAccent : const Color(0xFFD0D5DD),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.table_restaurant_rounded,
                        color: isSelected ? Colors.white : _kAccent,
                        size: 26,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tableNumber,
                        style: FontUtility.subheading.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFloorButton(
    BuildContext context, {
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? _kAccent.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            title,
            style: FontUtility.body.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected ? _kAccent : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderTypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _OrderTypeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _kAccent : const Color(0xFFF7F8FB),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 96,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              width: 2,
              color: selected ? _kAccent : const Color(0xFFD0D5DD),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: selected ? Colors.white : _kAccent),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FontUtility.body.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
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

class CustomerHit {
  final String uniqueId;
  final String name;
  final String phone;
  final String? email;
  final String? role;

  const CustomerHit({
    required this.uniqueId,
    required this.name,
    required this.phone,
    this.email,
    this.role,
  });
}
