// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get actionAdd => 'Add';

  @override
  String get actionBack => 'Back';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionChange => 'Change';

  @override
  String get actionClose => 'Close';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionKeep => 'Keep';

  @override
  String get actionLogout => 'Logout';

  @override
  String get actionPrint => 'Print';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionSave => 'Save';

  @override
  String get actionSaveChanges => 'Save changes';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get actionSignUp => 'Sign up';

  @override
  String get actionSubmit => 'Submit';

  @override
  String get actionSync => 'Sync';

  @override
  String get actionUpdate => 'Update';

  @override
  String get actionViewAll => 'View all';

  @override
  String get amountGreaterThanZero => 'Enter an amount greater than zero.';

  @override
  String get appName => 'EllanPos';

  @override
  String get authBackToGetStarted => 'Back to Get started';

  @override
  String get authEntryBrand => 'EllanPos';

  @override
  String get authEntryChooseContinue =>
      'Choose how you want to continue on this tablet.';

  @override
  String get authEntryCompanySetup => 'Company setup';

  @override
  String get authEntryCreateCompany => 'Create a new company';

  @override
  String get authEntryHero =>
      'Sign in to an existing company, or set up a new company on this device.';

  @override
  String get authEntryJoinExisting => 'Join an existing organisation device';

  @override
  String authEntryRootOrgLabel(String orgId) {
    return 'Root org  ·  $orgId';
  }

  @override
  String authEntryServerLabel(String server) {
    return 'Server  ·  $server';
  }

  @override
  String get authEntrySignInExisting => 'Already have a company? Sign in';

  @override
  String get authEntryTitle => 'Get started';

  @override
  String get billingAddDiscount => 'Add discount';

  @override
  String get billingAddDiscountCaps => 'ADD DISCOUNT';

  @override
  String get billingAddOnePaymentFirst => 'Add at least one payment first.';

  @override
  String get billingAddPayment => 'ADD PAYMENT';

  @override
  String get billingAddPaymentTitle => 'Add payment';

  @override
  String get billingAddTips => 'Add tips';

  @override
  String billingAmountExceedsRemaining(String amount) {
    return 'Amount cannot exceed remaining ($amount).';
  }

  @override
  String get billingAppliedDiscounts => 'Applied discounts';

  @override
  String get billingApply => 'APPLY';

  @override
  String get billingApplyServiceTax => 'Apply service tax';

  @override
  String get billingApplyTo => 'Apply to';

  @override
  String get billingAttachCustomer =>
      'Attach a customer to this bill (required for credit).';

  @override
  String get billingCheckoutComplete => 'Checkout complete';

  @override
  String get billingComplete => 'COMPLETE';

  @override
  String get billingCompleteWithoutPayment => 'COMPLETE WITHOUT PAYMENT';

  @override
  String get billingCompletingCheckout => 'Completing checkout…';

  @override
  String get billingCoverFullOrCredit =>
      'Cover the full amount or put the balance on credit with a customer.';

  @override
  String get billingCreditCancelled =>
      'Credit cancelled. Checkout was not completed.';

  @override
  String billingCreditLimitContinue(String message) {
    return '$message\n\nContinue anyway?';
  }

  @override
  String billingCreditLimitExceeded(
    String limit,
    String outstanding,
    String amountDue,
  ) {
    return 'Credit limit $limit would be exceeded (outstanding $outstanding + this sale $amountDue).';
  }

  @override
  String get billingCreditLimitWarningTitle => 'Credit limit warning';

  @override
  String get billingCreditNeedsCustomer =>
      'Credit payment needs a customer. Select a customer and try again.';

  @override
  String get billingCreditPlaceFailed =>
      'Could not place remaining balance on credit. Checkout cancelled.';

  @override
  String get billingCustomerForCredit => 'Customer for credit';

  @override
  String get billingCustomerOptionalCredit =>
      'Optional — required when paying on credit';

  @override
  String billingDiscountAdded(String title) {
    return 'Added \"$title\"';
  }

  @override
  String billingDiscountsCount(int count) {
    return 'Discounts ($count)';
  }

  @override
  String billingDraftSaved(int orderId) {
    return 'Draft order #$orderId saved.';
  }

  @override
  String get billingEntireOrder => 'Entire order';

  @override
  String get billingInvalidDiscountPct =>
      'Enter a discount percentage between 1 and 100';

  @override
  String get billingNoItems => 'No items to bill.';

  @override
  String get billingNoPaymentMethods => 'No payment methods configured.';

  @override
  String billingOrderCreditBalance(int orderId) {
    return 'Order #$orderId — balance added to customer credit';
  }

  @override
  String get billingOrderFullyCovered => 'Order is already fully covered.';

  @override
  String billingOrderPaidVia(int orderId, String mode) {
    return 'Order #$orderId paid via $mode';
  }

  @override
  String billingOrderPlacedBalance(int orderId, String amount) {
    return 'Order #$orderId placed with balance $amount';
  }

  @override
  String billingPaid(String amount) {
    return 'Paid  $amount';
  }

  @override
  String billingPaymentSale(String paymentLabel) {
    return '$paymentLabel sale';
  }

  @override
  String get billingPercentageHint => '1-100';

  @override
  String get billingPlaceFullCredit => 'Place full amount on credit';

  @override
  String get billingPlaceFullOnCredit => 'Place full amount on credit';

  @override
  String get billingPlaceWithBalance => 'PLACE WITH BALANCE';

  @override
  String billingRemainingAddPayment(String amount) {
    return 'Remaining $amount. Add another payment or place with balance due.';
  }

  @override
  String billingRemainingOnCredit(String amount) {
    return 'Remaining on credit: $amount';
  }

  @override
  String get billingRemoveAllDiscounts => 'Remove all discounts';

  @override
  String get billingRemoveExistingTax => 'Remove existing tax';

  @override
  String get billingRemoveTips => 'Remove tips';

  @override
  String get billingSaveAsDraft => 'Save as draft';

  @override
  String billingSelectCustomerCredit(String amount) {
    return 'Select or add the customer to put $amount on their credit account.';
  }

  @override
  String get billingServiceTaxApplied => 'Service tax applied';

  @override
  String get billingServiceTaxLabel => 'Service tax';

  @override
  String billingTaxPct(String percent) {
    return 'Tax $percent%';
  }

  @override
  String get billingTaxPlaceholder => 'Enter tax percentage (1-100)';

  @override
  String billingTipsAmount(String amount) {
    return 'Tips $amount';
  }

  @override
  String get billingTipsApplied => 'Tips applied';

  @override
  String get billingTipsPlaceholder => 'Enter tip amount';

  @override
  String get billingTitle => 'Billing & Payment';

  @override
  String billingToPay(String amount) {
    return 'To pay  $amount';
  }

  @override
  String get catalogAllPackages => 'All packages';

  @override
  String get catalogAppliesTo => 'Applies to';

  @override
  String get catalogBarcode => 'Barcode';

  @override
  String get catalogBillOffer => 'Bill offer';

  @override
  String get catalogEmpty => 'No products in catalog';

  @override
  String catalogMrpPrice(String amount) {
    return 'MRP $amount';
  }

  @override
  String get catalogNoActiveOffers => 'No active offers synced for this store';

  @override
  String get catalogNoAddonGroups => 'No add-on groups linked to this package';

  @override
  String get catalogNoCatalogueDevice =>
      'No catalogue on this device yet. Open Sync and pull products, add-ons, and offers.';

  @override
  String get catalogNoItemsInGroup => 'No items in this group';

  @override
  String get catalogNoOffersTargetPackage => 'No offers target this package';

  @override
  String get catalogNoPackagesView => 'No packages in this view';

  @override
  String catalogOffersCount(int count) {
    return 'Offers ($count)';
  }

  @override
  String catalogPackagesCount(int count) {
    return 'Packages ($count)';
  }

  @override
  String catalogProductPrefix(String name) {
    return 'Product · $name';
  }

  @override
  String get catalogRefreshLocal => 'Refresh from local DB';

  @override
  String get catalogRefreshTooltip => 'Refresh from local DB';

  @override
  String get catalogSearchExtended => 'Search product, package, barcode…';

  @override
  String get catalogSearchHint => 'Search products';

  @override
  String get catalogSell => 'Sell';

  @override
  String get catalogTitle => 'Catalog';

  @override
  String get catalogUnit => 'Unit';

  @override
  String get commonActions => 'Actions';

  @override
  String get commonActive => 'Active';

  @override
  String get commonAddons => 'Add-ons';

  @override
  String get commonAddress => 'Address';

  @override
  String get commonAmount => 'Amount';

  @override
  String get commonAmountToPay => 'Amount to Pay';

  @override
  String get commonBackToSelling => 'Back to selling';

  @override
  String commonBal(String amount) {
    return 'Bal $amount';
  }

  @override
  String get commonBalanceDue => 'Balance due';

  @override
  String get commonBusiness => 'Business';

  @override
  String get commonCard => 'Card';

  @override
  String get commonCash => 'Cash';

  @override
  String get commonCatalogs => 'Catalogs';

  @override
  String get commonCategories => 'Categories';

  @override
  String get commonChangePaymentMethod => 'Change Payment Method';

  @override
  String get commonChannel => 'Channel';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonClearCustomer => 'Clear customer';

  @override
  String get commonCode => 'Code';

  @override
  String get commonCollect => 'Collect';

  @override
  String get commonCompany => 'Company';

  @override
  String get commonConfirmPayment => 'Confirm Payment';

  @override
  String get commonConfirmPaymentCaps => 'CONFIRM PAYMENT';

  @override
  String get commonContactEmail => 'Contact email';

  @override
  String get commonCredit => 'Credit';

  @override
  String get commonCreditHistory => 'Credit history';

  @override
  String get commonCreditOrders => 'Credit Orders';

  @override
  String get commonCredits => 'Credits';

  @override
  String get commonCurrent => 'Current';

  @override
  String get commonCustomer => 'Customer';

  @override
  String get commonCustomers => 'Customers';

  @override
  String get commonDate => 'Date';

  @override
  String get commonDelivery => 'Delivery';

  @override
  String get commonDeliveryCharge => 'Delivery Charge';

  @override
  String get commonDetails => 'Details';

  @override
  String get commonDevice => 'Device';

  @override
  String get commonDeviceId => 'Device ID';

  @override
  String get commonDiscount => 'Discount';

  @override
  String commonDiscountPct(String title, String percent) {
    return '$title ($percent%)';
  }

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get commonDone => 'Done';

  @override
  String get commonDueDate => 'Due date';

  @override
  String get commonDueDateOptional => 'Due date (optional)';

  @override
  String commonDueValue(String date) {
    return 'Due $date';
  }

  @override
  String get commonEmail => 'Email';

  @override
  String get commonEmpty => '—';

  @override
  String get commonEnterQuantityGtZero => 'Enter a quantity greater than zero.';

  @override
  String get commonExact => 'Exact';

  @override
  String get commonExporting => 'Exporting catalogue…';

  @override
  String get commonFailed => 'Failed';

  @override
  String get commonFrequency => 'Frequency';

  @override
  String get commonGuest => 'Guest';

  @override
  String get commonHardware => 'Hardware';

  @override
  String get commonHideDetails => 'Hide details';

  @override
  String get commonIdentifier => 'Identifier';

  @override
  String get commonInactive => 'Inactive';

  @override
  String get commonInfo => 'Info';

  @override
  String get commonItem => 'Item';

  @override
  String get commonItems => 'Items';

  @override
  String commonKot(String qty) {
    return 'KOT $qty';
  }

  @override
  String get commonLedger => 'Ledger';

  @override
  String get commonLimit => 'Limit';

  @override
  String commonLineTotal(String amount) {
    return 'Line total: $amount';
  }

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonMiscItem => 'Misc item';

  @override
  String get commonMonthly => 'Monthly';

  @override
  String get commonName => 'Name';

  @override
  String commonNetDays(int days) {
    return 'Net $days';
  }

  @override
  String get commonNetTotal => 'Net Total';

  @override
  String get commonNever => 'Never';

  @override
  String get commonNewOrder => 'New Order';

  @override
  String get commonNext => 'Next';

  @override
  String get commonNo => 'No';

  @override
  String get commonNoData => 'No data';

  @override
  String get commonNoPaymentsYet => 'No payments yet';

  @override
  String get commonNoSalesPeriod => 'No sales in this period';

  @override
  String get commonNone => 'None';

  @override
  String get commonNotSet => 'Not set';

  @override
  String get commonNotes => 'Notes';

  @override
  String commonOfAmount(String amount) {
    return 'of $amount';
  }

  @override
  String get commonOfferApplied => 'Offer applied';

  @override
  String commonOfferLabel(String labels) {
    return 'Offer · $labels';
  }

  @override
  String get commonOffers => 'Offers';

  @override
  String get commonOk => 'OK';

  @override
  String get commonOnline => 'Online';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonOpenCreditAccount => 'Open credit account';

  @override
  String get commonOptional => 'Optional';

  @override
  String get commonOrderCount => 'Order count';

  @override
  String get commonOrderHistory => 'Order History';

  @override
  String get commonOrderLabel => 'Order';

  @override
  String get commonOrderTotal => 'Order total';

  @override
  String get commonOrders => 'Orders';

  @override
  String get commonOrganisation => 'Organisation';

  @override
  String get commonOrganisationRole => 'Organisation role';

  @override
  String get commonOrganisationTime => 'Organisation time';

  @override
  String get commonOutstanding => 'Outstanding';

  @override
  String get commonOverdue => 'Overdue';

  @override
  String get commonOverdueSuffix => ' · overdue';

  @override
  String get commonOwner => 'owner';

  @override
  String get commonPassword => 'Password';

  @override
  String get commonPay => 'Pay';

  @override
  String commonPayVia(String method) {
    return 'Pay via $method';
  }

  @override
  String get commonPaymentMode => 'Payment mode';

  @override
  String commonPaymentNumber(String id) {
    return 'Payment #$id';
  }

  @override
  String get commonPaymentTypes => 'Payment Types';

  @override
  String get commonPayments => 'Payments';

  @override
  String get commonPending => 'Pending';

  @override
  String get commonPercentage => 'Percentage';

  @override
  String get commonPhone => 'Phone';

  @override
  String get commonPlan => 'Plan';

  @override
  String commonPosCode(String code) {
    return 'POS $code';
  }

  @override
  String get commonPosCodeLabel => 'POS code';

  @override
  String get commonPreparing => 'Preparing';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get commonPrice => 'Price';

  @override
  String get commonProducts => 'Products';

  @override
  String get commonQty => 'Qty';

  @override
  String get commonQuantity => 'Quantity';

  @override
  String get commonReferenceOptional => 'Reference (optional)';

  @override
  String get commonRefunds => 'Refunds';

  @override
  String get commonRegNo => 'Reg no.';

  @override
  String commonRegValue(String reg) {
    return 'Reg $reg';
  }

  @override
  String get commonRemaining => 'Remaining';

  @override
  String get commonReports => 'Reports';

  @override
  String get commonRequired => 'Required';

  @override
  String get commonRetail => 'Retail';

  @override
  String get commonSaveOffline => 'Save offline';

  @override
  String get commonSaving => 'Saving…';

  @override
  String get commonSchedule => 'Schedule';

  @override
  String get commonSelect => 'Select';

  @override
  String get commonSelectCustomer => 'Select customer';

  @override
  String commonServeNumber(String number) {
    return 'Serve #$number';
  }

  @override
  String get commonServiceInstance => 'Service instance';

  @override
  String commonServiceInstanceShort(String id) {
    return 'SI $id';
  }

  @override
  String get commonServiceTax => 'Service tax';

  @override
  String commonServiceTaxPct(String percent) {
    return 'Service Tax ($percent%)';
  }

  @override
  String get commonSettleFullBalance => 'Settle full balance';

  @override
  String get commonSettled => 'Settled';

  @override
  String get commonSkipped => 'Skipped';

  @override
  String get commonStaff => 'Staff';

  @override
  String get commonStatus => 'Status';

  @override
  String get commonStore => 'Store';

  @override
  String get commonStoreId => 'Store ID';

  @override
  String get commonStoreRole => 'Store role';

  @override
  String get commonSubtotal => 'Subtotal';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonSummary => 'Summary';

  @override
  String get commonSynced => 'Synced';

  @override
  String get commonTable => 'Table';

  @override
  String get commonTax => 'Tax';

  @override
  String get commonTips => 'Tips';

  @override
  String get commonTitleLabel => 'Title';

  @override
  String get commonTotal => 'Total';

  @override
  String get commonTotalAmount => 'Total Amount';

  @override
  String get commonType => 'Type';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonUnnamedCustomer => 'Unnamed customer';

  @override
  String get commonUpi => 'UPI';

  @override
  String get commonUseCustomer => 'Use customer';

  @override
  String get commonView => 'View';

  @override
  String commonViewAllCount(int count) {
    return 'View all ($count)';
  }

  @override
  String get commonVoid => 'Void';

  @override
  String get commonVoucher => 'Voucher';

  @override
  String get commonWalkIn => 'Walk-in';

  @override
  String get commonWeekly => 'Weekly';

  @override
  String get commonYes => 'Yes';

  @override
  String get companyAddSubscriber => 'Add subscriber';

  @override
  String get companyAddToBranch => 'Add to branch';

  @override
  String get companyAddress => 'Address';

  @override
  String get companyAllPaymentMethodsAdded =>
      'All payment methods are already on this branch.';

  @override
  String get companyBranch => 'Branch';

  @override
  String get companyBranchLogo => 'Branch logo';

  @override
  String get companyBranchStoreName => 'Branch / store name';

  @override
  String get companyChannel => 'Channel';

  @override
  String get companyChannelPush => 'Push';

  @override
  String get companyChannelSlack => 'Slack';

  @override
  String get companyChannelSms => 'SMS';

  @override
  String get companyChannelWhatsApp => 'WhatsApp';

  @override
  String get companyChooseLogo => 'Choose company logo';

  @override
  String get companyContact => 'Contact';

  @override
  String get companyCouldNotAddSubscriber => 'Could not add subscriber.';

  @override
  String get companyCouldNotLoadReports => 'Could not load reports.';

  @override
  String get companyHubTitle => 'Company';

  @override
  String get companyIdentifier => 'Identifier';

  @override
  String get companyInvoiceBookings => 'Invoice / bookings';

  @override
  String companyLabelLocked(String label) {
    return '$label · locked';
  }

  @override
  String get companyLegal => 'Legal';

  @override
  String get companyLogo => 'Logo';

  @override
  String get companyLogoFilePath => 'Logo file path';

  @override
  String get companyLogoSavedOnDevice =>
      'Saved on this device · syncs with Save';

  @override
  String get companyMailerFixedHint =>
      'Report and invoice/bookings mailers are fixed by Ellan POS. Credentials cannot be changed or added on the tablet.';

  @override
  String get companyMethod => 'Method';

  @override
  String get companyNoPaymentMethodsBranch =>
      'No payment methods on this branch yet. Use Add to branch.';

  @override
  String get companyNoPaymentVariants =>
      'No payment method variants are available from the server.';

  @override
  String get companyNoSubscribers => 'No subscribers yet.';

  @override
  String get companyNoSubscribersYet => 'No subscribers yet.';

  @override
  String get companyOpenStore => 'Open store';

  @override
  String get companyOwner => 'Owner';

  @override
  String get companyOwnerSubscriberLocked =>
      'Owner subscriber cannot be removed.';

  @override
  String get companyPaymentMethod => 'Payment method';

  @override
  String companyPaymentMethodAdded(String label) {
    return '$label added to this branch.';
  }

  @override
  String get companyPeriodAnnually => 'Annually';

  @override
  String get companyPeriodDaily => 'Daily';

  @override
  String get companyPeriodicity => 'Periodicity';

  @override
  String get companyRegistrationNumber => 'Registration number';

  @override
  String get companyReportsHint => 'Sales report subscribers and schedule';

  @override
  String get companyReportsTitle => 'Reports';

  @override
  String get companySalesReports => 'Sales reports';

  @override
  String get companySalesReportsHint =>
      'Daily sales summaries are emailed to every enabled subscriber using the system report mailer.';

  @override
  String get companySalesReportsTitle => 'Sales reports';

  @override
  String get companySaveChanges => 'Save changes';

  @override
  String get companySavedOnDevice => 'Saved on this device · syncs with Save';

  @override
  String get companySettingsNameRegAddress =>
      'Name, registration, address, tax, phone, email, identifier';

  @override
  String get companySettingsSaved => 'Company settings saved.';

  @override
  String get companySettingsSavedOffline =>
      'Saved on this device. Company details will sync when you\'re back online.';

  @override
  String get companySettingsPendingSync =>
      'Not synced yet — changes are saved on this device and will upload on the next sync.';

  @override
  String companySettingsSavedNotSynced(String reason) {
    return 'Saved on this device, but the server rejected the update: $reason';
  }

  @override
  String get companySettingsTitle => 'Company settings';

  @override
  String get companyStaffsListHint =>
      'List staff and add new accounts for this store';

  @override
  String get companyStaffsTitle => 'Staff';

  @override
  String get companyStoreSetupHint => 'Catalogue, offers, add-ons';

  @override
  String get companySubscribers => 'Subscribers';

  @override
  String get companySystemEmailLocked => 'System email (locked)';

  @override
  String get companySystemMailerLocked => 'System mailer (locked)';

  @override
  String get companyTapMethodToAdd => 'Tap a method to add';

  @override
  String get companyTaxRegistrationNumber => 'Tax registration number';

  @override
  String get companyUploadLogo => 'Upload logo';

  @override
  String get companyUseFile => 'Use file';

  @override
  String get companyWallet => 'Wallet';

  @override
  String creditsAccountCount(int count) {
    return '$count account(s)';
  }

  @override
  String get creditsAllowedWarn => 'Allowed (warn)';

  @override
  String get creditsBlocked => 'Blocked';

  @override
  String creditsCancelFailed(String error) {
    return 'Cancel failed: $error';
  }

  @override
  String get creditsCancelScheduleAction => 'Cancel schedule';

  @override
  String creditsCancelScheduleBody(String amount, String dueDate) {
    return 'Cancel $amount due $dueDate?';
  }

  @override
  String get creditsCancelScheduleTitle => 'Cancel scheduled repayment';

  @override
  String get creditsCollect => 'Collect';

  @override
  String get creditsCollectPayment => 'Collect payment';

  @override
  String creditsCollectedScheduled(String amount) {
    return 'Collected scheduled $amount';
  }

  @override
  String creditsCollectedVia(String amount, String mode) {
    return 'Collected $amount via $mode';
  }

  @override
  String get creditsCreditAccount => 'Credit account';

  @override
  String get creditsCreditLimit => 'Credit limit';

  @override
  String get creditsCreditLimitLabel => 'Credit limit';

  @override
  String creditsCreditNumber(String id) {
    return 'Credit #$id';
  }

  @override
  String creditsCreditOrderLine(String creditId, String orderId) {
    return 'Credit #$creditId · Order #$orderId';
  }

  @override
  String creditsCreditSaleOrder(String orderId) {
    return 'Credit sale · Order #$orderId';
  }

  @override
  String get creditsCreditSalePlain => 'Credit sale';

  @override
  String get creditsCreditSales => 'Credit sales';

  @override
  String get creditsCreditSoFar => 'Credit so far';

  @override
  String get creditsCustomerCreditLimit => 'Customer credit limit';

  @override
  String get creditsCustomerLimit => 'Customer credit limit';

  @override
  String creditsCustomerScopedTitle(String name) {
    return 'Credit · $name';
  }

  @override
  String get creditsHardBlock => 'Hard block';

  @override
  String get creditsInstallments => 'Installments';

  @override
  String get creditsLedgerVoided => 'voided';

  @override
  String get creditsLimit => 'Limit';

  @override
  String creditsMaxAmount(String amount) {
    return 'Max $amount';
  }

  @override
  String get creditsNetTerms => 'Net terms';

  @override
  String creditsNetTermsDays(int days) {
    return '$days days';
  }

  @override
  String get creditsNoAccountsMatch => 'No accounts match the current filters.';

  @override
  String get creditsNoAccountsOnDevice =>
      'No credit accounts on this device yet.';

  @override
  String get creditsNoAccountsYet => 'No credit accounts on this device yet.';

  @override
  String get creditsNoCreditLimitHint =>
      'No credit limit for this customer. Set credit_limit_amount on Store/CustomerCredit/Account/<id>/ (or store defaults on Store/CustomerCredit/Settings/), then sync credits.';

  @override
  String get creditsNoCreditPayments => 'No credit payments recorded yet.';

  @override
  String get creditsNoCreditSales => 'No credit sales for this customer.';

  @override
  String get creditsNoLedger => 'No ledger activity yet.';

  @override
  String get creditsNoOpenScheduled => 'No open scheduled payments.';

  @override
  String get creditsNoRepaymentsYet => 'No repayments recorded yet.';

  @override
  String get creditsNoScheduledToday => 'No scheduled payments due today.';

  @override
  String get creditsNoSchedules => 'No installment schedules on this account.';

  @override
  String get creditsNoUpcoming => 'No upcoming repayments scheduled.';

  @override
  String get creditsNotSet => 'Not set';

  @override
  String get creditsNothingOutstanding =>
      'Nothing outstanding for this customer.';

  @override
  String get creditsOneShot => 'One-shot';

  @override
  String get creditsOpenAccount => 'Open credit account';

  @override
  String get creditsOutstanding => 'Outstanding';

  @override
  String creditsOutstandingAmount(String amount) {
    return 'Outstanding $amount';
  }

  @override
  String get creditsOutstandingOnly => 'Outstanding only';

  @override
  String get creditsOverLimit => 'Over-limit';

  @override
  String get creditsOverLimitLabel => 'Over-limit';

  @override
  String get creditsPaymentSchedules => 'Payment schedules';

  @override
  String get creditsRepaid => 'Repaid';

  @override
  String creditsRepaymentMode(String mode) {
    return 'Repayment · $mode';
  }

  @override
  String get creditsRepaymentVoided => 'Repayment voided.';

  @override
  String get creditsScheduleBody =>
      'Record an upcoming payment promise from this customer.';

  @override
  String get creditsSchedulePayments => 'Schedule payments';

  @override
  String get creditsScheduleRepayment => 'Schedule repayment';

  @override
  String creditsScheduledFor(String amount, String dueDate) {
    return 'Scheduled $amount for $dueDate';
  }

  @override
  String get creditsSearchHint => 'Search customer name or id';

  @override
  String get creditsSort => 'Sort';

  @override
  String get creditsSortHighest => 'Highest';

  @override
  String get creditsSortLongPending => 'Long pending';

  @override
  String get creditsStoreCreditSettings => 'Store credit settings';

  @override
  String get creditsStoreSettings => 'Store credit settings';

  @override
  String get creditsTitle => 'Credits';

  @override
  String get creditsTodayScheduled => 'Today\'s scheduled payments';

  @override
  String get creditsUpcoming => 'Upcoming repayments';

  @override
  String creditsUsedAvailable(String used, String available) {
    return 'Used $used · Available $available';
  }

  @override
  String get creditsView => 'View';

  @override
  String creditsVoidRepaymentBody(String amount, String date) {
    return 'Void $amount paid on $date?';
  }

  @override
  String get creditsVoidRepaymentTitle => 'Void repayment';

  @override
  String get creditsVoidedOnPos => 'Voided on POS tablet';

  @override
  String get creditsWarnOnly => 'Warn only';

  @override
  String get customerAdvanceAdd => 'Add customer advance';

  @override
  String get customerAdvanceAvailable => 'Advance available';

  @override
  String customerAdvanceAvailableValue(String amount) {
    return 'Advance available: $amount';
  }

  @override
  String get customerAdvanceExplanation =>
      'Money received is applied to any balance due first. The remainder stays available for future sales.';

  @override
  String get customerAdvanceRecord => 'Record advance';

  @override
  String get customerAdvanceRecorded => 'Customer advance recorded.';

  @override
  String get customerBalanceDue => 'Balance due';

  @override
  String customerBalanceDueValue(String amount) {
    return 'Balance due: $amount';
  }

  @override
  String get customerCouldNotSave => 'Could not save customer';

  @override
  String get customerCreditHistory => 'Credit history';

  @override
  String get customerEmailOptional => 'Email (optional)';

  @override
  String get customerEnterValidPhone => 'Enter a valid 10-digit phone';

  @override
  String get customerNameOptional => 'Name (optional)';

  @override
  String get customerNoCreditPaymentsYet => 'No credit payments recorded yet.';

  @override
  String get customerNoCreditSalesYet =>
      'No credit sales for this customer yet.';

  @override
  String get customerNoOrdersYet => 'No orders for this customer yet.';

  @override
  String get customerOrderHistory => 'Order history';

  @override
  String get customerProfileTitle => 'Customer profile';

  @override
  String get customerSaveContinue => 'Save & continue';

  @override
  String get customerSearchHintFull => 'Search phone, email, or name';

  @override
  String get customerSelectOrAdd => 'Select or add a customer to continue';

  @override
  String get customerSelectSearchHint => 'Search customers';

  @override
  String get customersBackToSearch => 'Back to search';

  @override
  String get customersEmpty =>
      'No retail or business customers for this store yet. Add them under Retail Customers / Business Customers, then sync.';

  @override
  String get customersNew => 'New customer';

  @override
  String get customersSearchHint => 'Search by name, phone, or email';

  @override
  String get customersTitle => 'Customers';

  @override
  String get dashboardCreditAmount => 'Credit amount';

  @override
  String get dashboardCreditOrders => 'Credit Orders';

  @override
  String get dashboardCreditOutstanding => 'Credit outstanding';

  @override
  String get dashboardCredits => 'Credits';

  @override
  String get dashboardFilterMonth => 'This Month';

  @override
  String get dashboardFilterToday => 'Today';

  @override
  String get dashboardFilterWeek => 'This Week';

  @override
  String get dashboardFilterYear => 'This Year';

  @override
  String get dashboardFilterYesterday => 'Yesterday';

  @override
  String get dashboardMetricCancelled => 'Cancelled';

  @override
  String get dashboardMetricDelivered => 'Delivered';

  @override
  String get dashboardMetricDineIn => 'Dine-In';

  @override
  String get dashboardMetricOrders => 'Orders';

  @override
  String get dashboardMetricPickup => 'Pickup';

  @override
  String get dashboardMetricTotalSales => 'Total Sales';

  @override
  String get dashboardNoCategorySales => 'No category sales yet';

  @override
  String get dashboardNoOpenCredits => 'No open credits';

  @override
  String get dashboardNoPaymentsYet => 'No payments yet';

  @override
  String get dashboardNoProductSales => 'No product sales yet';

  @override
  String get dashboardNoSalesYet => 'No sales in this period';

  @override
  String get dashboardNoStaffSales => 'No staff sales in this period.';

  @override
  String get dashboardOpenCredits => 'Open credits';

  @override
  String get dashboardOrderCount => 'Order count';

  @override
  String get dashboardOrderTotal => 'Order total';

  @override
  String get dashboardPaymentMix => 'Payment mix';

  @override
  String get dashboardPaymentTypes => 'Payment Types';

  @override
  String get dashboardRefunds => 'Refunds';

  @override
  String get dashboardRepayments => 'Repayments';

  @override
  String get dashboardSalesByStaff => 'Sales by staff';

  @override
  String get dashboardSalesTrend => 'Sales trend';

  @override
  String dashboardSoldCount(int count) {
    return '$count sold';
  }

  @override
  String get dashboardStaffSalesHint =>
      'Orders · amount · credit by checkout staff';

  @override
  String get dashboardTitle => 'POS Dashboard';

  @override
  String get dashboardTopCategories => 'Top Categories';

  @override
  String get dashboardTopProducts => 'Top Products';

  @override
  String get deviceAutoSync => 'Auto sync';

  @override
  String deviceAutoSyncEnabled(String interval) {
    return 'Auto sync enabled — $interval';
  }

  @override
  String get deviceAutoSyncOff => 'Auto sync turned off';

  @override
  String get deviceAutoSyncRunning => 'Running in the background';

  @override
  String get deviceAutoSyncStarting => 'Running in the background (starting…)';

  @override
  String get deviceCashDenominations => 'Cash denominations';

  @override
  String get deviceCashDenomsHint =>
      'Comma-separated tender chips shown on Billing & Payment.';

  @override
  String get deviceCashDenomsSaved => 'Cash denominations saved.';

  @override
  String get deviceCompanySettingsStaff => 'Company (settings & staff)';

  @override
  String get deviceDangerZone => 'Danger zone';

  @override
  String get deviceEnableAutoSync => 'Enable auto sync';

  @override
  String get deviceInterval15Min => 'Every 15 minutes';

  @override
  String get deviceInterval1Hour => 'Every 1 hour';

  @override
  String get deviceInterval1Min => 'Every 1 minute';

  @override
  String get deviceInterval30Min => 'Every 30 minutes';

  @override
  String get deviceInterval5Min => 'Every 5 minutes';

  @override
  String deviceIntervalEveryMinutes(int minutes) {
    return 'Every $minutes minutes';
  }

  @override
  String deviceIntervalEverySeconds(int seconds) {
    return 'Every $seconds seconds';
  }

  @override
  String get deviceKeepSavedServerUrls => 'Keep saved server URLs';

  @override
  String get deviceKeepSavedServers => 'Keep saved server URLs';

  @override
  String get deviceLastOnlineLogin => 'Last online login';

  @override
  String get deviceLastSuccessfulSync => 'Last successful sync';

  @override
  String deviceLeaseDaysCount(int count) {
    return '$count days';
  }

  @override
  String get deviceLeaseOneDay => '1 day';

  @override
  String get deviceLoginLease => 'Login lease';

  @override
  String get deviceLoginLeaseDays => 'Login lease days';

  @override
  String get deviceOnlineSignInRequired => 'Online sign-in required';

  @override
  String get deviceOpenSyncNow => 'Open sync now';

  @override
  String get deviceResetAction => 'Reset';

  @override
  String get deviceResetAllLocal => 'Reset all local data';

  @override
  String get deviceResetConfirmBody =>
      'This permanently deletes local orders, catalogue, customers, sync history, device approval flags, and login on this tablet. It does not delete anything on the server.';

  @override
  String get deviceResetConfirmTitle => 'Reset all local data?';

  @override
  String deviceResetFailed(String error) {
    return 'Reset failed: $error';
  }

  @override
  String get deviceResetLocalBody =>
      'Wipe this tablet’s offline database, device setup, login, and sync history so you can test from a clean first launch.';

  @override
  String get deviceResetting => 'Resetting…';

  @override
  String get deviceSaveDenominations => 'Save denominations';

  @override
  String get deviceSettingsTitle => 'Device settings';

  @override
  String get deviceSyncHistory => 'Sync history (last 20)';

  @override
  String get deviceSyncInterval => 'Sync interval';

  @override
  String get deviceSyncOnTapOnly => 'Only sync when you tap Sync';

  @override
  String get deviceTypeResetConfirm => 'Type RESET to confirm';

  @override
  String get deviceTypeResetToConfirm => 'Type RESET to confirm';

  @override
  String get deviceValidUntil => 'Valid until';

  @override
  String get dineInFloorFirst => 'First Floor';

  @override
  String get dineInBooked => 'Booked';

  @override
  String get dineInTableUnavailable =>
      'This table is no longer available. Please select another table.';

  @override
  String get dineInNoTables =>
      'No tables configured. Sync or configure the store\'s floors and tables.';

  @override
  String get dineInRefreshTables => 'Refresh table availability';

  @override
  String get dineInFloorSecond => 'Second Floor';

  @override
  String dineInTable(String number) {
    return 'Table $number';
  }

  @override
  String get errorAccessDenied =>
      'Access denied. Ask an administrator to check this device and account.';

  @override
  String errorAmountExceedsOutstanding(String amount) {
    return 'Amount cannot exceed outstanding ($amount).';
  }

  @override
  String get errorBootstrapFailed => 'Bootstrap failed';

  @override
  String errorCancelFailed(String error) {
    return 'Cancel failed: $error';
  }

  @override
  String get errorCannotReachServer =>
      'Cannot reach server. Check your connection and Server.';

  @override
  String errorCatalogueExportFailed(String message) {
    return 'Catalogue export failed: $message';
  }

  @override
  String errorCheckoutFailed(String error) {
    return 'Checkout failed: $error';
  }

  @override
  String errorCollectFailed(String error) {
    return 'Collect failed: $error';
  }

  @override
  String get errorConfigLookupFailed => 'Config lookup failed';

  @override
  String get errorCouldNotAddPaymentMethod => 'Could not add payment method.';

  @override
  String get errorCouldNotAddSubscriber => 'Could not add subscriber.';

  @override
  String errorCouldNotCancel(String error) {
    return 'Could not cancel: $error';
  }

  @override
  String errorCouldNotDeleteDraft(String error) {
    return 'Could not delete draft: $error';
  }

  @override
  String get errorCouldNotLoadCompanySettings =>
      'Could not load company settings.';

  @override
  String get errorCouldNotLoadReports => 'Could not load reports.';

  @override
  String get errorCouldNotLoadStaff => 'Could not load staff.';

  @override
  String errorCouldNotOpenDraft(String error) {
    return 'Could not open draft: $error';
  }

  @override
  String get errorCouldNotPickLogo =>
      'Could not pick logo. Fully restart the app (stop + run), then try again.';

  @override
  String get errorCouldNotSaveCompanySettings =>
      'Could not save company settings.';

  @override
  String errorCouldNotSaveDenoms(String error) {
    return 'Could not save denominations: $error';
  }

  @override
  String errorCouldNotSaveDraft(String error) {
    return 'Could not save draft: $error';
  }

  @override
  String get errorCouldNotSync => 'Could not sync. Try again.';

  @override
  String get errorCouldNotUseCustomer =>
      'Could not use that customer. Try again.';

  @override
  String get errorCreditRequiresCustomer =>
      'Credit requires a saved customer. Try again.';

  @override
  String get errorDbNeedsUpdate =>
      'Local database needs an update. Fully restart the app, then try Sync again.';

  @override
  String errorDbOutdated(String detail) {
    return 'Local database is outdated ($detail). Fully restart the app, then Sync again.';
  }

  @override
  String get errorFileNotFound => 'File not found.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String errorHttpFallback(String fallback, int statusCode) {
    return '$fallback (HTTP $statusCode)';
  }

  @override
  String get errorInvalidCredentials => 'Invalid credentials';

  @override
  String get errorInvalidEmail => 'Invalid email address';

  @override
  String get errorInvalidPhone => 'Must be exactly 10 digits';

  @override
  String get errorNameMinLength => 'Minimum 3 characters';

  @override
  String get errorNamePackageUnitPriceRequired =>
      'Name, package, unit and price are required';

  @override
  String get errorNetwork => 'Cannot reach server';

  @override
  String errorNoCachedPosConfig(String orgCode) {
    return 'No cached POS config for \"$orgCode\". Complete device setup first.';
  }

  @override
  String errorOrderNotFound(int orderId) {
    return 'Order #$orderId was not found.';
  }

  @override
  String get errorOrganisationNotFound => 'Organisation not found';

  @override
  String get errorParentOrgNotFound => 'Parent organisation was not found.';

  @override
  String errorPaymentFailed(String error) {
    return 'Payment failed: $error';
  }

  @override
  String errorRefundFailed(String error) {
    return 'Refund failed: $error';
  }

  @override
  String get errorRequiredField => 'This field is required';

  @override
  String errorScheduleFailed(String error) {
    return 'Schedule failed: $error';
  }

  @override
  String get errorSecureConnectionFailed =>
      'Secure connection failed. Check the server address and try again.';

  @override
  String get errorSelectCustomerForCredit =>
      'Select a customer to put the balance on credit.';

  @override
  String get errorSignInFailed =>
      'Sign-in failed. Check your email and password, then try again.';

  @override
  String get errorSignInOnlineFirst =>
      'Sign in online first to update company settings.';

  @override
  String get errorSignupFailed => 'Signup failed.';

  @override
  String errorSyncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get errorUnableLoadSignupOptions => 'Unable to load signup options';

  @override
  String errorVoidFailed(String error) {
    return 'Void failed: $error';
  }

  @override
  String errorWithMessage(String message, String error) {
    return '$message: $error';
  }

  @override
  String errorWithStatus(String fallback, String statusCode) {
    return '$fallback ($statusCode)';
  }

  @override
  String get forgotPasswordBackToSignIn => 'Back to Sign In';

  @override
  String get forgotPasswordInstruction =>
      'Please enter your registered Email address or Phone Number.';

  @override
  String get forgotPasswordSendLink => 'Send Reset Link';

  @override
  String get forgotPasswordSuccess =>
      'Password reset link sent to your registered address!';

  @override
  String get forgotPasswordTitle => 'Forgot Password?';

  @override
  String get homeActivityPrompt => 'What would you like to do today?';

  @override
  String get homeCatalogs => 'Catalogs';

  @override
  String get homeCompany => 'Company';

  @override
  String get homeCreateOrder => 'New Order';

  @override
  String get homeCredits => 'Credits';

  @override
  String get homeCustomers => 'Customers';

  @override
  String get homeDashboardDesc => 'View analytics and summary';

  @override
  String get homeDeviceSettings => 'Device settings';

  @override
  String get homeDraftOrders => 'Drafts';

  @override
  String get homeLogoutTooltip => 'Logout';

  @override
  String get homeMenu => 'Menu';

  @override
  String homeNewOrderCount(int count) {
    return 'New Order ($count)';
  }

  @override
  String get homeNoItems => 'No items';

  @override
  String get homeNoSavedDrafts => 'No saved drafts yet.';

  @override
  String get homeOpenStoreFirst => 'Open a store first';

  @override
  String get homeOrdersList => 'Orders';

  @override
  String get homeOrdersListDesc => 'View and manage all orders';

  @override
  String get homePosDashboard => 'POS Dashboard';

  @override
  String get homeRefunds => 'Refunds';

  @override
  String get homeSavedDrafts => 'Saved drafts';

  @override
  String get homeStoreAdminRequiredCompany =>
      'Store Admin access required for Company.';

  @override
  String get homeStoreAdminRequiredSetup =>
      'Store Admin access required for Store setup.';

  @override
  String get homeStoreSetup => 'Store setup';

  @override
  String get homeSyncFailedRetry => 'Sync failed — tap to retry';

  @override
  String get homeSyncTooltip => 'Sync';

  @override
  String homeViewAllCount(int count) {
    return 'View all ($count)';
  }

  @override
  String get homeWelcomeBack => 'Welcome Back';

  @override
  String get invoiceAmountPaid => 'Amount paid';

  @override
  String invoiceMethod(String method) {
    return 'Method: $method';
  }

  @override
  String get invoiceOrderSummary => 'Order summary';

  @override
  String get invoicePrinting => 'Printing to thermal printer…';

  @override
  String get invoiceTitle => 'Invoice / Receipt';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageTamil => 'Tamil';

  @override
  String get orderAddRecordPayment => 'Add / Record payment';

  @override
  String orderAddonsLabel(String labels) {
    return 'Add-ons: $labels';
  }

  @override
  String get orderAllItemsSentKitchen => 'All items already sent to kitchen.';

  @override
  String get orderAlreadyFullyPaid => 'This order is already fully paid.';

  @override
  String get orderAlreadyFullyRefunded =>
      'This payment is already fully refunded.';

  @override
  String get orderAppliedOffers => 'Applied offers';

  @override
  String get orderCancelConfirm => 'Mark this order as Cancelled?';

  @override
  String get orderCancelTitle => 'Cancel order';

  @override
  String get orderCancelled => 'Order cancelled.';

  @override
  String get orderCancelledTitle => 'Order cancelled';

  @override
  String orderChartPoint(String label, String amount, int count) {
    return '$label\n$amount\n$count orders';
  }

  @override
  String get orderClearFilter => 'Clear Filter';

  @override
  String get orderCompleted => 'Completed';

  @override
  String orderCouldNotOpenDraft(String error) {
    return 'Could not open draft: $error';
  }

  @override
  String get orderCreateAddItemsBeforeDraft =>
      'Add items before saving a draft.';

  @override
  String get orderCreateAddMiscItem => 'Add misc item';

  @override
  String get orderCreateAllItemsSentKitchen =>
      'All items already sent to kitchen.';

  @override
  String get orderCreateCartEmpty => 'Your cart is empty';

  @override
  String get orderCreateDeleteDraftBody =>
      'This clears the cart and removes the saved draft.';

  @override
  String get orderCreateDraftDeleted => 'Draft deleted.';

  @override
  String get orderCreateDraftSaved => 'Draft saved.';

  @override
  String get orderCreateEnterValidPrice => 'Enter a valid price';

  @override
  String orderCreateFloorTable(String floor, String table) {
    return 'Floor: $floor | Table: $table';
  }

  @override
  String get orderCreateHistoryRefreshed => 'History refreshed';

  @override
  String orderCreateHowMany(String unit) {
    return 'How many $unit?';
  }

  @override
  String orderCreateKotFailed(String error) {
    return 'KOT failed: $error';
  }

  @override
  String orderCreateKotSent(int batch, int orderId) {
    return 'KOT #$batch sent · Order #$orderId saved';
  }

  @override
  String get orderCreateMisc => 'Misc';

  @override
  String orderCreateNewOrderTitle(String orderType) {
    return 'New $orderType order';
  }

  @override
  String get orderCreateNoOrderHistory => 'No order history yet';

  @override
  String get orderCreatePastOrders => 'Past orders';

  @override
  String get orderCreateProductName => 'Product name';

  @override
  String orderCreateQuantityUnit(String unit) {
    return 'Quantity ($unit)';
  }

  @override
  String get orderCreateSaveDraftTooltip =>
      'Save cart draft (Home drafts, not Purchases list)';

  @override
  String get orderCreateTitle => 'New order';

  @override
  String get orderCreationSaveContinue => 'Save & continue';

  @override
  String get orderDeleteDraft => 'Delete draft';

  @override
  String get orderDeleteDraftConfirm =>
      'Permanently delete this draft order? This cannot be undone.';

  @override
  String get orderDeleteDraftQuestion => 'Delete draft?';

  @override
  String get orderDeliveredStatus => 'Order Delivered';

  @override
  String orderDetailsDueSuffix(String amount) {
    return ' · Due $amount';
  }

  @override
  String get orderDetailsNoPaymentsRecorded => 'No payments recorded yet.';

  @override
  String orderDetailsRefundablePayments(int count) {
    return '$count payment(s) still have a refundable balance. Refund them now to cancel this order, or open Payments to refund individually.';
  }

  @override
  String get orderDetailsTitle => 'Order details';

  @override
  String orderDetailsTotalPaid(String amount) {
    return 'Total paid $amount';
  }

  @override
  String get orderDetailsViewPayments => 'View payments';

  @override
  String get orderDraftDeleted => 'Draft deleted.';

  @override
  String get orderDraftSaved =>
      'Cart draft saved. Open it from Home → Saved drafts.';

  @override
  String get orderDeleteOrder => 'Delete order';

  @override
  String get orderDeleteOrderQuestion => 'Delete order?';

  @override
  String get orderDeleteOrderBody =>
      'This removes all products from the order, deletes its saved draft and frees the table. Items already sent to the kitchen are logged as cancelled.';

  @override
  String get orderDeletedTableFreed => 'Order deleted. Table is free.';

  @override
  String get orderCancelledTableFreed =>
      'Order was already sent to the kitchen or synced, so it was cancelled. Table is free.';

  @override
  String errorCouldNotDeleteOrder(String error) {
    return 'Could not delete order: $error';
  }

  @override
  String get orderGoToPayments => 'Go to payments';

  @override
  String orderHistoryId(String id, int orderId) {
    return '$id · Order #$orderId';
  }

  @override
  String orderKotFailed(String error) {
    return 'KOT failed: $error';
  }

  @override
  String get orderListCancelHint =>
      'To cancel an order, open Order details and use Cancel (refunds are required first when payments exist).';

  @override
  String get orderListClearFilter => 'Clear filter';

  @override
  String get orderListColumnActions => 'Actions';

  @override
  String get orderListColumnItems => 'Items';

  @override
  String get orderListColumnName => 'Name';

  @override
  String get orderListColumnOrderId => 'Order ID';

  @override
  String get orderListColumnOrderType => 'Type';

  @override
  String get orderListColumnPayment => 'Payment';

  @override
  String get orderListColumnSlNo => 'Sl No';

  @override
  String get orderListColumnStatus => 'Status';

  @override
  String get orderListColumnTime => 'Time';

  @override
  String get orderListColumnTotal => 'Total';

  @override
  String get orderListFilterAll => 'All';

  @override
  String get orderListFilterButton => 'Filter';

  @override
  String get orderListFilterDelivery => 'Delivery';

  @override
  String get orderListFilterDineIn => 'Dine In';

  @override
  String get orderListFilterPickup => 'Pickup';

  @override
  String get orderListNoOrdersFound => 'No orders found';

  @override
  String get orderListPayNow => 'Pay Now';

  @override
  String orderListPosCode(String code) {
    return 'POS $code';
  }

  @override
  String orderListPrintInvoiceBody(String orderId) {
    return 'Print invoice for Order #$orderId?';
  }

  @override
  String get orderListPrintInvoiceTitle => 'Print invoice';

  @override
  String get orderListRefreshButton => 'Refresh';

  @override
  String get orderListSearchHint => 'Search by order ID, name, phone, email...';

  @override
  String orderListSelectNewStatus(String orderId) {
    return 'Select new status for Order #$orderId:';
  }

  @override
  String orderListServeNumber(String number) {
    return 'Serve #$number';
  }

  @override
  String orderListUnableOpenOrder(String orderId) {
    return 'Unable to open order #$orderId';
  }

  @override
  String get orderListUpdateStatusTitle => 'Update status';

  @override
  String get orderMisc => 'Misc';

  @override
  String get orderNoItems => 'No items on this order.';

  @override
  String get orderNotSyncedRemote => 'Not yet synced to remote';

  @override
  String orderNumber(int orderId) {
    return 'Order #$orderId';
  }

  @override
  String orderOfferLabel(String label) {
    return 'Offer: $label';
  }

  @override
  String orderPaymentFailed(String error) {
    return 'Payment failed: $error';
  }

  @override
  String get orderPaymentsAddPayment => 'Add payment';

  @override
  String orderPaymentsCustomerLabel(String label) {
    return 'Customer $label';
  }

  @override
  String get orderPaymentsFullyPaid => 'This order is already fully paid.';

  @override
  String get orderPaymentsFullyRefunded =>
      'This payment is already fully refunded.';

  @override
  String get orderPaymentsNoPaymentsRecorded =>
      'No payments recorded for this order.';

  @override
  String get orderPaymentsNoPaymentsUnpaid =>
      'No payments yet. Record a payment for this unpaid order.';

  @override
  String get orderPaymentsOnlineUpi => 'Online / UPI';

  @override
  String orderPaymentsOrderSummary(String total, String remaining) {
    return 'Order total $total · Remaining $remaining';
  }

  @override
  String get orderPaymentsReasonOptional => 'Reason (optional)';

  @override
  String get orderPaymentsRecordTitle => 'Record payment';

  @override
  String orderPaymentsRecordedBalance(String balance) {
    return 'Payment recorded. Balance $balance';
  }

  @override
  String get orderPaymentsRecordedFullyPaid =>
      'Payment recorded. Order is fully paid.';

  @override
  String orderPaymentsRefLabel(String reference) {
    return 'Ref $reference';
  }

  @override
  String get orderPaymentsRefundAction => 'Refund';

  @override
  String get orderPaymentsRefundAmount => 'Refund amount';

  @override
  String orderPaymentsRefundAmountRange(String max) {
    return 'Enter an amount between 0.01 and $max.';
  }

  @override
  String get orderPaymentsRefundTitle => 'Refund payment';

  @override
  String orderPaymentsRefundableOf(String refundable, String total) {
    return 'Refundable $refundable of $total';
  }

  @override
  String orderPaymentsRefundedAmount(String amount) {
    return 'Refunded $amount.';
  }

  @override
  String get orderPaymentsRefundedCancelled =>
      'Payments refunded and order cancelled.';

  @override
  String orderPaymentsRefundedLeft(String refunded, String left) {
    return 'Refunded $refunded · Left $left';
  }

  @override
  String get orderPaymentsTitle => 'Order payments';

  @override
  String get orderPrintInvoice => 'Print Invoice';

  @override
  String orderPrintInvoiceConfirm(int orderId) {
    return 'Print invoice for Order #$orderId?';
  }

  @override
  String get orderReadyToServe => 'Ready To Serve';

  @override
  String get orderRecordPayment => 'Record payment';

  @override
  String get orderRefund => 'Refund';

  @override
  String get orderRefundAllAndCancel => 'Refund all & cancel';

  @override
  String orderRefundBeforeCancelBody(int count) {
    return '$count payment(s) still have a refundable balance. Refund them now to cancel this order, or open Payments to refund individually.';
  }

  @override
  String get orderRefundBeforeCancelTitle => 'Refund before cancel';

  @override
  String orderRefundFailed(String error) {
    return 'Refund failed: $error';
  }

  @override
  String get orderRefundNotNow => 'Not now';

  @override
  String get orderRefundPayment => 'Refund payment';

  @override
  String orderRefundedAmount(String amount) {
    return 'Refunded $amount.';
  }

  @override
  String get orderSaveDraft => 'Save cart draft';

  @override
  String get orderSummary => 'Summary';

  @override
  String get orderSyncedRemote => 'Synced to remote backend';

  @override
  String get orderTypeDineIn => 'Dine-In';

  @override
  String get orderTypePickup => 'Pickup';

  @override
  String get orderTypeSelection => 'Select Order Type';

  @override
  String orderTypeTable(String type, String table) {
    return '$type · $table';
  }

  @override
  String orderUnableToOpen(int orderId) {
    return 'Unable to open order #$orderId';
  }

  @override
  String get orderUpdateStatus => 'Update Status';

  @override
  String get pickupAddButton => 'Add';

  @override
  String get pickupCancelButton => 'Cancel';

  @override
  String get pickupName => 'Name';

  @override
  String get pickupNameHint => 'Enter your name';

  @override
  String get pickupPhone => 'Phone Number';

  @override
  String get pickupPhoneHint => 'Enter 10-digit number';

  @override
  String get profileAccount => 'Account';

  @override
  String get profileCode => 'Code';

  @override
  String get profileContactEmail => 'Contact email';

  @override
  String get profileCurrent => 'Current';

  @override
  String get profileCurrentStore => 'Current store';

  @override
  String get profileMyProfile => 'My Profile';

  @override
  String get profileOrganisationRole => 'Organisation role';

  @override
  String get profilePosOperator => 'POS Operator';

  @override
  String get profileRole => 'Role';

  @override
  String get profileServiceInstance => 'Service instance';

  @override
  String get profileSignedIn => 'Signed in';

  @override
  String get profileSignedInAs => 'Signed in as';

  @override
  String get profileStoreId => 'Store ID';

  @override
  String get profileStoreLabel => 'Store';

  @override
  String get profileStoreRole => 'Store role';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileType => 'Type';

  @override
  String refundsCount(int count) {
    return '$count refunds';
  }

  @override
  String get refundsEmpty => 'No refunds recorded yet.';

  @override
  String refundsPeriodTitle(String period) {
    return 'Refunds · $period';
  }

  @override
  String get refundsTitle => 'Refunds';

  @override
  String get scheduledPaymentsTitle => 'Scheduled payments';

  @override
  String get signInButton => 'Sign In';

  @override
  String get signInEmailPhone => 'Email / Mobile Number';

  @override
  String get signInEmailPhoneHint => 'Enter email or mobile';

  @override
  String get signInForgotPasswordPrompt => 'Forgot Password?';

  @override
  String get signInIdentifierHint => 'Email / phone / staff ID';

  @override
  String get signInNewCompany => 'New company?';

  @override
  String get signInPassword => 'Password';

  @override
  String get signInPasswordHint => 'Enter password';

  @override
  String get signInRenewDevice => 'Sign in to renew this device';

  @override
  String get signInShowPassword => 'Show Password';

  @override
  String get signInWelcome => 'Welcome';

  @override
  String get signupAlreadyHaveCompany => 'Already have a company? Sign in';

  @override
  String get signupBackToBranch => 'Back to branch details';

  @override
  String get signupBackToSignIn => 'Back to sign in';

  @override
  String get signupBodyBranch =>
      'Name the branch and city. Registration number is optional.';

  @override
  String get signupBodyBusinessType =>
      'Pick the business type. We will create a restaurant store under your branch.';

  @override
  String get signupBodyCompanyDetails =>
      'Tell us about the company and the owner who will administer it.';

  @override
  String get signupBodyCreateCompany => 'Create a new company for this tablet.';

  @override
  String get signupBodyCreateCompanyManual =>
      'Enter your server and parent organisation, then create a new company for this tablet.';

  @override
  String get signupBodyReady =>
      'Your company is ready. Sign in with your company identifier and password.';

  @override
  String get signupBodySettingUp =>
      'Creating your organisation, branch, and store — this only takes a moment.';

  @override
  String get signupBranchName => 'Branch name';

  @override
  String get signupBusinessBakery => 'Bakery';

  @override
  String get signupBusinessCafe => 'Cafe';

  @override
  String get signupBusinessOther => 'Others';

  @override
  String get signupBusinessRestaurant => 'Restaurant';

  @override
  String get signupCity => 'City';

  @override
  String get signupCompanyIdentifier => 'Company identifier';

  @override
  String get signupCompanyName => 'Company name';

  @override
  String get signupConfirmPassword => 'Confirm password';

  @override
  String get signupCouldNotPrepare => 'Could not prepare company signup.';

  @override
  String get signupCountry => 'Country';

  @override
  String get signupCreateCompany => 'Create company';

  @override
  String get signupJoinExistingDevice => 'Join an existing organisation device';

  @override
  String get signupLoginNow => 'Login now';

  @override
  String signupNoCountriesMatch(String query) {
    return 'No countries match “$query”';
  }

  @override
  String get signupOwnerName => 'Owner name';

  @override
  String get signupParentOrgHelp =>
      'We’ll check this organisation exists before continuing.';

  @override
  String get signupParentOrgHint =>
      'Parent organisation identifier or instance id';

  @override
  String get signupPasswordHelp =>
      'Keep it simple for floor staff — letters, numbers, or both.';

  @override
  String get signupPasswordHint => 'Password (min 6 letters/digits)';

  @override
  String get signupPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get signupPhoneHint => 'Phone number';

  @override
  String signupPhoneHintWithDial(String dialCode) {
    return 'Phone number (e.g. $dialCode 9876543210)';
  }

  @override
  String get signupChooseLanguage => 'Choose your preferred language';

  @override
  String get signupChooseLanguageHelp =>
      'Your signup screens will use this language. You can change it anytime using the language menu.';

  @override
  String get signupPreparing => 'Preparing company signup.';

  @override
  String get signupProgressCreatingCompany => 'Creating company';

  @override
  String get signupProgressCreatingUser => 'Creating user';

  @override
  String get signupProgressSettingAccount => 'Setting up account';

  @override
  String get signupProgressSettingBranch => 'Setting up branch';

  @override
  String get signupProgressSettingProfile => 'Setting profile';

  @override
  String get signupProgressSuccess => 'Congratulations — success';

  @override
  String get signupRegistrationOptional => 'Registration number (optional)';

  @override
  String get signupSearchCountry => 'Search country, code, or dial';

  @override
  String get signupSelectCountry => 'Select country';

  @override
  String get signupServerUrlHint =>
      'Server URL (e.g. http://192.168.1.10:8000)';

  @override
  String get signupTitleBranch => 'Your first branch';

  @override
  String get signupTitleBusinessType => 'What do you run?';

  @override
  String get signupTitleCompanyDetails => 'Company details';

  @override
  String get signupTitleCreateCompany => 'Create your company';

  @override
  String get signupTitleReady => 'You are ready';

  @override
  String get signupTitleSettingUp => 'Setting things up';

  @override
  String get signupTryAgain => 'Try again';

  @override
  String get signupUseIdentifierHelp =>
      'Use this identifier with your email/phone and password to sign in.';

  @override
  String get splashCheckAgain => 'Check again';

  @override
  String get splashDeviceNotApproved => 'Device not approved';

  @override
  String get splashInitError => 'Initialization Error';

  @override
  String get splashNoConfig => 'No stored configuration found';

  @override
  String get splashNoOrgCode => 'No stored organisation code found';

  @override
  String get splashPleaseSignIn => 'Please sign in to continue';

  @override
  String get splashTagline => 'Precision in every transaction';

  @override
  String get staffLockAllStaff => 'All staff';

  @override
  String get staffLockBranchNotLoaded => 'Branch not loaded';

  @override
  String get staffLockMore => 'More';

  @override
  String get staffLockOnlineSignIn => 'Online device sign-in';

  @override
  String get staffLockStaffId => 'Staff ID';

  @override
  String staffLockStaffStore(String storeName) {
    return 'Staff · $storeName';
  }

  @override
  String get staffLockSwitchStore => 'Switch store';

  @override
  String get staffLockTitle => 'Staff unlock';

  @override
  String get staffLockUnlock => 'Unlock';

  @override
  String get staffLogoutConfirmBody =>
      'This locks the register. Another staff member can unlock with their PIN or password.';

  @override
  String get staffLogoutConfirmBodyFull =>
      'You\'ll be signed out and your PIN is removed from this device. The next person signs in online. Orders already saved stay on this device.';

  @override
  String get staffLogoutConfirmTitle => 'Log out staff?';

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusCollected => 'Collected';

  @override
  String get statusCooking => 'Cooking';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusInitiated => 'Initiated';

  @override
  String get statusOpen => 'Open';

  @override
  String get statusOrderAccepted => 'Order Accepted';

  @override
  String get statusOrderCancelled => 'Order Cancelled';

  @override
  String get statusOrderCompleted => 'Order Completed';

  @override
  String get statusOrderPending => 'Order Pending';

  @override
  String get statusOrderPreparing => 'Order Preparing';

  @override
  String get statusOrderReady => 'Order Ready';

  @override
  String get statusPaid => 'Paid';

  @override
  String get statusPartial => 'Partial';

  @override
  String get statusPickedUp => 'Picked up';

  @override
  String get statusPlaced => 'Placed';

  @override
  String get statusReadyToServe => 'Ready to serve';

  @override
  String get statusRefunded => 'Refunded';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get statusReturned => 'Returned';

  @override
  String get statusServed => 'Served';

  @override
  String get statusSettled => 'Settled';

  @override
  String get statusUnpaid => 'Unpaid';

  @override
  String get storeAdminAccessRequired => 'Store Admin access required.';

  @override
  String get storeListBackToUnlock => 'Back to staff unlock';

  @override
  String get storeListChooseBranchUnlock =>
      'Choose a branch, then unlock with staff ID';

  @override
  String get storeListChooseStore => 'Choose your store to continue';

  @override
  String get storeListEmpty => 'No stores found';

  @override
  String get storeListLoading => 'Loading stores...';

  @override
  String get storeListOpenBranch => 'Open branch';

  @override
  String get storeListSearchHint => 'Search by store name or ID...';

  @override
  String get storeListSelectStore => 'Select Store';

  @override
  String storeListStoreId(String storeId) {
    return 'Store ID: $storeId';
  }

  @override
  String get storeListTitle => 'My stores';

  @override
  String storeListTitleCount(int count) {
    return 'My stores ($count)';
  }

  @override
  String storeSelectedSuccess(String storeName) {
    return '$storeName selected successfully!';
  }

  @override
  String storeSyncTitle(String storeName) {
    return 'Setting up $storeName';
  }

  @override
  String get storeSyncBody =>
      'Downloading catalogue, customers and orders to this device. Keep the app open.';

  @override
  String get storeSyncPreparing => 'Preparing…';

  @override
  String get storeSetupAccess => 'Access';

  @override
  String get storeSetupAddCashier => 'Add cashier';

  @override
  String get storeSetupAddCashierHint =>
      'Add a cashier with name, email, phone and password.';

  @override
  String get storeSetupAddGroup => 'Add group';

  @override
  String get storeSetupAddLinkCategoryFirst => 'Add and link a category first';

  @override
  String get storeSetupAddOffer => 'Add offer';

  @override
  String get storeSetupAddSellableItem => 'Add sellable item';

  @override
  String get storeSetupAddToStore => 'Add to store';

  @override
  String get storeSetupAddonDeletedOffline =>
      'Add-on deleted offline. Sync to export.';

  @override
  String get storeSetupAddonGroup => 'Add-on group';

  @override
  String get storeSetupAddons => 'Add-ons';

  @override
  String get storeSetupCashier => 'Cashier';

  @override
  String get storeSetupCashierCreated =>
      'Cashier created. They can unlock this store after logout.';

  @override
  String storeSetupCatalogueExportFailed(String message) {
    return 'Catalogue export failed: $message';
  }

  @override
  String get storeSetupCategories => 'Categories';

  @override
  String get storeSetupCategory => 'Category';

  @override
  String get storeSetupCategoryAddedOffline =>
      'Category added to master and this store (offline). Sync to export.';

  @override
  String get storeSetupCategoryDeletedOffline =>
      'Category deleted offline. Sync to export.';

  @override
  String get storeSetupCategoryName => 'Category name';

  @override
  String get storeSetupChooseCategory => 'Choose category';

  @override
  String get storeSetupChoosePackage => 'Choose a package';

  @override
  String get storeSetupCreate => 'Create';

  @override
  String get storeSetupCreateCashier => 'Create cashier';

  @override
  String get storeSetupDeleteAddonGroup => 'Delete add-on group?';

  @override
  String get storeSetupDeleteOffer => 'Delete offer?';

  @override
  String get storeSetupDeletePackage => 'Delete package?';

  @override
  String get storeSetupDeletedOffline => 'Deleted offline. Sync to export.';

  @override
  String get storeSetupDeletedTombstone =>
      'Deleted offline. Sync to export tombstone.';

  @override
  String get storeSetupPackageMarkedActive =>
      'Package is active and available for billing. Sync to update the admin panel.';

  @override
  String get storeSetupPackageMarkedInactive =>
      'Package is inactive and hidden from billing. Sync to update the admin panel.';

  @override
  String get storeSetupEditAddonGroup => 'Edit add-on group';

  @override
  String get storeSetupEditOffer => 'Edit offer';

  @override
  String get storeSetupEditPackage => 'Edit package';

  @override
  String get storeSetupExportNotConfigured =>
      'Catalogue export not configured — local edits stayed on this tablet.';

  @override
  String get storeSetupFirstItemName => 'First item name *';

  @override
  String get storeSetupGroupName => 'Group name *';

  @override
  String get storeSetupItemPrice => 'Item price *';

  @override
  String get storeSetupLinkCategoryFirst => 'Link a category first';

  @override
  String get storeSetupLinkPackagesHint =>
      'Leave empty for a whole-bill offer. Select packages to limit where it applies.';

  @override
  String get storeSetupLinkPackagesOptional => 'Link to packages (optional)';

  @override
  String get storeSetupLinkToPackage => 'Link to package';

  @override
  String get storeSetupLinkToPackageHint =>
      'Choose which package should offer this add-on group.';

  @override
  String storeSetupLinkedMaster(String name) {
    return 'Linked \"$name\" to this store';
  }

  @override
  String storeSetupLinkedToStore(String name) {
    return 'Linked “$name” to this store';
  }

  @override
  String get storeSetupMasterCategories => 'Master categories';

  @override
  String get storeSetupMasterLinked =>
      'Master linked with default package. Edit price, then Sync.';

  @override
  String get storeSetupMinBill => 'Min bill';

  @override
  String get storeSetupNameRequired => 'Name *';

  @override
  String get storeSetupNewCategory => 'New category';

  @override
  String get storeSetupNewMasterCategory => 'New master category';

  @override
  String get storeSetupNewOffer => 'New offer';

  @override
  String get storeSetupNewProduct => 'New product / package';

  @override
  String get storeSetupNoAddonsYet => 'No add-ons yet';

  @override
  String get storeSetupNoCashiersYet => 'No cashiers yet';

  @override
  String get storeSetupNoMasterCategories => 'No master categories';

  @override
  String get storeSetupNoOffersEmpty => 'No offers yet';

  @override
  String get storeSetupNoOffersYet =>
      'No offers yet — create some in Offers setup.';

  @override
  String get storeSetupNoPackagesCreateProducts =>
      'No packages yet — create products first.';

  @override
  String get storeSetupNoPackagesYet => 'No packages yet';

  @override
  String get storeSetupNoPackagesYetShort => 'No packages yet.';

  @override
  String get storeSetupNoTaxUnset => 'No tax / unset';

  @override
  String get storeSetupNoTaxesYet =>
      'No taxes yet — they are added automatically when the company is set up.';

  @override
  String get storeSetupNothingLinked => 'Nothing linked yet';

  @override
  String get storeSetupOfferDeletedOffline =>
      'Offer deleted offline. Sync to export.';

  @override
  String storeSetupOfferPctOff(String pct) {
    return '$pct% off';
  }

  @override
  String get storeSetupOfferSavedOffline => 'Offer saved offline';

  @override
  String get storeSetupOfferUpdatedOffline => 'Offer updated offline';

  @override
  String get storeSetupOffers => 'Offers';

  @override
  String get storeSetupOffersForPackage => 'Offers for this package';

  @override
  String get storeSetupOffersForPackageHint =>
      'Select offers that should apply to this package. Leave none for no package-specific offers.';

  @override
  String get storeSetupOptionalMinBill => 'Optional minimum bill';

  @override
  String get storeSetupPackage => 'Package';

  @override
  String get storeSetupPackageName => 'Package name *';

  @override
  String get storeSetupPackageNameHint => 'e.g. Regular, Large, Family';

  @override
  String get storeSetupPackageNamePlain => 'Package name';

  @override
  String get storeSetupPercentOff => 'Percent off';

  @override
  String get storeSetupProductName => 'Product / service name *';

  @override
  String get storeSetupProductNameHint => 'e.g. Chicken Biryani';

  @override
  String get storeSetupProductNamePlain => 'Product / service name';

  @override
  String get storeSetupProducts => 'Products';

  @override
  String get storeSetupProductsPackages => 'Products & packages';

  @override
  String get storeSetupRegular => 'Regular';

  @override
  String get storeSetupRemoveCategory => 'Remove category?';

  @override
  String storeSetupRemoveEntitySync(String name) {
    return 'Remove \"$name\". Sync to export.';
  }

  @override
  String get storeSetupRemoveFromStore => 'Remove from store';

  @override
  String get storeSetupRenameCategory => 'Rename category';

  @override
  String get storeSetupRenamedOffline => 'Renamed offline. Sync to export.';

  @override
  String get storeSetupSavedOffline => 'Saved offline. Sync to export.';

  @override
  String get storeSetupSavedOfflineMaster =>
      'Saved offline. Sync to export to master + store.';

  @override
  String get storeSetupSellPrice => 'Sell price *';

  @override
  String get storeSetupStoreAdmin => 'Store admin';

  @override
  String get storeSetupSyncExport => 'Sync / export';

  @override
  String storeSetupSyncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String storeSetupSyncFinishedExported(int count) {
    return 'Sync finished — exported $count catalogue row(s).';
  }

  @override
  String get storeSetupSyncFinishedNone =>
      'Sync finished — no pending catalogue changes to export.';

  @override
  String get storeSetupTaxForPackage => 'Tax for this package';

  @override
  String get storeSetupTaxForPackageHint =>
      'Company tax bands from setup. Leave none if this package is tax-free / unset.';

  @override
  String storeSetupTaxNamePct(String name, String pct) {
    return '$name ($pct%)';
  }

  @override
  String storeSetupTaxPct(String pct) {
    return 'Tax $pct%';
  }

  @override
  String storeSetupTaxTotalPct(String pct) {
    return '$pct% total';
  }

  @override
  String get storeSetupThisStore => 'This store';

  @override
  String get storeSetupTitle => 'Store setup';

  @override
  String get storeSetupUnit => 'Unit *';

  @override
  String get storeSetupUnitHint => 'pcs, kg…';

  @override
  String get storeSetupUnitQty => 'Unit qty *';

  @override
  String get storeSetupUpdatedOffline => 'Updated offline. Sync to export.';

  @override
  String get syncAgain => 'Sync again';

  @override
  String get syncComplete => 'Sync complete';

  @override
  String get syncDataSync => 'Data Sync';

  @override
  String get syncDescription =>
      'Uploads POS customers, orders and credits from this device first, then downloads catalogue updates. Offline sales stay local until the next successful sync.';

  @override
  String get syncDownloadFromRemote => 'Download from remote';

  @override
  String get syncHistory => 'History';

  @override
  String get syncHistory45 => 'Sync history (last 45 days)';

  @override
  String syncHistoryStats(int processed, int success, int failed) {
    return '$processed processed · $success ok · $failed failed';
  }

  @override
  String get syncInProgress => 'Sync in progress…';

  @override
  String syncLastSync(String timestamp) {
    return 'Last sync: $timestamp';
  }

  @override
  String syncNamedStoreWithRemote(String storeName) {
    return 'Sync \"$storeName\" with remote';
  }

  @override
  String get syncNeverSynced => 'Never synced';

  @override
  String get syncNoAttemptsYet =>
      'No sync attempts recorded on this device yet.';

  @override
  String get syncNoHistory =>
      'No sync attempts recorded on this device yet. Run a sync to populate history.';

  @override
  String get syncOfflineWhenOnline => 'Offline — sync when online';

  @override
  String get syncRunning => 'Running';

  @override
  String get syncServerUnreachable =>
      'Server unreachable. Keep selling offline — pending uploads stay queued on this device until you sync again online.';

  @override
  String get syncStart => 'Start sync';

  @override
  String get syncStoreWithRemote => 'Sync store data with remote';

  @override
  String get syncSyncing => 'Syncing…';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncUploadToRemote => 'Upload to remote';

  @override
  String get unsupportedDeviceDesc =>
      'EllanPos is designed specifically for tablets and large screens.\n\nPlease access the app from an iPad or Android Tablet in landscape orientation.';

  @override
  String get unsupportedDeviceTitle => 'Device Not Supported';

  @override
  String get welcomeAlreadySetupSignIn => 'Already set up? Sign in';

  @override
  String get welcomeAuthPrompt =>
      'Log in to your account or create a new one to start processing payments effortlessly.';

  @override
  String get welcomeChooseSavedServer => 'Choose a saved server';

  @override
  String get welcomeCreateCompanyInstead => 'Create a new company instead';

  @override
  String get welcomeDeleteFromList => 'Delete from list';

  @override
  String get welcomeDeleteSavedServer => 'Delete saved server';

  @override
  String get welcomeDescription =>
      'EllanPos provides an intuitive tablet experience designed perfectly for modern workflows.';

  @override
  String get welcomeEnterOrg => 'Enter your organization name';

  @override
  String get welcomeEnterOrgCode => 'Enter your organization code';

  @override
  String get welcomeGetStarted => 'Let\'s Get Started';

  @override
  String get welcomeOrgCodeHint => 'e.g., 100001';

  @override
  String get welcomeOrgHint => 'e.g. Acme Corp';

  @override
  String get welcomeOrgInstanceId => 'Organisation instance id';

  @override
  String get welcomeRegisterDevice => 'Register device';

  @override
  String get welcomeRegisterHint => 'Register this tablet to continue.';

  @override
  String get welcomeRegisterHintManual =>
      'Enter the backend server URL and organisation instance id before registering this device.';

  @override
  String welcomeRemoveServerConfirm(String label) {
    return 'Remove \"$label\" from this device?';
  }

  @override
  String get welcomeSavedServers => 'Saved servers';

  @override
  String get welcomeServerUrl => 'Server URL';

  @override
  String get welcomeServerUrlHint => 'e.g. http://192.168.1.10:8000';

  @override
  String get welcomeSubmit => 'Submit';

  @override
  String get welcomeUnlockBusiness => 'Unlock Your\nBusiness Potential';

  @override
  String get signInSwitchCompany => 'Switch company';

  @override
  String get signInSwitchCompanyTitle => 'Switch company?';

  @override
  String get signInSwitchCompanyBody =>
      'Switching company resets this device. Local orders, catalogue, customers, sync history and device settings will be permanently deleted, including any orders not yet synced. Nothing is deleted on the server.';

  @override
  String get signInSwitchCompanyAction => 'Switch & reset';

  @override
  String get supportTitle => 'Customer support';

  @override
  String get supportSubtitle => 'We\'re here to help with your POS.';

  @override
  String get supportEmail => 'Email';

  @override
  String get supportWhatsapp => 'WhatsApp';

  @override
  String get supportDeviceId => 'Device ID';

  @override
  String get supportCompany => 'Company';

  @override
  String get supportShareHint =>
      'Share these details when you contact support.';

  @override
  String get supportNotConfigured =>
      'Support contact details are not set up yet. Please ask your administrator.';

  @override
  String supportCopied(String value) {
    return 'Copied $value';
  }

  @override
  String get supportEmailAction => 'Email';

  @override
  String get supportWhatsappAction => 'Chat';

  @override
  String get homeLock => 'Lock screen';

  @override
  String get actionLock => 'Lock';

  @override
  String get lockEnterPin => 'Enter your PIN to unlock';

  @override
  String lockEnterPinAt(String storeName) {
    return 'Enter your PIN to unlock $storeName';
  }

  @override
  String get lockSignedOutTitle => 'Signed out';

  @override
  String get lockSignedOutBody =>
      'Sign in online to start using this register.';

  @override
  String get lockSignIn => 'Sign in';

  @override
  String get lockSignInInstead => 'Sign in (new staff or forgot PIN)';

  @override
  String lockWrongPin(int remaining) {
    return 'Wrong PIN. $remaining attempts left.';
  }

  @override
  String get lockTooManyAttempts => 'Too many wrong PINs. Please sign in.';

  @override
  String get lockLeaseExpired => 'Device login expired. Please sign in online.';

  @override
  String get pinCreateTitle => 'Create your PIN';

  @override
  String get pinConfirmTitle => 'Confirm your PIN';

  @override
  String pinCreateBody(int length) {
    return 'Choose a $length-digit PIN to unlock this register quickly.';
  }

  @override
  String get pinMismatch => 'PINs don\'t match. Try again.';

  @override
  String get lockChooseStaff => 'Who\'s using the register?';

  @override
  String lockNoStoreAccess(String name) {
    return '$name can\'t use this store. Please sign in.';
  }

  @override
  String get storeTradeTitle => 'Buy & Sell';

  @override
  String get storeTradeBody =>
      'Choose what this store does. You can select both. Saved on this device right away.';

  @override
  String get storeTradeSell => 'SELL';

  @override
  String get storeTradeSellHint => 'Sales to customers';

  @override
  String get storeTradeBuy => 'BUY';

  @override
  String get storeTradeBuyHint => 'Purchases from suppliers';

  @override
  String get storeTradeNeedOne => 'Keep at least one of Buy or Sell selected.';

  @override
  String get orderListAllTables => 'All tables';

  @override
  String orderListTableChip(String name) {
    return 'Table $name';
  }

  @override
  String get orderListNoTables =>
      'No tables yet. Tables appear here once dine-in orders use them.';

  @override
  String get orderListPeriodAll => 'All time';

  @override
  String get orderListPeriodToday => 'Today';

  @override
  String get orderListPeriodLast24h => 'Last 24 hrs';

  @override
  String get orderListPeriodYesterday => 'Yesterday';

  @override
  String get orderListPeriodCustom => 'Custom…';

  @override
  String get orderListPeriodTooltip => 'Filter by date';

  @override
  String get dashboardPending => 'Pending';

  @override
  String dashboardPendingOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders',
      one: '1 order',
    );
    return '$_temp0';
  }
}
