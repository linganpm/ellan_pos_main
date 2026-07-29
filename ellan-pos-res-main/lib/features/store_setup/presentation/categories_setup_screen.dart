import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/features/store_setup/presentation/store_setup_ui.dart';

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
      title: 'New master category',
      accent: _accent,
      confirmLabel: 'Create',
      child: TextField(
        controller: nameCtrl,
        autofocus: true,
        decoration: StoreSetupUi.field(
          hint: 'e.g. Starters, Mains, Drinks',
          label: 'Category name',
          icon: Icons.folder_rounded,
          accent: _accent,
        ),
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final store = context.read<UiStoreController>().store!;
    final master =
        await store.products.createMasterCategory(name: nameCtrl.text.trim());
    await store.products.linkMasterCategory(
      scope: store.scope,
      masterLocalId: '${master['localId']}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Category added to master and this store (offline). Sync to export.',
        ),
      ),
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
      SnackBar(content: Text('Linked “${master['name']}” to this store')),
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
        title: const Text('Remove category?'),
        content: Text(
          'Remove "$name" and its packages from this store. Sync to export.',
        ),
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
    await store.products.softDeleteCategory(
      scope: store.scope,
      categoryLocalId: localId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Category deleted offline. Sync to export.'),
      ),
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
      title: 'Rename category',
      accent: _accent,
      confirmLabel: 'Save',
      child: TextField(
        controller: nameCtrl,
        autofocus: true,
        decoration: StoreSetupUi.field(
          hint: 'Category name',
          label: 'Name',
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
      const SnackBar(content: Text('Renamed offline. Sync to export.')),
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
        title: 'Categories',
        accent: _accent,
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createMaster,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New category'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
              ? Center(child: Text(_error!))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 900;
                    final masterPanel = _panel(
                      title: 'Master categories',
                      child: _masters.isEmpty
                          ? StoreSetupUi.emptyState(
                              icon: Icons.folder_open_rounded,
                              title: 'No master categories',
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
                                          'Pending',
                                          pending: true,
                                          accent: _accent,
                                        ),
                                      TextButton(
                                        onPressed: () => _linkMaster(m),
                                        child: Text(
                                          'Add to store',
                                          style: FontUtility.body.copyWith(
                                            color: _accent,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    );
                    final storePanel = _panel(
                      title: 'This store',
                      child: _linked.isEmpty
                          ? StoreSetupUi.emptyState(
                              icon: Icons.storefront_outlined,
                              title: 'Nothing linked yet',
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
                                  trailing: IconButton(
                                    tooltip: 'Remove from store',
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red.shade400,
                                    ),
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

  Widget _panel({
    required String title,
    required Widget child,
  }) {
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
