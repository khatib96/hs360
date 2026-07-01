import 'package:decimal/decimal.dart';

import '../../../domain/finance/invoice_line_math.dart';
import '../../../domain/finance/invoice_totals.dart';
import '../../../domain/finance/tax_class.dart';
import '../domain/invoice_draft.dart';
import '../domain/invoice_form_state.dart' as domain;
import '../domain/invoice_type.dart';
import '../../products/domain/product.dart';
import 'invoice_form_state.dart';

domain.InvoiceFormState buildSafeInvoiceFormState({
  required InvoiceType type,
  required String? invoiceId,
  required String? customerId,
  required String? supplierId,
  String? cashAccountId,
  required String warehouseId,
  required DateTime date,
  required DateTime? dueDate,
  required String? notes,
  required List<InvoiceFormLineUiState> lines,
}) {
  final draftLines = <InvoiceDraftLine>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.product == null) continue;
    draftLines.add(
      InvoiceDraftLine(
        lineOrder: draftLines.length + 1,
        productId: line.product!.id,
        qty: line.qty,
        unitPrice: line.unitPrice,
        discountPct: line.discountPct,
        productUnitId: line.productUnitId,
        units: line.units,
      ),
    );
  }

  return domain.InvoiceFormState(
    draft: InvoiceDraft(
      type: type,
      invoiceId: invoiceId,
      customerId: customerId,
      supplierId: supplierId,
      cashAccountId: cashAccountId,
      warehouseId: warehouseId,
      date: date,
      dueDate: dueDate,
      notes: notes,
      lines: draftLines,
    ),
  );
}

Map<String, bool> serializedByProductIdFromLines(
  List<InvoiceFormLineUiState> lines,
) {
  final map = <String, bool>{};
  for (final line in lines) {
    final product = line.product;
    if (product != null) {
      map[product.id] = product.isSerialized;
    }
  }
  return map;
}

/// Whether a line can safely feed the estimate math without throwing.
///
/// Mirrors the invariants enforced by `calculateInvoiceLineSnapshot`
/// (positive qty, non-negative price, discount within 0..100). Lines that are
/// mid-edit (no product, empty/zero/invalid qty) are simply excluded from the
/// live estimate; final validation on Confirm still rejects them.
bool isEstimableLine(InvoiceFormLineUiState line) {
  if (line.product == null) return false;
  if (line.qty <= Decimal.zero) return false;
  if (line.unitPrice < Decimal.zero) return false;
  if (line.discountPct < Decimal.zero ||
      line.discountPct > Decimal.fromInt(100)) {
    return false;
  }
  return true;
}

InvoiceEstimateTotals? computeEstimateTotals({
  required List<InvoiceFormLineUiState> lines,
  required int decimalPlaces,
  required bool taxEnabled,
  Decimal? effectiveTaxRate,
  String? effectiveTaxRateId,
}) {
  if (lines.isEmpty) return null;

  final inputs = <InvoiceLineInput>[];
  for (final line in lines) {
    if (!isEstimableLine(line)) continue;
    inputs.add(
      InvoiceLineInput(
        productId: line.product!.id,
        qty: line.qty,
        unitPrice: line.unitPrice,
        discountPct: line.discountPct,
        taxClass: ProductTaxClass.nonTaxable,
      ),
    );
  }
  if (inputs.isEmpty) return null;

  final canShowTax =
      taxEnabled && effectiveTaxRate != null && effectiveTaxRate > Decimal.zero;

  final totals = calculateInvoiceTotals(
    lines: inputs,
    decimalPlaces: decimalPlaces,
    taxEnabled: canShowTax,
    effectiveTaxRateId: canShowTax ? effectiveTaxRateId : null,
    effectiveTaxRate: canShowTax ? effectiveTaxRate : null,
  );

  return InvoiceEstimateTotals(
    subtotal: totals.subtotal,
    discountAmount: totals.discountAmount,
    taxAmount: canShowTax ? totals.taxAmount : null,
    total: canShowTax ? totals.total : totals.subtotal - totals.discountAmount,
    isTaxEstimate: canShowTax,
  );
}

class InvoiceEstimateTotals {
  const InvoiceEstimateTotals({
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.total,
    required this.isTaxEstimate,
  });

  final Decimal subtotal;
  final Decimal discountAmount;
  final Decimal? taxAmount;
  final Decimal total;
  final bool isTaxEstimate;
}

/// Display-only per-line net total (gross - discount), before tax.
///
/// Mirrors the server line math for preview purposes; does not affect posting.
Decimal lineNetTotalEstimate({
  required Decimal qty,
  required Decimal unitPrice,
  required Decimal discountPct,
  required int decimalPlaces,
}) {
  final safeQty = qty < Decimal.zero ? Decimal.zero : qty;
  final safePrice = unitPrice < Decimal.zero ? Decimal.zero : unitPrice;
  var pct = discountPct;
  if (pct < Decimal.zero) pct = Decimal.zero;
  if (pct > Decimal.fromInt(100)) pct = Decimal.fromInt(100);

  final gross = roundMoney(safeQty * safePrice, decimalPlaces);
  final discount = roundMoney(
    (gross * pct / Decimal.fromInt(100)).toDecimal(),
    decimalPlaces,
  );
  return gross - discount;
}

List<InvoiceFormLineUiState> linesFromProducts(
  List<InvoiceDraftLine> draftLines,
  Map<String, Product> productsById,
) {
  return draftLines
      .map(
        (line) => InvoiceFormLineUiState(
          product: productsById[line.productId],
          qty: line.qty,
          unitPrice: line.unitPrice,
          discountPct: line.discountPct,
          productUnitId: line.productUnitId,
          units: line.units,
        ),
      )
      .toList();
}
