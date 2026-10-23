import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/features/store_setup/presentation/store_setup_ui.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import 'package:pos_tablet/presentation/widgets/rubber_push.dart';

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
      title: isEdit
          ? context.l10n.storeSetupEditAddonGroup
          : context.l10n.storeSetupAddonGroup,
      accent: _accent,
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RubberPush(child: TextField(
              controller: nameCtrl,
              decoration: StoreSetupUi.field(
                hint: 'e.g. Extra toppings',
                label: context.l10n.storeSetupGroupName,
                icon: Icons.playlist_add_rounded,
                accent: _accent,
              ),
            )),
            const SizedBox(height: 12),
            RubberPush(child: TextField(
              controller: itemCtrl,
              decoration: StoreSetupUi.field(
                hint: 'e.g. Cheese',
                label: context.l10n.storeSetupFirstItemName,
                icon: Icons.egg_alt_rounded,
                accent: _accent,
              ),
            )),
            const SizedBox(height: 12),
            RubberPush(child: TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: StoreSetupUi.field(
                hint: '0.00',
                label: context.l10n.storeSetupItemPrice,
                icon: Icons.payments_rounded,
                accent: _accent,
              ),
            )),
            if (!isEdit && _variants.isNotEmpty) ...[
              const SizedBox(height: 12),
              RubberPush(child: DropdownButtonFormField<String>(
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
                  hint: context.l10n.storeSetupChoosePackage,
                  label: context.l10n.storeSetupLinkToPackage,
                  icon: Icons.link_rounded,
                  accent: _accent,
                ),
              )),
            ],
            if (isEdit) ...[
              const SizedBox(height: 12),
              if (_variants.isEmpty)
                Text(
                  context.l10n.storeSetupNoPackagesYetShort,
                  style: FontUtility.body.copyWith(color: StoreSetupUi.muted),
                )
              else
                RubberPush(child: DropdownButtonFormField<String>(
                  initialValue: variantLocalId,
                  items: [
                    for (final v in _variants)
                      DropdownMenuItem(
                        value: v.localId,
                        child: Text(
                          '${v.productName} · ${v.productVariantName}',
                        ),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => variantLocalId = v),
                  decoration: StoreSetupUi.field(
                    hint: context.l10n.storeSetupChoosePackage,
                    label: context.l10n.storeSetupPackage,
                    accent: _accent,
                  ),
                )),
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
        content: Text(
          isEdit ? 'Add-on updated offline' : 'Add-on saved offline',
        ),
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
        title: Text(context.l10n.storeSetupDeleteAddonGroup),
        content: Text(
          context.l10n.storeSetupRemoveEntitySync('${group['name']}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.actionDelete),
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
      SnackBar(content: Text(context.l10n.storeSetupAddonDeletedOffline)),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StoreSetupUi.canvas,
      appBar: StoreSetupUi.appBar(
        title: context.l10n.commonAddons,
        accent: _accent,
      ),
      floatingActionButton: StoreSetupUi.addButton(
        label: context.l10n.storeSetupAddGroup,
        onPressed: () => _upsert(),
        accent: _accent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _groups.isEmpty
          ? StoreSetupUi.emptyState(
              icon: Icons.playlist_add_check_rounded,
              title: context.l10n.storeSetupNoAddonsYet,
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
                        pending
                            ? context.l10n.commonPending
                            : context.l10n.commonSynced,
                        pending: pending,
                        accent: _accent,
                      ),
                      StoreSetupUi.iconAction(
                        label: context.l10n.actionDelete,
                        icon: Icons.delete_outline_rounded,
                        color: Colors.red.shade400,
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
