import 'package:flutter/material.dart';

import '../../core/constants/discovery_constants.dart';
import '../../core/routes.dart';
import '../../core/utils/font_utility.dart';

/// First-run chooser: sign in to an existing company, or create a new one.
class AuthEntryScreen extends StatelessWidget {
  const AuthEntryScreen({super.key});

  static const _primary = Color(0xFF4A00E0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.point_of_sale_rounded,
                      size: 72,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'NexPOS',
                      style: FontUtility.heading.copyWith(
                        color: Colors.white,
                        fontSize: 44,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sign in to an existing company, or set up a new company on this device.',
                      style: FontUtility.body.copyWith(
                        color: Colors.white70,
                        fontSize: 18,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Server  ·  $kDefaultServerOrigin',
                      style: FontUtility.body.copyWith(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Root org  ·  $kDefaultRootOrgInstanceId',
                      style: FontUtility.body.copyWith(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: Colors.white,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Get started',
                          style: FontUtility.heading.copyWith(
                            fontSize: 32,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Choose how you want to continue on this tablet.',
                          style: FontUtility.body.copyWith(
                            color: Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 36),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.login,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Sign in',
                              style: FontUtility.button.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.onboarding,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: _primary,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Company setup',
                              style: FontUtility.button.copyWith(
                                color: _primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.joinExisting,
                            );
                          },
                          child: Text(
                            'Join an existing organisation device',
                            style: FontUtility.body.copyWith(
                              color: _primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
