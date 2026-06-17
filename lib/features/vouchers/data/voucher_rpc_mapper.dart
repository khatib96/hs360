import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import '../../finance_shared/domain/party_reference.dart';
import '../../finance_shared/domain/payment_method.dart';
import '../domain/voucher_allocation.dart';
import '../domain/voucher_detail.dart';
import '../domain/voucher_form_state.dart';
import '../domain/voucher_status.dart';
import '../domain/voucher_type.dart';

Map<String, dynamic> returnRefundVoucherParams({
  required String rpcReturnInvoiceId,
  required VoucherFormState form,
  required String idempotencyKey,
}) {
  final returnInvoiceId = rpcReturnInvoiceId.trim();
  return {
    'p_return_invoice_id': returnInvoiceId.isEmpty ? null : returnInvoiceId,
    'p_data': form.toReturnRefundPayload(
      includeAllocations: returnInvoiceId.isEmpty,
    ),
    'p_idempotency_key': idempotencyKey,
  };
}

VoucherDetail mapVoucherDetail(Map<String, dynamic> json) {
  final customerJson = json['customer'];
  final supplierJson = json['supplier'];
  final allocationsRaw = json['allocations'];

  return VoucherDetail(
    id: json['id'] as String,
    voucherNumber: json['voucher_number'] as String?,
    type: VoucherType.fromDb(json['type'] as String?),
    status: VoucherStatus.fromDb(json['status'] as String?),
    date: DateTime.parse(json['date'] as String),
    amount: parseDecimal(json['amount']),
    paymentMethod: PaymentMethod.fromDb(json['payment_method'] as String?),
    referenceNo: json['reference_no'] as String?,
    notes: json['notes'] as String?,
    collectedBy: json['collected_by'] as String?,
    customer: customerJson is Map
        ? PartyReference.fromCustomerJson(
            Map<String, dynamic>.from(customerJson),
          )
        : null,
    supplier: supplierJson is Map
        ? PartyReference.fromSupplierJson(
            Map<String, dynamic>.from(supplierJson),
          )
        : null,
    account: VoucherAccountRef.fromJson(
      Map<String, dynamic>.from(json['account'] as Map),
    ),
    cashAccount: VoucherAccountRef.fromJson(
      Map<String, dynamic>.from(json['cash_account'] as Map),
    ),
    journalEntryId: json['journal_entry_id'] as String?,
    reversalJournalEntryId: json['reversal_journal_entry_id'] as String?,
    confirmedAt: json['confirmed_at'] != null
        ? DateTime.parse(json['confirmed_at'] as String)
        : null,
    confirmedBy: json['confirmed_by'] as String?,
    cancelledAt: json['cancelled_at'] != null
        ? DateTime.parse(json['cancelled_at'] as String)
        : null,
    cancelledBy: json['cancelled_by'] as String?,
    cancellationReason: json['cancellation_reason'] as String?,
    allocations: allocationsRaw is List
        ? allocationsRaw
              .map(
                (row) => VoucherAllocation.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList()
        : const [],
    allocatedAmount: parseDecimal(json['allocated_amount'] ?? 0),
    unallocatedAmount: parseDecimal(json['unallocated_amount'] ?? 0),
  );
}

class OpenInvoiceAllocationOption {
  const OpenInvoiceAllocationOption({
    required this.id,
    this.invoiceNumber,
    required this.status,
    required this.date,
    this.dueDate,
    required this.total,
    required this.paidAmount,
    required this.outstanding,
  });

  final String id;
  final String? invoiceNumber;
  final String status;
  final DateTime date;
  final DateTime? dueDate;
  final Decimal total;
  final Decimal paidAmount;
  final Decimal outstanding;

  factory OpenInvoiceAllocationOption.fromListRow(Map<String, dynamic> row) {
    return OpenInvoiceAllocationOption(
      id: row['id'] as String,
      invoiceNumber: row['invoice_number'] as String?,
      status: row['status'] as String,
      date: DateTime.parse(row['date'] as String),
      dueDate: row['due_date'] != null
          ? DateTime.parse(row['due_date'] as String)
          : null,
      total: parseDecimal(row['total']),
      paidAmount: parseDecimal(row['paid_amount']),
      outstanding: parseDecimal(row['outstanding']),
    );
  }
}
