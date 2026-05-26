import '../../../core/errors/products_exception.dart';
import '../../../domain/validators/validation_result.dart';
import '../../auth/domain/app_session.dart';
import 'product.dart';
import 'product_form_state.dart';

const _costFieldPermissions = [
  'products.field.avg_cost',
  'products.field.last_purchase_cost',
  'products.field.min_sale_price',
  'products.field.min_rental_price',
];

/// Whether reads may use [products] with full cost columns (not [products_safe]).
bool canViewFullProductCosts(AppSession session) {
  if (session.permissions.isManager) return true;
  return _costFieldPermissions.every(session.permissions.can);
}

bool canWriteProductCosts(AppSession session) {
  if (session.permissions.isManager) return true;
  return _costFieldPermissions.every(session.permissions.can);
}

String productReadTableForSession(AppSession session) {
  return canViewFullProductCosts(session) ? 'products' : 'products_safe';
}

String productReadColumnsForSession(AppSession session) {
  return canViewFullProductCosts(session)
      ? ProductColumns.full
      : ProductColumns.safe;
}

/// Non-cost columns for inventory balance / stock label hydration.
const productStockLabelColumns =
    'id, sku, name_ar, name_en, reorder_point';

String productStockLabelColumnsForSession(AppSession session) =>
    productStockLabelColumns;

String productMutationReturnColumnsForSession(AppSession session) {
  return canViewFullProductCosts(session) ? ProductColumns.full : 'id';
}

bool _hasSubmittedExistingCostFields(ProductFormState input) {
  return input.avgCost != null ||
      input.lastPurchaseCost != null ||
      input.minSalePrice != null;
}

/// Pure cost write policy — unit-testable without Supabase.
ValidationResult validateProductCostWrite(
  AppSession session,
  ProductFormState input,
) {
  final codes = <String>[];

  if (input.minRentalPrice != null) {
    codes.add(ProductsException.fieldNotSupported);
  }

  if (_hasSubmittedExistingCostFields(input) && !canWriteProductCosts(session)) {
    codes.add(ProductsException.permissionDenied);
  }

  if (codes.isEmpty) return const ValidationResult.valid();
  return ValidationResult(codes: codes);
}

/// Throws [ProductsException] when [validateProductCostWrite] fails.
void assertProductCostWrite(AppSession session, ProductFormState input) {
  final result = validateProductCostWrite(session, input);
  if (result.isValid) return;
  final code = result.codes.first;
  throw ProductsException(code: code);
}
