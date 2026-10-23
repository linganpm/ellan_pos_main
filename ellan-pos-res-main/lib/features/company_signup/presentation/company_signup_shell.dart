import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../bloc/language/language_bloc.dart';
import '../../../bloc/language/language_event.dart';
import '../../../bloc/language/language_state.dart';
import '../../../core/routes.dart';
import '../../../core/localization/l10n_context.dart';
import '../../../core/constants/discovery_constants.dart';
import '../../../core/utils/font_utility.dart';
import '../../../presentation/widgets/customer_support.dart';
import '../cubit/company_signup_cubit.dart';
import '../cubit/company_signup_state.dart';
import '../data/signup_api.dart';
import 'package:pos_tablet/presentation/widgets/pos_brand_logo.dart';
import 'package:pos_tablet/presentation/widgets/rubber_push.dart';

class CompanySignupShell extends StatelessWidget {
  const CompanySignupShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          CompanySignupCubit(prefs: context.read<SharedPreferences>()),
      child: const _SignupView(),
    );
  }
}

class _SignupView extends StatefulWidget {
  const _SignupView();

  @override
  State<_SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<_SignupView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _askForLanguagePreference();
    });
  }

  Future<void> _askForLanguagePreference() async {
    final prefs = context.read<SharedPreferences>();
    if (prefs.containsKey(LanguageBloc.localePreferenceKey) || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(
            Icons.language_rounded,
            color: Color(0xFF4A00E0),
            size: 36,
          ),
          title: Text(context.l10n.signupChooseLanguage),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () {
                context.read<LanguageBloc>().add(
                  ChangeLanguageEvent(const Locale('en')),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('English'),
            ),
            FilledButton(
              onPressed: () {
                context.read<LanguageBloc>().add(
                  ChangeLanguageEvent(const Locale('ta')),
                );
                Navigator.pop(dialogContext);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A00E0),
              ),
              child: const Text('தமிழ்'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 380,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: BlocBuilder<CompanySignupCubit, CompanySignupState>(
                    builder: (context, state) {
                      final title = switch (state.step) {
                        CompanySignupStep.serverParent ||
                        CompanySignupStep.country =>
                          context.l10n.signupTitleCreateCompany,
                        CompanySignupStep.account => _copy(
                          context,
                          'Account',
                          'கணக்கு',
                        ),
                        CompanySignupStep.verification => _copy(
                          context,
                          'Verification',
                          'சரிபார்ப்பு',
                        ),
                        CompanySignupStep.plan => _copy(
                          context,
                          'Plan',
                          'திட்டம்',
                        ),
                        CompanySignupStep.setup => _copy(
                          context,
                          'Setup',
                          'அமைப்பு',
                        ),
                        CompanySignupStep.progress =>
                          state.isSuccess
                              ? context.l10n.signupTitleReady
                              : context.l10n.signupTitleSettingUp,
                      };
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            size: 56,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            title,
                            style: FontUtility.heading.copyWith(
                              color: Colors.white,
                              fontSize: 34,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 28),
                          const EllantecSiteMark(color: Colors.white),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: ColoredBox(
              color: Colors.white,
              child: Stack(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: BlocBuilder<CompanySignupCubit, CompanySignupState>(
                          builder: (context, state) {
                            return SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (state.errorMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.red.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        state.errorMessage!,
                                        style: FontUtility.body.copyWith(
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_showsJourney(state.step)) ...[
                                    const _SignupJourney(),
                                    const SizedBox(height: 20),
                                  ],
                                  switch (state.step) {
                                    CompanySignupStep.serverParent =>
                                      kIsPosDiscoveryConfiguredByEnv
                                          ? const _ConfiguredEnvironmentSetup()
                                          : const _ServerParentForm(),
                                    CompanySignupStep.country =>
                                      const _CountryStep(),
                                    CompanySignupStep.account =>
                                      const _CompanyDetailsForm(),
                                    CompanySignupStep.verification =>
                                      const _VerificationStep(),
                                    CompanySignupStep.plan => const _PlanStep(),
                                    CompanySignupStep.setup =>
                                      const _BranchDetailsForm(),
                                    CompanySignupStep.progress =>
                                      const _ProgressPanel(),
                                  },
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 24,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CustomerSupportButton(),
                        const SizedBox(width: 4),
                        BlocBuilder<LanguageBloc, LanguageState>(
                          builder: (context, languageState) {
                            return PopupMenuButton<Locale>(
                              tooltip: context.l10n.languageLabel,
                              initialValue: languageState.locale,
                              onSelected: (locale) {
                                context.read<LanguageBloc>().add(
                                  ChangeLanguageEvent(locale),
                                );
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: const Locale('en'),
                                  child: Text(context.l10n.languageEnglish),
                                ),
                                PopupMenuItem(
                                  value: const Locale('ta'),
                                  child: Text(context.l10n.languageTamil),
                                ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F5FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF4A00E0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.language_rounded,
                                      color: Color(0xFF4A00E0),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      languageState.locale.languageCode == 'ta'
                                          ? context.l10n.languageTamil
                                          : context.l10n.languageEnglish,
                                      style: FontUtility.body.copyWith(
                                        color: const Color(0xFF4A00E0),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: Color(0xFF4A00E0),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: FontUtility.body.copyWith(color: Colors.black38),
    floatingLabelBehavior: FloatingLabelBehavior.never,
    filled: true,
    fillColor: const Color(0xFFF7F8FB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    border: PosFields.border,
    enabledBorder: PosFields.border,
    focusedBorder: PosFields.border,
  );
}

Widget _primaryButton({
  required String label,
  required VoidCallback? onPressed,
  bool loading = false,
}) {
  return SizedBox(
    height: 56,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4A00E0),
        disabledBackgroundColor: Colors.grey.shade300,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: FontUtility.button.copyWith(
                color: onPressed == null ? Colors.grey.shade500 : Colors.white,
              ),
            ),
    ),
  );
}

Widget _iconAction({
  required String label,
  required IconData icon,
  required VoidCallback onPressed,
}) {
  return Tooltip(
    message: label,
    child: Semantics(
      label: label,
      button: true,
      child: IconButton(onPressed: onPressed, icon: Icon(icon)),
    ),
  );
}

class _ConfiguredEnvironmentSetup extends StatelessWidget {
  const _ConfiguredEnvironmentSetup();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CompanySignupCubit>().state;
    if (state.isLoadingMeta) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.signupCouldNotPrepare,
          style: FontUtility.body.copyWith(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        _primaryButton(
          label: context.l10n.actionRetry,
          onPressed: () =>
              context.read<CompanySignupCubit>().continueFromServerParent(),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () =>
              Navigator.pushReplacementNamed(context, AppRoutes.login),
          child: Text(context.l10n.signupBackToSignIn),
        ),
      ],
    );
  }
}

class _ServerParentForm extends StatefulWidget {
  const _ServerParentForm();

  @override
  State<_ServerParentForm> createState() => _ServerParentFormState();
}

class _ServerParentFormState extends State<_ServerParentForm> {
  late final TextEditingController _server;
  late final TextEditingController _parent;

  @override
  void initState() {
    super.initState();
    final state = context.read<CompanySignupCubit>().state;
    _server = TextEditingController(text: state.serverUrl);
    _parent = TextEditingController(text: state.parentOrgIdentifier);
  }

  @override
  void dispose() {
    _server.dispose();
    _parent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CompanySignupCubit>();
    final state = context.watch<CompanySignupCubit>().state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RubberPush(
          child: TextField(
            controller: _server,
            keyboardType: TextInputType.url,
            onChanged: cubit.serverUrlChanged,
            decoration: _fieldDecoration(context.l10n.signupServerUrlHint),
          ),
        ),
        const SizedBox(height: 16),
        RubberPush(
          child: TextField(
            controller: _parent,
            onChanged: cubit.parentOrgChanged,
            decoration: _fieldDecoration(context.l10n.signupParentOrgHint),
          ),
        ),
        const SizedBox(height: 28),
        _primaryButton(
          label: context.l10n.actionContinue,
          loading: state.isLoadingMeta,
          onPressed: state.canContinueServerParent && !state.isLoadingMeta
              ? () => cubit.continueFromServerParent()
              : null,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          },
          child: Text(
            context.l10n.signupAlreadyHaveCompany,
            style: FontUtility.body.copyWith(
              color: const Color(0xFF4A00E0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, AppRoutes.joinExisting);
          },
          child: Text(
            context.l10n.signupJoinExistingDevice,
            style: FontUtility.body.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

String _copy(BuildContext context, String english, String tamil) {
  return Localizations.localeOf(context).languageCode == 'ta' ? tamil : english;
}

bool _showsJourney(CompanySignupStep step) {
  return step == CompanySignupStep.account ||
      step == CompanySignupStep.verification ||
      step == CompanySignupStep.plan ||
      step == CompanySignupStep.setup ||
      step == CompanySignupStep.progress;
}

class _SignupJourney extends StatelessWidget {
  const _SignupJourney();

  @override
  Widget build(BuildContext context) {
    final step = context.watch<CompanySignupCubit>().state.step;
    final labels = [
      _copy(context, 'Account', 'கணக்கு'),
      _copy(context, 'Verification', 'சரிபார்ப்பு'),
      _copy(context, 'Plan', 'திட்டம்'),
      _copy(context, 'Setup', 'அமைப்பு'),
      _copy(context, 'Dashboard', 'டாஷ்போர்டு'),
    ];
    final current = switch (step) {
      CompanySignupStep.account => 0,
      CompanySignupStep.verification => 1,
      CompanySignupStep.plan => 2,
      CompanySignupStep.setup => 3,
      CompanySignupStep.progress => 4,
      _ => 0,
    };
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++)
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: index <= current
                      ? const Color(0xFF4A00E0)
                      : const Color(0xFFE5E7EB),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: index <= current ? Colors.white : Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: FontUtility.body.copyWith(
                    fontSize: 11,
                    fontWeight: index == current
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: index == current
                        ? const Color(0xFF4A00E0)
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CountryStep extends StatelessWidget {
  const _CountryStep();

  Future<void> _pick(
    BuildContext context,
    CompanySignupCubit cubit,
    CompanySignupState state,
  ) async {
    final selected = await showModalBottomSheet<SignupCountry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _CountryPickerSheet(
          countries: state.countries,
          selectedId: state.countryId,
        );
      },
    );
    if (selected != null) cubit.countryChanged(selected.id);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CompanySignupCubit>();
    final state = context.watch<CompanySignupCubit>().state;
    final selected = state.selectedCountry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _copy(
            context,
            'Choose your country',
            'உங்கள் நாட்டைத் தேர்ந்தெடுக்கவும்',
          ),
          style: FontUtility.heading.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: state.countries.isEmpty
              ? null
              : () => _pick(context, cubit, state),
          borderRadius: BorderRadius.circular(12),
          child: RubberPush(
            child: InputDecorator(
              decoration: _fieldDecoration(
                selected == null ? context.l10n.signupSelectCountry : '',
              ),
              child: selected == null
                  ? const SizedBox(height: 24)
                  : Row(
                      children: [
                        Text(
                          selected.flag.isNotEmpty ? selected.flag : '',
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selected.name,
                            style: FontUtility.body.copyWith(
                              color: const Color(0xFF1F2937),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            _iconAction(
              label: kIsPosDiscoveryConfiguredByEnv
                  ? context.l10n.signupBackToSignIn
                  : context.l10n.actionBack,
              icon: Icons.arrow_back_rounded,
              onPressed: kIsPosDiscoveryConfiguredByEnv
                  ? () =>
                        Navigator.pushReplacementNamed(context, AppRoutes.login)
                  : cubit.goBack,
            ),
            const Spacer(),
            Expanded(
              flex: 2,
              child: _primaryButton(
                label: context.l10n.actionContinue,
                onPressed: state.countryId.trim().isEmpty
                    ? null
                    : cubit.continueFromCountry,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VerificationStep extends StatelessWidget {
  const _VerificationStep();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CompanySignupCubit>();
    final state = context.watch<CompanySignupCubit>().state;
    final country = state.selectedCountry?.name ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _copy(
            context,
            'No email code is required for $country.',
            '$countryக்கு மின்னஞ்சல் குறியீடு தேவையில்லை.',
          ),
          style: FontUtility.body.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 16),
        Text(
          state.email,
          style: FontUtility.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(state.phoneNumber, style: FontUtility.body),
        const SizedBox(height: 28),
        Row(
          children: [
            _iconAction(
              label: context.l10n.actionBack,
              icon: Icons.arrow_back_rounded,
              onPressed: cubit.goBack,
            ),
            const Spacer(),
            Expanded(
              flex: 2,
              child: _primaryButton(
                label: context.l10n.actionContinue,
                onPressed: cubit.continueFromVerification,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompanyDetailsForm extends StatefulWidget {
  const _CompanyDetailsForm();

  @override
  State<_CompanyDetailsForm> createState() => _CompanyDetailsFormState();
}

class _CompanyDetailsFormState extends State<_CompanyDetailsForm> {
  late final TextEditingController _company;
  late final TextEditingController _owner;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final state = context.read<CompanySignupCubit>().state;
    _company = TextEditingController(text: state.companyName);
    _owner = TextEditingController(text: state.ownerName);
    _email = TextEditingController(text: state.email);
    _phone = TextEditingController(text: state.phoneNumber);
    _password = TextEditingController(text: state.password);
  }

  @override
  void dispose() {
    _company.dispose();
    _owner.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CompanySignupCubit>();
    final state = context.watch<CompanySignupCubit>().state;
    final selected = state.selectedCountry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RubberPush(
          child: TextField(
            controller: _company,
            onChanged: cubit.companyNameChanged,
            decoration: _fieldDecoration(context.l10n.signupCompanyName),
          ),
        ),
        const SizedBox(height: 16),
        RubberPush(
          child: TextField(
            controller: _owner,
            onChanged: cubit.ownerNameChanged,
            decoration: _fieldDecoration(context.l10n.signupOwnerName),
          ),
        ),
        const SizedBox(height: 16),
        RubberPush(
          child: TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            onChanged: cubit.emailChanged,
            decoration: _fieldDecoration(context.l10n.commonEmail),
          ),
        ),
        const SizedBox(height: 16),
        RubberPush(
          child: TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            onChanged: cubit.phoneChanged,
            decoration: _fieldDecoration(
              selected?.dialCode.isNotEmpty == true
                  ? context.l10n.signupPhoneHintWithDial(selected!.dialCode)
                  : context.l10n.signupPhoneHint,
            ),
          ),
        ),
        const SizedBox(height: 16),
        RubberPush(
          child: TextField(
            controller: _password,
            obscureText: _obscure,
            onChanged: cubit.passwordChanged,
            decoration: _fieldDecoration(context.l10n.signupPasswordHint)
                .copyWith(
                  suffixIcon: _iconAction(
                    label: _obscure
                        ? context.l10n.signInShowPassword
                        : context.l10n.commonHideDetails,
                    icon: _obscure ? Icons.visibility_off : Icons.visibility,
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            _iconAction(
              label: kIsPosDiscoveryConfiguredByEnv
                  ? context.l10n.signupBackToSignIn
                  : context.l10n.actionBack,
              icon: Icons.arrow_back_rounded,
              onPressed: kIsPosDiscoveryConfiguredByEnv
                  ? () =>
                        Navigator.pushReplacementNamed(context, AppRoutes.login)
                  : cubit.goBack,
            ),
            const Spacer(),
            Expanded(
              flex: 2,
              child: _primaryButton(
                label: context.l10n.actionContinue,
                onPressed: state.canContinueCompanyDetails
                    ? cubit.continueFromCompanyDetails
                    : null,
              ),
            ),
          ],
        ),
        // The server/parent step (which carries these links) is skipped
        // when discovery comes from .env.
        if (kIsPosDiscoveryConfiguredByEnv) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.login),
            child: Text(
              context.l10n.signupAlreadyHaveCompany,
              style: FontUtility.body.copyWith(
                color: const Color(0xFF4A00E0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.joinExisting),
            child: Text(
              context.l10n.signupJoinExistingDevice,
              style: FontUtility.body.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({
    required this.countries,
    required this.selectedId,
  });

  final List<SignupCountry> countries;
  final String selectedId;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  late final TextEditingController _search;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = widget.countries
        .where((c) {
          if (q.isEmpty) return true;
          return c.name.toLowerCase().contains(q) ||
              c.code.toLowerCase().contains(q) ||
              c.dialCode.toLowerCase().contains(q);
        })
        .toList(growable: false);

    final height = MediaQuery.sizeOf(context).height * 0.75;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: RubberPush(
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: _fieldDecoration(
                  context.l10n.signupSearchCountry,
                ).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.signupNoCountriesMatch(_query),
                      style: FontUtility.body.copyWith(color: Colors.black54),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final country = filtered[index];
                      final selected = country.id == widget.selectedId;
                      return ListTile(
                        leading: Text(
                          country.flag.isNotEmpty ? country.flag : '🏳️',
                          style: const TextStyle(fontSize: 22),
                        ),
                        title: Text(
                          country.name,
                          style: FontUtility.body.copyWith(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (country.code.isNotEmpty) country.code,
                            if (country.dialCode.isNotEmpty) country.dialCode,
                          ].join(' · '),
                          style: FontUtility.body.copyWith(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF4A00E0),
                              )
                            : null,
                        onTap: () => Navigator.pop(context, country),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlanStep extends StatefulWidget {
  const _PlanStep();

  @override
  State<_PlanStep> createState() => _PlanStepState();
}

class _PlanStepState extends State<_PlanStep> {
  final CompanySignupApi _api = CompanySignupApi();
  SignupPricing? _pricing;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final country = context.read<CompanySignupCubit>().state.selectedCountry;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pricing = await _api.fetchPricing(country?.code ?? '');
      if (!mounted) return;
      final cubit = context.read<CompanySignupCubit>();
      if (cubit.state.packageKey.isEmpty && pricing.plans.isNotEmpty) {
        cubit.packageChanged(pricing.plans.first.key);
      }
      if (pricing.currencyCode.isNotEmpty) {
        cubit.planCurrencyChanged(pricing.currencyCode);
      }
      setState(() {
        _pricing = pricing;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  String _priceLabel(SignupPlan plan, String interval, String symbol) {
    if (plan.isFree) return 'Free';
    final yearly = interval == 'yearly' && plan.annualPrice.isNotEmpty;
    final amount = yearly ? plan.annualPrice : plan.price;
    if (amount.isEmpty) return 'Price on request';
    final numeric = RegExp(r'^\d+(?:\.\d+)?$').hasMatch(amount);
    if (!numeric) return amount;
    final suffix = yearly ? '/ year' : plan.priceSuffix;
    return '$symbol$amount${suffix.isEmpty ? '' : ' $suffix'}';
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CompanySignupCubit>();
    final state = context.watch<CompanySignupCubit>().state;
    final plans = _pricing?.plans ?? const <SignupPlan>[];
    final symbol = _pricing?.currencySymbol ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              _copy(context, 'Billing period', 'பில்லிங் காலம்'),
              style: FontUtility.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'monthly',
                  label: Text(_copy(context, 'Monthly', 'மாதாந்திரம்')),
                ),
                ButtonSegment(
                  value: 'yearly',
                  label: Text(_copy(context, 'Annual', 'ஆண்டு')),
                ),
              ],
              selected: {state.billingInterval},
              onSelectionChanged: (value) =>
                  cubit.billingIntervalChanged(value.first),
            ),
          ],
        ),
        if ((_pricing?.currencyCode ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _pricing!.currencyCode,
            style: FontUtility.body.copyWith(color: Colors.black54),
          ),
        ],
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Text(
            _error!,
            style: FontUtility.body.copyWith(color: Colors.red.shade800),
          )
        else if (plans.isEmpty)
          Text(
            _copy(
              context,
              'No prices are available right now.',
              'விலைகள் இப்போது இல்லை.',
            ),
            style: FontUtility.body,
          )
        else
          ...plans.map((plan) {
            final selected = state.packageKey == plan.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => cubit.packageChanged(plan.key),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF4A00E0).withValues(alpha: 0.08)
                        : const Color(0xFFF7F8FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF4A00E0)
                          : const Color(0xFFD0D5DD),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        style: FontUtility.body.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      if (plan.label.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          plan.label,
                          style: FontUtility.body.copyWith(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _priceLabel(plan, state.billingInterval, symbol),
                        style: FontUtility.body.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: const Color(0xFF4A00E0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        Row(
          children: [
            _iconAction(
              label: context.l10n.actionBack,
              icon: Icons.arrow_back_rounded,
              onPressed: cubit.goBack,
            ),
            const Spacer(),
            Expanded(
              flex: 2,
              child: _primaryButton(
                label: context.l10n.actionContinue,
                onPressed:
                    !_loading &&
                        (_error != null ||
                            plans.isEmpty ||
                            state.canContinuePlan)
                    ? cubit.continueFromPlan
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BranchDetailsForm extends StatefulWidget {
  const _BranchDetailsForm();

  @override
  State<_BranchDetailsForm> createState() => _BranchDetailsFormState();
}

class _BranchDetailsFormState extends State<_BranchDetailsForm> {
  late final TextEditingController _branch;
  late final TextEditingController _city;
  late final TextEditingController _reg;

  @override
  void initState() {
    super.initState();
    final state = context.read<CompanySignupCubit>().state;
    _branch = TextEditingController(text: state.branchName);
    _city = TextEditingController(text: state.city);
    _reg = TextEditingController(text: state.registrationNumber);
  }

  @override
  void dispose() {
    _branch.dispose();
    _city.dispose();
    _reg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CompanySignupCubit>();
    final state = context.watch<CompanySignupCubit>().state;
    final types = state.businessTypes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.signupApplicationType,
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 12),
        if (types.isEmpty)
          Text(
            context.l10n.signupBodyBusinessType,
            style: FontUtility.body,
          )
        else
          ...types.map((type) {
            final selected = state.businessType == type.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => cubit.businessTypeChanged(type.id),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF4A00E0).withValues(alpha: 0.08)
                        : const Color(0xFFF7F8FB),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2E1B1433),
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                      BoxShadow(
                        color: Color(0x1A1B1433),
                        offset: Offset(0, 10),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Text(
                    type.label,
                    style: FontUtility.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? const Color(0xFF4A00E0)
                          : const Color(0xFF1F2937),
                    ),
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
        RubberPush(
          child: TextField(
            controller: _branch,
            onChanged: cubit.branchNameChanged,
            decoration: _fieldDecoration(context.l10n.signupBranchName),
          ),
        ),
        const SizedBox(height: 16),
        RubberPush(
          child: TextField(
            controller: _city,
            onChanged: cubit.cityChanged,
            decoration: _fieldDecoration(context.l10n.signupCity),
          ),
        ),
        const SizedBox(height: 16),
        RubberPush(
          child: TextField(
            controller: _reg,
            onChanged: cubit.registrationNumberChanged,
            decoration: _fieldDecoration(
              context.l10n.signupRegistrationOptional,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            _iconAction(
              label: context.l10n.actionBack,
              icon: Icons.arrow_back_rounded,
              onPressed: cubit.goBack,
            ),
            const Spacer(),
            Expanded(
              flex: 2,
              child: _primaryButton(
                label: context.l10n.signupCreateCompany,
                onPressed: state.canSubmitBranch
                    ? cubit.submitBranchAndCreate
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CompanySignupCubit>().state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...CompanySignupCubit.progressSteps.map((step) {
          final done = state.completedProgressIds.contains(step.id);
          final active = state.activeProgressId == step.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? const Color(0xFF12B76A)
                        : active
                        ? const Color(0xFF4A00E0)
                        : const Color(0xFFE4E7EC),
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : active
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    switch (step.labelKey) {
                      'signupProgressCreatingUser' =>
                        context.l10n.signupProgressCreatingUser,
                      'signupProgressCreatingCompany' =>
                        context.l10n.signupProgressCreatingCompany,
                      'signupProgressSettingProfile' =>
                        context.l10n.signupProgressSettingProfile,
                      'signupProgressSettingBranch' =>
                        context.l10n.signupProgressSettingBranch,
                      'signupProgressSettingAccount' =>
                        context.l10n.signupProgressSettingAccount,
                      'signupProgressSuccess' =>
                        context.l10n.signupProgressSuccess,
                      _ => step.labelKey,
                    },
                    style: FontUtility.body.copyWith(
                      fontWeight: done || active
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: done || active
                          ? const Color(0xFF1F2937)
                          : Colors.black45,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        if (state.isSuccess) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA6F4C5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.signupCompanyIdentifier,
                  style: FontUtility.body.copyWith(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.companyIdentifier ?? '',
                  style: FontUtility.heading.copyWith(
                    fontSize: 22,
                    color: const Color(0xFF027A48),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _primaryButton(
            label: context.l10n.signupLoginNow,
            onPressed: () {
              Navigator.pushReplacementNamed(
                context,
                AppRoutes.login,
                arguments: {
                  'companyIdentifier': state.companyIdentifier,
                  'email': state.email,
                  'phone': state.phoneNumber,
                },
              );
            },
          ),
        ],
        if (!state.isSubmitting &&
            !state.isSuccess &&
            state.errorMessage != null) ...[
          const SizedBox(height: 20),
          _primaryButton(
            label: context.l10n.signupTryAgain,
            onPressed: () {
              context.read<CompanySignupCubit>().submitBranchAndCreate();
            },
          ),
          TextButton(
            onPressed: () {
              context.read<CompanySignupCubit>().goBack();
            },
            child: Text(context.l10n.signupBackToBranch),
          ),
        ],
      ],
    );
  }
}
