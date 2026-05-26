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
  /// **'Warehouse changes use inventory transfer (coming soon).'**
  String get productUnitWarehouseTransferHint;
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
