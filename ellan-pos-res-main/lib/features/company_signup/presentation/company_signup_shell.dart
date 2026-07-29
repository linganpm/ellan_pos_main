import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/routes.dart';
import '../../../core/utils/font_utility.dart';
import '../cubit/company_signup_cubit.dart';
import '../cubit/company_signup_state.dart';
import '../data/signup_api.dart';

class CompanySignupShell extends StatelessWidget {
  const CompanySignupShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CompanySignupCubit(
        prefs: context.read<SharedPreferences>(),
      ),
      child: const _SignupView(),
    );
  }
}

class _SignupView extends StatelessWidget {
  const _SignupView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 1,
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
                  padding: const EdgeInsets.all(40),
                  child: BlocBuilder<CompanySignupCubit, CompanySignupState>(
                    builder: (context, state) {
                      final title = switch (state.step) {
                        CompanySignupStep.serverParent => 'Create your company',
                        CompanySignupStep.companyDetails => 'Company details',
                        CompanySignupStep.businessType => 'What do you run?',
                        CompanySignupStep.branchDetails => 'Your first branch',
                        CompanySignupStep.progress => state.isSuccess
                            ? 'You are ready'
                            : 'Setting things up',
                      };
                      final body = switch (state.step) {
                        CompanySignupStep.serverParent =>
                          'Enter your server and parent organisation, then create a new company for this tablet.',
                        CompanySignupStep.companyDetails =>
                          'Tell us about the company and the owner who will administer it.',
                        CompanySignupStep.businessType =>
                          'Pick the business type. We will create a restaurant store under your branch.',
                        CompanySignupStep.branchDetails =>
                          'Name the branch and city. Registration number is optional.',
                        CompanySignupStep.progress => state.isSuccess
                            ? 'Your company is ready. Sign in with your company identifier and password.'
                            : 'Creating your organisation, branch, and store — this only takes a moment.',
                      };
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            size: 80,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 32),
                          Text(
                            title,
                            style: FontUtility.heading.copyWith(
                              color: Colors.white,
                              fontSize: 40,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            body,
                            style: FontUtility.body.copyWith(
                              color: Colors.white70,
                              fontSize: 18,
                              height: 1.5,
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
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              child: Center(
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
                                    border: Border.all(color: Colors.red.shade200),
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
                              switch (state.step) {
                                CompanySignupStep.serverParent =>
                                  const _ServerParentForm(),
                                CompanySignupStep.companyDetails =>
                                  const _CompanyDetailsForm(),
                                CompanySignupStep.businessType =>
                                  const _BusinessTypeForm(),
                                CompanySignupStep.branchDetails =>
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
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD0D5DD), width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD0D5DD), width: 2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF4A00E0), width: 2.5),
    ),
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
        TextField(
          controller: _server,
          keyboardType: TextInputType.url,
          onChanged: cubit.serverUrlChanged,
          decoration: _fieldDecoration('Server URL (e.g. http://192.168.1.10:8000)'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _parent,
          onChanged: cubit.parentOrgChanged,
          decoration: _fieldDecoration('Parent organisation identifier or instance id'),
        ),
        const SizedBox(height: 8),
        Text(
          'We’ll check this organisation exists before continuing.',
          style: FontUtility.body.copyWith(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 28),
        _primaryButton(
          label: 'Continue',
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
            'Already have a company? Sign in',
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
            'Join an existing organisation device',
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
  late final TextEditingController _passwordConfirm;
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    final state = context.read<CompanySignupCubit>().state;
    _company = TextEditingController(text: state.companyName);
    _owner = TextEditingController(text: state.ownerName);
    _email = TextEditingController(text: state.email);
    _phone = TextEditingController(text: state.phoneNumber);
    _password = TextEditingController(text: state.password);
    _passwordConfirm = TextEditingController(text: state.passwordConfirm);
  }

  @override
  void dispose() {
    _company.dispose();
    _owner.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _pickCountry(CompanySignupCubit cubit, CompanySignupState state) async {
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
    if (selected != null) {
      cubit.countryChanged(selected.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CompanySignupCubit>();
    final state = context.watch<CompanySignupCubit>().state;
    final selected = state.selectedCountry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.parentOrgName.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD0D5DD)),
            ),
            child: Text(
              'Parent: ${state.parentOrgName}',
              style: FontUtility.body.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A00E0),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _company,
          onChanged: cubit.companyNameChanged,
          decoration: _fieldDecoration('Company name'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _owner,
          onChanged: cubit.ownerNameChanged,
          decoration: _fieldDecoration('Owner name'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          onChanged: cubit.emailChanged,
          decoration: _fieldDecoration('Email'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          onChanged: cubit.phoneChanged,
          decoration: _fieldDecoration(
            selected?.dialCode.isNotEmpty == true
                ? 'Phone number (e.g. ${selected!.dialCode} 9876543210)'
                : 'Phone number',
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _pickCountry(cubit, state),
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: _fieldDecoration('Country'),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected?.displayLabel ?? 'Select country',
                    style: FontUtility.body.copyWith(
                      color: selected == null ? Colors.black38 : const Color(0xFF1F2937),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.search_rounded, color: Colors.black45),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _password,
          obscureText: _obscure,
          onChanged: cubit.passwordChanged,
          decoration: _fieldDecoration('Password (min 6 letters/digits)').copyWith(
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Keep it simple for floor staff — letters, numbers, or both.',
          style: FontUtility.body.copyWith(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordConfirm,
          obscureText: _obscureConfirm,
          onChanged: cubit.passwordConfirmChanged,
          decoration: _fieldDecoration('Confirm password').copyWith(
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
            ),
            errorText: state.passwordConfirm.isNotEmpty && !state.passwordsMatch
                ? 'Passwords do not match'
                : null,
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            TextButton(onPressed: cubit.goBack, child: const Text('Back')),
            const Spacer(),
            Expanded(
              flex: 2,
              child: _primaryButton(
                label: 'Continue',
                onPressed: state.canContinueCompanyDetails
                    ? cubit.continueFromCompanyDetails
                    : null,
              ),
            ),
          ],
        ),
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
    final filtered = widget.countries.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q) ||
          c.dialCode.toLowerCase().contains(q);
    }).toList(growable: false);

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
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: _fieldDecoration('Search country, code, or dial').copyWith(
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No countries match “$_query”',
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
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
                            ? const Icon(Icons.check_circle, color: Color(0xFF4A00E0))
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

class _BusinessTypeForm extends StatelessWidget {
  const _BusinessTypeForm();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CompanySignupCubit>();
    final state = context.watch<CompanySignupCubit>().state;
    final types = state.businessTypes.isEmpty
        ? const [
            SignupBusinessType(id: 'cafe', label: 'Cafe'),
            SignupBusinessType(id: 'restaurant', label: 'Restaurant'),
            SignupBusinessType(id: 'bakery', label: 'Bakery'),
            SignupBusinessType(id: 'other', label: 'Others'),
          ]
        : state.businessTypes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...types.map((type) {
          final selected = state.businessType == type.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => cubit.businessTypeChanged(type.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF4A00E0).withValues(alpha: 0.08) : const Color(0xFFF7F8FB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? const Color(0xFF4A00E0) : const Color(0xFFD0D5DD),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: selected ? const Color(0xFF4A00E0) : Colors.black45,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      type.label,
                      style: FontUtility.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
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
            TextButton(onPressed: cubit.goBack, child: const Text('Back')),
            const Spacer(),
            Expanded(
              flex: 2,
              child: _primaryButton(
                label: 'Continue',
                onPressed: state.canContinueBusinessType
                    ? cubit.continueFromBusinessType
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _branch,
          onChanged: cubit.branchNameChanged,
          decoration: _fieldDecoration('Branch name'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _city,
          onChanged: cubit.cityChanged,
          decoration: _fieldDecoration('City'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _reg,
          onChanged: cubit.registrationNumberChanged,
          decoration: _fieldDecoration('Registration number (optional)'),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            TextButton(onPressed: cubit.goBack, child: const Text('Back')),
            const Spacer(),
            Expanded(
              flex: 2,
              child: _primaryButton(
                label: 'Create company',
                onPressed:
                    state.canSubmitBranch ? cubit.submitBranchAndCreate : null,
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
                    step.label,
                    style: FontUtility.body.copyWith(
                      fontWeight: done || active ? FontWeight.w700 : FontWeight.w500,
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
                  'Company identifier',
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
                const SizedBox(height: 8),
                Text(
                  'Use this identifier with your email/phone and password to sign in.',
                  style: FontUtility.body.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _primaryButton(
            label: 'Login now',
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
        if (!state.isSubmitting && !state.isSuccess && state.errorMessage != null) ...[
          const SizedBox(height: 20),
          _primaryButton(
            label: 'Try again',
            onPressed: () {
              context.read<CompanySignupCubit>().submitBranchAndCreate();
            },
          ),
          TextButton(
            onPressed: () {
              context.read<CompanySignupCubit>().goBack();
            },
            child: const Text('Back to branch details'),
          ),
        ],
      ],
    );
  }
}
