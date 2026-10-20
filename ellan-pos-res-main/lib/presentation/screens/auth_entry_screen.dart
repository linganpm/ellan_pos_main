import 'package:flutter/material.dart';

import '../../core/constants/discovery_constants.dart';
import '../../core/localization/l10n_context.dart';
import '../../core/routes.dart';
import '../../core/utils/font_utility.dart';
import '../widgets/pos_brand_logo.dart';

/// First-run chooser: sign in to an existing company, or create a new one.
class AuthEntryScreen extends StatelessWidget {
  const AuthEntryScreen({super.key});

  static const _primary = Color(0xFF4A00E0);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                    const PosBrandLogo(size: 72),
                    const SizedBox(height: 28),
                    Text(
                      l10n.authEntryBrand,
                      style: FontUtility.heading.copyWith(
                        color: Colors.white,
                        fontSize: 44,
                      ),
                    ),
                    if (!kIsPosDiscoveryConfiguredByEnv) ...[
                      const SizedBox(height: 28),
                      Text(
                        '${l10n.welcomeServerUrl}  ·  $kDefaultServerOrigin',
                        style: FontUtility.body.copyWith(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${l10n.welcomeOrgInstanceId}  ·  $kDefaultRootOrgInstanceId',
                        style: FontUtility.body.copyWith(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
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
                          l10n.authEntryTitle,
                          style: FontUtility.heading.copyWith(
                            fontSize: 32,
                            color: const Color(0xFF1A1A2E),
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
                              l10n.actionSignIn,
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
                              side: const BorderSide(color: _primary, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              l10n.authEntryCompanySetup,
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
                            l10n.authEntryJoinExisting,
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
