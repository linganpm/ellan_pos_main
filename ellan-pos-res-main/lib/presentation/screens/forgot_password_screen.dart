import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/localization/l10n/app_localizations.dart';
import '../../core/utils/font_utility.dart';
import '../../bloc/forgot_password/forgot_password_cubit.dart';
import '../../bloc/forgot_password/forgot_password_state.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ForgotPasswordCubit(),
      child: Scaffold(
        body: Row(
          children: [
            // Left Side - Branding / Graphic (Same as Welcome/SignIn)
            Expanded(
              flex: 1,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF8E2DE2),
                      Color(0xFF4A00E0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.insights_rounded,
                          size: 80,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          AppLocalizations.of(context)!.welcomeUnlockBusiness,
                          style: FontUtility.heading.copyWith(
                            color: Colors.white,
                            fontSize: 42,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          AppLocalizations.of(context)!.welcomeDescription,
                          style: FontUtility.body.copyWith(
                            color: Colors.white70,
                            fontSize: 18,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Right Side - Forgot Password Action Area
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60.0),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: BlocConsumer<ForgotPasswordCubit, ForgotPasswordState>(
                        listener: (context, state) {
                          if (state.isSuccess) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(context)!.forgotPasswordSuccess,
                                  style: FontUtility.body.copyWith(color: Colors.white),
                                ),
                                backgroundColor: Colors.green.shade600,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                            // Navigate back after delay
                            Future.delayed(const Duration(seconds: 2), () {
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            });
                          }
                        },
                        builder: (context, state) {
                          return SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.forgotPasswordTitle,
                                  textAlign: TextAlign.center,
                                  style: FontUtility.heading.copyWith(
                                    color: const Color(0xFF333333),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  AppLocalizations.of(context)!.forgotPasswordInstruction,
                                  textAlign: TextAlign.center,
                                  style: FontUtility.body.copyWith(
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 48),
                                if (state.errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            state.errorMessage!,
                                            style: FontUtility.body.copyWith(color: Colors.red.shade700, fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F6F8),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: TextField(
                                    onChanged: (value) => context.read<ForgotPasswordCubit>().identifierChanged(value),
                                    decoration: InputDecoration(
                                      hintText: AppLocalizations.of(context)!.signInEmailPhone,
                                      hintStyle: FontUtility.body.copyWith(color: Colors.black38),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF4A00E0), width: 2),
                                      ),
                                    ),
                                    style: FontUtility.body,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Container(
                                  width: double.infinity,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: state.isValid && !state.isLoading && !state.isSuccess
                                        ? const LinearGradient(
                                            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          )
                                        : null,
                                    color: state.isValid && !state.isLoading && !state.isSuccess ? null : Colors.grey.shade300,
                                    boxShadow: state.isValid && !state.isLoading && !state.isSuccess
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF4A00E0).withOpacity(0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: state.isValid && !state.isLoading && !state.isSuccess
                                          ? () => context.read<ForgotPasswordCubit>().submit()
                                          : null,
                                      child: Center(
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 300),
                                          child: state.isLoading
                                              ? const SizedBox(
                                                  height: 24,
                                                  width: 24,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2.5,
                                                  ),
                                                )
                                              : state.isSuccess 
                                                ? const Icon(Icons.check, color: Colors.white, size: 28)
                                                : Text(
                                                    AppLocalizations.of(context)!.forgotPasswordSendLink,
                                                    style: FontUtility.button.copyWith(
                                                      color: state.isValid ? Colors.white : Colors.grey.shade500,
                                                    ),
                                                  ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (!state.isLoading) {
                                        Navigator.pop(context);
                                      }
                                    },
                                    child: Text(
                                      AppLocalizations.of(context)!.forgotPasswordBackToSignIn,
                                      style: FontUtility.body.copyWith(
                                        color: const Color(0xFF4A00E0),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
