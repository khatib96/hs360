import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import '../../finance_shared/domain/payment_method.dart';
import '../../finance_shared/domain/party_reference.dart';
import 'voucher_status.dart';
import 'voucher_type.dart';

class VoucherSummary {
  const VoucherSummary({
    required this.id,
    this.voucherNumber,
    required this.type,
    required this.status,
    required this.date,
    required this.amount,
    required this.paymentMethod,
    this.referenceNo,
    this.customer,
    this.supplier,
    this.accountId,
    this.cashAccountId,
    required this.allocatedAmount,
    required this.unallocatedAmount,
    this.journalEntryId,
    this.cancelledAt,
  });

  final String id;
  final String? voucherNumber;
  final VoucherType type;
  final VoucherStatus status;
  final DateTime date;
  final Decimal amount;
  final PaymentMethod paymentMethod;
  final String? referenceNo;
  final PartyReference? customer;
  final PartyReference? supplier;
  final String? accountId;
  final String? cashAccountId;
  final Decimal allocatedAmount;
  final Decimal unallocatedAmount;
  final String? journalEntryId;
  final DateTime? cancelledAt;

  factory VoucherSummary.fromListRow(Map<String, dynamic> row) {
    final customerId = row['customer_id'] as String?;
    final supplierId = row['supplier_id'] as String?;
    return VoucherSummary(
      id: row['id'] as String,
      voucherNumber: row['voucher_number'] as String?,
      type: VoucherType.fromDb(row['type'] as String?),
      status: VoucherStatus.fromDb(row['status'] as String?),
      date: DateTime.parse(row['date'] as String),
      amount: parseDecimal(row['amount']),
      paymentMethod: PaymentMethod.fromDb(row['payment_method'] as String?),
      referenceNo: row['reference_no'] as String?,
      customer: customerId != null
          ? PartyReference(
              customerId: customerId,
              nameAr: row['customer_name_ar'] as String? ?? '',
              nameEn: row['customer_name_en'] as String? ?? '',
            )
          : null,
      supplier: supplierId != null
          ? PartyReference(
              supplierId: supplierId,
              nameAr: row['supplier_name_ar'] as String? ?? '',
              nameEn: row['supplier_name_en'] as String? ?? '',
            )
          : null,
      accountId: row['account_id'] as String?,
      cashAccountId: row['cash_account_id'] as String?,
      allocatedAmount: parseDecimal(row['allocated_amount']),
      unallocatedAmount: parseDecimal(row['unallocated_amount']),
      journalEntryId: row['journal_entry_id'] as String?,
      cancelledAt: row['cancelled_at'] != null
          ? DateTime.parse(row['cancelled_at'] as String)
          : null,
    );
  }
}
