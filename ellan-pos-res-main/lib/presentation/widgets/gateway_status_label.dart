import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pos_tablet/core/network_reachability.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';

import '../../core/localization/l10n_context.dart';

/// Small Online / Offline label for the top of the screen.
class GatewayStatusLabel extends StatefulWidget {
  const GatewayStatusLabel({super.key});

  @override
  State<GatewayStatusLabel> createState() => _GatewayStatusLabelState();
}

class _GatewayStatusLabelState extends State<GatewayStatusLabel>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool? _online;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _probe();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _probe());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _probe();
  }

  Future<void> _probe() async {
    final online = await NetworkReachability.canReachGateway(
      timeout: const Duration(seconds: 2),
    );
    if (!mounted || online == _online) return;
    setState(() => _online = online);
  }

  @override
  Widget build(BuildContext context) {
    final online = _online;
    if (online == null) return const SizedBox.shrink();
    final color = online ? const Color(0xFF128A3E) : const Color(0xFFB42318);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          online ? context.l10n.commonOnline : context.l10n.commonOffline,
          style: FontUtility.body.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
