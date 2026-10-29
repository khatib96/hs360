import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import '../../auth/domain/app_session.dart';

/// One payment-confirmed rental collection (invoice + receipt voucher).
class RentalCollectionEntry {
  const RentalCollectionEntry({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.date,
    required this.total,
    required this.isCancelled,
    required this.coverageMonths,
    this.voucherNumber,
    this.cancellationReason,
  });

  final String invoiceId;
  final String invoiceNumber;
  final DateTime date;
  final Decimal total;
  final bool isCancelled;
  final List<DateTime> coverageMonths;
  final String? voucherNumber;
  final String? cancellationReason;

  factory RentalCollectionEntry.fromJson(Map<String, dynamic> json) {
    return RentalCollectionEntry(
      invoiceId: json['invoice_id'] as String,
      invoiceNumber: json['invoice_number'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      total: parseDecimal(json['total']),
      isCancelled: json['status'] == 'cancelled',
      coverageMonths: _months(json['coverage_months']),
      voucherNumber: json['voucher_number'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
    );
  }
}

class RentalArrearsItem {
  const RentalArrearsItem({
    required this.contractId,
    required this.contractNumber,
    required this.customerNameAr,
    required this.customerNameEn,
    required this.monthlyRentalValue,
    required this.months,
    required this.amount,
    required this.oldestDueDate,
  });

  final String contractId;
  final String contractNumber;
  final String customerNameAr;
  final String customerNameEn;
  final Decimal monthlyRentalValue;
  final List<DateTime> months;
  final Decimal amount;
  final DateTime oldestDueDate;

  String customerName(String languageCode) {
    final preferred = languageCode == 'ar' ? customerNameAr : customerNameEn;
    return preferred.trim().isNotEmpty
        ? preferred
        : (customerNameAr.isNotEmpty ? customerNameAr : customerNameEn);
  }

  factory RentalArrearsItem.fromJson(Map<String, dynamic> json) {
    return RentalArrearsItem(
      contractId: json['contract_id'] as String,
      contractNumber: json['contract_number'] as String? ?? '',
      customerNameAr: json['customer_name_ar'] as String? ?? '',
      customerNameEn: json['customer_name_en'] as String? ?? '',
      monthlyRentalValue: parseDecimal(json['monthly_rental_value']),
      months: _months(json['months']),
      amount: parseDecimal(json['amount']),
      oldestDueDate: DateTime.parse(json['oldest_due_date'] as String),
    );
  }
}

/// Uncollected rental months whose billing day has passed (no invoices).
class RentalArrearsReport {
  const RentalArrearsReport({
    required this.asOf,
    required this.currencyCode,
    required this.totalAmount,
    required this.totalMonths,
    required this.items,
  });

  final DateTime asOf;
  final String currencyCode;
  final Decimal totalAmount;
  final int totalMonths;
  final List<RentalArrearsItem> items;

  factory RentalArrearsReport.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    return RentalArrearsReport(
      asOf: DateTime.parse(json['as_of'] as String),
      currencyCode: json['currency_code'] as String? ?? '',
      totalAmount: parseDecimal(json['total_amount'] ?? 0),
      totalMonths: (json['total_months'] as num?)?.toInt() ?? 0,
      items: [
        if (items is List)
          for (final item in items)
            if (item is Map)
              RentalArrearsItem.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

List<DateTime> _months(Object? value) => [
  if (value is List)
    for (final month in value) ?DateTime.tryParse(month.toString()),
];

bool canViewRentalCollections(AppSession session) =>
    session.isManager ||
    session.permissions.can('invoices.view') ||
    session.permissions.can('invoices.view_sales') ||
    session.permissions.can('vouchers.view');

/// Cancelling reverses both the invoice and the receipt voucher.
bool canCancelRentalCollection(AppSession session) =>
    session.isManager ||
    (session.permissions.can('invoices.cancel') &&
        session.permissions.can('vouchers.cancel'));

bool canViewRentalArrears(AppSession session) =>
    session.isManager ||
    (session.permissions.can('contracts.view') &&
        (session.permissions.can('invoices.view') ||
            session.permissions.can('invoices.view_sales')));
