import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/l10n/app_localizations.dart';
import '../../core/localization/l10n_context.dart';
import '../../core/utils/font_utility.dart';
import '../../bloc/sign_in/sign_in_cubit.dart';
import '../../bloc/sign_in/sign_in_state.dart';
import 'forgot_password_screen.dart';
import '../../core/routes.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({
    super.key,
    this.initialIdentifier,
    this.companyIdentifierHint,
  });

  final String? initialIdentifier;
  final String? companyIdentifierHint;

  static const _primary = Color(0xFF4A00E0);

  InputDecoration _fieldDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: FontUtility.body.copyWith(
        color: Colors.black38,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      filled: true,
      fillColor: const Color(0xFFF7F8FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD), width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD), width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 2.5),
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = SignInCubit(prefs: context.read<SharedPreferences>());
        final seed = initialIdentifier?.trim() ?? '';
        if (seed.isNotEmpty) {
          cubit.identifierChanged(seed);
        }
        return cubit;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5F9),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: BlocConsumer<SignInCubit, SignInState>(
                  listener: (context, state) {
                    if (state.isSuccess) {
                      if (state.navigateToHome) {
                        Navigator.pushReplacementNamed(context, AppRoutes.home);
                      } else {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.storeList,
                        );
                      }
                    }
                  },
                  builder: (context, state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: context.l10n.actionBack,
                            onPressed: () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              } else {
                                Navigator.pushReplacementNamed(
                                  context,
                                  AppRoutes.authEntry,
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: _SignInForm(
                                state: state,
                                fieldDecoration: _fieldDecoration,
                                companyIdentifierHint: companyIdentifierHint,
                                initialIdentifier: initialIdentifier,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInForm extends StatefulWidget {
  const _SignInForm({
    required this.state,
    required this.fieldDecoration,
    this.companyIdentifierHint,
    this.initialIdentifier,
  });

  final SignInState state;
  final InputDecoration Function(String hint, {Widget? suffixIcon})
  fieldDecoration;
  final String? companyIdentifierHint;
  final String? initialIdentifier;

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  late final TextEditingController _identifierController;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(
      text: widget.initialIdentifier?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 32, 36, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context)!.signInWelcome,
                textAlign: TextAlign.center,
                style: FontUtility.heading.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2937),
                ),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: FontUtility.body.copyWith(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _identifierController,
                onChanged: (value) =>
                    context.read<SignInCubit>().identifierChanged(value),
                style: FontUtility.body.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
                decoration: widget.fieldDecoration(
                  context.l10n.signInIdentifierHint,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) =>
                    context.read<SignInCubit>().passwordChanged(value),
                obscureText: state.obscurePassword,
                style: FontUtility.body.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
                decoration: widget.fieldDecoration(
                  context.l10n.signInPassword,
                  suffixIcon: IconButton(
                    onPressed: () =>
                        context.read<SignInCubit>().togglePasswordVisibility(),
                    icon: Icon(
                      state.obscurePassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: Text(
                    AppLocalizations.of(context)!.signInForgotPasswordPrompt,
                    style: FontUtility.body.copyWith(
                      color: SignInScreen._primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: state.isValid && !state.isLoading
                      ? () => context.read<SignInCubit>().submit()
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SignInScreen._primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          AppLocalizations.of(context)!.signInButton,
                          style: FontUtility.button.copyWith(
                            color: state.isValid
                                ? Colors.white
                                : Colors.grey.shade500,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.signInNewCompany,
                    style: FontUtility.body.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextButton(
                    onPressed: state.isLoading
                        ? null
                        : () {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.onboarding,
                            );
                          },
                    child: Text(
                      context.l10n.actionSignUp,
                      style: FontUtility.body.copyWith(
                        color: SignInScreen._primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
