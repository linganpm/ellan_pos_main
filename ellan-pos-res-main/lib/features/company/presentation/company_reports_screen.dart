import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/pos_report_mailer_defaults.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/core/utils/user_facing_error.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';

/// Sales report subscribers for the open store.
class CompanyReportsScreen extends StatefulWidget {
  const CompanyReportsScreen({super.key});

  @override
  State<CompanyReportsScreen> createState() => _CompanyReportsScreenState();
}

class _CompanyReportsScreenState extends State<CompanyReportsScreen> {
  static const _primary = Color(0xFF4A00E0);
  static const _ink = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF6B7280);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _subscribers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = context.read<UiStoreController>();
      final store = controller.store;
      if (store == null) {
        setState(() {
          _error = context.l10n.homeOpenStoreFirst;
          _loading = false;
        });
        return;
      }

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

      final login = controller.organisationLogin;
      final ownerEmail = (login?.email ?? store.contactEmail).trim();
      final ownerName = (login?.customerName ?? context.l10n.companyOwner)
          .trim();
      if (ownerEmail.contains('@')) {
        await store.ensureOwnerReportSubscriber(
          email: ownerEmail,
          name: ownerName,
        );
      }

      final rows = await store.listReportSubscribers();
      if (!mounted) return;
      setState(() {
        _subscribers = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(
          e,
          fallback: context.l10n.companyCouldNotLoadReports,
        );
        _loading = false;
      });
    }
  }

  Future<void> _addSubscriber() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    var cadence = 'daily';
    var notificationType = 'email';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                context.l10n.companyAddSubscriber,
                style: FontUtility.heading.copyWith(fontSize: 22, color: _ink),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: context.l10n.commonName,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: context.l10n.commonEmail,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: notificationType,
                      decoration: InputDecoration(
                        labelText: context.l10n.companyChannel,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'email',
                          child: Text(context.l10n.commonEmail),
                        ),
                        DropdownMenuItem(
                          value: 'slack',
                          child: Text(context.l10n.companyChannelSlack),
                        ),
                        DropdownMenuItem(
                          value: 'whatsapp',
                          child: Text(context.l10n.companyChannelWhatsApp),
                        ),
                        DropdownMenuItem(
                          value: 'sms',
                          child: Text(context.l10n.companyChannelSms),
                        ),
                        DropdownMenuItem(
                          value: 'push',
                          child: Text(context.l10n.companyChannelPush),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => notificationType = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: cadence,
                      decoration: InputDecoration(
                        labelText: context.l10n.companyPeriodicity,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'daily',
                          child: Text(context.l10n.companyPeriodDaily),
                        ),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text(context.l10n.commonWeekly),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text(context.l10n.commonMonthly),
                        ),
                        DropdownMenuItem(
                          value: 'annually',
                          child: Text(context.l10n.companyPeriodAnnually),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => cadence = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.l10n.actionCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: _primary),
                  child: Text(context.l10n.actionAdd),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return;
    try {
      final store = context.read<UiStoreController>().store;
      if (store == null) return;
      await store.addReportSubscriber(
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        cadence: cadence,
        notificationType: notificationType,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(
              e,
              fallback: context.l10n.companyCouldNotAddSubscriber,
            ),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    final id = (row['id'] as num?)?.toInt();
    if (id == null) return;
    if (((row['is_owner_default'] as num?)?.toInt() ?? 0) == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.companyOwnerSubscriberLocked)),
      );
      return;
    }
    try {
      await context.read<UiStoreController>().store?.deleteReportSubscriber(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0.5,
        title: Text(
          context.l10n.commonReports,
          style: FontUtility.heading.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        actions: [
          Tooltip(
            message: context.l10n.actionRefresh,
            child: Semantics(
              label: context.l10n.actionRefresh,
              button: true,
              child: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Tooltip(
        message: context.l10n.companyAddSubscriber,
        child: Semantics(
          label: context.l10n.companyAddSubscriber,
          button: true,
          child: FloatingActionButton(
            onPressed: _addSubscriber,
            backgroundColor: _primary,
            child: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: FontUtility.body.copyWith(color: Colors.red.shade700),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.companySystemMailerLocked,
                              style: FontUtility.body.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              PosReportMailerDefaults.fromEmail,
                              style: FontUtility.body.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            Text(
                              PosReportMailerDefaults.host,
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
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.companySubscribers,
                  style: FontUtility.heading.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 12),
                if (_subscribers.isEmpty)
                  Text(
                    context.l10n.companyNoSubscribersYet,
                    style: FontUtility.body.copyWith(color: _muted),
                  )
                else
                  ..._subscribers.map((row) {
                    final owner =
                        ((row['is_owner_default'] as num?)?.toInt() ?? 0) == 1;
                    final cadence =
                        '${row['periodicity'] ?? row['cadence'] ?? 'daily'}';
                    final channel = '${row['notification_type'] ?? 'email'}';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${row['name'] ?? ''}',
                                  style: FontUtility.body.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: _ink,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${row['email'] ?? ''}',
                                  style: FontUtility.body.copyWith(
                                    color: _muted,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$channel · $cadence'
                                  '${owner ? ' · ${context.l10n.commonOwner}' : ''}',
                                  style: FontUtility.body.copyWith(
                                    color: _primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!owner)
                            Tooltip(
                              message: context.l10n.actionDelete,
                              child: Semantics(
                                label: context.l10n.actionDelete,
                                button: true,
                                child: IconButton(
                                  onPressed: () => _remove(row),
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
