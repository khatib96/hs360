import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';

/// Invoice allocation on a voucher from detail RPC JSON.
class VoucherAllocation {
  const VoucherAllocation({
    required this.id,
    required this.invoiceId,
    this.invoiceNumber,
    this.invoiceDate,
    this.invoiceDueDate,
    this.invoiceTotal,
    required this.allocatedAmount,
    required this.isReversed,
    this.reversedAt,
  });

  final String id;
  final String invoiceId;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final DateTime? invoiceDueDate;
  final Decimal? invoiceTotal;
  final Decimal allocatedAmount;
  final bool isReversed;
  final DateTime? reversedAt;

  factory VoucherAllocation.fromJson(Map<String, dynamic> json) {
    return VoucherAllocation(
      id: json['id'] as String,
      invoiceId: json['invoice_id'] as String,
      invoiceNumber: json['invoice_number'] as String?,
      invoiceDate: json['invoice_date'] != null
          ? DateTime.parse(json['invoice_date'] as String)
          : null,
      invoiceDueDate: json['invoice_due_date'] != null
          ? DateTime.parse(json['invoice_due_date'] as String)
          : null,
      invoiceTotal: tryParseDecimal(json['invoice_total']),
      allocatedAmount: parseDecimal(json['allocated_amount']),
      isReversed: json['is_reversed'] as bool? ?? false,
      reversedAt: json['reversed_at'] != null
          ? DateTime.parse(json['reversed_at'] as String)
          : null,
    );
  }
}

class VoucherAccountRef {
  const VoucherAccountRef({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;

  factory VoucherAccountRef.fromJson(Map<String, dynamic> json) {
    return VoucherAccountRef(
      id: json['id'] as String,
      code: json['code'] as String,
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
    );
  }
}
