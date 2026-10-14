// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get actionAdd => 'சேர்';

  @override
  String get actionBack => 'பின்செல்';

  @override
  String get actionCancel => 'ரத்துசெய்';

  @override
  String get actionChange => 'மாற்று';

  @override
  String get actionClose => 'மூடு';

  @override
  String get actionConfirm => 'உறுதிப்படுத்து';

  @override
  String get actionContinue => 'தொடரவும்';

  @override
  String get actionDelete => 'நீக்கு';

  @override
  String get actionEdit => 'திருத்து';

  @override
  String get actionKeep => 'வைத்திரு';

  @override
  String get actionLogout => 'வெளியேறு';

  @override
  String get actionPrint => 'அச்சிடு';

  @override
  String get actionRefresh => 'புதுப்பி';

  @override
  String get actionRemove => 'அகற்று';

  @override
  String get actionRetry => 'மீண்டும் முயற்சி';

  @override
  String get actionSave => 'சேமி';

  @override
  String get actionSaveChanges => 'மாற்றங்களைச் சேமி';

  @override
  String get actionSearch => 'தேடு';

  @override
  String get actionSignIn => 'உள்நுழைக';

  @override
  String get actionSignUp => 'பதிவு செய்';

  @override
  String get actionSubmit => 'சமர்ப்பி';

  @override
  String get actionSync => 'ஒத்திசை';

  @override
  String get actionUpdate => 'புதுப்பி';

  @override
  String get actionViewAll => 'அனைத்தையும் காண்க';

  @override
  String get amountGreaterThanZero => 'பூஜ்ஜியத்திற்கு மேல் தொகையை உள்ளிடவும்.';

  @override
  String get appName => 'EllanPos';

  @override
  String get authBackToGetStarted => 'தொடக்கத்திற்குத் திரும்பு';

  @override
  String get authEntryBrand => 'EllanPos';

  @override
  String get authEntryChooseContinue =>
      'இந்த டேப்லெட்டில் எவ்வாறு தொடர விரும்புகிறீர்கள் என்பதைத் தேர்வுசெய்க.';

  @override
  String get authEntryCompanySetup => 'நிறுவன அமைப்பு';

  @override
  String get authEntryCreateCompany => 'புதிய நிறுவனம் உருவாக்கு';

  @override
  String get authEntryHero =>
      'ஏற்கனவே உள்ள நிறுவனத்தில் உள்நுழைக அல்லது இந்த சாதனத்தில் புதிய நிறுவனத்தை அமைக்கவும்.';

  @override
  String get authEntryJoinExisting => 'ஏற்கனவே உள்ள நிறுவன சாதனத்தில் சேரவும்';

  @override
  String authEntryRootOrgLabel(String orgId) {
    return 'முதன்மை நிறுவனம்  ·  $orgId';
  }

  @override
  String authEntryServerLabel(String server) {
    return 'சர்வர்  ·  $server';
  }

  @override
  String get authEntrySignInExisting => 'ஏற்கனவே நிறுவனம் உள்ளதா? உள்நுழைக';

  @override
  String get authEntryTitle => 'தொடங்குங்கள்';

  @override
  String get billingAddDiscount => 'தள்ளுபடி சேர்';

  @override
  String get billingAddDiscountCaps => 'தள்ளுபடி சேர்';

  @override
  String get billingAddOnePaymentFirst =>
      'முதலில் குறைந்தது ஒரு பணம் சேர்க்கவும்.';

  @override
  String get billingAddPayment => 'தொகை சேர்';

  @override
  String get billingAddPaymentTitle => 'பணம் சேர்';

  @override
  String get billingAddTips => 'டிப்ஸ் சேர்';

  @override
  String billingAmountExceedsRemaining(String amount) {
    return 'தொகை மீதமுள்ளதை ($amount) மீறக்கூடாது.';
  }

  @override
  String get billingAppliedDiscounts => 'பயன்படுத்தப்பட்ட தள்ளுபடிகள்';

  @override
  String get billingApply => 'பயன்படுத்து';

  @override
  String get billingApplyServiceTax => 'சேவை வரியைப் பயன்படுத்து';

  @override
  String get billingApplyTo => 'பயன்படுத்து';

  @override
  String get billingAttachCustomer =>
      'இந்த பில்லுடன் வாடிக்கையாளரை இணைக்கவும் (கடனுக்கு அவசியம்).';

  @override
  String get billingCheckoutComplete => 'செக்அவுட் முடிந்தது';

  @override
  String get billingComplete => 'முடி';

  @override
  String get billingCompleteWithoutPayment => 'பணம் இல்லாமல் முடி';

  @override
  String get billingCompletingCheckout => 'செக்அவுட் முடிக்கிறது…';

  @override
  String get billingCoverFullOrCredit =>
      'முழுத் தொகையையும் செலுத்தவும் அல்லது நிலுவையை வாடிக்கையாளர் கடனில் வைக்கவும்.';

  @override
  String get billingCreditCancelled =>
      'கடன் ரத்து. செக்அவுட் முடிக்கப்படவில்லை.';

  @override
  String billingCreditLimitContinue(String message) {
    return '$message\n\nஎப்படியும் தொடரவா?';
  }

  @override
  String billingCreditLimitExceeded(
    String limit,
    String outstanding,
    String amountDue,
  ) {
    return 'கடன் வரம்பு $limit மீறப்படும் (நிலுவை $outstanding + இந்த விற்பனை $amountDue).';
  }

  @override
  String get billingCreditLimitWarningTitle => 'கடன் வரம்பு எச்சரிக்கை';

  @override
  String get billingCreditNeedsCustomer =>
      'கடன் பணத்திற்கு வாடிக்கையாளர் தேவை. வாடிக்கையாளரைத் தேர்ந்தெடுத்து மீண்டும் முயற்சிக்கவும்.';

  @override
  String get billingCreditPlaceFailed =>
      'மீத நிலுவையை கடனில் வைக்க முடியவில்லை. செக்அவுட் ரத்து செய்யப்பட்டது.';

  @override
  String get billingCustomerForCredit => 'கடனுக்கான வாடிக்கையாளர்';

  @override
  String get billingCustomerOptionalCredit =>
      'விரும்பினால் — கடனில் செலுத்தும்போது அவசியம்';

  @override
  String billingDiscountAdded(String title) {
    return '\"$title\" சேர்க்கப்பட்டது';
  }

  @override
  String billingDiscountsCount(int count) {
    return 'தள்ளுபடிகள் ($count)';
  }

  @override
  String billingDraftSaved(int orderId) {
    return 'வரைவு ஆர்டர் #$orderId சேமிக்கப்பட்டது.';
  }

  @override
  String get billingEntireOrder => 'முழு ஆர்டர்';

  @override
  String get billingInvalidDiscountPct =>
      '1 முதல் 100 வரை தள்ளுபடி சதவீதத்தை உள்ளிடவும்';

  @override
  String get billingNoItems => 'பில் செய்ய பொருட்கள் இல்லை.';

  @override
  String get billingNoPaymentMethods =>
      'பணம் செலுத்தும் முறைகள் அமைக்கப்படவில்லை.';

  @override
  String billingOrderCreditBalance(int orderId) {
    return 'ஆர்டர் #$orderId — நிலுவை வாடிக்கையாளர் கடனில் சேர்க்கப்பட்டது';
  }

  @override
  String get billingOrderFullyCovered =>
      'ஆர்டர் ஏற்கனவே முழுமையாக மூடப்பட்டுள்ளது.';

  @override
  String billingOrderPaidVia(int orderId, String mode) {
    return 'ஆர்டர் #$orderId $mode மூலம் செலுத்தப்பட்டது';
  }

  @override
  String billingOrderPlacedBalance(int orderId, String amount) {
    return 'ஆர்டர் #$orderId நிலுவை $amount உடன் வைக்கப்பட்டது';
  }

  @override
  String billingPaid(String amount) {
    return 'செலுத்தப்பட்டது  $amount';
  }

  @override
  String billingPaymentSale(String paymentLabel) {
    return '$paymentLabel விற்பனை';
  }

  @override
  String get billingPercentageHint => '1-100';

  @override
  String get billingPlaceFullCredit => 'முழுத் தொகையையும் கடனில் வை';

  @override
  String get billingPlaceFullOnCredit => 'முழுத் தொகையையும் கடனில் வை';

  @override
  String get billingPlaceWithBalance => 'நிலுவையுடன் வை';

  @override
  String billingRemainingAddPayment(String amount) {
    return 'நிலுவை $amount. மற்றொரு பணம் சேர்க்கவும் அல்லது நிலுவையுடன் வைக்கவும்.';
  }

  @override
  String billingRemainingOnCredit(String amount) {
    return 'கடனில் மீதம்: $amount';
  }

  @override
  String get billingRemoveAllDiscounts => 'அனைத்து தள்ளுபடிகளையும் நீக்கு';

  @override
  String get billingRemoveExistingTax => 'உள்ள வரியை நீக்கு';

  @override
  String get billingRemoveTips => 'டிப்ஸை நீக்கு';

  @override
  String get billingSaveAsDraft => 'வரைவாகச் சேமி';

  @override
  String billingSelectCustomerCredit(String amount) {
    return 'அவர்களின் கடன் கணக்கில் $amount வைக்க வாடிக்கையாளரைத் தேர்ந்தெடுக்கவும் அல்லது சேர்க்கவும்.';
  }

  @override
  String get billingServiceTaxApplied => 'சேவை வரி பயன்படுத்தப்பட்டது';

  @override
  String get billingServiceTaxLabel => 'சேவை வரி';

  @override
  String billingTaxPct(String percent) {
    return 'வரி $percent%';
  }

  @override
  String get billingTaxPlaceholder => 'வரி சதவீதத்தை உள்ளிடவும் (1-100)';

  @override
  String billingTipsAmount(String amount) {
    return 'டிப்ஸ் $amount';
  }

  @override
  String get billingTipsApplied => 'டிப்ஸ் பயன்படுத்தப்பட்டது';

  @override
  String get billingTipsPlaceholder => 'டிப்ஸ் தொகையை உள்ளிடவும்';

  @override
  String get billingTitle => 'பில்லிங் & பணம்';

  @override
  String billingToPay(String amount) {
    return 'செலுத்த வேண்டியது  $amount';
  }

  @override
  String get catalogAllPackages => 'அனைத்து பேக்கேஜ்கள்';

  @override
  String get catalogAppliesTo => 'பொருந்தும்';

  @override
  String get catalogBarcode => 'பார்கோடு';

  @override
  String get catalogBillOffer => 'பில் சலுகை';

  @override
  String get catalogEmpty => 'பட்டியலில் பொருட்கள் இல்லை';

  @override
  String catalogMrpPrice(String amount) {
    return 'MRP $amount';
  }

  @override
  String get catalogNoActiveOffers =>
      'இந்த கடைக்கு செயலில் உள்ள சலுகைகள் ஒத்திசைக்கப்படவில்லை';

  @override
  String get catalogNoAddonGroups =>
      'இந்தத் தொகுப்புடன் துணைப்பொருள் குழுக்கள் இணைக்கப்படவில்லை';

  @override
  String get catalogNoCatalogueDevice =>
      'இந்த சாதனத்தில் இன்னும் பட்டியல் இல்லை. ஒத்திசைவைத் திறந்து பொருட்கள், துணைகள் மற்றும் சலுகைகளை இழுக்கவும்.';

  @override
  String get catalogNoItemsInGroup => 'இந்த குழுவில் உருப்படிகள் இல்லை';

  @override
  String get catalogNoOffersTargetPackage =>
      'இந்த பேக்கேஜை இலக்காகக் கொண்ட சலுகைகள் இல்லை';

  @override
  String get catalogNoPackagesView => 'இந்த காட்சியில் பேக்கேஜ்கள் இல்லை';

  @override
  String catalogOffersCount(int count) {
    return 'சலுகைகள் ($count)';
  }

  @override
  String catalogPackagesCount(int count) {
    return 'பேக்கேஜ்கள் ($count)';
  }

  @override
  String catalogProductPrefix(String name) {
    return 'பொருள் · $name';
  }

  @override
  String get catalogRefreshLocal => 'உள்ளூர் DB இலிருந்து புதுப்பி';

  @override
  String get catalogRefreshTooltip => 'உள்ளூர் DB இலிருந்து புதுப்பி';

  @override
  String get catalogSearchExtended => 'பொருள், பேக்கேஜ், பார்கோடு… தேடு';

  @override
  String get catalogSearchHint => 'பொருட்களைத் தேடு';

  @override
  String get catalogSell => 'விற்பனை';

  @override
  String get catalogTitle => 'பட்டியல்';

  @override
  String get catalogUnit => 'அலகு';

  @override
  String get commonActions => 'செயல்கள்';

  @override
  String get commonActive => 'செயலில்';

  @override
  String get commonAddons => 'கூடுதல் பொருட்கள்';

  @override
  String get commonAddress => 'முகவரி';

  @override
  String get commonAmount => 'தொகை';

  @override
  String get commonAmountToPay => 'செலுத்த வேண்டிய தொகை';

  @override
  String get commonBackToSelling => 'விற்பனைக்குத் திரும்பு';

  @override
  String commonBal(String amount) {
    return 'மீதி $amount';
  }

  @override
  String get commonBalanceDue => 'நிலுவை தொகை';

  @override
  String get commonBusiness => 'வணிகம்';

  @override
  String get commonCard => 'அட்டை';

  @override
  String get commonCash => 'ரொக்கம்';

  @override
  String get commonCatalogs => 'பட்டியல்கள்';

  @override
  String get commonCategories => 'பிரிவுகள்';

  @override
  String get commonChangePaymentMethod => 'கட்டண முறையை மாற்று';

  @override
  String get commonChannel => 'சேனல்';

  @override
  String get commonClear => 'அழி';

  @override
  String get commonClearCustomer => 'வாடிக்கையாளரை அழி';

  @override
  String get commonCode => 'குறியீடு';

  @override
  String get commonCollect => 'வசூல்';

  @override
  String get commonCompany => 'நிறுவனம்';

  @override
  String get commonConfirmPayment => 'கட்டணத்தை உறுதிப்படுத்து';

  @override
  String get commonConfirmPaymentCaps => 'கட்டணத்தை உறுதிப்படுத்து';

  @override
  String get commonContactEmail => 'தொடர்பு மின்னஞ்சல்';

  @override
  String get commonCredit => 'கடன்';

  @override
  String get commonCreditHistory => 'கடன் வரலாறு';

  @override
  String get commonCreditOrders => 'கடன் ஆர்டர்கள்';

  @override
  String get commonCredits => 'கடன்கள்';

  @override
  String get commonCurrent => 'தற்போதைய';

  @override
  String get commonCustomer => 'வாடிக்கையாளர்';

  @override
  String get commonCustomers => 'வாடிக்கையாளர்கள்';

  @override
  String get commonDate => 'தேதி';

  @override
  String get commonDelivery => 'டெலிவரி';

  @override
  String get commonDeliveryCharge => 'டெலிவரி கட்டணம்';

  @override
  String get commonDetails => 'விவரங்கள்';

  @override
  String get commonDevice => 'சாதனம்';

  @override
  String get commonDeviceId => 'சாதன அடையாளம்';

  @override
  String get commonDiscount => 'தள்ளுபடி';

  @override
  String commonDiscountPct(String title, String percent) {
    return '$title ($percent%)';
  }

  @override
  String get commonDismiss => 'நிராகரி';

  @override
  String get commonDone => 'முடிந்தது';

  @override
  String get commonDueDate => 'செலுத்த வேண்டிய தேதி';

  @override
  String get commonDueDateOptional => 'செலுத்த வேண்டிய தேதி (விரும்பினால்)';

  @override
  String commonDueValue(String date) {
    return 'செலுத்த வேண்டியது $date';
  }

  @override
  String get commonEmail => 'மின்னஞ்சல்';

  @override
  String get commonEmpty => '—';

  @override
  String get commonEnterQuantityGtZero =>
      'பூஜ்ஜியத்தை விட அதிக அளவை உள்ளிடவும்.';

  @override
  String get commonExact => 'சரியானது';

  @override
  String get commonExporting => 'பட்டியல் ஏற்றுமதி…';

  @override
  String get commonFailed => 'தோல்வி';

  @override
  String get commonFrequency => 'அதிர்வெண்';

  @override
  String get commonGuest => 'விருந்தினர்';

  @override
  String get commonHardware => 'வன்பொருள்';

  @override
  String get commonHideDetails => 'விவரங்களை மறை';

  @override
  String get commonIdentifier => 'அடையாளம்';

  @override
  String get commonInactive => 'செயலற்றது';

  @override
  String get commonInfo => 'தகவல்';

  @override
  String get commonItem => 'பொருள்';

  @override
  String get commonItems => 'பொருட்கள்';

  @override
  String commonKot(String qty) {
    return 'KOT $qty';
  }

  @override
  String get commonLedger => 'பதிவேடு';

  @override
  String get commonLimit => 'வரம்பு';

  @override
  String commonLineTotal(String amount) {
    return 'வரி மொத்தம்: $amount';
  }

  @override
  String get commonLoading => 'ஏற்றுகிறது…';

  @override
  String get commonMiscItem => 'இதர பொருள்';

  @override
  String get commonMonthly => 'மாதாந்திரம்';

  @override
  String get commonName => 'பெயர்';

  @override
  String commonNetDays(int days) {
    return 'நிகர $days';
  }

  @override
  String get commonNetTotal => 'நிகர மொத்தம்';

  @override
  String get commonNever => 'எப்போதும் இல்லை';

  @override
  String get commonNewOrder => 'புதிய ஆர்டர்';

  @override
  String get commonNext => 'அடுத்து';

  @override
  String get commonNo => 'இல்லை';

  @override
  String get commonNoData => 'தரவு இல்லை';

  @override
  String get commonNoPaymentsYet => 'இன்னும் கட்டணங்கள் இல்லை';

  @override
  String get commonNoSalesPeriod => 'இந்தக் காலத்தில் விற்பனை இல்லை';

  @override
  String get commonNone => 'இல்லை';

  @override
  String get commonNotSet => 'அமைக்கப்படவில்லை';

  @override
  String get commonNotes => 'குறிப்புகள்';

  @override
  String commonOfAmount(String amount) {
    return '$amount இல்';
  }

  @override
  String get commonOfferApplied => 'சலுகை பயன்படுத்தப்பட்டது';

  @override
  String commonOfferLabel(String labels) {
    return 'சலுகை · $labels';
  }

  @override
  String get commonOffers => 'சலுகைகள்';

  @override
  String get commonOk => 'சரி';

  @override
  String get commonOnline => 'ஆன்லைன்';

  @override
  String get commonOpen => 'திறந்தது';

  @override
  String get commonOpenCreditAccount => 'கடன் கணக்கைத் திற';

  @override
  String get commonOptional => 'விருப்பமானது';

  @override
  String get commonOrderCount => 'ஆர்டர் எண்ணிக்கை';

  @override
  String get commonOrderHistory => 'ஆர்டர் வரலாறு';

  @override
  String get commonOrderLabel => 'ஆர்டர்';

  @override
  String get commonOrderTotal => 'ஆர்டர் மொத்தம்';

  @override
  String get commonOrders => 'ஆர்டர்கள்';

  @override
  String get commonOrganisation => 'நிறுவனம்';

  @override
  String get commonOrganisationRole => 'நிறுவனப் பங்கு';

  @override
  String get commonOrganisationTime => 'நிறுவன நேரம்';

  @override
  String get commonOutstanding => 'நிலுவை';

  @override
  String get commonOverdue => 'காலாவதி';

  @override
  String get commonOverdueSuffix => ' · தாமதம்';

  @override
  String get commonOwner => 'உரிமையாளர்';

  @override
  String get commonPassword => 'கடவுச்சொல்';

  @override
  String get commonPay => 'செலுத்து';

  @override
  String commonPayVia(String method) {
    return '$method மூலம் செலுத்து';
  }

  @override
  String get commonPaymentMode => 'கட்டண முறை';

  @override
  String commonPaymentNumber(String id) {
    return 'தொகை #$id';
  }

  @override
  String get commonPaymentTypes => 'கட்டண வகைகள்';

  @override
  String get commonPayments => 'கட்டணங்கள்';

  @override
  String get commonPending => 'நிலுவையில்';

  @override
  String get commonPercentage => 'சதவீதம்';

  @override
  String get commonPhone => 'தொலைபேசி';

  @override
  String get commonPlan => 'திட்டம்';

  @override
  String commonPosCode(String code) {
    return 'POS $code';
  }

  @override
  String get commonPosCodeLabel => 'POS குறியீடு';

  @override
  String get commonPreparing => 'தயாராகிறது';

  @override
  String get commonPrevious => 'முந்தைய';

  @override
  String get commonPrice => 'விலை';

  @override
  String get commonProducts => 'பொருட்கள்';

  @override
  String get commonQty => 'அளவு';

  @override
  String get commonQuantity => 'அளவு';

  @override
  String get commonReferenceOptional => 'குறிப்பு (விரும்பினால்)';

  @override
  String get commonRefunds => 'பணத்திரும்பல்';

  @override
  String get commonRegNo => 'பதிவு எண்';

  @override
  String commonRegValue(String reg) {
    return 'பதிவு $reg';
  }

  @override
  String get commonRemaining => 'மீதம்';

  @override
  String get commonReports => 'அறிக்கைகள்';

  @override
  String get commonRequired => 'அவசியம்';

  @override
  String get commonRetail => 'சில்லறை';

  @override
  String get commonSaveOffline => 'ஆஃப்லைனில் சேமி';

  @override
  String get commonSaving => 'சேமிக்கிறது…';

  @override
  String get commonSchedule => 'அட்டவணை';

  @override
  String get commonSelect => 'தேர்வு';

  @override
  String get commonSelectCustomer => 'வாடிக்கையாளரைத் தேர்ந்தெடு';

  @override
  String commonServeNumber(String number) {
    return 'சேவை #$number';
  }

  @override
  String get commonServiceInstance => 'சேவை நிகழ்வு';

  @override
  String commonServiceInstanceShort(String id) {
    return 'SI $id';
  }

  @override
  String get commonServiceTax => 'சேவை வரி';

  @override
  String commonServiceTaxPct(String percent) {
    return 'சேவை வரி ($percent%)';
  }

  @override
  String get commonSettleFullBalance => 'முழு நிலுவையைத் தீர்த்து வை';

  @override
  String get commonSettled => 'முடிக்கப்பட்டது';

  @override
  String get commonSkipped => 'தவிர்க்கப்பட்டது';

  @override
  String get commonStaff => 'பணியாளர்';

  @override
  String get commonStatus => 'நிலை';

  @override
  String get commonStore => 'கிளை';

  @override
  String get commonStoreId => 'கடை ID';

  @override
  String get commonStoreRole => 'கடைப் பங்கு';

  @override
  String get commonSubtotal => 'உபமொத்தம்';

  @override
  String get commonSuccess => 'வெற்றி';

  @override
  String get commonSummary => 'சுருக்கம்';

  @override
  String get commonSynced => 'ஒத்திசைக்கப்பட்டது';

  @override
  String get commonTable => 'மேசை';

  @override
  String get commonTax => 'வரி';

  @override
  String get commonTips => 'டிப்ஸ்';

  @override
  String get commonTitleLabel => 'தலைப்பு';

  @override
  String get commonTotal => 'மொத்தம்';

  @override
  String get commonTotalAmount => 'மொத்தத் தொகை';

  @override
  String get commonType => 'வகை';

  @override
  String get commonUnknown => 'தெரியாதது';

  @override
  String get commonUnnamedCustomer => 'பெயரில்லா வாடிக்கையாளர்';

  @override
  String get commonUpi => 'UPI';

  @override
  String get commonUseCustomer => 'வாடிக்கையாளரைப் பயன்படுத்து';

  @override
  String get commonView => 'காண்க';

  @override
  String commonViewAllCount(int count) {
    return 'அனைத்தையும் காண ($count)';
  }

  @override
  String get commonVoid => 'ரத்து';

  @override
  String get commonVoucher => 'வவுச்சர்';

  @override
  String get commonWalkIn => 'நேரடி வாடிக்கையாளர்';

  @override
  String get commonWeekly => 'வாராந்திரம்';

  @override
  String get commonYes => 'ஆம்';

  @override
  String get companyAddSubscriber => 'சந்தாதாரரைச் சேர்';

  @override
  String get companyAddToBranch => 'கிளையில் சேர்';

  @override
  String get companyAddress => 'முகவரி';

  @override
  String get companyAllPaymentMethodsAdded =>
      'அனைத்து கட்டண முறைகளும் ஏற்கனவே இந்தக் கிளையில் உள்ளன.';

  @override
  String get companyBranch => 'கிளை';

  @override
  String get companyBranchLogo => 'கிளை லோகோ';

  @override
  String get companyBranchStoreName => 'கிளை / கடை பெயர்';

  @override
  String get companyChannel => 'சேனல்';

  @override
  String get companyChannelPush => 'Push';

  @override
  String get companyChannelSlack => 'Slack';

  @override
  String get companyChannelSms => 'SMS';

  @override
  String get companyChannelWhatsApp => 'WhatsApp';

  @override
  String get companyChooseLogo => 'நிறுவன லோகோவைத் தேர்ந்தெடு';

  @override
  String get companyContact => 'தொடர்பு';

  @override
  String get companyCouldNotAddSubscriber =>
      'சந்தாதாரரைச் சேர்க்க முடியவில்லை.';

  @override
  String get companyCouldNotLoadReports => 'அறிக்கைகளை ஏற்ற முடியவில்லை.';

  @override
  String get companyHubTitle => 'நிறுவனம்';

  @override
  String get companyIdentifier => 'அடையாளம்';

  @override
  String get companyInvoiceBookings => 'விலைப்பட்டி / முன்பதிவுகள்';

  @override
  String companyLabelLocked(String label) {
    return '$label · பூட்டப்பட்டது';
  }

  @override
  String get companyLegal => 'சட்டம்';

  @override
  String get companyLogo => 'லோகோ';

  @override
  String get companyLogoFilePath => 'லோகோ கோப்பு பாதை';

  @override
  String get companyLogoSavedOnDevice =>
      'இந்த சாதனத்தில் சேமிக்கப்பட்டது · சேமிக்கும்போது ஒத்திசைக்கும்';

  @override
  String get companyMailerFixedHint =>
      'அறிக்கை மற்றும் விலைப்பட்டி/முன்பதிவு மெயிலர்கள் Ellan POS மூலம் நிர்ணயிக்கப்பட்டவை. டேப்லெட்டில் சான்றுகளை மாற்றவோ சேர்க்கவோ முடியாது.';

  @override
  String get companyMethod => 'முறை';

  @override
  String get companyNoPaymentMethodsBranch =>
      'இந்த கிளையில் இன்னும் கட்டண முறைகள் இல்லை. கிளையில் சேர் ஐப் பயன்படுத்தவும்.';

  @override
  String get companyNoPaymentVariants =>
      'சர்வரிலிருந்து கட்டண முறை மாறுபாடுகள் கிடைக்கவில்லை.';

  @override
  String get companyNoSubscribers => 'இன்னும் சந்தாதாரர்கள் இல்லை.';

  @override
  String get companyNoSubscribersYet => 'இன்னும் சந்தாதாரர்கள் இல்லை.';

  @override
  String get companyOpenStore => 'கிளையைத் திற';

  @override
  String get companyOwner => 'உரிமையாளர்';

  @override
  String get companyOwnerSubscriberLocked =>
      'உரிமையாளர் சந்தாதாரரை நீக்க முடியாது.';

  @override
  String get companyPaymentMethod => 'கட்டண முறை';

  @override
  String companyPaymentMethodAdded(String label) {
    return '$label இந்தக் கிளையில் சேர்க்கப்பட்டது.';
  }

  @override
  String get companyPeriodAnnually => 'ஆண்டுதோறும்';

  @override
  String get companyPeriodDaily => 'தினசரி';

  @override
  String get companyPeriodicity => 'அதிர்வெண்';

  @override
  String get companyRegistrationNumber => 'பதிவு எண்';

  @override
  String get companyReportsHint =>
      'விற்பனை அறிக்கை சந்தாதாரர்கள் மற்றும் அட்டவணை';

  @override
  String get companyReportsTitle => 'அறிக்கைகள்';

  @override
  String get companySalesReports => 'விற்பனை அறிக்கைகள்';

  @override
  String get companySalesReportsHint =>
      'தினசரி விற்பனை சுருக்கங்கள் சistema அறிக்கை மெயிலர் மூலம் இயக்கப்பட்ட ஒவ்வொரு சந்தாதாரருக்கும் மின்னஞ்சல் அனுப்பப்படும்.';

  @override
  String get companySalesReportsTitle => 'விற்பனை அறிக்கைகள்';

  @override
  String get companySaveChanges => 'மாற்றங்களைச் சேமி';

  @override
  String get companySavedOnDevice =>
      'இந்தச் சாதனத்தில் சேமிக்கப்பட்டது · Save உடன் ஒத்திசைக்கும்';

  @override
  String get companySettingsNameRegAddress =>
      'பெயர், பதிவு, முகவரி, வரி, தொலைபேசி, மின்னஞ்சல், அடையாளம்';

  @override
  String get companySettingsSaved => 'நிறுவன அமைப்புகள் சேமிக்கப்பட்டன.';

  @override
  String get companySettingsTitle => 'நிறுவன அமைப்புகள்';

  @override
  String get companyStaffsListHint =>
      'ஊழியர்களைப் பட்டியலிட்டு இந்தக் கிளைக்கு புதிய கணக்குகளைச் சேர்க்கவும்';

  @override
  String get companyStaffsTitle => 'பணியாளர்கள்';

  @override
  String get companyStoreSetupHint => 'பட்டியல், சலுகைகள், துணைப்பொருட்கள்';

  @override
  String get companySubscribers => 'சந்தாதாரர்கள்';

  @override
  String get companySystemEmailLocked => 'கணினி மின்னஞ்சல் (பூட்டப்பட்டது)';

  @override
  String get companySystemMailerLocked => 'கணினி மெயிலர் (பூட்டப்பட்டது)';

  @override
  String get companyTapMethodToAdd => 'சேர்க்க ஒரு முறையைத் தட்டவும்';

  @override
  String get companyTaxRegistrationNumber => 'வரி பதிவு எண்';

  @override
  String get companyUploadLogo => 'லோகோவைப் பதிவேற்று';

  @override
  String get companyUseFile => 'கோப்பைப் பயன்படுத்து';

  @override
  String get companyWallet => 'பணப்பை';

  @override
  String creditsAccountCount(int count) {
    return '$count கணக்கு(கள்)';
  }

  @override
  String get creditsAllowedWarn => 'அனுமதி (எச்சரிக்கை)';

  @override
  String get creditsBlocked => 'தடுக்கப்பட்டது';

  @override
  String creditsCancelFailed(String error) {
    return 'ரத்து தோல்வி: $error';
  }

  @override
  String get creditsCancelScheduleAction => 'அட்டவணையை ரத்துசெய்';

  @override
  String creditsCancelScheduleBody(String amount, String dueDate) {
    return '$dueDate அன்று செலுத்த வேண்டிய $amount ஐ ரத்துசெய்யவா?';
  }

  @override
  String get creditsCancelScheduleTitle =>
      'திட்டமிட்ட திருப்பிச் செலுத்தலை ரத்துசெய்';

  @override
  String get creditsCollect => 'வசூல்';

  @override
  String get creditsCollectPayment => 'தொகை வசூலி';

  @override
  String creditsCollectedScheduled(String amount) {
    return 'அட்டவணையிடப்பட்ட $amount வசூலிக்கப்பட்டது';
  }

  @override
  String creditsCollectedVia(String amount, String mode) {
    return '$mode மூலம் $amount வசூலிக்கப்பட்டது';
  }

  @override
  String get creditsCreditAccount => 'கடன் கணக்கு';

  @override
  String get creditsCreditLimit => 'கடன் வரம்பு';

  @override
  String get creditsCreditLimitLabel => 'கடன் வரம்பு';

  @override
  String creditsCreditNumber(String id) {
    return 'கடன் #$id';
  }

  @override
  String creditsCreditOrderLine(String creditId, String orderId) {
    return 'கடன் #$creditId · ஆர்டர் #$orderId';
  }

  @override
  String creditsCreditSaleOrder(String orderId) {
    return 'கடன் விற்பனை · ஆர்டர் #$orderId';
  }

  @override
  String get creditsCreditSalePlain => 'கடன் விற்பனை';

  @override
  String get creditsCreditSales => 'கடன் விற்பனைகள்';

  @override
  String get creditsCreditSoFar => 'இதுவரை கடன்';

  @override
  String get creditsCustomerCreditLimit => 'வாடிக்கையாளர் கடன் வரம்பு';

  @override
  String get creditsCustomerLimit => 'வாடிக்கையாளர் கடன் வரம்பு';

  @override
  String creditsCustomerScopedTitle(String name) {
    return 'கடன் · $name';
  }

  @override
  String get creditsHardBlock => 'கடுமையான தடை';

  @override
  String get creditsInstallments => 'தவணைகள்';

  @override
  String get creditsLedgerVoided => 'ரத்து செய்யப்பட்டது';

  @override
  String get creditsLimit => 'வரம்பு';

  @override
  String creditsMaxAmount(String amount) {
    return 'அதிகபட்சம் $amount';
  }

  @override
  String get creditsNetTerms => 'நிகழ் விதிமுறைகள்';

  @override
  String creditsNetTermsDays(int days) {
    return '$days நாட்கள்';
  }

  @override
  String get creditsNoAccountsMatch =>
      'தற்போதைய வடிகட்டிகளுக்கு பொருந்தும் கணக்குகள் இல்லை.';

  @override
  String get creditsNoAccountsOnDevice =>
      'இந்த சாதனத்தில் இன்னும் கடன் கணக்குகள் இல்லை.';

  @override
  String get creditsNoAccountsYet =>
      'இந்தச் சாதனத்தில் இன்னும் கடன் கணக்குகள் இல்லை.';

  @override
  String get creditsNoCreditLimitHint =>
      'இந்த வாடிக்கையாளருக்கு கடன் வரம்பு இல்லை. Store/CustomerCredit/Account/<id>/ இல் credit_limit_amount (அல்லது Store/CustomerCredit/Settings/ இல் கடை இயல்புகள்) அமைத்து, பின்னர் கடன்களை ஒத்திசைக்கவும்.';

  @override
  String get creditsNoCreditPayments =>
      'இன்னும் கடன் கட்டணங்கள் பதிவு செய்யப்படவில்லை.';

  @override
  String get creditsNoCreditSales =>
      'இந்த வாடிக்கையாளருக்கு கடன் விற்பனை இல்லை.';

  @override
  String get creditsNoLedger => 'இன்னும் பதிவேட்டு செயல்பாடு இல்லை.';

  @override
  String get creditsNoOpenScheduled => 'திறந்த திட்டமிட்ட கட்டணங்கள் இல்லை.';

  @override
  String get creditsNoRepaymentsYet =>
      'இன்னும் திருப்பிச் செலுத்தல்கள் பதிவு செய்யப்படவில்லை.';

  @override
  String get creditsNoScheduledToday =>
      'இன்று செலுத்த வேண்டிய திட்டமிட்ட கட்டணங்கள் இல்லை.';

  @override
  String get creditsNoSchedules => 'இந்தக் கணக்கில் தவணை அட்டவணைகள் இல்லை.';

  @override
  String get creditsNoUpcoming => 'வரவிருக்கும் திருப்பிச் செலுத்தல்கள் இல்லை.';

  @override
  String get creditsNotSet => 'அமைக்கப்படவில்லை';

  @override
  String get creditsNothingOutstanding =>
      'இந்த வாடிக்கையாளருக்கு நிலுவை இல்லை.';

  @override
  String get creditsOneShot => 'ஒருமுறை';

  @override
  String get creditsOpenAccount => 'கடன் கணக்கைத் திற';

  @override
  String get creditsOutstanding => 'நிலுவை';

  @override
  String creditsOutstandingAmount(String amount) {
    return 'நிலுவை $amount';
  }

  @override
  String get creditsOutstandingOnly => 'நிலுவை மட்டும்';

  @override
  String get creditsOverLimit => 'வரம்பு மீறியது';

  @override
  String get creditsOverLimitLabel => 'வரம்பு மீறல்';

  @override
  String get creditsPaymentSchedules => 'கட்டண அட்டவணைகள்';

  @override
  String get creditsRepaid => 'திருப்பிச் செலுத்தப்பட்டது';

  @override
  String creditsRepaymentMode(String mode) {
    return 'திருப்பிச் செலுத்தல் · $mode';
  }

  @override
  String get creditsRepaymentVoided =>
      'திருப்பிச் செலுத்தல் ரத்துசெய்யப்பட்டது.';

  @override
  String get creditsScheduleBody =>
      'இந்த வாடிக்கையாளரின் வரவிருக்கும் கட்டண வாக்குறுதியைப் பதிவுசெய்க.';

  @override
  String get creditsSchedulePayments => 'பணம் செலுத்தல்களை திட்டமிடு';

  @override
  String get creditsScheduleRepayment => 'திருப்பிச் செலுத்தலைத் திட்டமிடு';

  @override
  String creditsScheduledFor(String amount, String dueDate) {
    return '$dueDate க்கு $amount அட்டவணையிடப்பட்டது';
  }

  @override
  String get creditsSearchHint =>
      'வாடிக்கையாளர் பெயர் அல்லது அடையாளத்தைத் தேடு';

  @override
  String get creditsSort => 'வரிசைப்படுத்து';

  @override
  String get creditsSortHighest => 'அதிகம்';

  @override
  String get creditsSortLongPending => 'நீண்ட நிலுவை';

  @override
  String get creditsStoreCreditSettings => 'கடை கடன் அமைப்புகள்';

  @override
  String get creditsStoreSettings => 'கிளை கடன் அமைப்புகள்';

  @override
  String get creditsTitle => 'கடன்கள்';

  @override
  String get creditsTodayScheduled => 'இன்றைய திட்டமிட்ட கட்டணங்கள்';

  @override
  String get creditsUpcoming => 'வரவிருக்கும் திருப்பிச் செலுத்தல்கள்';

  @override
  String creditsUsedAvailable(String used, String available) {
    return 'பயன்படுத்தப்பட்டது $used · கிடைக்கும் $available';
  }

  @override
  String get creditsView => 'காண்';

  @override
  String creditsVoidRepaymentBody(String amount, String date) {
    return '$date அன்று செலுத்தப்பட்ட $amount ஐ ரத்துசெய்யவா?';
  }

  @override
  String get creditsVoidRepaymentTitle => 'திருப்பிச் செலுத்தலை ரத்துசெய்';

  @override
  String get creditsVoidedOnPos => 'POS டேப்லெட்டில் ரத்துசெய்யப்பட்டது';

  @override
  String get creditsWarnOnly => 'எச்சரிக்கை மட்டும்';

  @override
  String get customerAdvanceAdd => 'வாடிக்கையாளர் முன்பணத்தைச் சேர்';

  @override
  String get customerAdvanceAvailable => 'கிடைக்கும் முன்பணம்';

  @override
  String customerAdvanceAvailableValue(String amount) {
    return 'கிடைக்கும் முன்பணம்: $amount';
  }

  @override
  String get customerAdvanceExplanation =>
      'பெறப்பட்ட தொகை முதலில் நிலுவைத் தொகையில் கழிக்கப்படும். மீதமுள்ள தொகை எதிர்கால விற்பனைக்கான முன்பணமாக இருக்கும்.';

  @override
  String get customerAdvanceRecord => 'முன்பணத்தைப் பதிவு செய்';

  @override
  String get customerAdvanceRecorded =>
      'வாடிக்கையாளர் முன்பணம் பதிவுசெய்யப்பட்டது.';

  @override
  String get customerBalanceDue => 'நிலுவைத் தொகை';

  @override
  String customerBalanceDueValue(String amount) {
    return 'நிலுவைத் தொகை: $amount';
  }

  @override
  String get customerCouldNotSave => 'வாடிக்கையாளரைச் சேமிக்க முடியவில்லை';

  @override
  String get customerCreditHistory => 'கடன் வரலாறு';

  @override
  String get customerEmailOptional => 'மின்னஞ்சல் (விரும்பினால்)';

  @override
  String get customerEnterValidPhone => 'சரியான 10 இலக்க தொலைபேசியை உள்ளிடவும்';

  @override
  String get customerNameOptional => 'பெயர் (விரும்பினால்)';

  @override
  String get customerNoCreditPaymentsYet =>
      'இன்னும் கடன் கட்டணங்கள் பதிவுசெய்யப்படவில்லை.';

  @override
  String get customerNoCreditSalesYet =>
      'இந்த வாடிக்கையாளருக்கு இன்னும் கடன் விற்பனை இல்லை.';

  @override
  String get customerNoOrdersYet =>
      'இந்த வாடிக்கையாளருக்கு இன்னும் ஆர்டர்கள் இல்லை.';

  @override
  String get customerOrderHistory => 'ஆர்டர் வரலாறு';

  @override
  String get customerProfileTitle => 'வாடிக்கையாளர் சுயவிவரம்';

  @override
  String get customerSaveContinue => 'சேமித்துத் தொடருங்கள்';

  @override
  String get customerSearchHintFull =>
      'தொலைபேசி, மின்னஞ்சல் அல்லது பெயரால் தேடுங்கள்';

  @override
  String get customerSelectOrAdd =>
      'தொடர வாடிக்கையாளரைத் தேர்ந்தெடுக்கவும் அல்லது சேர்க்கவும்';

  @override
  String get customerSelectSearchHint => 'வாடிக்கையாளர்களைத் தேடு';

  @override
  String get customersBackToSearch => 'தேடலுக்குத் திரும்பு';

  @override
  String get customersEmpty =>
      'இந்தக் கிளைக்கு இன்னும் சில்லறை அல்லது வணிக வாடிக்கையாளர்கள் இல்லை. Retail Customers / Business Customers இல் சேர்த்து ஒத்திசையுங்கள்.';

  @override
  String get customersNew => 'புதிய வாடிக்கையாளர்';

  @override
  String get customersSearchHint =>
      'பெயர், தொலைபேசி அல்லது மின்னஞ்சலால் தேடுங்கள்';

  @override
  String get customersTitle => 'வாடிக்கையாளர்கள்';

  @override
  String get dashboardCreditAmount => 'கடன் தொகை';

  @override
  String get dashboardCreditOrders => 'கடன் ஆர்டர்கள்';

  @override
  String get dashboardCreditOutstanding => 'நிலுவை கடன்';

  @override
  String get dashboardCredits => 'கடன்கள்';

  @override
  String get dashboardFilterMonth => 'இந்த மாதம்';

  @override
  String get dashboardFilterToday => 'இன்று';

  @override
  String get dashboardFilterWeek => 'இந்த வாரம்';

  @override
  String get dashboardFilterYear => 'இந்த ஆண்டு';

  @override
  String get dashboardFilterYesterday => 'நேற்று';

  @override
  String get dashboardMetricCancelled => 'ரத்து செய்யப்பட்டது';

  @override
  String get dashboardMetricDelivered => 'டெலிவரி செய்யப்பட்டவை';

  @override
  String get dashboardMetricDineIn => 'உள்ளே சாப்பிடுபவர்கள்';

  @override
  String get dashboardMetricOrders => 'ஆர்டர்கள்';

  @override
  String get dashboardMetricPickup => 'நேரடிப் பெறுதல்';

  @override
  String get dashboardMetricTotalSales => 'மொத்த விற்பனை';

  @override
  String get dashboardNoCategorySales => 'இன்னும் பிரிவு விற்பனை இல்லை';

  @override
  String get dashboardNoOpenCredits => 'திறந்த கடன்கள் இல்லை';

  @override
  String get dashboardNoPaymentsYet => 'இன்னும் கட்டணங்கள் இல்லை';

  @override
  String get dashboardNoProductSales => 'இன்னும் பொருள் விற்பனை இல்லை';

  @override
  String get dashboardNoSalesYet => 'இந்த காலத்தில் விற்பனை இல்லை';

  @override
  String get dashboardNoStaffSales => 'இந்தக் காலத்தில் ஊழியர் விற்பனை இல்லை.';

  @override
  String get dashboardOpenCredits => 'திறந்த கடன்கள்';

  @override
  String get dashboardOrderCount => 'ஆர்டர் எண்ணிக்கை';

  @override
  String get dashboardOrderTotal => 'ஆர்டர் மொத்தம்';

  @override
  String get dashboardPaymentMix => 'கட்டணக் கலவை';

  @override
  String get dashboardPaymentTypes => 'கட்டண வகைகள்';

  @override
  String get dashboardRefunds => 'பணத்திரும்பல்';

  @override
  String get dashboardRepayments => 'திருப்பிச் செலுத்தல்கள்';

  @override
  String get dashboardSalesByStaff => 'பணியாளர் விற்பனை';

  @override
  String get dashboardSalesTrend => 'விற்பனை போக்கு';

  @override
  String dashboardSoldCount(int count) {
    return '$count விற்கப்பட்டது';
  }

  @override
  String get dashboardStaffSalesHint =>
      'ஆர்டர்கள் · தொகை · செக்அவுட் ஊழியர் கடன்';

  @override
  String get dashboardTitle => 'பாஸ் (POS) டாஷ்போர்டு';

  @override
  String get dashboardTopCategories => 'சிறந்த பிரிவுகள்';

  @override
  String get dashboardTopProducts => 'சிறந்த பொருட்கள்';

  @override
  String get deviceAutoSync => 'தானியங்கி ஒத்திசைவு';

  @override
  String deviceAutoSyncEnabled(String interval) {
    return 'தானியங்கி ஒத்திசைவு இயக்கப்பட்டது — $interval';
  }

  @override
  String get deviceAutoSyncOff => 'தானியங்கி ஒத்திசைவு அணைக்கப்பட்டது';

  @override
  String get deviceAutoSyncRunning => 'பின்னணியில் இயங்குகிறது';

  @override
  String get deviceAutoSyncStarting =>
      'பின்னணியில் இயங்குகிறது (தொடங்குகிறது…)';

  @override
  String get deviceCashDenominations => 'பண நாணய மதிப்புகள்';

  @override
  String get deviceCashDenomsHint =>
      'Billing & Payment இல் காட்டப்படும் கமாவால் பிரிக்கப்பட்ட தொகை சில்லுகள்.';

  @override
  String get deviceCashDenomsSaved => 'பண நாணய மதிப்புகள் சேமிக்கப்பட்டன.';

  @override
  String get deviceCompanySettingsStaff => 'நிறுவனம் (அமைப்புகள் & ஊழியர்கள்)';

  @override
  String get deviceDangerZone => 'ஆபத்து மண்டலம்';

  @override
  String get deviceEnableAutoSync => 'தானியங்கி ஒத்திசையை இயக்கு';

  @override
  String get deviceInterval15Min => 'ஒவ்வொரு 15 நிமிடமும்';

  @override
  String get deviceInterval1Hour => 'ஒவ்வொரு 1 மணி நேரமும்';

  @override
  String get deviceInterval1Min => 'ஒவ்வொரு 1 நிமிடமும்';

  @override
  String get deviceInterval30Min => 'ஒவ்வொரு 30 நிமிடமும்';

  @override
  String get deviceInterval5Min => 'ஒவ்வொரு 5 நிமிடமும்';

  @override
  String deviceIntervalEveryMinutes(int minutes) {
    return 'ஒவ்வொரு $minutes நிமிடமும்';
  }

  @override
  String deviceIntervalEverySeconds(int seconds) {
    return 'ஒவ்வொரு $seconds வினாடியும்';
  }

  @override
  String get deviceKeepSavedServerUrls => 'சேமித்த சேவையக URLகளை வைத்திரு';

  @override
  String get deviceKeepSavedServers => 'சேமிக்கப்பட்ட சர்வர் URL களை வைத்திரு';

  @override
  String get deviceLastOnlineLogin => 'கடைசி ஆன்லைன் உள்நுழைவு';

  @override
  String get deviceLastSuccessfulSync => 'கடைசி வெற்றிகரமான ஒத்திசைவு';

  @override
  String deviceLeaseDaysCount(int count) {
    return '$count நாட்கள்';
  }

  @override
  String get deviceLeaseOneDay => '1 நாள்';

  @override
  String get deviceLoginLease => 'உள்நுழைவு காலம்';

  @override
  String get deviceLoginLeaseDays => 'உள்நுழைவு கால நாட்கள்';

  @override
  String get deviceOnlineSignInRequired => 'ஆன்லைன் உள்நுழைவு அவசியம்';

  @override
  String get deviceOpenSyncNow => 'இப்போது ஒத்திசையைத் திற';

  @override
  String get deviceResetAction => 'மீட்டமை';

  @override
  String get deviceResetAllLocal => 'அனைத்து உள்ளூர் தரவையும் மீட்டமை';

  @override
  String get deviceResetConfirmBody =>
      'இது உள்ளூர் ஆர்டர்கள், பட்டியல், வாடிக்கையாளர்கள், ஒத்திசை வரலாறு, சாதன அனுமதி கொடிகள் மற்றும் இந்த டேப்லெட்டில் உள்நுழைவை நிரந்தரமாக நீக்கும். சேவையகத்தில் எதையும் நீக்காது.';

  @override
  String get deviceResetConfirmTitle =>
      'அனைத்து உள்ளூர் தரவையும் மீட்டமைக்கவா?';

  @override
  String deviceResetFailed(String error) {
    return 'மீட்டமைப்பு தோல்வி: $error';
  }

  @override
  String get deviceResetLocalBody =>
      'சுத்தமான முதல் தொடக்கத்திலிருந்து சோதிக்க இந்த டேப்லெட்டின் ஆஃப்லைன் தரவுத்தளம், சாதன அமைப்பு, உள்நுழைவு மற்றும் ஒத்திசைவு வரலாறை அழிக்கவும்.';

  @override
  String get deviceResetting => 'மீட்டமைக்கிறது…';

  @override
  String get deviceSaveDenominations => 'நாணய மதிப்புகளைச் சேமி';

  @override
  String get deviceSettingsTitle => 'சாதன அமைப்புகள்';

  @override
  String get deviceSyncHistory => 'ஒத்திசைவு வரலாறு (கடைசி 20)';

  @override
  String get deviceSyncInterval => 'ஒத்திசைவு இடைவெளி';

  @override
  String get deviceSyncOnTapOnly => 'Sync ஐத் தட்டும்போது மட்டும் ஒத்திசை';

  @override
  String get deviceTypeResetConfirm =>
      'உறுதிப்படுத்த RESET என தட்டச்சு செய்யவும்';

  @override
  String get deviceTypeResetToConfirm =>
      'உறுதிப்படுத்த RESET என தட்டச்சு செய்யவும்';

  @override
  String get deviceValidUntil => 'செல்லுபடியாகும் வரை';

  @override
  String get dineInFloorFirst => 'முதல் தளம்';

  @override
  String get dineInFloorSecond => 'இரண்டாவது தளம்';

  @override
  String dineInTable(String number) {
    return 'மேஜை $number';
  }

  @override
  String get errorAccessDenied =>
      'அணுகல் மறுக்கப்பட்டது. நிர்வாகியிடம் இந்தச் சாதனத்தையும் கணக்கையும் சரிபார்க்கச் சொல்லுங்கள்.';

  @override
  String errorAmountExceedsOutstanding(String amount) {
    return 'தொகை நிலுவையை ($amount) மீறக்கூடாது.';
  }

  @override
  String get errorBootstrapFailed => 'தொடக்க அமைப்பு தோல்வி';

  @override
  String errorCancelFailed(String error) {
    return 'ரத்து தோல்வி: $error';
  }

  @override
  String get errorCannotReachServer =>
      'சர்வரை அணுக முடியவில்லை. இணைப்பையும் சர்வரையும் சரிபார்க்கவும்.';

  @override
  String errorCatalogueExportFailed(String message) {
    return 'பட்டியல் ஏற்றுமதி தோல்வி: $message';
  }

  @override
  String errorCheckoutFailed(String error) {
    return 'செக்அவுட் தோல்வி: $error';
  }

  @override
  String errorCollectFailed(String error) {
    return 'வசூல் தோல்வி: $error';
  }

  @override
  String get errorConfigLookupFailed => 'அமைப்பு தேடல் தோல்வி';

  @override
  String get errorCouldNotAddPaymentMethod =>
      'கட்டண முறையைச் சேர்க்க முடியவில்லை.';

  @override
  String get errorCouldNotAddSubscriber => 'சந்தாதாரரைச் சேர்க்க முடியவில்லை.';

  @override
  String errorCouldNotCancel(String error) {
    return 'ரத்து செய்ய முடியவில்லை: $error';
  }

  @override
  String errorCouldNotDeleteDraft(String error) {
    return 'வரைவை நீக்க முடியவில்லை: $error';
  }

  @override
  String get errorCouldNotLoadCompanySettings =>
      'நிறுவன அமைப்புகளை ஏற்ற முடியவில்லை.';

  @override
  String get errorCouldNotLoadReports => 'அறிக்கைகளை ஏற்ற முடியவில்லை.';

  @override
  String get errorCouldNotLoadStaff => 'ஊழியர்களை ஏற்ற முடியவில்லை.';

  @override
  String errorCouldNotOpenDraft(String error) {
    return 'வரைவைத் திறக்க முடியவில்லை: $error';
  }

  @override
  String get errorCouldNotPickLogo =>
      'லோகோவைத் தேர்ந்தெடுக்க முடியவில்லை. பயன்பாட்டை முழுமையாக மறுதொடக்கம் செய்து மீண்டும் முயலவும்.';

  @override
  String get errorCouldNotSaveCompanySettings =>
      'நிறுவன அமைப்புகளைச் சேமிக்க முடியவில்லை.';

  @override
  String errorCouldNotSaveDenoms(String error) {
    return 'நாணய மதிப்புகளைச் சேமிக்க முடியவில்லை: $error';
  }

  @override
  String errorCouldNotSaveDraft(String error) {
    return 'வரைவைச் சேமிக்க முடியவில்லை: $error';
  }

  @override
  String get errorCouldNotSync =>
      'ஒத்திசைக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';

  @override
  String get errorCouldNotUseCustomer =>
      'அந்த வாடிக்கையாளரைப் பயன்படுத்த முடியவில்லை. மீண்டும் முயலவும்.';

  @override
  String get errorCreditRequiresCustomer =>
      'கடனுக்கு சேமிக்கப்பட்ட வாடிக்கையாளர் தேவை. மீண்டும் முயலவும்.';

  @override
  String get errorDbNeedsUpdate =>
      'உள்ளூர் தரவுத்தளத்திற்கு புதுப்பிப்பு தேவை. பயன்பாட்டை முழுமையாக மறுதொடக்கம் செய்து மீண்டும் ஒத்திசையுங்கள்.';

  @override
  String errorDbOutdated(String detail) {
    return 'உள்ளூர் தரவுத்தளம் காலாவதி ($detail). பயன்பாட்டை முழுமையாக மறுதொடக்கம் செய்து மீண்டும் ஒத்திசையுங்கள்.';
  }

  @override
  String get errorFileNotFound => 'கோப்பு காணப்படவில்லை.';

  @override
  String get errorGeneric => 'ஏதோ தவறு நடந்தது. மீண்டும் முயற்சிக்கவும்.';

  @override
  String errorHttpFallback(String fallback, int statusCode) {
    return '$fallback (HTTP $statusCode)';
  }

  @override
  String get errorInvalidCredentials => 'தவறான அறிமுகச் சான்றுகள்';

  @override
  String get errorInvalidEmail => 'தவறான மின்னஞ்சல் முகவரி';

  @override
  String get errorInvalidPhone => 'சரியாக 10 இலக்கங்கள் இருக்க வேண்டும்';

  @override
  String get errorNameMinLength => 'குறைந்தபட்சம் 3 எழுத்துகள்';

  @override
  String get errorNamePackageUnitPriceRequired =>
      'பெயர், தொகுப்பு, அலகு மற்றும் விலை அவசியம்';

  @override
  String get errorNetwork => 'சேவையகத்தை அணுக முடியவில்லை';

  @override
  String errorNoCachedPosConfig(String orgCode) {
    return '\"$orgCode\" க்கான சேமிக்கப்பட்ட POS அமைப்பு இல்லை. முதலில் சாதன அமைப்பை முடிக்கவும்.';
  }

  @override
  String errorOrderNotFound(int orderId) {
    return 'ஆர்டர் #$orderId காணப்படவில்லை.';
  }

  @override
  String get errorOrganisationNotFound => 'நிறுவனம் காணப்படவில்லை';

  @override
  String get errorParentOrgNotFound => 'பெற்றோர் நிறுவனம் காணப்படவில்லை.';

  @override
  String errorPaymentFailed(String error) {
    return 'பணம் செலுத்தல் தோல்வி: $error';
  }

  @override
  String errorRefundFailed(String error) {
    return 'திருப்பிச் செலுத்தல் தோல்வி: $error';
  }

  @override
  String get errorRequiredField => 'இந்த புலம் அவசியம்';

  @override
  String errorScheduleFailed(String error) {
    return 'அட்டவணை தோல்வி: $error';
  }

  @override
  String get errorSecureConnectionFailed =>
      'பாதுகாப்பான இணைப்பு தோல்வி. சர்வர் முகவரியைச் சரிபார்த்து மீண்டும் முயலவும்.';

  @override
  String get errorSelectCustomerForCredit =>
      'நிலுவையைக் கடனில் வைக்க வாடிக்கையாளரைத் தேர்ந்தெடுக்கவும்.';

  @override
  String get errorSignInFailed =>
      'உள்நுழைவு தோல்வி. மின்னஞ்சல் மற்றும் கடவுச்சொல்லைச் சரிபார்த்து மீண்டும் முயலவும்.';

  @override
  String get errorSignInOnlineFirst =>
      'நிறுவன அமைப்புகளைப் புதுப்பிக்க முதலில் ஆன்லைனில் உள்நுழையவும்.';

  @override
  String get errorSignupFailed => 'பதிவு தோல்வி.';

  @override
  String errorSyncFailed(String error) {
    return 'ஒத்திசைவு தோல்வி: $error';
  }

  @override
  String get errorUnableLoadSignupOptions =>
      'பதிவு விருப்பங்களை ஏற்ற முடியவில்லை';

  @override
  String errorVoidFailed(String error) {
    return 'ரத்து தோல்வி: $error';
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
  String get forgotPasswordBackToSignIn => 'உள்நுழைவுக்குத் திரும்பு';

  @override
  String get forgotPasswordInstruction =>
      'உங்கள் பதிவு செய்யப்பட்ட மின்னஞ்சல் முகவரி அல்லது தொலைபேசி எண்ணை உள்ளிடவும்.';

  @override
  String get forgotPasswordSendLink => 'மீட்டமைப்பு இணைப்பை அனுப்பு';

  @override
  String get forgotPasswordSuccess =>
      'உங்கள் பதிவு செய்யப்பட்ட முகவரிக்கு கடவுச்சொல் மீட்டமைப்பு இணைப்பு அனுப்பப்பட்டுள்ளது!';

  @override
  String get forgotPasswordTitle => 'கடவுச்சொல் மறந்துவிட்டதா?';

  @override
  String get homeActivityPrompt =>
      'இன்று நீங்கள் என்ன செய்ய விரும்புகிறீர்கள்?';

  @override
  String get homeCatalogs => 'பட்டியல்கள்';

  @override
  String get homeCompany => 'நிறுவனம்';

  @override
  String get homeCreateOrder => 'புதிய ஆர்டர்';

  @override
  String get homeCredits => 'கடன்கள்';

  @override
  String get homeCustomers => 'வாடிக்கையாளர்கள்';

  @override
  String get homeDashboardDesc => 'பகுப்பாய்வு மற்றும் சுருக்கத்தைக் காண்க';

  @override
  String get homeDeviceSettings => 'சாதன அமைப்புகள்';

  @override
  String get homeDraftOrders => 'வரைவுகள்';

  @override
  String get homeLogoutTooltip => 'வெளியேறு';

  @override
  String get homeMenu => 'மெனு';

  @override
  String homeNewOrderCount(int count) {
    return 'புதிய ஆர்டர் ($count)';
  }

  @override
  String get homeNoItems => 'பொருட்கள் இல்லை';

  @override
  String get homeNoSavedDrafts => 'இன்னும் சேமித்த வரைவுகள் இல்லை.';

  @override
  String get homeOpenStoreFirst => 'முதலில் ஒரு கிளையைத் திறக்கவும்';

  @override
  String get homeOrdersList => 'ஆர்டர்கள்';

  @override
  String get homeOrdersListDesc => 'அனைத்து ஆர்டர்களையும் நிர்வகிக்கவும்';

  @override
  String get homePosDashboard => 'பாஸ் (POS) டாஷ்போர்டு';

  @override
  String get homeRefunds => 'பணத்திரும்பல்';

  @override
  String get homeSavedDrafts => 'சேமிக்கப்பட்ட வரைவுகள்';

  @override
  String get homeStoreAdminRequiredCompany =>
      'நிறுவனத்திற்கு கடை நிர்வாகி அணுகல் தேவை.';

  @override
  String get homeStoreAdminRequiredSetup =>
      'கடை அமைப்புக்கு கடை நிர்வாகி அணுகல் தேவை.';

  @override
  String get homeStoreSetup => 'கடை அமைப்பு';

  @override
  String get homeSyncFailedRetry =>
      'ஒத்திசைவு தோல்வி — மீண்டும் முயற்சிக்க தட்டவும்';

  @override
  String get homeSyncTooltip => 'ஒத்திசை';

  @override
  String homeViewAllCount(int count) {
    return 'அனைத்தையும் காண்க ($count)';
  }

  @override
  String get homeWelcomeBack => 'மீண்டும் வரவேற்கிறோம்';

  @override
  String get invoiceAmountPaid => 'செலுத்திய தொகை';

  @override
  String invoiceMethod(String method) {
    return 'முறை: $method';
  }

  @override
  String get invoiceOrderSummary => 'ஆர்டர் சுருக்கம்';

  @override
  String get invoicePrinting =>
      'தermal அல்லது வெப்ப அச்சுப்பொறிக்கு அச்சிடுகிறது…';

  @override
  String get invoiceTitle => 'விலைப்பட்டியல் / ரசீது';

  @override
  String get languageEnglish => 'ஆங்கிலம்';

  @override
  String get languageLabel => 'மொழி';

  @override
  String get languageTamil => 'தமிழ்';

  @override
  String get orderAddRecordPayment => 'தொகை சேர் / பதிவு செய்';

  @override
  String orderAddonsLabel(String labels) {
    return 'துணைப்பொருட்கள்: $labels';
  }

  @override
  String get orderAllItemsSentKitchen =>
      'அனைத்து பொருட்களும் ஏற்கனவே சமையலறைக்கு அனுப்பப்பட்டன.';

  @override
  String get orderAlreadyFullyPaid =>
      'இந்த ஆர்டர் ஏற்கனவே முழுமையாகச் செலுத்தப்பட்டது.';

  @override
  String get orderAlreadyFullyRefunded =>
      'இந்தத் தொகை ஏற்கனவே முழுமையாகத் திருப்பப்பட்டது.';

  @override
  String get orderAppliedOffers => 'பயன்படுத்தப்பட்ட சலுகைகள்';

  @override
  String get orderCancelConfirm =>
      'இந்த ஆர்டரை ரத்துசெய்யப்பட்டதாகக் குறிக்கவா?';

  @override
  String get orderCancelTitle => 'ஆர்டரை ரத்துசெய்';

  @override
  String get orderCancelled => 'ஆர்டர் ரத்துசெய்யப்பட்டது.';

  @override
  String get orderCancelledTitle => 'ஆர்டர் ரத்துசெய்யப்பட்டது';

  @override
  String orderChartPoint(String label, String amount, int count) {
    return '$label\n$amount\n$count ஆர்டர்கள்';
  }

  @override
  String get orderClearFilter => 'வடிகட்டியை அழி';

  @override
  String get orderCompleted => 'முடிக்கப்பட்டது';

  @override
  String orderCouldNotOpenDraft(String error) {
    return 'வரைவைத் திறக்க முடியவில்லை: $error';
  }

  @override
  String get orderCreateAddItemsBeforeDraft =>
      'வரைவைச் சேமிக்க முன் பொருட்களைச் சேர்க்கவும்.';

  @override
  String get orderCreateAddMiscItem => 'இதர பொருளைச் சேர்';

  @override
  String get orderCreateAllItemsSentKitchen =>
      'அனைத்து பொருட்களும் ஏற்கனவே சமையலறைக்கு அனுப்பப்பட்டுள்ளன.';

  @override
  String get orderCreateCartEmpty => 'உங்கள் கார்ட் காலியாக உள்ளது';

  @override
  String get orderCreateDeleteDraftBody =>
      'இது கார்ட்டை அழித்து சேமித்த வரைவை நீக்கும்.';

  @override
  String get orderCreateDraftDeleted => 'வரைவு நீக்கப்பட்டது.';

  @override
  String get orderCreateDraftSaved => 'வரைவு சேமிக்கப்பட்டது.';

  @override
  String get orderCreateEnterValidPrice => 'சரியான விலையை உள்ளிடவும்';

  @override
  String orderCreateFloorTable(String floor, String table) {
    return 'தளம்: $floor | மேசை: $table';
  }

  @override
  String get orderCreateHistoryRefreshed => 'வரலாறு புதுப்பிக்கப்பட்டது';

  @override
  String orderCreateHowMany(String unit) {
    return 'எத்தனை $unit?';
  }

  @override
  String orderCreateKotFailed(String error) {
    return 'KOT தோல்வி: $error';
  }

  @override
  String orderCreateKotSent(int batch, int orderId) {
    return 'KOT #$batch அனுப்பப்பட்டது · ஆர்டர் #$orderId சேமிக்கப்பட்டது';
  }

  @override
  String get orderCreateMisc => 'இதர';

  @override
  String orderCreateNewOrderTitle(String orderType) {
    return 'புதிய $orderType ஆர்டர்';
  }

  @override
  String get orderCreateNoOrderHistory => 'இன்னும் ஆர்டர் வரலாறு இல்லை';

  @override
  String get orderCreatePastOrders => 'கடந்த ஆர்டர்கள்';

  @override
  String get orderCreateProductName => 'பொருள் பெயர்';

  @override
  String orderCreateQuantityUnit(String unit) {
    return 'அளவு ($unit)';
  }

  @override
  String get orderCreateSaveDraftTooltip =>
      'வண்டி வரைவைச் சேமி (முகப்பு வரைவுகள்; கொள்முதல் பட்டியல் அல்ல)';

  @override
  String get orderCreateTitle => 'புதிய ஆர்டர்';

  @override
  String get orderCreationSaveContinue => 'சேமித்துத் தொடருங்கள்';

  @override
  String get orderDeleteDraft => 'வரைவை நீக்கு';

  @override
  String get orderDeleteDraftConfirm =>
      'இந்த வரைவு ஆர்டரை நிரந்தரமாக நீக்கவா? இதை மாற்ற முடியாது.';

  @override
  String get orderDeleteDraftQuestion => 'வரைவை நீக்கவா?';

  @override
  String get orderDeliveredStatus => 'ஆர்டர் டெலிவரி செய்யப்பட்டது';

  @override
  String orderDetailsDueSuffix(String amount) {
    return ' · நிலுவை $amount';
  }

  @override
  String get orderDetailsNoPaymentsRecorded =>
      'இன்னும் பணம் பதிவு செய்யப்படவில்லை.';

  @override
  String orderDetailsRefundablePayments(int count) {
    return '$count பணம்செலுத்தலில் இன்னும் திருப்பிச் செலுத்தக்கூடிய இருப்பு உள்ளது. இந்த ஆர்டரை ரத்துசெய்ய இப்போது திரும்பப்பெறவும், அல்லது தனித்தனியாக திரும்பப்பெற Payments-ஐத் திறக்கவும்.';
  }

  @override
  String get orderDetailsTitle => 'ஆர்டர் விவரங்கள்';

  @override
  String orderDetailsTotalPaid(String amount) {
    return 'மொத்தம் செலுத்தப்பட்டது $amount';
  }

  @override
  String get orderDetailsViewPayments => 'பணம் செலுத்தல்களைக் காண்க';

  @override
  String get orderDraftDeleted => 'வரைவு நீக்கப்பட்டது.';

  @override
  String get orderDraftSaved =>
      'வண்டி வரைவு சேமிக்கப்பட்டது. முகப்பு → சேமிக்கப்பட்ட வரைவுகள் வழியாகத் திறக்கவும்.';

  @override
  String get orderGoToPayments => 'கட்டணங்களுக்குச் செல்';

  @override
  String orderHistoryId(String id, int orderId) {
    return '$id · ஆர்டர் #$orderId';
  }

  @override
  String orderKotFailed(String error) {
    return 'KOT தோல்வி: $error';
  }

  @override
  String get orderListCancelHint =>
      'ஆர்டரை ரத்து செய்ய, ஆர்டர் விவரங்களைத் திறந்து ரத்து செய் பயன்படுத்தவும் (பணம் செலுத்தப்பட்டிருந்தால் முதலில் திருப்பிச் செலுத்த வேண்டும்).';

  @override
  String get orderListClearFilter => 'வடிகட்டியை அழி';

  @override
  String get orderListColumnActions => 'செயல்கள்';

  @override
  String get orderListColumnItems => 'பொருட்கள்';

  @override
  String get orderListColumnName => 'பெயர்';

  @override
  String get orderListColumnOrderId => 'ஆர்டர் ஐடி';

  @override
  String get orderListColumnOrderType => 'வகை';

  @override
  String get orderListColumnPayment => 'தொகை';

  @override
  String get orderListColumnSlNo => 'வ.எண்';

  @override
  String get orderListColumnStatus => 'நிலை';

  @override
  String get orderListColumnTime => 'நேரம்';

  @override
  String get orderListColumnTotal => 'மொத்தம்';

  @override
  String get orderListFilterAll => 'அனைத்தும்';

  @override
  String get orderListFilterButton => 'வடிகட்டி';

  @override
  String get orderListFilterDelivery => 'டெலிவரி';

  @override
  String get orderListFilterDineIn => 'உள்ளே சாப்பிடுபவர்கள்';

  @override
  String get orderListFilterPickup => 'நேரடிப் பெறுதல்';

  @override
  String get orderListNoOrdersFound => 'ஆர்டர்கள் எதுவும் இல்லை';

  @override
  String get orderListPayNow => 'இப்போது செலுத்து';

  @override
  String orderListPosCode(String code) {
    return 'POS $code';
  }

  @override
  String orderListPrintInvoiceBody(String orderId) {
    return 'ஆர்டர் #$orderId க்கான விலைப்பட்டியலை அச்சிடவா?';
  }

  @override
  String get orderListPrintInvoiceTitle => 'விலைப்பட்டியல் அச்சிடு';

  @override
  String get orderListRefreshButton => 'புதுப்பி';

  @override
  String get orderListSearchHint =>
      'ஆர்டர் ஐடி, பெயர், தொலைபேசி, மின்னஞ்சல் மூலம் தேடுங்கள்...';

  @override
  String orderListSelectNewStatus(String orderId) {
    return 'ஆர்டர் #$orderId க்கான புதிய நிலையைத் தேர்ந்தெடுக்கவும்:';
  }

  @override
  String orderListServeNumber(String number) {
    return 'சேவை #$number';
  }

  @override
  String orderListUnableOpenOrder(String orderId) {
    return 'ஆர்டர் #$orderId ஐ திறக்க முடியவில்லை';
  }

  @override
  String get orderListUpdateStatusTitle => 'நிலையை புதுப்பி';

  @override
  String get orderMisc => 'இதர';

  @override
  String get orderNoItems => 'இந்த ஆர்டரில் பொருட்கள் இல்லை.';

  @override
  String get orderNotSyncedRemote =>
      'இன்னும் ரிமோட்டிற்கு ஒத்திசைக்கப்படவில்லை';

  @override
  String orderNumber(int orderId) {
    return 'ஆர்டர் #$orderId';
  }

  @override
  String orderOfferLabel(String label) {
    return 'சலுகை: $label';
  }

  @override
  String orderPaymentFailed(String error) {
    return 'தொகை பதிவு தோல்வி: $error';
  }

  @override
  String get orderPaymentsAddPayment => 'பணம் சேர்';

  @override
  String orderPaymentsCustomerLabel(String label) {
    return 'வாடிக்கையாளர் $label';
  }

  @override
  String get orderPaymentsFullyPaid =>
      'இந்த ஆர்டர் ஏற்கனவே முழுமையாக செலுத்தப்பட்டது.';

  @override
  String get orderPaymentsFullyRefunded =>
      'இந்த பணம் ஏற்கனவே முழுமையாக திருப்பிச் செலுத்தப்பட்டது.';

  @override
  String get orderPaymentsNoPaymentsRecorded =>
      'இந்த ஆர்டருக்கு பணம் பதிவு செய்யப்படவில்லை.';

  @override
  String get orderPaymentsNoPaymentsUnpaid =>
      'இன்னும் பணம் இல்லை. இந்த செலுத்தப்படாத ஆர்டருக்கு பணம் பதிவு செய்யவும்.';

  @override
  String get orderPaymentsOnlineUpi => 'ஆன்லைன் / UPI';

  @override
  String orderPaymentsOrderSummary(String total, String remaining) {
    return 'ஆர்டர் மொத்தம் $total · நிலுவை $remaining';
  }

  @override
  String get orderPaymentsReasonOptional => 'காரணம் (விருப்பம்)';

  @override
  String get orderPaymentsRecordTitle => 'பணம் பதிவு செய்';

  @override
  String orderPaymentsRecordedBalance(String balance) {
    return 'பணம் பதிவு செய்யப்பட்டது. நிலுவை $balance';
  }

  @override
  String get orderPaymentsRecordedFullyPaid =>
      'பணம் பதிவு செய்யப்பட்டது. ஆர்டர் முழுமையாக செலுத்தப்பட்டது.';

  @override
  String orderPaymentsRefLabel(String reference) {
    return 'குறிப்பு $reference';
  }

  @override
  String get orderPaymentsRefundAction => 'திருப்பிச் செலுத்து';

  @override
  String get orderPaymentsRefundAmount => 'திருப்பிச் செலுத்தும் தொகை';

  @override
  String orderPaymentsRefundAmountRange(String max) {
    return '0.01 முதல் $max வரை தொகையை உள்ளிடவும்.';
  }

  @override
  String get orderPaymentsRefundTitle => 'பணம் திருப்பிச் செலுத்து';

  @override
  String orderPaymentsRefundableOf(String refundable, String total) {
    return 'திருப்பிச் செலுத்தக்கூடிய $refundable / $total';
  }

  @override
  String orderPaymentsRefundedAmount(String amount) {
    return '$amount திருப்பிச் செலுத்தப்பட்டது.';
  }

  @override
  String get orderPaymentsRefundedCancelled =>
      'கட்டணங்கள் திருப்பப்பட்டு ஆர்டர் ரத்துசெய்யப்பட்டது.';

  @override
  String orderPaymentsRefundedLeft(String refunded, String left) {
    return 'திருப்பிச் செலுத்தப்பட்டது $refunded · மீதம் $left';
  }

  @override
  String get orderPaymentsTitle => 'ஆர்டர் கட்டணங்கள்';

  @override
  String get orderPrintInvoice => 'விலைப்பட்டியலை அச்சிடு';

  @override
  String orderPrintInvoiceConfirm(int orderId) {
    return 'ஆர்டர் #$orderId க்கான விலைப்பட்டியலை அச்சிடவா?';
  }

  @override
  String get orderReadyToServe => 'சேவைக்குத் தயார்';

  @override
  String get orderRecordPayment => 'கட்டணத்தைப் பதிவுசெய்';

  @override
  String get orderRefund => 'பணத்திருப்பம்';

  @override
  String get orderRefundAllAndCancel => 'அனைத்தையும் திருப்பி ரத்துசெய்';

  @override
  String orderRefundBeforeCancelBody(int count) {
    return '$count கட்டண(ங்கள்) இன்னும் திருப்பக்கூடிய நிலுவை உள்ளன. ஆர்டரை ரத்துசெய்ய இப்போது திருப்பவும், அல்லது தனித்தனியாக திருப்ப Payments ஐத் திறக்கவும்.';
  }

  @override
  String get orderRefundBeforeCancelTitle => 'ரத்துக்கு முன் பணத்தைத் திருப்பு';

  @override
  String orderRefundFailed(String error) {
    return 'பணத்திருப்பம் தோல்வி: $error';
  }

  @override
  String get orderRefundNotNow => 'இப்போது வேண்டாம்';

  @override
  String get orderRefundPayment => 'கட்டணத்தைத் திருப்பு';

  @override
  String orderRefundedAmount(String amount) {
    return '$amount திருப்பப்பட்டது.';
  }

  @override
  String get orderSaveDraft => 'வண்டி வரைவைச் சேமி';

  @override
  String get orderSummary => 'சுருக்கம்';

  @override
  String get orderSyncedRemote => 'ரிமோட் பேக்கெண்டிற்கு ஒத்திசைக்கப்பட்டது';

  @override
  String get orderTypeDineIn => 'உள்ளே சாப்பிடுபவர்கள்';

  @override
  String get orderTypePickup => 'நேரடிப் பெறுதல்';

  @override
  String get orderTypeSelection => 'ஆர்டர் வகையைத் தேர்ந்தெடுக்கவும்';

  @override
  String orderTypeTable(String type, String table) {
    return '$type · $table';
  }

  @override
  String orderUnableToOpen(int orderId) {
    return 'ஆர்டர் #$orderId ஐத் திறக்க முடியவில்லை';
  }

  @override
  String get orderUpdateStatus => 'நிலையைப் புதுப்பி';

  @override
  String get pickupAddButton => 'சேர்';

  @override
  String get pickupCancelButton => 'ரத்துசெய்';

  @override
  String get pickupName => 'பெயர்';

  @override
  String get pickupNameHint => 'உங்கள் பெயரை உள்ளிடவும்';

  @override
  String get pickupPhone => 'தொலைபேசி எண்';

  @override
  String get pickupPhoneHint => '10 இலக்க எண்ணை உள்ளிடவும்';

  @override
  String get profileAccount => 'கணக்கு';

  @override
  String get profileCode => 'குறியீடு';

  @override
  String get profileContactEmail => 'தொடர்பு மின்னஞ்சல்';

  @override
  String get profileCurrent => 'தற்போதைய';

  @override
  String get profileCurrentStore => 'தற்போதைய கிளை';

  @override
  String get profileMyProfile => 'என் சுயவிவரம்';

  @override
  String get profileOrganisationRole => 'நிறுவனப் பங்கு';

  @override
  String get profilePosOperator => 'POS இயக்குனர்';

  @override
  String get profileRole => 'பங்கு';

  @override
  String get profileServiceInstance => 'சேவை நிகழ்வு';

  @override
  String get profileSignedIn => 'உள்நுழைந்தது';

  @override
  String get profileSignedInAs => 'உள்நுழைந்துள்ளவர்';

  @override
  String get profileStoreId => 'கிளை அடையாளம்';

  @override
  String get profileStoreLabel => 'கிளை';

  @override
  String get profileStoreRole => 'கடைப் பங்கு';

  @override
  String get profileTitle => 'சுயவிவரம்';

  @override
  String get profileType => 'வகை';

  @override
  String refundsCount(int count) {
    return '$count பணத்திருப்பங்கள்';
  }

  @override
  String get refundsEmpty => 'இன்னும் பணத்திருப்பங்கள் பதிவுசெய்யப்படவில்லை.';

  @override
  String refundsPeriodTitle(String period) {
    return 'பணத்திருப்பங்கள் · $period';
  }

  @override
  String get refundsTitle => 'பணத்திரும்பல்';

  @override
  String get scheduledPaymentsTitle => 'திட்டமிட்ட கட்டணங்கள்';

  @override
  String get signInButton => 'உள்நுழைக';

  @override
  String get signInEmailPhone => 'மின்னஞ்சல் / மொபைல் எண்';

  @override
  String get signInEmailPhoneHint => 'மின்னஞ்சல் அல்லது மொபைலை உள்ளிடவும்';

  @override
  String get signInForgotPasswordPrompt => 'கடவுச்சொல் மறந்துவிட்டதா?';

  @override
  String get signInIdentifierHint => 'மின்னஞ்சல் / தொலைபேசி / பணியாளர் ஐடி';

  @override
  String get signInNewCompany => 'புதிய நிறுவனமா?';

  @override
  String get signInPassword => 'கடவுச்சொல்';

  @override
  String get signInPasswordHint => 'கடவுச்சொல்லை உள்ளிடவும்';

  @override
  String get signInRenewDevice => 'இந்த சாதனத்தைப் புதுப்பிக்க உள்நுழைக';

  @override
  String get signInShowPassword => 'கடவுச்சொல்லைக் காட்டு';

  @override
  String get signInWelcome => 'வரவேற்பு';

  @override
  String get signupAlreadyHaveCompany => 'ஏற்கனவே நிறுவனம் உள்ளதா? உள்நுழைக';

  @override
  String get signupBackToBranch => 'கிளை விவரங்களுக்குத் திரும்பு';

  @override
  String get signupBackToSignIn => 'உள்நுழைவுக்குத் திரும்பு';

  @override
  String get signupBodyBranch =>
      'கிளை மற்றும் நகரத்தை பெயரிடுங்கள். பதிவு எண் விருப்பமானது.';

  @override
  String get signupBodyBusinessType =>
      'வணிக வகையைத் தேர்வுசெய்க. உங்கள் கிளையின் கீழ் உணவகக் கடை உருவாக்கப்படும்.';

  @override
  String get signupBodyCompanyDetails =>
      'நிறுவனம் மற்றும் அதை நிர்வகிக்கும் உரிமையாளர் பற்றி கூறுங்கள்.';

  @override
  String get signupBodyCreateCompany =>
      'இந்த டேப்லெட்டுக்காக புதிய நிறுவனத்தை உருவாக்கவும்.';

  @override
  String get signupBodyCreateCompanyManual =>
      'சேவையகம் மற்றும் தாய் நிறுவனத்தை உள்ளிட்டு இந்த டேப்லெட்டுக்காக புதிய நிறுவனத்தை உருவாக்கவும்.';

  @override
  String get signupBodyReady =>
      'உங்கள் நிறுவனம் தயாராக உள்ளது. நிறுவன அடையாளம் மற்றும் கடவுச்சொல்லுடன் உள்நுழைக.';

  @override
  String get signupBodySettingUp =>
      'உங்கள் நிறுவனம், கிளை மற்றும் கடை உருவாக்கப்படுகிறது — சிறிது நேரம் மட்டும்.';

  @override
  String get signupBranchName => 'கிளைப் பெயர்';

  @override
  String get signupBusinessBakery => 'பேக்கரி';

  @override
  String get signupBusinessCafe => 'காஃபி';

  @override
  String get signupBusinessOther => 'மற்றவை';

  @override
  String get signupBusinessRestaurant => 'உணவகம்';

  @override
  String get signupCity => 'நகரம்';

  @override
  String get signupCompanyIdentifier => 'நிறுவன அடையாளம்';

  @override
  String get signupCompanyName => 'நிறுவனப் பெயர்';

  @override
  String get signupConfirmPassword => 'கடவுச்சொல்லை உறுதிப்படுத்து';

  @override
  String get signupCouldNotPrepare => 'நிறுவனப் பதிவைத் தயாரிக்க முடியவில்லை.';

  @override
  String get signupCountry => 'நாடு';

  @override
  String get signupCreateCompany => 'நிறுவனம் உருவாக்கு';

  @override
  String get signupJoinExistingDevice =>
      'ஏற்கனவே உள்ள நிறுவன சாதனத்தில் சேரவும்';

  @override
  String get signupLoginNow => 'இப்போது உள்நுழைக';

  @override
  String signupNoCountriesMatch(String query) {
    return '“$query” உடன் பொருந்தும் நாடுகள் இல்லை';
  }

  @override
  String get signupOwnerName => 'உரிமையாளர் பெயர்';

  @override
  String get signupParentOrgHelp =>
      'தொடர்வதற்கு முன் இந்த நிறுவனம் உள்ளதா எனச் சரிபார்ப்போம்.';

  @override
  String get signupParentOrgHint => 'தாய் நிறுவன அடையாளம்';

  @override
  String get signupPasswordHelp =>
      'தரைப் பணியாளர்களுக்கு எளிமையாக வைத்திருங்கள் — எழுத்துகள், எண்கள் அல்லது இரண்டும்.';

  @override
  String get signupPasswordHint => 'கடவுச்சொல் (குறைந்தது 6 எழுத்துகள்/எண்கள்)';

  @override
  String get signupPasswordsDoNotMatch => 'கடவுச்சொற்கள் பொருந்தவில்லை';

  @override
  String get signupPhoneHint => 'தொலைபேசி எண்';

  @override
  String signupPhoneHintWithDial(String dialCode) {
    return 'தொலைபேசி எண் (எ.கா. $dialCode 9876543210)';
  }

  @override
  String get signupChooseLanguage =>
      'உங்களுக்கு விருப்பமான மொழியைத் தேர்ந்தெடுக்கவும்';

  @override
  String get signupChooseLanguageHelp =>
      'பதிவு திரைகள் இந்த மொழியில் காண்பிக்கப்படும். மொழி மெனுவைப் பயன்படுத்தி எப்போது வேண்டுமானாலும் மாற்றலாம்.';

  @override
  String get signupPreparing => 'நிறுவனப் பதிவு தயாராகிறது.';

  @override
  String get signupProgressCreatingCompany => 'நிறுவனத்தை உருவாக்குகிறது';

  @override
  String get signupProgressCreatingUser => 'பயனரை உருவாக்குகிறது';

  @override
  String get signupProgressSettingAccount => 'கணக்கை அமைக்கிறது';

  @override
  String get signupProgressSettingBranch => 'கிளையை அமைக்கிறது';

  @override
  String get signupProgressSettingProfile => 'சுயவிவரத்தை அமைக்கிறது';

  @override
  String get signupProgressSuccess => 'வாழ்த்துக்கள் — வெற்றி';

  @override
  String get signupRegistrationOptional => 'பதிவு எண் (விரும்பினால்)';

  @override
  String get signupSearchCountry => 'நாடு, குறியீடு அல்லது டயல் தேடு';

  @override
  String get signupSelectCountry => 'நாட்டைத் தேர்வுசெய்க';

  @override
  String get signupServerUrlHint =>
      'சேவையக URL (எ.கா. http://192.168.1.10:8000)';

  @override
  String get signupTitleBranch => 'உங்கள் முதல் கிளை';

  @override
  String get signupTitleBusinessType => 'நீங்கள் என்ன நடத்துகிறீர்கள்?';

  @override
  String get signupTitleCompanyDetails => 'நிறுவன விவரங்கள்';

  @override
  String get signupTitleCreateCompany => 'உங்கள் நிறுவனத்தை உருவாக்குங்கள்';

  @override
  String get signupTitleReady => 'நீங்கள் தயாராக உள்ளீர்கள்';

  @override
  String get signupTitleSettingUp => 'அமைப்பு நடைபெறுகிறது';

  @override
  String get signupTryAgain => 'மீண்டும் முயற்சி';

  @override
  String get signupUseIdentifierHelp =>
      'உள்நுழைய இந்த அடையாளத்தை மின்னஞ்சல்/தொலைபேசி மற்றும் கடவுச்சொல்லுடன் பயன்படுத்தவும்.';

  @override
  String get splashCheckAgain => 'மீண்டும் சரிபார்';

  @override
  String get splashDeviceNotApproved => 'சாதனம் அங்கீகரிக்கப்படவில்லை';

  @override
  String get splashInitError => 'தொடக்கப் பிழை';

  @override
  String get splashNoConfig => 'சேமிக்கப்பட்ட அமைப்பு இல்லை';

  @override
  String get splashNoOrgCode => 'சேமிக்கப்பட்ட நிறுவனக் குறியீடு இல்லை';

  @override
  String get splashPleaseSignIn => 'தொடர உள்நுழையவும்';

  @override
  String get splashTagline => 'ஒவ்வொரு பரிவர்த்தனையிலும் துல்லியம்';

  @override
  String get staffLockAllStaff => 'அனைத்து ஊழியர்களும்';

  @override
  String get staffLockBranchNotLoaded => 'கிளை ஏற்றப்படவில்லை';

  @override
  String get staffLockMore => 'மேலும்';

  @override
  String get staffLockOnlineSignIn => 'ஆன்லைன் சாதன உள்நுழைவு';

  @override
  String get staffLockStaffId => 'ஊழியர் அடையாளம்';

  @override
  String staffLockStaffStore(String storeName) {
    return 'ஊழியர் · $storeName';
  }

  @override
  String get staffLockSwitchStore => 'கிளையை மாற்று';

  @override
  String get staffLockTitle => 'பணியாளர் திறப்பு';

  @override
  String get staffLockUnlock => 'திற';

  @override
  String get staffLogoutConfirmBody =>
      'இது பதிவேட்டைப் பூட்டும். மற்றொரு பணியாளர் தங்கள் பின் அல்லது கடவுச்சொல்லால் திறக்கலாம்.';

  @override
  String get staffLogoutConfirmBodyFull =>
      'நீங்கள் வெளியேற்றப்படுவீர்கள்; உங்கள் பின் இந்தச் சாதனத்திலிருந்து நீக்கப்படும். அடுத்தவர் ஆன்லைனில் உள்நுழைய வேண்டும். ஏற்கனவே சேமிக்கப்பட்ட ஆர்டர்கள் இந்தச் சாதனத்தில் இருக்கும்.';

  @override
  String get staffLogoutConfirmTitle => 'பணியாளரை வெளியேற்றவா?';

  @override
  String get statusApproved => 'அங்கீகரிக்கப்பட்டது';

  @override
  String get statusCollected => 'வசூலிக்கப்பட்டது';

  @override
  String get statusCooking => 'சமைக்கிறது';

  @override
  String get statusDelivered => 'டெலிவரி செய்யப்பட்டது';

  @override
  String get statusFailed => 'தோல்வி';

  @override
  String get statusInitiated => 'தொடங்கப்பட்டது';

  @override
  String get statusOpen => 'திறந்தது';

  @override
  String get statusOrderAccepted => 'ஆர்டர் ஏற்கப்பட்டது';

  @override
  String get statusOrderCancelled => 'ஆர்டர் ரத்து';

  @override
  String get statusOrderCompleted => 'ஆர்டர் முடிந்தது';

  @override
  String get statusOrderPending => 'ஆர்டர் நிலுவை';

  @override
  String get statusOrderPreparing => 'ஆர்டர் தயாராகிறது';

  @override
  String get statusOrderReady => 'ஆர்டர் தயார்';

  @override
  String get statusPaid => 'செலுத்தப்பட்டது';

  @override
  String get statusPartial => 'பகுதி';

  @override
  String get statusPickedUp => 'எடுக்கப்பட்டது';

  @override
  String get statusPlaced => 'வைக்கப்பட்டது';

  @override
  String get statusReadyToServe => 'சேவைக்குத் தயார்';

  @override
  String get statusRefunded => 'திரும்பப் பெறப்பட்டது';

  @override
  String get statusRejected => 'நிராகரிக்கப்பட்டது';

  @override
  String get statusReturned => 'திரும்பியது';

  @override
  String get statusServed => 'சேவை செய்யப்பட்டது';

  @override
  String get statusSettled => 'தீர்க்கப்பட்டது';

  @override
  String get statusUnpaid => 'செலுத்தப்படவில்லை';

  @override
  String get storeAdminAccessRequired => 'கடை நிர்வாகி அணுகல் தேவை.';

  @override
  String get storeListBackToUnlock => 'ஊழியர் திறப்பிற்குத் திரும்பு';

  @override
  String get storeListChooseBranchUnlock =>
      'கிளையைத் தேர்ந்தெடுத்து ஊழியர் அடையாளத்தால் திறக்கவும்';

  @override
  String get storeListChooseStore => 'தொடர உங்கள் கிளையைத் தேர்ந்தெடுக்கவும்';

  @override
  String get storeListEmpty => 'கிளைகள் இல்லை';

  @override
  String get storeListLoading => 'கிளைகள் ஏற்றப்படுகின்றன...';

  @override
  String get storeListOpenBranch => 'கிளையைத் திற';

  @override
  String get storeListSearchHint =>
      'கிளை பெயர் அல்லது அடையாளத்தால் தேடுங்கள்...';

  @override
  String get storeListSelectStore => 'கிளையைத் தேர்ந்தெடு';

  @override
  String storeListStoreId(String storeId) {
    return 'கிளை அடையாளம்: $storeId';
  }

  @override
  String get storeListTitle => 'என் கடைகள்';

  @override
  String storeListTitleCount(int count) {
    return 'என் கடைகள் ($count)';
  }

  @override
  String storeSelectedSuccess(String storeName) {
    return '$storeName வெற்றிகரமாகத் தேர்ந்தெடுக்கப்பட்டது!';
  }

  @override
  String storeSyncTitle(String storeName) {
    return '$storeName அமைக்கப்படுகிறது';
  }

  @override
  String get storeSyncBody =>
      'பட்டியல், வாடிக்கையாளர்கள் மற்றும் ஆர்டர்கள் இந்தச் சாதனத்திற்குப் பதிவிறக்கப்படுகின்றன. பயன்பாட்டைத் திறந்தே வைத்திருங்கள்.';

  @override
  String get storeSyncPreparing => 'தயாராகிறது…';

  @override
  String get storeSetupAccess => 'அணுகல்';

  @override
  String get storeSetupAddCashier => 'காசாளரைச் சேர்';

  @override
  String get storeSetupAddCashierHint =>
      'பெயர், மின்னஞ்சல், தொலைபேசி மற்றும் கடவுச்சொல்லுடன் காசியரைச் சேர்க்கவும்.';

  @override
  String get storeSetupAddGroup => 'குழுவைச் சேர்';

  @override
  String get storeSetupAddLinkCategoryFirst =>
      'முதலில் ஒரு பிரிவைச் சேர்த்து இணைக்கவும்';

  @override
  String get storeSetupAddOffer => 'சலுகையைச் சேர்';

  @override
  String get storeSetupAddSellableItem => 'விற்பனை பொருளைச் சேர்';

  @override
  String get storeSetupAddToStore => 'கிளையில் சேர்';

  @override
  String get storeSetupAddonDeletedOffline =>
      'துணைப்பொருள் ஆஃப்லைனில் நீக்கப்பட்டது. ஏற்றுமதிக்கு ஒத்திசையுங்கள்.';

  @override
  String get storeSetupAddonGroup => 'துணைப்பொருள் குழு';

  @override
  String get storeSetupAddons => 'துணைப்பொருட்கள்';

  @override
  String get storeSetupCashier => 'காசியர்';

  @override
  String get storeSetupCashierCreated =>
      'காசியர் உருவாக்கப்பட்டார். வெளியேறிய பிறகு இந்தக் கிளையைத் திறக்கலாம்.';

  @override
  String storeSetupCatalogueExportFailed(String message) {
    return 'பட்டியல் ஏற்றுமதி தோல்வி: $message';
  }

  @override
  String get storeSetupCategories => 'பிரிவுகள்';

  @override
  String get storeSetupCategory => 'பிரிவு';

  @override
  String get storeSetupCategoryAddedOffline =>
      'பிரிவு முதன்மை மற்றும் இந்தக் கிளையில் சேர்க்கப்பட்டது (ஆஃப்லைன்). ஏற்றுமதிக்கு ஒத்திசையுங்கள்.';

  @override
  String get storeSetupCategoryDeletedOffline =>
      'பிரிவு ஆஃப்லைனில் நீக்கப்பட்டது. ஏற்றுமதிக்கு ஒத்திசையுங்கள்.';

  @override
  String get storeSetupCategoryName => 'பிரிவு பெயர்';

  @override
  String get storeSetupChooseCategory => 'பிரிவைத் தேர்ந்தெடு';

  @override
  String get storeSetupChoosePackage => 'தொகுப்பைத் தேர்ந்தெடு';

  @override
  String get storeSetupCreate => 'உருவாக்கு';

  @override
  String get storeSetupCreateCashier => 'காசியரை உருவாக்கு';

  @override
  String get storeSetupDeleteAddonGroup => 'துணைப்பொருள் குழுவை நீக்கவா?';

  @override
  String get storeSetupDeleteOffer => 'சலுகையை நீக்கவா?';

  @override
  String get storeSetupDeletePackage => 'தொகுப்பை நீக்கவா?';

  @override
  String get storeSetupDeletedOffline =>
      'ஆஃப்லைனில் நீக்கப்பட்டது. ஏற்றுமதிக்கு ஒத்திசைக்கவும்.';

  @override
  String get storeSetupDeletedTombstone =>
      'ஆஃப்லைனில் நீக்கப்பட்டது. tombstone ஏற்றுமதிக்கு ஒத்திசையுங்கள்.';

  @override
  String get storeSetupEditAddonGroup => 'துணைப்பொருள் குழுவைத் திருத்து';

  @override
  String get storeSetupEditOffer => 'சலுகையைத் திருத்து';

  @override
  String get storeSetupEditPackage => 'தொகுப்பைத் திருத்து';

  @override
  String get storeSetupExportNotConfigured =>
      'பட்டியல் ஏற்றுமதி அமைக்கப்படவில்லை — உள்ளூர் திருத்தங்கள் இந்த டேப்லெட்டில் தங்கின.';

  @override
  String get storeSetupFirstItemName => 'முதல் பொருள் பெயர் *';

  @override
  String get storeSetupGroupName => 'குழு பெயர் *';

  @override
  String get storeSetupItemPrice => 'பொருள் விலை *';

  @override
  String get storeSetupLinkCategoryFirst => 'முதலில் ஒரு பிரிவை இணைக்கவும்';

  @override
  String get storeSetupLinkPackagesHint =>
      'முழு-பில் சலுகைக்கு காலியாக விடவும். எங்கு பொருந்தும் என்பதை வரையறுக்க தொகுப்புகளைத் தேர்ந்தெடுக்கவும்.';

  @override
  String get storeSetupLinkPackagesOptional =>
      'தொகுப்புகளுடன் இணை (விரும்பினால்)';

  @override
  String get storeSetupLinkToPackage => 'தொகுப்புடன் இணை';

  @override
  String get storeSetupLinkToPackageHint =>
      'இந்தத் துணைப்பொருள் குழுவை எந்தத் தொகுப்பு வழங்க வேண்டும் என்பதைத் தேர்ந்தெடுக்கவும்.';

  @override
  String storeSetupLinkedMaster(String name) {
    return '\"$name\" இந்த கடையுடன் இணைக்கப்பட்டது';
  }

  @override
  String storeSetupLinkedToStore(String name) {
    return '“$name” இந்தக் கிளையுடன் இணைக்கப்பட்டது';
  }

  @override
  String get storeSetupMasterCategories => 'முதன்மை பிரிவுகள்';

  @override
  String get storeSetupMasterLinked =>
      'முதன்மை இயல்புநிலை தொகுப்புடன் இணைக்கப்பட்டது. விலையைத் திருத்தி ஒத்திசையுங்கள்.';

  @override
  String get storeSetupMinBill => 'குறைந்தபட்ச பில்';

  @override
  String get storeSetupNameRequired => 'பெயர் *';

  @override
  String get storeSetupNewCategory => 'புதிய பிரிவு';

  @override
  String get storeSetupNewMasterCategory => 'புதிய முதன்மை பிரிவு';

  @override
  String get storeSetupNewOffer => 'புதிய சலுகை';

  @override
  String get storeSetupNewProduct => 'புதிய பொருள் / தொகுப்பு';

  @override
  String get storeSetupNoAddonsYet => 'இன்னும் துணைப்பொருட்கள் இல்லை';

  @override
  String get storeSetupNoCashiersYet => 'இன்னும் காசியர்கள் இல்லை';

  @override
  String get storeSetupNoMasterCategories => 'முதன்மை பிரிவுகள் இல்லை';

  @override
  String get storeSetupNoOffersEmpty => 'இன்னும் சலுகைகள் இல்லை';

  @override
  String get storeSetupNoOffersYet =>
      'இன்னும் சலுகைகள் இல்லை — Offers அமைப்பில் உருவாக்குங்கள்.';

  @override
  String get storeSetupNoPackagesCreateProducts =>
      'இன்னும் தொகுப்புகள் இல்லை — முதலில் பொருட்களை உருவாக்குங்கள்.';

  @override
  String get storeSetupNoPackagesYet => 'இன்னும் தொகுப்புகள் இல்லை';

  @override
  String get storeSetupNoPackagesYetShort => 'இன்னும் தொகுப்புகள் இல்லை.';

  @override
  String get storeSetupNoTaxUnset => 'வரி இல்லை / அமைக்கப்படவில்லை';

  @override
  String get storeSetupNoTaxesYet =>
      'இன்னும் வரிகள் இல்லை — நிறுவனம் அமைக்கப்படும்போது தானாகச் சேர்க்கப்படும்.';

  @override
  String get storeSetupNothingLinked => 'இன்னும் எதுவும் இணைக்கப்படவில்லை';

  @override
  String get storeSetupOfferDeletedOffline =>
      'சலுகை ஆஃப்லைனில் நீக்கப்பட்டது. ஏற்றுமதிக்கு ஒத்திசையுங்கள்.';

  @override
  String storeSetupOfferPctOff(String pct) {
    return '$pct% தள்ளுபடி';
  }

  @override
  String get storeSetupOfferSavedOffline => 'சலுகை ஆஃப்லைனில் சேமிக்கப்பட்டது';

  @override
  String get storeSetupOfferUpdatedOffline =>
      'சலுகை ஆஃப்லைனில் புதுப்பிக்கப்பட்டது';

  @override
  String get storeSetupOffers => 'சலுகைகள்';

  @override
  String get storeSetupOffersForPackage => 'இந்தத் தொகுப்பிற்கான சலுகைகள்';

  @override
  String get storeSetupOffersForPackageHint =>
      'இந்தத் தொகுப்பிற்குப் பொருந்தும் சலுகைகளைத் தேர்ந்தெடுக்கவும். தொகுப்பு-குறிப்பிட்ட சலுகைகள் இல்லையெனில் எதையும் விடாதீர்கள்.';

  @override
  String get storeSetupOptionalMinBill => 'விருப்ப குறைந்தபட்ச பில்';

  @override
  String get storeSetupPackage => 'தொகுப்பு';

  @override
  String get storeSetupPackageName => 'தொகுப்பு பெயர் *';

  @override
  String get storeSetupPackageNameHint => 'எ.கா. வழக்கமான, பெரிய, குடும்பம்';

  @override
  String get storeSetupPackageNamePlain => 'தொகுப்பு பெயர்';

  @override
  String get storeSetupPercentOff => 'சதவீதத் தள்ளுபடி';

  @override
  String get storeSetupProductName => 'பொருள் / சேவை பெயர் *';

  @override
  String get storeSetupProductNameHint => 'எ.கா. சிக்கன் பிரியாணி';

  @override
  String get storeSetupProductNamePlain => 'பொருள் / சேவை பெயர்';

  @override
  String get storeSetupProducts => 'பொருட்கள்';

  @override
  String get storeSetupProductsPackages => 'பொருட்கள் & தொகுப்புகள்';

  @override
  String get storeSetupRegular => 'வழக்கமான';

  @override
  String get storeSetupRemoveCategory => 'பிரிவை நீக்கவா?';

  @override
  String storeSetupRemoveEntitySync(String name) {
    return '\"$name\" ஐ அகற்று. ஏற்றுமதிக்கு ஒத்திசைக்கவும்.';
  }

  @override
  String get storeSetupRemoveFromStore => 'கிளையிலிருந்து நீக்கு';

  @override
  String get storeSetupRenameCategory => 'பிரிவை மறுபெயரிடு';

  @override
  String get storeSetupRenamedOffline =>
      'ஆஃப்லைனில் மறுபெயரிடப்பட்டது. ஏற்றுமதிக்கு ஒத்திசையுங்கள்.';

  @override
  String get storeSetupSavedOffline =>
      'ஆஃப்லைனில் சேமிக்கப்பட்டது. ஏற்றுமதிக்கு ஒத்திசைக்கவும்.';

  @override
  String get storeSetupSavedOfflineMaster =>
      'ஆஃப்லைனில் சேமிக்கப்பட்டது. master + store க்கு ஏற்றுமதி செய்ய ஒத்திசையுங்கள்.';

  @override
  String get storeSetupSellPrice => 'விற்பனை விலை *';

  @override
  String get storeSetupStoreAdmin => 'கிளை நிர்வாகி';

  @override
  String get storeSetupSyncExport => 'ஒத்திசை / ஏற்றுமதி';

  @override
  String storeSetupSyncFailed(String error) {
    return 'ஒத்திசைவு தோல்வி: $error';
  }

  @override
  String storeSetupSyncFinishedExported(int count) {
    return 'ஒத்திசைவு முடிந்தது — $count பட்டியல் வரிசை(கள்) ஏற்றுமதி செய்யப்பட்டன.';
  }

  @override
  String get storeSetupSyncFinishedNone =>
      'ஒத்திசைவு முடிந்தது — ஏற்றுமதி செய்ய நிலுவையில் உள்ள பட்டியல் மாற்றங்கள் இல்லை.';

  @override
  String get storeSetupTaxForPackage => 'இந்தத் தொகுப்பிற்கான வரி';

  @override
  String get storeSetupTaxForPackageHint =>
      'அமைப்பிலிருந்து நிறுவன வரிப் பட்டைகள். இந்தத் தொகுப்பு வரி-இல்லாததாக இருந்தால் எதையும் விடாதீர்கள்.';

  @override
  String storeSetupTaxNamePct(String name, String pct) {
    return '$name ($pct%)';
  }

  @override
  String storeSetupTaxPct(String pct) {
    return 'வரி $pct%';
  }

  @override
  String storeSetupTaxTotalPct(String pct) {
    return '$pct% மொத்தம்';
  }

  @override
  String get storeSetupThisStore => 'இந்தக் கிளை';

  @override
  String get storeSetupTitle => 'கடை அமைப்பு';

  @override
  String get storeSetupUnit => 'அலகு *';

  @override
  String get storeSetupUnitHint => 'pcs, kg…';

  @override
  String get storeSetupUnitQty => 'அலகு அளவு *';

  @override
  String get storeSetupUpdatedOffline =>
      'ஆஃப்லைனில் புதுப்பிக்கப்பட்டது. ஏற்றுமதிக்கு ஒத்திசைக்கவும்.';

  @override
  String get syncAgain => 'மீண்டும் ஒத்திசை';

  @override
  String get syncComplete => 'ஒத்திசைவு முடிந்தது';

  @override
  String get syncDataSync => 'தரவு ஒத்திசைவு';

  @override
  String get syncDescription =>
      'இந்த சாதனத்திலிருந்து POS வாடிக்கையாளர்கள், ஆர்டர்கள் மற்றும் கடன்களை முதலில் பதிவேற்றி, பின்னர் பட்டியல் புதுப்பிப்புகளைப் பதிவிறக்கும். ஆஃப்லைன் விற்பனை அடுத்த வெற்றிகரமான ஒத்திசைவு வரை உள்ளூரில் இருக்கும்.';

  @override
  String get syncDownloadFromRemote => 'ரிமோட்டிலிருந்து பதிவிறக்கு';

  @override
  String get syncHistory => 'வரலாறு';

  @override
  String get syncHistory45 => 'ஒத்திசைவு வரலாறு (கடைசி 45 நாட்கள்)';

  @override
  String syncHistoryStats(int processed, int success, int failed) {
    return '$processed செயலாக்கப்பட்டது · $success சரி · $failed தோல்வி';
  }

  @override
  String get syncInProgress => 'ஒத்திசைவு நடைபெறுகிறது…';

  @override
  String syncLastSync(String timestamp) {
    return 'கடைசி ஒத்திசை: $timestamp';
  }

  @override
  String syncNamedStoreWithRemote(String storeName) {
    return '“$storeName” ஐ ரிமோட்டுடன் ஒத்திசை';
  }

  @override
  String get syncNeverSynced => 'ஒருபோதும் ஒத்திசைக்கப்படவில்லை';

  @override
  String get syncNoAttemptsYet =>
      'இந்தச் சாதனத்தில் இன்னும் ஒத்திசைவு முயற்சிகள் பதிவுசெய்யப்படவில்லை.';

  @override
  String get syncNoHistory =>
      'இந்த சாதனத்தில் இன்னும் ஒத்திசை முயற்சிகள் இல்லை. வரலாற்றை நிரப்ப ஒத்திசை செய்யவும்.';

  @override
  String get syncOfflineWhenOnline => 'ஆஃப்லைன் — ஆன்லைனில் ஒத்திசையுங்கள்';

  @override
  String get syncRunning => 'இயங்குகிறது';

  @override
  String get syncServerUnreachable =>
      'சர்வர் அணுக முடியவில்லை. ஆஃப்லைனில் விற்பனையைத் தொடருங்கள் — நிலுவைப் பதிவேற்றங்கள் ஒத்திசைக்கும் வரை இந்தச் சாதனத்தில் வரிசையில் இருக்கும்';

  @override
  String get syncStart => 'ஒத்திசையைத் தொடங்கு';

  @override
  String get syncStoreWithRemote => 'கிளைத் தரவை ரிமோட்டுடன் ஒத்திசை';

  @override
  String get syncSyncing => 'ஒத்திசைக்கிறது…';

  @override
  String get syncTitle => 'ஒத்திசை';

  @override
  String get syncUploadToRemote => 'ரிமோட்டுக்குப் பதிவேற்று';

  @override
  String get unsupportedDeviceDesc =>
      'EllanPos குறிப்பாக டேப்லெட்டுகள் மற்றும் பெரிய திரைகளுக்காக வடிவமைக்கப்பட்டுள்ளது.\n\nதயவுசெய்து ஐபாட் அல்லது ஆண்ட்ராய்டு டேப்லெட்டிலிருந்து போர்ட்ரெய்ட் அல்லாமல் லேண்ட்ஸ்கேப்பில் பயன்படுத்தவும்.';

  @override
  String get unsupportedDeviceTitle => 'சாதனம் ஆதரிக்கப்படவில்லை';

  @override
  String get welcomeAlreadySetupSignIn => 'ஏற்கனவே அமைக்கப்பட்டதா? உள்நுழைக';

  @override
  String get welcomeAuthPrompt =>
      'கட்டணப் பரிமாற்றங்களை எளிதாகத் தொடங்க உங்கள் கணக்கில் உள்நுழைக அல்லது புதிதாக ஒன்றை உருவாக்கவும்.';

  @override
  String get welcomeChooseSavedServer => 'சேமித்த சேவையகத்தைத் தேர்வுசெய்க';

  @override
  String get welcomeCreateCompanyInstead =>
      'அதற்குப் பதிலாக புதிய நிறுவனம் உருவாக்கு';

  @override
  String get welcomeDeleteFromList => 'பட்டியலிலிருந்து நீக்கு';

  @override
  String get welcomeDeleteSavedServer => 'சேமித்த சேவையகத்தை நீக்கு';

  @override
  String get welcomeDescription =>
      'EllanPos நவீன பணிப்பாய்வுகளுக்காக வடிவமைக்கப்பட்ட ஒரு சிறப்பான டேப்லெட் அனுபவத்தை வழங்குகிறது.';

  @override
  String get welcomeEnterOrg => 'உங்கள் நிறுவனத்தின் பெயரை உள்ளிடவும்';

  @override
  String get welcomeEnterOrgCode => 'உங்கள் நிறுவனக் குறியீட்டை உள்ளிடவும்';

  @override
  String get welcomeGetStarted => 'தொடங்குவோம்';

  @override
  String get welcomeOrgCodeHint => 'எ.கா., 100001';

  @override
  String get welcomeOrgHint => 'எ.கா. ஆக்மே நிறுவனம்';

  @override
  String get welcomeOrgInstanceId => 'நிறுவன அடையாளம்';

  @override
  String get welcomeRegisterDevice => 'சாதனத்தைப் பதிவு செய்';

  @override
  String get welcomeRegisterHint => 'தொடர இந்த டேப்லெட்டைப் பதிவு செய்யவும்.';

  @override
  String get welcomeRegisterHintManual =>
      'இந்த சாதனத்தைப் பதிவு செய்வதற்கு முன் சேவையக URL மற்றும் நிறுவன அடையாளத்தை உள்ளிடவும்.';

  @override
  String welcomeRemoveServerConfirm(String label) {
    return 'இந்த சாதனத்திலிருந்து \"$label\" ஐ அகற்றவா?';
  }

  @override
  String get welcomeSavedServers => 'சேமித்த சேவையகங்கள்';

  @override
  String get welcomeServerUrl => 'சேவையக URL';

  @override
  String get welcomeServerUrlHint => 'எ.கா. http://192.168.1.10:8000';

  @override
  String get welcomeSubmit => 'சமர்ப்பி';

  @override
  String get welcomeUnlockBusiness => 'உங்கள் வணிக\nதிறனைத் திறக்கவும்';

  @override
  String get signInSwitchCompany => 'நிறுவனத்தை மாற்று';

  @override
  String get signInSwitchCompanyTitle => 'நிறுவனத்தை மாற்றவா?';

  @override
  String get signInSwitchCompanyBody =>
      'நிறுவனத்தை மாற்றினால் இந்த சாதனம் மீட்டமைக்கப்படும். உள்ளூர் ஆர்டர்கள், பட்டியல், வாடிக்கையாளர்கள், ஒத்திசை வரலாறு மற்றும் சாதன அமைப்புகள் நிரந்தரமாக நீக்கப்படும் — இன்னும் ஒத்திசைக்கப்படாத ஆர்டர்களும் இதில் அடங்கும். சேவையகத்தில் எதுவும் நீக்கப்படாது.';

  @override
  String get signInSwitchCompanyAction => 'மாற்றி மீட்டமை';

  @override
  String get supportTitle => 'வாடிக்கையாளர் உதவி';

  @override
  String get supportSubtitle => 'உங்கள் POS-க்கு உதவ நாங்கள் இருக்கிறோம்.';

  @override
  String get supportEmail => 'மின்னஞ்சல்';

  @override
  String get supportWhatsapp => 'வாட்ஸ்அப்';

  @override
  String get supportDeviceId => 'சாதன ஐடி';

  @override
  String get supportCompany => 'நிறுவனம்';

  @override
  String get supportShareHint =>
      'உதவியைத் தொடர்பு கொள்ளும்போது இந்த விவரங்களைப் பகிருங்கள்.';

  @override
  String get supportNotConfigured =>
      'உதவி தொடர்பு விவரங்கள் இன்னும் அமைக்கப்படவில்லை. உங்கள் நிர்வாகியிடம் கேளுங்கள்.';

  @override
  String supportCopied(String value) {
    return '$value நகலெடுக்கப்பட்டது';
  }

  @override
  String get supportEmailAction => 'மின்னஞ்சல்';

  @override
  String get supportWhatsappAction => 'அரட்டை';

  @override
  String get homeLock => 'திரையைப் பூட்டு';

  @override
  String get lockEnterPin => 'திறக்க உங்கள் பின்னை உள்ளிடுங்கள்';

  @override
  String lockEnterPinAt(String storeName) {
    return '$storeName திறக்க உங்கள் பின்னை உள்ளிடுங்கள்';
  }

  @override
  String get lockSignedOutTitle => 'வெளியேறிவிட்டீர்கள்';

  @override
  String get lockSignedOutBody =>
      'இந்தப் பதிவேட்டைப் பயன்படுத்த ஆன்லைனில் உள்நுழையுங்கள்.';

  @override
  String get lockSignIn => 'உள்நுழை';

  @override
  String get lockSignInInstead =>
      'உள்நுழை (புதிய பணியாளர் அல்லது பின் மறந்தது)';

  @override
  String lockWrongPin(int remaining) {
    return 'தவறான பின். இன்னும் $remaining முயற்சிகள்.';
  }

  @override
  String get lockTooManyAttempts => 'பல தவறான பின்கள். உள்நுழையுங்கள்.';

  @override
  String get lockLeaseExpired =>
      'சாதன உள்நுழைவு காலாவதியானது. ஆன்லைனில் உள்நுழையுங்கள்.';

  @override
  String get pinCreateTitle => 'உங்கள் பின்னை உருவாக்குங்கள்';

  @override
  String get pinConfirmTitle => 'உங்கள் பின்னை உறுதிப்படுத்துங்கள்';

  @override
  String pinCreateBody(int length) {
    return 'இந்தப் பதிவேட்டை விரைவாகத் திறக்க $length இலக்க பின்னைத் தேர்ந்தெடுங்கள்.';
  }

  @override
  String get pinMismatch => 'பின்கள் பொருந்தவில்லை. மீண்டும் முயலுங்கள்.';

  @override
  String get lockChooseStaff => 'பதிவேட்டைப் பயன்படுத்துபவர் யார்?';

  @override
  String lockNoStoreAccess(String name) {
    return '$name இந்தக் கடையைப் பயன்படுத்த முடியாது. உள்நுழையுங்கள்.';
  }

  @override
  String get storeTradeTitle => 'வாங்குதல் & விற்பனை';

  @override
  String get storeTradeBody =>
      'இந்தக் கடை என்ன செய்கிறது என்பதைத் தேர்ந்தெடுங்கள். இரண்டையும் தேர்ந்தெடுக்கலாம். இந்தச் சாதனத்தில் உடனே சேமிக்கப்படும்.';

  @override
  String get storeTradeSell => 'விற்பனை';

  @override
  String get storeTradeSellHint => 'வாடிக்கையாளர்களுக்கு விற்பனை';

  @override
  String get storeTradeBuy => 'கொள்முதல்';

  @override
  String get storeTradeBuyHint => 'சப்ளையர்களிடமிருந்து கொள்முதல்';

  @override
  String get storeTradeNeedOne =>
      'வாங்குதல் அல்லது விற்பனையில் குறைந்தது ஒன்றைத் தேர்ந்தெடுங்கள்.';

  @override
  String get orderListAllTables => 'அனைத்து மேசைகள்';

  @override
  String orderListTableChip(String name) {
    return 'மேசை $name';
  }

  @override
  String get orderListNoTables =>
      'இன்னும் மேசைகள் இல்லை. டைன்-இன் ஆர்டர்கள் பயன்படுத்தியதும் இங்கே தோன்றும்.';

  @override
  String get orderListPeriodAll => 'எல்லா நேரமும்';

  @override
  String get orderListPeriodToday => 'இன்று';

  @override
  String get orderListPeriodLast24h => 'கடந்த 24 மணி';

  @override
  String get orderListPeriodYesterday => 'நேற்று';

  @override
  String get orderListPeriodCustom => 'தனிப்பயன்…';

  @override
  String get orderListPeriodTooltip => 'தேதி வாரியாக வடிகட்டு';

  @override
  String get dashboardPending => 'நிலுவை';

  @override
  String dashboardPendingOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ஆர்டர்கள்',
      one: '1 ஆர்டர்',
    );
    return '$_temp0';
  }
}
