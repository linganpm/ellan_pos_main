import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/user/user_bloc.dart';
import '../../bloc/user/user_event.dart';
import '../../bloc/user/user_state.dart';
import '../../core/routes.dart';
import '../../core/utils/font_utility.dart';
import '../../core/utils/user_facing_error.dart';
import '../../core/localization/l10n_context.dart';
import '../widgets/pos_brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Start splash bloc loading
    // Dispatch user initialization event
    context.read<UserBloc>().add(UserInitializeEvent());

    // Setup micro-animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserBloc, UserState>(
      listener: (context, state) {
        if (state is UserLoaded) {
          // Navigate to Home screen when user is loaded
          Future.delayed(Duration(seconds: 2), () {
            Navigator.pushReplacementNamed(context, AppRoutes.home);
          });
        } else if (state is UserNeedsStaffUnlock) {
          if (state.leaseExpired) {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          } else {
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.staffLock,
              arguments: {
                'storeId': state.storeId,
                'storeName': state.storeName,
              },
            );
          }
        } else if (state is UserError) {
          if (state.message.startsWith(deviceNotApprovedPrefix)) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                title: Text(context.l10n.splashDeviceNotApproved),
                content: Text(
                  state.message
                      .substring(deviceNotApprovedPrefix.length)
                      .trim(),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      context.read<UserBloc>().add(UserInitializeEvent());
                    },
                    child: Text(context.l10n.splashCheckAgain),
                  ),
                ],
              ),
            );
          } else if (state.message.contains(context.l10n.splashNoOrgCode) ||
              state.message.contains(context.l10n.splashNoConfig)) {
            Navigator.pushReplacementNamed(context, AppRoutes.authEntry);
          } else if (state.message.contains(context.l10n.splashPleaseSignIn)) {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          } else {
            final networkIssue = isNetworkConnectivityError(state.message);
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                title: Text(
                  networkIssue
                      ? context.l10n.errorNetwork
                      : context.l10n.splashInitError,
                ),
                content: Text(state.message),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    },
                    child: Text(context.l10n.actionSignIn),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      context.read<UserBloc>().add(UserInitializeEvent());
                    },
                    child: Text(context.l10n.actionRetry),
                  ),
                ],
              ),
            );
          }
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PosBrandLogo(size: 180),
                    const SizedBox(height: 32),
                    Text(
                      context.l10n.authEntryBrand,
                      style: FontUtility.heading.copyWith(
                        color: Colors.white,
                        fontSize: 48,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 48),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
