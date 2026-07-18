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
  String get loadMore => 'Load more';

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
      'Local Supabase key is missing. Start the app with the local run script';

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
  String get productSerialTrackingPrepare => 'Prepare serial tracking';

  @override
  String get productSerialTrackingPrefix => 'Serial prefix';

  @override
  String get productSerialTrackingStart => 'Start number';

  @override
  String get productSerialTrackingCount => 'Available count';

  @override
  String get productSerialTrackingGenerate => 'Generate serials';

  @override
  String get productSerialTrackingSerials => 'Serial numbers';

  @override
  String get productSerialTrackingReason => 'Reason';

  @override
  String get productSerialTrackingConfirm => 'Activate tracking';

  @override
  String get productSerialTrackingPrepared => 'Serial tracking prepared.';

  @override
  String get productSerialTrackingValidation =>
      'Select a warehouse, generate exactly the available count, and enter a reason.';

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
  String get customerProfile => 'Profile';

  @override
  String get customerContracts => 'Contracts';

  @override
  String get customerInvoices => 'Invoices';

  @override
  String get customerVouchers => 'Vouchers';

  @override
  String get customerNotFound => 'Customer not found.';

  @override
  String get customerPrimaryLocationSummary => 'Primary location';

  @override
  String get customerAccountNotLinked => 'No linked A/R account';

  @override
  String get customerAccountIdLabel => 'Account ID';

  @override
  String get customerLedgerPermissionDenied =>
      'You do not have permission to view this customer\'s ledger.';

  @override
  String get customerStatementEmpty => 'No ledger movements yet.';

  @override
  String get customerStatementNotLoaded =>
      'Open this tab to load the statement.';

  @override
  String get customerStatementSummaryTitle => 'Account summary';

  @override
  String get customerStatementDebit => 'Debit';

  @override
  String get customerStatementCredit => 'Credit';

  @override
  String get customerStatementBalance => 'Balance';

  @override
  String get customerStatementColumnDate => 'Date';

  @override
  String get customerStatementColumnEntry => 'Entry';

  @override
  String get customerStatementColumnSource => 'Source';

  @override
  String get customerStatementColumnDescription => 'Description';

  @override
  String get customerContractsEmpty => 'No contracts yet.';

  @override
  String get customerContractsPrepared =>
      'Contract list for this customer will appear here once available.';

  @override
  String get customerContractsNotLoaded => 'Open this tab to load contracts.';

  @override
  String get contractTitle => 'Contracts';

  @override
  String get contractDetailTitle => 'Contract';

  @override
  String get contractPreviewAction => 'Preview contract PDF';

  @override
  String get pdfDraftWatermark => 'DRAFT';

  @override
  String get contractCreateTitle => 'New contract';

  @override
  String get contractConvertTitle => 'Convert trial';

  @override
  String get contractListPrepared =>
      'Contract list will appear here once available.';

  @override
  String get contractCreatePrepared =>
      'Contract creation will open here once ready.';

  @override
  String get contractDetailPrepared =>
      'Contract details will appear here once available.';

  @override
  String get contractConvertPrepared =>
      'Trial conversion will open here once ready.';

  @override
  String get contractCreateNew => 'New contract';

  @override
  String get contractViewAll => 'All contracts';

  @override
  String get contractTypeTrial => 'Trial';

  @override
  String get contractTypeRental => 'Rental';

  @override
  String get contractStatusDraft => 'Draft';

  @override
  String get contractStatusActive => 'Active';

  @override
  String get contractStatusSuspended => 'Suspended';

  @override
  String get contractStatusCompleted => 'Completed';

  @override
  String get contractStatusTerminatedEarly => 'Terminated early';

  @override
  String get contractStatusExpired => 'Expired';

  @override
  String get contractColumnNumber => 'Contract #';

  @override
  String get contractColumnType => 'Type';

  @override
  String get contractColumnStatus => 'Status';

  @override
  String get contractColumnStartDate => 'Start date';

  @override
  String get contractColumnDates => 'Dates';

  @override
  String get contractColumnMonthlyValue => 'Monthly value';

  @override
  String get contractColumnCustomer => 'Customer';

  @override
  String get contractColumnServiceLocation => 'Service location';

  @override
  String get contractListEmpty => 'No contracts yet.';

  @override
  String get contractListEmptyFiltered => 'No contracts match your filters.';

  @override
  String get contractFilterType => 'Type';

  @override
  String get contractFilterSearchHint =>
      'Search by contract #, customer, phone, governorate, or area';

  @override
  String get contractFilterLowProfitOverride => 'Low-profit override only';

  @override
  String get contractSectionOverview => 'Overview';

  @override
  String get contractSectionAssets => 'Assets';

  @override
  String get contractSectionConsumables => 'Consumables';

  @override
  String get contractSectionLifecycle => 'Lifecycle';

  @override
  String get contractSectionPricingSnapshot => 'Pricing snapshot';

  @override
  String get contractFieldEndDate => 'End date';

  @override
  String get contractFieldTrialEndDate => 'Trial end';

  @override
  String get contractFieldBillingDay => 'Billing day';

  @override
  String get contractFieldRefillDay => 'Refill day';

  @override
  String get contractFieldNotes => 'Notes';

  @override
  String get contractFieldSerialNumber => 'Serial';

  @override
  String get contractFieldProduct => 'Product';

  @override
  String get contractFieldQtyPerRefill => 'Qty per refill';

  @override
  String get contractFieldRefillFrequency => 'Refill frequency (months)';

  @override
  String get contractFieldMonthlyCost => 'Monthly cost';

  @override
  String get contractFieldUnitCost => 'Unit cost';

  @override
  String get contractFieldDeviceMonthlyCost => 'Device monthly cost';

  @override
  String get contractFieldOilMonthlyCost => 'Consumable monthly cost';

  @override
  String get contractFieldTotalMonthlyCost => 'Total monthly cost';

  @override
  String get contractFieldMonthlyProfit => 'Monthly profit';

  @override
  String get contractFieldNetMonthlyProfit => 'Net monthly profit';

  @override
  String get contractFieldConvertedFrom => 'Converted from';

  @override
  String get contractFieldConvertedTo => 'Converted to';

  @override
  String get contractFieldReturnReason => 'Return reason';

  @override
  String get contractFieldClosureReason => 'Closure reason';

  @override
  String get contractFieldOverrideReason => 'Override reason';

  @override
  String get contractAssetsEmpty => 'No asset lines on this contract.';

  @override
  String get contractConsumablesEmpty =>
      'No consumable lines on this contract.';

  @override
  String get contractLifecycleEmpty => 'No lifecycle metadata recorded yet.';

  @override
  String get contractSectionProducts => 'Products';

  @override
  String get contractSectionValueSummary => 'Contract value';

  @override
  String get contractFinancialDetails => 'Cost and profitability';

  @override
  String get contractSectionUpcomingSchedule => 'Upcoming schedule';

  @override
  String get contractSectionHistory => 'History';

  @override
  String get contractFieldProductType => 'Type';

  @override
  String get contractFieldQuantity => 'Quantity';

  @override
  String get contractFieldFrequency => 'Frequency';

  @override
  String get contractFieldContractDuration => 'Duration';

  @override
  String contractDurationMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get contractFieldTotalContractValue => 'Total contract value';

  @override
  String get contractFieldMonthlyRentalValue => 'Monthly rental value';

  @override
  String get contractNextVisit => 'Next visit';

  @override
  String get contractNextPayment => 'Next payment';

  @override
  String contractRemainingDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days remaining',
      one: '1 day remaining',
    );
    return '$_temp0';
  }

  @override
  String contractRemainingDaysOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '-$_temp0';
  }

  @override
  String get contractOverdue => 'Overdue';

  @override
  String get contractProductsEmpty => 'No products on this contract.';

  @override
  String get contractScheduleEmpty =>
      'No upcoming visits or payments scheduled yet.';

  @override
  String get contractScheduleEventTrialEnding => 'Trial ending';

  @override
  String get contractScheduleEventBillingDue => 'Billing due';

  @override
  String get contractScheduleEventRefillDue => 'Refill due';

  @override
  String get contractScheduleEventContractEnd => 'Contract end';

  @override
  String get contractScheduleEventConsumableChange =>
      'Includes consumable change';

  @override
  String get contractScheduleRemaining => 'Remaining';

  @override
  String get contractHistoryEmpty => 'No contract history recorded yet.';

  @override
  String get contractProductTypeAsset => 'Device';

  @override
  String get contractProductTypeConsumable => 'Consumable';

  @override
  String get contractConvertLink => 'Convert to rental';

  @override
  String get contractConvertAction => 'Convert to rental';

  @override
  String get contractConvertConfirmTitle => 'Convert trial';

  @override
  String get contractConvertConfirmBody =>
      'Convert this trial into a rental contract with the entered terms?';

  @override
  String get contractExtendTrialTitle => 'Extend trial';

  @override
  String get contractExtendTrialAction => 'Extend trial';

  @override
  String get contractReturnTrialTitle => 'Return trial';

  @override
  String get contractReturnTrialAction => 'Return trial';

  @override
  String get contractCloseRentalTitle => 'Close rental';

  @override
  String get contractCloseRentalAction => 'Close rental';

  @override
  String get contractFieldExtensionReason => 'Extension reason';

  @override
  String get contractFieldChangeReason => 'Change reason';

  @override
  String get contractFieldEffectiveDate => 'Effective date';

  @override
  String get contractFieldConversionStartDate => 'Conversion start date';

  @override
  String get contractFieldCloseDate => 'Close date';

  @override
  String get contractFieldClosedAt => 'Closed on';

  @override
  String get contractFieldReturnedAt => 'Returned on';

  @override
  String get contractFieldReturnCondition => 'Return condition';

  @override
  String get contractFieldClosureType => 'Closure type';

  @override
  String get contractClosureTypeNormal => 'Normal completion';

  @override
  String get contractClosureTypeEarlyTermination => 'Early termination';

  @override
  String get contractReturnConditionAvailableUsed => 'Available (used)';

  @override
  String get contractReturnConditionMaintenance => 'Maintenance';

  @override
  String get contractReturnConditionDamaged => 'Damaged';

  @override
  String get contractReturnConditionLost => 'Lost';

  @override
  String get contractErrorManualWarehouseResolutionRequired =>
      'This contract line needs manual warehouse resolution before it can be released.';

  @override
  String get contractErrorConsumableScheduleConflict =>
      'A future consumable change is already scheduled for this line.';

  @override
  String get contractConsumableCurrent => 'Current consumable';

  @override
  String contractConsumableScheduledBanner(String date) {
    return 'A consumable change is already scheduled for $date.';
  }

  @override
  String get contractScheduleConsumableAction => 'Schedule consumable change';

  @override
  String get contractCollectRentalAction => 'Collect rental';

  @override
  String get contractCollectRentalTitle => 'Collect rental payment';

  @override
  String get contractCollectCoverageMonths => 'Coverage months';

  @override
  String get contractCollectCollectionDate => 'Collection date';

  @override
  String get contractCollectPaymentMethod => 'Payment method';

  @override
  String get contractCollectCashAccount => 'Cash/bank account';

  @override
  String get contractCollectReferenceNo => 'Reference';

  @override
  String get contractCollectExpectedAmount => 'Expected collected amount';

  @override
  String get contractCollectPreviewSubtotal => 'Subtotal';

  @override
  String get contractCollectPreviewTax => 'Tax';

  @override
  String get contractCollectPreviewTotal => 'Invoice total';

  @override
  String get contractCollectConfirmAction => 'Confirm collection';

  @override
  String get contractCollectViewInvoice => 'View invoice';

  @override
  String get contractCollectViewReceipt => 'View receipt';

  @override
  String get contractCollectSuccess => 'Rental payment collected successfully.';

  @override
  String get contractCollectNoEligibleMonths =>
      'No eligible coverage months remain for this contract.';

  @override
  String get contractCollectCashAccountsUnavailable =>
      'Cash/bank accounts are unavailable for this session.';

  @override
  String get contractCreateTrial => 'Create trial';

  @override
  String get contractCreateRental => 'Create rental';

  @override
  String get contractCreateConfirmTitle => 'Create contract';

  @override
  String get contractCreateConfirmBody =>
      'Create this contract with the entered lines and terms?';

  @override
  String get contractAddRentalProduct => 'Add rental product';

  @override
  String get contractAddAssetLine => 'Add device';

  @override
  String get contractAddConsumableLine => 'Add consumable';

  @override
  String get contractRemoveLine => 'Remove line';

  @override
  String get contractSerialOrBarcode => 'Serial or barcode';

  @override
  String get contractResolveSerial => 'Resolve serial/barcode';

  @override
  String get contractTrialDaysLabel => 'Trial days';

  @override
  String get contractTermTwelveMonths => '12-month term';

  @override
  String get contractLowProfitWarning =>
      'Monthly profit is below the minimum threshold.';

  @override
  String get contractRequestOverride => 'Request profit override';

  @override
  String get contractRefreshPreview => 'Refresh pricing preview';

  @override
  String get contractCustomerSelectFirst => 'Select a customer first.';

  @override
  String get contractSelectProductFirst => 'Select a product first.';

  @override
  String get contractNoAvailableUnits => 'No available units for this product.';

  @override
  String get customerInvoicesEmpty => 'No invoices yet.';

  @override
  String get customerInvoicesNotLoaded => 'Open this tab to load invoices.';

  @override
  String get customerVouchersEmpty => 'No vouchers yet.';

  @override
  String get customerVouchersNotLoaded =>
      'Open this tab to load receipt vouchers.';

  @override
  String get customerTimelineEmpty => 'No timeline events yet.';

  @override
  String get customerTimelineCreated => 'Customer created';

  @override
  String get customerTimelineUpdated => 'Profile updated';

  @override
  String get customerTimelineAcquired => 'Customer acquired';

  @override
  String get journalSourceManual => 'Manual entry';

  @override
  String get journalSourceSalesInvoice => 'Sales invoice';

  @override
  String get journalSourcePurchaseInvoice => 'Purchase invoice';

  @override
  String get journalSourceReceiptVoucher => 'Receipt voucher';

  @override
  String get journalSourcePaymentVoucher => 'Payment voucher';

  @override
  String get journalSourceRentalInvoice => 'Rental invoice';

  @override
  String get journalSourceContractCreation => 'Contract creation';

  @override
  String get journalSourceContractClosure => 'Contract closure';

  @override
  String get journalSourceOpeningBalance => 'Opening balance';

  @override
  String get journalSourceInventoryAdjustment => 'Inventory adjustment';

  @override
  String get journalSourceSalaryPayment => 'Salary payment';

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
  String get customerDetailsUnavailable => 'Customer not found or unavailable.';

  @override
  String get customerEditUnavailable =>
      'Customer editing is not available in this build.';

  @override
  String get supplierDetailsUnavailable =>
      'Supplier details are not available in this build.';

  @override
  String get supplierNotFound => 'Supplier not found.';

  @override
  String get supplierPurchaseInvoices => 'Purchase invoices';

  @override
  String get supplierPaymentVouchers => 'Payment vouchers';

  @override
  String get supplierStatement => 'Statement';

  @override
  String get supplierStatementUnavailable =>
      'Supplier statement requires backend support (get_supplier_statement). This will be available in a future release.';

  @override
  String get supplierInvoicesEmpty => 'No purchase invoices yet.';

  @override
  String get supplierInvoicesNotLoaded =>
      'Open this tab to load purchase invoices.';

  @override
  String get supplierVouchersEmpty => 'No payment vouchers yet.';

  @override
  String get supplierVouchersNotLoaded =>
      'Open this tab to load payment vouchers.';

  @override
  String get chartOfAccountsUnavailable =>
      'Chart of accounts view is not available in this build.';

  @override
  String get moduleSectionUnavailable =>
      'This section is not available in this build.';

  @override
  String get moduleAccessUnavailable =>
      'You do not have permission to view this section.';

  @override
  String get createCustomerTitle => 'New customer';

  @override
  String get customerSearchHint => 'Search by code, name, phone, email';

  @override
  String get customerFilterStatus => 'Status';

  @override
  String get customerFilterAll => 'All';

  @override
  String get customerStatusActive => 'Active';

  @override
  String get customerStatusInactive => 'Inactive';

  @override
  String get customerFilterVip => 'VIP';

  @override
  String get customerVip => 'VIP';

  @override
  String get customerNonVip => 'Standard';

  @override
  String get customerClearFilters => 'Clear filters';

  @override
  String get customerTypeLabel => 'Type';

  @override
  String get customerTypeIndividual => 'Individual';

  @override
  String get customerTypeCompany => 'Company';

  @override
  String get customerColumnCode => 'Code';

  @override
  String get customerColumnName => 'Name';

  @override
  String get customerColumnPhone => 'Phone';

  @override
  String get customerColumnType => 'Type';

  @override
  String get customerColumnLocation => 'Location';

  @override
  String get customerColumnStatus => 'Status';

  @override
  String get customerActionView => 'View';

  @override
  String get customerActionEdit => 'Edit';

  @override
  String get customerActionDeactivate => 'Deactivate';

  @override
  String get customerAdd => 'Add customer';

  @override
  String get customerListEmpty => 'No customers yet.';

  @override
  String get customerListEmptyFiltered => 'No customers match your filters.';

  @override
  String get customerDeactivateConfirmTitle => 'Deactivate customer';

  @override
  String get customerDeactivateConfirmBody =>
      'This customer will be hidden from the active list. You can still find them by switching the status filter. Continue?';

  @override
  String get customerCreated => 'Customer created.';

  @override
  String get customerUpdated => 'Customer saved.';

  @override
  String get customerDeactivated => 'Customer deactivated.';

  @override
  String get customerFieldCode => 'Code';

  @override
  String get customerFieldNameAr => 'Name';

  @override
  String get customerFieldNameEn => 'Name (English)';

  @override
  String get customerFieldContactName => 'Contact person';

  @override
  String get customerFieldContactPhone => 'Contact phone';

  @override
  String get customerFieldPhonePrimary => 'Primary phone';

  @override
  String get customerFieldEmail => 'Email';

  @override
  String get customerFieldTaxNumber => 'Tax number';

  @override
  String get customerFieldAddress => 'Address details';

  @override
  String get customerFieldArea => 'Area';

  @override
  String get customerFieldGovernorate => 'Governorate';

  @override
  String get customerFieldCountry => 'Country';

  @override
  String get customerFieldGoogleMapsUrl => 'Google Maps link';

  @override
  String get customerFieldVip => 'VIP customer';

  @override
  String get customerFieldNotes => 'Notes';

  @override
  String get customerFieldCreateAccount => 'Create accounting account';

  @override
  String get customerFieldCreateAccountHint =>
      'Links an A/R subaccount under receivables.';

  @override
  String get customerLinkedAccountYes => 'Linked accounting account';

  @override
  String get customerLinkedAccountNo => 'No accounting account';

  @override
  String get customerEnsureAccount => 'Create accounting account';

  @override
  String get customerAccountLinked => 'Accounting account linked.';

  @override
  String get customerSectionIdentity => 'Identity';

  @override
  String get customerSectionContact => 'Contact';

  @override
  String get customerSectionLocation => 'Location';

  @override
  String get customerSectionAccounting => 'Accounting';

  @override
  String get customerValidationNameArRequired => 'Arabic name is required.';

  @override
  String get customerValidationPhoneRequired => 'Primary phone is required.';

  @override
  String get customerValidationEmailInvalid => 'Enter a valid email address.';

  @override
  String get customerValidationFailed =>
      'Could not save the customer. Please check the values.';

  @override
  String get customerErrorPermissionDenied =>
      'You do not have permission to perform this action.';

  @override
  String get customerErrorAccountAlreadyLinked =>
      'This profile already has a linked accounting account.';

  @override
  String get customerErrorUnknown => 'Something went wrong. Please try again.';

  @override
  String get locationAreaOther => 'Other (custom)';

  @override
  String get locationEnterCustomArea => 'Enter area manually';

  @override
  String get locationUseCatalogArea => 'Choose from list';

  @override
  String get createSupplierTitle => 'New supplier';

  @override
  String get editSupplierTitle => 'Edit supplier';

  @override
  String get supplierSearchHint => 'Search by code, name, phone, email';

  @override
  String get supplierFilterStatus => 'Status';

  @override
  String get supplierFilterAll => 'All';

  @override
  String get supplierStatusActive => 'Active';

  @override
  String get supplierStatusInactive => 'Inactive';

  @override
  String get supplierClearFilters => 'Clear filters';

  @override
  String get supplierColumnCode => 'Code';

  @override
  String get supplierColumnName => 'Name';

  @override
  String get supplierColumnPhone => 'Phone';

  @override
  String get supplierColumnEmail => 'Email';

  @override
  String get supplierColumnLocation => 'Location';

  @override
  String get supplierColumnStatus => 'Status';

  @override
  String get supplierActionView => 'View';

  @override
  String get supplierActionEdit => 'Edit';

  @override
  String get supplierActionDeactivate => 'Deactivate';

  @override
  String get supplierAdd => 'Add supplier';

  @override
  String get supplierListEmpty => 'No suppliers yet.';

  @override
  String get supplierListEmptyFiltered => 'No suppliers match your filters.';

  @override
  String get supplierDeactivateConfirmTitle => 'Deactivate supplier';

  @override
  String get supplierDeactivateConfirmBody =>
      'This supplier will be hidden from the active list. You can still find them by switching the status filter. Continue?';

  @override
  String get supplierCreated => 'Supplier created.';

  @override
  String get supplierUpdated => 'Supplier saved.';

  @override
  String get supplierDeactivated => 'Supplier deactivated.';

  @override
  String get supplierFieldCode => 'Code';

  @override
  String get supplierFieldNameAr => 'Name (Arabic)';

  @override
  String get supplierFieldNameEn => 'Name (English)';

  @override
  String get supplierFieldPhone => 'Phone';

  @override
  String get supplierFieldEmail => 'Email';

  @override
  String get supplierFieldTaxNumber => 'Tax number';

  @override
  String get supplierFieldAddress => 'Address details';

  @override
  String get supplierFieldGoogleMapsUrl => 'Google Maps link';

  @override
  String get supplierFieldNotes => 'Notes';

  @override
  String get supplierFieldCreateAccount => 'Create accounting account';

  @override
  String get supplierFieldCreateAccountHint =>
      'Links an A/P subaccount under payables.';

  @override
  String get supplierLinkedAccountYes => 'Linked accounting account';

  @override
  String get supplierLinkedAccountNo => 'No accounting account';

  @override
  String get supplierEnsureAccount => 'Create accounting account';

  @override
  String get supplierAccountLinked => 'Accounting account linked.';

  @override
  String get supplierSectionIdentity => 'Identity';

  @override
  String get supplierSectionContact => 'Contact';

  @override
  String get supplierSectionLocation => 'Location';

  @override
  String get supplierSectionAccounting => 'Accounting';

  @override
  String get supplierValidationNameArRequired => 'Arabic name is required.';

  @override
  String get supplierValidationEmailInvalid => 'Enter a valid email address.';

  @override
  String get supplierValidationFailed =>
      'Could not save the supplier. Please check the values.';

  @override
  String get supplierErrorPermissionDenied =>
      'You do not have permission to perform this action.';

  @override
  String get supplierErrorAccountAlreadyLinked =>
      'This profile already has a linked accounting account.';

  @override
  String get supplierErrorUnknown => 'Something went wrong. Please try again.';

  @override
  String get customerLocations => 'Locations';

  @override
  String get serviceLocationPrimary => 'Primary';

  @override
  String get serviceLocationAdd => 'Add location';

  @override
  String get serviceLocationEdit => 'Edit location';

  @override
  String get serviceLocationDeactivate => 'Deactivate';

  @override
  String get serviceLocationSetPrimary => 'Set as primary';

  @override
  String get serviceLocationEmpty => 'No service locations yet.';

  @override
  String get serviceLocationInUse =>
      'This location is still used by a contract, visit, calendar event, or device.';

  @override
  String get serviceLocationPrimaryRequired =>
      'Set another active location as primary before deactivating this one.';

  @override
  String get serviceLocationValidationNameRequired =>
      'Location name is required.';

  @override
  String get primaryLocationLabel => 'Primary location';

  @override
  String get customerAddressBecomesPrimaryLocation =>
      'Address fields create a primary service location for this customer.';

  @override
  String get serviceLocationFieldName => 'Location name';

  @override
  String get serviceLocationFieldType => 'Type';

  @override
  String get serviceLocationFieldContactName => 'Responsible person';

  @override
  String get serviceLocationFieldContactPhone => 'Responsible phone';

  @override
  String get serviceLocationFieldContactEmail => 'Responsible email';

  @override
  String get serviceLocationFieldLatitude => 'Latitude';

  @override
  String get serviceLocationFieldLongitude => 'Longitude';

  @override
  String get serviceLocationCoordinatesSection => 'Coordinates';

  @override
  String get serviceLocationCoordinatesHint =>
      'Paste a Google Maps link. Coordinates are extracted automatically and are not entered manually.';

  @override
  String get googleMapsLinkResolutionHint =>
      'Paste a Google Maps link to extract the location automatically.';

  @override
  String get googleMapsResolveLink => 'Extract location';

  @override
  String googleMapsCoordinatesResolved(String latitude, String longitude) {
    return 'Location extracted: $latitude, $longitude';
  }

  @override
  String get googleMapsLinkInvalid => 'Enter a valid Google Maps link.';

  @override
  String get googleMapsCoordinatesNotFound =>
      'Coordinates could not be extracted from this Google Maps link.';

  @override
  String get googleMapsResolutionFailed =>
      'The Google Maps link could not be resolved. Check the connection and try again.';

  @override
  String get serviceLocationUseCurrentLocation => 'Use current location';

  @override
  String get serviceLocationClearCoordinates => 'Clear coordinates';

  @override
  String get serviceLocationCoordinatePairRequired =>
      'Enter both latitude and longitude.';

  @override
  String get serviceLocationLatitudeInvalid =>
      'Latitude must be between -90 and 90.';

  @override
  String get serviceLocationLongitudeInvalid =>
      'Longitude must be between -180 and 180.';

  @override
  String get serviceLocationCoordinateMetadataInvalid =>
      'Coordinate source or quality information is invalid.';

  @override
  String get serviceLocationCoordinatesCaptured => 'Current location captured.';

  @override
  String get serviceLocationCoordinateSource => 'Source';

  @override
  String get serviceLocationCoordinateSourceMapPick => 'Map selection';

  @override
  String get serviceLocationCoordinateSourceDeviceGps => 'Device GPS';

  @override
  String get serviceLocationCoordinateSourceUrl => 'Resolved map link';

  @override
  String get serviceLocationCoordinateSourceManual => 'Manual entry';

  @override
  String get serviceLocationCoordinateResolvedAt => 'Resolved';

  @override
  String serviceLocationCoordinateAccuracy(String meters) {
    return 'Accuracy: $meters m';
  }

  @override
  String get serviceLocationTypeBranch => 'Branch';

  @override
  String get serviceLocationTypeOffice => 'Office';

  @override
  String get serviceLocationTypeWarehouse => 'Warehouse';

  @override
  String get serviceLocationTypeHome => 'Home';

  @override
  String get serviceLocationTypeInstallationSite => 'Installation site';

  @override
  String get serviceLocationTypeOther => 'Other';

  @override
  String get serviceLocationMapsCopied => 'Maps link copied.';

  @override
  String get serviceLocationOpenMaps => 'Open map link';

  @override
  String get chartAccountSearchHint => 'Search by code or name';

  @override
  String get chartAccountFilterType => 'Account type';

  @override
  String get chartAccountFilterAllTypes => 'All types';

  @override
  String get chartAccountFilterStatus => 'Status';

  @override
  String get chartAccountFilterAll => 'All';

  @override
  String get chartAccountStatusActive => 'Active';

  @override
  String get chartAccountStatusInactive => 'Inactive';

  @override
  String get chartAccountClearFilters => 'Clear filters';

  @override
  String get chartAccountTypeAsset => 'Asset';

  @override
  String get chartAccountTypeLiability => 'Liability';

  @override
  String get chartAccountTypeEquity => 'Equity';

  @override
  String get chartAccountTypeIncome => 'Income';

  @override
  String get chartAccountTypeExpense => 'Expense';

  @override
  String get chartAccountBadgeSystem => 'System';

  @override
  String get chartAccountBadgeManual => 'Manual';

  @override
  String get chartAccountBadgeCustomer => 'Customer';

  @override
  String get chartAccountBadgeSupplier => 'Supplier';

  @override
  String get chartAccountBadgeInactive => 'Inactive';

  @override
  String get chartAccountAdd => 'Add account';

  @override
  String get chartAccountEdit => 'Edit account';

  @override
  String get chartAccountDeactivate => 'Deactivate';

  @override
  String get chartAccountExpandAll => 'Expand all';

  @override
  String get chartAccountCollapseAll => 'Collapse all';

  @override
  String get chartAccountExpand => 'Expand';

  @override
  String get chartAccountCollapse => 'Collapse';

  @override
  String get chartAccountCreateTitle => 'New account';

  @override
  String get chartAccountEditTitle => 'Edit account';

  @override
  String get chartAccountFieldCode => 'Code';

  @override
  String get chartAccountFieldNameAr => 'Name (Arabic)';

  @override
  String get chartAccountFieldNameEn => 'Name (English)';

  @override
  String get chartAccountFieldType => 'Type';

  @override
  String get chartAccountFieldParent => 'Parent account';

  @override
  String get chartAccountParentNone => 'None (root level)';

  @override
  String get chartAccountCodeReadOnlyHint =>
      'Account code cannot be changed after creation.';

  @override
  String get chartAccountCreated => 'Account created.';

  @override
  String get chartAccountUpdated => 'Account saved.';

  @override
  String get chartAccountDeactivated => 'Account deactivated.';

  @override
  String get chartAccountListEmpty => 'No accounts yet.';

  @override
  String get chartAccountListEmptyFiltered => 'No accounts match your filters.';

  @override
  String get chartAccountDeactivateConfirmTitle => 'Deactivate account';

  @override
  String get chartAccountDeactivateConfirmBody =>
      'This account will be marked inactive. Continue?';

  @override
  String get chartAccountSetupArMissing =>
      'Accounts Receivable parent (1201) is missing. Customer subaccounts may not function correctly.';

  @override
  String get chartAccountSetupApMissing =>
      'Accounts Payable parent (2101) is missing. Supplier subaccounts may not function correctly.';

  @override
  String get chartAccountErrorPermissionDenied =>
      'You do not have permission for this action.';

  @override
  String get chartAccountErrorUnknown =>
      'Something went wrong. Please try again.';

  @override
  String get chartAccountValidationFailed =>
      'Please check the form and try again.';

  @override
  String get chartAccountValidationCodeRequired => 'Account code is required.';

  @override
  String get chartAccountValidationNameArRequired => 'Arabic name is required.';

  @override
  String get chartAccountValidationNameEnRequired =>
      'English name is required.';

  @override
  String get chartAccountErrorParentTypeMismatch =>
      'Account type must match the parent account type.';

  @override
  String get chartAccountErrorDuplicateCode =>
      'This account code is already in use.';

  @override
  String get chartAccountErrorAccountProtected =>
      'This account is protected and cannot be changed.';

  @override
  String get chartAccountErrorTypeChangeUnsafe =>
      'Account type cannot be changed while the account has subaccounts or journal entries.';

  @override
  String get chartAccountErrorHasActiveChildren =>
      'Cannot deactivate an account that has active subaccounts.';

  @override
  String get chartAccountErrorImmutableColumn =>
      'This field cannot be changed.';

  @override
  String get scanInputLabel => 'Scan barcode or serial';

  @override
  String get scanMobileTitle => 'Scan code';

  @override
  String get scanErrorAmbiguous => 'Multiple matches found for this code.';

  @override
  String get scanErrorNotFound => 'No product or unit matched this code.';

  @override
  String get scanErrorPermissionDenied =>
      'You do not have permission to scan inventory codes.';

  @override
  String get scanErrorUnknown => 'Scan failed. Please try again.';

  @override
  String get productUnitDetailTitle => 'Unit details';

  @override
  String get productUnitDetailNotFound => 'Product unit not found.';

  @override
  String get productUnitDetailNoBarcode => 'No barcode';

  @override
  String get productUnitDetailLocation => 'Current location';

  @override
  String get productUnitDetailLocationUnknown => 'Location not assigned';

  @override
  String get productUnitDetailMaintenanceCount => 'Maintenance count';

  @override
  String get productUnitSerialCorrectionTitle => 'Correct serial number';

  @override
  String get productUnitSerialCorrectionNewSerial => 'New serial number';

  @override
  String get productUnitSerialCorrectionReason => 'Reason for correction';

  @override
  String get productUnitSerialCorrectionSubmit => 'Save serial correction';

  @override
  String get productUnitSerialCorrectionSuccess => 'Serial number updated.';

  @override
  String get productUnitTimelineTitle => 'Unit timeline';

  @override
  String get productUnitTimelineEmpty => 'No timeline events yet.';

  @override
  String get productUnitTimelineAcquisition => 'Unit acquired';

  @override
  String get productUnitTimelinePurchaseInvoice => 'Purchase invoice';

  @override
  String get productUnitTimelineInventoryMovement => 'Inventory movement';

  @override
  String get productUnitTimelineReconciled => 'Serial reconciled';

  @override
  String get productUnitTimelineSerialCorrection => 'Serial corrected';

  @override
  String get documentPreviewTitle => 'Document preview';

  @override
  String get documentPreviewAction => 'Preview PDF';

  @override
  String get documentPreviewAssetLabel => 'Print asset label';

  @override
  String get documentPreviewEmpty => 'No document to preview.';

  @override
  String get documentPreviewPermissionDenied =>
      'You do not have permission to preview this document.';

  @override
  String get documentErrorUnknown =>
      'Could not generate the document. Please try again.';

  @override
  String get documentErrorNoTemplate =>
      'No default document template is configured.';

  @override
  String get documentErrorStatementDateRange =>
      'Statement date range is invalid.';

  @override
  String get documentErrorStatementTooLarge =>
      'Statement has too many rows to print.';

  @override
  String get documentErrorUnsupportedType =>
      'This document type is not supported yet.';

  @override
  String get documentErrorThermalTooLarge =>
      'Content is too large for thermal printing.';

  @override
  String get documentErrorFontLoad => 'Could not load document fonts.';

  @override
  String get documentErrorValidation => 'Document settings are invalid.';

  @override
  String get documentErrorTenantNotFound => 'Tenant context was not found.';

  @override
  String get documentErrorNotConfigured =>
      'Document service is not configured.';

  @override
  String get documentErrorLogoInvalidUrl => 'Logo URL must use HTTPS.';

  @override
  String get documentErrorLogoTooLarge =>
      'Logo file is too large (max 512 KB).';

  @override
  String get documentErrorLogoInvalidDimensions =>
      'Logo dimensions are too large (max 4096 px per side, 16 MP total).';

  @override
  String get documentErrorLogoUnsupportedFormat =>
      'Logo must be a PNG or JPEG image.';

  @override
  String get documentErrorLogoFetchFailed =>
      'Could not download the logo. Check the URL and try again.';

  @override
  String get customerStatementFromDate => 'From';

  @override
  String get customerStatementToDate => 'To';

  @override
  String get templateSettingsTitle => 'Document templates';

  @override
  String get templateSettingsPermissionDenied =>
      'You do not have permission to view template settings.';

  @override
  String get templateSettingsLogoUrl => 'Logo URL (HTTPS)';

  @override
  String get templateSettingsPrimaryColor => 'Primary color (#RRGGBB)';

  @override
  String get templateSettingsSecondaryColor => 'Secondary color (#RRGGBB)';

  @override
  String get templateSettingsDefaultLanguage => 'Default document language';

  @override
  String get templateSettingsInvoicePaper => 'Invoice paper';

  @override
  String get templateSettingsAssetLabelPaper => 'Asset label paper';

  @override
  String get templateSettingsVoucherPaper => 'Voucher paper';

  @override
  String get templateSettingsHeaderSection => 'Document header';

  @override
  String get templateSettingsHeaderAr => 'Header text (Arabic)';

  @override
  String get templateSettingsHeaderEn => 'Header text (English)';

  @override
  String get templateSettingsFooterSection => 'Document footer';

  @override
  String get templateSettingsFooterAr => 'Footer text (Arabic)';

  @override
  String get templateSettingsFooterEn => 'Footer text (English)';

  @override
  String get templateSettingsOptionalColumnsSection => 'Optional columns';

  @override
  String get templateSettingsOptionalSalesInvoice => 'Sales invoice';

  @override
  String get templateSettingsOptionalPurchaseInvoice => 'Purchase invoice';

  @override
  String get templateSettingsOptionalCustomerStatement => 'Customer statement';

  @override
  String get templateSettingsOptionalQty => 'Show quantity';

  @override
  String get templateSettingsOptionalUnitPrice => 'Show unit price';

  @override
  String get templateSettingsOptionalDebit => 'Show debit';

  @override
  String get templateSettingsOptionalCredit => 'Show credit';

  @override
  String get templateSettingsLanguageAr => 'Arabic';

  @override
  String get templateSettingsLanguageEn => 'English';

  @override
  String get templateSettingsLanguageBilingual => 'Bilingual';

  @override
  String get templateSettingsPaperA4 => 'A4';

  @override
  String get templateSettingsPaperThermal => 'Thermal 80mm';

  @override
  String get templateSettingsPaperLabel => 'Label sheet';

  @override
  String get templateSettingsSaved => 'Document settings saved.';

  @override
  String get templateSettingsSave => 'Save settings';

  @override
  String get navInvoices => 'Invoices';

  @override
  String get navContracts => 'Contracts';

  @override
  String get navVouchers => 'Vouchers';

  @override
  String get navJournal => 'Journal';

  @override
  String get navCashBank => 'Cash & Bank';

  @override
  String get financePlaceholderM9Body =>
      'Full workflow screens arrive in the next milestone.';

  @override
  String get financeModuleAccessUnavailable =>
      'You do not have permission to view this finance section.';

  @override
  String get financeErrorTenantNotFound => 'Tenant context was not found.';

  @override
  String get financeErrorPermissionDenied =>
      'You do not have permission for this finance action.';

  @override
  String get financeErrorValidationFailed =>
      'The finance data is invalid. Review the form and try again.';

  @override
  String get financeErrorBelowMinProfit =>
      'Monthly profit is below the minimum allowed. Adjust pricing or request an authorized override.';

  @override
  String get financeErrorIdempotencyPayloadMismatch =>
      'This request conflicts with a previous submission. Start again.';

  @override
  String get financeErrorBooksLocked =>
      'Accounting books are locked for this date.';

  @override
  String get financeErrorDuplicateSerial =>
      'A duplicate serial number was detected.';

  @override
  String get financeErrorCrossTenantReference =>
      'A cross-tenant reference is not allowed.';

  @override
  String get financeErrorTaxRateNotFound =>
      'The selected tax rate was not found.';

  @override
  String get financeErrorTaxRateInUse =>
      'This tax rate is in use and cannot be changed.';

  @override
  String get financeErrorNotFound => 'The finance record was not found.';

  @override
  String get financeErrorNotAvailable =>
      'This finance feature is not available yet.';

  @override
  String get financeErrorCorrectionDocumentRequired =>
      'Safe cancellation is not available. A correction document is required.';

  @override
  String get financeErrorUnknown =>
      'A finance error occurred. Please try again.';

  @override
  String get financeValidationNotesRequired => 'Notes are required.';

  @override
  String get financeValidationGainReasonRequired => 'Gain reason is required.';

  @override
  String get financeValidationLossReasonRequired => 'Loss reason is required.';

  @override
  String get financeValidationSerializedQtyIntegerRequired =>
      'Serialized quantity must be a positive whole number.';

  @override
  String get financeErrorReturnDocumentRequired =>
      'A return document is required for this operation.';

  @override
  String get financeErrorSerializedAdjustmentNotSupported =>
      'Serialized adjustments are not supported yet.';

  @override
  String get financeErrorBackendMigrationRequired =>
      'This invoice workflow needs a database update before it can be confirmed.';

  @override
  String financeErrorUnknownWithCode(String code) {
    return 'An unexpected finance error occurred. Please try again. (Ref: $code)';
  }

  @override
  String get financeValidationCustomerRequired =>
      'Select a customer for this invoice.';

  @override
  String get financeValidationSupplierRequired =>
      'Select a supplier for this invoice.';

  @override
  String get financeValidationWarehouseRequired => 'Select a warehouse.';

  @override
  String get financeValidationPartyRequired => 'Select a customer or supplier.';

  @override
  String get financeValidationLinesRequired => 'Add at least one line item.';

  @override
  String get financeValidationProductRequired =>
      'Select a product for every line.';

  @override
  String get financeValidationLineQtyInvalid =>
      'Quantity must be greater than zero.';

  @override
  String get financeValidationLinePriceInvalid =>
      'Unit price cannot be negative.';

  @override
  String get financeValidationDiscountOutOfRange =>
      'Discount must be between 0 and 100 percent.';

  @override
  String get financeValidationDueDateBeforeInvoiceDate =>
      'Due date cannot be before the invoice date.';

  @override
  String get financeValidationSerializedUnitRequired =>
      'Select a serial/unit for serialized products.';

  @override
  String get financeValidationSerialCountMismatch =>
      'Serial count must match the line quantity.';

  @override
  String get financeValidationOriginalInvoiceRequired =>
      'Select the original invoice to return against.';

  @override
  String get financeValidationReturnReasonRequired =>
      'Enter a reason for this return.';

  @override
  String get financeValidationReturnQtyExceedsReturnable =>
      'Return quantity exceeds the returnable quantity.';

  @override
  String get financeValidationCashAccountRequired =>
      'Select a cash or bank account.';

  @override
  String get financeValidationAccountRequired => 'Select a financial account.';

  @override
  String get financeValidationCancellationReasonRequired =>
      'Enter a cancellation reason.';

  @override
  String get financeValidationCancellationReasonTooLong =>
      'Cancellation reason is too long.';

  @override
  String get journalSourceSalesReturn => 'Sales return';

  @override
  String get journalSourcePurchaseReturn => 'Purchase return';

  @override
  String get journalSourceSalesReturnReversal => 'Sales return reversal';

  @override
  String get journalSourcePurchaseReturnReversal => 'Purchase return reversal';

  @override
  String get journalSourceCustomerRefundVoucher => 'Customer refund voucher';

  @override
  String get journalSourceSupplierRefundReceipt => 'Supplier refund receipt';

  @override
  String get journalSourceSalesInvoiceReversal => 'Sales invoice reversal';

  @override
  String get journalSourcePurchaseInvoiceReversal =>
      'Purchase invoice reversal';

  @override
  String get journalSourceReceiptVoucherReversal => 'Receipt voucher reversal';

  @override
  String get journalSourcePaymentVoucherReversal => 'Payment voucher reversal';

  @override
  String get journalSourceOpeningStock => 'Opening stock';

  @override
  String get journalSourceInventoryStockIn => 'Stock in';

  @override
  String get journalSourceInventoryStockOut => 'Stock out';

  @override
  String get journalSourceStockCount => 'Stock count';

  @override
  String get journalSourceInventoryDocumentReversal =>
      'Inventory document reversal';

  @override
  String get cashBankChartViewRequiredTitle =>
      'Chart of accounts access required';

  @override
  String get cashBankChartViewRequiredBody =>
      'Select a cash or bank account from the chart of accounts. Ask your administrator for chart of accounts view permission.';

  @override
  String get invoiceTitle => 'Invoices';

  @override
  String get invoiceNewSales => 'New sales invoice';

  @override
  String get invoiceNewPurchase => 'New purchase invoice';

  @override
  String get invoiceDetailTitle => 'Invoice detail';

  @override
  String get invoiceReturnTitle => 'Return invoice';

  @override
  String get invoiceTypeSales => 'Sales';

  @override
  String get invoiceTypePurchase => 'Purchase';

  @override
  String get invoiceTypeSalesReturn => 'Sales return';

  @override
  String get invoiceTypePurchaseReturn => 'Purchase return';

  @override
  String get invoiceStatusDraft => 'Draft';

  @override
  String get invoiceStatusConfirmed => 'Confirmed';

  @override
  String get invoiceStatusPartiallyPaid => 'Partially paid';

  @override
  String get invoiceStatusPaid => 'Paid';

  @override
  String get invoiceStatusCancelled => 'Cancelled';

  @override
  String get invoiceFilterType => 'Type';

  @override
  String get invoiceFilterSearch => 'Search';

  @override
  String get invoiceColumnNumber => 'Number';

  @override
  String get invoiceColumnParty => 'Party';

  @override
  String get invoiceColumnDate => 'Date';

  @override
  String get invoiceColumnDueDate => 'Due date';

  @override
  String get invoiceColumnTotal => 'Total';

  @override
  String get invoiceColumnPaid => 'Paid';

  @override
  String get invoiceColumnOutstanding => 'Outstanding';

  @override
  String get invoiceOverdueBadge => 'Overdue';

  @override
  String get invoiceListEmpty => 'No invoices yet.';

  @override
  String get invoiceListEmptyFiltered => 'No invoices match your filters.';

  @override
  String get invoiceDetailLines => 'Lines';

  @override
  String get invoicePaymentSummary => 'Payment summary';

  @override
  String get invoiceActionCancel => 'Cancel invoice';

  @override
  String get invoiceActionReturn => 'Create return';

  @override
  String get invoiceActionEditDraft => 'Edit draft';

  @override
  String get invoiceActionConfirmDraft => 'Confirm draft';

  @override
  String get invoiceCancelReason => 'Cancellation reason';

  @override
  String get invoiceConfirmCancel => 'Cancel this invoice?';

  @override
  String get invoiceJournalEntry => 'Journal entry';

  @override
  String get invoiceTotalsSubtotal => 'Subtotal';

  @override
  String get invoiceTotalsDiscount => 'Discount';

  @override
  String get invoiceTotalsTax => 'Tax';

  @override
  String get invoiceTotalsTotal => 'Total';

  @override
  String get invoiceCreditAllocations => 'Credit allocations';

  @override
  String get invoiceReturnNotEligible => 'This invoice cannot be returned.';

  @override
  String get invoiceCreateSales => 'New sales';

  @override
  String get invoiceCreatePurchase => 'New purchase';

  @override
  String get invoiceCreateNew => 'Add';

  @override
  String get invoiceCreateReturnHint => 'From an invoice';

  @override
  String get invoiceFormWarehouse => 'Warehouse';

  @override
  String get invoiceFormDate => 'Invoice date';

  @override
  String get invoiceFormDueDate => 'Due date';

  @override
  String get invoiceFormNotes => 'Notes';

  @override
  String get invoiceFormNumberAuto =>
      'Invoice number: assigned after confirmation';

  @override
  String get invoicePaymentTermsTitle => 'Payment terms';

  @override
  String get invoicePaymentTermsCash => 'Cash / immediate';

  @override
  String get invoicePaymentTermsCredit => 'Credit';

  @override
  String get invoicePaymentTermsCashHelper =>
      'Payment will be recorded later from vouchers.';

  @override
  String get invoicePaymentTermsCashHelperSales =>
      'A receipt voucher will be created after the invoice is confirmed.';

  @override
  String get invoicePaymentTermsCashHelperPurchase =>
      'A payment voucher will be created after the invoice is confirmed.';

  @override
  String get invoiceFormNewCustomer => '+ New customer';

  @override
  String get invoicePickOriginalInvoiceTitle => 'Select original invoice';

  @override
  String get invoicePickOriginalInvoiceSearch => 'Search by number or party';

  @override
  String get invoicePickOriginalInvoiceEmpty =>
      'No confirmed invoices eligible for return.';

  @override
  String get invoiceFormCustomer => 'Customer';

  @override
  String get invoiceFormSupplier => 'Supplier';

  @override
  String get invoiceFormAddLine => 'Add line';

  @override
  String get invoiceFormSaveDraft => 'Save draft';

  @override
  String get invoiceFormConfirm => 'Confirm invoice';

  @override
  String get invoiceFormDiscardDraft => 'Discard draft';

  @override
  String get invoiceFormSelectProduct => 'Product';

  @override
  String get invoiceFormQty => 'Quantity';

  @override
  String get invoiceFormUnitPrice => 'Unit price';

  @override
  String get invoiceFormDiscount => 'Discount %';

  @override
  String get invoiceFormSerialNumber => 'Serial number';

  @override
  String get invoiceFormDiscard => 'Discard';

  @override
  String get invoiceColumnUnit => 'Unit';

  @override
  String get invoiceColumnDescription => 'Description';

  @override
  String get invoiceColumnLineTotal => 'Line total';

  @override
  String get invoiceColumnActions => 'Actions';

  @override
  String get invoiceFormConfirmMessage =>
      'Confirm and post this invoice? Totals are calculated on the server.';

  @override
  String get invoiceEstimatedTotalsDisclaimer =>
      'Estimated totals only. Final tax and total are set when the invoice is confirmed.';

  @override
  String get invoiceEstimatedCreditPreview => 'Estimated credit preview';

  @override
  String get invoiceFinalTotalsAfterConfirm =>
      'Final totals are calculated after confirmation.';

  @override
  String get invoiceReturnReason => 'Return reason';

  @override
  String get invoiceReturnSubmit => 'Submit return';

  @override
  String get voucherTitle => 'Vouchers';

  @override
  String get voucherNewReceipt => 'New receipt voucher';

  @override
  String get voucherNewPayment => 'New payment voucher';

  @override
  String get voucherDetailTitle => 'Voucher detail';

  @override
  String get voucherTypeReceipt => 'Receipt';

  @override
  String get voucherTypePayment => 'Payment';

  @override
  String get voucherStatusConfirmed => 'Confirmed';

  @override
  String get voucherStatusCancelled => 'Cancelled';

  @override
  String get voucherAllocationFifo => 'Apply to oldest invoices first (FIFO)';

  @override
  String get voucherAllocationManual => 'Allocate manually';

  @override
  String get voucherPaymentDestinationSupplier => 'Pay supplier';

  @override
  String get voucherPaymentDestinationAccount => 'Pay to account';

  @override
  String get voucherOpenInvoices => 'Open invoices';

  @override
  String get voucherSelectCashAccount => 'Cash or bank account';

  @override
  String get voucherFormSubmit => 'Record voucher';

  @override
  String get voucherFormSubmitSuccess => 'Voucher recorded.';

  @override
  String get voucherFormPaymentMethod => 'Payment method';

  @override
  String get voucherListEmpty => 'No vouchers yet.';

  @override
  String get voucherListEmptyFiltered => 'No vouchers match your filters.';

  @override
  String get voucherFilterType => 'Type';

  @override
  String get voucherFilterSearch => 'Search';

  @override
  String get voucherCreateReceipt => 'New receipt';

  @override
  String get voucherCreatePayment => 'New payment';

  @override
  String get voucherColumnNumber => 'Number';

  @override
  String get voucherFormCustomer => 'Customer';

  @override
  String get voucherFormSupplier => 'Supplier';

  @override
  String get voucherFormCashAccount => 'Cash account';

  @override
  String get voucherFormReference => 'Reference';

  @override
  String get voucherFormNotes => 'Notes';

  @override
  String get voucherFormAmount => 'Amount';

  @override
  String get voucherFormDate => 'Date';

  @override
  String get voucherAllocationsTitle => 'Invoice allocations';

  @override
  String get voucherAllocatedAmount => 'Allocated';

  @override
  String get voucherUnallocatedAmount => 'Unallocated';

  @override
  String get voucherCancelAction => 'Cancel voucher';

  @override
  String get voucherCancelReason => 'Cancellation reason';

  @override
  String get voucherConfirmCancel => 'Cancel this voucher?';

  @override
  String get voucherJournalEntry => 'Journal entry';

  @override
  String get voucherReversalJournal => 'Reversal journal';

  @override
  String get journalTitle => 'Journal';

  @override
  String get journalDetailTitle => 'Journal entry';

  @override
  String get journalListEmpty => 'No journal entries yet.';

  @override
  String get journalListEmptyFiltered =>
      'No journal entries match the current filters.';

  @override
  String get journalFilterSource => 'Source';

  @override
  String get journalFilterSearch => 'Search entries';

  @override
  String get journalPostedBadge => 'Posted';

  @override
  String get journalReversalBadge => 'Reversal';

  @override
  String get journalSourceDocument => 'Source document';

  @override
  String get journalReversalEntry => 'Reversal of';

  @override
  String get journalLineAccount => 'Account';

  @override
  String get cashBankTitle => 'Cash & Bank';

  @override
  String get cashBankSelectAccount => 'Select cash or bank account';

  @override
  String get cashBankOpeningBalance => 'Opening balance';

  @override
  String get cashBankRunningBalance => 'Running balance';

  @override
  String get cashBankExportLoadedRows => 'Export loaded rows';

  @override
  String get cashBankExportLoadedRowsCopied =>
      'Loaded rows copied to clipboard as CSV.';

  @override
  String get cashBankActivityEmpty =>
      'No activity for this account in the selected period.';

  @override
  String get taxSettingsTitle => 'Tax settings';

  @override
  String get inventoryDocumentsTitle => 'Inventory financial documents';

  @override
  String get inventoryDocumentsLink => 'Financial documents';

  @override
  String get inventoryDocumentOpeningStock => 'Opening stock';

  @override
  String get inventoryDocumentStockIn => 'Stock in';

  @override
  String get inventoryDocumentStockOut => 'Stock out';

  @override
  String get inventoryDocumentStockCount => 'Stock count';

  @override
  String get inventoryDocumentsDeferredBody =>
      'Inventory accounting documents will be available after the accounting review milestone.';

  @override
  String get inventoryDocumentListEmpty =>
      'No inventory financial documents yet.';

  @override
  String get inventoryDocumentListEmptyFiltered =>
      'No documents match the current filters.';

  @override
  String get inventoryDocumentNumber => 'Document no.';

  @override
  String get inventoryDocumentKind => 'Type';

  @override
  String get inventoryDocumentWarehouse => 'Warehouse';

  @override
  String get inventoryDocumentDate => 'Date';

  @override
  String get inventoryDocumentNotes => 'Notes';

  @override
  String get inventoryDocumentReason => 'Reason';

  @override
  String get inventoryDocumentGainReason => 'Gain reason';

  @override
  String get inventoryDocumentLossReason => 'Loss reason';

  @override
  String get inventoryDocumentSystemQty => 'System qty';

  @override
  String get inventoryDocumentCountedQty => 'Counted qty';

  @override
  String get inventoryDocumentDeltaQty => 'Delta';

  @override
  String get inventoryDocumentUnitCost => 'Unit cost';

  @override
  String get inventoryDocumentWacHint =>
      'Uses current average cost when unit cost is omitted.';

  @override
  String get inventoryDocumentAddLine => 'Add line';

  @override
  String get inventoryDocumentRemoveLine => 'Remove line';

  @override
  String get inventoryDocumentConfirmSubmit => 'Confirm document';

  @override
  String get inventoryDocumentConfirmSubmitMessage =>
      'This will post the inventory financial document and cannot be edited afterward.';

  @override
  String get inventoryDocumentSubmit => 'Post document';

  @override
  String get inventoryDocumentCancelAction => 'Cancel document';

  @override
  String get inventoryDocumentCancelReason => 'Cancellation reason';

  @override
  String get inventoryDocumentCancelled => 'Cancelled';

  @override
  String get inventoryDocumentLines => 'Lines';

  @override
  String get inventoryDocumentMovements => 'Movements';

  @override
  String get inventoryDocumentJournalEntry => 'Journal entry';

  @override
  String get inventoryDocumentReversalJournal => 'Reversal journal';

  @override
  String get inventoryDocumentSerializedNotSupportedYet =>
      'Serialized products are not supported for this document type yet.';

  @override
  String get inventoryDocumentStatusConfirmed => 'Confirmed';

  @override
  String get inventoryDocumentStatusCancelled => 'Cancelled';

  @override
  String get inventoryDocumentFilterKind => 'Document type';

  @override
  String get inventoryDocumentFilterWarehouse => 'Warehouse';

  @override
  String get inventoryDocumentCreateOpening => 'Opening stock';

  @override
  String get inventoryDocumentCreateStockIn => 'Stock in';

  @override
  String get inventoryDocumentCreateStockOut => 'Stock out';

  @override
  String get inventoryDocumentCreateStockCount => 'Stock count';

  @override
  String get inventoryDocumentSelectProduct => 'Select product';

  @override
  String get inventoryDocumentSelectReason => 'Select reason';

  @override
  String get inventoryDocumentSerialUnits => 'Serial numbers';

  @override
  String get inventoryDocumentSelectUnits => 'Select units';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodKnet => 'KNET';

  @override
  String get paymentMethodBankTransfer => 'Bank transfer';

  @override
  String get paymentMethodCheque => 'Cheque';

  @override
  String get paymentMethodOther => 'Other';

  @override
  String get financeColumnParty => 'Party';

  @override
  String get financeColumnDate => 'Date';

  @override
  String get financeColumnDueDate => 'Due date';

  @override
  String get financeColumnTotal => 'Total';

  @override
  String get financeColumnPaid => 'Paid';

  @override
  String get financeColumnOutstanding => 'Outstanding';

  @override
  String get financeColumnStatus => 'Status';

  @override
  String get financeColumnReference => 'Reference';

  @override
  String get financeColumnAmount => 'Amount';

  @override
  String get financeColumnDescription => 'Description';

  @override
  String get financeColumnDebit => 'Debit';

  @override
  String get financeColumnCredit => 'Credit';

  @override
  String get financeColumnBalance => 'Balance';

  @override
  String get financeTotalsSubtotal => 'Subtotal';

  @override
  String get financeTotalsDiscount => 'Discount';

  @override
  String get financeTotalsTax => 'Tax';

  @override
  String get financeTotalsGrandTotal => 'Grand total';

  @override
  String get financeAllocationModeFifo => 'FIFO';

  @override
  String get financeAllocationModeManual => 'Manual';

  @override
  String get financeAllocationModeUnallocated => 'Unallocated';

  @override
  String get financeActionCancel => 'Cancel';

  @override
  String get financeActionPrint => 'Print';

  @override
  String get financeActionScan => 'Scan';

  @override
  String get financeActionSelectSerial => 'Select serial';

  @override
  String get financeCancellationReason => 'Cancellation reason';

  @override
  String get financeReversalLabel => 'Reversal';

  @override
  String get calendarSettingsTitle => 'Working Days & Hours';

  @override
  String get calendarSettingsPermissionDenied =>
      'You do not have permission to view calendar settings.';

  @override
  String get calendarSettingsSetupRequired =>
      'Calendar setup is required before working windows and reminders are available.';

  @override
  String get calendarSettingsTimezone => 'IANA timezone';

  @override
  String get calendarSettingsTimezoneRequired => 'Select a valid timezone.';

  @override
  String calendarSettingsLegacyTimezoneSuggestion(String timezone) {
    return 'Legacy suggestion (unconfirmed): $timezone';
  }

  @override
  String get calendarSettingsWorkingDaysSection => 'Working days';

  @override
  String get calendarSettingsDayMode => 'Day mode';

  @override
  String get calendarSettingsWorkStart => 'Start';

  @override
  String get calendarSettingsWorkEnd => 'End';

  @override
  String calendarSettingsDaySummary(String start, String end) {
    return 'Window: $start – $end';
  }

  @override
  String get calendarSettingsRemindEventDay =>
      'Remind at event working-day start';

  @override
  String get calendarSettingsRemindPreviousDay =>
      'Remind at previous working-day start';

  @override
  String get calendarSettingsSave => 'Save settings';

  @override
  String get calendarSettingsSaved => 'Calendar settings saved.';

  @override
  String get calendarSettingsValidationFailed =>
      'Could not save calendar settings. Check the fields and try again.';

  @override
  String get calendarSettingsUnsavedTitle => 'Discard changes?';

  @override
  String get calendarSettingsUnsavedBody =>
      'You have unsaved calendar settings changes.';

  @override
  String get calendarSettingsDiscard => 'Discard';

  @override
  String get calendarSettingsDayValidationError =>
      'Review this day\'s settings.';

  @override
  String get calendarDayModeUnreviewed => 'Unreviewed';

  @override
  String get calendarDayModeDayOff => 'Day off';

  @override
  String get calendarDayModeWorkingHours => 'Working hours';

  @override
  String get calendarDayMode24Hours => '24 hours';

  @override
  String get calendarWeekdayMonday => 'Monday';

  @override
  String get calendarWeekdayTuesday => 'Tuesday';

  @override
  String get calendarWeekdayWednesday => 'Wednesday';

  @override
  String get calendarWeekdayThursday => 'Thursday';

  @override
  String get calendarWeekdayFriday => 'Friday';

  @override
  String get calendarWeekdaySaturday => 'Saturday';

  @override
  String get calendarWeekdaySunday => 'Sunday';

  @override
  String get navCalendarSettings => 'Calendar settings';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarLoading => 'Loading calendar…';

  @override
  String get calendarPermissionDenied =>
      'You do not have permission to view the calendar.';

  @override
  String get calendarSetupWarning =>
      'Working schedule is not configured yet. Events are still readable, but overdue and working-day rules are limited until setup is complete.';

  @override
  String get calendarAgendaEmpty => 'No events on this day.';

  @override
  String get calendarLoadMore => 'Load more';

  @override
  String calendarVisibleRange(String from, String to) {
    return 'Range: $from – $to';
  }

  @override
  String calendarSelectedDate(String date) {
    return 'Selected: $date';
  }

  @override
  String get calendarErrorValidation =>
      'Calendar request was invalid. Check the date range and filters.';

  @override
  String get calendarErrorInvalidCursor =>
      'Calendar page expired. Refresh and try again.';

  @override
  String get calendarErrorTenantNotFound =>
      'Tenant could not be resolved for the calendar.';

  @override
  String get calendarErrorMalformed =>
      'Calendar data from the server was incomplete. Please retry.';

  @override
  String get calendarErrorUnavailable =>
      'Calendar is temporarily unavailable. Please try again.';

  @override
  String get calendarErrorUnknown =>
      'Something went wrong loading the calendar.';

  @override
  String get calendarEventTypeRefillDue => 'Refill due';

  @override
  String get calendarEventTypeBillingDue => 'Billing due';

  @override
  String get calendarEventTypePaymentDue => 'Payment due';

  @override
  String get calendarEventTypeMaintenanceDue => 'Maintenance due';

  @override
  String get calendarEventTypeFollowUp => 'Follow-up';

  @override
  String get calendarEventTypeTrialEnding => 'Trial ending';

  @override
  String get calendarEventTypeContractStart => 'Contract start';

  @override
  String get calendarEventTypeContractEnd => 'Contract end';

  @override
  String get calendarEventTypeCustomerVisit => 'Customer visit';

  @override
  String get calendarEventTypeInternalMeeting => 'Internal meeting';

  @override
  String get calendarEventTypeInternalTask => 'Internal task';

  @override
  String get calendarEventTypeInternalActivity => 'Internal activity';

  @override
  String get calendarEventTypeCustom => 'Custom';

  @override
  String get calendarEventStatusPending => 'Pending';

  @override
  String get calendarEventStatusDone => 'Done';

  @override
  String get calendarEventStatusMissed => 'Missed';

  @override
  String get calendarEventStatusCancelled => 'Cancelled';

  @override
  String get calendarEventStatusRescheduled => 'Rescheduled';

  @override
  String get calendarSourceKindManual => 'Manual';

  @override
  String get calendarSourceKindContractGenerated => 'Contract generated';

  @override
  String get calendarScheduleStateWorkingDay => 'Working day';

  @override
  String get calendarScheduleStateNonWorkingDay => 'Non-working day';

  @override
  String get calendarScheduleStateUnconfigured => 'Schedule unconfigured';

  @override
  String get calendarScheduleStateDayOffOverridden => 'Day-off overridden';

  @override
  String get calendarOverdueStateNotApplicable => 'Not applicable';

  @override
  String get calendarOverdueStateUnconfigured => 'Schedule unconfigured';

  @override
  String get calendarOverdueStateOverdue => 'Overdue';

  @override
  String get calendarOverdueStateNotOverdue => 'Not overdue';

  @override
  String get calendarFilterAssigned => 'Assigned agent';

  @override
  String get calendarFilterUnassigned => 'Unassigned only';

  @override
  String get calendarFilterSearch => 'Search';

  @override
  String get calendarFilterSearchHint =>
      'Search events, customers, contracts, locations, and agents';

  @override
  String get calendarFilterOpenFilters => 'Filters';

  @override
  String get calendarFilterReset => 'Reset';

  @override
  String get calendarFilterAnySource => 'Any source';

  @override
  String get calendarFilterOverdueOnly => 'Overdue only';

  @override
  String get calendarFilterWorkingDayConflict => 'Working-day conflict';

  @override
  String get calendarFilterTypes => 'Event types';

  @override
  String get calendarFilterStatuses => 'Statuses';

  @override
  String get calendarFilterSourceKind => 'Source';

  @override
  String get calendarFilterCustomer => 'Customer';

  @override
  String get calendarFilterContract => 'Contract';

  @override
  String get calendarFilterServiceLocation => 'Service location';

  @override
  String get calendarFilterApply => 'Apply filters';

  @override
  String get calendarFilterClear => 'Clear filters';

  @override
  String calendarFilterActiveCount(int count) {
    return '$count active';
  }

  @override
  String get calendarFilterDirty => 'Unapplied filter changes';

  @override
  String get calendarFilterSelectCustomerFirst =>
      'Select a customer to filter by location.';

  @override
  String get calendarFilterLookupUnavailable =>
      'Lookup unavailable for your permissions.';

  @override
  String get calendarFilterLookupError => 'Could not load lookup results.';

  @override
  String get calendarEventActionsTitle => 'Event actions';

  @override
  String get calendarEventActionsClose => 'Close';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarPreviousMonth => 'Previous month';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String get calendarSelectMonth => 'Select month';

  @override
  String get calendarSelectYear => 'Select year';

  @override
  String calendarMonthYear(String month, int year) {
    return '$month $year';
  }

  @override
  String calendarCountOverflow(int value) {
    return '$value+';
  }

  @override
  String calendarDayEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String calendarDayUnassignedCount(int count) {
    return '$count unassigned';
  }

  @override
  String calendarDayOverdueCount(int count) {
    return '$count overdue';
  }

  @override
  String calendarWorkingWindow(String start, String end) {
    return 'Working hours: $start–$end';
  }

  @override
  String get calendarAgendaFilteredEmpty =>
      'No events match the current filters.';

  @override
  String get calendarOverdueSectionTitle => 'Overdue outside this range';

  @override
  String get calendarOverdueUnavailable =>
      'Overdue items are unavailable until the working schedule is configured.';

  @override
  String get calendarOverdueEmpty => 'No overdue events outside this range.';

  @override
  String get calendarDirectionsAvailable => 'Directions available';

  @override
  String get calendarRescheduledBadge => 'Rescheduled';

  @override
  String get calendarDayOffConflict => 'Scheduled on a day off';

  @override
  String get calendarViewCustomer => 'View customer';

  @override
  String get calendarViewContract => 'View contract';

  @override
  String get calendarSemanticsToday => 'Today';

  @override
  String get calendarSemanticsSelected => 'Selected';

  @override
  String get calendarSemanticsDayOff => 'Day off';

  @override
  String get calendarSemanticsConflict => 'Working-day conflict';

  @override
  String get calendarMonthSkeleton => 'Loading month summary…';

  @override
  String get calendarAgendaLoading => 'Loading agenda…';

  @override
  String get calendarOverdueLoading => 'Loading overdue…';

  @override
  String get calendarValidationRangeSpan =>
      'Date range must be between 1 and 62 days.';

  @override
  String get calendarValidationSearchTooShort =>
      'Search must be at least 2 characters.';

  @override
  String get calendarValidationUnassignedAssignedConflict =>
      'Cannot combine unassigned-only with an assigned agent.';

  @override
  String get calendarValidationOverdueRequiresPending =>
      'Overdue-only requires pending status.';

  @override
  String get calendarValidationAssignedOnlyAgent =>
      'Assigned-only users cannot filter by agent.';

  @override
  String get calendarValidationAssignedOnlyUnassigned =>
      'Assigned-only users cannot request unassigned events.';

  @override
  String get calendarLabelAssigned => 'Assigned';

  @override
  String get calendarLabelUnassigned => 'Unassigned';

  @override
  String get calendarCreateEvent => 'Create event';

  @override
  String get calendarCreateEventTitle => 'Create calendar event';

  @override
  String get calendarEditEventTitle => 'Edit calendar event';

  @override
  String calendarEventScheduledDate(String date) {
    return 'Scheduled date: $date';
  }

  @override
  String get calendarCreateEventConfirm => 'Create';

  @override
  String get calendarSaveEvent => 'Save';

  @override
  String get calendarManualCategory => 'Category';

  @override
  String get calendarManualTitleAr => 'Title (Arabic)';

  @override
  String get calendarManualTitleEn => 'Title (English)';

  @override
  String get calendarManualNotes => 'Notes';

  @override
  String get calendarManualSetTime => 'Set time';

  @override
  String get calendarManualStartTime => 'Start';

  @override
  String get calendarManualEndTime => 'End';

  @override
  String get calendarManualTeam => 'Team (optional)';

  @override
  String get calendarManualLocation => 'Location (optional)';

  @override
  String get calendarManualNone => 'None';

  @override
  String get calendarMeetingMode => 'Meeting mode';

  @override
  String get calendarMeetingModeInPerson => 'In person';

  @override
  String get calendarMeetingModeOnline => 'Online';

  @override
  String get calendarMeetingUrl => 'Meeting URL (HTTPS)';

  @override
  String get calendarParticipants => 'Participants';

  @override
  String get calendarParticipantsSearch => 'Search employees';

  @override
  String get calendarAgendaTimedSection => 'Timed appointments';

  @override
  String get calendarAgendaDayTasksSection => 'Day tasks';

  @override
  String get calendarCancelEventTitle => 'Cancel event';

  @override
  String get calendarCancelEventBody =>
      'Cancellation requires a reason and preserves the event for audit.';

  @override
  String get calendarCancelReasonLabel => 'Cancellation reason';

  @override
  String get calendarCancelReasonRequired =>
      'Enter a non-empty cancellation reason.';

  @override
  String get calendarCancelEventConfirm => 'Cancel event';

  @override
  String get calendarEditManual => 'Edit';

  @override
  String get calendarCancelManual => 'Cancel event';

  @override
  String get calendarMarkManualDone => 'Mark done';

  @override
  String get calendarCloseMeeting => 'Close meeting';

  @override
  String get calendarMarkDoneConfirmTitle => 'Mark event done?';

  @override
  String get calendarMarkDoneConfirmBody =>
      'This marks the event as completed.';

  @override
  String get calendarCloseMeetingConfirmTitle => 'Close this meeting?';

  @override
  String get calendarCloseMeetingConfirmBody =>
      'This marks the meeting as completed.';

  @override
  String get calendarMarkDoneConfirmAction => 'Confirm';

  @override
  String get calendarJoinMeeting => 'Join meeting';

  @override
  String get calendarJoinMeetingFailed => 'Could not open the meeting link.';

  @override
  String get calendarJoinMeetingInvalid =>
      'Meeting link is missing or invalid.';

  @override
  String get calendarConflictConfirmTitle => 'Confirm schedule conflicts';

  @override
  String get calendarConflictConfirmBody =>
      'This event has soft conflicts. Confirm the warnings to continue.';

  @override
  String calendarConflictAckOverlap(int count) {
    return 'Acknowledge participant/time overlap ($count)';
  }

  @override
  String get calendarConflictAckNonWorkingDay => 'Acknowledge non-working day';

  @override
  String get calendarConflictAckUnconfigured =>
      'Acknowledge unconfigured schedule';

  @override
  String get calendarConflictAckOutsideWindow =>
      'Acknowledge outside working window';

  @override
  String get calendarConflictDayOffReason => 'Day-off override reason';

  @override
  String get calendarConflictConfirmContinue => 'Continue anyway';

  @override
  String get calendarMutationSuccess => 'Calendar event saved.';

  @override
  String get calendarMutationCancelled => 'Event cancelled.';

  @override
  String get calendarMutationMarkedDone => 'Event marked done.';

  @override
  String get calendarErrorStaleVersion =>
      'This event changed on another screen. Refresh and try again.';

  @override
  String get calendarErrorLocalTimeNonexistent =>
      'That local time does not exist on this date (DST).';

  @override
  String get calendarErrorLocalTimeAmbiguous =>
      'That local time is ambiguous on this date (DST).';

  @override
  String get calendarErrorTimezoneUnconfigured =>
      'Calendar timezone is not configured.';

  @override
  String get calendarErrorTimeWindowCrossDate =>
      'Timed windows must stay on the same scheduled date.';

  @override
  String get calendarErrorIdempotencyMismatch =>
      'A previous submit used different data. Close and try again.';

  @override
  String get calendarValidationTypeRequired => 'Select a category.';

  @override
  String get calendarValidationTitleRequired => 'Arabic title is required.';

  @override
  String get calendarValidationMeetingModeRequired =>
      'Meeting mode is required.';

  @override
  String get calendarValidationMeetingUrlRequired =>
      'A valid HTTPS meeting URL is required.';

  @override
  String get calendarValidationMeetingLocationRequired =>
      'Meeting location is required.';

  @override
  String get calendarValidationTimeRequired =>
      'Start and end times are required.';

  @override
  String get calendarValidationTimeOrder =>
      'End time must be after start time.';

  @override
  String calendarTimeWindowLabel(String start, String end) {
    return '$start – $end';
  }

  @override
  String get calendarWorkingDateExceptionsSectionTitle =>
      'Holidays & date exceptions';

  @override
  String get calendarWorkingDateExceptionsEmpty => 'No date exceptions found.';

  @override
  String get calendarWorkingDateExceptionsAdd => 'Add exception';

  @override
  String get calendarWorkingDateExceptionsFilterStatusLabel => 'Status';

  @override
  String get calendarWorkingDateExceptionsFilterActive => 'Active';

  @override
  String get calendarWorkingDateExceptionsFilterCancelled => 'Cancelled';

  @override
  String get calendarWorkingDateExceptionsFilterAll => 'All';

  @override
  String get calendarWorkingDateExceptionsPermissionDenied =>
      'You do not have permission to view date exceptions.';

  @override
  String get calendarWorkingDateExceptionKindOfficialHoliday =>
      'Official holiday';

  @override
  String get calendarWorkingDateExceptionKindCompanyClosure =>
      'Company closure';

  @override
  String get calendarWorkingDateExceptionKindExceptionalWorkingDay =>
      'Exceptional working day';

  @override
  String get calendarWorkingDateExceptionStatusActive => 'Active';

  @override
  String get calendarWorkingDateExceptionStatusCancelled => 'Cancelled';

  @override
  String calendarWorkingDateExceptionDateRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get calendarWorkingDateExceptionCreateTitle => 'Add date exception';

  @override
  String get calendarWorkingDateExceptionEditTitle => 'Edit date exception';

  @override
  String get calendarWorkingDateExceptionKindLabel => 'Kind';

  @override
  String get calendarWorkingDateExceptionStartDate => 'Start date';

  @override
  String get calendarWorkingDateExceptionEndDate => 'End date';

  @override
  String get calendarWorkingDateExceptionTitleAr => 'Title (Arabic)';

  @override
  String get calendarWorkingDateExceptionTitleEn => 'Title (English)';

  @override
  String get calendarWorkingDateExceptionNotes => 'Notes (optional)';

  @override
  String get calendarWorkingDateExceptionDayModeLabel =>
      'Working hours for this day';

  @override
  String get calendarWorkingDateExceptionDayMode24Hours => '24 hours';

  @override
  String get calendarWorkingDateExceptionDayModeLimitedHours =>
      'Limited working hours';

  @override
  String get calendarWorkingDateExceptionCreateConfirm => 'Create';

  @override
  String get calendarWorkingDateExceptionSaveConfirm => 'Save';

  @override
  String get calendarWorkingDateExceptionEditAction => 'Edit';

  @override
  String get calendarWorkingDateExceptionCancelAction => 'Cancel';

  @override
  String get calendarWorkingDateExceptionCancelTitle => 'Cancel date exception';

  @override
  String get calendarWorkingDateExceptionCancelBody =>
      'Cancelling requires a reason and preserves the exception for audit.';

  @override
  String get calendarWorkingDateExceptionCancelConfirm => 'Cancel exception';

  @override
  String get calendarWorkingDateExceptionCreated => 'Date exception created.';

  @override
  String get calendarWorkingDateExceptionUpdated => 'Date exception updated.';

  @override
  String get calendarWorkingDateExceptionCancelSuccess =>
      'Date exception cancelled.';

  @override
  String get calendarErrorWorkingDateExceptionOverlap =>
      'This date range overlaps an existing active date exception.';

  @override
  String get calendarWorkingDateExceptionValidationKindRequired =>
      'Select a kind.';

  @override
  String get calendarWorkingDateExceptionValidationDateRequired =>
      'Start and end dates are required.';

  @override
  String get calendarWorkingDateExceptionValidationDateInvalid =>
      'Enter valid dates.';

  @override
  String get calendarWorkingDateExceptionValidationDateRangeInvalid =>
      'End date must not be before the start date.';

  @override
  String get calendarWorkingDateExceptionValidationDateRangeTooLong =>
      'Date range cannot exceed 366 days.';

  @override
  String get calendarWorkingDateExceptionValidationTitleRequired =>
      'Enter a title in Arabic or English.';

  @override
  String get calendarWorkingDateExceptionValidationTitleTooLong =>
      'Title is too long.';

  @override
  String get calendarWorkingDateExceptionValidationNotesTooLong =>
      'Notes are too long.';

  @override
  String get calendarWorkingDateExceptionValidationDayModeRequired =>
      'Select 24-hour or limited working hours.';

  @override
  String get calendarWorkingDateExceptionValidationDayModeNotAllowed =>
      'Working hours only apply to an exceptional working day.';

  @override
  String get calendarWorkingDateExceptionValidationWorkWindowRequired =>
      'Enter start and end working hours.';

  @override
  String get calendarWorkingDateExceptionValidationWorkWindowNotAllowed =>
      'Working hours are not allowed for this selection.';

  @override
  String get calendarWorkingDateExceptionValidationWorkWindowInvalid =>
      'Enter valid HH:mm working hours.';

  @override
  String get calendarWorkingDateExceptionValidationWorkWindowOrder =>
      'End time must be after start time.';

  @override
  String calendarDateExceptionKindTitle(String kind, String title) {
    return '$kind – $title';
  }

  @override
  String calendarAgendaExceptionLabel(String kindTitle) {
    return 'Exception: $kindTitle';
  }

  @override
  String calendarConflictNonWorkingDayExceptionLabel(String kindTitle) {
    return 'Non-working day: $kindTitle';
  }

  @override
  String calendarMonthExceptionMarkerSemantics(String kindTitle) {
    return 'Date exception: $kindTitle';
  }

  @override
  String get calendarAssignAction => 'Assign';

  @override
  String get calendarRescheduleAction => 'Reschedule';

  @override
  String get calendarAssignDialogTitle => 'Assign event';

  @override
  String calendarAssignCurrentAssignee(String name) {
    return 'Current assignee: $name';
  }

  @override
  String get calendarAssignCurrentlyUnassigned => 'Currently unassigned.';

  @override
  String get calendarAssignCurrentUnavailable =>
      'Current assignee — unavailable (inactive)';

  @override
  String get calendarAssignUnassignOption => 'Unassigned';

  @override
  String get calendarAssignSearchHint => 'Search active employees';

  @override
  String get calendarAssignNoResults => 'No matching active employees.';

  @override
  String get calendarAssignRetry => 'Retry';

  @override
  String get calendarAssignWarningNoCalendarAccess =>
      'No calendar access — assigned events will not be visible to them.';

  @override
  String get calendarAssignWarningNoActiveAccount =>
      'Account is inactive for this company.';

  @override
  String get calendarAssignWarningNoAppAccount =>
      'No app account — they cannot sign in.';

  @override
  String get calendarAssignSubmit => 'Assign';

  @override
  String get calendarAssignSuccess => 'Assignment saved.';

  @override
  String get calendarAssignedEventHidden =>
      'Assignment saved. This event is no longer visible in your view.';

  @override
  String get calendarRescheduleDialogTitle => 'Reschedule event';

  @override
  String calendarRescheduleCurrentDate(String date) {
    return 'Current date: $date';
  }

  @override
  String calendarRescheduleTargetDate(String date) {
    return 'New date: $date';
  }

  @override
  String get calendarRescheduleDateUnchanged =>
      'Pick a different date to enable rescheduling.';

  @override
  String calendarRescheduleTimedWindow(String start, String end) {
    return 'Time window $start–$end is kept on the new date.';
  }

  @override
  String get calendarRescheduleReasonLabel => 'Reschedule reason';

  @override
  String get calendarRescheduleReasonRequired =>
      'Enter a non-empty reschedule reason.';

  @override
  String get calendarRescheduleSubmit => 'Reschedule';

  @override
  String get calendarRescheduleSuccess => 'Event rescheduled.';

  @override
  String get calendarErrorAssignmentNotApplicable =>
      'This event cannot be assigned.';

  @override
  String get calendarPreviousWeek => 'Previous week';

  @override
  String get calendarNextWeek => 'Next week';

  @override
  String get calendarMobileDaySelected => 'Selected';

  @override
  String get calendarOverdueSectionExpand => 'Show overdue outside range';

  @override
  String get calendarOverdueSectionCollapse => 'Hide overdue outside range';

  @override
  String get calendarDirectionsUnavailable => 'Directions not available';
}
