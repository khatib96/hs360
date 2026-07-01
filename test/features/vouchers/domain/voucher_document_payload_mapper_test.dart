import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_payload.dart';
import 'package:hs360/features/finance_shared/domain/party_reference.dart';
import 'package:hs360/features/finance_shared/domain/payment_method.dart';
import 'package:hs360/features/vouchers/domain/voucher_allocation.dart';
import 'package:hs360/features/vouchers/domain/voucher_detail.dart';
import 'package:hs360/features/vouchers/domain/voucher_document_payload_mapper.dart';
import 'package:hs360/features/vouchers/domain/voucher_status.dart';
import 'package:hs360/features/vouchers/domain/voucher_type.dart';

void main() {
  test('maps receipt voucher with document party payment only', () {
    final detail = VoucherDetail(
      id: 'v-1',
      voucherNumber: 'RV-001',
      type: VoucherType.receipt,
      status: VoucherStatus.confirmed,
      date: DateTime(2026, 6, 1),
      amount: Decimal.parse('150.000'),
      paymentMethod: PaymentMethod.cash,
      referenceNo: 'REF-1',
      collectedBy: 'Cashier',
      customer: const PartyReference(
        customerId: 'c-1',
        nameAr: 'عميل',
        nameEn: 'Customer',
      ),
      account: const VoucherAccountRef(
        id: 'acct-1',
        code: '2000',
        nameAr: 'حساب',
        nameEn: 'Account',
      ),
      cashAccount: const VoucherAccountRef(
        id: 'cash-1',
        code: '1000',
        nameAr: 'نقد',
        nameEn: 'Cash',
      ),
      allocations: const [],
      allocatedAmount: Decimal.parse('150.000'),
      unallocatedAmount: Decimal.zero,
    );

    final payload = mapVoucherDetailToPayload(detail);

    expect(payload, isA<VoucherPayload>());
    expect(payload.documentType, DocumentKind.receiptVoucher);
    expect(payload.document['number'], 'RV-001');
    expect(payload.document['date'], '2026-06-01');
    expect(payload.party['name_en'], 'Customer');
    expect(payload.payment['amount'], Decimal.parse('150.000'));
    expect(payload.payment['method'], 'Cash');
    expect(payload.payment['reference'], 'REF-1');
    expect(payload.payment['collected_by'], 'Cashier');
  });
}
