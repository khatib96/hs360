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
  String get warehouseAdd => 'Add warehouse';

  @override
  String get warehouseEdit => 'Edit warehouse';

  @override
  String get warehouseDeactivate => 'Deactivate warehouse';

  @override
  String get warehouseDeactivateConfirm =>
      'Deactivate this warehouse? It will no longer appear in stock movement choices.';

  @override
  String get warehouseNameAr => 'Arabic name';

  @override
  String get warehouseNameEn => 'English name';

  @override
  String get warehouseType => 'Warehouse type';

  @override
  String get warehouseTypeMain => 'Main';

  @override
  String get warehouseTypeBranch => 'Branch';

  @override
  String get warehouseTypeVan => 'Van';

  @override
  String get warehouseEmployee => 'Employee';

  @override
  String get warehouseEmployeeNone => 'Select employee';

  @override
  String get warehouseEmployeeInactiveHint => 'Inactive employee';

  @override
  String get warehouseLocationAddress => 'Location address';

  @override
  String get warehouseActive => 'Active';

  @override
  String get warehouseInactive => 'Inactive';

  @override
  String get warehouseColumnName => 'Name';

  @override
  String get warehouseColumnType => 'Type';

  @override
  String get warehouseColumnEmployee => 'Employee';

  @override
  String get warehouseColumnAddress => 'Address';

  @override
  String get warehouseColumnStatus => 'Status';

  @override
  String get warehouseListEmpty => 'No warehouses yet.';

  @override
  String get warehouseListError => 'Could not load warehouses. Try again.';

  @override
  String get warehouseValidationAgentRequired =>
      'Select an employee for van warehouses';

  @override
  String get warehouseErrorDuplicateActiveVan =>
      'This employee already has an active van warehouse';

  @override
  String get warehouseErrorUnknown => 'Something went wrong. Try again.';

  @override
  String get warehouseEmployeeLookupFailed =>
      'Could not load employees for van assignment. Van warehouses may be limited until this is fixed.';

  @override
  String get warehouseEmployeeLookupRetry => 'Retry employee lookup';

  @override
  String get inventory => 'Inventory Balances';

  @override
  String get inventoryBalancesEmpty => 'No stock balances yet.';

  @override
  String get inventoryBalancesError =>
      'Could not load inventory balances. Try again.';

  @override
  String get inventoryBalancesProductLabelsFailed =>
      'Product names could not be loaded. Balances are shown with limited labels.';

  @override
  String get inventoryBalancesWarehouseLabelsFailed =>
      'Warehouse names could not be loaded. Balances are shown with limited labels.';

  @override
  String get inventoryBalanceNameUnavailable => 'Unavailable';

  @override
  String get inventoryBalanceProduct => 'Product';

  @override
  String get inventoryBalanceWarehouse => 'Warehouse';

  @override
  String get inventoryBalanceAvailable => 'Available';

  @override
  String get inventoryBalanceRented => 'Rented';

  @override
  String get inventoryBalanceTrial => 'Trial';

  @override
  String get inventoryBalanceMaintenance => 'Maintenance';

  @override
  String get inventoryBalanceDamaged => 'Damaged';

  @override
  String get inventoryBalancesSearchHint => 'Search product or warehouse';

  @override
  String get inventoryBalancesFilterWarehouse => 'Warehouse';

  @override
  String get inventoryBalancesFilterWarehouseAll => 'All warehouses';

  @override
  String get inventoryBalancesFilterLowStock => 'Low stock only';

  @override
  String get inventoryBalancesSummaryTotal => 'Filtered totals';

  @override
  String get inventoryErrorInsufficientStock =>
      'Insufficient stock for this operation.';

  @override
  String get inventoryErrorSerializedAdjustmentNotSupported =>
      'Bulk quantity adjustments are not supported for serialized products. Use product units instead.';

  @override
  String get inventoryManualAdjustment => 'Manual adjustment';

  @override
  String get inventoryAdjustmentTitle => 'Manual stock adjustment';

  @override
  String get inventoryAdjustmentNotes => 'Reason / notes';

  @override
  String get inventoryAdjustmentQuantity => 'Quantity';

  @override
  String get inventoryAdjustmentUnitCost => 'Unit cost';

  @override
  String get inventoryAdjustmentPreviewDelta => 'Available change';

  @override
  String get inventoryAdjustmentPreviewWac =>
      'Estimated average cost after stock-in';

  @override
  String get inventoryAdjustmentStockInRequiresCost =>
      'Stock-in requires full product cost permissions.';

  @override
  String get inventoryAdjustmentProductsViewRequired =>
      'Product search requires products.view permission.';

  @override
  String get inventoryAdjustmentWarehouseRequired => 'Select a warehouse.';

  @override
  String get inventoryAdjustmentProductRequired => 'Select a product.';

  @override
  String get inventoryAdjustmentSuccess => 'Inventory adjustment recorded.';

  @override
  String get inventoryTransferTitle => 'Stock transfer';

  @override
  String get inventoryTransferSourceWarehouse => 'Source warehouse';

  @override
  String get inventoryTransferDestinationWarehouse => 'Destination warehouse';

  @override
  String get inventoryTransferQuantity => 'Quantity';

  @override
  String get inventoryTransferNotes => 'Reason / notes';

  @override
  String get inventoryTransferSelectProduct => 'Search product by name or SKU';

  @override
  String get inventoryTransferPreviewSource => 'Source change';

  @override
  String get inventoryTransferPreviewDestination => 'Destination change';

  @override
  String get inventoryTransferSameWarehouse =>
      'Source and destination must be different warehouses.';

  @override
  String get inventoryTransferSuccess => 'Stock transfer recorded.';

  @override
  String get inventorySourceWarehouseRequired => 'Select a source warehouse.';

  @override
  String get inventoryDestinationWarehouseRequired =>
      'Select a destination warehouse.';

  @override
  String get inventoryErrorSerializedTransferNotSupported =>
      'Stock transfers are not supported for serialized products.';

  @override
  String get inventoryAdjustmentSelectProduct =>
      'Search product by name or SKU';

  @override
  String get inventoryAdjustmentMovementType => 'Movement type';

  @override
  String get productDetailStockByWarehouse => 'By warehouse';

  @override
  String get productDetailStockLowWarning =>
      'Available stock is at or below the reorder point.';

  @override
  String get inventoryMovements => 'Movements Log';

  @override
  String get inventoryTransfers => 'Stock Transfers';

  @override
  String get inventoryMovementsEmpty =>
      'No inventory movements match your filters.';

  @override
  String get inventoryMovementsError =>
      'Could not load inventory movements. Try again.';

  @override
  String get inventoryMovementsProductLabelsFailed =>
      'Product names could not be loaded. Movements are shown with limited labels.';

  @override
  String get inventoryMovementsWarehouseLabelsFailed =>
      'Warehouse names could not be loaded. Movements are shown with limited labels.';

  @override
  String get inventoryMovementsSearchHint => 'Search product name or SKU';

  @override
  String get inventoryMovementsSearchRequiresProducts =>
      'Product name or SKU search requires products.view permission. You can still search by movement IDs and notes.';

  @override
  String get inventoryMovementsFilterWarehouse => 'Warehouse';

  @override
  String get inventoryMovementsFilterWarehouseAll => 'All warehouses';

  @override
  String get inventoryMovementsFilterMovementType => 'Movement type';

  @override
  String get inventoryMovementsFilterMovementTypeAll => 'All types';

  @override
  String get inventoryMovementsFilterDateFrom => 'From date';

  @override
  String get inventoryMovementsFilterDateTo => 'To date';

  @override
  String get inventoryMovementsFilterPageSize => 'Page size';

  @override
  String get inventoryMovementOccurredAt => 'Occurred';

  @override
  String get inventoryMovementType => 'Type';

  @override
  String get inventoryMovementProduct => 'Product';

  @override
  String get inventoryMovementWarehouse => 'Warehouse';

  @override
  String get inventoryMovementQuantity => 'Quantity';

  @override
  String get inventoryMovementReference => 'Reference';

  @override
  String get inventoryMovementCreatedBy => 'Created by';

  @override
  String get inventoryMovementNotes => 'Notes';

  @override
  String get inventoryMovementUnitCost => 'Unit cost';

  @override
  String get inventoryMovementNotesNone => '—';

  @override
  String get inventoryMovementReferenceNone => '—';

  @override
  String get inventoryMovementCreatedByNotRecorded => 'Not recorded';

  @override
  String get inventoryMovementReferenceAdjustment => 'Adjustment';

  @override
  String get inventoryMovementReferenceTransfer => 'Transfer';

  @override
  String get inventoryMovementReferenceProductUnit => 'Product unit';

  @override
  String get inventoryMovementTypePurchase => 'Purchase';

  @override
  String get inventoryMovementTypeSale => 'Sale';

  @override
  String get inventoryMovementTypeRentalOut => 'Rental out';

  @override
  String get inventoryMovementTypeRentalReturn => 'Rental return';

  @override
  String get inventoryMovementTypeRefill => 'Refill';

  @override
  String get inventoryMovementTypeTransferOut => 'Transfer out';

  @override
  String get inventoryMovementTypeTransferIn => 'Transfer in';

  @override
  String get inventoryMovementTypeAdjustmentIn => 'Adjustment in';

  @override
  String get inventoryMovementTypeAdjustmentOut => 'Adjustment out';

  @override
  String get inventoryMovementTypeSaleReturn => 'Sale return';

  @override
  String get inventoryMovementTypePurchaseReturn => 'Purchase return';

  @override
  String get inventoryMovementTypeMaintenanceIn => 'Maintenance in';

  @override
  String get inventoryMovementTypeMaintenanceOut => 'Maintenance out';

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
  String get productModeSale => 'Sale';

  @override
  String get productModeRental => 'Rental';

  @override
  String get productRentalTypeAsset => 'Asset';

  @override
  String get productRentalTypeConsumable => 'Consumable';

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
  String get productFieldMode => 'Product mode';

  @override
  String get productFieldRentalType => 'Rental type';

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
  String get productFieldExpectedLifespan => 'Expected lifespan (months)';

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
  String get productValidationModeRequired => 'Select sale, rental, or both';

  @override
  String get productValidationExpectedLifespan =>
      'Expected lifespan must be a positive whole number';

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

  @override
  String get productUnitsNotSerialized =>
      'Unit tracking applies to serialized products only.';

  @override
  String get productUnitsViewDenied =>
      'You do not have permission to view product units.';

  @override
  String get productUnitsEmpty =>
      'No units yet. Add a unit or bulk import serial numbers.';

  @override
  String get productUnitsHistoryEmpty =>
      'No contract history for this unit yet.';

  @override
  String get productUnitAdd => 'Add unit';

  @override
  String get productUnitBulkAdd => 'Bulk add';

  @override
  String get productUnitEdit => 'Edit unit';

  @override
  String get productUnitFieldSerial => 'Serial number';

  @override
  String get productUnitFieldBarcode => 'Barcode';

  @override
  String get productUnitFieldStatus => 'Status';

  @override
  String get productUnitFieldWarehouse => 'Warehouse';

  @override
  String get productUnitFieldPurchaseCost => 'Purchase cost';

  @override
  String get productUnitFieldHealth => 'Health';

  @override
  String get productUnitFieldAcquired => 'Acquired';

  @override
  String get productUnitFieldNotes => 'Notes';

  @override
  String get productUnitBulkPasteHint =>
      'Paste one serial per line, or CSV: serial,barcode,cost. Simple CSV only (no quoted commas).';

  @override
  String get productUnitBulkPreview => 'Preview';

  @override
  String get productUnitBulkConfirm => 'Create units';

  @override
  String get productUnitHealthGood => 'Good';

  @override
  String get productUnitHealthNeedsService => 'Needs service';

  @override
  String get productUnitHealthDamaged => 'Damaged';

  @override
  String get productUnitHealthLost => 'Lost';

  @override
  String get productUnitStatusAvailableNew => 'Available (new)';

  @override
  String get productUnitStatusAvailableUsed => 'Available (used)';

  @override
  String get productUnitStatusRented => 'Rented';

  @override
  String get productUnitStatusTrial => 'Trial';

  @override
  String get productUnitStatusMaintenance => 'Maintenance';

  @override
  String get productUnitStatusSold => 'Sold';

  @override
  String get productUnitStatusDamaged => 'Damaged';

  @override
  String get productUnitStatusLost => 'Lost';

  @override
  String get productUnitStatusRetired => 'Retired';

  @override
  String get productUnitErrorDuplicateSerial => 'Serial number already exists';

  @override
  String get productUnitErrorNotSerialized => 'This product is not serialized';

  @override
  String get productUnitErrorNotEditable =>
      'This unit cannot be edited in its current status';

  @override
  String get productUnitErrorBulkLimit =>
      'Maximum 100 units per bulk operation';

  @override
  String get productUnitParserEmptySerial =>
      'Empty serial number in pasted list';

  @override
  String get productUnitParserDuplicate => 'Duplicate serial in pasted list';

  @override
  String get productUnitParserInvalidCost =>
      'Invalid purchase cost in pasted list';

  @override
  String get productUnitSectionHistory => 'Contract history';

  @override
  String get productUnitWarehouseTransferHint =>
      'Use Stock Transfers to move stock between warehouses.';

  @override
  String get customers => 'Customers';

  @override
  String get suppliers => 'Suppliers';

  @override
  String get customerDetails => 'Customer details';

  @override
  String get editCustomer => 'Edit customer';

  @override
  String get customerOverview => 'Overview';

  @override
  String get customerStatement => 'Statement';

  @override
  String get customerTimeline => 'Timeline';

  @override
  String get chartOfAccounts => 'Chart of accounts';

  @override
  String get referenceId => 'Reference ID';

  @override
  String get customersListUnavailable =>
      'Customer list is not available in this build.';

  @override
  String get suppliersListUnavailable =>
      'Supplier list is not available in this build.';

  @override
  String get customerDetailsUnavailable =>
      'Details will be enabled when this module is completed.';

  @override
  String get customerEditUnavailable =>
      'Customer editing is not available in this build.';

  @override
  String get supplierDetailsUnavailable =>
      'Supplier details are not available in this build.';

  @override
  String get chartOfAccountsUnavailable =>
      'Chart of accounts view is not available in this build.';

  @override
  String get moduleSectionUnavailable =>
      'This section is not available in this build.';

  @override
  String get moduleAccessUnavailable =>
      'You do not have permission to view this section.';
}
