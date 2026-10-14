import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/device_approval.dart';
import '../../core/device_setup_store.dart';
import '../../core/di/service_locator.dart';
import '../../core/localization/l10n_context.dart';
import '../../core/support_contact.dart';
import '../../core/utils/font_utility.dart';

const _accent = Color(0xFF4A00E0);

/// Headset icon that opens the customer support card.
class CustomerSupportButton extends StatelessWidget {
  final Color? color;
  final bool filled;

  const CustomerSupportButton({super.key, this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.support_agent_rounded,
      color: color ?? _accent,
      size: filled ? 22 : 24,
    );
    void onPressed() => showCustomerSupport(context);
    if (!filled) {
      return IconButton(
        tooltip: context.l10n.supportTitle,
        onPressed: onPressed,
        icon: icon,
      );
    }
    return Tooltip(
      message: context.l10n.supportTitle,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(padding: const EdgeInsets.all(12), child: icon),
        ),
      ),
    );
  }
}

Future<void> showCustomerSupport(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _CustomerSupportDialog(),
  );
}

class _CustomerSupportDialog extends StatefulWidget {
  const _CustomerSupportDialog();

  @override
  State<_CustomerSupportDialog> createState() => _CustomerSupportDialogState();
}

class _CustomerSupportDialogState extends State<_CustomerSupportDialog> {
  late final SharedPreferences _prefs = getIt<SharedPreferences>();
  late final SupportContactService _service = SupportContactService(_prefs);
  late SupportContact? _contact = _service.cached;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service.load().then((contact) {
      if (!mounted) return;
      setState(() {
        _contact = contact;
        _loading = false;
      });
    });
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(context.l10n.supportCopied(value)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final contact = _contact;
    final companyCode =
        DeviceSetupStore(_prefs).activeOrgInstanceId ??
        _prefs.getString(DeviceSetupStore.orgCodeKey) ??
        '';
    final rows = <Widget>[
      if (contact != null) ...[
        if (contact.email.isNotEmpty)
          _ContactRow(
            icon: Icons.mail_outline_rounded,
            label: l10n.supportEmail,
            value: contact.email,
            actionLabel: l10n.supportEmailAction,
            uri: Uri(scheme: 'mailto', path: contact.email),
            onCopy: _copy,
          ),
        if (contact.whatsapp.isNotEmpty)
          _ContactRow(
            icon: Icons.chat_rounded,
            label: l10n.supportWhatsapp,
            value: contact.whatsapp,
            actionLabel: l10n.supportWhatsappAction,
            uri: Uri.parse(
              'https://wa.me/${contact.whatsapp.replaceAll(RegExp(r'[^0-9]'), '')}',
            ),
            onCopy: _copy,
          ),
      ],
    ];

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: _accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.supportTitle,
                          style: FontUtility.heading.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (contact?.name ?? '').isNotEmpty
                              ? contact!.name
                              : l10n.supportSubtitle,
                          style: FontUtility.body.copyWith(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (rows.isNotEmpty)
                ...rows
              else if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                )
              else
                Text(
                  l10n.supportNotConfigured,
                  style: FontUtility.body.copyWith(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.supportShareHint,
                      style: FontUtility.body.copyWith(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ReferenceLine(
                      label: l10n.supportDeviceId,
                      value: posDeviceId(_prefs),
                      onCopy: _copy,
                    ),
                    if (companyCode.trim().isNotEmpty)
                      _ReferenceLine(
                        label: l10n.supportCompany,
                        value: companyCode.trim(),
                        onCopy: _copy,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.actionClose),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String actionLabel;
  final Uri uri;
  final ValueChanged<String> onCopy;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.actionLabel,
    required this.uri,
    required this.onCopy,
  });

  Future<void> _open() async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    // No mail app / browser on the tablet: still hand over the details.
    if (!opened) onCopy(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: _accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: FontUtility.body.copyWith(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                      SelectableText(
                        value,
                        style: FontUtility.body.copyWith(
                          color: const Color(0xFF1F2937),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).copyButtonLabel,
                  onPressed: () => onCopy(value),
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: Colors.black38,
                  ),
                ),
                FilledButton(
                  onPressed: _open,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceLine extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onCopy;

  const _ReferenceLine({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onCopy(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(
              '$label: ',
              style: FontUtility.body.copyWith(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: FontUtility.body.copyWith(
                  color: const Color(0xFF374151),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.copy_rounded, size: 14, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
