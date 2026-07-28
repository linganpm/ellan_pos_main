import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/utils/font_utility.dart';
import '../../core/routes.dart';
import '../../bloc/store_list/store_list_bloc.dart';
import '../../bloc/store_list/store_list_state.dart';
import '../../data/models/store_model.dart';
import '../../core/localization/l10n/app_localizations.dart';

/// Store List Screen - Premium tablet-optimized UI for store selection
/// 
/// This screen allows users to select a store from the available list
/// before proceeding to the main dashboard. The left side uses the same
/// branding layout as the welcome screen, while the right side displays
/// an elegant store selection interface.
class StoreListScreen extends StatelessWidget {
  const StoreListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => StoreListCubit()
          ..loadStores(),
      child: Scaffold(
        body: Row(
          children: [
            // LEFT SIDE - Branding / Graphic (Reused from WelcomeScreen)
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

            // RIGHT SIDE - Store Selection Area
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          'Select Store',
                          style: FontUtility.heading.copyWith(
                            color: const Color(0xFF333333),
                            fontSize: 36,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Subtitle
                        Text(
                          'Choose your store to continue',
                          style: FontUtility.body.copyWith(
                            color: Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Search Field
                        _buildSearchField(),
                        const SizedBox(height: 24),

                        // Store List
                        Expanded(
                          child: _buildStoreListContent(),
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        _buildSubmitButton(),
                      ],
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

  /// Builds the search field for filtering stores
  Widget _buildSearchField() {
    return BlocBuilder<StoreListCubit, StoreListState>(
      builder: (context, state) {
        return TextField(
          onChanged: (query) {
            context.read<StoreListCubit>().searchStores(query);
          },
          decoration: InputDecoration(
            hintText: 'Search by store name or ID...',
            hintStyle: FontUtility.body.copyWith(color: Colors.black38),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF4A00E0)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          ),
          style: FontUtility.body,
        );
      },
    );
  }

  /// Builds the main store list content with appropriate state handling
  Widget _buildStoreListContent() {
    return BlocBuilder<StoreListCubit, StoreListState>(
      builder: (context, state) {
        if (state is StoreListLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF4A00E0),
                  strokeWidth: 2.5,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading stores...',
                  style: FontUtility.body.copyWith(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (state is StoreListError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red.shade700,
                ),
                const SizedBox(height: 16),
                Text(
                  state.errorMessage,
                  textAlign: TextAlign.center,
                  style: FontUtility.body.copyWith(
                    color: Colors.red.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        List<StoreModel> stores = [];
        String? selectedStoreId;

        if (state is StoreListLoaded) {
          stores = state.filteredStores ?? state.stores;
          selectedStoreId = state.selectedStoreId;
        } else if (state is StoreSelectionChanged) {
          stores = state.allStores;
          selectedStoreId = state.selectedStore.storeId;
        }

        if (stores.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 48,
                  color: Colors.black26,
                ),
                const SizedBox(height: 16),
                Text(
                  'No stores found',
                  style: FontUtility.body.copyWith(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        // Display store list
        return ListView.builder(
          itemCount: stores.length,
          itemBuilder: (context, index) {
            final store = stores[index];
            final isSelected = selectedStoreId == store.storeId;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildStoreCard(
                context: context,
                store: store,
                isSelected: isSelected,
              ),
            );
          },
        );
      },
    );
  }

  /// Builds an individual store card with selection indicator
  Widget _buildStoreCard({
    required BuildContext context,
    required StoreModel store,
    required bool isSelected,
  }) {
    return InkWell(
               onTap: () {
                context.read<StoreListCubit>().selectStore(store.storeId);
              
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A00E0).withValues(alpha: 0.08) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF4A00E0) : Colors.black12,
            width: isSelected ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4A00E0).withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Store Avatar/Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF8E2DE2).withValues(alpha: 0.8),
                      const Color(0xFF4A00E0).withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.store_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Store Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Store Name
                    Text(
                      store.storeName,
                      style: FontUtility.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Store ID
                    Text(
                      'Store ID: ${store.storeId}',
                      style: FontUtility.body.copyWith(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Role Badge
                    _buildRoleBadge(store.storeRole),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Selection Indicator
              AnimatedScale(
                scale: isSelected ? 1.0 : 0.8,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF4A00E0) : Colors.black26,
                      width: 2.0,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF4A00E0),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a role badge widget
  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    Color textColor;

    switch (role.toLowerCase()) {
      case 'admin':
        badgeColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
      case 'manager':
        badgeColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
      case 'cashier':
        badgeColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
      default:
        badgeColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: FontUtility.body.copyWith(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Builds the submit button
  Widget _buildSubmitButton() {
    return BlocListener<StoreListCubit, StoreListState>(
      listener: (context, state) {
        if (state is StoreVerificationSuccess) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${state.store.storeName} selected successfully!'),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 2),
            ),
          );
          // Navigate to home screen after a brief delay
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, AppRoutes.home);
          });
        } else if (state is StoreVerificationFailure) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
        child: BlocBuilder<StoreListCubit, StoreListState>(
        builder: (context, state) {
          bool isLoading = state is StoreVerificationLoading;
          final syncMessage =
              state is StoreVerificationLoading ? state.message : null;
          bool isEnabled = false;

          if (state is StoreListLoaded && state.selectedStoreId != null) {
            isEnabled = true;
          } else if (state is StoreSelectionChanged) {
            isEnabled = true;
          }

          return SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
               onPressed: isEnabled && !isLoading
                  ? () {
                      context.read<StoreListCubit>().verifySelectedStore();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A00E0),
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: isEnabled ? 5 : 0,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                          if (syncMessage != null && syncMessage.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                syncMessage,
                                overflow: TextOverflow.ellipsis,
                                style: FontUtility.button.copyWith(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    : Text(
                        'Continue',
                        style: FontUtility.button.copyWith(
                          color: isEnabled ? Colors.white : Colors.grey.shade500,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}