import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/device_settings_store.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/routes.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/presentation/screens/splash_screen.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';

/// Device-level POS settings: auto sync, interval, POS code, and sync history.
class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({super.key});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  static const Color _primary = Color(0xFF4A00E0);

  bool _loading = true;
  bool _saving = false;
  bool _resetting = false;
  String? _error;
  DeviceSettingsSnapshot? _snapshot;
  List<StoreSyncAttemptRecord> _history = const [];
  late final TextEditingController _denominationsController;
  late final TextEditingController _serveNumberMaximumController;

  @override
  void initState() {
    super.initState();
    _denominationsController = TextEditingController(
      text: DeviceSettingsStore.defaultCashDenominations,
    );
    _serveNumberMaximumController = TextEditingController(text: '100');
    _load();
  }

  @override
  void dispose() {
    _denominationsController.dispose();
    _serveNumberMaximumController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = getIt<UiStoreController>();
      final snapshot = await controller.loadDeviceSettingsSnapshot();
      final denomStore = await DeviceSettingsStore.open();
      var serveNumberMaximum = 100;
      try {
        serveNumberMaximum = await controller.loadServeNumberMaximum();
      } catch (_) {}
      List<StoreSyncAttemptRecord> history = const [];
      try {
        history = await controller.loadSyncHistory(limit: 20);
      } catch (_) {
        history = const [];
      }
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _history = history;
        _denominationsController.text = denomStore.loadCashDenominationsRaw();
        _serveNumberMaximumController.text = '$serveNumberMaximum';
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

  Future<void> _saveDenominations() async {
    setState(() => _saving = true);
    try {
      final store = await DeviceSettingsStore.open();
      await store.saveCashDenominationsRaw(_denominationsController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.deviceCashDenomsSaved)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.errorCouldNotSaveDenoms(error.toString())),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveServeNumberMaximum() async {
    final maximum = int.tryParse(_serveNumberMaximumController.text.trim());
    if (maximum == null || maximum < 1 || maximum > 9999) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a maximum between 1 and 9999.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await getIt<UiStoreController>().updateServeNumberMaximum(maximum);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Service numbers will rotate from 1 after reaching $maximum.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveSettings(DeviceSyncSettings settings) async {
    setState(() => _saving = true);
    try {
      await getIt<UiStoreController>().updateDeviceSyncSettings(settings);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.autoSyncEnabled
                ? context.l10n.deviceAutoSyncEnabled(
                    _intervalLabel(context, settings.intervalSeconds),
                  )
                : context.l10n.deviceAutoSyncOff,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          context.l10n.deviceSettingsTitle,
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.actionRefresh,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
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
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: FontUtility.body.copyWith(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: Text(context.l10n.actionRetry),
              ),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final settings = snapshot.syncSettings;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionCard(
          title: context.l10n.commonDevice,
          child: Column(
            children: [
              _infoRow(
                context.l10n.commonPosCodeLabel,
                snapshot.posCode.isEmpty ? '—' : snapshot.posCode,
                emphasize: snapshot.posCode.isNotEmpty,
              ),
              const Divider(height: 24),
              _infoRow(
                context.l10n.commonDeviceId,
                snapshot.deviceId.isEmpty ? '—' : snapshot.deviceId,
                mono: true,
              ),
              if (snapshot.make.isNotEmpty || snapshot.model.isNotEmpty) ...[
                const Divider(height: 24),
                _infoRow(
                  context.l10n.commonHardware,
                  [
                    snapshot.make,
                    snapshot.model,
                  ].where((part) => part.isNotEmpty).join(' '),
                ),
              ],
              const Divider(height: 24),
              _infoRow(
                context.l10n.commonStore,
                snapshot.storeName.isEmpty ? '—' : snapshot.storeName,
              ),
              const Divider(height: 24),
              _infoRow(
                context.l10n.commonOrganisation,
                [
                      if (snapshot.orgName.isNotEmpty) snapshot.orgName,
                      if (snapshot.orgCode.isNotEmpty) snapshot.orgCode,
                    ].join(' · ').isEmpty
                    ? '—'
                    : [
                        if (snapshot.orgName.isNotEmpty) snapshot.orgName,
                        if (snapshot.orgCode.isNotEmpty) snapshot.orgCode,
                      ].join(' · '),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: context.l10n.deviceLoginLease,
          child: Column(
            children: [
              _infoRow(
                context.l10n.deviceLoginLeaseDays,
                _formatLeaseDays(snapshot.loginLeaseDays),
              ),
              const Divider(height: 24),
              _infoRow(
                context.l10n.deviceLastOnlineLogin,
                snapshot.lastOnlineLoginAt == null
                    ? '—'
                    : DateFormat(
                        'dd MMM yyyy · HH:mm',
                      ).format(snapshot.lastOnlineLoginAt!),
              ),
              const Divider(height: 24),
              _infoRow(
                context.l10n.deviceValidUntil,
                snapshot.onlineLoginValidUntil == null
                    ? context.l10n.deviceOnlineSignInRequired
                    : DateFormat(
                        'dd MMM yyyy · HH:mm',
                      ).format(snapshot.onlineLoginValidUntil!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: context.l10n.deviceAutoSync,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.l10n.deviceEnableAutoSync,
                  style: FontUtility.subheading.copyWith(fontSize: 16),
                ),
                subtitle: Text(
                  settings.autoSyncEnabled
                      ? (snapshot.autoSyncRunning
                            ? context.l10n.deviceAutoSyncRunning
                            : context.l10n.deviceAutoSyncStarting)
                      : context.l10n.deviceSyncOnTapOnly,
                  style: FontUtility.body.copyWith(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                value: settings.autoSyncEnabled,
                activeThumbColor: _primary,
                onChanged: _saving
                    ? null
                    : (value) => _saveSettings(
                        settings.copyWith(autoSyncEnabled: value),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.deviceSyncInterval,
                style: FontUtility.body.copyWith(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: settings.intervalSeconds,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  for (final option in DeviceSyncSettings.intervalOptions)
                    DropdownMenuItem(
                      value: option.seconds,
                      child: Text(_intervalLabel(context, option.seconds)),
                    ),
                ],
                onChanged: (_saving || !settings.autoSyncEnabled)
                    ? null
                    : (value) {
                        if (value == null) return;
                        _saveSettings(
                          settings.copyWith(intervalSeconds: value),
                        );
                      },
              ),
              const SizedBox(height: 16),
              _infoRow(
                context.l10n.deviceLastSuccessfulSync,
                snapshot.lastSuccessfulSyncAt == null
                    ? context.l10n.commonNever
                    : DateFormat(
                        'MMM dd, yyyy hh:mm a',
                      ).format(snapshot.lastSuccessfulSyncAt!.toLocal()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.sync),
                  icon: const Icon(Icons.sync_rounded),
                  label: Text(context.l10n.deviceOpenSyncNow),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final store = getIt<UiStoreController>().store;
                    if (store == null) return;
                    final ok = await store.auth.hasStoreRole('admin');
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.storeAdminAccessRequired),
                        ),
                      );
                      return;
                    }
                    Navigator.pushNamed(context, AppRoutes.company);
                  },
                  icon: const Icon(Icons.apartment_rounded),
                  label: Text(context.l10n.deviceCompanySettingsStaff),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: context.l10n.deviceCashDenominations,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _denominationsController,
                enabled: !_saving,
                decoration: InputDecoration(
                  hintText: DeviceSettingsStore.defaultCashDenominations,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _saving ? null : _saveDenominations,
                  style: FilledButton.styleFrom(backgroundColor: _primary),
                  child: Text(context.l10n.deviceSaveDenominations),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Service number rotation',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maximum service number. The next number rotates back to 1.',
                style: FontUtility.body.copyWith(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _serveNumberMaximumController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Maximum service number',
                  hintText: '100',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _saving ? null : _saveServeNumberMaximum,
                  style: FilledButton.styleFrom(backgroundColor: _primary),
                  child: const Text('Save service number maximum'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: context.l10n.deviceSyncHistory,
          child: _history.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    context.l10n.syncNoHistory,
                    style: FontUtility.body.copyWith(color: Colors.black54),
                  ),
                )
              : Column(
                  children: [
                    for (var index = 0; index < _history.length; index++) ...[
                      if (index > 0) const Divider(height: 20),
                      _historyTile(_history[index]),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: context.l10n.deviceDangerZone,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.deviceResetLocalBody,
                style: FontUtility.body.copyWith(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: (_saving || _resetting)
                      ? null
                      : _confirmResetLocalData,
                  icon: _resetting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever_rounded),
                  label: Text(
                    _resetting
                        ? context.l10n.deviceResetting
                        : context.l10n.deviceResetAllLocal,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB42318),
                    side: const BorderSide(color: Color(0xFFB42318)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmResetLocalData() async {
    final confirmController = TextEditingController();
    var keepServers = true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.l10n.deviceResetConfirmTitle),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.deviceResetConfirmBody,
                      style: FontUtility.body.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: keepServers,
                      onChanged: (value) {
                        setDialogState(() => keepServers = value ?? true);
                      },
                      title: Text(
                        context.l10n.deviceKeepSavedServers,
                        style: FontUtility.body.copyWith(fontSize: 14),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.deviceTypeResetConfirm,
                      style: FontUtility.body.copyWith(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'RESET',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.l10n.actionCancel),
                ),
                TextButton(
                  onPressed:
                      confirmController.text.trim().toUpperCase() == 'RESET'
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB42318),
                  ),
                  child: Text(context.l10n.deviceResetAction),
                ),
              ],
            );
          },
        );
      },
    );
    confirmController.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _resetting = true);
    try {
      await getIt<UiStoreController>().resetAllLocalData(
        keepSavedServers: keepServers,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _resetting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.deviceResetFailed(error.toString())),
        ),
      );
    }
  }

  String _intervalLabel(BuildContext context, int seconds) {
    switch (seconds) {
      case 60:
        return context.l10n.deviceInterval1Min;
      case 300:
        return context.l10n.deviceInterval5Min;
      case 900:
        return context.l10n.deviceInterval15Min;
      case 1800:
        return context.l10n.deviceInterval30Min;
      case 3600:
        return context.l10n.deviceInterval1Hour;
      default:
        final minutes = seconds ~/ 60;
        if (minutes >= 1) {
          return context.l10n.deviceIntervalEveryMinutes(minutes);
        }
        return context.l10n.deviceIntervalEverySeconds(seconds);
    }
  }

  String _formatLeaseDays(double days) {
    if (days <= 0) return context.l10n.commonEmpty;
    if ((days - days.round()).abs() < 0.001) {
      final whole = days.round();
      return whole == 1
          ? context.l10n.deviceLeaseOneDay
          : context.l10n.deviceLeaseDaysCount(whole);
    }
    return context.l10n.deviceLeaseDaysCount(days.round());
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: FontUtility.subheading.copyWith(fontSize: 18)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    bool emphasize = false,
    bool mono = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: FontUtility.body.copyWith(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: FontUtility.body.copyWith(
              fontSize: emphasize ? 22 : 15,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: emphasize ? 2 : (mono ? 0.2 : 0),
              fontFamily: mono || emphasize ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _historyTile(StoreSyncAttemptRecord entry) {
    final ok = entry.success && !entry.skipped;
    final color = entry.skipped
        ? Colors.orange.shade700
        : (ok ? Colors.green.shade700 : Colors.red.shade700);
    final when =
        DateTime.tryParse(entry.completedAt) ??
        DateTime.tryParse(entry.startedAt);
    final stamp = when == null
        ? '—'
        : DateFormat('MMM dd, hh:mm a').format(when.toLocal());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: entry.direction == 'import'
              ? context.l10n.syncDownloadFromRemote
              : context.l10n.syncUploadToRemote,
          child: Icon(
            entry.direction == 'import'
                ? Icons.cloud_download_rounded
                : Icons.cloud_upload_rounded,
            size: 20,
            color: _primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.entity,
                style: FontUtility.subheading.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                stamp,
                style: FontUtility.body.copyWith(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              if (entry.message.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  entry.message,
                  style: FontUtility.body.copyWith(fontSize: 13),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                context.l10n.syncHistoryStats(
                  entry.processedCount,
                  entry.successCount,
                  entry.failureCount,
                ),
                style: FontUtility.body.copyWith(
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
        Text(
          entry.skipped
              ? context.l10n.commonSkipped
              : (ok ? context.l10n.commonSuccess : context.l10n.commonFailed),
          style: FontUtility.body.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
