import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/company_device_setup.dart';
import '../../core/controllers/ui_store_controller.dart';
import '../../core/di/service_locator.dart';
import '../../core/localization/l10n/app_localizations.dart';
import 'splash_screen.dart';
import '../../core/localization/l10n_context.dart';
import '../../core/utils/font_utility.dart';
import '../../bloc/sign_in/sign_in_cubit.dart';
import '../../bloc/sign_in/sign_in_state.dart';
import 'forgot_password_screen.dart';
import 'package:pos_tablet/presentation/widgets/customer_support.dart';
import 'package:pos_tablet/presentation/widgets/pin_pad.dart';
import '../../core/routes.dart';
import '../widgets/pos_brand_logo.dart';

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
        final hint = companyIdentifierHint?.trim() ?? '';
        cubit.companyCodeChanged(
          hint.isNotEmpty ? hint : cubit.cachedCompanyCode,
        );
        return cubit;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5F9),
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    child: BlocConsumer<SignInCubit, SignInState>(
                      listenWhen: (prev, next) =>
                          prev.isSuccess != next.isSuccess ||
                          prev.needsPinSetup != next.needsPinSetup,
                      listener: (context, state) async {
                        if (state.needsPinSetup && !state.isSuccess) {
                          final cubit = context.read<SignInCubit>();
                          await showCreatePinDialog(
                            context,
                            onSubmit: cubit.createPin,
                          );
                          cubit.pinSetupCompleted();
                          return;
                        }
                        if (state.isSuccess) {
                          if (state.navigateToHome) {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.home,
                            );
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
                                    companyIdentifierHint:
                                        companyIdentifierHint,
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
              const Positioned(
                top: 16,
                right: 16,
                child: CustomerSupportButton(filled: true),
              ),
              const Positioned(
                right: 16,
                bottom: 12,
                child: _ResetLocalDataButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _danger = Color(0xFFD92D20);

/// Modern destructive confirmation used by reset and switch-company.
Future<bool> _confirmDestructive(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String body,
  required String actionLabel,
  bool caution = false,
}) async {
  final confirmController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final typed = confirmController.text.trim().toUpperCase() == 'RESET';
        return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _danger, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: FontUtility.heading.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 10),
              if (caution) ...[
                Text(
                  Localizations.localeOf(context).languageCode == 'ta'
                      ? 'எச்சரிக்கை'
                      : 'Caution',
                  textAlign: TextAlign.center,
                  style: FontUtility.body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _danger,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                body,
                textAlign: TextAlign.center,
                style: FontUtility.body.copyWith(
                  fontSize: caution ? 16 : 14,
                  height: 1.45,
                  fontWeight: caution ? FontWeight.w700 : FontWeight.w500,
                  color: caution
                      ? const Color(0xFF1F2937)
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.deviceTypeResetConfirm,
                textAlign: TextAlign.center,
                style: FontUtility.body.copyWith(
                  fontSize: caution ? 15 : 13,
                  fontWeight: caution ? FontWeight.w700 : FontWeight.w500,
                  color: caution
                      ? const Color(0xFF1F2937)
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'RESET'),
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          side: const BorderSide(color: Color(0xFFD0D5DD)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          context.l10n.actionCancel,
                          style: FontUtility.button.copyWith(
                            color: const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: typed
                            ? () => Navigator.pop(dialogContext, true)
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _danger,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          actionLabel,
                          style: FontUtility.button.copyWith(
                            color: Colors.white,
                          ),
                        ),
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
      },
    ),
  );
  confirmController.dispose();
  return confirmed == true;
}

/// Wipes cached databases, company setup and settings. Device identity and
/// language are kept. Returns false (after showing a snackbar) on failure.
Future<bool> _resetLocalData(BuildContext context) async {
  try {
    await getIt<UiStoreController>().resetAllLocalData(
      keepSavedServers: false,
      preserveKeys: kDevicePreservedPrefKeys,
    );
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.deviceResetFailed(error.toString())),
        ),
      );
    }
    return false;
  }
}

class _ResetLocalDataButton extends StatefulWidget {
  const _ResetLocalDataButton();

  @override
  State<_ResetLocalDataButton> createState() => _ResetLocalDataButtonState();
}

class _ResetLocalDataButtonState extends State<_ResetLocalDataButton> {
  bool _resetting = false;

