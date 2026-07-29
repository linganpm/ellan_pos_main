import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/pos_report_mailer_defaults.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/core/utils/user_facing_error.dart';

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
  List<Map<String, dynamic>> _subscribers = const [];

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
          _error = 'Open a store first.';
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
      final ownerName = (login?.customerName ?? 'Owner').trim();
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
        _error = userFacingError(e, fallback: 'Could not load reports.');
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
                'Add subscriber',
                style: FontUtility.heading.copyWith(fontSize: 22, color: _ink),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: notificationType,
                      decoration: const InputDecoration(
                        labelText: 'Channel',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'email', child: Text('Email')),
                        DropdownMenuItem(value: 'slack', child: Text('Slack')),
                        DropdownMenuItem(
                            value: 'whatsapp', child: Text('WhatsApp')),
                        DropdownMenuItem(value: 'sms', child: Text('SMS')),
                        DropdownMenuItem(value: 'push', child: Text('Push')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => notificationType = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: cadence,
                      decoration: const InputDecoration(
                        labelText: 'Periodicity',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(
                            value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(
                            value: 'monthly', child: Text('Monthly')),
                        DropdownMenuItem(
                            value: 'annually', child: Text('Annually')),
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
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: _primary),
                  child: const Text('Add'),
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
          content: Text(userFacingError(e, fallback: 'Could not add subscriber.')),
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
        const SnackBar(content: Text('Owner subscriber cannot be removed.')),
      );
      return;
    }
    try {
      await context.read<UiStoreController>().store?.deleteReportSubscriber(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
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
          'Reports',
          style: FontUtility.heading.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubscriber,
        backgroundColor: _primary,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add subscriber'),
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
                          Text(
                            'Sales reports',
                            style: FontUtility.heading.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Daily sales summaries are emailed to every enabled '
                            'subscriber using the system report mailer.',
                            style: FontUtility.body.copyWith(
                              color: _muted,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
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
                                  'System mailer (locked)',
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
                      'Subscribers',
                      style: FontUtility.heading.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_subscribers.isEmpty)
                      Text(
                        'No subscribers yet.',
                        style: FontUtility.body.copyWith(color: _muted),
                      )
                    else
                      ..._subscribers.map((row) {
                        final owner =
                            ((row['is_owner_default'] as num?)?.toInt() ?? 0) ==
                                1;
                        final cadence =
                            '${row['periodicity'] ?? row['cadence'] ?? 'daily'}';
                        final channel =
                            '${row['notification_type'] ?? 'email'}';
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
                                      '${owner ? ' · owner' : ''}',
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
                                IconButton(
                                  onPressed: () => _remove(row),
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.red.shade600,
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
