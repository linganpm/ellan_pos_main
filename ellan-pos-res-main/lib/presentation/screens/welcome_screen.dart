import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/l10n/app_localizations.dart';
import '../../core/utils/font_utility.dart';
import '../../bloc/welcome/welcome_cubit.dart';
import '../../bloc/welcome/welcome_state.dart';
import '../../core/routes.dart';
import '../../core/device_setup_store.dart';
import '../../core/constants/discovery_constants.dart';
import '../../core/localization/l10n_context.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          WelcomeCubit(prefs: context.read<SharedPreferences>()),
      child: const _WelcomeView(),
    );
  }
}

class _WelcomeView extends StatefulWidget {
  const _WelcomeView();

  @override
  State<_WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<_WelcomeView> {
  final _serverUrlController = TextEditingController();
  final _orgIdController = TextEditingController();
  bool _controllersSeeded = false;

  @override
  void dispose() {
    _serverUrlController.dispose();
    _orgIdController.dispose();
    super.dispose();
  }

  void _syncControllers(WelcomeState state, {bool force = false}) {
    if (!_controllersSeeded || force) {
      _serverUrlController.text = state.serverUrl;
      _orgIdController.text = state.organizationName;
      _controllersSeeded = true;
    }
  }

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
                        context.l10n.appName,
                        style: FontUtility.heading.copyWith(
                          color: Colors.white,
                          fontSize: 42,
                          height: 1.2,
                        ),
                      ),
                    ],
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60.0),
                  child: BlocConsumer<WelcomeCubit, WelcomeState>(
                    listener: (context, state) {
                      if (state.isSuccess) {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.login,
                        );
                      }
                    },
                    builder: (context, state) {
                      _syncControllers(state);
                      return SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                tooltip: context.l10n.actionBack,
                                onPressed: state.isLoading
                                    ? null
                                    : () {
                                        Navigator.pushNamedAndRemoveUntil(
                                          context,
                                          AppRoutes.authEntry,
                                          (route) => false,
                                        );
                                      },
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context)!.welcomeGetStarted,
                              style: FontUtility.heading.copyWith(
                                color: const Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 32),
                            if (state.errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        state.errorMessage!,
                                        style: FontUtility.body.copyWith(
                                          color: Colors.red.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                            if (!kIsPosDiscoveryConfiguredByEnv &&
                                state.savedServers.isNotEmpty) ...[
                              Text(
                                context.l10n.welcomeSavedServers,
                                style: FontUtility.body.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 8),
                              InputDecorator(
                                decoration: _fieldDecoration(
                                  hintText:
                                      context.l10n.welcomeChooseSavedServer,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<PosServerEntry>(
                                    value: _selectedEntry(state),
                                    isExpanded: true,
                                    hint: Text(
                                      context.l10n.welcomeChooseSavedServer,
                                      style: FontUtility.body.copyWith(
                                        color: Colors.black38,
                                      ),
                                    ),
                                    items: state.savedServers
                                        .map(
                                          (entry) => DropdownMenuItem(
                                            value: entry,
                                            child: Text(
                                              entry.displayLabel,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: state.isLoading
                                        ? null
                                        : (entry) {
                                            if (entry == null) return;
                                            context
                                                .read<WelcomeCubit>()
                                                .selectSavedServer(entry);
                                            _syncControllers(
                                              context
                                                  .read<WelcomeCubit>()
                                                  .state,
                                              force: true,
                                            );
                                          },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_selectedEntry(state) != null)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: state.isLoading
                                        ? null
                                        : () async {
                                            final cubit = context
                                                .read<WelcomeCubit>();
                                            final entry = _selectedEntry(
                                              state,
                                            )!;
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (dialogContext) => AlertDialog(
                                                title: Text(
                                                  dialogContext
                                                      .l10n
                                                      .welcomeDeleteSavedServer,
                                                ),
                                                content: Text(
                                                  dialogContext.l10n
                                                      .welcomeRemoveServerConfirm(
                                                        entry.displayLabel,
                                                      ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          dialogContext,
                                                          false,
                                                        ),
                                                    child: Text(
                                                      dialogContext
                                                          .l10n
                                                          .actionCancel,
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          dialogContext,
                                                          true,
                                                        ),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              const Color(
                                                                0xFFFF512F,
                                                              ),
                                                          foregroundColor:
                                                              Colors.white,
                                                        ),
                                                    child: Text(
                                                      dialogContext
                                                          .l10n
                                                          .actionDelete,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirmed != true || !mounted) {
                                              return;
                                            }
                                            await cubit.deleteSavedServer(
                                              entry,
                                            );
                                            if (!mounted) return;
                                            _syncControllers(
                                              cubit.state,
                                              force: true,
                                            );
                                          },
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Color(0xFFFF512F),
                                    ),
                                    label: Text(
                                      context.l10n.welcomeDeleteFromList,
                                      style: const TextStyle(
                                        color: Color(0xFFFF512F),
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                            ],
                            if (!kIsPosDiscoveryConfiguredByEnv) ...[
                              Text(
                                context.l10n.welcomeServerUrl,
                                style: FontUtility.body.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _serverUrlController,
                                enabled: !state.isLoading,
                                keyboardType: TextInputType.url,
                                onChanged: (value) => context
                                    .read<WelcomeCubit>()
                                    .serverUrlChanged(value),
                                decoration: _fieldDecoration(
                                  hintText: context.l10n.welcomeServerUrlHint,
                                ),
                                style: FontUtility.body,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                context.l10n.welcomeOrgInstanceId,
                                style: FontUtility.body.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _orgIdController,
                                enabled: !state.isLoading,
                                keyboardType: TextInputType.text,
                                onChanged: (value) => context
                                    .read<WelcomeCubit>()
                                    .organizationNameChanged(value),
                                decoration: _fieldDecoration(
                                  hintText: AppLocalizations.of(
                                    context,
                                  )!.welcomeOrgCodeHint,
                                ),
                                style: FontUtility.body,
                              ),
                              const SizedBox(height: 24),
                            ],
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: state.isValid && !state.isLoading
                                    ? () =>
                                          context.read<WelcomeCubit>().submit()
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A00E0),
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: state.isValid ? 5 : 0,
                                ),
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
                                      : Text(
                                          context.l10n.welcomeRegisterDevice,
                                          style: FontUtility.button.copyWith(
                                            color: state.isValid
                                                ? Colors.white
                                                : Colors.grey.shade500,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: state.isLoading
                                    ? null
                                    : () {
                                        Navigator.pushNamedAndRemoveUntil(
                                          context,
                                          AppRoutes.login,
                                          (route) => false,
                                        );
                                      },
                                child: Text(
                                  context.l10n.welcomeAlreadySetupSignIn,
                                  style: FontUtility.body.copyWith(
                                    color: const Color(0xFF4A00E0),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: TextButton(
                                onPressed: state.isLoading
                                    ? null
                                    : () {
                                        Navigator.pushNamedAndRemoveUntil(
                                          context,
                                          AppRoutes.onboarding,
                                          (route) => false,
                                        );
                                      },
                                child: Text(
                                  context.l10n.welcomeCreateCompanyInstead,
                                  style: FontUtility.body.copyWith(
                                    color: Colors.black54,
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
        ],
      ),
    );
  }

  PosServerEntry? _selectedEntry(WelcomeState state) {
    final typedOrg = state.organizationName.trim();
    final typedServer = state.serverUrl.trim();
    if (typedOrg.isEmpty || typedServer.isEmpty) return null;

    final typedOrigin = discoveryOrigin(typedServer);
    for (final entry in state.savedServers) {
      final sameOrg = entry.orgInstanceId.trim() == typedOrg;
      final sameServer = discoveryOrigin(entry.serverUrl) == typedOrigin;
      if (sameOrg && sameServer) return entry;
    }
    return null;
  }

  InputDecoration _fieldDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: FontUtility.body.copyWith(color: Colors.black38),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4A00E0), width: 2),
      ),
    );
  }
}
