import 'package:decimal/decimal.dart';

import '../../finance_shared/domain/payment_method.dart';
import 'voucher_type.dart';

/// Manual allocation row for receipt/payment voucher RPC payloads.
class VoucherAllocationInput {
  const VoucherAllocationInput({
    required this.invoiceId,
    required this.allocatedAmount,
  });

  final String invoiceId;
  final Decimal allocatedAmount;

  Map<String, dynamic> toPayload() {
    return {
      'invoice_id': invoiceId,
      'allocated_amount': allocatedAmount.toString(),
    };
  }
}

/// Receipt or payment voucher form state mapped to record RPC payloads.
class VoucherFormState {
  const VoucherFormState({
    required this.type,
    this.customerId,
    this.supplierId,
    this.accountId,
    required this.date,
    required this.amount,
    required this.paymentMethod,
    required this.cashAccountId,
    this.referenceNo,
    this.notes,
    this.allocationMode,
    this.allocations = const [],
    this.paymentDestination,
    this.cancellationReason,
  });

  final VoucherType type;
  final String? customerId;
  final String? supplierId;
  final String? accountId;
  final DateTime date;
  final Decimal amount;
  final PaymentMethod paymentMethod;
  final String cashAccountId;
  final String? referenceNo;
  final String? notes;
  final String? allocationMode;
  final List<VoucherAllocationInput> allocations;
  final String? paymentDestination;
  final String? cancellationReason;

  Map<String, dynamic> toRecordPayload() {
    return switch (type) {
      VoucherType.receipt => {
        'customer_id': customerId,
        'date': _isoDate(date),
        'amount': amount.toString(),
        'payment_method': paymentMethod.toDb(),
        'cash_account_id': cashAccountId,
        'allocation_mode': allocationMode ?? 'fifo',
        if (referenceNo?.trim().isNotEmpty == true)
          'reference_no': referenceNo!.trim(),
        if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
        if (allocationMode == 'manual')
          'allocations': allocations.map((a) => a.toPayload()).toList(),
      },
      VoucherType.payment => {
        'payment_destination': paymentDestination ?? 'supplier',
        'date': _isoDate(date),
        'amount': amount.toString(),
        'payment_method': paymentMethod.toDb(),
        'cash_account_id': cashAccountId,
        if (paymentDestination == 'supplier') ...{
          'supplier_id': supplierId,
          'allocation_mode': allocationMode ?? 'fifo',
          if (allocationMode == 'manual')
            'allocations': allocations.map((a) => a.toPayload()).toList(),
        },
        if (paymentDestination == 'account') 'account_id': accountId,
        if (referenceNo?.trim().isNotEmpty == true)
          'reference_no': referenceNo!.trim(),
        if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
      },
    };
  }

  Map<String, dynamic> toReturnRefundPayload({
    required bool includeAllocations,
  }) {
    return {
      'date': _isoDate(date),
      'amount': amount.toString(),
      'payment_method': paymentMethod.toDb(),
      'cash_account_id': cashAccountId,
      if (referenceNo?.trim().isNotEmpty == true)
        'reference_no': referenceNo!.trim(),
      if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
      if (includeAllocations)
        'allocations': allocations
            .map(
              (a) => {
                'return_invoice_id': a.invoiceId,
                'allocated_amount': a.allocatedAmount.toString(),
              },
            )
            .toList(),
    };
  }

  Map<String, dynamic> toCancelPayload(String voucherId) {
    return {
      'voucher_id': voucherId,
      'reason': cancellationReason?.trim() ?? '',
    };
  }
}

String _isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
