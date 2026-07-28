import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/device_setup_store.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/org_timezone.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live organisation clock with org currency + timezone for the home AppBar.
///
/// Shows only configured org currency and timezone — never invents `$` / USD.
class OrgLocalClockBadge extends StatefulWidget {
  const OrgLocalClockBadge({super.key});

  @override
  State<OrgLocalClockBadge> createState() => _OrgLocalClockBadgeState();
}

class _OrgLocalClockBadgeState extends State<OrgLocalClockBadge> {
  Timer? _timer;
  String _clock = '';
  String _currency = '';
  String _timezoneLabel = '';

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    final prefs = getIt<SharedPreferences>();
    final setup = DeviceSetupStore(prefs);
    final storeId = getIt<UiStoreController>().store?.storeId;
    final tzName = setup.timezoneForStore(storeId);
    final currencyMeta = setup.currencyMetaForStore(storeId);
    final clock = OrgTimezone.formatNowClock(tzName);
    // Symbol when present, else ISO code — never a hard-coded `$`.
    final currency = currencyMeta.symbol.isNotEmpty
        ? currencyMeta.symbol
        : currencyMeta.code;
    final tzLabel = (tzName ?? '').trim();
    final shortTz = tzLabel.contains('/')
        ? tzLabel.split('/').last.replaceAll('_', ' ')
        : tzLabel;

    if (!mounted) return;
    if (clock == _clock &&
        currency == _currency &&
        shortTz == _timezoneLabel) {
      return;
    }
    setState(() {
      _clock = clock;
      _currency = currency;
      _timezoneLabel = shortTz;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_clock.isEmpty && _currency.isEmpty && _timezoneLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    final tooltip = [
      if (_currency.isNotEmpty) _currency,
      if (_timezoneLabel.isNotEmpty) _timezoneLabel,
      'Organisation time',
    ].join(' · ');

    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF4A00E0).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF4A00E0).withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currency.isNotEmpty) ...[
              Text(
                _currency,
                style: FontUtility.body.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF2D1B69),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (_clock.isNotEmpty)
              Text(
                _clock,
                style: FontUtility.body.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D1B69),
                  letterSpacing: 0.2,
                ),
              ),
            if (_timezoneLabel.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                _timezoneLabel,
                style: FontUtility.body.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
