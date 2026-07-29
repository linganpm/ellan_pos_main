import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/features/store_setup/presentation/store_setup_ui.dart';

class AddonsSetupScreen extends StatefulWidget {
  const AddonsSetupScreen({super.key});

  @override
  State<AddonsSetupScreen> createState() => _AddonsSetupScreenState();
}

class _AddonsSetupScreenState extends State<AddonsSetupScreen> {
  static const _accent = StoreSetupUi.addonsAccent;

  List<Map<String, dynamic>> _groups = [];
  List<StoreProductVariantRecord> _variants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final store = context.read<UiStoreController>().store!;
    final groups = await store.products.listCatalogAddonGroups(store.scope);
    final variants = await store.products.searchDetails(scope: store.scope);
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _variants = variants;
      _loading = false;
    });
  }

  Future<void> _upsert({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: '${existing?['name'] ?? ''}');
    final itemCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String? variantLocalId = _variants.isEmpty ? null : _variants.first.localId;
    final isEdit = existing != null;

    if (isEdit) {
      final store = context.read<UiStoreController>().store!;
      final items = await store.products.listCatalogAddonItems(
        store.scope,
        '${existing['localId']}',
      );
      if (items.isNotEmpty) {
        itemCtrl.text = '${items.first['name'] ?? ''}';
        priceCtrl.text = '${items.first['price'] ?? ''}';
      }
    }

    final ok = await StoreSetupUi.showFormDialog(
      context: context,
      title: isEdit ? 'Edit add-on group' : 'Add-on group',
      accent: _accent,
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: StoreSetupUi.field(
                hint: 'e.g. Extra toppings',
                label: 'Group name *',
                icon: Icons.playlist_add_rounded,
                accent: _accent,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: itemCtrl,
              decoration: StoreSetupUi.field(
                hint: 'e.g. Cheese',
                label: 'First item name *',
                icon: Icons.egg_alt_rounded,
                accent: _accent,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: StoreSetupUi.field(
                hint: '0.00',
                label: 'Item price *',
                icon: Icons.payments_rounded,
                accent: _accent,
              ),
            ),
            if (!isEdit && _variants.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: variantLocalId,
                items: [
                  for (final v in _variants)
                    DropdownMenuItem(
                      value: v.localId,
                      child: Text('${v.productName} · ${v.productVariantName}'),
                    ),
                ],
                onChanged: (v) => setLocal(() => variantLocalId = v),
                decoration: StoreSetupUi.field(
                  hint: 'Choose a package',
                  label: 'Link to package',
                  icon: Icons.link_rounded,
                  accent: _accent,
                ),
              ),
            ],
            if (isEdit) ...[
              const SizedBox(height: 12),
              StoreSetupUi.sectionLabel('Link to package', accent: _accent),
              Text(
                'Choose which package should offer this add-on group.',
                style: FontUtility.body.copyWith(
                  fontSize: 12,
                  color: StoreSetupUi.muted,
                ),
              ),
              const SizedBox(height: 8),
              if (_variants.isEmpty)
                Text(
                  'No packages yet.',
                  style: FontUtility.body.copyWith(color: StoreSetupUi.muted),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: variantLocalId,
                  items: [
                    for (final v in _variants)
                      DropdownMenuItem(
                        value: v.localId,
                        child:
                            Text('${v.productName} · ${v.productVariantName}'),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => variantLocalId = v),
                  decoration: StoreSetupUi.field(
                    hint: 'Choose a package',
                    label: 'Package',
                    accent: _accent,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
    if (ok != true ||
        nameCtrl.text.trim().isEmpty ||
        itemCtrl.text.trim().isEmpty) {
      return;
    }
    final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
    final store = context.read<UiStoreController>().store!;
    final group = await store.products.upsertAddonGroup(
      scope: store.scope,
      localId: isEdit ? '${existing['localId']}' : null,
      name: nameCtrl.text.trim(),
      items: [(name: itemCtrl.text.trim(), price: price)],
    );
    if (variantLocalId != null && variantLocalId!.isNotEmpty) {
      await store.products.linkAddonGroup(
        scope: store.scope,
        variantLocalId: variantLocalId!,
        groupLocalId: '${group['localId']}',
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEdit ? 'Add-on updated offline' : 'Add-on saved offline'),
      ),
    );
    await _reload();
  }

  Future<void> _delete(Map<String, dynamic> group) async {
    final localId = '${group['localId'] ?? ''}'.trim();
    if (localId.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete add-on group?'),
        content: Text('Remove "${group['name']}". Sync to export.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final store = context.read<UiStoreController>().store!;
    await store.products.softDeleteAddonGroup(
      scope: store.scope,
      groupLocalId: localId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add-on deleted offline. Sync to export.'),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StoreSetupUi.canvas,
      appBar: StoreSetupUi.appBar(title: 'Add-ons', accent: _accent),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _upsert(),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add group'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _groups.isEmpty
              ? StoreSetupUi.emptyState(
                  icon: Icons.playlist_add_check_rounded,
                  title: 'No add-ons yet',
                  accent: _accent,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _groups.length,
                  itemBuilder: (_, i) {
                    final g = _groups[i];
                    final pending = g['exported'] == 0;
                    return StoreSetupUi.cardTile(
                      accent: _accent,
                      icon: Icons.playlist_add_rounded,
                      title: '${g['name']}',
                      onTap: () => _upsert(existing: g),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StoreSetupUi.statusChip(
                            pending ? 'Pending' : 'Synced',
                            pending: pending,
                            accent: _accent,
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red.shade400,
                            ),
                            onPressed: () => _delete(g),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
