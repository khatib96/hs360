import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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
    Locale('ar'),
    Locale('en'),
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'HS360'**
  String get appTitle;

  /// Dashboard screen title
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// Phase 2 status message on dashboard
  ///
  /// In en, this message translates to:
  /// **'Phase 2 active — authentication, permissions, and routing are ready. Modules arrive in Phase 3.'**
  String get dashboardPhase2Subtitle;

  /// Session summary display name label
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get sessionDisplayNameLabel;

  /// Session summary account type label
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get sessionAccountTypeLabel;

  /// Session summary email label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get sessionEmailLabel;

  /// Session summary tenant id label
  ///
  /// In en, this message translates to:
  /// **'Tenant ID'**
  String get sessionTenantLabel;

  /// Manager account type
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get accountTypeManager;

  /// User account type
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get accountTypeUser;

  /// Language switcher label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Login screen title
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// Login screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Enter your account details to continue'**
  String get loginSubtitle;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Sign in button
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// Link to forgot password screen
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// Forgot password submit button
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// Return to login from forgot password
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToLogin;

  /// Logout action
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// Loading state label
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// Button label for loading the next page of list results
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// Retry action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Password visibility toggle show
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// Password visibility toggle hide
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// Email required validation
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get validationEmailRequired;

  /// Email format validation
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get validationEmailInvalid;

  /// Password required validation
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get validationPasswordRequired;

  /// Invalid login credentials
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get authErrorInvalidCredentials;

  /// Network unavailable
  ///
  /// In en, this message translates to:
  /// **'Could not connect. Check your network or local Supabase'**
  String get authErrorNetworkUnavailable;

  /// No tenant user
  ///
  /// In en, this message translates to:
  /// **'No active tenant account is linked to this user'**
  String get authErrorNoActiveTenantUser;

  /// Inactive user
  ///
  /// In en, this message translates to:
  /// **'This user account is inactive'**
  String get authErrorUserInactive;

  /// Supabase not configured
  ///
  /// In en, this message translates to:
  /// **'Supabase is not configured'**
  String get authErrorSupabaseNotConfigured;

  /// Unknown auth error
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again'**
  String get authErrorUnknown;

  /// Missing anon key banner
  ///
  /// In en, this message translates to:
  /// **'Local Supabase key is missing. Run the app via scripts/run-local.ps1'**
  String get authMissingAnonKey;

  /// Supabase init failed banner
  ///
  /// In en, this message translates to:
  /// **'Could not initialize Supabase. Check that local services are running'**
  String get authInitFailed;

  /// Password reset request success message
  ///
  /// In en, this message translates to:
  /// **'If the email is registered, password reset instructions will be sent.'**
  String get resetPasswordSuccess;

  /// Forgot password screen title
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get forgotPasswordTitle;

  /// Forgot password screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we will send reset instructions if the account exists'**
  String get forgotPasswordSubtitle;

  /// Field today screen title
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get fieldTodayTitle;

  /// Field today placeholder body
  ///
  /// In en, this message translates to:
  /// **'Assigned visits will appear here in a later phase.'**
  String get fieldTodayPlaceholder;

  /// Blocked screen title
  ///
  /// In en, this message translates to:
  /// **'No access'**
  String get blockedTitle;

  /// Blocked screen message
  ///
  /// In en, this message translates to:
  /// **'Your account has no assigned permissions. Contact your manager for access.'**
  String get blockedMessage;

  /// Products menu/screen title
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// New product screen title
  ///
  /// In en, this message translates to:
  /// **'New Product'**
  String get productsNew;

  /// Product details screen title
  ///
  /// In en, this message translates to:
  /// **'Product Details'**
  String get productsDetail;

  /// Warehouses menu/screen title
  ///
  /// In en, this message translates to:
  /// **'Warehouses'**
  String get warehouses;

  /// No description provided for @warehouseAdd.
  ///
  /// In en, this message translates to:
  /// **'Add warehouse'**
  String get warehouseAdd;

  /// No description provided for @warehouseEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit warehouse'**
  String get warehouseEdit;

  /// No description provided for @warehouseDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate warehouse'**
  String get warehouseDeactivate;

  /// No description provided for @warehouseDeactivateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Deactivate this warehouse? It will no longer appear in stock movement choices.'**
  String get warehouseDeactivateConfirm;

  /// No description provided for @warehouseNameAr.
  ///
  /// In en, this message translates to:
  /// **'Arabic name'**
  String get warehouseNameAr;

  /// No description provided for @warehouseNameEn.
  ///
  /// In en, this message translates to:
  /// **'English name'**
  String get warehouseNameEn;

  /// No description provided for @warehouseType.
  ///
  /// In en, this message translates to:
  /// **'Warehouse type'**
  String get warehouseType;

  /// No description provided for @warehouseTypeMain.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get warehouseTypeMain;

  /// No description provided for @warehouseTypeBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get warehouseTypeBranch;

  /// No description provided for @warehouseTypeVan.
  ///
  /// In en, this message translates to:
  /// **'Van'**
  String get warehouseTypeVan;

  /// No description provided for @warehouseEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get warehouseEmployee;

  /// No description provided for @warehouseEmployeeNone.
  ///
  /// In en, this message translates to:
  /// **'Select employee'**
  String get warehouseEmployeeNone;

  /// No description provided for @warehouseEmployeeInactiveHint.
  ///
  /// In en, this message translates to:
  /// **'Inactive employee'**
  String get warehouseEmployeeInactiveHint;

  /// No description provided for @warehouseLocationAddress.
  ///
  /// In en, this message translates to:
  /// **'Location address'**
  String get warehouseLocationAddress;

  /// No description provided for @warehouseActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get warehouseActive;

  /// No description provided for @warehouseInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get warehouseInactive;

  /// No description provided for @warehouseColumnName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get warehouseColumnName;

  /// No description provided for @warehouseColumnType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get warehouseColumnType;

  /// No description provided for @warehouseColumnEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get warehouseColumnEmployee;

  /// No description provided for @warehouseColumnAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get warehouseColumnAddress;

  /// No description provided for @warehouseColumnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get warehouseColumnStatus;

  /// No description provided for @warehouseListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No warehouses yet.'**
  String get warehouseListEmpty;

  /// No description provided for @warehouseListError.
  ///
  /// In en, this message translates to:
  /// **'Could not load warehouses. Try again.'**
  String get warehouseListError;

  /// No description provided for @warehouseValidationAgentRequired.
  ///
  /// In en, this message translates to:
  /// **'Select an employee for van warehouses'**
  String get warehouseValidationAgentRequired;

  /// No description provided for @warehouseErrorDuplicateActiveVan.
  ///
  /// In en, this message translates to:
  /// **'This employee already has an active van warehouse'**
  String get warehouseErrorDuplicateActiveVan;

  /// No description provided for @warehouseErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get warehouseErrorUnknown;

  /// No description provided for @warehouseEmployeeLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load employees for van assignment. Van warehouses may be limited until this is fixed.'**
  String get warehouseEmployeeLookupFailed;

  /// No description provided for @warehouseEmployeeLookupRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry employee lookup'**
  String get warehouseEmployeeLookupRetry;

  /// Inventory balances screen title
  ///
  /// In en, this message translates to:
  /// **'Inventory Balances'**
  String get inventory;

  /// No description provided for @inventoryBalancesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stock balances yet.'**
  String get inventoryBalancesEmpty;

  /// No description provided for @inventoryBalancesError.
  ///
  /// In en, this message translates to:
  /// **'Could not load inventory balances. Try again.'**
  String get inventoryBalancesError;

  /// No description provided for @inventoryBalancesProductLabelsFailed.
  ///
  /// In en, this message translates to:
  /// **'Product names could not be loaded. Balances are shown with limited labels.'**
  String get inventoryBalancesProductLabelsFailed;

  /// No description provided for @inventoryBalancesWarehouseLabelsFailed.
  ///
  /// In en, this message translates to:
  /// **'Warehouse names could not be loaded. Balances are shown with limited labels.'**
  String get inventoryBalancesWarehouseLabelsFailed;

  /// No description provided for @inventoryBalanceNameUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get inventoryBalanceNameUnavailable;

  /// No description provided for @inventoryBalanceProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get inventoryBalanceProduct;

  /// No description provided for @inventoryBalanceWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get inventoryBalanceWarehouse;

  /// No description provided for @inventoryBalanceAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get inventoryBalanceAvailable;

  /// No description provided for @inventoryBalanceRented.
  ///
  /// In en, this message translates to:
  /// **'Rented'**
  String get inventoryBalanceRented;

  /// No description provided for @inventoryBalanceTrial.
  ///
  /// In en, this message translates to:
  /// **'Trial'**
  String get inventoryBalanceTrial;

  /// No description provided for @inventoryBalanceMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get inventoryBalanceMaintenance;

  /// No description provided for @inventoryBalanceDamaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get inventoryBalanceDamaged;

  /// No description provided for @inventoryBalancesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search product or warehouse'**
  String get inventoryBalancesSearchHint;

  /// No description provided for @inventoryBalancesFilterWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get inventoryBalancesFilterWarehouse;

  /// No description provided for @inventoryBalancesFilterWarehouseAll.
  ///
  /// In en, this message translates to:
  /// **'All warehouses'**
  String get inventoryBalancesFilterWarehouseAll;

  /// No description provided for @inventoryBalancesFilterLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low stock only'**
  String get inventoryBalancesFilterLowStock;

  /// No description provided for @inventoryBalancesSummaryTotal.
  ///
  /// In en, this message translates to:
  /// **'Filtered totals'**
  String get inventoryBalancesSummaryTotal;

  /// No description provided for @inventoryErrorInsufficientStock.
  ///
  /// In en, this message translates to:
  /// **'Insufficient stock for this operation.'**
  String get inventoryErrorInsufficientStock;

  /// No description provided for @inventoryErrorSerializedAdjustmentNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Bulk quantity adjustments are not supported for serialized products. Use product units instead.'**
  String get inventoryErrorSerializedAdjustmentNotSupported;

  /// No description provided for @inventoryManualAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Manual adjustment'**
  String get inventoryManualAdjustment;

  /// No description provided for @inventoryAdjustmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual stock adjustment'**
  String get inventoryAdjustmentTitle;

  /// No description provided for @inventoryAdjustmentNotes.
  ///
  /// In en, this message translates to:
  /// **'Reason / notes'**
  String get inventoryAdjustmentNotes;

  /// No description provided for @inventoryAdjustmentQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get inventoryAdjustmentQuantity;

  /// No description provided for @inventoryAdjustmentUnitCost.
  ///
  /// In en, this message translates to:
  /// **'Unit cost'**
  String get inventoryAdjustmentUnitCost;

  /// No description provided for @inventoryAdjustmentPreviewDelta.
  ///
  /// In en, this message translates to:
  /// **'Available change'**
  String get inventoryAdjustmentPreviewDelta;

  /// No description provided for @inventoryAdjustmentPreviewWac.
  ///
  /// In en, this message translates to:
  /// **'Estimated average cost after stock-in'**
  String get inventoryAdjustmentPreviewWac;

  /// No description provided for @inventoryAdjustmentStockInRequiresCost.
  ///
  /// In en, this message translates to:
  /// **'Stock-in requires full product cost permissions.'**
  String get inventoryAdjustmentStockInRequiresCost;

  /// No description provided for @inventoryAdjustmentProductsViewRequired.
  ///
  /// In en, this message translates to:
  /// **'Product search requires products.view permission.'**
  String get inventoryAdjustmentProductsViewRequired;

  /// No description provided for @inventoryAdjustmentWarehouseRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a warehouse.'**
  String get inventoryAdjustmentWarehouseRequired;

  /// No description provided for @inventoryAdjustmentProductRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a product.'**
  String get inventoryAdjustmentProductRequired;

  /// No description provided for @inventoryAdjustmentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Inventory adjustment recorded.'**
  String get inventoryAdjustmentSuccess;

  /// No description provided for @inventoryTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock transfer'**
  String get inventoryTransferTitle;

  /// No description provided for @inventoryTransferSourceWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Source warehouse'**
  String get inventoryTransferSourceWarehouse;

  /// No description provided for @inventoryTransferDestinationWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Destination warehouse'**
  String get inventoryTransferDestinationWarehouse;

  /// No description provided for @inventoryTransferQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get inventoryTransferQuantity;

  /// No description provided for @inventoryTransferNotes.
  ///
  /// In en, this message translates to:
  /// **'Reason / notes'**
  String get inventoryTransferNotes;

  /// No description provided for @inventoryTransferSelectProduct.
  ///
  /// In en, this message translates to:
  /// **'Search product by name or SKU'**
  String get inventoryTransferSelectProduct;

  /// No description provided for @inventoryTransferPreviewSource.
  ///
  /// In en, this message translates to:
  /// **'Source change'**
  String get inventoryTransferPreviewSource;

  /// No description provided for @inventoryTransferPreviewDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination change'**
  String get inventoryTransferPreviewDestination;

  /// No description provided for @inventoryTransferSameWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Source and destination must be different warehouses.'**
  String get inventoryTransferSameWarehouse;

  /// No description provided for @inventoryTransferSuccess.
  ///
  /// In en, this message translates to:
  /// **'Stock transfer recorded.'**
  String get inventoryTransferSuccess;

  /// No description provided for @inventorySourceWarehouseRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a source warehouse.'**
  String get inventorySourceWarehouseRequired;

  /// No description provided for @inventoryDestinationWarehouseRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a destination warehouse.'**
  String get inventoryDestinationWarehouseRequired;

  /// No description provided for @inventoryErrorSerializedTransferNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Stock transfers are not supported for serialized products.'**
  String get inventoryErrorSerializedTransferNotSupported;

  /// No description provided for @inventoryAdjustmentSelectProduct.
  ///
  /// In en, this message translates to:
  /// **'Search product by name or SKU'**
  String get inventoryAdjustmentSelectProduct;

  /// No description provided for @inventoryAdjustmentMovementType.
  ///
  /// In en, this message translates to:
  /// **'Movement type'**
  String get inventoryAdjustmentMovementType;

  /// No description provided for @productDetailStockByWarehouse.
  ///
  /// In en, this message translates to:
  /// **'By warehouse'**
  String get productDetailStockByWarehouse;

  /// No description provided for @productDetailStockLowWarning.
  ///
  /// In en, this message translates to:
  /// **'Available stock is at or below the reorder point.'**
  String get productDetailStockLowWarning;

  /// Inventory movements log screen title
  ///
  /// In en, this message translates to:
  /// **'Movements Log'**
  String get inventoryMovements;

  /// Inventory transfers screen title
  ///
  /// In en, this message translates to:
  /// **'Stock Transfers'**
  String get inventoryTransfers;

  /// No description provided for @inventoryMovementsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No inventory movements match your filters.'**
  String get inventoryMovementsEmpty;

  /// No description provided for @inventoryMovementsError.
  ///
  /// In en, this message translates to:
  /// **'Could not load inventory movements. Try again.'**
  String get inventoryMovementsError;

  /// No description provided for @inventoryMovementsProductLabelsFailed.
  ///
  /// In en, this message translates to:
  /// **'Product names could not be loaded. Movements are shown with limited labels.'**
  String get inventoryMovementsProductLabelsFailed;

  /// No description provided for @inventoryMovementsWarehouseLabelsFailed.
  ///
  /// In en, this message translates to:
  /// **'Warehouse names could not be loaded. Movements are shown with limited labels.'**
  String get inventoryMovementsWarehouseLabelsFailed;

  /// No description provided for @inventoryMovementsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search product name or SKU'**
  String get inventoryMovementsSearchHint;

  /// No description provided for @inventoryMovementsSearchRequiresProducts.
  ///
  /// In en, this message translates to:
  /// **'Product name or SKU search requires products.view permission. You can still search by movement IDs and notes.'**
  String get inventoryMovementsSearchRequiresProducts;

  /// No description provided for @inventoryMovementsFilterWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get inventoryMovementsFilterWarehouse;

  /// No description provided for @inventoryMovementsFilterWarehouseAll.
  ///
  /// In en, this message translates to:
  /// **'All warehouses'**
  String get inventoryMovementsFilterWarehouseAll;

  /// No description provided for @inventoryMovementsFilterMovementType.
  ///
  /// In en, this message translates to:
  /// **'Movement type'**
  String get inventoryMovementsFilterMovementType;

  /// No description provided for @inventoryMovementsFilterMovementTypeAll.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get inventoryMovementsFilterMovementTypeAll;

  /// No description provided for @inventoryMovementsFilterDateFrom.
  ///
  /// In en, this message translates to:
  /// **'From date'**
  String get inventoryMovementsFilterDateFrom;

  /// No description provided for @inventoryMovementsFilterDateTo.
  ///
  /// In en, this message translates to:
  /// **'To date'**
  String get inventoryMovementsFilterDateTo;

  /// No description provided for @inventoryMovementsFilterPageSize.
  ///
  /// In en, this message translates to:
  /// **'Page size'**
  String get inventoryMovementsFilterPageSize;

  /// No description provided for @inventoryMovementOccurredAt.
  ///
  /// In en, this message translates to:
  /// **'Occurred'**
  String get inventoryMovementOccurredAt;

  /// No description provided for @inventoryMovementType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get inventoryMovementType;

  /// No description provided for @inventoryMovementProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get inventoryMovementProduct;

  /// No description provided for @inventoryMovementWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get inventoryMovementWarehouse;

  /// No description provided for @inventoryMovementQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get inventoryMovementQuantity;

  /// No description provided for @inventoryMovementReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get inventoryMovementReference;

  /// No description provided for @inventoryMovementCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get inventoryMovementCreatedBy;

  /// No description provided for @inventoryMovementNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get inventoryMovementNotes;

  /// No description provided for @inventoryMovementUnitCost.
  ///
  /// In en, this message translates to:
  /// **'Unit cost'**
  String get inventoryMovementUnitCost;

  /// No description provided for @inventoryMovementNotesNone.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get inventoryMovementNotesNone;

  /// No description provided for @inventoryMovementReferenceNone.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get inventoryMovementReferenceNone;

  /// No description provided for @inventoryMovementCreatedByNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get inventoryMovementCreatedByNotRecorded;

  /// No description provided for @inventoryMovementReferenceAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get inventoryMovementReferenceAdjustment;

  /// No description provided for @inventoryMovementReferenceTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get inventoryMovementReferenceTransfer;

  /// No description provided for @inventoryMovementReferenceProductUnit.
  ///
  /// In en, this message translates to:
  /// **'Product unit'**
  String get inventoryMovementReferenceProductUnit;

  /// No description provided for @inventoryMovementTypePurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get inventoryMovementTypePurchase;

  /// No description provided for @inventoryMovementTypeSale.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get inventoryMovementTypeSale;

  /// No description provided for @inventoryMovementTypeRentalOut.
  ///
  /// In en, this message translates to:
  /// **'Rental out'**
  String get inventoryMovementTypeRentalOut;

  /// No description provided for @inventoryMovementTypeRentalReturn.
  ///
  /// In en, this message translates to:
  /// **'Rental return'**
  String get inventoryMovementTypeRentalReturn;

  /// No description provided for @inventoryMovementTypeRefill.
  ///
  /// In en, this message translates to:
  /// **'Refill'**
  String get inventoryMovementTypeRefill;

  /// No description provided for @inventoryMovementTypeTransferOut.
  ///
  /// In en, this message translates to:
  /// **'Transfer out'**
  String get inventoryMovementTypeTransferOut;

  /// No description provided for @inventoryMovementTypeTransferIn.
  ///
  /// In en, this message translates to:
  /// **'Transfer in'**
  String get inventoryMovementTypeTransferIn;

  /// No description provided for @inventoryMovementTypeAdjustmentIn.
  ///
  /// In en, this message translates to:
  /// **'Adjustment in'**
  String get inventoryMovementTypeAdjustmentIn;

  /// No description provided for @inventoryMovementTypeAdjustmentOut.
  ///
  /// In en, this message translates to:
  /// **'Adjustment out'**
  String get inventoryMovementTypeAdjustmentOut;

  /// No description provided for @inventoryMovementTypeSaleReturn.
  ///
  /// In en, this message translates to:
  /// **'Sale return'**
  String get inventoryMovementTypeSaleReturn;

  /// No description provided for @inventoryMovementTypePurchaseReturn.
  ///
  /// In en, this message translates to:
  /// **'Purchase return'**
  String get inventoryMovementTypePurchaseReturn;

  /// No description provided for @inventoryMovementTypeMaintenanceIn.
  ///
  /// In en, this message translates to:
  /// **'Maintenance in'**
  String get inventoryMovementTypeMaintenanceIn;

  /// No description provided for @inventoryMovementTypeMaintenanceOut.
  ///
  /// In en, this message translates to:
  /// **'Maintenance out'**
  String get inventoryMovementTypeMaintenanceOut;

  /// No description provided for @productsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search SKU, name, or barcode'**
  String get productsSearchHint;

  /// No description provided for @productsListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No products match your filters.'**
  String get productsListEmpty;

  /// No description provided for @productsListError.
  ///
  /// In en, this message translates to:
  /// **'Could not load products. Try again.'**
  String get productsListError;

  /// No description provided for @productsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get productsNotAvailable;

  /// No description provided for @productsGroupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get productsGroupUnavailable;

  /// No description provided for @productsAllGroups.
  ///
  /// In en, this message translates to:
  /// **'All products'**
  String get productsAllGroups;

  /// No description provided for @productsFilterType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get productsFilterType;

  /// No description provided for @productsFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get productsFilterActive;

  /// No description provided for @productsFilterStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get productsFilterStock;

  /// No description provided for @productsFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get productsFilterClear;

  /// No description provided for @productsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get productsFilterAll;

  /// No description provided for @productsFilterActiveOnly.
  ///
  /// In en, this message translates to:
  /// **'Active only'**
  String get productsFilterActiveOnly;

  /// No description provided for @productsFilterInactiveOnly.
  ///
  /// In en, this message translates to:
  /// **'Inactive only'**
  String get productsFilterInactiveOnly;

  /// No description provided for @productTypeSaleOnly.
  ///
  /// In en, this message translates to:
  /// **'Sale only'**
  String get productTypeSaleOnly;

  /// No description provided for @productTypeAssetRental.
  ///
  /// In en, this message translates to:
  /// **'Asset rental'**
  String get productTypeAssetRental;

  /// No description provided for @productTypeConsumableRental.
  ///
  /// In en, this message translates to:
  /// **'Consumable rental'**
  String get productTypeConsumableRental;

  /// No description provided for @productModeSale.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get productModeSale;

  /// No description provided for @productModeRental.
  ///
  /// In en, this message translates to:
  /// **'Rental'**
  String get productModeRental;

  /// No description provided for @productRentalTypeAsset.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get productRentalTypeAsset;

  /// No description provided for @productRentalTypeConsumable.
  ///
  /// In en, this message translates to:
  /// **'Consumable'**
  String get productRentalTypeConsumable;

  /// No description provided for @productStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get productStatusActive;

  /// No description provided for @productStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get productStatusInactive;

  /// No description provided for @productStockIn.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get productStockIn;

  /// No description provided for @productStockOut.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get productStockOut;

  /// No description provided for @productStockLow.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get productStockLow;

  /// No description provided for @productColumnSku.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get productColumnSku;

  /// No description provided for @productColumnName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get productColumnName;

  /// No description provided for @productColumnGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get productColumnGroup;

  /// No description provided for @productColumnType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get productColumnType;

  /// No description provided for @productColumnSalePrice.
  ///
  /// In en, this message translates to:
  /// **'Sale price'**
  String get productColumnSalePrice;

  /// No description provided for @productColumnStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get productColumnStock;

  /// No description provided for @productColumnActive.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get productColumnActive;

  /// No description provided for @productColumnAvgCost.
  ///
  /// In en, this message translates to:
  /// **'Avg cost'**
  String get productColumnAvgCost;

  /// No description provided for @productColumnLastPurchaseCost.
  ///
  /// In en, this message translates to:
  /// **'Last purchase'**
  String get productColumnLastPurchaseCost;

  /// No description provided for @productColumnMinSalePrice.
  ///
  /// In en, this message translates to:
  /// **'Min sale price'**
  String get productColumnMinSalePrice;

  /// No description provided for @productGroupAdd.
  ///
  /// In en, this message translates to:
  /// **'Add group'**
  String get productGroupAdd;

  /// No description provided for @productGroupEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get productGroupEdit;

  /// No description provided for @productGroupDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate group'**
  String get productGroupDeactivate;

  /// No description provided for @productGroupDeactivateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Deactivate this product group?'**
  String get productGroupDeactivateConfirm;

  /// No description provided for @productGroupNameAr.
  ///
  /// In en, this message translates to:
  /// **'Arabic name'**
  String get productGroupNameAr;

  /// No description provided for @productGroupNameEn.
  ///
  /// In en, this message translates to:
  /// **'English name'**
  String get productGroupNameEn;

  /// No description provided for @productGroupParent.
  ///
  /// In en, this message translates to:
  /// **'Parent group'**
  String get productGroupParent;

  /// No description provided for @productGroupActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get productGroupActive;

  /// No description provided for @productGroupNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get productGroupNone;

  /// No description provided for @productGroupValidationNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter Arabic and English names'**
  String get productGroupValidationNameRequired;

  /// No description provided for @productsGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Product groups'**
  String get productsGroupsTitle;

  /// No description provided for @productsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get productsEdit;

  /// No description provided for @productEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get productEditAction;

  /// No description provided for @productWizardStepIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get productWizardStepIdentity;

  /// No description provided for @productWizardStepUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get productWizardStepUnits;

  /// No description provided for @productWizardStepPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get productWizardStepPricing;

  /// No description provided for @productWizardStepFlags.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get productWizardStepFlags;

  /// No description provided for @productWizardStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get productWizardStepReview;

  /// No description provided for @productWizardNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get productWizardNext;

  /// No description provided for @productWizardBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get productWizardBack;

  /// No description provided for @productWizardSubmit.
  ///
  /// In en, this message translates to:
  /// **'Save product'**
  String get productWizardSubmit;

  /// No description provided for @productWizardCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get productWizardCreateTitle;

  /// No description provided for @productFieldSku.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get productFieldSku;

  /// No description provided for @productFieldNameAr.
  ///
  /// In en, this message translates to:
  /// **'Arabic name'**
  String get productFieldNameAr;

  /// No description provided for @productFieldNameEn.
  ///
  /// In en, this message translates to:
  /// **'English name'**
  String get productFieldNameEn;

  /// No description provided for @productFieldGroup.
  ///
  /// In en, this message translates to:
  /// **'Product group'**
  String get productFieldGroup;

  /// No description provided for @productFieldType.
  ///
  /// In en, this message translates to:
  /// **'Product type'**
  String get productFieldType;

  /// No description provided for @productFieldMode.
  ///
  /// In en, this message translates to:
  /// **'Product mode'**
  String get productFieldMode;

  /// No description provided for @productFieldRentalType.
  ///
  /// In en, this message translates to:
  /// **'Rental type'**
  String get productFieldRentalType;

  /// No description provided for @productFieldUnitPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary unit'**
  String get productFieldUnitPrimary;

  /// No description provided for @productFieldUnitSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary unit'**
  String get productFieldUnitSecondary;

  /// No description provided for @productFieldConversionFactor.
  ///
  /// In en, this message translates to:
  /// **'Conversion factor'**
  String get productFieldConversionFactor;

  /// No description provided for @productFieldSalePrice.
  ///
  /// In en, this message translates to:
  /// **'Sale price'**
  String get productFieldSalePrice;

  /// No description provided for @productFieldMinSalePrice.
  ///
  /// In en, this message translates to:
  /// **'Min sale price'**
  String get productFieldMinSalePrice;

  /// No description provided for @productFieldAvgCost.
  ///
  /// In en, this message translates to:
  /// **'Average cost'**
  String get productFieldAvgCost;

  /// No description provided for @productFieldLastPurchaseCost.
  ///
  /// In en, this message translates to:
  /// **'Last purchase cost'**
  String get productFieldLastPurchaseCost;

  /// No description provided for @productFieldBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get productFieldBarcode;

  /// No description provided for @productFieldSerialized.
  ///
  /// In en, this message translates to:
  /// **'Serialized product'**
  String get productFieldSerialized;

  /// No description provided for @productFieldMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Trackable for maintenance'**
  String get productFieldMaintenance;

  /// No description provided for @productFieldExpectedLifespan.
  ///
  /// In en, this message translates to:
  /// **'Expected lifespan (months)'**
  String get productFieldExpectedLifespan;

  /// No description provided for @productFieldReorderPoint.
  ///
  /// In en, this message translates to:
  /// **'Reorder point'**
  String get productFieldReorderPoint;

  /// No description provided for @productFieldActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get productFieldActive;

  /// No description provided for @productSectionOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get productSectionOverview;

  /// No description provided for @productSectionPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get productSectionPricing;

  /// No description provided for @productSectionUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get productSectionUnits;

  /// No description provided for @productSectionInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get productSectionInventory;

  /// No description provided for @productSectionAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit'**
  String get productSectionAudit;

  /// No description provided for @productDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product not found.'**
  String get productDetailNotFound;

  /// No description provided for @productDetailLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load product. Try again.'**
  String get productDetailLoadError;

  /// No description provided for @productDetailStockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Stock summary unavailable.'**
  String get productDetailStockUnavailable;

  /// No description provided for @productDetailStockTotal.
  ///
  /// In en, this message translates to:
  /// **'Total available'**
  String get productDetailStockTotal;

  /// No description provided for @productDetailCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get productDetailCreatedAt;

  /// No description provided for @productDetailUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get productDetailUpdatedAt;

  /// No description provided for @productImageAdd.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get productImageAdd;

  /// No description provided for @productImageChange.
  ///
  /// In en, this message translates to:
  /// **'Change image'**
  String get productImageChange;

  /// No description provided for @productImageUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading image…'**
  String get productImageUploading;

  /// No description provided for @productCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Product {sku} created successfully.'**
  String productCreatedSuccess(String sku);

  /// No description provided for @productSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Product saved.'**
  String get productSavedSuccess;

  /// No description provided for @productGroupsPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'You need product group access to create products.'**
  String get productGroupsPermissionRequired;

  /// No description provided for @productValidationSkuRequired.
  ///
  /// In en, this message translates to:
  /// **'SKU is required'**
  String get productValidationSkuRequired;

  /// No description provided for @productValidationNameArRequired.
  ///
  /// In en, this message translates to:
  /// **'Arabic name is required'**
  String get productValidationNameArRequired;

  /// No description provided for @productValidationNameEnRequired.
  ///
  /// In en, this message translates to:
  /// **'English name is required'**
  String get productValidationNameEnRequired;

  /// No description provided for @productValidationGroupRequired.
  ///
  /// In en, this message translates to:
  /// **'Product group is required'**
  String get productValidationGroupRequired;

  /// No description provided for @productValidationConversionInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid conversion factor for selected units'**
  String get productValidationConversionInvalid;

  /// No description provided for @productValidationSaleBelowMin.
  ///
  /// In en, this message translates to:
  /// **'Sale price cannot be below minimum sale price'**
  String get productValidationSaleBelowMin;

  /// No description provided for @productValidationModeRequired.
  ///
  /// In en, this message translates to:
  /// **'Select sale, rental, or both'**
  String get productValidationModeRequired;

  /// No description provided for @productValidationExpectedLifespan.
  ///
  /// In en, this message translates to:
  /// **'Expected lifespan must be a positive whole number'**
  String get productValidationExpectedLifespan;

  /// No description provided for @productValidationSerializedPiece.
  ///
  /// In en, this message translates to:
  /// **'Serialized products must use piece as primary unit'**
  String get productValidationSerializedPiece;

  /// No description provided for @productValidationNegative.
  ///
  /// In en, this message translates to:
  /// **'Value cannot be negative'**
  String get productValidationNegative;

  /// No description provided for @productValidationInvalidDecimal.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get productValidationInvalidDecimal;

  /// No description provided for @productValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Please fix the highlighted fields'**
  String get productValidationFailed;

  /// No description provided for @productErrorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission for this action'**
  String get productErrorPermissionDenied;

  /// No description provided for @productErrorDuplicateSku.
  ///
  /// In en, this message translates to:
  /// **'SKU already exists'**
  String get productErrorDuplicateSku;

  /// No description provided for @productErrorDuplicateBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode already exists'**
  String get productErrorDuplicateBarcode;

  /// No description provided for @productErrorFieldNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This field is not supported yet'**
  String get productErrorFieldNotSupported;

  /// No description provided for @productErrorImageType.
  ///
  /// In en, this message translates to:
  /// **'Image must be JPG, PNG, or WebP'**
  String get productErrorImageType;

  /// No description provided for @productErrorImageSize.
  ///
  /// In en, this message translates to:
  /// **'Image must be 5 MB or smaller'**
  String get productErrorImageSize;

  /// No description provided for @productErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get productErrorUnknown;

  /// No description provided for @productSerializedLocked.
  ///
  /// In en, this message translates to:
  /// **'Cannot change serialization while stock exists or is unknown'**
  String get productSerializedLocked;

  /// No description provided for @productNoSecondaryUnit.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get productNoSecondaryUnit;

  /// No description provided for @productWizardReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review before saving'**
  String get productWizardReviewTitle;

  /// No description provided for @productUnitsNotSerialized.
  ///
  /// In en, this message translates to:
  /// **'Unit tracking applies to serialized products only.'**
  String get productUnitsNotSerialized;

  /// No description provided for @productUnitsViewDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to view product units.'**
  String get productUnitsViewDenied;

  /// No description provided for @productUnitsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No units yet. Add a unit or bulk import serial numbers.'**
  String get productUnitsEmpty;

  /// No description provided for @productUnitsHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No contract history for this unit yet.'**
  String get productUnitsHistoryEmpty;

  /// No description provided for @productUnitAdd.
  ///
  /// In en, this message translates to:
  /// **'Add unit'**
  String get productUnitAdd;

  /// No description provided for @productUnitBulkAdd.
  ///
  /// In en, this message translates to:
  /// **'Bulk add'**
  String get productUnitBulkAdd;

  /// No description provided for @productUnitEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit unit'**
  String get productUnitEdit;

  /// No description provided for @productUnitFieldSerial.
  ///
  /// In en, this message translates to:
  /// **'Serial number'**
  String get productUnitFieldSerial;

  /// No description provided for @productUnitFieldBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get productUnitFieldBarcode;

  /// No description provided for @productUnitFieldStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get productUnitFieldStatus;

  /// No description provided for @productUnitFieldWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get productUnitFieldWarehouse;

  /// No description provided for @productUnitFieldPurchaseCost.
  ///
  /// In en, this message translates to:
  /// **'Purchase cost'**
  String get productUnitFieldPurchaseCost;

  /// No description provided for @productUnitFieldHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get productUnitFieldHealth;

  /// No description provided for @productUnitFieldAcquired.
  ///
  /// In en, this message translates to:
  /// **'Acquired'**
  String get productUnitFieldAcquired;

  /// No description provided for @productUnitFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get productUnitFieldNotes;

  /// No description provided for @productUnitBulkPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste one serial per line, or CSV: serial,barcode,cost. Simple CSV only (no quoted commas).'**
  String get productUnitBulkPasteHint;

  /// No description provided for @productUnitBulkPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get productUnitBulkPreview;

  /// No description provided for @productUnitBulkConfirm.
  ///
  /// In en, this message translates to:
  /// **'Create units'**
  String get productUnitBulkConfirm;

  /// No description provided for @productUnitHealthGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get productUnitHealthGood;

  /// No description provided for @productUnitHealthNeedsService.
  ///
  /// In en, this message translates to:
  /// **'Needs service'**
  String get productUnitHealthNeedsService;

  /// No description provided for @productUnitHealthDamaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get productUnitHealthDamaged;

  /// No description provided for @productUnitHealthLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get productUnitHealthLost;

  /// No description provided for @productUnitStatusAvailableNew.
  ///
  /// In en, this message translates to:
  /// **'Available (new)'**
  String get productUnitStatusAvailableNew;

  /// No description provided for @productUnitStatusAvailableUsed.
  ///
  /// In en, this message translates to:
  /// **'Available (used)'**
  String get productUnitStatusAvailableUsed;

  /// No description provided for @productUnitStatusRented.
  ///
  /// In en, this message translates to:
  /// **'Rented'**
  String get productUnitStatusRented;

  /// No description provided for @productUnitStatusTrial.
  ///
  /// In en, this message translates to:
  /// **'Trial'**
  String get productUnitStatusTrial;

  /// No description provided for @productUnitStatusMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get productUnitStatusMaintenance;

  /// No description provided for @productUnitStatusSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get productUnitStatusSold;

  /// No description provided for @productUnitStatusDamaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get productUnitStatusDamaged;

  /// No description provided for @productUnitStatusLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get productUnitStatusLost;

  /// No description provided for @productUnitStatusRetired.
  ///
  /// In en, this message translates to:
  /// **'Retired'**
  String get productUnitStatusRetired;

  /// No description provided for @productUnitErrorDuplicateSerial.
  ///
  /// In en, this message translates to:
  /// **'Serial number already exists'**
  String get productUnitErrorDuplicateSerial;

  /// No description provided for @productUnitErrorNotSerialized.
  ///
  /// In en, this message translates to:
  /// **'This product is not serialized'**
  String get productUnitErrorNotSerialized;

  /// No description provided for @productUnitErrorNotEditable.
  ///
  /// In en, this message translates to:
  /// **'This unit cannot be edited in its current status'**
  String get productUnitErrorNotEditable;

  /// No description provided for @productUnitErrorBulkLimit.
  ///
  /// In en, this message translates to:
  /// **'Maximum 100 units per bulk operation'**
  String get productUnitErrorBulkLimit;

  /// No description provided for @productUnitParserEmptySerial.
  ///
  /// In en, this message translates to:
  /// **'Empty serial number in pasted list'**
  String get productUnitParserEmptySerial;

  /// No description provided for @productUnitParserDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate serial in pasted list'**
  String get productUnitParserDuplicate;

  /// No description provided for @productUnitParserInvalidCost.
  ///
  /// In en, this message translates to:
  /// **'Invalid purchase cost in pasted list'**
  String get productUnitParserInvalidCost;

  /// No description provided for @productUnitSectionHistory.
  ///
  /// In en, this message translates to:
  /// **'Contract history'**
  String get productUnitSectionHistory;

  /// No description provided for @productUnitWarehouseTransferHint.
  ///
  /// In en, this message translates to:
  /// **'Use Stock Transfers to move stock between warehouses.'**
  String get productUnitWarehouseTransferHint;

  /// Customers module title and navigation label
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// Suppliers tab label
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliers;

  /// Customer detail screen title
  ///
  /// In en, this message translates to:
  /// **'Customer details'**
  String get customerDetails;

  /// Customer edit screen title
  ///
  /// In en, this message translates to:
  /// **'Edit customer'**
  String get editCustomer;

  /// Customer detail overview tab
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get customerOverview;

  /// Customer detail statement tab
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get customerStatement;

  /// Customer detail timeline tab
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get customerTimeline;

  /// Customer detail profile tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get customerProfile;

  /// Customer detail contracts tab
  ///
  /// In en, this message translates to:
  /// **'Contracts'**
  String get customerContracts;

  /// Customer detail invoices tab
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get customerInvoices;

  /// Customer detail vouchers tab
  ///
  /// In en, this message translates to:
  /// **'Vouchers'**
  String get customerVouchers;

  /// Shown when customer detail id does not resolve
  ///
  /// In en, this message translates to:
  /// **'Customer not found.'**
  String get customerNotFound;

  /// Header label for primary service location summary
  ///
  /// In en, this message translates to:
  /// **'Primary location'**
  String get customerPrimaryLocationSummary;

  /// Header status when customer has no accounting account
  ///
  /// In en, this message translates to:
  /// **'No linked A/R account'**
  String get customerAccountNotLinked;

  /// Label for linked accounting account id
  ///
  /// In en, this message translates to:
  /// **'Account ID'**
  String get customerAccountIdLabel;

  /// Statement tab when customers.view_ledger is missing
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to view this customer\'s ledger.'**
  String get customerLedgerPermissionDenied;

  /// Statement tab empty state for permitted user
  ///
  /// In en, this message translates to:
  /// **'No ledger movements yet.'**
  String get customerStatementEmpty;

  /// Statement tab before first load is triggered
  ///
  /// In en, this message translates to:
  /// **'Open this tab to load the statement.'**
  String get customerStatementNotLoaded;

  /// Statement summary section title
  ///
  /// In en, this message translates to:
  /// **'Account summary'**
  String get customerStatementSummaryTitle;

  /// Statement debit column/label
  ///
  /// In en, this message translates to:
  /// **'Debit'**
  String get customerStatementDebit;

  /// Statement credit column/label
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get customerStatementCredit;

  /// Statement running balance column/label
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get customerStatementBalance;

  /// Statement table date column
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get customerStatementColumnDate;

  /// Statement table entry number column
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get customerStatementColumnEntry;

  /// Statement table journal source column
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get customerStatementColumnSource;

  /// Statement table description column
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get customerStatementColumnDescription;

  /// Contracts tab empty state when user can view contracts
  ///
  /// In en, this message translates to:
  /// **'No contracts yet.'**
  String get customerContractsEmpty;

  /// Invoices tab empty state when user can view invoices
  ///
  /// In en, this message translates to:
  /// **'No invoices yet.'**
  String get customerInvoicesEmpty;

  /// Vouchers tab empty state when user can view vouchers
  ///
  /// In en, this message translates to:
  /// **'No vouchers yet.'**
  String get customerVouchersEmpty;

  /// Timeline tab when no metadata events exist
  ///
  /// In en, this message translates to:
  /// **'No timeline events yet.'**
  String get customerTimelineEmpty;

  /// Timeline event for customer creation
  ///
  /// In en, this message translates to:
  /// **'Customer created'**
  String get customerTimelineCreated;

  /// Timeline event for profile update
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get customerTimelineUpdated;

  /// Timeline event for customer acquisition
  ///
  /// In en, this message translates to:
  /// **'Customer acquired'**
  String get customerTimelineAcquired;

  /// No description provided for @journalSourceManual.
  ///
  /// In en, this message translates to:
  /// **'Manual entry'**
  String get journalSourceManual;

  /// No description provided for @journalSourceSalesInvoice.
  ///
  /// In en, this message translates to:
  /// **'Sales invoice'**
  String get journalSourceSalesInvoice;

  /// No description provided for @journalSourcePurchaseInvoice.
  ///
  /// In en, this message translates to:
  /// **'Purchase invoice'**
  String get journalSourcePurchaseInvoice;

  /// No description provided for @journalSourceReceiptVoucher.
  ///
  /// In en, this message translates to:
  /// **'Receipt voucher'**
  String get journalSourceReceiptVoucher;

  /// No description provided for @journalSourcePaymentVoucher.
  ///
  /// In en, this message translates to:
  /// **'Payment voucher'**
  String get journalSourcePaymentVoucher;

  /// No description provided for @journalSourceRentalInvoice.
  ///
  /// In en, this message translates to:
  /// **'Rental invoice'**
  String get journalSourceRentalInvoice;

  /// No description provided for @journalSourceContractCreation.
  ///
  /// In en, this message translates to:
  /// **'Contract creation'**
  String get journalSourceContractCreation;

  /// No description provided for @journalSourceContractClosure.
  ///
  /// In en, this message translates to:
  /// **'Contract closure'**
  String get journalSourceContractClosure;

  /// No description provided for @journalSourceOpeningBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get journalSourceOpeningBalance;

  /// No description provided for @journalSourceInventoryAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Inventory adjustment'**
  String get journalSourceInventoryAdjustment;

  /// No description provided for @journalSourceSalaryPayment.
  ///
  /// In en, this message translates to:
  /// **'Salary payment'**
  String get journalSourceSalaryPayment;

  /// Chart of accounts module title and navigation label
  ///
  /// In en, this message translates to:
  /// **'Chart of accounts'**
  String get chartOfAccounts;

  /// Secondary label for route entity id in placeholder screens
  ///
  /// In en, this message translates to:
  /// **'Reference ID'**
  String get referenceId;

  /// Placeholder when customer list UI is not yet available
  ///
  /// In en, this message translates to:
  /// **'Customer list is not available in this build.'**
  String get customersListUnavailable;

  /// Placeholder when supplier list UI is not yet available
  ///
  /// In en, this message translates to:
  /// **'Supplier list is not available in this build.'**
  String get suppliersListUnavailable;

  /// Placeholder when customer detail content is not yet available
  ///
  /// In en, this message translates to:
  /// **'Customer not found or unavailable.'**
  String get customerDetailsUnavailable;

  /// Placeholder when customer edit form is not yet available
  ///
  /// In en, this message translates to:
  /// **'Customer editing is not available in this build.'**
  String get customerEditUnavailable;

  /// Placeholder when supplier detail content is not yet available
  ///
  /// In en, this message translates to:
  /// **'Supplier details are not available in this build.'**
  String get supplierDetailsUnavailable;

  /// Placeholder when chart of accounts tree is not yet available
  ///
  /// In en, this message translates to:
  /// **'Chart of accounts view is not available in this build.'**
  String get chartOfAccountsUnavailable;

  /// Generic placeholder for unavailable module sections or tabs
  ///
  /// In en, this message translates to:
  /// **'This section is not available in this build.'**
  String get moduleSectionUnavailable;

  /// Shown when user has no visible tabs in customers hub
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to view this section.'**
  String get moduleAccessUnavailable;

  /// No description provided for @createCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'New customer'**
  String get createCustomerTitle;

  /// No description provided for @customerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by code, name, phone, email'**
  String get customerSearchHint;

  /// No description provided for @customerFilterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get customerFilterStatus;

  /// No description provided for @customerFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get customerFilterAll;

  /// No description provided for @customerStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get customerStatusActive;

  /// No description provided for @customerStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get customerStatusInactive;

  /// No description provided for @customerFilterVip.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get customerFilterVip;

  /// No description provided for @customerVip.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get customerVip;

  /// No description provided for @customerNonVip.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get customerNonVip;

  /// No description provided for @customerClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get customerClearFilters;

  /// No description provided for @customerTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get customerTypeLabel;

  /// No description provided for @customerTypeIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get customerTypeIndividual;

  /// No description provided for @customerTypeCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get customerTypeCompany;

  /// No description provided for @customerColumnCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get customerColumnCode;

  /// No description provided for @customerColumnName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get customerColumnName;

  /// No description provided for @customerColumnPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get customerColumnPhone;

  /// No description provided for @customerColumnType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get customerColumnType;

  /// No description provided for @customerColumnLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get customerColumnLocation;

  /// No description provided for @customerColumnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get customerColumnStatus;

  /// No description provided for @customerActionView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get customerActionView;

  /// No description provided for @customerActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get customerActionEdit;

  /// No description provided for @customerActionDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get customerActionDeactivate;

  /// No description provided for @customerAdd.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get customerAdd;

  /// No description provided for @customerListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No customers yet.'**
  String get customerListEmpty;

  /// No description provided for @customerListEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No customers match your filters.'**
  String get customerListEmptyFiltered;

  /// No description provided for @customerDeactivateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate customer'**
  String get customerDeactivateConfirmTitle;

  /// No description provided for @customerDeactivateConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This customer will be hidden from the active list. You can still find them by switching the status filter. Continue?'**
  String get customerDeactivateConfirmBody;

  /// No description provided for @customerCreated.
  ///
  /// In en, this message translates to:
  /// **'Customer created.'**
  String get customerCreated;

  /// No description provided for @customerUpdated.
  ///
  /// In en, this message translates to:
  /// **'Customer saved.'**
  String get customerUpdated;

  /// No description provided for @customerDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Customer deactivated.'**
  String get customerDeactivated;

  /// No description provided for @customerFieldCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get customerFieldCode;

  /// No description provided for @customerFieldNameAr.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get customerFieldNameAr;

  /// No description provided for @customerFieldNameEn.
  ///
  /// In en, this message translates to:
  /// **'Name (English)'**
  String get customerFieldNameEn;

  /// No description provided for @customerFieldContactName.
  ///
  /// In en, this message translates to:
  /// **'Contact person'**
  String get customerFieldContactName;

  /// No description provided for @customerFieldContactPhone.
  ///
  /// In en, this message translates to:
  /// **'Contact phone'**
  String get customerFieldContactPhone;

  /// No description provided for @customerFieldPhonePrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary phone'**
  String get customerFieldPhonePrimary;

  /// No description provided for @customerFieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get customerFieldEmail;

  /// No description provided for @customerFieldTaxNumber.
  ///
  /// In en, this message translates to:
  /// **'Tax number'**
  String get customerFieldTaxNumber;

  /// No description provided for @customerFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address details'**
  String get customerFieldAddress;

  /// No description provided for @customerFieldArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get customerFieldArea;

  /// No description provided for @customerFieldGovernorate.
  ///
  /// In en, this message translates to:
  /// **'Governorate'**
  String get customerFieldGovernorate;

  /// No description provided for @customerFieldCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get customerFieldCountry;

  /// No description provided for @customerFieldGoogleMapsUrl.
  ///
  /// In en, this message translates to:
  /// **'Google Maps link'**
  String get customerFieldGoogleMapsUrl;

  /// No description provided for @customerFieldVip.
  ///
  /// In en, this message translates to:
  /// **'VIP customer'**
  String get customerFieldVip;

  /// No description provided for @customerFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get customerFieldNotes;

  /// No description provided for @customerFieldCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create accounting account'**
  String get customerFieldCreateAccount;

  /// No description provided for @customerFieldCreateAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Links an A/R subaccount under receivables.'**
  String get customerFieldCreateAccountHint;

  /// No description provided for @customerLinkedAccountYes.
  ///
  /// In en, this message translates to:
  /// **'Linked accounting account'**
  String get customerLinkedAccountYes;

  /// No description provided for @customerLinkedAccountNo.
  ///
  /// In en, this message translates to:
  /// **'No accounting account'**
  String get customerLinkedAccountNo;

  /// No description provided for @customerEnsureAccount.
  ///
  /// In en, this message translates to:
  /// **'Create accounting account'**
  String get customerEnsureAccount;

  /// No description provided for @customerAccountLinked.
  ///
  /// In en, this message translates to:
  /// **'Accounting account linked.'**
  String get customerAccountLinked;

  /// No description provided for @customerSectionIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get customerSectionIdentity;

  /// No description provided for @customerSectionContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get customerSectionContact;

  /// No description provided for @customerSectionLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get customerSectionLocation;

  /// No description provided for @customerSectionAccounting.
  ///
  /// In en, this message translates to:
  /// **'Accounting'**
  String get customerSectionAccounting;

  /// No description provided for @customerValidationNameArRequired.
  ///
  /// In en, this message translates to:
  /// **'Arabic name is required.'**
  String get customerValidationNameArRequired;

  /// No description provided for @customerValidationPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Primary phone is required.'**
  String get customerValidationPhoneRequired;

  /// No description provided for @customerValidationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get customerValidationEmailInvalid;

  /// No description provided for @customerValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the customer. Please check the values.'**
  String get customerValidationFailed;

  /// No description provided for @customerErrorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to perform this action.'**
  String get customerErrorPermissionDenied;

  /// No description provided for @customerErrorAccountAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'This profile already has a linked accounting account.'**
  String get customerErrorAccountAlreadyLinked;

  /// No description provided for @customerErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get customerErrorUnknown;

  /// No description provided for @locationAreaOther.
  ///
  /// In en, this message translates to:
  /// **'Other (custom)'**
  String get locationAreaOther;

  /// No description provided for @locationEnterCustomArea.
  ///
  /// In en, this message translates to:
  /// **'Enter area manually'**
  String get locationEnterCustomArea;

  /// No description provided for @locationUseCatalogArea.
  ///
  /// In en, this message translates to:
  /// **'Choose from list'**
  String get locationUseCatalogArea;

  /// No description provided for @createSupplierTitle.
  ///
  /// In en, this message translates to:
  /// **'New supplier'**
  String get createSupplierTitle;

  /// No description provided for @editSupplierTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit supplier'**
  String get editSupplierTitle;

  /// No description provided for @supplierSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by code, name, phone, email'**
  String get supplierSearchHint;

  /// No description provided for @supplierFilterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get supplierFilterStatus;

  /// No description provided for @supplierFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get supplierFilterAll;

  /// No description provided for @supplierStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get supplierStatusActive;

  /// No description provided for @supplierStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get supplierStatusInactive;

  /// No description provided for @supplierClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get supplierClearFilters;

  /// No description provided for @supplierColumnCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get supplierColumnCode;

  /// No description provided for @supplierColumnName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get supplierColumnName;

  /// No description provided for @supplierColumnPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get supplierColumnPhone;

  /// No description provided for @supplierColumnEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get supplierColumnEmail;

  /// No description provided for @supplierColumnLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get supplierColumnLocation;

  /// No description provided for @supplierColumnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get supplierColumnStatus;

  /// No description provided for @supplierActionView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get supplierActionView;

  /// No description provided for @supplierActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get supplierActionEdit;

  /// No description provided for @supplierActionDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get supplierActionDeactivate;

  /// No description provided for @supplierAdd.
  ///
  /// In en, this message translates to:
  /// **'Add supplier'**
  String get supplierAdd;

  /// No description provided for @supplierListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No suppliers yet.'**
  String get supplierListEmpty;

  /// No description provided for @supplierListEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No suppliers match your filters.'**
  String get supplierListEmptyFiltered;

  /// No description provided for @supplierDeactivateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate supplier'**
  String get supplierDeactivateConfirmTitle;

  /// No description provided for @supplierDeactivateConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This supplier will be hidden from the active list. You can still find them by switching the status filter. Continue?'**
  String get supplierDeactivateConfirmBody;

  /// No description provided for @supplierCreated.
  ///
  /// In en, this message translates to:
  /// **'Supplier created.'**
  String get supplierCreated;

  /// No description provided for @supplierUpdated.
  ///
  /// In en, this message translates to:
  /// **'Supplier saved.'**
  String get supplierUpdated;

  /// No description provided for @supplierDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Supplier deactivated.'**
  String get supplierDeactivated;

  /// No description provided for @supplierFieldCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get supplierFieldCode;

  /// No description provided for @supplierFieldNameAr.
  ///
  /// In en, this message translates to:
  /// **'Name (Arabic)'**
  String get supplierFieldNameAr;

  /// No description provided for @supplierFieldNameEn.
  ///
  /// In en, this message translates to:
  /// **'Name (English)'**
  String get supplierFieldNameEn;

  /// No description provided for @supplierFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get supplierFieldPhone;

  /// No description provided for @supplierFieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get supplierFieldEmail;

  /// No description provided for @supplierFieldTaxNumber.
  ///
  /// In en, this message translates to:
  /// **'Tax number'**
  String get supplierFieldTaxNumber;

  /// No description provided for @supplierFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address details'**
  String get supplierFieldAddress;

  /// No description provided for @supplierFieldGoogleMapsUrl.
  ///
  /// In en, this message translates to:
  /// **'Google Maps link'**
  String get supplierFieldGoogleMapsUrl;

  /// No description provided for @supplierFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get supplierFieldNotes;

  /// No description provided for @supplierFieldCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create accounting account'**
  String get supplierFieldCreateAccount;

  /// No description provided for @supplierFieldCreateAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Links an A/P subaccount under payables.'**
  String get supplierFieldCreateAccountHint;

  /// No description provided for @supplierLinkedAccountYes.
  ///
  /// In en, this message translates to:
  /// **'Linked accounting account'**
  String get supplierLinkedAccountYes;

  /// No description provided for @supplierLinkedAccountNo.
  ///
  /// In en, this message translates to:
  /// **'No accounting account'**
  String get supplierLinkedAccountNo;

  /// No description provided for @supplierEnsureAccount.
  ///
  /// In en, this message translates to:
  /// **'Create accounting account'**
  String get supplierEnsureAccount;

  /// No description provided for @supplierAccountLinked.
  ///
  /// In en, this message translates to:
  /// **'Accounting account linked.'**
  String get supplierAccountLinked;

  /// No description provided for @supplierSectionIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get supplierSectionIdentity;

  /// No description provided for @supplierSectionContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get supplierSectionContact;

  /// No description provided for @supplierSectionLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get supplierSectionLocation;

  /// No description provided for @supplierSectionAccounting.
  ///
  /// In en, this message translates to:
  /// **'Accounting'**
  String get supplierSectionAccounting;

  /// No description provided for @supplierValidationNameArRequired.
  ///
  /// In en, this message translates to:
  /// **'Arabic name is required.'**
  String get supplierValidationNameArRequired;

  /// No description provided for @supplierValidationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get supplierValidationEmailInvalid;

  /// No description provided for @supplierValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the supplier. Please check the values.'**
  String get supplierValidationFailed;

  /// No description provided for @supplierErrorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to perform this action.'**
  String get supplierErrorPermissionDenied;

  /// No description provided for @supplierErrorAccountAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'This profile already has a linked accounting account.'**
  String get supplierErrorAccountAlreadyLinked;

  /// No description provided for @supplierErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get supplierErrorUnknown;

  /// No description provided for @customerLocations.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get customerLocations;

  /// No description provided for @serviceLocationPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get serviceLocationPrimary;

  /// No description provided for @serviceLocationAdd.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get serviceLocationAdd;

  /// No description provided for @serviceLocationEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit location'**
  String get serviceLocationEdit;

  /// No description provided for @serviceLocationDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get serviceLocationDeactivate;

  /// No description provided for @serviceLocationSetPrimary.
  ///
  /// In en, this message translates to:
  /// **'Set as primary'**
  String get serviceLocationSetPrimary;

  /// No description provided for @serviceLocationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No service locations yet.'**
  String get serviceLocationEmpty;

  /// No description provided for @serviceLocationInUse.
  ///
  /// In en, this message translates to:
  /// **'This location is still used by a contract, visit, calendar event, or device.'**
  String get serviceLocationInUse;

  /// No description provided for @serviceLocationPrimaryRequired.
  ///
  /// In en, this message translates to:
  /// **'Set another active location as primary before deactivating this one.'**
  String get serviceLocationPrimaryRequired;

  /// No description provided for @serviceLocationValidationNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Location name is required.'**
  String get serviceLocationValidationNameRequired;

  /// No description provided for @primaryLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary location'**
  String get primaryLocationLabel;

  /// No description provided for @customerAddressBecomesPrimaryLocation.
  ///
  /// In en, this message translates to:
  /// **'Address fields create a primary service location for this customer.'**
  String get customerAddressBecomesPrimaryLocation;

  /// No description provided for @serviceLocationFieldName.
  ///
  /// In en, this message translates to:
  /// **'Location name'**
  String get serviceLocationFieldName;

  /// No description provided for @serviceLocationFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get serviceLocationFieldType;

  /// No description provided for @serviceLocationFieldContactName.
  ///
  /// In en, this message translates to:
  /// **'Responsible person'**
  String get serviceLocationFieldContactName;

  /// No description provided for @serviceLocationFieldContactPhone.
  ///
  /// In en, this message translates to:
  /// **'Responsible phone'**
  String get serviceLocationFieldContactPhone;

  /// No description provided for @serviceLocationFieldContactEmail.
  ///
  /// In en, this message translates to:
  /// **'Responsible email'**
  String get serviceLocationFieldContactEmail;

  /// No description provided for @serviceLocationFieldLatitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get serviceLocationFieldLatitude;

  /// No description provided for @serviceLocationFieldLongitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get serviceLocationFieldLongitude;

  /// No description provided for @serviceLocationCoordinatesSection.
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get serviceLocationCoordinatesSection;

  /// No description provided for @serviceLocationCoordinatesHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a Google Maps link. Coordinates are extracted automatically and are not entered manually.'**
  String get serviceLocationCoordinatesHint;

  /// No description provided for @googleMapsLinkResolutionHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a Google Maps link to extract the location automatically.'**
  String get googleMapsLinkResolutionHint;

  /// No description provided for @googleMapsResolveLink.
  ///
  /// In en, this message translates to:
  /// **'Extract location'**
  String get googleMapsResolveLink;

  /// No description provided for @googleMapsCoordinatesResolved.
  ///
  /// In en, this message translates to:
  /// **'Location extracted: {latitude}, {longitude}'**
  String googleMapsCoordinatesResolved(String latitude, String longitude);

  /// No description provided for @googleMapsLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Google Maps link.'**
  String get googleMapsLinkInvalid;

  /// No description provided for @googleMapsCoordinatesNotFound.
  ///
  /// In en, this message translates to:
  /// **'Coordinates could not be extracted from this Google Maps link.'**
  String get googleMapsCoordinatesNotFound;

  /// No description provided for @googleMapsResolutionFailed.
  ///
  /// In en, this message translates to:
  /// **'The Google Maps link could not be resolved. Check the connection and try again.'**
  String get googleMapsResolutionFailed;

  /// No description provided for @serviceLocationUseCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get serviceLocationUseCurrentLocation;

  /// No description provided for @serviceLocationClearCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Clear coordinates'**
  String get serviceLocationClearCoordinates;

  /// No description provided for @serviceLocationCoordinatePairRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter both latitude and longitude.'**
  String get serviceLocationCoordinatePairRequired;

  /// No description provided for @serviceLocationLatitudeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Latitude must be between -90 and 90.'**
  String get serviceLocationLatitudeInvalid;

  /// No description provided for @serviceLocationLongitudeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Longitude must be between -180 and 180.'**
  String get serviceLocationLongitudeInvalid;

  /// No description provided for @serviceLocationCoordinateMetadataInvalid.
  ///
  /// In en, this message translates to:
  /// **'Coordinate source or quality information is invalid.'**
  String get serviceLocationCoordinateMetadataInvalid;

  /// No description provided for @serviceLocationCoordinatesCaptured.
  ///
  /// In en, this message translates to:
  /// **'Current location captured.'**
  String get serviceLocationCoordinatesCaptured;

  /// No description provided for @serviceLocationCoordinateSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get serviceLocationCoordinateSource;

  /// No description provided for @serviceLocationCoordinateSourceMapPick.
  ///
  /// In en, this message translates to:
  /// **'Map selection'**
  String get serviceLocationCoordinateSourceMapPick;

  /// No description provided for @serviceLocationCoordinateSourceDeviceGps.
  ///
  /// In en, this message translates to:
  /// **'Device GPS'**
  String get serviceLocationCoordinateSourceDeviceGps;

  /// No description provided for @serviceLocationCoordinateSourceUrl.
  ///
  /// In en, this message translates to:
  /// **'Resolved map link'**
  String get serviceLocationCoordinateSourceUrl;

  /// No description provided for @serviceLocationCoordinateSourceManual.
  ///
  /// In en, this message translates to:
  /// **'Manual entry'**
  String get serviceLocationCoordinateSourceManual;

  /// No description provided for @serviceLocationCoordinateResolvedAt.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get serviceLocationCoordinateResolvedAt;

  /// No description provided for @serviceLocationCoordinateAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy: {meters} m'**
  String serviceLocationCoordinateAccuracy(String meters);

  /// No description provided for @serviceLocationTypeBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get serviceLocationTypeBranch;

  /// No description provided for @serviceLocationTypeOffice.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get serviceLocationTypeOffice;

  /// No description provided for @serviceLocationTypeWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get serviceLocationTypeWarehouse;

  /// No description provided for @serviceLocationTypeHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get serviceLocationTypeHome;

  /// No description provided for @serviceLocationTypeInstallationSite.
  ///
  /// In en, this message translates to:
  /// **'Installation site'**
  String get serviceLocationTypeInstallationSite;

  /// No description provided for @serviceLocationTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get serviceLocationTypeOther;

  /// No description provided for @serviceLocationMapsCopied.
  ///
  /// In en, this message translates to:
  /// **'Maps link copied.'**
  String get serviceLocationMapsCopied;

  /// No description provided for @serviceLocationOpenMaps.
  ///
  /// In en, this message translates to:
  /// **'Open map link'**
  String get serviceLocationOpenMaps;

  /// No description provided for @chartAccountSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by code or name'**
  String get chartAccountSearchHint;

  /// No description provided for @chartAccountFilterType.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get chartAccountFilterType;

  /// No description provided for @chartAccountFilterAllTypes.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get chartAccountFilterAllTypes;

  /// No description provided for @chartAccountFilterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get chartAccountFilterStatus;

  /// No description provided for @chartAccountFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get chartAccountFilterAll;

  /// No description provided for @chartAccountStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get chartAccountStatusActive;

  /// No description provided for @chartAccountStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get chartAccountStatusInactive;

  /// No description provided for @chartAccountClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get chartAccountClearFilters;

  /// No description provided for @chartAccountTypeAsset.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get chartAccountTypeAsset;

  /// No description provided for @chartAccountTypeLiability.
  ///
  /// In en, this message translates to:
  /// **'Liability'**
  String get chartAccountTypeLiability;

  /// No description provided for @chartAccountTypeEquity.
  ///
  /// In en, this message translates to:
  /// **'Equity'**
  String get chartAccountTypeEquity;

  /// No description provided for @chartAccountTypeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get chartAccountTypeIncome;

  /// No description provided for @chartAccountTypeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get chartAccountTypeExpense;

  /// No description provided for @chartAccountBadgeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get chartAccountBadgeSystem;

  /// No description provided for @chartAccountBadgeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get chartAccountBadgeManual;

  /// No description provided for @chartAccountBadgeCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get chartAccountBadgeCustomer;

  /// No description provided for @chartAccountBadgeSupplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get chartAccountBadgeSupplier;

  /// No description provided for @chartAccountBadgeInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get chartAccountBadgeInactive;

  /// No description provided for @chartAccountAdd.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get chartAccountAdd;

  /// No description provided for @chartAccountEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get chartAccountEdit;

  /// No description provided for @chartAccountDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get chartAccountDeactivate;

  /// No description provided for @chartAccountExpandAll.
  ///
  /// In en, this message translates to:
  /// **'Expand all'**
  String get chartAccountExpandAll;

  /// No description provided for @chartAccountCollapseAll.
  ///
  /// In en, this message translates to:
  /// **'Collapse all'**
  String get chartAccountCollapseAll;

  /// No description provided for @chartAccountExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get chartAccountExpand;

  /// No description provided for @chartAccountCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get chartAccountCollapse;

  /// No description provided for @chartAccountCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get chartAccountCreateTitle;

  /// No description provided for @chartAccountEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get chartAccountEditTitle;

  /// No description provided for @chartAccountFieldCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get chartAccountFieldCode;

  /// No description provided for @chartAccountFieldNameAr.
  ///
  /// In en, this message translates to:
  /// **'Name (Arabic)'**
  String get chartAccountFieldNameAr;

  /// No description provided for @chartAccountFieldNameEn.
  ///
  /// In en, this message translates to:
  /// **'Name (English)'**
  String get chartAccountFieldNameEn;

  /// No description provided for @chartAccountFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get chartAccountFieldType;

  /// No description provided for @chartAccountFieldParent.
  ///
  /// In en, this message translates to:
  /// **'Parent account'**
  String get chartAccountFieldParent;

  /// No description provided for @chartAccountParentNone.
  ///
  /// In en, this message translates to:
  /// **'None (root level)'**
  String get chartAccountParentNone;

  /// No description provided for @chartAccountCodeReadOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Account code cannot be changed after creation.'**
  String get chartAccountCodeReadOnlyHint;

  /// No description provided for @chartAccountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created.'**
  String get chartAccountCreated;

  /// No description provided for @chartAccountUpdated.
  ///
  /// In en, this message translates to:
  /// **'Account saved.'**
  String get chartAccountUpdated;

  /// No description provided for @chartAccountDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Account deactivated.'**
  String get chartAccountDeactivated;

  /// No description provided for @chartAccountListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet.'**
  String get chartAccountListEmpty;

  /// No description provided for @chartAccountListEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No accounts match your filters.'**
  String get chartAccountListEmptyFiltered;

  /// No description provided for @chartAccountDeactivateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate account'**
  String get chartAccountDeactivateConfirmTitle;

  /// No description provided for @chartAccountDeactivateConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This account will be marked inactive. Continue?'**
  String get chartAccountDeactivateConfirmBody;

  /// No description provided for @chartAccountSetupArMissing.
  ///
  /// In en, this message translates to:
  /// **'Accounts Receivable parent (1201) is missing. Customer subaccounts may not function correctly.'**
  String get chartAccountSetupArMissing;

  /// No description provided for @chartAccountSetupApMissing.
  ///
  /// In en, this message translates to:
  /// **'Accounts Payable parent (2101) is missing. Supplier subaccounts may not function correctly.'**
  String get chartAccountSetupApMissing;

  /// No description provided for @chartAccountErrorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission for this action.'**
  String get chartAccountErrorPermissionDenied;

  /// No description provided for @chartAccountErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get chartAccountErrorUnknown;

  /// No description provided for @chartAccountValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Please check the form and try again.'**
  String get chartAccountValidationFailed;

  /// No description provided for @chartAccountValidationCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Account code is required.'**
  String get chartAccountValidationCodeRequired;

  /// No description provided for @chartAccountValidationNameArRequired.
  ///
  /// In en, this message translates to:
  /// **'Arabic name is required.'**
  String get chartAccountValidationNameArRequired;

  /// No description provided for @chartAccountValidationNameEnRequired.
  ///
  /// In en, this message translates to:
  /// **'English name is required.'**
  String get chartAccountValidationNameEnRequired;

  /// No description provided for @chartAccountErrorParentTypeMismatch.
  ///
  /// In en, this message translates to:
  /// **'Account type must match the parent account type.'**
  String get chartAccountErrorParentTypeMismatch;

  /// No description provided for @chartAccountErrorDuplicateCode.
  ///
  /// In en, this message translates to:
  /// **'This account code is already in use.'**
  String get chartAccountErrorDuplicateCode;

  /// No description provided for @chartAccountErrorAccountProtected.
  ///
  /// In en, this message translates to:
  /// **'This account is protected and cannot be changed.'**
  String get chartAccountErrorAccountProtected;

  /// No description provided for @chartAccountErrorTypeChangeUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Account type cannot be changed while the account has subaccounts or journal entries.'**
  String get chartAccountErrorTypeChangeUnsafe;

  /// No description provided for @chartAccountErrorHasActiveChildren.
  ///
  /// In en, this message translates to:
  /// **'Cannot deactivate an account that has active subaccounts.'**
  String get chartAccountErrorHasActiveChildren;

  /// No description provided for @chartAccountErrorImmutableColumn.
  ///
  /// In en, this message translates to:
  /// **'This field cannot be changed.'**
  String get chartAccountErrorImmutableColumn;

  /// Label for keyboard-wedge scan input field
  ///
  /// In en, this message translates to:
  /// **'Scan barcode or serial'**
  String get scanInputLabel;

  /// Title for mobile camera scan sheet
  ///
  /// In en, this message translates to:
  /// **'Scan code'**
  String get scanMobileTitle;

  /// No description provided for @scanErrorAmbiguous.
  ///
  /// In en, this message translates to:
  /// **'Multiple matches found for this code.'**
  String get scanErrorAmbiguous;

  /// No description provided for @scanErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'No product or unit matched this code.'**
  String get scanErrorNotFound;

  /// No description provided for @scanErrorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to scan inventory codes.'**
  String get scanErrorPermissionDenied;

  /// No description provided for @scanErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Scan failed. Please try again.'**
  String get scanErrorUnknown;

  /// Product unit detail screen title
  ///
  /// In en, this message translates to:
  /// **'Unit details'**
  String get productUnitDetailTitle;

  /// No description provided for @productUnitDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product unit not found.'**
  String get productUnitDetailNotFound;

  /// No description provided for @productUnitDetailNoBarcode.
  ///
  /// In en, this message translates to:
  /// **'No barcode'**
  String get productUnitDetailNoBarcode;

  /// No description provided for @productUnitDetailLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get productUnitDetailLocation;

  /// No description provided for @productUnitDetailLocationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Location not assigned'**
  String get productUnitDetailLocationUnknown;

  /// No description provided for @productUnitDetailMaintenanceCount.
  ///
  /// In en, this message translates to:
  /// **'Maintenance count'**
  String get productUnitDetailMaintenanceCount;

  /// No description provided for @productUnitSerialCorrectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Correct serial number'**
  String get productUnitSerialCorrectionTitle;

  /// No description provided for @productUnitSerialCorrectionNewSerial.
  ///
  /// In en, this message translates to:
  /// **'New serial number'**
  String get productUnitSerialCorrectionNewSerial;

  /// No description provided for @productUnitSerialCorrectionReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for correction'**
  String get productUnitSerialCorrectionReason;

  /// No description provided for @productUnitSerialCorrectionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Save serial correction'**
  String get productUnitSerialCorrectionSubmit;

  /// No description provided for @productUnitSerialCorrectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Serial number updated.'**
  String get productUnitSerialCorrectionSuccess;

  /// No description provided for @productUnitTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Unit timeline'**
  String get productUnitTimelineTitle;

  /// No description provided for @productUnitTimelineEmpty.
  ///
  /// In en, this message translates to:
  /// **'No timeline events yet.'**
  String get productUnitTimelineEmpty;

  /// No description provided for @productUnitTimelineAcquisition.
  ///
  /// In en, this message translates to:
  /// **'Unit acquired'**
  String get productUnitTimelineAcquisition;

  /// No description provided for @productUnitTimelinePurchaseInvoice.
  ///
  /// In en, this message translates to:
  /// **'Purchase invoice'**
  String get productUnitTimelinePurchaseInvoice;

  /// No description provided for @productUnitTimelineInventoryMovement.
  ///
  /// In en, this message translates to:
  /// **'Inventory movement'**
  String get productUnitTimelineInventoryMovement;

  /// No description provided for @productUnitTimelineReconciled.
  ///
  /// In en, this message translates to:
  /// **'Serial reconciled'**
  String get productUnitTimelineReconciled;

  /// No description provided for @productUnitTimelineSerialCorrection.
  ///
  /// In en, this message translates to:
  /// **'Serial corrected'**
  String get productUnitTimelineSerialCorrection;

  /// No description provided for @documentPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Document preview'**
  String get documentPreviewTitle;

  /// No description provided for @documentPreviewAction.
  ///
  /// In en, this message translates to:
  /// **'Preview PDF'**
  String get documentPreviewAction;

  /// No description provided for @documentPreviewAssetLabel.
  ///
  /// In en, this message translates to:
  /// **'Print asset label'**
  String get documentPreviewAssetLabel;

  /// No description provided for @documentPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No document to preview.'**
  String get documentPreviewEmpty;

  /// No description provided for @documentPreviewPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to preview this document.'**
  String get documentPreviewPermissionDenied;

  /// No description provided for @documentErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Could not generate the document. Please try again.'**
  String get documentErrorUnknown;

  /// No description provided for @documentErrorNoTemplate.
  ///
  /// In en, this message translates to:
  /// **'No default document template is configured.'**
  String get documentErrorNoTemplate;

  /// No description provided for @documentErrorStatementDateRange.
  ///
  /// In en, this message translates to:
  /// **'Statement date range is invalid.'**
  String get documentErrorStatementDateRange;

  /// No description provided for @documentErrorStatementTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Statement has too many rows to print.'**
  String get documentErrorStatementTooLarge;

  /// No description provided for @documentErrorUnsupportedType.
  ///
  /// In en, this message translates to:
  /// **'This document type is not supported yet.'**
  String get documentErrorUnsupportedType;

  /// No description provided for @documentErrorThermalTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Content is too large for thermal printing.'**
  String get documentErrorThermalTooLarge;

  /// No description provided for @documentErrorFontLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load document fonts.'**
  String get documentErrorFontLoad;

  /// No description provided for @documentErrorValidation.
  ///
  /// In en, this message translates to:
  /// **'Document settings are invalid.'**
  String get documentErrorValidation;

  /// No description provided for @documentErrorTenantNotFound.
  ///
  /// In en, this message translates to:
  /// **'Tenant context was not found.'**
  String get documentErrorTenantNotFound;

  /// No description provided for @documentErrorNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Document service is not configured.'**
  String get documentErrorNotConfigured;

  /// No description provided for @documentErrorLogoInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Logo URL must use HTTPS.'**
  String get documentErrorLogoInvalidUrl;

  /// No description provided for @documentErrorLogoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Logo file is too large (max 512 KB).'**
  String get documentErrorLogoTooLarge;

  /// No description provided for @documentErrorLogoInvalidDimensions.
  ///
  /// In en, this message translates to:
  /// **'Logo dimensions are too large (max 4096 px per side, 16 MP total).'**
  String get documentErrorLogoInvalidDimensions;

  /// No description provided for @documentErrorLogoUnsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'Logo must be a PNG or JPEG image.'**
  String get documentErrorLogoUnsupportedFormat;

  /// No description provided for @documentErrorLogoFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download the logo. Check the URL and try again.'**
  String get documentErrorLogoFetchFailed;

  /// No description provided for @customerStatementFromDate.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get customerStatementFromDate;

  /// No description provided for @customerStatementToDate.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get customerStatementToDate;

  /// No description provided for @templateSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Document templates'**
  String get templateSettingsTitle;

  /// No description provided for @templateSettingsPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to view template settings.'**
  String get templateSettingsPermissionDenied;

  /// No description provided for @templateSettingsLogoUrl.
  ///
  /// In en, this message translates to:
  /// **'Logo URL (HTTPS)'**
  String get templateSettingsLogoUrl;

  /// No description provided for @templateSettingsPrimaryColor.
  ///
  /// In en, this message translates to:
  /// **'Primary color (#RRGGBB)'**
  String get templateSettingsPrimaryColor;

  /// No description provided for @templateSettingsSecondaryColor.
  ///
  /// In en, this message translates to:
  /// **'Secondary color (#RRGGBB)'**
  String get templateSettingsSecondaryColor;

  /// No description provided for @templateSettingsDefaultLanguage.
  ///
  /// In en, this message translates to:
  /// **'Default document language'**
  String get templateSettingsDefaultLanguage;

  /// No description provided for @templateSettingsInvoicePaper.
  ///
  /// In en, this message translates to:
  /// **'Invoice paper'**
  String get templateSettingsInvoicePaper;

  /// No description provided for @templateSettingsAssetLabelPaper.
  ///
  /// In en, this message translates to:
  /// **'Asset label paper'**
  String get templateSettingsAssetLabelPaper;

  /// No description provided for @templateSettingsVoucherPaper.
  ///
  /// In en, this message translates to:
  /// **'Voucher paper'**
  String get templateSettingsVoucherPaper;

  /// No description provided for @templateSettingsHeaderSection.
  ///
  /// In en, this message translates to:
  /// **'Document header'**
  String get templateSettingsHeaderSection;

  /// No description provided for @templateSettingsHeaderAr.
  ///
  /// In en, this message translates to:
  /// **'Header text (Arabic)'**
  String get templateSettingsHeaderAr;

  /// No description provided for @templateSettingsHeaderEn.
  ///
  /// In en, this message translates to:
  /// **'Header text (English)'**
  String get templateSettingsHeaderEn;

  /// No description provided for @templateSettingsFooterSection.
  ///
  /// In en, this message translates to:
  /// **'Document footer'**
  String get templateSettingsFooterSection;

  /// No description provided for @templateSettingsFooterAr.
  ///
  /// In en, this message translates to:
  /// **'Footer text (Arabic)'**
  String get templateSettingsFooterAr;

  /// No description provided for @templateSettingsFooterEn.
  ///
  /// In en, this message translates to:
  /// **'Footer text (English)'**
  String get templateSettingsFooterEn;

  /// No description provided for @templateSettingsOptionalColumnsSection.
  ///
  /// In en, this message translates to:
  /// **'Optional columns'**
  String get templateSettingsOptionalColumnsSection;

  /// No description provided for @templateSettingsOptionalSalesInvoice.
  ///
  /// In en, this message translates to:
  /// **'Sales invoice'**
  String get templateSettingsOptionalSalesInvoice;

  /// No description provided for @templateSettingsOptionalPurchaseInvoice.
  ///
  /// In en, this message translates to:
  /// **'Purchase invoice'**
  String get templateSettingsOptionalPurchaseInvoice;

  /// No description provided for @templateSettingsOptionalCustomerStatement.
  ///
  /// In en, this message translates to:
  /// **'Customer statement'**
  String get templateSettingsOptionalCustomerStatement;

  /// No description provided for @templateSettingsOptionalQty.
  ///
  /// In en, this message translates to:
  /// **'Show quantity'**
  String get templateSettingsOptionalQty;

  /// No description provided for @templateSettingsOptionalUnitPrice.
  ///
  /// In en, this message translates to:
  /// **'Show unit price'**
  String get templateSettingsOptionalUnitPrice;

  /// No description provided for @templateSettingsOptionalDebit.
  ///
  /// In en, this message translates to:
  /// **'Show debit'**
  String get templateSettingsOptionalDebit;

  /// No description provided for @templateSettingsOptionalCredit.
  ///
  /// In en, this message translates to:
  /// **'Show credit'**
  String get templateSettingsOptionalCredit;

  /// No description provided for @templateSettingsLanguageAr.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get templateSettingsLanguageAr;

  /// No description provided for @templateSettingsLanguageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get templateSettingsLanguageEn;

  /// No description provided for @templateSettingsLanguageBilingual.
  ///
  /// In en, this message translates to:
  /// **'Bilingual'**
  String get templateSettingsLanguageBilingual;

  /// No description provided for @templateSettingsPaperA4.
  ///
  /// In en, this message translates to:
  /// **'A4'**
  String get templateSettingsPaperA4;

  /// No description provided for @templateSettingsPaperThermal.
  ///
  /// In en, this message translates to:
  /// **'Thermal 80mm'**
  String get templateSettingsPaperThermal;

  /// No description provided for @templateSettingsPaperLabel.
  ///
  /// In en, this message translates to:
  /// **'Label sheet'**
  String get templateSettingsPaperLabel;

  /// No description provided for @templateSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Document settings saved.'**
  String get templateSettingsSaved;

  /// No description provided for @templateSettingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get templateSettingsSave;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