  Future<void> _confirmAndReset() async {
    final confirmed = await _confirmDestructive(
      context,
      icon: Icons.restart_alt_rounded,
      title: context.l10n.deviceResetConfirmTitle,
      body: context.l10n.deviceResetConfirmBody,
      actionLabel: context.l10n.deviceResetAction,
    );
    if (!confirmed || !mounted) return;

    setState(() => _resetting = true);
    final ok = await _resetLocalData(context);
    if (!mounted) return;
    if (!ok) {
      setState(() => _resetting = false);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.deviceResetAllLocal,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _resetting ? null : _confirmAndReset,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: _resetting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: _danger,
                      ),
                    )
                  : Icon(
                      Icons.restart_alt_rounded,
                      color: _danger,
                      size: 24,
                      semanticLabel: context.l10n.deviceResetAllLocal,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only company the device is bound to, with a switch action that
/// resets the device (switching company always needs a clean device).
class _CompanyCard extends StatefulWidget {
  const _CompanyCard({required this.code, required this.name});

  final String code;
  final String name;

  @override
  State<_CompanyCard> createState() => _CompanyCardState();
}

class _CompanyCardState extends State<_CompanyCard> {
  bool _switching = false;

  Future<void> _confirmAndSwitch() async {
    final confirmed = await _confirmDestructive(
      context,
      icon: Icons.swap_horiz_rounded,
      title: context.l10n.signInSwitchCompanyTitle,
      body: context.l10n.signInSwitchCompanyBody,
      actionLabel: context.l10n.signInSwitchCompanyAction,
      caution: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _switching = true);
    final ok = await _resetLocalData(context);
    if (!mounted) return;
    if (!ok) {
      setState(() => _switching = false);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasName =
        widget.name.isNotEmpty &&
        widget.name.toLowerCase() != widget.code.toLowerCase();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4DBFF), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: SignInScreen._primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.business_rounded,
              color: SignInScreen._primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasName ? widget.name : widget.code,
                  overflow: TextOverflow.ellipsis,
                  style: FontUtility.body.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasName
                      ? '${context.l10n.signupCompanyIdentifier} · ${widget.code}'
                      : context.l10n.signupCompanyIdentifier,
                  overflow: TextOverflow.ellipsis,
                  style: FontUtility.body.copyWith(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: context.l10n.signInSwitchCompany,
            child: IconButton(
              onPressed: _switching ? null : _confirmAndSwitch,
              icon: _switching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Icon(
                      Icons.swap_horiz_rounded,
                      color: SignInScreen._primary,
                      semanticLabel: context.l10n.signInSwitchCompany,
                    ),
            ),
          ),
        ],
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
  late final TextEditingController _companyController;
  late final TextEditingController _identifierController;

  /// Company already bound to this device; changing it requires a reset.
  late final String _boundCompanyCode;
  late final String _boundCompanyName;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<SignInCubit>();
    _boundCompanyCode = cubit.cachedCompanyCode.trim();
    _boundCompanyName = cubit.cachedCompanyName;
    _companyController = TextEditingController(text: cubit.state.companyCode);
    _identifierController = TextEditingController(
      text: widget.initialIdentifier?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _companyController.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _signIn(BuildContext context) async {
    final cubit = context.read<SignInCubit>();
    if (cubit.deviceSyncedToAnotherCompany(cubit.state.companyCode)) {
      final confirmed = await _confirmDestructive(
        context,
        icon: Icons.swap_horiz_rounded,
        title: context.l10n.signInSwitchCompanyTitle,
        body: context.l10n.signInSwitchCompanyBody,
        actionLabel: context.l10n.signInSwitchCompanyAction,
        caution: true,
      );
      if (!confirmed || !context.mounted) return;
    }
    await cubit.submit();
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
              const Center(child: PosBrandLogo(size: 112)),
              const SizedBox(height: 16),
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
              if (_boundCompanyCode.isNotEmpty)
                _CompanyCard(code: _boundCompanyCode, name: _boundCompanyName)
              else
                TextField(
                  controller: _companyController,
                  onChanged: (value) =>
                      context.read<SignInCubit>().companyCodeChanged(value),
                  textInputAction: TextInputAction.next,
                  style: FontUtility.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                  decoration: widget.fieldDecoration(
                    context.l10n.signupCompanyIdentifier,
                    suffixIcon: const Icon(Icons.business_rounded),
                  ),
                ),
              const SizedBox(height: 14),
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
                      ? () => _signIn(context)
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
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
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
