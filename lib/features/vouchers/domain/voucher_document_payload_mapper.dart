import '../../../core/documents/domain/document_payload.dart';
import '../../finance_shared/domain/payment_method.dart';
import 'voucher_detail.dart';
import 'voucher_print_support.dart';

VoucherPayload mapVoucherDetailToPayload(VoucherDetail detail) {
  return VoucherPayload(
    documentType: documentKindForVoucher(detail),
    document: {
      'number': detail.voucherNumber ?? '',
      'date': _dateOnly(detail.date),
    },
    party: _partyFromDetail(detail),
    payment: {
      'amount': detail.amount,
      'method': _paymentMethodLabel(detail.paymentMethod),
      if (detail.referenceNo != null && detail.referenceNo!.trim().isNotEmpty)
        'reference': detail.referenceNo,
      if (detail.collectedBy != null && detail.collectedBy!.trim().isNotEmpty)
        'collected_by': detail.collectedBy,
    },
  );
}

Map<String, dynamic> _partyFromDetail(VoucherDetail detail) {
  final customer = detail.customer;
  if (customer != null) {
    return {
      'name_ar': customer.nameAr,
      'name_en': customer.nameEn,
      if (customer.code != null && customer.code!.isNotEmpty)
        'code': customer.code,
    };
  }
  final supplier = detail.supplier;
  if (supplier != null) {
    return {
      'name_ar': supplier.nameAr,
      'name_en': supplier.nameEn,
      if (supplier.code != null && supplier.code!.isNotEmpty)
        'code': supplier.code,
    };
  }
  return {
    'name_ar': detail.account.nameAr,
    'name_en': detail.account.nameEn,
    if (detail.account.code.isNotEmpty) 'code': detail.account.code,
  };
}

String _paymentMethodLabel(PaymentMethod method) {
  return switch (method) {
    PaymentMethod.cash => 'Cash',
    PaymentMethod.knet => 'KNET',
    PaymentMethod.bankTransfer => 'Bank transfer',
    PaymentMethod.cheque => 'Cheque',
    PaymentMethod.other => 'Other',
  };
}

String _dateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
