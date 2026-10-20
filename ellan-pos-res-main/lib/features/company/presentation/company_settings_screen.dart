import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../../presentation/widgets/adaptive_form_row.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/constants/discovery_constants.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/pos_report_mailer_defaults.dart';
import 'package:pos_tablet/core/pos_wallet_variant_defaults.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/core/utils/user_facing_error.dart';
import 'package:pos_tablet/core/store_trade_modes.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';

/// Edit open-store company profile (online + local store_info mirror).
class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  static const _primary = Color(0xFF4A00E0);
  static const _ink = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF6B7280);
  static const _surface = Color(0xFFF3F5F9);

  final _name = TextEditingController();
  final _registration = TextEditingController();
  final _address = TextEditingController();
  final _tax = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _identifier = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _walletsLoading = false;
  bool _addingWallet = false;
  String? _error;
  String _siLabel = '';
  String _uniqueId = '';
  String? _logoPath;
  bool _logoPendingSync = false;
  bool _profilePendingSync = false;
  List<StoreWalletRecord> _localWallets = const [];
  List<Map<String, dynamic>> _variants = const [];
  Set<int> _linkedVariantIds = {};
  List<Map<String, dynamic>> _fixedMailers = const [];
  StoreTradeModes _tradeModes = StoreTradeModes.current();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _registration.dispose();
    _address.dispose();
    _tax.dispose();
    _phone.dispose();
    _email.dispose();
    _identifier.dispose();
    super.dispose();
  }

  String? get _accessToken {
    final login = context.read<UiStoreController>().organisationLogin;
    final token = login?.accessToken?.trim() ?? '';
    return token.isEmpty ? null : token;
  }

  Map<String, String> _storeRefs() =>
      context.read<UiStoreController>().companyProfileRefs();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final store = context.read<UiStoreController>().store;
    if (store == null) {
      setState(() {
        _error = context.l10n.homeOpenStoreFirst;
        _loading = false;
      });
      return;
    }

    try {
      final profile = await store.loadCompanyProfile();
      _name.text = '${profile['storeName'] ?? ''}';
      _phone.text = '${profile['phone'] ?? ''}';
      _email.text = '${profile['contactEmail'] ?? ''}';
      _address.text = '${profile['address'] ?? ''}';
      _registration.text = '${profile['registration_number'] ?? ''}';
      _tax.text = '${profile['tax_number'] ?? ''}';
      _identifier.text = '${profile['identifier'] ?? ''}';
      final logo = '${profile['logo'] ?? ''}'.trim();
      _logoPath = (logo.isNotEmpty && logo != 'logo.png') ? logo : null;
      _logoPendingSync =
          ((profile['logo_pending_sync'] as num?)?.toInt() ?? 0) == 1;
      _profilePendingSync =
          ((profile['profile_pending_sync'] as num?)?.toInt() ?? 0) == 1;
      final remote = '${profile['storeRemoteId'] ?? ''}'.trim();
      _siLabel = remote.isNotEmpty
          ? remote
          : '${profile['serviceInstanceId'] ?? store.serviceInstanceId}';
      _uniqueId = '${profile['uniqueId'] ?? store.uniqueId}';

      await store.ensureFixedSystemMailers(
        host: PosReportMailerDefaults.host,
        port: PosReportMailerDefaults.port,
        username: PosReportMailerDefaults.username,
        password: PosReportMailerDefaults.password,
        fromEmail: PosReportMailerDefaults.fromEmail,
        reportsFromName: PosReportMailerDefaults.reportsFromName,
        invoicesFromName: PosReportMailerDefaults.invoicesFromName,
        useTls: PosReportMailerDefaults.useTls,
      );

      // Prefer gateway public mailers (no password) when online.
      final token = _accessToken;
      if (token != null) {
        try {
          final origin = discoveryOrigin(kDiscoveryUrl);
          final refs = _storeRefs();
          final uri = Uri.parse(
            '$origin/api/pos/store/profile',
          ).replace(queryParameters: refs);
          final response = await http.get(
            uri,
            headers: {'Authorization': 'Bearer $token'},
          );
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final body = jsonDecode(response.body);
            if (body is Map) {
              final raw = body['fixed_email_mailers'];
              if (raw is List) {
                final rows = raw
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList(growable: false);
                if (rows.isNotEmpty) {
                  await store.applyFixedEmailMailersFromRemote(
                    rows,
                    localPasswordFallback: PosReportMailerDefaults.password,
                  );
                }
              }
            }
          }
        } catch (_) {
          // Offline / profile fetch failure — keep local locked defaults.
        }
      }

      final mailers = <Map<String, dynamic>>[];
      for (final purpose in [
        PosReportMailerDefaults.purpose,
        PosReportMailerDefaults.invoicePurpose,
      ]) {
        final row = await store.loadEmailConfig(purpose);
        if (row != null) {
          mailers.add(Map<String, dynamic>.from(row));
        }
      }
      _fixedMailers = mailers.isEmpty
          ? PosReportMailerDefaults.localPublicRows()
          : mailers;
    } catch (e) {
      _error = userFacingError(
        e,
        fallback: context.l10n.errorCouldNotLoadCompanySettings,
      );
    }
    if (!mounted) return;
    setState(() => _loading = false);
    await _loadWallets();
  }

  Future<void> _loadWallets() async {
    final controller = context.read<UiStoreController>();
    final store = controller.store;
    if (store == null) return;

    setState(() => _walletsLoading = true);
    try {
      final local = await store.wallets.list(store.scope, skipAuth: true);
      // Brand-new branch with no wallets yet — seed Cash/Card/UPI/Credit locally
      // so checkout works before the first successful remote sync.
      if (local.isEmpty) {
        for (final row in PosWalletVariantDefaults.defaultBranchVariants) {
          final id = (row['id'] as num?)?.toInt();
          if (id == null) continue;
          final name = '${row['name'] ?? ''}'.trim();
          await store.wallets.addLocalVariant(
            store.scope,
            variantId: id,
            label: name.isEmpty ? context.l10n.companyWallet : name,
            variantName: name,
            variantType: (row['type'] as num?)?.toInt(),
          );
        }
      }
      final localAfterSeed = local.isEmpty
          ? await store.wallets.list(store.scope, skipAuth: true)
          : local;
      final cachedVariants = await store.wallets.listVariants(store.scope);
      if (!mounted) return;
      setState(() {
        _localWallets = localAfterSeed;
        _linkedVariantIds = {
          for (final w in localAfterSeed)
            if (w.walletVariantId != null) w.walletVariantId!,
        };
        _variants = PosWalletVariantDefaults.mergeWithRemote(cachedVariants);
      });

      // 2) Sync gateway catalogue + branch wallets whenever reachable.
      final refs = _storeRefs();
      final origin = discoveryOrigin(kDiscoveryUrl);
      final uri = Uri.parse('$origin/api/pos/store/wallets').replace(
        queryParameters: {
          for (final e in refs.entries)
            if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
        },
      );
      // Never send Authorization on GET — stale Bearer tokens can 401 listing.
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Keep cached / default catalogue; sync will retry next open / store sync.
        return;
      }
      final body = jsonDecode(response.body);
      if (body is! Map) return;

      final variants = <Map<String, dynamic>>[];
      final rawVariants = body['variants'];
      if (rawVariants is List) {
        for (final row in rawVariants.whereType<Map>()) {
          variants.add(Map<String, dynamic>.from(row));
        }
      }
      if (variants.isNotEmpty) {
        await store.wallets.saveVariants(store.scope, variants);
      }

      final linked = <int>{};
      final rawLinked = body['linked_variant_ids'];
      if (rawLinked is List) {
        for (final id in rawLinked) {
          final n = id is num ? id.toInt() : int.tryParse('$id');
          if (n != null) linked.add(n);
        }
      }

      final walletsPayload = body['wallets'];
      if (walletsPayload is Map) {
        final rows = walletsPayload['data'] ?? walletsPayload['wallets'];
        final hasRows = rows is List && rows.isNotEmpty;
        // Ensure variants hitch a ride even if nested payload omitted them.
        final importPayload = Map<String, dynamic>.from(walletsPayload);
        if (variants.isNotEmpty && importPayload['variants'] == null) {
          importPayload['variants'] = variants;
        }
        await store.wallets.importFromData(
          store.scope,
          importPayload,
          replaceScope: hasRows,
          skipAuth: true,
        );
      } else if (variants.isNotEmpty) {
        await store.wallets.saveVariants(store.scope, variants);
      }

      final refreshed = await store.wallets.list(store.scope, skipAuth: true);
      final linkedFromLocal = <int>{
        for (final w in refreshed)
          if (w.walletVariantId != null) w.walletVariantId!,
      };
      final effectiveLinked = linked.isNotEmpty ? linked : linkedFromLocal;
      final persisted = await store.wallets.listVariants(store.scope);

      if (!mounted) return;
      setState(() {
        _variants = PosWalletVariantDefaults.mergeWithRemote(
          persisted.isNotEmpty ? persisted : variants,
        );
        _linkedVariantIds = effectiveLinked;
        _localWallets = refreshed;
      });
    } catch (_) {
      if (_variants.isEmpty) {
        _variants = PosWalletVariantDefaults.mergeWithRemote(const []);
      }
    } finally {
      if (mounted) setState(() => _walletsLoading = false);
    }
  }

  String _apiErrorMessage(http.Response response, {required String fallback}) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        for (final key in ['message', 'error', 'detail']) {
          final value = body[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
          if (value is Map && value['message'] != null) {
            final nested = '${value['message']}'.trim();
            if (nested.isNotEmpty) return nested;
          }
        }
      }
    } catch (_) {}
    final snippet = response.body.trim();
    if (snippet.isNotEmpty &&
        snippet.length <= 160 &&
        !snippet.startsWith('<')) {
      return snippet;
    }
    return '$fallback (HTTP ${response.statusCode})';
  }

  Future<void> _addWallet(Map<String, dynamic> variant) async {
    final controller = context.read<UiStoreController>();
    final store = controller.store;
    if (store == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.homeOpenStoreFirst)));
      return;
    }

    final variantId = (variant['id'] as num?)?.toInt();
    if (variantId == null) return;
    final label = '${variant['name'] ?? context.l10n.companyPaymentMethod}'
        .trim();

    setState(() {
      _addingWallet = true;
      _error = null;
    });
    try {
      // Always attach locally first so POS works even if remote auth fails.
      await store.wallets.addLocalVariant(
        store.scope,
        variantId: variantId,
        label: label,
        variantName: label,
        variantType: (variant['type'] as num?)?.toInt(),
        variantPgType: (variant['pg_type'] as num?)?.toInt(),
      );

      final refs = _storeRefs();
      final origin = discoveryOrigin(kDiscoveryUrl);
      // Do not send Authorization — stale Bearer tokens trigger
      // "Please log in to continue" from global JWT / IsAuthenticated.
      final response = await http.post(
        Uri.parse('$origin/api/pos/store/wallets'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          ...refs,
          'wallet_variant_id': variantId,
          if ('${variant['key'] ?? ''}'.trim().isNotEmpty)
            'wallet_variant_key': '${variant['key']}'.trim(),
          if (label.isNotEmpty) 'wallet_variant_name': label,
          'label': label,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        if (body is Map && body['wallets'] is Map) {
          await store.wallets.importFromData(
            store.scope,
            Map<String, dynamic>.from(body['wallets'] as Map),
            replaceScope: true,
            skipAuth: true,
          );
        }
      }
      // Remote failure is fine — local wallet is already on the branch.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.companyPaymentMethodAdded(label))),
      );
      await _loadWallets();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(
              e,
              fallback: context.l10n.errorCouldNotAddPaymentMethod,
            ),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _addingWallet = false);
    }
  }

  Future<void> _pickVariantToAdd() async {
    // Refresh catalogue before opening the picker so linked ids stay accurate.
    if (_variants.isEmpty || _walletsLoading) {
      await _loadWallets();
      if (!mounted) return;
    }

    final linked = <int>{
      ..._linkedVariantIds,
      for (final w in _localWallets)
        if (w.walletVariantId != null) w.walletVariantId!,
    };
    final linkedNames = <String>{
      for (final w in _localWallets)
        if ((w.walletVariantName ?? '').trim().isNotEmpty)
          w.walletVariantName!.trim().toLowerCase()
        else if (w.label.trim().isNotEmpty)
          w.label.trim().toLowerCase(),
    };
    final available = _variants
        .where((v) {
          final id = (v['id'] as num?)?.toInt();
          final name = '${v['name'] ?? ''}'.trim().toLowerCase();
          if (id != null && linked.contains(id)) return false;
          if (name.isNotEmpty && linkedNames.contains(name)) return false;
          return true;
        })
        .toList(growable: false);

    if (available.isEmpty) {
      final message = _variants.isEmpty
          ? context.l10n.companyNoPaymentVariants
          : context.l10n.companyAllPaymentMethodsAdded;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Text(
                    context.l10n.companyTapMethodToAdd,
                    style: FontUtility.heading.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: available.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final v = available[i];
                      final subtitle = [
                        if ('${v['type_name'] ?? ''}'.trim().isNotEmpty)
                          '${v['type_name']}',
                        if ('${v['pg_name'] ?? ''}'.trim().isNotEmpty)
                          '${v['pg_name']}',
                      ].join(' · ');
                      return ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: _primary,
                          ),
                        ),
                        title: Text(
                          '${v['name'] ?? context.l10n.companyMethod}',
                          style: FontUtility.body.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: _ink,
                          ),
                        ),
                        subtitle: subtitle.isEmpty
                            ? null
                            : Text(
                                subtitle,
                                style: FontUtility.body.copyWith(
                                  color: _muted,
                                  fontSize: 13,
                                ),
                              ),
                        trailing: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: _primary,
                        ),
                        onTap: () => Navigator.pop(ctx, v),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) {
      await _addWallet(selected);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final sourcePath = await _resolveLogoSourcePath();
      if (sourcePath == null || sourcePath.isEmpty) return;
      if (!mounted) return;
      final store = context.read<UiStoreController>().store;
      if (store == null) return;

      final support = await getApplicationSupportDirectory();
      final dir = Directory(p.join(support.path, 'company_logos'));
      await dir.create(recursive: true);
      final ext = p.extension(sourcePath).isEmpty
          ? '.jpg'
          : p.extension(sourcePath);
      final dest = File(p.join(dir.path, '${store.storeId}$ext'));
      await File(sourcePath).copy(dest.path);
      await store.setCompanyLogoLocal(dest.path);
      if (!mounted) return;
      setState(() {
        _logoPath = dest.path;
        _logoPendingSync = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(e, fallback: context.l10n.errorCouldNotPickLogo),
          ),
        ),
      );
    }
  }

  /// Desktop Linux often breaks `image_picker`/`file_selector` after hot reload
  /// (pigeon channel-error). Prefer native dialogs, then image_picker, then a
  /// manual path entry.
  Future<String?> _resolveLogoSourcePath() async {
    if (Platform.isLinux) {
      final native = await _pickImagePathWithNativeLinuxDialog();
      if (native != null) return native;
    }

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 88,
      );
      if (file != null) return file.path;
    } catch (_) {
      // Fall through to manual path entry.
    }

    if (!mounted) return null;
    return _promptLogoPathManually();
  }

  Future<String?> _pickImagePathWithNativeLinuxDialog() async {
    Future<String?> run(String command, List<String> args) async {
      try {
        final result = await Process.run(command, args, runInShell: false);
        if (result.exitCode != 0) return null;
        final path = '${result.stdout}'.trim();
        if (path.isEmpty) return null;
        if (!File(path).existsSync()) return null;
        return path;
      } catch (_) {
        return null;
      }
    }

    return await run('zenity', const [
          '--file-selection',
          '--title=Choose company logo',
          '--file-filter=Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp',
        ]) ??
        await run('kdialog', const [
          '--getopenfilename',
          '.',
          'Images (*.png *.jpg *.jpeg *.webp *.gif *.bmp)',
        ]) ??
        await run('yad', [
          '--file',
          '--title=Choose company logo',
          '--file-filter=Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp',
        ]);
  }

  Future<String?> _promptLogoPathManually() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(context.l10n.companyLogoFilePath),
          content: SizedBox(
            width: 480,
            child: TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: '/path/to/logo.png',
              ),
              autofocus: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.companyUseFile),
            ),
          ],
        );
      },
    );
    if (ok != true) return null;
    final path = ctrl.text.trim();
    if (path.isEmpty || !File(path).existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorFileNotFound)));
      }
      return null;
    }
    return path;
  }

  Future<void> _save() async {
    final controller = context.read<UiStoreController>();
    final store = controller.store;
    if (store == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Save on the device first so edits work offline; the push below (or
      // the next sync) sends them to the backend.
      await store.saveCompanyProfileLocal(
        storeName: _name.text.trim(),
        contactEmail: _email.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        registrationNumber: _registration.text.trim(),
        taxNumber: _tax.text.trim(),
        identifier: _identifier.text.trim(),
        logo: _logoPath,
        profilePendingSync: true,
      );
      final synced = await controller.pushPendingCompanyProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synced
                ? context.l10n.companySettingsSaved
                : context.l10n.companySettingsSavedOffline,
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = context.l10n.companySettingsSavedNotSynced(
          userFacingError(
            e,
            fallback: context.l10n.errorCouldNotSaveCompanySettings,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setTradeMode({bool? sell, bool? buy}) async {
    final nextSell = sell ?? _tradeModes.sell;
    final nextBuy = buy ?? _tradeModes.buy;
    if (!nextSell && !nextBuy) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.storeTradeNeedOne)));
      return;
    }
    final storeId = context.read<UiStoreController>().store?.scope.storeId;
    if (storeId == null) return;
    final next = StoreTradeModes(sell: nextSell, buy: nextBuy);
    setState(() => _tradeModes = next);
    await next.save(getIt<SharedPreferences>(), storeId);
  }

  Widget _tradeModeTile({
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: FontUtility.heading.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    Text(
                      hint,
                      style: FontUtility.body.copyWith(
                        color: _muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: selected ? color : const Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String placeholder) {
    return InputDecoration(
      hintText: placeholder,
      hintStyle: FontUtility.body.copyWith(
        color: const Color(0xFF9CA3AF),
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
    );
  }

  Widget _section({
    required Color accent,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: FontUtility.heading.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _fieldGap(Widget child) =>
      Padding(padding: const EdgeInsets.only(bottom: 12), child: child);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0.5,
        title: Text(
          context.l10n.companySettingsTitle,
          style: FontUtility.heading.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : ListView(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
                20,
                MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
                40,
              ),
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: FontUtility.body.copyWith(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  _name.text.trim().isNotEmpty
                      ? _name.text.trim()
                      : context.l10n.companyBranch,
                  style: FontUtility.heading.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.commonServiceInstanceShort(_siLabel),
                  style: FontUtility.body.copyWith(
                    color: _muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _uniqueId,
                  style: FontUtility.body.copyWith(
                    color: const Color(0xFF9CA3AF),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 22),
                _section(
                  accent: const Color(0xFFEC4899),
                  icon: Icons.image_rounded,
                  title: context.l10n.companyLogo,
                  children: [
                    AdaptiveFormRow(
                      minChildWidth: 180,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF2F8),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFFBCFE8),
                              ),
                              image:
                                  (_logoPath != null &&
                                      File(_logoPath!).existsSync())
                                  ? DecorationImage(
                                      image: FileImage(File(_logoPath!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child:
                                (_logoPath != null &&
                                    File(_logoPath!).existsSync())
                                ? null
                                : const Icon(
                                    Icons.storefront_rounded,
                                    color: Color(0xFFDB2777),
                                    size: 36,
                                  ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _logoPendingSync
                                  ? context.l10n.companySavedOnDevice
                                  : context.l10n.companyBranchLogo,
                              style: FontUtility.body.copyWith(
                                color: _muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              onPressed: _pickLogo,
                              icon: const Icon(Icons.upload_rounded),
                              label: Text(context.l10n.companyUploadLogo),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                _section(
                  accent: _primary,
                  icon: Icons.storefront_rounded,
                  title: context.l10n.companyBranch,
                  children: [
                    _fieldGap(
                      TextField(
                        controller: _name,
                        style: FontUtility.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                          color: _ink,
                        ),
                        decoration: _fieldDecoration(
                          context.l10n.companyBranchStoreName,
                        ),
                      ),
                    ),
                    _fieldGap(
                      TextField(
                        controller: _identifier,
                        style: FontUtility.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                          color: _ink,
                        ),
                        decoration: _fieldDecoration(
                          context.l10n.companyIdentifier,
                        ),
                      ),
                    ),
                    TextField(
                      controller: _address,
                      maxLines: 2,
                      style: FontUtility.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: _ink,
                      ),
                      decoration: _fieldDecoration(context.l10n.companyAddress),
                    ),
                  ],
                ),
                _section(
                  accent: const Color(0xFF0EA5E9),
                  icon: Icons.contact_mail_rounded,
                  title: context.l10n.companyContact,
                  children: [
                    _fieldGap(
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        style: FontUtility.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                          color: _ink,
                        ),
                        decoration: _fieldDecoration(context.l10n.commonPhone),
                      ),
                    ),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: FontUtility.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: _ink,
                      ),
                      decoration: _fieldDecoration(context.l10n.commonEmail),
                    ),
                  ],
                ),
                _section(
                  accent: const Color(0xFF059669),
                  icon: Icons.badge_rounded,
                  title: context.l10n.companyLegal,
                  children: [
                    _fieldGap(
                      TextField(
                        controller: _registration,
                        style: FontUtility.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                          color: _ink,
                        ),
                        decoration: _fieldDecoration(
                          context.l10n.companyRegistrationNumber,
                        ),
                      ),
                    ),
                    TextField(
                      controller: _tax,
                      style: FontUtility.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: _ink,
                      ),
                      decoration: _fieldDecoration(
                        context.l10n.companyTaxRegistrationNumber,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                            context.l10n.companySaveChanges,
                            style: FontUtility.button.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                if (_profilePendingSync) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 18,
                        color: Color(0xFFB45309),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.companySettingsPendingSync,
                          style: FontUtility.body.copyWith(
                            color: const Color(0xFFB45309),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                _section(
                  accent: const Color(0xFF178A45),
                  icon: Icons.swap_vert_rounded,
                  title: context.l10n.storeTradeTitle,
                  children: [
                    Text(
                      context.l10n.storeTradeBody,
                      style: FontUtility.body.copyWith(
                        color: _muted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 14),
                    AdaptiveFormRow(
                      children: [
                        _tradeModeTile(
                            label: context.l10n.storeTradeSell,
                            hint: context.l10n.storeTradeSellHint,
                            icon: Icons.trending_up_rounded,
                            color: const Color(0xFF178A45),
                            selected: _tradeModes.sell,
                            onTap: () => _setTradeMode(sell: !_tradeModes.sell),
                        ),
                        _tradeModeTile(
                            label: context.l10n.storeTradeBuy,
                            hint: context.l10n.storeTradeBuyHint,
                            icon: Icons.trending_down_rounded,
                            color: const Color(0xFFD32F2F),
                            selected: _tradeModes.buy,
                            onTap: () => _setTradeMode(buy: !_tradeModes.buy),
                        ),
                      ],
                    ),
                  ],
                ),
                _section(
                  accent: const Color(0xFF6366F1),
                  icon: Icons.mail_rounded,
                  title: context.l10n.companySystemEmailLocked,
                  children: [
                    ...(_fixedMailers.isEmpty
                            ? PosReportMailerDefaults.localPublicRows()
                            : _fixedMailers)
                        .map((row) {
                          final purpose = '${row['purpose'] ?? ''}';
                          final label =
                              purpose == PosReportMailerDefaults.invoicePurpose
                              ? 'Invoice / bookings'
                              : context.l10n.companySalesReports;
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.companyLabelLocked(label),
                                  style: FontUtility.body.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: _primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${row['from_email'] ?? row['username'] ?? PosReportMailerDefaults.fromEmail}',
                                  style: FontUtility.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                                Text(
                                  '${row['from_name'] ?? ''}',
                                  style: FontUtility.body.copyWith(
                                    color: _muted,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${row['host'] ?? PosReportMailerDefaults.host}',
                                  style: FontUtility.body.copyWith(
                                    color: _muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                  ],
                ),
                const SizedBox(height: 8),
                _section(
                  accent: const Color(0xFFF59E0B),
                  icon: Icons.account_balance_wallet_rounded,
                  title: context.l10n.companyWallet,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Tooltip(
                        message: context.l10n.companyAddToBranch,
                        child: Semantics(
                          label: context.l10n.companyAddToBranch,
                          button: true,
                          child: IconButton(
                            onPressed: (_walletsLoading || _addingWallet)
                                ? null
                                : _pickVariantToAdd,
                            icon: const Icon(
                              Icons.add_rounded,
                              color: _primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_walletsLoading || _addingWallet)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(color: _primary),
                        ),
                      )
                    else if (_localWallets.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          context.l10n.companyNoPaymentMethodsBranch,
                          style: FontUtility.body.copyWith(
                            color: _muted,
                            fontSize: 15,
                          ),
                        ),
                      )
                    else
                      ..._localWallets.map((w) {
                        final title = w.label.trim().isEmpty
                            ? w.paymentMode
                            : w.label.trim();
                        final subtitle = [
                          if ((w.walletVariantName ?? '').trim().isNotEmpty)
                            w.walletVariantName!.trim(),
                          w.paymentMode,
                        ].where((s) => s.trim().isNotEmpty).join(' · ');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.payments_rounded,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: FontUtility.body.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: _ink,
                                      ),
                                    ),
                                    if (subtitle.isNotEmpty)
                                      Text(
                                        subtitle,
                                        style: FontUtility.body.copyWith(
                                          color: _muted,
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ),
    );
  }
}
