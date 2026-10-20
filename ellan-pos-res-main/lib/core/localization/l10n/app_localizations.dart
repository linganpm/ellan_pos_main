import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ta.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ta'),
  ];

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get actionChange;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get actionKeep;

  /// No description provided for @actionLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get actionLogout;

  /// No description provided for @actionPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get actionPrint;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get actionSaveChanges;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get actionSignIn;

  /// No description provided for @actionSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get actionSignUp;

  /// No description provided for @actionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get actionSubmit;

  /// No description provided for @actionSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get actionSync;

  /// No description provided for @actionUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get actionUpdate;

  /// No description provided for @actionViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get actionViewAll;

  /// No description provided for @amountGreaterThanZero.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than zero.'**
  String get amountGreaterThanZero;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'EllanPos'**
  String get appName;

  /// No description provided for @authBackToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Back to Get started'**
  String get authBackToGetStarted;

  /// No description provided for @authEntryBrand.
  ///
  /// In en, this message translates to:
  /// **'EllanPos'**
  String get authEntryBrand;

  /// No description provided for @authEntryChooseContinue.
  ///
  /// In en, this message translates to:
  /// **'Choose how you want to continue on this tablet.'**
  String get authEntryChooseContinue;

  /// No description provided for @authEntryCompanySetup.
  ///
  /// In en, this message translates to:
  /// **'Company setup'**
  String get authEntryCompanySetup;

  /// No description provided for @authEntryCreateCompany.
  ///
  /// In en, this message translates to:
  /// **'Create a new company'**
  String get authEntryCreateCompany;

  /// No description provided for @authEntryHero.
  ///
  /// In en, this message translates to:
  /// **'Sign in to an existing company, or set up a new company on this device.'**
  String get authEntryHero;

  /// No description provided for @authEntryJoinExisting.
  ///
  /// In en, this message translates to:
  /// **'Join an existing organisation device'**
  String get authEntryJoinExisting;

  /// No description provided for @authEntryRootOrgLabel.
  ///
  /// In en, this message translates to:
  /// **'Root org  ·  {orgId}'**
  String authEntryRootOrgLabel(String orgId);

  /// No description provided for @authEntryServerLabel.
  ///
  /// In en, this message translates to:
  /// **'Server  ·  {server}'**
  String authEntryServerLabel(String server);

  /// No description provided for @authEntrySignInExisting.
  ///
  /// In en, this message translates to:
  /// **'Already have a company? Sign in'**
  String get authEntrySignInExisting;

  /// No description provided for @authEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get authEntryTitle;

  /// No description provided for @billingAddDiscount.
  ///
  /// In en, this message translates to:
  /// **'Add discount'**
  String get billingAddDiscount;

  /// No description provided for @billingAddDiscountCaps.
  ///
  /// In en, this message translates to:
  /// **'ADD DISCOUNT'**
  String get billingAddDiscountCaps;

  /// No description provided for @billingAddOnePaymentFirst.
  ///
  /// In en, this message translates to:
  /// **'Add at least one payment first.'**
  String get billingAddOnePaymentFirst;

  /// No description provided for @billingAddPayment.
  ///
  /// In en, this message translates to:
  /// **'ADD PAYMENT'**
  String get billingAddPayment;

  /// No description provided for @billingAddPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Add payment'**
  String get billingAddPaymentTitle;

  /// No description provided for @billingAddTips.
  ///
  /// In en, this message translates to:
  /// **'Add tips'**
  String get billingAddTips;

  /// No description provided for @billingAmountExceedsRemaining.
  ///
  /// In en, this message translates to:
  /// **'Amount cannot exceed remaining ({amount}).'**
  String billingAmountExceedsRemaining(String amount);

  /// No description provided for @billingAppliedDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Applied discounts'**
  String get billingAppliedDiscounts;

  /// No description provided for @billingApply.
  ///
  /// In en, this message translates to:
  /// **'APPLY'**
  String get billingApply;

  /// No description provided for @billingApplyServiceTax.
  ///
  /// In en, this message translates to:
  /// **'Apply service tax'**
  String get billingApplyServiceTax;

  /// No description provided for @billingApplyTo.
  ///
  /// In en, this message translates to:
  /// **'Apply to'**
  String get billingApplyTo;

  /// No description provided for @billingAttachCustomer.
  ///
  /// In en, this message translates to:
  /// **'Attach a customer to this bill (required for credit).'**
  String get billingAttachCustomer;

  /// No description provided for @billingCheckoutComplete.
  ///
  /// In en, this message translates to:
  /// **'Checkout complete'**
  String get billingCheckoutComplete;

  /// No description provided for @billingComplete.
  ///
  /// In en, this message translates to:
  /// **'COMPLETE'**
  String get billingComplete;

  /// No description provided for @billingCompleteWithoutPayment.
  ///
  /// In en, this message translates to:
  /// **'COMPLETE WITHOUT PAYMENT'**
  String get billingCompleteWithoutPayment;

  /// No description provided for @billingCompletingCheckout.
  ///
  /// In en, this message translates to:
  /// **'Completing checkout…'**
  String get billingCompletingCheckout;

  /// No description provided for @billingCoverFullOrCredit.
  ///
  /// In en, this message translates to:
  /// **'Cover the full amount or put the balance on credit with a customer.'**
  String get billingCoverFullOrCredit;

  /// No description provided for @billingCreditCancelled.
  ///
  /// In en, this message translates to:
  /// **'Credit cancelled. Checkout was not completed.'**
  String get billingCreditCancelled;

  /// No description provided for @billingCreditLimitContinue.
  ///
  /// In en, this message translates to:
  /// **'{message}\n\nContinue anyway?'**
  String billingCreditLimitContinue(String message);

  /// No description provided for @billingCreditLimitExceeded.
  ///
  /// In en, this message translates to:
  /// **'Credit limit {limit} would be exceeded (outstanding {outstanding} + this sale {amountDue}).'**
  String billingCreditLimitExceeded(
    String limit,
    String outstanding,
    String amountDue,
  );

  /// No description provided for @billingCreditLimitWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Credit limit warning'**
  String get billingCreditLimitWarningTitle;

  /// No description provided for @billingCreditNeedsCustomer.
  ///
  /// In en, this message translates to:
  /// **'Credit payment needs a customer. Select a customer and try again.'**
  String get billingCreditNeedsCustomer;

  /// No description provided for @billingCreditPlaceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not place remaining balance on credit. Checkout cancelled.'**
  String get billingCreditPlaceFailed;

  /// No description provided for @billingCustomerForCredit.
  ///
  /// In en, this message translates to:
  /// **'Customer for credit'**
  String get billingCustomerForCredit;

  /// No description provided for @billingCustomerOptionalCredit.
  ///
  /// In en, this message translates to:
  /// **'Optional — required when paying on credit'**
  String get billingCustomerOptionalCredit;

  /// No description provided for @billingDiscountAdded.
  ///
  /// In en, this message translates to:
  /// **'Added \"{title}\"'**
  String billingDiscountAdded(String title);

  /// No description provided for @billingDiscountsCount.
  ///
  /// In en, this message translates to:
  /// **'Discounts ({count})'**
  String billingDiscountsCount(int count);

  /// No description provided for @billingDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft order #{orderId} saved.'**
  String billingDraftSaved(int orderId);

  /// No description provided for @billingEntireOrder.
  ///
  /// In en, this message translates to:
  /// **'Entire order'**
  String get billingEntireOrder;

  /// No description provided for @billingInvalidDiscountPct.
  ///
  /// In en, this message translates to:
  /// **'Enter a discount percentage between 1 and 100'**
  String get billingInvalidDiscountPct;

  /// No description provided for @billingNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items to bill.'**
  String get billingNoItems;

  /// No description provided for @billingNoPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'No payment methods configured.'**
  String get billingNoPaymentMethods;

  /// No description provided for @billingOrderCreditBalance.
  ///
  /// In en, this message translates to:
  /// **'Order #{orderId} — balance added to customer credit'**
  String billingOrderCreditBalance(int orderId);

  /// No description provided for @billingOrderFullyCovered.
  ///
  /// In en, this message translates to:
  /// **'Order is already fully covered.'**
  String get billingOrderFullyCovered;

  /// No description provided for @billingOrderPaidVia.
  ///
  /// In en, this message translates to:
  /// **'Order #{orderId} paid via {mode}'**
  String billingOrderPaidVia(int orderId, String mode);

  /// No description provided for @billingOrderPlacedBalance.
  ///
  /// In en, this message translates to:
  /// **'Order #{orderId} placed with balance {amount}'**
  String billingOrderPlacedBalance(int orderId, String amount);

  /// No description provided for @billingPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid  {amount}'**
  String billingPaid(String amount);

  /// No description provided for @billingPaymentSale.
  ///
  /// In en, this message translates to:
  /// **'{paymentLabel} sale'**
  String billingPaymentSale(String paymentLabel);

  /// No description provided for @billingPercentageHint.
  ///
  /// In en, this message translates to:
  /// **'1-100'**
  String get billingPercentageHint;

  /// No description provided for @billingPlaceFullCredit.
  ///
  /// In en, this message translates to:
  /// **'Place full amount on credit'**
  String get billingPlaceFullCredit;

  /// No description provided for @billingPlaceFullOnCredit.
  ///
  /// In en, this message translates to:
  /// **'Place full amount on credit'**
  String get billingPlaceFullOnCredit;

  /// No description provided for @billingPlaceWithBalance.
  ///
  /// In en, this message translates to:
  /// **'PLACE WITH BALANCE'**
  String get billingPlaceWithBalance;

  /// No description provided for @billingRemainingAddPayment.
  ///
  /// In en, this message translates to:
  /// **'Remaining {amount}. Add another payment or place with balance due.'**
  String billingRemainingAddPayment(String amount);

  /// No description provided for @billingRemainingOnCredit.
  ///
  /// In en, this message translates to:
  /// **'Remaining on credit: {amount}'**
  String billingRemainingOnCredit(String amount);

  /// No description provided for @billingRemoveAllDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Remove all discounts'**
  String get billingRemoveAllDiscounts;

  /// No description provided for @billingRemoveExistingTax.
  ///
  /// In en, this message translates to:
  /// **'Remove existing tax'**
  String get billingRemoveExistingTax;

  /// No description provided for @billingRemoveTips.
  ///
  /// In en, this message translates to:
  /// **'Remove tips'**
  String get billingRemoveTips;

  /// No description provided for @billingSaveAsDraft.
  ///
  /// In en, this message translates to:
  /// **'Save as draft'**
  String get billingSaveAsDraft;

  /// No description provided for @billingSelectCustomerCredit.
  ///
  /// In en, this message translates to:
  /// **'Select or add the customer to put {amount} on their credit account.'**
  String billingSelectCustomerCredit(String amount);

  /// No description provided for @billingServiceTaxApplied.
  ///
  /// In en, this message translates to:
  /// **'Service tax applied'**
  String get billingServiceTaxApplied;

  /// No description provided for @billingServiceTaxLabel.
  ///
  /// In en, this message translates to:
  /// **'Service tax'**
  String get billingServiceTaxLabel;

  /// No description provided for @billingTaxPct.
  ///
  /// In en, this message translates to:
  /// **'Tax {percent}%'**
  String billingTaxPct(String percent);

  /// No description provided for @billingTaxPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter tax percentage (1-100)'**
  String get billingTaxPlaceholder;

  /// No description provided for @billingTipsAmount.
  ///
  /// In en, this message translates to:
  /// **'Tips {amount}'**
  String billingTipsAmount(String amount);

  /// No description provided for @billingTipsApplied.
  ///
  /// In en, this message translates to:
  /// **'Tips applied'**
  String get billingTipsApplied;

  /// No description provided for @billingTipsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter tip amount'**
  String get billingTipsPlaceholder;

  /// No description provided for @billingTitle.
  ///
  /// In en, this message translates to:
  /// **'Billing & Payment'**
  String get billingTitle;

  /// No description provided for @billingToPay.
  ///
  /// In en, this message translates to:
  /// **'To pay  {amount}'**
  String billingToPay(String amount);

  /// No description provided for @catalogAllPackages.
  ///
  /// In en, this message translates to:
  /// **'All packages'**
  String get catalogAllPackages;

  /// No description provided for @catalogAppliesTo.
  ///
  /// In en, this message translates to:
  /// **'Applies to'**
  String get catalogAppliesTo;

  /// No description provided for @catalogBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get catalogBarcode;

  /// No description provided for @catalogBillOffer.
  ///
  /// In en, this message translates to:
  /// **'Bill offer'**
  String get catalogBillOffer;

  /// No description provided for @catalogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No products in catalog'**
  String get catalogEmpty;

  /// No description provided for @catalogMrpPrice.
  ///
  /// In en, this message translates to:
  /// **'MRP {amount}'**
  String catalogMrpPrice(String amount);

  /// No description provided for @catalogNoActiveOffers.
  ///
  /// In en, this message translates to:
  /// **'No active offers synced for this store'**
  String get catalogNoActiveOffers;

  /// No description provided for @catalogNoAddonGroups.
  ///
  /// In en, this message translates to:
  /// **'No add-on groups linked to this package'**
  String get catalogNoAddonGroups;

  /// No description provided for @catalogNoCatalogueDevice.
  ///
  /// In en, this message translates to:
  /// **'No catalogue on this device yet. Open Sync and pull products, add-ons, and offers.'**
  String get catalogNoCatalogueDevice;

  /// No description provided for @catalogNoItemsInGroup.
  ///
  /// In en, this message translates to:
  /// **'No items in this group'**
  String get catalogNoItemsInGroup;

  /// No description provided for @catalogNoOffersTargetPackage.
  ///
  /// In en, this message translates to:
  /// **'No offers target this package'**
  String get catalogNoOffersTargetPackage;

  /// No description provided for @catalogNoPackagesView.
  ///
  /// In en, this message translates to:
  /// **'No packages in this view'**
  String get catalogNoPackagesView;

  /// No description provided for @catalogOffersCount.
  ///
  /// In en, this message translates to:
  /// **'Offers ({count})'**
  String catalogOffersCount(int count);

  /// No description provided for @catalogPackagesCount.
  ///
  /// In en, this message translates to:
  /// **'Packages ({count})'**
  String catalogPackagesCount(int count);

  /// No description provided for @catalogProductPrefix.
  ///
  /// In en, this message translates to:
  /// **'Product · {name}'**
  String catalogProductPrefix(String name);

  /// No description provided for @catalogRefreshLocal.
  ///
  /// In en, this message translates to:
  /// **'Refresh from local DB'**
  String get catalogRefreshLocal;

  /// No description provided for @catalogRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh from local DB'**
  String get catalogRefreshTooltip;

  /// No description provided for @catalogSearchExtended.
  ///
  /// In en, this message translates to:
  /// **'Search product, package, barcode…'**
  String get catalogSearchExtended;

  /// No description provided for @catalogSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get catalogSearchHint;

  /// No description provided for @catalogSell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get catalogSell;

  /// No description provided for @catalogTitle.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get catalogTitle;

  /// No description provided for @catalogUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get catalogUnit;

  /// No description provided for @commonActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get commonActions;

  /// No description provided for @commonActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get commonActive;

  /// No description provided for @commonAddons.
  ///
  /// In en, this message translates to:
  /// **'Add-ons'**
  String get commonAddons;

  /// No description provided for @commonAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get commonAddress;

  /// No description provided for @commonAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get commonAmount;

  /// No description provided for @commonAmountToPay.
  ///
  /// In en, this message translates to:
  /// **'Amount to Pay'**
  String get commonAmountToPay;

  /// No description provided for @commonBackToSelling.
  ///
  /// In en, this message translates to:
  /// **'Back to selling'**
  String get commonBackToSelling;

  /// No description provided for @commonBal.
  ///
  /// In en, this message translates to:
  /// **'Bal {amount}'**
  String commonBal(String amount);

  /// No description provided for @commonBalanceDue.
  ///
  /// In en, this message translates to:
  /// **'Balance due'**
  String get commonBalanceDue;

  /// No description provided for @commonBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get commonBusiness;

  /// No description provided for @commonCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get commonCard;

  /// No description provided for @commonCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get commonCash;

  /// No description provided for @commonCatalogs.
  ///
  /// In en, this message translates to:
  /// **'Catalogs'**
  String get commonCatalogs;

  /// No description provided for @commonCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get commonCategories;

  /// No description provided for @commonChangePaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Change Payment Method'**
  String get commonChangePaymentMethod;

  /// No description provided for @commonChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get commonChannel;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonClearCustomer.
  ///
  /// In en, this message translates to:
  /// **'Clear customer'**
  String get commonClearCustomer;

  /// No description provided for @commonCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get commonCode;

  /// No description provided for @commonCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get commonCollect;

  /// No description provided for @commonCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get commonCompany;

  /// No description provided for @commonConfirmPayment.
  ///
  /// In en, this message translates to:
  /// **'Confirm Payment'**
  String get commonConfirmPayment;

  /// No description provided for @commonConfirmPaymentCaps.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM PAYMENT'**
  String get commonConfirmPaymentCaps;

  /// No description provided for @commonContactEmail.
  ///
  /// In en, this message translates to:
  /// **'Contact email'**
  String get commonContactEmail;

  /// No description provided for @commonCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get commonCredit;

  /// No description provided for @commonCreditHistory.
  ///
  /// In en, this message translates to:
  /// **'Credit history'**
  String get commonCreditHistory;

  /// No description provided for @commonCreditOrders.
  ///
  /// In en, this message translates to:
  /// **'Credit Orders'**
  String get commonCreditOrders;

  /// No description provided for @commonCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get commonCredits;

  /// No description provided for @commonCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get commonCurrent;

  /// No description provided for @commonCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get commonCustomer;

  /// No description provided for @commonCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get commonCustomers;

  /// No description provided for @commonDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get commonDate;

  /// No description provided for @commonDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get commonDelivery;

  /// No description provided for @commonDeliveryCharge.
  ///
  /// In en, this message translates to:
  /// **'Delivery Charge'**
  String get commonDeliveryCharge;

  /// No description provided for @commonDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get commonDetails;

  /// No description provided for @commonDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get commonDevice;

  /// No description provided for @commonDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get commonDeviceId;

  /// No description provided for @commonDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get commonDiscount;

  /// No description provided for @commonDiscountPct.
  ///
  /// In en, this message translates to:
  /// **'{title} ({percent}%)'**
  String commonDiscountPct(String title, String percent);

  /// No description provided for @commonDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get commonDueDate;

  /// No description provided for @commonDueDateOptional.
  ///
  /// In en, this message translates to:
  /// **'Due date (optional)'**
  String get commonDueDateOptional;

  /// No description provided for @commonDueValue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String commonDueValue(String date);

  /// No description provided for @commonEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get commonEmail;

  /// No description provided for @commonEmpty.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get commonEmpty;

  /// No description provided for @commonEnterQuantityGtZero.
  ///
  /// In en, this message translates to:
  /// **'Enter a quantity greater than zero.'**
  String get commonEnterQuantityGtZero;

  /// No description provided for @commonExact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get commonExact;

  /// No description provided for @commonExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting catalogue…'**
  String get commonExporting;

  /// No description provided for @commonFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get commonFailed;

  /// No description provided for @commonFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get commonFrequency;

  /// No description provided for @commonGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get commonGuest;

  /// No description provided for @commonHardware.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get commonHardware;

  /// No description provided for @commonHideDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get commonHideDetails;

  /// No description provided for @commonIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Identifier'**
  String get commonIdentifier;

  /// No description provided for @commonInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get commonInactive;

  /// No description provided for @commonInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get commonInfo;

  /// No description provided for @commonItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get commonItem;

  /// No description provided for @commonItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get commonItems;

  /// No description provided for @commonKot.
  ///
  /// In en, this message translates to:
  /// **'KOT {qty}'**
  String commonKot(String qty);

  /// No description provided for @commonLedger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get commonLedger;

  /// No description provided for @commonLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get commonLimit;

  /// No description provided for @commonLineTotal.
  ///
  /// In en, this message translates to:
  /// **'Line total: {amount}'**
  String commonLineTotal(String amount);

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonMiscItem.
  ///
  /// In en, this message translates to:
  /// **'Misc item'**
  String get commonMiscItem;

  /// No description provided for @commonMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get commonMonthly;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @commonNetDays.
  ///
  /// In en, this message translates to:
  /// **'Net {days}'**
  String commonNetDays(int days);

  /// No description provided for @commonNetTotal.
  ///
  /// In en, this message translates to:
  /// **'Net Total'**
  String get commonNetTotal;

  /// No description provided for @commonNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get commonNever;

  /// No description provided for @commonNewOrder.
  ///
  /// In en, this message translates to:
  /// **'New Order'**
  String get commonNewOrder;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get commonNoData;

  /// No description provided for @commonNoPaymentsYet.
  ///
  /// In en, this message translates to:
  /// **'No payments yet'**
  String get commonNoPaymentsYet;

  /// No description provided for @commonNoSalesPeriod.
  ///
  /// In en, this message translates to:
  /// **'No sales in this period'**
  String get commonNoSalesPeriod;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get commonNotSet;

  /// No description provided for @commonNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get commonNotes;

  /// No description provided for @commonOfAmount.
  ///
  /// In en, this message translates to:
  /// **'of {amount}'**
  String commonOfAmount(String amount);

  /// No description provided for @commonOfferApplied.
  ///
  /// In en, this message translates to:
  /// **'Offer applied'**
  String get commonOfferApplied;

  /// No description provided for @commonOfferLabel.
  ///
  /// In en, this message translates to:
  /// **'Offer · {labels}'**
  String commonOfferLabel(String labels);

  /// No description provided for @commonOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get commonOffers;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get commonOnline;

  /// No description provided for @commonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// No description provided for @commonOpenCreditAccount.
  ///
  /// In en, this message translates to:
  /// **'Open credit account'**
  String get commonOpenCreditAccount;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get commonOptional;

  /// No description provided for @commonOrderCount.
  ///
  /// In en, this message translates to:
  /// **'Order count'**
  String get commonOrderCount;

  /// No description provided for @commonOrderHistory.
  ///
  /// In en, this message translates to:
  /// **'Order History'**
  String get commonOrderHistory;

  /// No description provided for @commonOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get commonOrderLabel;

  /// No description provided for @commonOrderTotal.
  ///
  /// In en, this message translates to:
  /// **'Order total'**
  String get commonOrderTotal;

  /// No description provided for @commonOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get commonOrders;

  /// No description provided for @commonOrganisation.
  ///
  /// In en, this message translates to:
  /// **'Organisation'**
  String get commonOrganisation;

  /// No description provided for @commonOrganisationRole.
  ///
  /// In en, this message translates to:
  /// **'Organisation role'**
  String get commonOrganisationRole;

  /// No description provided for @commonOrganisationTime.
  ///
  /// In en, this message translates to:
  /// **'Organisation time'**
  String get commonOrganisationTime;

  /// No description provided for @commonOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get commonOutstanding;

  /// No description provided for @commonOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get commonOverdue;

  /// No description provided for @commonOverdueSuffix.
  ///
  /// In en, this message translates to:
  /// **' · overdue'**
  String get commonOverdueSuffix;

  /// No description provided for @commonOwner.
  ///
  /// In en, this message translates to:
  /// **'owner'**
  String get commonOwner;

  /// No description provided for @commonPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get commonPassword;

  /// No description provided for @commonPay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get commonPay;

  /// No description provided for @commonPayVia.
  ///
  /// In en, this message translates to:
  /// **'Pay via {method}'**
  String commonPayVia(String method);

  /// No description provided for @commonPaymentMode.
  ///
  /// In en, this message translates to:
  /// **'Payment mode'**
  String get commonPaymentMode;

  /// No description provided for @commonPaymentNumber.
  ///
  /// In en, this message translates to:
  /// **'Payment #{id}'**
  String commonPaymentNumber(String id);

  /// No description provided for @commonPaymentTypes.
  ///
  /// In en, this message translates to:
  /// **'Payment Types'**
  String get commonPaymentTypes;

  /// No description provided for @commonPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get commonPayments;

  /// No description provided for @commonPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get commonPending;

  /// No description provided for @commonPercentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get commonPercentage;

  /// No description provided for @commonPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get commonPhone;

  /// No description provided for @commonPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get commonPlan;

  /// No description provided for @commonPosCode.
  ///
  /// In en, this message translates to:
  /// **'POS {code}'**
  String commonPosCode(String code);

  /// No description provided for @commonPosCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'POS code'**
  String get commonPosCodeLabel;

  /// No description provided for @commonPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get commonPreparing;

  /// No description provided for @commonPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get commonPrevious;

  /// No description provided for @commonPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get commonPrice;

  /// No description provided for @commonProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get commonProducts;

  /// No description provided for @commonQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get commonQty;

  /// No description provided for @commonQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get commonQuantity;

  /// No description provided for @commonReferenceOptional.
  ///
  /// In en, this message translates to:
  /// **'Reference (optional)'**
  String get commonReferenceOptional;

  /// No description provided for @commonRefunds.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get commonRefunds;

  /// No description provided for @commonRegNo.
  ///
  /// In en, this message translates to:
  /// **'Reg no.'**
  String get commonRegNo;

  /// No description provided for @commonRegValue.
  ///
  /// In en, this message translates to:
  /// **'Reg {reg}'**
  String commonRegValue(String reg);

  /// No description provided for @commonRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get commonRemaining;

  /// No description provided for @commonReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get commonReports;

  /// No description provided for @commonRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get commonRequired;

  /// No description provided for @commonRetail.
  ///
  /// In en, this message translates to:
  /// **'Retail'**
  String get commonRetail;

  /// No description provided for @commonSaveOffline.
  ///
  /// In en, this message translates to:
  /// **'Save offline'**
  String get commonSaveOffline;

  /// No description provided for @commonSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get commonSaving;

  /// No description provided for @commonSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get commonSchedule;

  /// No description provided for @commonSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get commonSelect;

  /// No description provided for @commonSelectCustomer.
  ///
  /// In en, this message translates to:
  /// **'Select customer'**
  String get commonSelectCustomer;

  /// No description provided for @commonServeNumber.
  ///
  /// In en, this message translates to:
  /// **'Serve #{number}'**
  String commonServeNumber(String number);

  /// No description provided for @commonServiceInstance.
  ///
  /// In en, this message translates to:
  /// **'Service instance'**
  String get commonServiceInstance;

  /// No description provided for @commonServiceInstanceShort.
  ///
  /// In en, this message translates to:
  /// **'SI {id}'**
  String commonServiceInstanceShort(String id);

  /// No description provided for @commonServiceTax.
  ///
  /// In en, this message translates to:
  /// **'Service tax'**
  String get commonServiceTax;

  /// No description provided for @commonServiceTaxPct.
  ///
  /// In en, this message translates to:
  /// **'Service Tax ({percent}%)'**
  String commonServiceTaxPct(String percent);

  /// No description provided for @commonSettleFullBalance.
  ///
  /// In en, this message translates to:
  /// **'Settle full balance'**
  String get commonSettleFullBalance;

  /// No description provided for @commonSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get commonSettled;

  /// No description provided for @commonSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get commonSkipped;

  /// No description provided for @commonStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get commonStaff;

  /// No description provided for @commonStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commonStatus;

  /// No description provided for @commonStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get commonStore;

  /// No description provided for @commonStoreId.
  ///
  /// In en, this message translates to:
  /// **'Store ID'**
  String get commonStoreId;

  /// No description provided for @commonStoreRole.
  ///
  /// In en, this message translates to:
  /// **'Store role'**
  String get commonStoreRole;

  /// No description provided for @commonSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get commonSubtotal;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get commonSummary;

  /// No description provided for @commonSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get commonSynced;

  /// No description provided for @commonTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get commonTable;

  /// No description provided for @commonTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get commonTax;

  /// No description provided for @commonTips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get commonTips;

  /// No description provided for @commonTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get commonTitleLabel;

  /// No description provided for @commonTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get commonTotal;

  /// No description provided for @commonTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get commonTotalAmount;

  /// No description provided for @commonType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get commonType;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @commonUnnamedCustomer.
  ///
  /// In en, this message translates to:
  /// **'Unnamed customer'**
  String get commonUnnamedCustomer;

  /// No description provided for @commonUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get commonUpi;

  /// No description provided for @commonUseCustomer.
  ///
  /// In en, this message translates to:
  /// **'Use customer'**
  String get commonUseCustomer;

  /// No description provided for @commonView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get commonView;

  /// No description provided for @commonViewAllCount.
  ///
  /// In en, this message translates to:
  /// **'View all ({count})'**
  String commonViewAllCount(int count);

  /// No description provided for @commonVoid.
  ///
  /// In en, this message translates to:
  /// **'Void'**
  String get commonVoid;

  /// No description provided for @commonVoucher.
  ///
  /// In en, this message translates to:
  /// **'Voucher'**
  String get commonVoucher;

  /// No description provided for @commonWalkIn.
  ///
  /// In en, this message translates to:
  /// **'Walk-in'**
  String get commonWalkIn;

  /// No description provided for @commonWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get commonWeekly;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @companyAddSubscriber.
  ///
  /// In en, this message translates to:
  /// **'Add subscriber'**
  String get companyAddSubscriber;

  /// No description provided for @companyAddToBranch.
  ///
  /// In en, this message translates to:
  /// **'Add to branch'**
  String get companyAddToBranch;

  /// No description provided for @companyAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get companyAddress;

  /// No description provided for @companyAllPaymentMethodsAdded.
  ///
  /// In en, this message translates to:
  /// **'All payment methods are already on this branch.'**
  String get companyAllPaymentMethodsAdded;

  /// No description provided for @companyBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get companyBranch;

  /// No description provided for @companyBranchLogo.
  ///
  /// In en, this message translates to:
  /// **'Branch logo'**
  String get companyBranchLogo;

  /// No description provided for @companyBranchStoreName.
  ///
  /// In en, this message translates to:
  /// **'Branch / store name'**
  String get companyBranchStoreName;

  /// No description provided for @companyChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get companyChannel;

  /// No description provided for @companyChannelPush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get companyChannelPush;

  /// No description provided for @companyChannelSlack.
  ///
  /// In en, this message translates to:
  /// **'Slack'**
  String get companyChannelSlack;

  /// No description provided for @companyChannelSms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get companyChannelSms;

  /// No description provided for @companyChannelWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get companyChannelWhatsApp;

  /// No description provided for @companyChooseLogo.
  ///
  /// In en, this message translates to:
  /// **'Choose company logo'**
  String get companyChooseLogo;

  /// No description provided for @companyContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get companyContact;

  /// No description provided for @companyCouldNotAddSubscriber.
  ///
  /// In en, this message translates to:
  /// **'Could not add subscriber.'**
  String get companyCouldNotAddSubscriber;

  /// No description provided for @companyCouldNotLoadReports.
  ///
  /// In en, this message translates to:
  /// **'Could not load reports.'**
  String get companyCouldNotLoadReports;

  /// No description provided for @companyHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get companyHubTitle;

  /// No description provided for @companyIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Identifier'**
  String get companyIdentifier;

  /// No description provided for @companyInvoiceBookings.
  ///
  /// In en, this message translates to:
  /// **'Invoice / bookings'**
  String get companyInvoiceBookings;

  /// No description provided for @companyLabelLocked.
  ///
  /// In en, this message translates to:
  /// **'{label} · locked'**
  String companyLabelLocked(String label);

  /// No description provided for @companyLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get companyLegal;

  /// No description provided for @companyLogo.
  ///
  /// In en, this message translates to:
  /// **'Logo'**
  String get companyLogo;

  /// No description provided for @companyLogoFilePath.
  ///
  /// In en, this message translates to:
  /// **'Logo file path'**
  String get companyLogoFilePath;

  /// No description provided for @companyLogoSavedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device · syncs with Save'**
  String get companyLogoSavedOnDevice;

  /// No description provided for @companyMailerFixedHint.
  ///
  /// In en, this message translates to:
  /// **'Report and invoice/bookings mailers are fixed by Ellan POS. Credentials cannot be changed or added on the tablet.'**
  String get companyMailerFixedHint;

  /// No description provided for @companyMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get companyMethod;

  /// No description provided for @companyNoPaymentMethodsBranch.
  ///
  /// In en, this message translates to:
  /// **'No payment methods on this branch yet. Use Add to branch.'**
  String get companyNoPaymentMethodsBranch;

  /// No description provided for @companyNoPaymentVariants.
  ///
  /// In en, this message translates to:
  /// **'No payment method variants are available from the server.'**
  String get companyNoPaymentVariants;

  /// No description provided for @companyNoSubscribers.
  ///
  /// In en, this message translates to:
  /// **'No subscribers yet.'**
  String get companyNoSubscribers;

  /// No description provided for @companyNoSubscribersYet.
  ///
  /// In en, this message translates to:
  /// **'No subscribers yet.'**
  String get companyNoSubscribersYet;

  /// No description provided for @companyOpenStore.
  ///
  /// In en, this message translates to:
  /// **'Open store'**
  String get companyOpenStore;

  /// No description provided for @companyOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get companyOwner;

  /// No description provided for @companyOwnerSubscriberLocked.
  ///
  /// In en, this message translates to:
  /// **'Owner subscriber cannot be removed.'**
  String get companyOwnerSubscriberLocked;

  /// No description provided for @companyPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get companyPaymentMethod;

  /// No description provided for @companyPaymentMethodAdded.
  ///
  /// In en, this message translates to:
  /// **'{label} added to this branch.'**
  String companyPaymentMethodAdded(String label);

  /// No description provided for @companyPeriodAnnually.
  ///
  /// In en, this message translates to:
  /// **'Annually'**
  String get companyPeriodAnnually;

  /// No description provided for @companyPeriodDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get companyPeriodDaily;

  /// No description provided for @companyPeriodicity.
  ///
  /// In en, this message translates to:
  /// **'Periodicity'**
  String get companyPeriodicity;

  /// No description provided for @companyRegistrationNumber.
  ///
  /// In en, this message translates to:
  /// **'Registration number'**
  String get companyRegistrationNumber;

  /// No description provided for @companyReportsHint.
  ///
  /// In en, this message translates to:
  /// **'Sales report subscribers and schedule'**
  String get companyReportsHint;

  /// No description provided for @companyReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get companyReportsTitle;

  /// No description provided for @companySalesReports.
  ///
  /// In en, this message translates to:
  /// **'Sales reports'**
  String get companySalesReports;

  /// No description provided for @companySalesReportsHint.
  ///
  /// In en, this message translates to:
  /// **'Daily sales summaries are emailed to every enabled subscriber using the system report mailer.'**
  String get companySalesReportsHint;

  /// No description provided for @companySalesReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales reports'**
  String get companySalesReportsTitle;

  /// No description provided for @companySaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get companySaveChanges;

  /// No description provided for @companySavedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device · syncs with Save'**
  String get companySavedOnDevice;

  /// No description provided for @companySettingsNameRegAddress.
  ///
  /// In en, this message translates to:
  /// **'Name, registration, address, tax, phone, email, identifier'**
  String get companySettingsNameRegAddress;

  /// No description provided for @companySettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Company settings saved.'**
  String get companySettingsSaved;

  /// No description provided for @companySettingsSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. Company details will sync when you\'re back online.'**
  String get companySettingsSavedOffline;

  /// No description provided for @companySettingsPendingSync.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet — changes are saved on this device and will upload on the next sync.'**
  String get companySettingsPendingSync;

  /// No description provided for @companySettingsSavedNotSynced.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device, but the server rejected the update: {reason}'**
  String companySettingsSavedNotSynced(String reason);

  /// No description provided for @companySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Company settings'**
  String get companySettingsTitle;

  /// No description provided for @companyStaffsListHint.
  ///
  /// In en, this message translates to:
  /// **'List staff and add new accounts for this store'**
  String get companyStaffsListHint;

  /// No description provided for @companyStaffsTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get companyStaffsTitle;

  /// No description provided for @companyStoreSetupHint.
  ///
  /// In en, this message translates to:
  /// **'Catalogue, offers, add-ons'**
  String get companyStoreSetupHint;

  /// No description provided for @companySubscribers.
  ///
  /// In en, this message translates to:
  /// **'Subscribers'**
  String get companySubscribers;

  /// No description provided for @companySystemEmailLocked.
  ///
  /// In en, this message translates to:
  /// **'System email (locked)'**
  String get companySystemEmailLocked;

  /// No description provided for @companySystemMailerLocked.
  ///
  /// In en, this message translates to:
  /// **'System mailer (locked)'**
  String get companySystemMailerLocked;

  /// No description provided for @companyTapMethodToAdd.
  ///
  /// In en, this message translates to:
  /// **'Tap a method to add'**
  String get companyTapMethodToAdd;

  /// No description provided for @companyTaxRegistrationNumber.
  ///
  /// In en, this message translates to:
  /// **'Tax registration number'**
  String get companyTaxRegistrationNumber;

  /// No description provided for @companyUploadLogo.
  ///
  /// In en, this message translates to:
  /// **'Upload logo'**
  String get companyUploadLogo;

  /// No description provided for @companyUseFile.
  ///
  /// In en, this message translates to:
  /// **'Use file'**
  String get companyUseFile;

  /// No description provided for @companyWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get companyWallet;

  /// No description provided for @creditsAccountCount.
  ///
  /// In en, this message translates to:
  /// **'{count} account(s)'**
  String creditsAccountCount(int count);

  /// No description provided for @creditsAllowedWarn.
  ///
  /// In en, this message translates to:
  /// **'Allowed (warn)'**
  String get creditsAllowedWarn;

  /// No description provided for @creditsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get creditsBlocked;

  /// No description provided for @creditsCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Cancel failed: {error}'**
  String creditsCancelFailed(String error);

  /// No description provided for @creditsCancelScheduleAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel schedule'**
  String get creditsCancelScheduleAction;

  /// No description provided for @creditsCancelScheduleBody.
  ///
  /// In en, this message translates to:
  /// **'Cancel {amount} due {dueDate}?'**
  String creditsCancelScheduleBody(String amount, String dueDate);

  /// No description provided for @creditsCancelScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel scheduled repayment'**
  String get creditsCancelScheduleTitle;

  /// No description provided for @creditsCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get creditsCollect;

  /// No description provided for @creditsCollectPayment.
  ///
  /// In en, this message translates to:
  /// **'Collect payment'**
  String get creditsCollectPayment;

  /// No description provided for @creditsCollectedScheduled.
  ///
  /// In en, this message translates to:
  /// **'Collected scheduled {amount}'**
  String creditsCollectedScheduled(String amount);

  /// No description provided for @creditsCollectedVia.
  ///
  /// In en, this message translates to:
  /// **'Collected {amount} via {mode}'**
  String creditsCollectedVia(String amount, String mode);

  /// No description provided for @creditsCreditAccount.
  ///
  /// In en, this message translates to:
  /// **'Credit account'**
  String get creditsCreditAccount;

  /// No description provided for @creditsCreditLimit.
  ///
  /// In en, this message translates to:
  /// **'Credit limit'**
  String get creditsCreditLimit;

  /// No description provided for @creditsCreditLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Credit limit'**
  String get creditsCreditLimitLabel;

  /// No description provided for @creditsCreditNumber.
  ///
  /// In en, this message translates to:
  /// **'Credit #{id}'**
  String creditsCreditNumber(String id);

  /// No description provided for @creditsCreditOrderLine.
  ///
  /// In en, this message translates to:
  /// **'Credit #{creditId} · Order #{orderId}'**
  String creditsCreditOrderLine(String creditId, String orderId);

  /// No description provided for @creditsCreditSaleOrder.
  ///
  /// In en, this message translates to:
  /// **'Credit sale · Order #{orderId}'**
  String creditsCreditSaleOrder(String orderId);

  /// No description provided for @creditsCreditSalePlain.
  ///
  /// In en, this message translates to:
  /// **'Credit sale'**
  String get creditsCreditSalePlain;

  /// No description provided for @creditsCreditSales.
  ///
  /// In en, this message translates to:
  /// **'Credit sales'**
  String get creditsCreditSales;

  /// No description provided for @creditsCreditSoFar.
  ///
  /// In en, this message translates to:
  /// **'Credit so far'**
  String get creditsCreditSoFar;

  /// No description provided for @creditsCustomerCreditLimit.
  ///
  /// In en, this message translates to:
  /// **'Customer credit limit'**
  String get creditsCustomerCreditLimit;

  /// No description provided for @creditsCustomerLimit.
  ///
  /// In en, this message translates to:
  /// **'Customer credit limit'**
  String get creditsCustomerLimit;

  /// No description provided for @creditsCustomerScopedTitle.
  ///
  /// In en, this message translates to:
  /// **'Credit · {name}'**
  String creditsCustomerScopedTitle(String name);

  /// No description provided for @creditsHardBlock.
  ///
  /// In en, this message translates to:
  /// **'Hard block'**
  String get creditsHardBlock;

  /// No description provided for @creditsInstallments.
  ///
  /// In en, this message translates to:
  /// **'Installments'**
  String get creditsInstallments;

  /// No description provided for @creditsLedgerVoided.
  ///
  /// In en, this message translates to:
  /// **'voided'**
  String get creditsLedgerVoided;

  /// No description provided for @creditsLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get creditsLimit;

  /// No description provided for @creditsMaxAmount.
  ///
  /// In en, this message translates to:
  /// **'Max {amount}'**
  String creditsMaxAmount(String amount);

  /// No description provided for @creditsNetTerms.
  ///
  /// In en, this message translates to:
  /// **'Net terms'**
  String get creditsNetTerms;

  /// No description provided for @creditsNetTermsDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String creditsNetTermsDays(int days);

  /// No description provided for @creditsNoAccountsMatch.
  ///
  /// In en, this message translates to:
  /// **'No accounts match the current filters.'**
  String get creditsNoAccountsMatch;

  /// No description provided for @creditsNoAccountsOnDevice.
  ///
  /// In en, this message translates to:
  /// **'No credit accounts on this device yet.'**
  String get creditsNoAccountsOnDevice;

  /// No description provided for @creditsNoAccountsYet.
  ///
  /// In en, this message translates to:
  /// **'No credit accounts on this device yet.'**
  String get creditsNoAccountsYet;

  /// No description provided for @creditsNoCreditLimitHint.
  ///
  /// In en, this message translates to:
  /// **'No credit limit for this customer. Set credit_limit_amount on Store/CustomerCredit/Account/<id>/ (or store defaults on Store/CustomerCredit/Settings/), then sync credits.'**
  String get creditsNoCreditLimitHint;

  /// No description provided for @creditsNoCreditPayments.
  ///
  /// In en, this message translates to:
  /// **'No credit payments recorded yet.'**
  String get creditsNoCreditPayments;

  /// No description provided for @creditsNoCreditSales.
  ///
  /// In en, this message translates to:
  /// **'No credit sales for this customer.'**
  String get creditsNoCreditSales;

  /// No description provided for @creditsNoLedger.
  ///
  /// In en, this message translates to:
  /// **'No ledger activity yet.'**
  String get creditsNoLedger;

  /// No description provided for @creditsNoOpenScheduled.
  ///
  /// In en, this message translates to:
  /// **'No open scheduled payments.'**
  String get creditsNoOpenScheduled;

  /// No description provided for @creditsNoRepaymentsYet.
  ///
  /// In en, this message translates to:
  /// **'No repayments recorded yet.'**
  String get creditsNoRepaymentsYet;

  /// No description provided for @creditsNoScheduledToday.
  ///
  /// In en, this message translates to:
  /// **'No scheduled payments due today.'**
  String get creditsNoScheduledToday;

  /// No description provided for @creditsNoSchedules.
  ///
  /// In en, this message translates to:
  /// **'No installment schedules on this account.'**
  String get creditsNoSchedules;

  /// No description provided for @creditsNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming repayments scheduled.'**
  String get creditsNoUpcoming;

  /// No description provided for @creditsNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get creditsNotSet;

  /// No description provided for @creditsNothingOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Nothing outstanding for this customer.'**
  String get creditsNothingOutstanding;

  /// No description provided for @creditsOneShot.
  ///
  /// In en, this message translates to:
  /// **'One-shot'**
  String get creditsOneShot;

  /// No description provided for @creditsOpenAccount.
  ///
  /// In en, this message translates to:
  /// **'Open credit account'**
  String get creditsOpenAccount;

  /// No description provided for @creditsOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get creditsOutstanding;

  /// No description provided for @creditsOutstandingAmount.
  ///
  /// In en, this message translates to:
  /// **'Outstanding {amount}'**
  String creditsOutstandingAmount(String amount);

  /// No description provided for @creditsOutstandingOnly.
  ///
  /// In en, this message translates to:
  /// **'Outstanding only'**
  String get creditsOutstandingOnly;

  /// No description provided for @creditsOverLimit.
  ///
  /// In en, this message translates to:
  /// **'Over-limit'**
  String get creditsOverLimit;

  /// No description provided for @creditsOverLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Over-limit'**
  String get creditsOverLimitLabel;

  /// No description provided for @creditsPaymentSchedules.
  ///
  /// In en, this message translates to:
  /// **'Payment schedules'**
  String get creditsPaymentSchedules;

  /// No description provided for @creditsRepaid.
  ///
  /// In en, this message translates to:
  /// **'Repaid'**
  String get creditsRepaid;

  /// No description provided for @creditsRepaymentMode.
  ///
  /// In en, this message translates to:
  /// **'Repayment · {mode}'**
  String creditsRepaymentMode(String mode);

  /// No description provided for @creditsRepaymentVoided.
  ///
  /// In en, this message translates to:
  /// **'Repayment voided.'**
  String get creditsRepaymentVoided;

  /// No description provided for @creditsScheduleBody.
  ///
  /// In en, this message translates to:
  /// **'Record an upcoming payment promise from this customer.'**
  String get creditsScheduleBody;

  /// No description provided for @creditsSchedulePayments.
  ///
  /// In en, this message translates to:
  /// **'Schedule payments'**
  String get creditsSchedulePayments;

  /// No description provided for @creditsScheduleRepayment.
  ///
  /// In en, this message translates to:
  /// **'Schedule repayment'**
  String get creditsScheduleRepayment;

  /// No description provided for @creditsScheduledFor.
  ///
  /// In en, this message translates to:
  /// **'Scheduled {amount} for {dueDate}'**
  String creditsScheduledFor(String amount, String dueDate);

  /// No description provided for @creditsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search customer name or id'**
  String get creditsSearchHint;

  /// No description provided for @creditsSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get creditsSort;

  /// No description provided for @creditsSortHighest.
  ///
  /// In en, this message translates to:
  /// **'Highest'**
  String get creditsSortHighest;

  /// No description provided for @creditsSortLongPending.
  ///
  /// In en, this message translates to:
  /// **'Long pending'**
  String get creditsSortLongPending;

  /// No description provided for @creditsStoreCreditSettings.
  ///
  /// In en, this message translates to:
  /// **'Store credit settings'**
  String get creditsStoreCreditSettings;

  /// No description provided for @creditsStoreSettings.
  ///
  /// In en, this message translates to:
  /// **'Store credit settings'**
  String get creditsStoreSettings;

  /// No description provided for @creditsTitle.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get creditsTitle;

  /// No description provided for @creditsTodayScheduled.
  ///
  /// In en, this message translates to:
  /// **'Today\'s scheduled payments'**
  String get creditsTodayScheduled;

  /// No description provided for @creditsUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming repayments'**
  String get creditsUpcoming;

  /// No description provided for @creditsUsedAvailable.
  ///
  /// In en, this message translates to:
  /// **'Used {used} · Available {available}'**
  String creditsUsedAvailable(String used, String available);

  /// No description provided for @creditsView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get creditsView;

  /// No description provided for @creditsVoidRepaymentBody.
  ///
  /// In en, this message translates to:
  /// **'Void {amount} paid on {date}?'**
  String creditsVoidRepaymentBody(String amount, String date);

  /// No description provided for @creditsVoidRepaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Void repayment'**
  String get creditsVoidRepaymentTitle;

  /// No description provided for @creditsVoidedOnPos.
  ///
  /// In en, this message translates to:
  /// **'Voided on POS tablet'**
  String get creditsVoidedOnPos;

  /// No description provided for @creditsWarnOnly.
  ///
  /// In en, this message translates to:
  /// **'Warn only'**
  String get creditsWarnOnly;

  /// No description provided for @customerAdvanceAdd.
  ///
  /// In en, this message translates to:
  /// **'Add customer advance'**
  String get customerAdvanceAdd;

  /// No description provided for @customerAdvanceAvailable.
  ///
  /// In en, this message translates to:
  /// **'Advance available'**
  String get customerAdvanceAvailable;

  /// No description provided for @customerAdvanceAvailableValue.
  ///
  /// In en, this message translates to:
  /// **'Advance available: {amount}'**
  String customerAdvanceAvailableValue(String amount);

  /// No description provided for @customerAdvanceExplanation.
  ///
  /// In en, this message translates to:
  /// **'Money received is applied to any balance due first. The remainder stays available for future sales.'**
  String get customerAdvanceExplanation;

  /// No description provided for @customerAdvanceRecord.
  ///
  /// In en, this message translates to:
  /// **'Record advance'**
  String get customerAdvanceRecord;

  /// No description provided for @customerAdvanceRecorded.
  ///
  /// In en, this message translates to:
  /// **'Customer advance recorded.'**
  String get customerAdvanceRecorded;

  /// No description provided for @customerBalanceDue.
  ///
  /// In en, this message translates to:
  /// **'Balance due'**
  String get customerBalanceDue;

  /// No description provided for @customerBalanceDueValue.
  ///
  /// In en, this message translates to:
  /// **'Balance due: {amount}'**
  String customerBalanceDueValue(String amount);

  /// No description provided for @customerCouldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save customer'**
  String get customerCouldNotSave;

  /// No description provided for @customerCreditHistory.
  ///
  /// In en, this message translates to:
  /// **'Credit history'**
  String get customerCreditHistory;

  /// No description provided for @customerEmailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get customerEmailOptional;

  /// No description provided for @customerEnterValidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit phone'**
  String get customerEnterValidPhone;

  /// No description provided for @customerNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get customerNameOptional;

  /// No description provided for @customerNoCreditPaymentsYet.
  ///
  /// In en, this message translates to:
  /// **'No credit payments recorded yet.'**
  String get customerNoCreditPaymentsYet;

  /// No description provided for @customerNoCreditSalesYet.
  ///
  /// In en, this message translates to:
  /// **'No credit sales for this customer yet.'**
  String get customerNoCreditSalesYet;

  /// No description provided for @customerNoOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No orders for this customer yet.'**
  String get customerNoOrdersYet;

  /// No description provided for @customerOrderHistory.
  ///
  /// In en, this message translates to:
  /// **'Order history'**
  String get customerOrderHistory;

  /// No description provided for @customerProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer profile'**
  String get customerProfileTitle;

  /// No description provided for @customerSaveContinue.
  ///
  /// In en, this message translates to:
  /// **'Save & continue'**
  String get customerSaveContinue;

  /// No description provided for @customerSearchHintFull.
  ///
  /// In en, this message translates to:
  /// **'Search phone, email, or name'**
  String get customerSearchHintFull;

  /// No description provided for @customerSelectOrAdd.
  ///
  /// In en, this message translates to:
  /// **'Select or add a customer to continue'**
  String get customerSelectOrAdd;

  /// No description provided for @customerSelectSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search customers'**
  String get customerSelectSearchHint;

  /// No description provided for @customersBackToSearch.
  ///
  /// In en, this message translates to:
  /// **'Back to search'**
  String get customersBackToSearch;

  /// No description provided for @customersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No retail or business customers for this store yet. Add them under Retail Customers / Business Customers, then sync.'**
  String get customersEmpty;

  /// No description provided for @customersNew.
  ///
  /// In en, this message translates to:
  /// **'New customer'**
  String get customersNew;

  /// No description provided for @customersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, phone, or email'**
  String get customersSearchHint;

  /// No description provided for @customersTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customersTitle;

  /// No description provided for @dashboardCreditAmount.
  ///
  /// In en, this message translates to:
  /// **'Credit amount'**
  String get dashboardCreditAmount;

  /// No description provided for @dashboardCreditOrders.
  ///
  /// In en, this message translates to:
  /// **'Credit Orders'**
  String get dashboardCreditOrders;

  /// No description provided for @dashboardCreditOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Credit outstanding'**
  String get dashboardCreditOutstanding;

  /// No description provided for @dashboardCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get dashboardCredits;

  /// No description provided for @dashboardFilterMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get dashboardFilterMonth;

  /// No description provided for @dashboardFilterToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashboardFilterToday;

  /// No description provided for @dashboardFilterWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get dashboardFilterWeek;

  /// No description provided for @dashboardFilterYear.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get dashboardFilterYear;

  /// No description provided for @dashboardFilterYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dashboardFilterYesterday;

  /// No description provided for @dashboardMetricCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get dashboardMetricCancelled;

  /// No description provided for @dashboardMetricDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get dashboardMetricDelivered;

  /// No description provided for @dashboardMetricDineIn.
  ///
  /// In en, this message translates to:
  /// **'Dine-In'**
  String get dashboardMetricDineIn;

  /// No description provided for @dashboardMetricOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get dashboardMetricOrders;

  /// No description provided for @dashboardMetricPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get dashboardMetricPickup;

  /// No description provided for @dashboardMetricTotalSales.
  ///
  /// In en, this message translates to:
  /// **'Total Sales'**
  String get dashboardMetricTotalSales;

  /// No description provided for @dashboardNoCategorySales.
  ///
  /// In en, this message translates to:
  /// **'No category sales yet'**
  String get dashboardNoCategorySales;

  /// No description provided for @dashboardNoOpenCredits.
  ///
  /// In en, this message translates to:
  /// **'No open credits'**
  String get dashboardNoOpenCredits;

  /// No description provided for @dashboardNoPaymentsYet.
  ///
  /// In en, this message translates to:
  /// **'No payments yet'**
  String get dashboardNoPaymentsYet;

  /// No description provided for @dashboardNoProductSales.
  ///
  /// In en, this message translates to:
  /// **'No product sales yet'**
  String get dashboardNoProductSales;

  /// No description provided for @dashboardNoSalesYet.
  ///
  /// In en, this message translates to:
  /// **'No sales in this period'**
  String get dashboardNoSalesYet;

  /// No description provided for @dashboardNoStaffSales.
  ///
  /// In en, this message translates to:
  /// **'No staff sales in this period.'**
  String get dashboardNoStaffSales;

  /// No description provided for @dashboardOpenCredits.
  ///
  /// In en, this message translates to:
  /// **'Open credits'**
  String get dashboardOpenCredits;

  /// No description provided for @dashboardOrderCount.
  ///
  /// In en, this message translates to:
  /// **'Order count'**
  String get dashboardOrderCount;

  /// No description provided for @dashboardOrderTotal.
  ///
  /// In en, this message translates to:
  /// **'Order total'**
  String get dashboardOrderTotal;

  /// No description provided for @dashboardPaymentMix.
  ///
  /// In en, this message translates to:
  /// **'Payment mix'**
  String get dashboardPaymentMix;

  /// No description provided for @dashboardPaymentTypes.
  ///
  /// In en, this message translates to:
  /// **'Payment Types'**
  String get dashboardPaymentTypes;

  /// No description provided for @dashboardRefunds.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get dashboardRefunds;

  /// No description provided for @dashboardRepayments.
  ///
  /// In en, this message translates to:
  /// **'Repayments'**
  String get dashboardRepayments;

  /// No description provided for @dashboardSalesByStaff.
  ///
  /// In en, this message translates to:
  /// **'Sales by staff'**
  String get dashboardSalesByStaff;

  /// No description provided for @dashboardSalesTrend.
  ///
  /// In en, this message translates to:
  /// **'Sales trend'**
  String get dashboardSalesTrend;

  /// No description provided for @dashboardSoldCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sold'**
  String dashboardSoldCount(int count);

  /// No description provided for @dashboardStaffSalesHint.
  ///
  /// In en, this message translates to:
  /// **'Orders · amount · credit by checkout staff'**
  String get dashboardStaffSalesHint;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'POS Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardTopCategories.
  ///
  /// In en, this message translates to:
  /// **'Top Categories'**
  String get dashboardTopCategories;

  /// No description provided for @dashboardTopProducts.
  ///
  /// In en, this message translates to:
  /// **'Top Products'**
  String get dashboardTopProducts;

  /// No description provided for @deviceAutoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto sync'**
  String get deviceAutoSync;

  /// No description provided for @deviceAutoSyncEnabled.
  ///
  /// In en, this message translates to:
  /// **'Auto sync enabled — {interval}'**
  String deviceAutoSyncEnabled(String interval);

  /// No description provided for @deviceAutoSyncOff.
  ///
  /// In en, this message translates to:
  /// **'Auto sync turned off'**
  String get deviceAutoSyncOff;

  /// No description provided for @deviceAutoSyncRunning.
  ///
  /// In en, this message translates to:
  /// **'Running in the background'**
  String get deviceAutoSyncRunning;

  /// No description provided for @deviceAutoSyncStarting.
  ///
  /// In en, this message translates to:
  /// **'Running in the background (starting…)'**
  String get deviceAutoSyncStarting;

  /// No description provided for @deviceCashDenominations.
  ///
  /// In en, this message translates to:
  /// **'Cash denominations'**
  String get deviceCashDenominations;

  /// No description provided for @deviceCashDenomsHint.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated tender chips shown on Billing & Payment.'**
  String get deviceCashDenomsHint;

  /// No description provided for @deviceCashDenomsSaved.
  ///
  /// In en, this message translates to:
  /// **'Cash denominations saved.'**
  String get deviceCashDenomsSaved;

  /// No description provided for @deviceCompanySettingsStaff.
  ///
  /// In en, this message translates to:
  /// **'Company (settings & staff)'**
  String get deviceCompanySettingsStaff;

  /// No description provided for @deviceDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get deviceDangerZone;

  /// No description provided for @deviceEnableAutoSync.
  ///
  /// In en, this message translates to:
  /// **'Enable auto sync'**
  String get deviceEnableAutoSync;

  /// No description provided for @deviceInterval15Min.
  ///
  /// In en, this message translates to:
  /// **'Every 15 minutes'**
  String get deviceInterval15Min;

  /// No description provided for @deviceInterval1Hour.
  ///
  /// In en, this message translates to:
  /// **'Every 1 hour'**
  String get deviceInterval1Hour;

  /// No description provided for @deviceInterval1Min.
  ///
  /// In en, this message translates to:
  /// **'Every 1 minute'**
  String get deviceInterval1Min;

  /// No description provided for @deviceInterval30Min.
  ///
  /// In en, this message translates to:
  /// **'Every 30 minutes'**
  String get deviceInterval30Min;

  /// No description provided for @deviceInterval5Min.
  ///
  /// In en, this message translates to:
  /// **'Every 5 minutes'**
  String get deviceInterval5Min;

  /// No description provided for @deviceIntervalEveryMinutes.
  ///
  /// In en, this message translates to:
  /// **'Every {minutes} minutes'**
  String deviceIntervalEveryMinutes(int minutes);

  /// No description provided for @deviceIntervalEverySeconds.
  ///
  /// In en, this message translates to:
  /// **'Every {seconds} seconds'**
  String deviceIntervalEverySeconds(int seconds);

  /// No description provided for @deviceKeepSavedServerUrls.
  ///
  /// In en, this message translates to:
  /// **'Keep saved server URLs'**
  String get deviceKeepSavedServerUrls;

  /// No description provided for @deviceKeepSavedServers.
  ///
  /// In en, this message translates to:
  /// **'Keep saved server URLs'**
  String get deviceKeepSavedServers;

  /// No description provided for @deviceLastOnlineLogin.
  ///
  /// In en, this message translates to:
  /// **'Last online login'**
  String get deviceLastOnlineLogin;

  /// No description provided for @deviceLastSuccessfulSync.
  ///
  /// In en, this message translates to:
  /// **'Last successful sync'**
  String get deviceLastSuccessfulSync;

  /// No description provided for @deviceLeaseDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String deviceLeaseDaysCount(int count);

  /// No description provided for @deviceLeaseOneDay.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get deviceLeaseOneDay;

  /// No description provided for @deviceLoginLease.
  ///
  /// In en, this message translates to:
  /// **'Login lease'**
  String get deviceLoginLease;

  /// No description provided for @deviceLoginLeaseDays.
  ///
  /// In en, this message translates to:
  /// **'Login lease days'**
  String get deviceLoginLeaseDays;

  /// No description provided for @deviceOnlineSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Online sign-in required'**
  String get deviceOnlineSignInRequired;

  /// No description provided for @deviceOpenSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Open sync now'**
  String get deviceOpenSyncNow;

  /// No description provided for @deviceResetAction.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get deviceResetAction;

  /// No description provided for @deviceResetAllLocal.
  ///
  /// In en, this message translates to:
  /// **'Reset all local data'**
  String get deviceResetAllLocal;

  /// No description provided for @deviceResetConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes local orders, catalogue, customers, sync history, device approval flags, and login on this tablet. It does not delete anything on the server.'**
  String get deviceResetConfirmBody;

  /// No description provided for @deviceResetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset all local data?'**
  String get deviceResetConfirmTitle;

  /// No description provided for @deviceResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Reset failed: {error}'**
  String deviceResetFailed(String error);

  /// No description provided for @deviceResetLocalBody.
  ///
  /// In en, this message translates to:
  /// **'Wipe this tablet’s offline database, device setup, login, and sync history so you can test from a clean first launch.'**
  String get deviceResetLocalBody;

  /// No description provided for @deviceResetting.
  ///
  /// In en, this message translates to:
  /// **'Resetting…'**
  String get deviceResetting;

  /// No description provided for @deviceSaveDenominations.
  ///
  /// In en, this message translates to:
  /// **'Save denominations'**
  String get deviceSaveDenominations;

  /// No description provided for @deviceSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Device settings'**
  String get deviceSettingsTitle;

  /// No description provided for @deviceSyncHistory.
  ///
  /// In en, this message translates to:
  /// **'Sync history (last 20)'**
  String get deviceSyncHistory;

  /// No description provided for @deviceSyncInterval.
  ///
  /// In en, this message translates to:
  /// **'Sync interval'**
  String get deviceSyncInterval;

  /// No description provided for @deviceSyncOnTapOnly.
  ///
  /// In en, this message translates to:
  /// **'Only sync when you tap Sync'**
  String get deviceSyncOnTapOnly;

  /// No description provided for @deviceTypeResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type RESET to confirm'**
  String get deviceTypeResetConfirm;

  /// No description provided for @deviceTypeResetToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type RESET to confirm'**
  String get deviceTypeResetToConfirm;

  /// No description provided for @deviceValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get deviceValidUntil;

  /// No description provided for @dineInFloorFirst.
  ///
  /// In en, this message translates to:
  /// **'First Floor'**
  String get dineInFloorFirst;

  /// No description provided for @dineInBooked.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get dineInBooked;

  /// No description provided for @dineInTableUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This table is no longer available. Please select another table.'**
  String get dineInTableUnavailable;

  /// No description provided for @dineInNoTables.
  ///
  /// In en, this message translates to:
  /// **'No tables configured. Sync or configure the store\'s floors and tables.'**
  String get dineInNoTables;

  /// No description provided for @dineInRefreshTables.
  ///
  /// In en, this message translates to:
  /// **'Refresh table availability'**
  String get dineInRefreshTables;

  /// No description provided for @dineInFloorSecond.
  ///
  /// In en, this message translates to:
  /// **'Second Floor'**
  String get dineInFloorSecond;

  /// No description provided for @dineInTable.
  ///
  /// In en, this message translates to:
  /// **'Table {number}'**
  String dineInTable(String number);

  /// No description provided for @errorAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied. Ask an administrator to check this device and account.'**
  String get errorAccessDenied;

  /// No description provided for @errorAmountExceedsOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Amount cannot exceed outstanding ({amount}).'**
  String errorAmountExceedsOutstanding(String amount);

  /// No description provided for @errorBootstrapFailed.
  ///
  /// In en, this message translates to:
  /// **'Bootstrap failed'**
  String get errorBootstrapFailed;

  /// No description provided for @errorCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Cancel failed: {error}'**
  String errorCancelFailed(String error);

  /// No description provided for @errorCannotReachServer.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach server. Check your connection and Server.'**
  String get errorCannotReachServer;

  /// No description provided for @errorCatalogueExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Catalogue export failed: {message}'**
  String errorCatalogueExportFailed(String message);

  /// No description provided for @errorCheckoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Checkout failed: {error}'**
  String errorCheckoutFailed(String error);

  /// No description provided for @errorCollectFailed.
  ///
  /// In en, this message translates to:
  /// **'Collect failed: {error}'**
  String errorCollectFailed(String error);

  /// No description provided for @errorConfigLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Config lookup failed'**
  String get errorConfigLookupFailed;

  /// No description provided for @errorCouldNotAddPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Could not add payment method.'**
  String get errorCouldNotAddPaymentMethod;

  /// No description provided for @errorCouldNotAddSubscriber.
  ///
  /// In en, this message translates to:
  /// **'Could not add subscriber.'**
  String get errorCouldNotAddSubscriber;

  /// No description provided for @errorCouldNotCancel.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel: {error}'**
  String errorCouldNotCancel(String error);

  /// No description provided for @errorCouldNotDeleteDraft.
  ///
  /// In en, this message translates to:
  /// **'Could not delete draft: {error}'**
  String errorCouldNotDeleteDraft(String error);

  /// No description provided for @errorCouldNotLoadCompanySettings.
  ///
  /// In en, this message translates to:
  /// **'Could not load company settings.'**
  String get errorCouldNotLoadCompanySettings;

  /// No description provided for @errorCouldNotLoadReports.
  ///
  /// In en, this message translates to:
  /// **'Could not load reports.'**
  String get errorCouldNotLoadReports;

  /// No description provided for @errorCouldNotLoadStaff.
  ///
  /// In en, this message translates to:
  /// **'Could not load staff.'**
  String get errorCouldNotLoadStaff;

  /// No description provided for @errorCouldNotOpenDraft.
  ///
  /// In en, this message translates to:
  /// **'Could not open draft: {error}'**
  String errorCouldNotOpenDraft(String error);

  /// No description provided for @errorCouldNotPickLogo.
  ///
  /// In en, this message translates to:
  /// **'Could not pick logo. Fully restart the app (stop + run), then try again.'**
  String get errorCouldNotPickLogo;

  /// No description provided for @errorCouldNotSaveCompanySettings.
  ///
  /// In en, this message translates to:
  /// **'Could not save company settings.'**
  String get errorCouldNotSaveCompanySettings;

  /// No description provided for @errorCouldNotSaveDenoms.
  ///
  /// In en, this message translates to:
  /// **'Could not save denominations: {error}'**
  String errorCouldNotSaveDenoms(String error);

  /// No description provided for @errorCouldNotSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Could not save draft: {error}'**
  String errorCouldNotSaveDraft(String error);

  /// No description provided for @errorCouldNotSync.
  ///
  /// In en, this message translates to:
  /// **'Could not sync. Try again.'**
  String get errorCouldNotSync;

  /// No description provided for @errorCouldNotUseCustomer.
  ///
  /// In en, this message translates to:
  /// **'Could not use that customer. Try again.'**
  String get errorCouldNotUseCustomer;

  /// No description provided for @errorCreditRequiresCustomer.
  ///
  /// In en, this message translates to:
  /// **'Credit requires a saved customer. Try again.'**
  String get errorCreditRequiresCustomer;

  /// No description provided for @errorDbNeedsUpdate.
  ///
  /// In en, this message translates to:
  /// **'Local database needs an update. Fully restart the app, then try Sync again.'**
  String get errorDbNeedsUpdate;

  /// No description provided for @errorDbOutdated.
  ///
  /// In en, this message translates to:
  /// **'Local database is outdated ({detail}). Fully restart the app, then Sync again.'**
  String errorDbOutdated(String detail);

  /// No description provided for @errorFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found.'**
  String get errorFileNotFound;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorHttpFallback.
  ///
  /// In en, this message translates to:
  /// **'{fallback} (HTTP {statusCode})'**
  String errorHttpFallback(String fallback, int statusCode);

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials'**
  String get errorInvalidCredentials;

  /// No description provided for @errorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get errorInvalidEmail;

  /// No description provided for @errorInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Must be exactly 10 digits'**
  String get errorInvalidPhone;

  /// No description provided for @errorNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum 3 characters'**
  String get errorNameMinLength;

  /// No description provided for @errorNamePackageUnitPriceRequired.
  ///
  /// In en, this message translates to:
  /// **'Name, package, unit and price are required'**
  String get errorNamePackageUnitPriceRequired;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach server'**
  String get errorNetwork;

  /// No description provided for @errorNoCachedPosConfig.
  ///
  /// In en, this message translates to:
  /// **'No cached POS config for \"{orgCode}\". Complete device setup first.'**
  String errorNoCachedPosConfig(String orgCode);

  /// No description provided for @errorOrderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order #{orderId} was not found.'**
  String errorOrderNotFound(int orderId);

  /// No description provided for @errorOrganisationNotFound.
  ///
  /// In en, this message translates to:
  /// **'Organisation not found'**
  String get errorOrganisationNotFound;

  /// No description provided for @errorParentOrgNotFound.
  ///
  /// In en, this message translates to:
  /// **'Parent organisation was not found.'**
  String get errorParentOrgNotFound;

  /// No description provided for @errorPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed: {error}'**
  String errorPaymentFailed(String error);

  /// No description provided for @errorRefundFailed.
  ///
  /// In en, this message translates to:
  /// **'Refund failed: {error}'**
  String errorRefundFailed(String error);

  /// No description provided for @errorRequiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get errorRequiredField;

  /// No description provided for @errorScheduleFailed.
  ///
  /// In en, this message translates to:
  /// **'Schedule failed: {error}'**
  String errorScheduleFailed(String error);

  /// No description provided for @errorSecureConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Secure connection failed. Check the server address and try again.'**
  String get errorSecureConnectionFailed;

  /// No description provided for @errorSelectCustomerForCredit.
  ///
  /// In en, this message translates to:
  /// **'Select a customer to put the balance on credit.'**
  String get errorSelectCustomerForCredit;

  /// No description provided for @errorSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Check your email and password, then try again.'**
  String get errorSignInFailed;

  /// No description provided for @errorSignInOnlineFirst.
  ///
  /// In en, this message translates to:
  /// **'Sign in online first to update company settings.'**
  String get errorSignInOnlineFirst;

  /// No description provided for @errorSignupFailed.
  ///
  /// In en, this message translates to:
  /// **'Signup failed.'**
  String get errorSignupFailed;

  /// No description provided for @errorSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String errorSyncFailed(String error);

  /// No description provided for @errorUnableLoadSignupOptions.
  ///
  /// In en, this message translates to:
  /// **'Unable to load signup options'**
  String get errorUnableLoadSignupOptions;

  /// No description provided for @errorVoidFailed.
  ///
  /// In en, this message translates to:
  /// **'Void failed: {error}'**
  String errorVoidFailed(String error);

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'{message}: {error}'**
  String errorWithMessage(String message, String error);

  /// No description provided for @errorWithStatus.
  ///
  /// In en, this message translates to:
  /// **'{fallback} ({statusCode})'**
  String errorWithStatus(String fallback, String statusCode);

  /// No description provided for @forgotPasswordBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get forgotPasswordBackToSignIn;

  /// No description provided for @forgotPasswordInstruction.
  ///
  /// In en, this message translates to:
  /// **'Please enter your registered Email address or Phone Number.'**
  String get forgotPasswordInstruction;

  /// No description provided for @forgotPasswordSendLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get forgotPasswordSendLink;

  /// No description provided for @forgotPasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent to your registered address!'**
  String get forgotPasswordSuccess;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordTitle;

  /// No description provided for @homeActivityPrompt.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do today?'**
  String get homeActivityPrompt;

  /// No description provided for @homeCatalogs.
  ///
  /// In en, this message translates to:
  /// **'Catalogs'**
  String get homeCatalogs;

  /// No description provided for @homeCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get homeCompany;

  /// No description provided for @homeCreateOrder.
  ///
  /// In en, this message translates to:
  /// **'New Order'**
  String get homeCreateOrder;

  /// No description provided for @homeCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get homeCredits;

  /// No description provided for @homeCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get homeCustomers;

  /// No description provided for @homeDashboardDesc.
  ///
  /// In en, this message translates to:
  /// **'View analytics and summary'**
  String get homeDashboardDesc;

  /// No description provided for @homeDeviceSettings.
  ///
  /// In en, this message translates to:
  /// **'Device settings'**
  String get homeDeviceSettings;

  /// No description provided for @homeDraftOrders.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get homeDraftOrders;

  /// No description provided for @homeLogoutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get homeLogoutTooltip;

  /// No description provided for @homeMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get homeMenu;

  /// No description provided for @homeNewOrderCount.
  ///
  /// In en, this message translates to:
  /// **'New Order ({count})'**
  String homeNewOrderCount(int count);

  /// No description provided for @homeNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items'**
  String get homeNoItems;

  /// No description provided for @homeNoSavedDrafts.
  ///
  /// In en, this message translates to:
  /// **'No saved drafts yet.'**
  String get homeNoSavedDrafts;

  /// No description provided for @homeOpenStoreFirst.
  ///
  /// In en, this message translates to:
  /// **'Open a store first'**
  String get homeOpenStoreFirst;

  /// No description provided for @homeOrdersList.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get homeOrdersList;

  /// No description provided for @homeOrdersListDesc.
  ///
  /// In en, this message translates to:
  /// **'View and manage all orders'**
  String get homeOrdersListDesc;

  /// No description provided for @homePosDashboard.
  ///
  /// In en, this message translates to:
  /// **'POS Dashboard'**
  String get homePosDashboard;

  /// No description provided for @homeRefunds.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get homeRefunds;

  /// No description provided for @homeSavedDrafts.
  ///
  /// In en, this message translates to:
  /// **'Saved drafts'**
  String get homeSavedDrafts;

  /// No description provided for @homeStoreAdminRequiredCompany.
  ///
  /// In en, this message translates to:
  /// **'Store Admin access required for Company.'**
  String get homeStoreAdminRequiredCompany;

  /// No description provided for @homeStoreAdminRequiredSetup.
  ///
  /// In en, this message translates to:
  /// **'Store Admin access required for Store setup.'**
  String get homeStoreAdminRequiredSetup;

  /// No description provided for @homeStoreSetup.
  ///
  /// In en, this message translates to:
  /// **'Store setup'**
  String get homeStoreSetup;

  /// No description provided for @homeSyncFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Sync failed — tap to retry'**
  String get homeSyncFailedRetry;

  /// No description provided for @homeSyncTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get homeSyncTooltip;

  /// No description provided for @homeViewAllCount.
  ///
  /// In en, this message translates to:
  /// **'View all ({count})'**
  String homeViewAllCount(int count);

  /// No description provided for @homeWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get homeWelcomeBack;

  /// No description provided for @invoiceAmountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get invoiceAmountPaid;

  /// No description provided for @invoiceMethod.
  ///
  /// In en, this message translates to:
  /// **'Method: {method}'**
  String invoiceMethod(String method);

  /// No description provided for @invoiceOrderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order summary'**
  String get invoiceOrderSummary;

  /// No description provided for @invoicePrinting.
  ///
  /// In en, this message translates to:
  /// **'Printing to thermal printer…'**
  String get invoicePrinting;

  /// No description provided for @invoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice / Receipt'**
  String get invoiceTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageTamil.
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get languageTamil;

  /// No description provided for @orderAddRecordPayment.
  ///
  /// In en, this message translates to:
  /// **'Add / Record payment'**
  String get orderAddRecordPayment;

  /// No description provided for @orderAddonsLabel.
  ///
  /// In en, this message translates to:
  /// **'Add-ons: {labels}'**
  String orderAddonsLabel(String labels);

  /// No description provided for @orderAllItemsSentKitchen.
  ///
  /// In en, this message translates to:
  /// **'All items already sent to kitchen.'**
  String get orderAllItemsSentKitchen;

  /// No description provided for @orderAlreadyFullyPaid.
  ///
  /// In en, this message translates to:
  /// **'This order is already fully paid.'**
  String get orderAlreadyFullyPaid;

  /// No description provided for @orderAlreadyFullyRefunded.
  ///
  /// In en, this message translates to:
  /// **'This payment is already fully refunded.'**
  String get orderAlreadyFullyRefunded;

  /// No description provided for @orderAppliedOffers.
  ///
  /// In en, this message translates to:
  /// **'Applied offers'**
  String get orderAppliedOffers;

  /// No description provided for @orderCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Mark this order as Cancelled?'**
  String get orderCancelConfirm;

  /// No description provided for @orderCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get orderCancelTitle;

  /// No description provided for @orderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled.'**
  String get orderCancelled;

  /// No description provided for @orderCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get orderCancelledTitle;

  /// No description provided for @orderChartPoint.
  ///
  /// In en, this message translates to:
  /// **'{label}\n{amount}\n{count} orders'**
  String orderChartPoint(String label, String amount, int count);

  /// No description provided for @orderClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear Filter'**
  String get orderClearFilter;

  /// No description provided for @orderCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get orderCompleted;

  /// No description provided for @orderCouldNotOpenDraft.
  ///
  /// In en, this message translates to:
  /// **'Could not open draft: {error}'**
  String orderCouldNotOpenDraft(String error);

  /// No description provided for @orderCreateAddItemsBeforeDraft.
  ///
  /// In en, this message translates to:
  /// **'Add items before saving a draft.'**
  String get orderCreateAddItemsBeforeDraft;

  /// No description provided for @orderCreateAddMiscItem.
  ///
  /// In en, this message translates to:
  /// **'Add misc item'**
  String get orderCreateAddMiscItem;

  /// No description provided for @orderCreateAllItemsSentKitchen.
  ///
  /// In en, this message translates to:
  /// **'All items already sent to kitchen.'**
  String get orderCreateAllItemsSentKitchen;

  /// No description provided for @orderCreateCartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get orderCreateCartEmpty;

  /// No description provided for @orderCreateDeleteDraftBody.
  ///
  /// In en, this message translates to:
  /// **'This clears the cart and removes the saved draft.'**
  String get orderCreateDeleteDraftBody;

  /// No description provided for @orderCreateDraftDeleted.
  ///
  /// In en, this message translates to:
  /// **'Draft deleted.'**
  String get orderCreateDraftDeleted;

  /// No description provided for @orderCreateDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved.'**
  String get orderCreateDraftSaved;

  /// No description provided for @orderCreateEnterValidPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price'**
  String get orderCreateEnterValidPrice;

  /// No description provided for @orderCreateFloorTable.
  ///
  /// In en, this message translates to:
  /// **'Floor: {floor} | Table: {table}'**
  String orderCreateFloorTable(String floor, String table);

  /// No description provided for @orderCreateHistoryRefreshed.
  ///
  /// In en, this message translates to:
  /// **'History refreshed'**
  String get orderCreateHistoryRefreshed;

  /// No description provided for @orderCreateHowMany.
  ///
  /// In en, this message translates to:
  /// **'How many {unit}?'**
  String orderCreateHowMany(String unit);

  /// No description provided for @orderCreateKotFailed.
  ///
  /// In en, this message translates to:
  /// **'KOT failed: {error}'**
  String orderCreateKotFailed(String error);

  /// No description provided for @orderCreateKotSent.
  ///
  /// In en, this message translates to:
  /// **'KOT #{batch} sent · Order #{orderId} saved'**
  String orderCreateKotSent(int batch, int orderId);

  /// No description provided for @orderCreateMisc.
  ///
  /// In en, this message translates to:
  /// **'Misc'**
  String get orderCreateMisc;

  /// No description provided for @orderCreateNewOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'New {orderType} order'**
  String orderCreateNewOrderTitle(String orderType);

  /// No description provided for @orderCreateNoOrderHistory.
  ///
  /// In en, this message translates to:
  /// **'No order history yet'**
  String get orderCreateNoOrderHistory;

  /// No description provided for @orderCreatePastOrders.
  ///
  /// In en, this message translates to:
  /// **'Past orders'**
  String get orderCreatePastOrders;

  /// No description provided for @orderCreateProductName.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get orderCreateProductName;

  /// No description provided for @orderCreateQuantityUnit.
  ///
  /// In en, this message translates to:
  /// **'Quantity ({unit})'**
  String orderCreateQuantityUnit(String unit);

  /// No description provided for @orderCreateSaveDraftTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save cart draft (Home drafts, not Purchases list)'**
  String get orderCreateSaveDraftTooltip;

  /// No description provided for @orderCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get orderCreateTitle;

  /// No description provided for @orderCreationSaveContinue.
  ///
  /// In en, this message translates to:
  /// **'Save & continue'**
  String get orderCreationSaveContinue;

  /// No description provided for @orderDeleteDraft.
  ///
  /// In en, this message translates to:
  /// **'Delete draft'**
  String get orderDeleteDraft;

  /// No description provided for @orderDeleteDraftConfirm.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete this draft order? This cannot be undone.'**
  String get orderDeleteDraftConfirm;

  /// No description provided for @orderDeleteDraftQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete draft?'**
  String get orderDeleteDraftQuestion;

  /// No description provided for @orderDeliveredStatus.
  ///
  /// In en, this message translates to:
  /// **'Order Delivered'**
  String get orderDeliveredStatus;

  /// No description provided for @orderDetailsDueSuffix.
  ///
  /// In en, this message translates to:
  /// **' · Due {amount}'**
  String orderDetailsDueSuffix(String amount);

  /// No description provided for @orderDetailsNoPaymentsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No payments recorded yet.'**
  String get orderDetailsNoPaymentsRecorded;

  /// No description provided for @orderDetailsRefundablePayments.
  ///
  /// In en, this message translates to:
  /// **'{count} payment(s) still have a refundable balance. Refund them now to cancel this order, or open Payments to refund individually.'**
  String orderDetailsRefundablePayments(int count);

  /// No description provided for @orderDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get orderDetailsTitle;

  /// No description provided for @orderDetailsTotalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total paid {amount}'**
  String orderDetailsTotalPaid(String amount);

  /// No description provided for @orderDetailsViewPayments.
  ///
  /// In en, this message translates to:
  /// **'View payments'**
  String get orderDetailsViewPayments;

  /// No description provided for @orderDraftDeleted.
  ///
  /// In en, this message translates to:
  /// **'Draft deleted.'**
  String get orderDraftDeleted;

  /// No description provided for @orderDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Cart draft saved. Open it from Home → Saved drafts.'**
  String get orderDraftSaved;

  /// No description provided for @orderDeleteOrder.
  ///
  /// In en, this message translates to:
  /// **'Delete order'**
  String get orderDeleteOrder;

  /// No description provided for @orderDeleteOrderQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete order?'**
  String get orderDeleteOrderQuestion;

  /// No description provided for @orderDeleteOrderBody.
  ///
  /// In en, this message translates to:
  /// **'This removes all products from the order, deletes its saved draft and frees the table. Items already sent to the kitchen are logged as cancelled.'**
  String get orderDeleteOrderBody;

  /// No description provided for @orderDeletedTableFreed.
  ///
  /// In en, this message translates to:
  /// **'Order deleted. Table is free.'**
  String get orderDeletedTableFreed;

  /// No description provided for @orderCancelledTableFreed.
  ///
  /// In en, this message translates to:
  /// **'Order was already sent to the kitchen or synced, so it was cancelled. Table is free.'**
  String get orderCancelledTableFreed;

  /// No description provided for @errorCouldNotDeleteOrder.
  ///
  /// In en, this message translates to:
  /// **'Could not delete order: {error}'**
  String errorCouldNotDeleteOrder(String error);

  /// No description provided for @orderGoToPayments.
  ///
  /// In en, this message translates to:
  /// **'Go to payments'**
  String get orderGoToPayments;

  /// No description provided for @orderHistoryId.
  ///
  /// In en, this message translates to:
  /// **'{id} · Order #{orderId}'**
  String orderHistoryId(String id, int orderId);

  /// No description provided for @orderKotFailed.
  ///
  /// In en, this message translates to:
  /// **'KOT failed: {error}'**
  String orderKotFailed(String error);

  /// No description provided for @orderListCancelHint.
  ///
  /// In en, this message translates to:
  /// **'To cancel an order, open Order details and use Cancel (refunds are required first when payments exist).'**
  String get orderListCancelHint;

  /// No description provided for @orderListClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get orderListClearFilter;

  /// No description provided for @orderListColumnActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get orderListColumnActions;

  /// No description provided for @orderListColumnItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get orderListColumnItems;

  /// No description provided for @orderListColumnName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get orderListColumnName;

  /// No description provided for @orderListColumnOrderId.
  ///
  /// In en, this message translates to:
  /// **'Order ID'**
  String get orderListColumnOrderId;

  /// No description provided for @orderListColumnOrderType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get orderListColumnOrderType;

  /// No description provided for @orderListColumnPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get orderListColumnPayment;

  /// No description provided for @orderListColumnSlNo.
  ///
  /// In en, this message translates to:
  /// **'Sl No'**
  String get orderListColumnSlNo;

  /// No description provided for @orderListColumnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get orderListColumnStatus;

  /// No description provided for @orderListColumnTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get orderListColumnTime;

  /// No description provided for @orderListColumnTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get orderListColumnTotal;

  /// No description provided for @orderListFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get orderListFilterAll;

  /// No description provided for @orderListFilterButton.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get orderListFilterButton;

  /// No description provided for @orderListFilterDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get orderListFilterDelivery;

  /// No description provided for @orderListFilterDineIn.
  ///
  /// In en, this message translates to:
  /// **'Dine In'**
  String get orderListFilterDineIn;

  /// No description provided for @orderListFilterPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get orderListFilterPickup;

  /// No description provided for @orderListNoOrdersFound.
  ///
  /// In en, this message translates to:
  /// **'No orders found'**
  String get orderListNoOrdersFound;

  /// No description provided for @orderListPayNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get orderListPayNow;

  /// No description provided for @orderListPosCode.
  ///
  /// In en, this message translates to:
  /// **'POS {code}'**
  String orderListPosCode(String code);

  /// No description provided for @orderListPrintInvoiceBody.
  ///
  /// In en, this message translates to:
  /// **'Print invoice for Order #{orderId}?'**
  String orderListPrintInvoiceBody(String orderId);

  /// No description provided for @orderListPrintInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Print invoice'**
  String get orderListPrintInvoiceTitle;

  /// No description provided for @orderListRefreshButton.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get orderListRefreshButton;

  /// No description provided for @orderListSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by order ID, name, phone, email...'**
  String get orderListSearchHint;

  /// No description provided for @orderListSelectNewStatus.
  ///
  /// In en, this message translates to:
  /// **'Select new status for Order #{orderId}:'**
  String orderListSelectNewStatus(String orderId);

  /// No description provided for @orderListServeNumber.
  ///
  /// In en, this message translates to:
  /// **'Serve #{number}'**
  String orderListServeNumber(String number);

  /// No description provided for @orderListUnableOpenOrder.
  ///
  /// In en, this message translates to:
  /// **'Unable to open order #{orderId}'**
  String orderListUnableOpenOrder(String orderId);

  /// No description provided for @orderListUpdateStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Update status'**
  String get orderListUpdateStatusTitle;

  /// No description provided for @orderMisc.
  ///
  /// In en, this message translates to:
  /// **'Misc'**
  String get orderMisc;

  /// No description provided for @orderNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items on this order.'**
  String get orderNoItems;

  /// No description provided for @orderNotSyncedRemote.
  ///
  /// In en, this message translates to:
  /// **'Not yet synced to remote'**
  String get orderNotSyncedRemote;

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order #{orderId}'**
  String orderNumber(int orderId);

  /// No description provided for @orderOfferLabel.
  ///
  /// In en, this message translates to:
  /// **'Offer: {label}'**
  String orderOfferLabel(String label);

  /// No description provided for @orderPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed: {error}'**
  String orderPaymentFailed(String error);

  /// No description provided for @orderPaymentsAddPayment.
  ///
  /// In en, this message translates to:
  /// **'Add payment'**
  String get orderPaymentsAddPayment;

  /// No description provided for @orderPaymentsCustomerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer {label}'**
  String orderPaymentsCustomerLabel(String label);

  /// No description provided for @orderPaymentsFullyPaid.
  ///
  /// In en, this message translates to:
  /// **'This order is already fully paid.'**
  String get orderPaymentsFullyPaid;

  /// No description provided for @orderPaymentsFullyRefunded.
  ///
  /// In en, this message translates to:
  /// **'This payment is already fully refunded.'**
  String get orderPaymentsFullyRefunded;

  /// No description provided for @orderPaymentsNoPaymentsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No payments recorded for this order.'**
  String get orderPaymentsNoPaymentsRecorded;

  /// No description provided for @orderPaymentsNoPaymentsUnpaid.
  ///
  /// In en, this message translates to:
  /// **'No payments yet. Record a payment for this unpaid order.'**
  String get orderPaymentsNoPaymentsUnpaid;

  /// No description provided for @orderPaymentsOnlineUpi.
  ///
  /// In en, this message translates to:
  /// **'Online / UPI'**
  String get orderPaymentsOnlineUpi;

  /// No description provided for @orderPaymentsOrderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order total {total} · Remaining {remaining}'**
  String orderPaymentsOrderSummary(String total, String remaining);

  /// No description provided for @orderPaymentsReasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get orderPaymentsReasonOptional;

  /// No description provided for @orderPaymentsRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get orderPaymentsRecordTitle;

  /// No description provided for @orderPaymentsRecordedBalance.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded. Balance {balance}'**
  String orderPaymentsRecordedBalance(String balance);

  /// No description provided for @orderPaymentsRecordedFullyPaid.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded. Order is fully paid.'**
  String get orderPaymentsRecordedFullyPaid;

  /// No description provided for @orderPaymentsRefLabel.
  ///
  /// In en, this message translates to:
  /// **'Ref {reference}'**
  String orderPaymentsRefLabel(String reference);

  /// No description provided for @orderPaymentsRefundAction.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get orderPaymentsRefundAction;

  /// No description provided for @orderPaymentsRefundAmount.
  ///
  /// In en, this message translates to:
  /// **'Refund amount'**
  String get orderPaymentsRefundAmount;

  /// No description provided for @orderPaymentsRefundAmountRange.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount between 0.01 and {max}.'**
  String orderPaymentsRefundAmountRange(String max);

  /// No description provided for @orderPaymentsRefundTitle.
  ///
  /// In en, this message translates to:
  /// **'Refund payment'**
  String get orderPaymentsRefundTitle;

  /// No description provided for @orderPaymentsRefundableOf.
  ///
  /// In en, this message translates to:
  /// **'Refundable {refundable} of {total}'**
  String orderPaymentsRefundableOf(String refundable, String total);

  /// No description provided for @orderPaymentsRefundedAmount.
  ///
  /// In en, this message translates to:
  /// **'Refunded {amount}.'**
  String orderPaymentsRefundedAmount(String amount);

  /// No description provided for @orderPaymentsRefundedCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payments refunded and order cancelled.'**
  String get orderPaymentsRefundedCancelled;

  /// No description provided for @orderPaymentsRefundedLeft.
  ///
  /// In en, this message translates to:
  /// **'Refunded {refunded} · Left {left}'**
  String orderPaymentsRefundedLeft(String refunded, String left);

  /// No description provided for @orderPaymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Order payments'**
  String get orderPaymentsTitle;

  /// No description provided for @orderPrintInvoice.
  ///
  /// In en, this message translates to:
  /// **'Print Invoice'**
  String get orderPrintInvoice;

  /// No description provided for @orderPrintInvoiceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Print invoice for Order #{orderId}?'**
  String orderPrintInvoiceConfirm(int orderId);

  /// No description provided for @orderReadyToServe.
  ///
  /// In en, this message translates to:
  /// **'Ready To Serve'**
  String get orderReadyToServe;

  /// No description provided for @orderRecordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get orderRecordPayment;

  /// No description provided for @orderRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get orderRefund;

  /// No description provided for @orderRefundAllAndCancel.
  ///
  /// In en, this message translates to:
  /// **'Refund all & cancel'**
  String get orderRefundAllAndCancel;

  /// No description provided for @orderRefundBeforeCancelBody.
  ///
  /// In en, this message translates to:
  /// **'{count} payment(s) still have a refundable balance. Refund them now to cancel this order, or open Payments to refund individually.'**
  String orderRefundBeforeCancelBody(int count);

  /// No description provided for @orderRefundBeforeCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Refund before cancel'**
  String get orderRefundBeforeCancelTitle;

  /// No description provided for @orderRefundFailed.
  ///
  /// In en, this message translates to:
  /// **'Refund failed: {error}'**
  String orderRefundFailed(String error);

  /// No description provided for @orderRefundNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get orderRefundNotNow;

  /// No description provided for @orderRefundPayment.
  ///
  /// In en, this message translates to:
  /// **'Refund payment'**
  String get orderRefundPayment;

  /// No description provided for @orderRefundedAmount.
  ///
  /// In en, this message translates to:
  /// **'Refunded {amount}.'**
  String orderRefundedAmount(String amount);

  /// No description provided for @orderSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save cart draft'**
  String get orderSaveDraft;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get orderSummary;

  /// No description provided for @orderSyncedRemote.
  ///
  /// In en, this message translates to:
  /// **'Synced to remote backend'**
  String get orderSyncedRemote;

  /// No description provided for @orderTypeDineIn.
  ///
  /// In en, this message translates to:
  /// **'Dine-In'**
  String get orderTypeDineIn;

  /// No description provided for @orderTypePickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get orderTypePickup;

  /// No description provided for @orderTypeSelection.
  ///
  /// In en, this message translates to:
  /// **'Select Order Type'**
  String get orderTypeSelection;

  /// No description provided for @orderTypeTable.
  ///
  /// In en, this message translates to:
  /// **'{type} · {table}'**
  String orderTypeTable(String type, String table);

  /// No description provided for @orderUnableToOpen.
  ///
  /// In en, this message translates to:
  /// **'Unable to open order #{orderId}'**
  String orderUnableToOpen(int orderId);

  /// No description provided for @orderUpdateStatus.
  ///
  /// In en, this message translates to:
  /// **'Update Status'**
  String get orderUpdateStatus;

  /// No description provided for @pickupAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get pickupAddButton;

  /// No description provided for @pickupCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get pickupCancelButton;

  /// No description provided for @pickupName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get pickupName;

  /// No description provided for @pickupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get pickupNameHint;

  /// No description provided for @pickupPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get pickupPhone;

  /// No description provided for @pickupPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter 10-digit number'**
  String get pickupPhoneHint;

  /// No description provided for @profileAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccount;

  /// No description provided for @profileCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get profileCode;

  /// No description provided for @profileContactEmail.
  ///
  /// In en, this message translates to:
  /// **'Contact email'**
  String get profileContactEmail;

  /// No description provided for @profileCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get profileCurrent;

  /// No description provided for @profileCurrentStore.
  ///
  /// In en, this message translates to:
  /// **'Current store'**
  String get profileCurrentStore;

  /// No description provided for @profileMyProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get profileMyProfile;

  /// No description provided for @profileOrganisationRole.
  ///
  /// In en, this message translates to:
  /// **'Organisation role'**
  String get profileOrganisationRole;

  /// No description provided for @profilePosOperator.
  ///
  /// In en, this message translates to:
  /// **'POS Operator'**
  String get profilePosOperator;

  /// No description provided for @profileRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get profileRole;

  /// No description provided for @profileServiceInstance.
  ///
  /// In en, this message translates to:
  /// **'Service instance'**
  String get profileServiceInstance;

  /// No description provided for @profileSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get profileSignedIn;

  /// No description provided for @profileSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get profileSignedInAs;

  /// No description provided for @profileStoreId.
  ///
  /// In en, this message translates to:
  /// **'Store ID'**
  String get profileStoreId;

  /// No description provided for @profileStoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get profileStoreLabel;

  /// No description provided for @profileStoreRole.
  ///
  /// In en, this message translates to:
  /// **'Store role'**
  String get profileStoreRole;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get profileType;

  /// No description provided for @refundsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} refunds'**
  String refundsCount(int count);

  /// No description provided for @refundsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No refunds recorded yet.'**
  String get refundsEmpty;

  /// No description provided for @refundsPeriodTitle.
  ///
  /// In en, this message translates to:
  /// **'Refunds · {period}'**
  String refundsPeriodTitle(String period);

  /// No description provided for @refundsTitle.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get refundsTitle;

  /// No description provided for @scheduledPaymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled payments'**
  String get scheduledPaymentsTitle;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInButton;

  /// No description provided for @signInEmailPhone.
  ///
  /// In en, this message translates to:
  /// **'Email / Mobile Number'**
  String get signInEmailPhone;

  /// No description provided for @signInEmailPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter email or mobile'**
  String get signInEmailPhoneHint;

  /// No description provided for @signInForgotPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get signInForgotPasswordPrompt;

  /// No description provided for @signInIdentifierHint.
  ///
  /// In en, this message translates to:
  /// **'Email / phone / staff ID'**
  String get signInIdentifierHint;

  /// No description provided for @signInNewCompany.
  ///
  /// In en, this message translates to:
  /// **'New company?'**
  String get signInNewCompany;

  /// No description provided for @signInPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get signInPassword;

  /// No description provided for @signInPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get signInPasswordHint;

  /// No description provided for @signInRenewDevice.
  ///
  /// In en, this message translates to:
  /// **'Sign in to renew this device'**
  String get signInRenewDevice;

  /// No description provided for @signInShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show Password'**
  String get signInShowPassword;

  /// No description provided for @signInWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get signInWelcome;

  /// No description provided for @signupAlreadyHaveCompany.
  ///
  /// In en, this message translates to:
  /// **'Already have a company? Sign in'**
  String get signupAlreadyHaveCompany;

  /// No description provided for @signupBackToBranch.
  ///
  /// In en, this message translates to:
  /// **'Back to branch details'**
  String get signupBackToBranch;

  /// No description provided for @signupBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get signupBackToSignIn;

  /// No description provided for @signupBodyBranch.
  ///
  /// In en, this message translates to:
  /// **'Name the branch and city. Registration number is optional.'**
  String get signupBodyBranch;

  /// No description provided for @signupBodyBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Pick the business type. We will create a restaurant store under your branch.'**
  String get signupBodyBusinessType;

  /// No description provided for @signupBodyCompanyDetails.
  ///
  /// In en, this message translates to:
  /// **'Tell us about the company and the owner who will administer it.'**
  String get signupBodyCompanyDetails;

  /// No description provided for @signupBodyCreateCompany.
  ///
  /// In en, this message translates to:
  /// **'Create a new company for this tablet.'**
  String get signupBodyCreateCompany;

  /// No description provided for @signupBodyCreateCompanyManual.
  ///
  /// In en, this message translates to:
  /// **'Enter your server and parent organisation, then create a new company for this tablet.'**
  String get signupBodyCreateCompanyManual;

  /// No description provided for @signupBodyReady.
  ///
  /// In en, this message translates to:
  /// **'Your company is ready. Sign in with your company identifier and password.'**
  String get signupBodyReady;

  /// No description provided for @signupBodySettingUp.
  ///
  /// In en, this message translates to:
  /// **'Creating your organisation, branch, and store — this only takes a moment.'**
  String get signupBodySettingUp;

  /// No description provided for @signupBranchName.
  ///
  /// In en, this message translates to:
  /// **'Branch name'**
  String get signupBranchName;

  /// No description provided for @signupBusinessBakery.
  ///
  /// In en, this message translates to:
  /// **'Bakery'**
  String get signupBusinessBakery;

  /// No description provided for @signupBusinessCafe.
  ///
  /// In en, this message translates to:
  /// **'Cafe'**
  String get signupBusinessCafe;

  /// No description provided for @signupBusinessOther.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get signupBusinessOther;

  /// No description provided for @signupBusinessRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get signupBusinessRestaurant;

  /// No description provided for @signupCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get signupCity;

  /// No description provided for @signupCompanyIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Company identifier'**
  String get signupCompanyIdentifier;

  /// No description provided for @signupCompanyName.
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get signupCompanyName;

  /// No description provided for @signupConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get signupConfirmPassword;

  /// No description provided for @signupCouldNotPrepare.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare company signup.'**
  String get signupCouldNotPrepare;

  /// No description provided for @signupCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get signupCountry;

  /// No description provided for @signupCreateCompany.
  ///
  /// In en, this message translates to:
  /// **'Create company'**
  String get signupCreateCompany;

  /// No description provided for @signupJoinExistingDevice.
  ///
  /// In en, this message translates to:
  /// **'Join an existing organisation device'**
  String get signupJoinExistingDevice;

  /// No description provided for @signupLoginNow.
  ///
  /// In en, this message translates to:
  /// **'Login now'**
  String get signupLoginNow;

  /// No description provided for @signupNoCountriesMatch.
  ///
  /// In en, this message translates to:
  /// **'No countries match “{query}”'**
  String signupNoCountriesMatch(String query);

  /// No description provided for @signupOwnerName.
  ///
  /// In en, this message translates to:
  /// **'Owner name'**
  String get signupOwnerName;

  /// No description provided for @signupParentOrgHelp.
  ///
  /// In en, this message translates to:
  /// **'We’ll check this organisation exists before continuing.'**
  String get signupParentOrgHelp;

  /// No description provided for @signupParentOrgHint.
  ///
  /// In en, this message translates to:
  /// **'Parent organisation identifier or instance id'**
  String get signupParentOrgHint;

  /// No description provided for @signupPasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep it simple for floor staff — letters, numbers, or both.'**
  String get signupPasswordHelp;

  /// No description provided for @signupPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password (min 6 letters/digits)'**
  String get signupPasswordHint;

  /// No description provided for @signupPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get signupPasswordsDoNotMatch;

  /// No description provided for @signupPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get signupPhoneHint;

  /// No description provided for @signupPhoneHintWithDial.
  ///
  /// In en, this message translates to:
  /// **'Phone number (e.g. {dialCode} 9876543210)'**
  String signupPhoneHintWithDial(String dialCode);

  /// No description provided for @signupChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language'**
  String get signupChooseLanguage;

  /// No description provided for @signupChooseLanguageHelp.
  ///
  /// In en, this message translates to:
  /// **'Your signup screens will use this language. You can change it anytime using the language menu.'**
  String get signupChooseLanguageHelp;

  /// No description provided for @signupPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing company signup.'**
  String get signupPreparing;

  /// No description provided for @signupProgressCreatingCompany.
  ///
  /// In en, this message translates to:
  /// **'Creating company'**
  String get signupProgressCreatingCompany;

  /// No description provided for @signupProgressCreatingUser.
  ///
  /// In en, this message translates to:
  /// **'Creating user'**
  String get signupProgressCreatingUser;

  /// No description provided for @signupProgressSettingAccount.
  ///
  /// In en, this message translates to:
  /// **'Setting up account'**
  String get signupProgressSettingAccount;

  /// No description provided for @signupProgressSettingBranch.
  ///
  /// In en, this message translates to:
  /// **'Setting up branch'**
  String get signupProgressSettingBranch;

  /// No description provided for @signupProgressSettingProfile.
  ///
  /// In en, this message translates to:
  /// **'Setting profile'**
  String get signupProgressSettingProfile;

  /// No description provided for @signupProgressSuccess.
  ///
  /// In en, this message translates to:
  /// **'Congratulations — success'**
  String get signupProgressSuccess;

  /// No description provided for @signupRegistrationOptional.
  ///
  /// In en, this message translates to:
  /// **'Registration number (optional)'**
  String get signupRegistrationOptional;

  /// No description provided for @signupSearchCountry.
  ///
  /// In en, this message translates to:
  /// **'Search country, code, or dial'**
  String get signupSearchCountry;

  /// No description provided for @signupSelectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select country'**
  String get signupSelectCountry;

  /// No description provided for @signupServerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Server URL (e.g. http://192.168.1.10:8000)'**
  String get signupServerUrlHint;

  /// No description provided for @signupTitleBranch.
  ///
  /// In en, this message translates to:
  /// **'Your first branch'**
  String get signupTitleBranch;

  /// No description provided for @signupTitleBusinessType.
  ///
  /// In en, this message translates to:
  /// **'What do you run?'**
  String get signupTitleBusinessType;

  /// No description provided for @signupTitleCompanyDetails.
  ///
  /// In en, this message translates to:
  /// **'Company details'**
  String get signupTitleCompanyDetails;

  /// No description provided for @signupTitleCreateCompany.
  ///
  /// In en, this message translates to:
  /// **'Create your company'**
  String get signupTitleCreateCompany;

  /// No description provided for @signupTitleReady.
  ///
  /// In en, this message translates to:
  /// **'You are ready'**
  String get signupTitleReady;

  /// No description provided for @signupTitleSettingUp.
  ///
  /// In en, this message translates to:
  /// **'Setting things up'**
  String get signupTitleSettingUp;

  /// No description provided for @signupTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get signupTryAgain;

  /// No description provided for @signupUseIdentifierHelp.
  ///
  /// In en, this message translates to:
  /// **'Use this identifier with your email/phone and password to sign in.'**
  String get signupUseIdentifierHelp;

  /// No description provided for @splashCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get splashCheckAgain;

  /// No description provided for @splashDeviceNotApproved.
  ///
  /// In en, this message translates to:
  /// **'Device not approved'**
  String get splashDeviceNotApproved;

  /// No description provided for @splashInitError.
  ///
  /// In en, this message translates to:
  /// **'Initialization Error'**
  String get splashInitError;

  /// No description provided for @splashNoConfig.
  ///
  /// In en, this message translates to:
  /// **'No stored configuration found'**
  String get splashNoConfig;

  /// No description provided for @splashNoOrgCode.
  ///
  /// In en, this message translates to:
  /// **'No stored organisation code found'**
  String get splashNoOrgCode;

  /// No description provided for @splashPleaseSignIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to continue'**
  String get splashPleaseSignIn;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Precision in every transaction'**
  String get splashTagline;

  /// No description provided for @staffLockAllStaff.
  ///
  /// In en, this message translates to:
  /// **'All staff'**
  String get staffLockAllStaff;

  /// No description provided for @staffLockBranchNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Branch not loaded'**
  String get staffLockBranchNotLoaded;

  /// No description provided for @staffLockMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get staffLockMore;

  /// No description provided for @staffLockOnlineSignIn.
  ///
  /// In en, this message translates to:
  /// **'Online device sign-in'**
  String get staffLockOnlineSignIn;

  /// No description provided for @staffLockStaffId.
  ///
  /// In en, this message translates to:
  /// **'Staff ID'**
  String get staffLockStaffId;

  /// No description provided for @staffLockStaffStore.
  ///
  /// In en, this message translates to:
  /// **'Staff · {storeName}'**
  String staffLockStaffStore(String storeName);

  /// No description provided for @staffLockSwitchStore.
  ///
  /// In en, this message translates to:
  /// **'Switch store'**
  String get staffLockSwitchStore;

  /// No description provided for @staffLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff unlock'**
  String get staffLockTitle;

  /// No description provided for @staffLockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get staffLockUnlock;

  /// No description provided for @staffLogoutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This locks the register. Another staff member can unlock with their PIN or password.'**
  String get staffLogoutConfirmBody;

  /// No description provided for @staffLogoutConfirmBodyFull.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be signed out and your PIN is removed from this device. The next person signs in online. Orders already saved stay on this device.'**
  String get staffLogoutConfirmBodyFull;

  /// No description provided for @staffLogoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out staff?'**
  String get staffLogoutConfirmTitle;

  /// No description provided for @statusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get statusApproved;

  /// No description provided for @statusCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get statusCollected;

  /// No description provided for @statusCooking.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get statusCooking;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @statusInitiated.
  ///
  /// In en, this message translates to:
  /// **'Initiated'**
  String get statusInitiated;

  /// No description provided for @statusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get statusOpen;

  /// No description provided for @statusOrderAccepted.
  ///
  /// In en, this message translates to:
  /// **'Order Accepted'**
  String get statusOrderAccepted;

  /// No description provided for @statusOrderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order Cancelled'**
  String get statusOrderCancelled;

  /// No description provided for @statusOrderCompleted.
  ///
  /// In en, this message translates to:
  /// **'Order Completed'**
  String get statusOrderCompleted;

  /// No description provided for @statusOrderPending.
  ///
  /// In en, this message translates to:
  /// **'Order Pending'**
  String get statusOrderPending;

  /// No description provided for @statusOrderPreparing.
  ///
  /// In en, this message translates to:
  /// **'Order Preparing'**
  String get statusOrderPreparing;

  /// No description provided for @statusOrderReady.
  ///
  /// In en, this message translates to:
  /// **'Order Ready'**
  String get statusOrderReady;

  /// No description provided for @statusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statusPaid;

  /// No description provided for @statusPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get statusPartial;

  /// No description provided for @statusPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get statusPickedUp;

  /// No description provided for @statusPlaced.
  ///
  /// In en, this message translates to:
  /// **'Placed'**
  String get statusPlaced;

  /// No description provided for @statusReadyToServe.
  ///
  /// In en, this message translates to:
  /// **'Ready to serve'**
  String get statusReadyToServe;

  /// No description provided for @statusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get statusRefunded;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @statusReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get statusReturned;

  /// No description provided for @statusServed.
  ///
  /// In en, this message translates to:
  /// **'Served'**
  String get statusServed;

  /// No description provided for @statusSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get statusSettled;

  /// No description provided for @statusUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get statusUnpaid;

  /// No description provided for @storeAdminAccessRequired.
  ///
  /// In en, this message translates to:
  /// **'Store Admin access required.'**
  String get storeAdminAccessRequired;

  /// No description provided for @storeListBackToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Back to staff unlock'**
  String get storeListBackToUnlock;

  /// No description provided for @storeListChooseBranchUnlock.
  ///
  /// In en, this message translates to:
  /// **'Choose a branch, then unlock with staff ID'**
  String get storeListChooseBranchUnlock;

  /// No description provided for @storeListChooseStore.
  ///
  /// In en, this message translates to:
  /// **'Choose your store to continue'**
  String get storeListChooseStore;

  /// No description provided for @storeListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stores found'**
  String get storeListEmpty;

  /// No description provided for @storeListLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading stores...'**
  String get storeListLoading;

  /// No description provided for @storeListOpenBranch.
  ///
  /// In en, this message translates to:
  /// **'Open branch'**
  String get storeListOpenBranch;

  /// No description provided for @storeListSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by store name or ID...'**
  String get storeListSearchHint;

  /// No description provided for @storeListSelectStore.
  ///
  /// In en, this message translates to:
  /// **'Select Store'**
  String get storeListSelectStore;

  /// No description provided for @storeListStoreId.
  ///
  /// In en, this message translates to:
  /// **'Store ID: {storeId}'**
  String storeListStoreId(String storeId);

  /// No description provided for @storeListTitle.
  ///
  /// In en, this message translates to:
  /// **'My stores'**
  String get storeListTitle;

  /// No description provided for @storeListTitleCount.
  ///
  /// In en, this message translates to:
  /// **'My stores ({count})'**
  String storeListTitleCount(int count);

  /// No description provided for @storeSelectedSuccess.
  ///
  /// In en, this message translates to:
  /// **'{storeName} selected successfully!'**
  String storeSelectedSuccess(String storeName);

  /// No description provided for @storeSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Setting up {storeName}'**
  String storeSyncTitle(String storeName);

  /// No description provided for @storeSyncBody.
  ///
  /// In en, this message translates to:
  /// **'Downloading catalogue, customers and orders to this device. Keep the app open.'**
  String get storeSyncBody;

  /// No description provided for @storeSyncPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get storeSyncPreparing;

  /// No description provided for @storeSetupAccess.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get storeSetupAccess;

  /// No description provided for @storeSetupAddCashier.
  ///
  /// In en, this message translates to:
  /// **'Add cashier'**
  String get storeSetupAddCashier;

  /// No description provided for @storeSetupAddCashierHint.
  ///
  /// In en, this message translates to:
  /// **'Add a cashier with name, email, phone and password.'**
  String get storeSetupAddCashierHint;

  /// No description provided for @storeSetupAddGroup.
  ///
  /// In en, this message translates to:
  /// **'Add group'**
  String get storeSetupAddGroup;

  /// No description provided for @storeSetupAddLinkCategoryFirst.
  ///
  /// In en, this message translates to:
  /// **'Add and link a category first'**
  String get storeSetupAddLinkCategoryFirst;

  /// No description provided for @storeSetupAddOffer.
  ///
  /// In en, this message translates to:
  /// **'Add offer'**
  String get storeSetupAddOffer;

  /// No description provided for @storeSetupAddSellableItem.
  ///
  /// In en, this message translates to:
  /// **'Add sellable item'**
  String get storeSetupAddSellableItem;

  /// No description provided for @storeSetupAddToStore.
  ///
  /// In en, this message translates to:
  /// **'Add to store'**
  String get storeSetupAddToStore;

  /// No description provided for @storeSetupAddonDeletedOffline.
  ///
  /// In en, this message translates to:
  /// **'Add-on deleted offline. Sync to export.'**
  String get storeSetupAddonDeletedOffline;

  /// No description provided for @storeSetupAddonGroup.
  ///
  /// In en, this message translates to:
  /// **'Add-on group'**
  String get storeSetupAddonGroup;

  /// No description provided for @storeSetupAddons.
  ///
  /// In en, this message translates to:
  /// **'Add-ons'**
  String get storeSetupAddons;

  /// No description provided for @storeSetupCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get storeSetupCashier;

  /// No description provided for @storeSetupCashierCreated.
  ///
  /// In en, this message translates to:
  /// **'Cashier created. They can unlock this store after logout.'**
  String get storeSetupCashierCreated;

  /// No description provided for @storeSetupCatalogueExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Catalogue export failed: {message}'**
  String storeSetupCatalogueExportFailed(String message);

  /// No description provided for @storeSetupCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get storeSetupCategories;

  /// No description provided for @storeSetupCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get storeSetupCategory;

  /// No description provided for @storeSetupCategoryAddedOffline.
  ///
  /// In en, this message translates to:
  /// **'Category added to master and this store (offline). Sync to export.'**
  String get storeSetupCategoryAddedOffline;

  /// No description provided for @storeSetupCategoryDeletedOffline.
  ///
  /// In en, this message translates to:
  /// **'Category deleted offline. Sync to export.'**
  String get storeSetupCategoryDeletedOffline;

  /// No description provided for @storeSetupCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get storeSetupCategoryName;

  /// No description provided for @storeSetupChooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose category'**
  String get storeSetupChooseCategory;

  /// No description provided for @storeSetupChoosePackage.
  ///
  /// In en, this message translates to:
  /// **'Choose a package'**
  String get storeSetupChoosePackage;

  /// No description provided for @storeSetupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get storeSetupCreate;

  /// No description provided for @storeSetupCreateCashier.
  ///
  /// In en, this message translates to:
  /// **'Create cashier'**
  String get storeSetupCreateCashier;

  /// No description provided for @storeSetupDeleteAddonGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete add-on group?'**
  String get storeSetupDeleteAddonGroup;

  /// No description provided for @storeSetupDeleteOffer.
  ///
  /// In en, this message translates to:
  /// **'Delete offer?'**
  String get storeSetupDeleteOffer;

  /// No description provided for @storeSetupDeletePackage.
  ///
  /// In en, this message translates to:
  /// **'Delete package?'**
  String get storeSetupDeletePackage;

  /// No description provided for @storeSetupDeletedOffline.
  ///
  /// In en, this message translates to:
  /// **'Deleted offline. Sync to export.'**
  String get storeSetupDeletedOffline;

  /// No description provided for @storeSetupDeletedTombstone.
  ///
  /// In en, this message translates to:
  /// **'Deleted offline. Sync to export tombstone.'**
  String get storeSetupDeletedTombstone;

  /// No description provided for @storeSetupPackageMarkedActive.
  ///
  /// In en, this message translates to:
  /// **'Package is active and available for billing. Sync to update the admin panel.'**
  String get storeSetupPackageMarkedActive;

  /// No description provided for @storeSetupPackageMarkedInactive.
  ///
  /// In en, this message translates to:
  /// **'Package is inactive and hidden from billing. Sync to update the admin panel.'**
  String get storeSetupPackageMarkedInactive;

  /// No description provided for @storeSetupEditAddonGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit add-on group'**
  String get storeSetupEditAddonGroup;

  /// No description provided for @storeSetupEditOffer.
  ///
  /// In en, this message translates to:
  /// **'Edit offer'**
  String get storeSetupEditOffer;

  /// No description provided for @storeSetupEditPackage.
  ///
  /// In en, this message translates to:
  /// **'Edit package'**
  String get storeSetupEditPackage;

  /// No description provided for @storeSetupExportNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Catalogue export not configured — local edits stayed on this tablet.'**
  String get storeSetupExportNotConfigured;

  /// No description provided for @storeSetupFirstItemName.
  ///
  /// In en, this message translates to:
  /// **'First item name *'**
  String get storeSetupFirstItemName;

  /// No description provided for @storeSetupGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group name *'**
  String get storeSetupGroupName;

  /// No description provided for @storeSetupItemPrice.
  ///
  /// In en, this message translates to:
  /// **'Item price *'**
  String get storeSetupItemPrice;

  /// No description provided for @storeSetupLinkCategoryFirst.
  ///
  /// In en, this message translates to:
  /// **'Link a category first'**
  String get storeSetupLinkCategoryFirst;

  /// No description provided for @storeSetupLinkPackagesHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for a whole-bill offer. Select packages to limit where it applies.'**
  String get storeSetupLinkPackagesHint;

  /// No description provided for @storeSetupLinkPackagesOptional.
  ///
  /// In en, this message translates to:
  /// **'Link to packages (optional)'**
  String get storeSetupLinkPackagesOptional;

  /// No description provided for @storeSetupLinkToPackage.
  ///
  /// In en, this message translates to:
  /// **'Link to package'**
  String get storeSetupLinkToPackage;

  /// No description provided for @storeSetupLinkToPackageHint.
  ///
  /// In en, this message translates to:
  /// **'Choose which package should offer this add-on group.'**
  String get storeSetupLinkToPackageHint;

  /// No description provided for @storeSetupLinkedMaster.
  ///
  /// In en, this message translates to:
  /// **'Linked \"{name}\" to this store'**
  String storeSetupLinkedMaster(String name);

  /// No description provided for @storeSetupLinkedToStore.
  ///
  /// In en, this message translates to:
  /// **'Linked “{name}” to this store'**
  String storeSetupLinkedToStore(String name);

  /// No description provided for @storeSetupMasterCategories.
  ///
  /// In en, this message translates to:
  /// **'Master categories'**
  String get storeSetupMasterCategories;

  /// No description provided for @storeSetupMasterLinked.
  ///
  /// In en, this message translates to:
  /// **'Master linked with default package. Edit price, then Sync.'**
  String get storeSetupMasterLinked;

  /// No description provided for @storeSetupMinBill.
  ///
  /// In en, this message translates to:
  /// **'Min bill'**
  String get storeSetupMinBill;

  /// No description provided for @storeSetupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get storeSetupNameRequired;

  /// No description provided for @storeSetupNewCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get storeSetupNewCategory;

  /// No description provided for @storeSetupNewMasterCategory.
  ///
  /// In en, this message translates to:
  /// **'New master category'**
  String get storeSetupNewMasterCategory;

  /// No description provided for @storeSetupNewOffer.
  ///
  /// In en, this message translates to:
  /// **'New offer'**
  String get storeSetupNewOffer;

  /// No description provided for @storeSetupNewProduct.
  ///
  /// In en, this message translates to:
  /// **'New product / package'**
  String get storeSetupNewProduct;

  /// No description provided for @storeSetupNoAddonsYet.
  ///
  /// In en, this message translates to:
  /// **'No add-ons yet'**
  String get storeSetupNoAddonsYet;

  /// No description provided for @storeSetupNoCashiersYet.
  ///
  /// In en, this message translates to:
  /// **'No cashiers yet'**
  String get storeSetupNoCashiersYet;

  /// No description provided for @storeSetupNoMasterCategories.
  ///
  /// In en, this message translates to:
  /// **'No master categories'**
  String get storeSetupNoMasterCategories;

  /// No description provided for @storeSetupNoOffersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No offers yet'**
  String get storeSetupNoOffersEmpty;

  /// No description provided for @storeSetupNoOffersYet.
  ///
  /// In en, this message translates to:
  /// **'No offers yet — create some in Offers setup.'**
  String get storeSetupNoOffersYet;

  /// No description provided for @storeSetupNoPackagesCreateProducts.
  ///
  /// In en, this message translates to:
  /// **'No packages yet — create products first.'**
  String get storeSetupNoPackagesCreateProducts;

  /// No description provided for @storeSetupNoPackagesYet.
  ///
  /// In en, this message translates to:
  /// **'No packages yet'**
  String get storeSetupNoPackagesYet;

  /// No description provided for @storeSetupNoPackagesYetShort.
  ///
  /// In en, this message translates to:
  /// **'No packages yet.'**
  String get storeSetupNoPackagesYetShort;

  /// No description provided for @storeSetupNoTaxUnset.
  ///
  /// In en, this message translates to:
  /// **'No tax / unset'**
  String get storeSetupNoTaxUnset;

  /// No description provided for @storeSetupNoTaxesYet.
  ///
  /// In en, this message translates to:
  /// **'No taxes yet — they are added automatically when the company is set up.'**
  String get storeSetupNoTaxesYet;

  /// No description provided for @storeSetupNothingLinked.
  ///
  /// In en, this message translates to:
  /// **'Nothing linked yet'**
  String get storeSetupNothingLinked;

  /// No description provided for @storeSetupOfferDeletedOffline.
  ///
  /// In en, this message translates to:
  /// **'Offer deleted offline. Sync to export.'**
  String get storeSetupOfferDeletedOffline;

  /// No description provided for @storeSetupOfferPctOff.
  ///
  /// In en, this message translates to:
  /// **'{pct}% off'**
  String storeSetupOfferPctOff(String pct);

  /// No description provided for @storeSetupOfferSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Offer saved offline'**
  String get storeSetupOfferSavedOffline;

  /// No description provided for @storeSetupOfferUpdatedOffline.
  ///
  /// In en, this message translates to:
  /// **'Offer updated offline'**
  String get storeSetupOfferUpdatedOffline;

  /// No description provided for @storeSetupOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get storeSetupOffers;

  /// No description provided for @storeSetupOffersForPackage.
  ///
  /// In en, this message translates to:
  /// **'Offers for this package'**
  String get storeSetupOffersForPackage;

  /// No description provided for @storeSetupOffersForPackageHint.
  ///
  /// In en, this message translates to:
  /// **'Select offers that should apply to this package. Leave none for no package-specific offers.'**
  String get storeSetupOffersForPackageHint;

  /// No description provided for @storeSetupOptionalMinBill.
  ///
  /// In en, this message translates to:
  /// **'Optional minimum bill'**
  String get storeSetupOptionalMinBill;

  /// No description provided for @storeSetupPackage.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get storeSetupPackage;

  /// No description provided for @storeSetupPackageName.
  ///
  /// In en, this message translates to:
  /// **'Package name *'**
  String get storeSetupPackageName;

  /// No description provided for @storeSetupPackageNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Regular, Large, Family'**
  String get storeSetupPackageNameHint;

  /// No description provided for @storeSetupPackageNamePlain.
  ///
  /// In en, this message translates to:
  /// **'Package name'**
  String get storeSetupPackageNamePlain;

  /// No description provided for @storeSetupPercentOff.
  ///
  /// In en, this message translates to:
  /// **'Percent off'**
  String get storeSetupPercentOff;

  /// No description provided for @storeSetupProductName.
  ///
  /// In en, this message translates to:
  /// **'Product / service name *'**
  String get storeSetupProductName;

  /// No description provided for @storeSetupProductNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Chicken Biryani'**
  String get storeSetupProductNameHint;

  /// No description provided for @storeSetupProductNamePlain.
  ///
  /// In en, this message translates to:
  /// **'Product / service name'**
  String get storeSetupProductNamePlain;

  /// No description provided for @storeSetupProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get storeSetupProducts;

  /// No description provided for @storeSetupProductsPackages.
  ///
  /// In en, this message translates to:
  /// **'Products & packages'**
  String get storeSetupProductsPackages;

  /// No description provided for @storeSetupRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get storeSetupRegular;

  /// No description provided for @storeSetupRemoveCategory.
  ///
  /// In en, this message translates to:
  /// **'Remove category?'**
  String get storeSetupRemoveCategory;

  /// No description provided for @storeSetupRemoveEntitySync.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\". Sync to export.'**
  String storeSetupRemoveEntitySync(String name);

  /// No description provided for @storeSetupRemoveFromStore.
  ///
  /// In en, this message translates to:
  /// **'Remove from store'**
  String get storeSetupRemoveFromStore;

  /// No description provided for @storeSetupRenameCategory.
  ///
  /// In en, this message translates to:
  /// **'Rename category'**
  String get storeSetupRenameCategory;

  /// No description provided for @storeSetupRenamedOffline.
  ///
  /// In en, this message translates to:
  /// **'Renamed offline. Sync to export.'**
  String get storeSetupRenamedOffline;

  /// No description provided for @storeSetupSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved offline. Sync to export.'**
  String get storeSetupSavedOffline;

  /// No description provided for @storeSetupSavedOfflineMaster.
  ///
  /// In en, this message translates to:
  /// **'Saved offline. Sync to export to master + store.'**
  String get storeSetupSavedOfflineMaster;

  /// No description provided for @storeSetupSellPrice.
  ///
  /// In en, this message translates to:
  /// **'Sell price *'**
  String get storeSetupSellPrice;

  /// No description provided for @storeSetupStoreAdmin.
  ///
  /// In en, this message translates to:
  /// **'Store admin'**
  String get storeSetupStoreAdmin;

  /// No description provided for @storeSetupSyncExport.
  ///
  /// In en, this message translates to:
  /// **'Sync / export'**
  String get storeSetupSyncExport;

  /// No description provided for @storeSetupSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String storeSetupSyncFailed(String error);

  /// No description provided for @storeSetupSyncFinishedExported.
  ///
  /// In en, this message translates to:
  /// **'Sync finished — exported {count} catalogue row(s).'**
  String storeSetupSyncFinishedExported(int count);

  /// No description provided for @storeSetupSyncFinishedNone.
  ///
  /// In en, this message translates to:
  /// **'Sync finished — no pending catalogue changes to export.'**
  String get storeSetupSyncFinishedNone;

  /// No description provided for @storeSetupTaxForPackage.
  ///
  /// In en, this message translates to:
  /// **'Tax for this package'**
  String get storeSetupTaxForPackage;

  /// No description provided for @storeSetupTaxForPackageHint.
  ///
  /// In en, this message translates to:
  /// **'Company tax bands from setup. Leave none if this package is tax-free / unset.'**
  String get storeSetupTaxForPackageHint;

  /// No description provided for @storeSetupTaxNamePct.
  ///
  /// In en, this message translates to:
  /// **'{name} ({pct}%)'**
  String storeSetupTaxNamePct(String name, String pct);

  /// No description provided for @storeSetupTaxPct.
  ///
  /// In en, this message translates to:
  /// **'Tax {pct}%'**
  String storeSetupTaxPct(String pct);

  /// No description provided for @storeSetupTaxTotalPct.
  ///
  /// In en, this message translates to:
  /// **'{pct}% total'**
  String storeSetupTaxTotalPct(String pct);

  /// No description provided for @storeSetupThisStore.
  ///
  /// In en, this message translates to:
  /// **'This store'**
  String get storeSetupThisStore;

  /// No description provided for @storeSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Store setup'**
  String get storeSetupTitle;

  /// No description provided for @storeSetupUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit *'**
  String get storeSetupUnit;

  /// No description provided for @storeSetupUnitHint.
  ///
  /// In en, this message translates to:
  /// **'pcs, kg…'**
  String get storeSetupUnitHint;

  /// No description provided for @storeSetupUnitQty.
  ///
  /// In en, this message translates to:
  /// **'Unit qty *'**
  String get storeSetupUnitQty;

  /// No description provided for @storeSetupUpdatedOffline.
  ///
  /// In en, this message translates to:
  /// **'Updated offline. Sync to export.'**
  String get storeSetupUpdatedOffline;

  /// No description provided for @syncAgain.
  ///
  /// In en, this message translates to:
  /// **'Sync again'**
  String get syncAgain;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get syncComplete;

  /// No description provided for @syncDataSync.
  ///
  /// In en, this message translates to:
  /// **'Data Sync'**
  String get syncDataSync;

  /// No description provided for @syncDescription.
  ///
  /// In en, this message translates to:
  /// **'Uploads POS customers, orders and credits from this device first, then downloads catalogue updates. Offline sales stay local until the next successful sync.'**
  String get syncDescription;

  /// No description provided for @syncDownloadFromRemote.
  ///
  /// In en, this message translates to:
  /// **'Download from remote'**
  String get syncDownloadFromRemote;

  /// No description provided for @syncHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get syncHistory;

  /// No description provided for @syncHistory45.
  ///
  /// In en, this message translates to:
  /// **'Sync history (last 45 days)'**
  String get syncHistory45;

  /// No description provided for @syncHistoryStats.
  ///
  /// In en, this message translates to:
  /// **'{processed} processed · {success} ok · {failed} failed'**
  String syncHistoryStats(int processed, int success, int failed);

  /// No description provided for @syncInProgress.
  ///
  /// In en, this message translates to:
  /// **'Sync in progress…'**
  String get syncInProgress;

  /// No description provided for @syncLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync: {timestamp}'**
  String syncLastSync(String timestamp);

  /// No description provided for @syncNamedStoreWithRemote.
  ///
  /// In en, this message translates to:
  /// **'Sync \"{storeName}\" with remote'**
  String syncNamedStoreWithRemote(String storeName);

  /// No description provided for @syncNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get syncNeverSynced;

  /// No description provided for @syncNoAttemptsYet.
  ///
  /// In en, this message translates to:
  /// **'No sync attempts recorded on this device yet.'**
  String get syncNoAttemptsYet;

  /// No description provided for @syncNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No sync attempts recorded on this device yet. Run a sync to populate history.'**
  String get syncNoHistory;

  /// No description provided for @syncOfflineWhenOnline.
  ///
  /// In en, this message translates to:
  /// **'Offline — sync when online'**
  String get syncOfflineWhenOnline;

  /// No description provided for @syncRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get syncRunning;

  /// No description provided for @syncServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable. Keep selling offline — pending uploads stay queued on this device until you sync again online.'**
  String get syncServerUnreachable;

  /// No description provided for @syncStart.
  ///
  /// In en, this message translates to:
  /// **'Start sync'**
  String get syncStart;

  /// No description provided for @syncStoreWithRemote.
  ///
  /// In en, this message translates to:
  /// **'Sync store data with remote'**
  String get syncStoreWithRemote;

  /// No description provided for @syncSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncSyncing;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTitle;

  /// No description provided for @syncUploadToRemote.
  ///
  /// In en, this message translates to:
  /// **'Upload to remote'**
  String get syncUploadToRemote;

  /// No description provided for @unsupportedDeviceDesc.
  ///
  /// In en, this message translates to:
  /// **'EllanPos is designed specifically for tablets and large screens.\n\nPlease access the app from an iPad or Android Tablet in landscape orientation.'**
  String get unsupportedDeviceDesc;

  /// No description provided for @unsupportedDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Not Supported'**
  String get unsupportedDeviceTitle;

  /// No description provided for @welcomeAlreadySetupSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already set up? Sign in'**
  String get welcomeAlreadySetupSignIn;

  /// No description provided for @welcomeAuthPrompt.
  ///
  /// In en, this message translates to:
  /// **'Log in to your account or create a new one to start processing payments effortlessly.'**
  String get welcomeAuthPrompt;

  /// No description provided for @welcomeChooseSavedServer.
  ///
  /// In en, this message translates to:
  /// **'Choose a saved server'**
  String get welcomeChooseSavedServer;

  /// No description provided for @welcomeCreateCompanyInstead.
  ///
  /// In en, this message translates to:
  /// **'Create a new company instead'**
  String get welcomeCreateCompanyInstead;

  /// No description provided for @welcomeDeleteFromList.
  ///
  /// In en, this message translates to:
  /// **'Delete from list'**
  String get welcomeDeleteFromList;

  /// No description provided for @welcomeDeleteSavedServer.
  ///
  /// In en, this message translates to:
  /// **'Delete saved server'**
  String get welcomeDeleteSavedServer;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'EllanPos provides an intuitive tablet experience designed perfectly for modern workflows.'**
  String get welcomeDescription;

  /// No description provided for @welcomeEnterOrg.
  ///
  /// In en, this message translates to:
  /// **'Enter your organization name'**
  String get welcomeEnterOrg;

  /// No description provided for @welcomeEnterOrgCode.
  ///
  /// In en, this message translates to:
  /// **'Enter your organization code'**
  String get welcomeEnterOrgCode;

  /// No description provided for @welcomeGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Get Started'**
  String get welcomeGetStarted;

  /// No description provided for @welcomeOrgCodeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 100001'**
  String get welcomeOrgCodeHint;

  /// No description provided for @welcomeOrgHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Acme Corp'**
  String get welcomeOrgHint;

  /// No description provided for @welcomeOrgInstanceId.
  ///
  /// In en, this message translates to:
  /// **'Organisation instance id'**
  String get welcomeOrgInstanceId;

  /// No description provided for @welcomeRegisterDevice.
  ///
  /// In en, this message translates to:
  /// **'Register device'**
  String get welcomeRegisterDevice;

  /// No description provided for @welcomeRegisterHint.
  ///
  /// In en, this message translates to:
  /// **'Register this tablet to continue.'**
  String get welcomeRegisterHint;

  /// No description provided for @welcomeRegisterHintManual.
  ///
  /// In en, this message translates to:
  /// **'Enter the backend server URL and organisation instance id before registering this device.'**
  String get welcomeRegisterHintManual;

  /// No description provided for @welcomeRemoveServerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{label}\" from this device?'**
  String welcomeRemoveServerConfirm(String label);

  /// No description provided for @welcomeSavedServers.
  ///
  /// In en, this message translates to:
  /// **'Saved servers'**
  String get welcomeSavedServers;

  /// No description provided for @welcomeServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get welcomeServerUrl;

  /// No description provided for @welcomeServerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. http://192.168.1.10:8000'**
  String get welcomeServerUrlHint;

  /// No description provided for @welcomeSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get welcomeSubmit;

  /// No description provided for @welcomeUnlockBusiness.
  ///
  /// In en, this message translates to:
  /// **'Unlock Your\nBusiness Potential'**
  String get welcomeUnlockBusiness;

  /// No description provided for @signInSwitchCompany.
  ///
  /// In en, this message translates to:
  /// **'Switch company'**
  String get signInSwitchCompany;

  /// No description provided for @signInSwitchCompanyTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch company?'**
  String get signInSwitchCompanyTitle;

  /// No description provided for @signInSwitchCompanyBody.
  ///
  /// In en, this message translates to:
  /// **'Switching company resets this device. Local orders, catalogue, customers, sync history and device settings will be permanently deleted, including any orders not yet synced. Nothing is deleted on the server.'**
  String get signInSwitchCompanyBody;

  /// No description provided for @signInSwitchCompanyAction.
  ///
  /// In en, this message translates to:
  /// **'Switch & reset'**
  String get signInSwitchCompanyAction;

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer support'**
  String get supportTitle;

  /// No description provided for @supportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'re here to help with your POS.'**
  String get supportSubtitle;

  /// No description provided for @supportEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get supportEmail;

  /// No description provided for @supportWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get supportWhatsapp;

  /// No description provided for @supportDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get supportDeviceId;

  /// No description provided for @supportCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get supportCompany;

  /// No description provided for @supportShareHint.
  ///
  /// In en, this message translates to:
  /// **'Share these details when you contact support.'**
  String get supportShareHint;

  /// No description provided for @supportNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Support contact details are not set up yet. Please ask your administrator.'**
  String get supportNotConfigured;

  /// No description provided for @supportCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied {value}'**
  String supportCopied(String value);

  /// No description provided for @supportEmailAction.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get supportEmailAction;

  /// No description provided for @supportWhatsappAction.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get supportWhatsappAction;

  /// No description provided for @homeLock.
  ///
  /// In en, this message translates to:
  /// **'Lock screen'**
  String get homeLock;

  /// No description provided for @actionLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get actionLock;

  /// No description provided for @lockEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN to unlock'**
  String get lockEnterPin;

  /// No description provided for @lockEnterPinAt.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN to unlock {storeName}'**
  String lockEnterPinAt(String storeName);

  /// No description provided for @lockSignedOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get lockSignedOutTitle;

  /// No description provided for @lockSignedOutBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in online to start using this register.'**
  String get lockSignedOutBody;

  /// No description provided for @lockSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get lockSignIn;

  /// No description provided for @lockSignInInstead.
  ///
  /// In en, this message translates to:
  /// **'Sign in (new staff or forgot PIN)'**
  String get lockSignInInstead;

  /// No description provided for @lockWrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN. {remaining} attempts left.'**
  String lockWrongPin(int remaining);

  /// No description provided for @lockTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong PINs. Please sign in.'**
  String get lockTooManyAttempts;

  /// No description provided for @lockLeaseExpired.
  ///
  /// In en, this message translates to:
  /// **'Device login expired. Please sign in online.'**
  String get lockLeaseExpired;

  /// No description provided for @pinCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your PIN'**
  String get pinCreateTitle;

  /// No description provided for @pinConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your PIN'**
  String get pinConfirmTitle;

  /// No description provided for @pinCreateBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a {length}-digit PIN to unlock this register quickly.'**
  String pinCreateBody(int length);

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs don\'t match. Try again.'**
  String get pinMismatch;

  /// No description provided for @lockChooseStaff.
  ///
  /// In en, this message translates to:
  /// **'Who\'s using the register?'**
  String get lockChooseStaff;

  /// No description provided for @lockNoStoreAccess.
  ///
  /// In en, this message translates to:
  /// **'{name} can\'t use this store. Please sign in.'**
  String lockNoStoreAccess(String name);

  /// No description provided for @storeTradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Buy & Sell'**
  String get storeTradeTitle;

  /// No description provided for @storeTradeBody.
  ///
  /// In en, this message translates to:
  /// **'Choose what this store does. You can select both. Saved on this device right away.'**
  String get storeTradeBody;

  /// No description provided for @storeTradeSell.
  ///
  /// In en, this message translates to:
  /// **'SELL'**
  String get storeTradeSell;

  /// No description provided for @storeTradeSellHint.
  ///
  /// In en, this message translates to:
  /// **'Sales to customers'**
  String get storeTradeSellHint;

  /// No description provided for @storeTradeBuy.
  ///
  /// In en, this message translates to:
  /// **'BUY'**
  String get storeTradeBuy;

  /// No description provided for @storeTradeBuyHint.
  ///
  /// In en, this message translates to:
  /// **'Purchases from suppliers'**
  String get storeTradeBuyHint;

  /// No description provided for @storeTradeNeedOne.
  ///
  /// In en, this message translates to:
  /// **'Keep at least one of Buy or Sell selected.'**
  String get storeTradeNeedOne;

  /// No description provided for @orderListAllTables.
  ///
  /// In en, this message translates to:
  /// **'All tables'**
  String get orderListAllTables;

  /// No description provided for @orderListTableChip.
  ///
  /// In en, this message translates to:
  /// **'Table {name}'**
  String orderListTableChip(String name);

  /// No description provided for @orderListNoTables.
  ///
  /// In en, this message translates to:
  /// **'No tables yet. Tables appear here once dine-in orders use them.'**
  String get orderListNoTables;

  /// No description provided for @orderListPeriodAll.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get orderListPeriodAll;

  /// No description provided for @orderListPeriodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get orderListPeriodToday;

  /// No description provided for @orderListPeriodLast24h.
  ///
  /// In en, this message translates to:
  /// **'Last 24 hrs'**
  String get orderListPeriodLast24h;

  /// No description provided for @orderListPeriodYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get orderListPeriodYesterday;

  /// No description provided for @orderListPeriodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get orderListPeriodCustom;

  /// No description provided for @orderListPeriodTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter by date'**
  String get orderListPeriodTooltip;

  /// No description provided for @dashboardPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get dashboardPending;

  /// No description provided for @dashboardPendingOrders.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 order} other{{count} orders}}'**
  String dashboardPendingOrders(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
