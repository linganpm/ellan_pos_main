import 'package:flutter/material.dart';

import '../../core/store_trade_modes.dart';
import '../../core/utils/font_utility.dart';
import 'order_list_screen.dart';

class OrdersHubScreen extends StatelessWidget {
  const OrdersHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final modes = StoreTradeModes.current();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Orders',
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              children: [
                if (modes.sell)
                  Expanded(
                    child: _OrderFlowCard(
                      title: 'Sales',
                      subtitle: 'Customer sales orders',
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFF178A45),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SalesListScreen(),
                        ),
                      ),
                    ),
                  ),
                if (modes.both) const SizedBox(width: 28),
                if (modes.buy)
                  Expanded(
                    child: _OrderFlowCard(
                      title: 'Purchases',
                      subtitle: 'கொள்முதல் · Supplier buy orders',
                      icon: Icons.trending_down_rounded,
                      color: const Color(0xFFD32F2F),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PurchasesListScreen(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderFlowCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _OrderFlowCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      elevation: 8,
      shadowColor: color.withValues(alpha: 0.28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 72, color: Colors.white),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: FontUtility.heading.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: FontUtility.body.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
