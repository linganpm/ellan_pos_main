import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/features/store_setup/presentation/store_setup_ui.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';

class CategoriesSetupScreen extends StatefulWidget {
  const CategoriesSetupScreen({super.key});

  @override
  State<CategoriesSetupScreen> createState() => _CategoriesSetupScreenState();
}

class _CategoriesSetupScreenState extends State<CategoriesSetupScreen> {
  static const _accent = StoreSetupUi.categoriesAccent;

  List<Map<String, dynamic>> _masters = [];
  List<dynamic> _linked = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = context.read<UiStoreController>();
      final store = c.store!;
      final masters = await store.products.listMasterCategories();
      final linked = await store.products.listCategories(store.scope);
      if (!mounted) return;
      setState(() {
        _masters = masters;
        _linked = linked;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _createMaster() async {
    final nameCtrl = TextEditingController();
    final ok = await StoreSetupUi.showFormDialog(
      context: context,
      title: context.l10n.storeSetupNewMasterCategory,
      accent: _accent,
      confirmLabel: context.l10n.storeSetupCreate,
      child: TextField(
        controller: nameCtrl,
        autofocus: true,
        decoration: StoreSetupUi.field(
          hint: 'e.g. Starters, Mains, Drinks',
          label: context.l10n.storeSetupCategoryName,
          icon: Icons.folder_rounded,
          accent: _accent,
        ),
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final store = context.read<UiStoreController>().store!;
    final master = await store.products.createMasterCategory(
      name: nameCtrl.text.trim(),
    );
    await store.products.linkMasterCategory(
      scope: store.scope,
      masterLocalId: '${master['localId']}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.storeSetupCategoryAddedOffline)),
    );
    await _reload();
    try {
      await context.read<UiStoreController>().loadCatalogue();
    } catch (_) {}
  }

  Future<void> _linkMaster(Map<String, dynamic> master) async {
    final store = context.read<UiStoreController>().store!;
    await store.products.linkMasterCategory(
      scope: store.scope,
      masterLocalId: '${master['localId']}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.storeSetupLinkedToStore('${master['name']}'),
        ),
      ),
    );
    await _reload();
  }

  Future<void> _deleteLinked(dynamic category) async {
    final localId = '${category.localId ?? ''}'.trim();
    if (localId.isEmpty) return;
    final name = '${category.name ?? localId}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.l10n.storeSetupRemoveCategory),
        content: Text(
          'Remove "$name" and its packages from this store. Sync to export.',
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
    await store.products.softDeleteCategory(
      scope: store.scope,
      categoryLocalId: localId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.storeSetupCategoryDeletedOffline)),
    );
    await _reload();
    try {
      await context.read<UiStoreController>().loadCatalogue();
    } catch (_) {}
  }

  Future<void> _renameLinked(dynamic category) async {
    final localId = '${category.localId ?? ''}'.trim();
    if (localId.isEmpty) return;
    final nameCtrl = TextEditingController(text: '${category.name ?? ''}');
    final ok = await StoreSetupUi.showFormDialog(
      context: context,
      title: context.l10n.storeSetupRenameCategory,
      accent: _accent,
      confirmLabel: context.l10n.actionSave,
      child: TextField(
        controller: nameCtrl,
        autofocus: true,
        decoration: StoreSetupUi.field(
          hint: context.l10n.storeSetupCategoryName,
          label: context.l10n.commonName,
          icon: Icons.edit_rounded,
          accent: _accent,
        ),
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final store = context.read<UiStoreController>().store!;
    await store.products.renameCategory(
      scope: store.scope,
      categoryLocalId: localId,
      name: nameCtrl.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.storeSetupRenamedOffline)),
    );
    await _reload();
    try {
      await context.read<UiStoreController>().loadCatalogue();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StoreSetupUi.canvas,
      appBar: StoreSetupUi.appBar(
        title: context.l10n.commonCategories,
        accent: _accent,
        actions: [
          StoreSetupUi.iconAction(
            label: context.l10n.actionRefresh,
            icon: Icons.refresh_rounded,
            onPressed: _reload,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: StoreSetupUi.addButton(
        label: context.l10n.storeSetupNewCategory,
        onPressed: _createMaster,
        accent: _accent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
          ? Center(child: Text(_error!))
          : LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 900;
                final masterPanel = _panel(
                  title: context.l10n.storeSetupMasterCategories,
                  child: _masters.isEmpty
                      ? StoreSetupUi.emptyState(
                          icon: Icons.folder_open_rounded,
                          title: context.l10n.storeSetupNoMasterCategories,
                          accent: _accent,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          itemCount: _masters.length,
                          itemBuilder: (_, i) {
                            final m = _masters[i];
                            final pending = m['exported'] == 0;
                            return StoreSetupUi.cardTile(
                              accent: _accent,
                              icon: Icons.folder_rounded,
                              title: '${m['name']}',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (pending)
                                    StoreSetupUi.statusChip(
                                      context.l10n.commonPending,
                                      pending: true,
                                      accent: _accent,
                                    ),
                                  StoreSetupUi.iconAction(
                                    label: context.l10n.storeSetupAddToStore,
                                    icon: Icons.add_rounded,
                                    color: _accent,
                                    onPressed: () => _linkMaster(m),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                );
                final storePanel = _panel(
                  title: context.l10n.storeSetupThisStore,
                  child: _linked.isEmpty
                      ? StoreSetupUi.emptyState(
                          icon: Icons.storefront_outlined,
                          title: context.l10n.storeSetupNothingLinked,
                          accent: _accent,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                          itemCount: _linked.length,
                          itemBuilder: (_, i) {
                            final c = _linked[i];
                            final name = c.name ?? c.toString();
                            return StoreSetupUi.cardTile(
                              accent: const Color(0xFFD97706),
                              icon: Icons.storefront_rounded,
                              title: '$name',
                              onTap: () => _renameLinked(c),
                              trailing: StoreSetupUi.iconAction(
                                label: context.l10n.storeSetupRemoveFromStore,
                                icon: Icons.delete_outline_rounded,
                                color: Colors.red.shade400,
                                onPressed: () => _deleteLinked(c),
                              ),
                            );
                          },
                        ),
                );
                if (stacked) {
                  return ListView(
                    children: [
                      SizedBox(height: 360, child: masterPanel),
                      SizedBox(height: 420, child: storePanel),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: masterPanel),
                    const SizedBox(width: 12),
                    Expanded(child: storePanel),
                  ],
                );
              },
            ),
    );
  }

  Widget _panel({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Text(
              title,
              style: FontUtility.heading.copyWith(
                fontSize: 20,
                color: StoreSetupUi.ink,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
