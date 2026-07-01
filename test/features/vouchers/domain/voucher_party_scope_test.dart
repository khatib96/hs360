import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/finance_shared/domain/party_reference.dart';
import 'package:hs360/features/vouchers/domain/voucher_party_scope.dart';
import 'package:hs360/features/vouchers/domain/voucher_status.dart';
import 'package:hs360/features/vouchers/domain/voucher_summary.dart';
import 'package:hs360/features/vouchers/domain/voucher_type.dart';
import 'package:hs360/features/finance_shared/domain/payment_method.dart';

VoucherSummary _voucher({
  required VoucherType type,
  String? customerId,
  String? supplierId,
}) {
  return VoucherSummary(
    id: 'v-1',
    type: type,
    status: VoucherStatus.confirmed,
    date: DateTime(2026, 6, 1),
    amount: Decimal.one,
    paymentMethod: PaymentMethod.cash,
    customer: customerId == null
        ? null
        : PartyReference(
            customerId: customerId,
            nameAr: 'عميل',
            nameEn: 'Customer',
          ),
    supplier: supplierId == null
        ? null
        : PartyReference(
            supplierId: supplierId,
            nameAr: 'مورد',
            nameEn: 'Supplier',
          ),
    allocatedAmount: Decimal.zero,
    unallocatedAmount: Decimal.one,
  );
}

void main() {
  test('scopeCustomerReceiptVouchers keeps receipt for matching customer', () {
    final rows = [
      _voucher(type: VoucherType.receipt, customerId: 'cust-1'),
      _voucher(type: VoucherType.payment, supplierId: 'cust-1'),
      _voucher(type: VoucherType.receipt, customerId: 'other'),
    ];

    final scoped = scopeCustomerReceiptVouchers(rows, 'cust-1');
    expect(scoped, hasLength(1));
    expect(scoped.first.type, VoucherType.receipt);
    expect(scoped.first.customer?.customerId, 'cust-1');
  });

  test('scopeSupplierPaymentVouchers keeps payment for matching supplier', () {
    final rows = [
      _voucher(type: VoucherType.payment, supplierId: 'sup-1'),
      _voucher(type: VoucherType.receipt, customerId: 'sup-1'),
      _voucher(type: VoucherType.payment, supplierId: 'other'),
    ];

    final scoped = scopeSupplierPaymentVouchers(rows, 'sup-1');
    expect(scoped, hasLength(1));
    expect(scoped.first.type, VoucherType.payment);
    expect(scoped.first.supplier?.supplierId, 'sup-1');
  });
}
