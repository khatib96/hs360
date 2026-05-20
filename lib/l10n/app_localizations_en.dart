// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'HS360';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get dashboardPhase2Subtitle =>
      'Phase 2 active — authentication, permissions, and routing are ready. Modules arrive in Phase 3.';

  @override
  String get sessionDisplayNameLabel => 'Display name';

  @override
  String get sessionAccountTypeLabel => 'Account type';

  @override
  String get sessionEmailLabel => 'Email';

  @override
  String get sessionTenantLabel => 'Tenant ID';

  @override
  String get accountTypeManager => 'Manager';

  @override
  String get accountTypeUser => 'User';

  @override
  String get language => 'Language';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageEnglish => 'English';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle => 'Enter your account details to continue';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get backToLogin => 'Back to sign in';

  @override
  String get logout => 'Sign out';

  @override
  String get loading => 'Loading…';

  @override
  String get retry => 'Retry';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get validationEmailRequired => 'Enter your email';

  @override
  String get validationEmailInvalid => 'Enter a valid email address';

  @override
  String get validationPasswordRequired => 'Enter your password';

  @override
  String get authErrorInvalidCredentials => 'Invalid email or password';

  @override
  String get authErrorNetworkUnavailable =>
      'Could not connect. Check your network or local Supabase';

  @override
  String get authErrorNoActiveTenantUser =>
      'No active tenant account is linked to this user';

  @override
  String get authErrorUserInactive => 'This user account is inactive';

  @override
  String get authErrorSupabaseNotConfigured => 'Supabase is not configured';

  @override
  String get authErrorUnknown =>
      'An unexpected error occurred. Please try again';

  @override
  String get authMissingAnonKey =>
      'Local Supabase key is missing. Run the app via scripts/run-local.ps1';

  @override
  String get authInitFailed =>
      'Could not initialize Supabase. Check that local services are running';

  @override
  String get resetPasswordSuccess =>
      'If the email is registered, password reset instructions will be sent.';

  @override
  String get forgotPasswordTitle => 'Reset password';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your email and we will send reset instructions if the account exists';

  @override
  String get fieldTodayTitle => 'Today';

  @override
  String get fieldTodayPlaceholder =>
      'Assigned visits will appear here in a later phase.';

  @override
  String get blockedTitle => 'No access';

  @override
  String get blockedMessage =>
      'Your account has no assigned permissions. Contact your manager for access.';

  @override
  String get products => 'Products';

  @override
  String get productsNew => 'New Product';

  @override
  String get productsDetail => 'Product Details';

  @override
  String get warehouses => 'Warehouses';

  @override
  String get inventory => 'Inventory Balances';

  @override
  String get inventoryMovements => 'Movements Log';

  @override
  String get inventoryTransfers => 'Stock Transfers';

  @override
  String get productsSearchHint => 'Search SKU, name, or barcode';

  @override
  String get productsListEmpty => 'No products match your filters.';

  @override
  String get productsListError => 'Could not load products. Try again.';

  @override
  String get productsNotAvailable => '—';

  @override
  String get productsGroupUnavailable => 'Unavailable';

  @override
  String get productsAllGroups => 'All products';

  @override
  String get productsFilterType => 'Type';

  @override
  String get productsFilterActive => 'Status';

  @override
  String get productsFilterStock => 'Stock';

  @override
  String get productsFilterClear => 'Clear filters';

  @override
  String get productsFilterAll => 'All';

  @override
  String get productsFilterActiveOnly => 'Active only';

  @override
  String get productsFilterInactiveOnly => 'Inactive only';

  @override
  String get productTypeSaleOnly => 'Sale only';

  @override
  String get productTypeAssetRental => 'Asset rental';

  @override
  String get productTypeConsumableRental => 'Consumable rental';

  @override
  String get productStatusActive => 'Active';

  @override
  String get productStatusInactive => 'Inactive';

  @override
  String get productStockIn => 'In stock';

  @override
  String get productStockOut => 'Out of stock';

  @override
  String get productStockLow => 'Low stock';

  @override
  String get productColumnSku => 'SKU';

  @override
  String get productColumnName => 'Name';

  @override
  String get productColumnGroup => 'Group';

  @override
  String get productColumnType => 'Type';

  @override
  String get productColumnSalePrice => 'Sale price';

  @override
  String get productColumnRentalPrice => 'Rental price';

  @override
  String get productColumnStock => 'Stock';

  @override
  String get productColumnActive => 'Status';

  @override
  String get productColumnAvgCost => 'Avg cost';

  @override
  String get productColumnLastPurchaseCost => 'Last purchase';

  @override
  String get productColumnMinSalePrice => 'Min sale price';

  @override
  String get productGroupAdd => 'Add group';

  @override
  String get productGroupEdit => 'Edit group';

  @override
  String get productGroupDeactivate => 'Deactivate group';

  @override
  String get productGroupDeactivateConfirm => 'Deactivate this product group?';

  @override
  String get productGroupNameAr => 'Arabic name';

  @override
  String get productGroupNameEn => 'English name';

  @override
  String get productGroupParent => 'Parent group';

  @override
  String get productGroupActive => 'Active';

  @override
  String get productGroupNone => 'None';

  @override
  String get productGroupValidationNameRequired =>
      'Enter Arabic and English names';

  @override
  String get productsGroupsTitle => 'Product groups';

  @override
  String get productsEdit => 'Edit Product';

  @override
  String get productEditAction => 'Edit';

  @override
  String get productWizardStepIdentity => 'Identity';

  @override
  String get productWizardStepUnits => 'Units';

  @override
  String get productWizardStepPricing => 'Pricing';

  @override
  String get productWizardStepFlags => 'Details';

  @override
  String get productWizardStepReview => 'Review';

  @override
  String get productWizardNext => 'Next';

  @override
  String get productWizardBack => 'Back';

  @override
  String get productWizardSubmit => 'Save product';

  @override
  String get productWizardCreateTitle => 'New product';

  @override
  String get productFieldSku => 'SKU';

  @override
  String get productFieldNameAr => 'Arabic name';

  @override
  String get productFieldNameEn => 'English name';

  @override
  String get productFieldGroup => 'Product group';

  @override
  String get productFieldType => 'Product type';

  @override
  String get productFieldUnitPrimary => 'Primary unit';

  @override
  String get productFieldUnitSecondary => 'Secondary unit';

  @override
  String get productFieldConversionFactor => 'Conversion factor';

  @override
  String get productFieldSalePrice => 'Sale price';

  @override
  String get productFieldMinSalePrice => 'Min sale price';

  @override
  String get productFieldRentalPrice => 'Monthly rental price';

  @override
  String get productFieldAvgCost => 'Average cost';

  @override
  String get productFieldLastPurchaseCost => 'Last purchase cost';

  @override
  String get productFieldBarcode => 'Barcode';

  @override
  String get productFieldSerialized => 'Serialized product';

  @override
  String get productFieldMaintenance => 'Trackable for maintenance';

  @override
  String get productFieldReorderPoint => 'Reorder point';

  @override
  String get productFieldActive => 'Active';

  @override
  String get productSectionOverview => 'Overview';

  @override
  String get productSectionPricing => 'Pricing';

  @override
  String get productSectionUnits => 'Units';

  @override
  String get productSectionInventory => 'Inventory';

  @override
  String get productSectionAudit => 'Audit';

  @override
  String get productDetailNotFound => 'Product not found.';

  @override
  String get productDetailLoadError => 'Could not load product. Try again.';

  @override
  String get productDetailStockUnavailable => 'Stock summary unavailable.';

  @override
  String get productDetailStockTotal => 'Total available';

  @override
  String get productDetailCreatedAt => 'Created';

  @override
  String get productDetailUpdatedAt => 'Updated';

  @override
  String get productImageAdd => 'Add image';

  @override
  String get productImageChange => 'Change image';

  @override
  String get productImageUploading => 'Uploading image…';

  @override
  String productCreatedSuccess(String sku) {
    return 'Product $sku created successfully.';
  }

  @override
  String get productSavedSuccess => 'Product saved.';

  @override
  String get productGroupsPermissionRequired =>
      'You need product group access to create products.';

  @override
  String get productValidationSkuRequired => 'SKU is required';

  @override
  String get productValidationNameArRequired => 'Arabic name is required';

  @override
  String get productValidationNameEnRequired => 'English name is required';

  @override
  String get productValidationGroupRequired => 'Product group is required';

  @override
  String get productValidationConversionInvalid =>
      'Invalid conversion factor for selected units';

  @override
  String get productValidationSaleBelowMin =>
      'Sale price cannot be below minimum sale price';

  @override
  String get productValidationRentalRequired =>
      'Rental price is required for rental products';

  @override
  String get productValidationSerializedPiece =>
      'Serialized products must use piece as primary unit';

  @override
  String get productValidationNegative => 'Value cannot be negative';

  @override
  String get productValidationInvalidDecimal => 'Enter a valid number';

  @override
  String get productValidationFailed => 'Please fix the highlighted fields';

  @override
  String get productErrorPermissionDenied =>
      'You do not have permission for this action';

  @override
  String get productErrorDuplicateSku => 'SKU already exists';

  @override
  String get productErrorDuplicateBarcode => 'Barcode already exists';

  @override
  String get productErrorFieldNotSupported => 'This field is not supported yet';

  @override
  String get productErrorImageType => 'Image must be JPG, PNG, or WebP';

  @override
  String get productErrorImageSize => 'Image must be 5 MB or smaller';

  @override
  String get productErrorUnknown => 'Something went wrong. Try again.';

  @override
  String get productSerializedLocked =>
      'Cannot change serialization while stock exists or is unknown';

  @override
  String get productNoSecondaryUnit => 'None';

  @override
  String get productWizardReviewTitle => 'Review before saving';
}
