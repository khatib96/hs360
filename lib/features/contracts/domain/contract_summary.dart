import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import 'contract_status.dart';
import 'contract_type.dart';

/// Minimal bounded list row for contracts (fixture-ready for future list RPC).
class ContractSummary {
  const ContractSummary({
    required this.id,
    this.contractNumber,
    required this.type,
    required this.status,
    required this.startDate,
    this.endDate,
    this.customerId,
    this.customerNameAr,
    this.customerNameEn,
    this.serviceLocationId,
    this.monthlyRentalValue,
    this.minProfitOverridden,
  });

  final String id;
  final String? contractNumber;
  final ContractType type;
  final ContractStatus status;
  final DateTime startDate;
  final DateTime? endDate;
  final String? customerId;
  final String? customerNameAr;
  final String? customerNameEn;
  final String? serviceLocationId;
  final Decimal? monthlyRentalValue;
  final bool? minProfitOverridden;

  factory ContractSummary.fromListRow(Map<String, dynamic> row) {
    return ContractSummary(
      id: row['id'] as String,
      contractNumber: row['contract_number'] as String?,
      type: ContractType.fromDb(row['type'] as String?),
      status: ContractStatus.fromDb(row['status'] as String?),
      startDate: DateTime.parse(row['start_date'] as String),
      endDate: row['end_date'] != null
          ? DateTime.parse(row['end_date'] as String)
          : null,
      customerId: row['customer_id'] as String?,
      customerNameAr: row['customer_name_ar'] as String?,
      customerNameEn: row['customer_name_en'] as String?,
      serviceLocationId: row['service_location_id'] as String?,
      monthlyRentalValue: tryParseDecimal(row['monthly_rental_value']),
      minProfitOverridden: row['min_profit_overridden'] as bool?,
    );
  }
}
