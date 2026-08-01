import 'package:flutter/material.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';

const _kAccent = Color(0xFF4A00E0);
const _kDefaultCustomerName = 'Guest';

class CustomerSelectResult {
  final String customerUniqueId;
  final String name;
  final String phone;
  final String email;

  const CustomerSelectResult({
    required this.customerUniqueId,
    required this.name,
    required this.phone,
    required this.email,
  });
}

/// Search / select / create a directory customer (same form as order start).
Future<CustomerSelectResult?> showCustomerSelectSheet(
  BuildContext context, {
  String? title,
  String? subtitle,
  String? confirmLabel,
  bool isDismissible = true,
  List<String>? roles,
  String customerGroup = 'retail_customer',
}) {
  final resolvedTitle = title ?? context.l10n.commonSelectCustomer;
  final resolvedConfirm = confirmLabel ?? context.l10n.actionContinue;
  return showModalBottomSheet<CustomerSelectResult>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: Colors.transparent,
    builder: (_) => CustomerSelectSheet(
      title: resolvedTitle,
      subtitle: subtitle,
      confirmLabel: resolvedConfirm,
      roles: roles,
      customerGroup: customerGroup,
    ),
  );
}

class CustomerSelectSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String confirmLabel;
  final List<String>? roles;
  final String customerGroup;

  const CustomerSelectSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.confirmLabel,
    this.roles,
    this.customerGroup = 'retail_customer',
  });

  @override
  State<CustomerSelectSheet> createState() => _CustomerSelectSheetState();
}

class _CustomerSelectSheetState extends State<CustomerSelectSheet> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  List<_CustomerHit> _searchHits = const [];
  CustomerSelectResult? _selected;
  bool _searching = false;
  bool _creatingCustomer = false;
  bool _saving = false;
  String? _formError;
  String? _searchError;

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
      filled: true,
      fillColor: const Color(0xFFF7F8FB),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kAccent, width: 1.5),
      ),
    );
  }

  Future<void> _runCustomerSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchHits = const [];
        _searchError = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final rows = await getIt<UiStoreController>().searchCustomers(
        trimmed,
        roles: widget.roles,
      );
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchHits = rows
            .map(
              (row) => _CustomerHit(
                uniqueId: row.customerId,
                name: row.name,
                phone: row.phone,
                email: row.email,
              ),
            )
            .where((hit) => hit.uniqueId.trim().isNotEmpty)
            .toList(growable: false);
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
      _selected = null;
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

  void _selectCustomer(_CustomerHit hit) {
    setState(() {
      _selected = CustomerSelectResult(
        customerUniqueId: hit.uniqueId,
        name: hit.name.isEmpty
            ? (hit.phone.isEmpty ? _kDefaultCustomerName : hit.phone)
            : hit.name,
        phone: hit.phone,
        email: hit.email ?? '',
      );
      _searchController.clear();
      _searchHits = const [];
      _creatingCustomer = false;
      _formError = null;
    });
  }

  Future<void> _confirm() async {
    if (_creatingCustomer) {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
        setState(() => _formError = context.l10n.customerEnterValidPhone);
        return;
      }
      setState(() {
        _saving = true;
        _formError = null;
      });
      try {
        final customer = await getIt<UiStoreController>()
            .createDirectoryCustomer(
              name: name.isEmpty ? phone : name,
              phone: phone,
              email: email.isEmpty ? null : email,
              customerGroup: widget.customerGroup,
            );
        if (!mounted) return;
        if (customer == null || customer.customerId.trim().isEmpty) {
          setState(() {
            _saving = false;
            _formError = context.l10n.customerCouldNotSave;
          });
          return;
        }
        Navigator.of(context).pop(
          CustomerSelectResult(
            customerUniqueId: customer.customerId,
            name: customer.name.isEmpty
                ? (customer.phone.isEmpty
                      ? _kDefaultCustomerName
                      : customer.phone)
                : customer.name,
            phone: customer.phone,
            email: customer.email,
          ),
        );
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _formError = error.toString();
        });
      }
      return;
    }

    final selected = _selected;
    if (selected == null) {
      setState(() => _formError = context.l10n.customerSelectOrAdd);
      return;
    }
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Center(
        child: Container(
          width: isTablet ? 720 : screenWidth,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          margin: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.08,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: FontUtility.heading.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (widget.subtitle != null &&
                              widget.subtitle!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
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
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selected != null && !_creatingCustomer)
                        Container(
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
                                backgroundColor: _kAccent.withValues(
                                  alpha: 0.12,
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: _kAccent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selected!.name,
                                      style: FontUtility.subheading.copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (_selected!.phone.isNotEmpty ||
                                        _selected!.email.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          if (_selected!.phone.isNotEmpty)
                                            _selected!.phone,
                                          if (_selected!.email.isNotEmpty)
                                            _selected!.email,
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
                                onPressed: () =>
                                    setState(() => _selected = null),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        )
                      else if (!_creatingCustomer) ...[
                        TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            Future<void>.delayed(
                              const Duration(milliseconds: 250),
                              () {
                                if (!mounted) return;
                                if (_searchController.text.trim() ==
                                    value.trim()) {
                                  _runCustomerSearch(value);
                                }
                              },
                            );
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
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
                                  icon: const Icon(
                                    Icons.add_rounded,
                                    color: _kAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_searchError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _searchError!,
                            style: FontUtility.body.copyWith(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (_searchHits.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 220),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFD0D5DD),
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _searchHits.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: Colors.grey.shade200,
                              ),
                              itemBuilder: (context, index) {
                                final hit = _searchHits[index];
                                final displayName = hit.name.isEmpty
                                    ? (hit.phone.isEmpty
                                          ? _kDefaultCustomerName
                                          : hit.phone)
                                    : hit.name;
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundColor: _kAccent.withValues(
                                      alpha: 0.12,
                                    ),
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
                                      if (hit.phone.trim().isNotEmpty)
                                        hit.phone,
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
                          decoration: _fieldDecoration(
                            hint: context.l10n.commonPhone,
                          ),
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
                      ],
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
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: Text(
                              context.l10n.actionCancel,
                              style: FontUtility.button.copyWith(
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _confirm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                ),
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
                                          : widget.confirmLabel,
                                      style: FontUtility.button.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerHit {
  final String uniqueId;
  final String name;
  final String phone;
  final String? email;

  const _CustomerHit({
    required this.uniqueId,
    required this.name,
    required this.phone,
    this.email,
  });
}
