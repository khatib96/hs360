import 'voucher_summary.dart';
import 'voucher_type.dart';

/// Client-side guard for [list_vouchers] OR party filter (`customer_id` / `supplier_id`).
List<VoucherSummary> scopeCustomerReceiptVouchers(
  List<VoucherSummary> rows,
  String customerId,
) {
  return rows
      .where(
        (v) =>
            v.type == VoucherType.receipt &&
            v.customer?.customerId == customerId,
      )
      .toList();
}

List<VoucherSummary> scopeSupplierPaymentVouchers(
  List<VoucherSummary> rows,
  String supplierId,
) {
  return rows
      .where(
        (v) =>
            v.type == VoucherType.payment &&
            v.supplier?.supplierId == supplierId,
      )
      .toList();
}
