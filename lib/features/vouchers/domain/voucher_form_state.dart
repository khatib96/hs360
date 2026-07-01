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

  VoucherFormState copyWith({
    VoucherType? type,
    String? customerId,
    bool clearCustomerId = false,
    String? supplierId,
    bool clearSupplierId = false,
    String? accountId,
    bool clearAccountId = false,
    DateTime? date,
    Decimal? amount,
    PaymentMethod? paymentMethod,
    String? cashAccountId,
    String? referenceNo,
    bool clearReferenceNo = false,
    String? notes,
    bool clearNotes = false,
    String? allocationMode,
    bool clearAllocationMode = false,
    List<VoucherAllocationInput>? allocations,
    String? paymentDestination,
    bool clearPaymentDestination = false,
    String? cancellationReason,
  }) {
    return VoucherFormState(
      type: type ?? this.type,
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      supplierId: clearSupplierId ? null : (supplierId ?? this.supplierId),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      date: date ?? this.date,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cashAccountId: cashAccountId ?? this.cashAccountId,
      referenceNo: clearReferenceNo ? null : (referenceNo ?? this.referenceNo),
      notes: clearNotes ? null : (notes ?? this.notes),
      allocationMode: clearAllocationMode
          ? null
          : (allocationMode ?? this.allocationMode),
      allocations: allocations ?? this.allocations,
      paymentDestination: clearPaymentDestination
          ? null
          : (paymentDestination ?? this.paymentDestination),
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }

  Map<String, dynamic> toRecordPayload() {
    return switch (type) {
      VoucherType.receipt => _receiptPayload(),
      VoucherType.payment => _paymentPayload(),
    };
  }

  Map<String, dynamic> _receiptPayload() {
    final isDirectAccount = accountId != null && accountId!.trim().isNotEmpty;
    return {
      'date': _isoDate(date),
      'amount': amount.toString(),
      'payment_method': paymentMethod.toDb(),
      'cash_account_id': cashAccountId,
      if (isDirectAccount) ...{
        'receipt_source': 'account',
        'account_id': accountId,
      } else ...{
        'receipt_source': 'customer',
        'customer_id': customerId,
        'allocation_mode': allocationMode ?? 'fifo',
        if (allocationMode == 'manual')
          'allocations': allocations.map((a) => a.toPayload()).toList(),
      },
      if (referenceNo?.trim().isNotEmpty == true)
        'reference_no': referenceNo!.trim(),
      if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
    };
  }

  Map<String, dynamic> _paymentPayload() {
    final destination = paymentDestination ?? 'account';
    return {
      'payment_destination': destination,
      'date': _isoDate(date),
      'amount': amount.toString(),
      'payment_method': paymentMethod.toDb(),
      'cash_account_id': cashAccountId,
      if (destination == 'supplier') ...{
        'supplier_id': supplierId,
        'allocation_mode': allocationMode ?? 'fifo',
        if (allocationMode == 'manual')
          'allocations': allocations.map((a) => a.toPayload()).toList(),
      },
      if (destination == 'account') 'account_id': accountId,
      if (referenceNo?.trim().isNotEmpty == true)
        'reference_no': referenceNo!.trim(),
      if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
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
