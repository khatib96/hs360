import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';

/// Totals from [get_customer_balance_summary] RPC.
class CustomerBalanceSummary {
  const CustomerBalanceSummary({
    required this.debitTotal,
    required this.creditTotal,
    required this.balance,
  });

  final Decimal debitTotal;
  final Decimal creditTotal;
  final Decimal balance;

  factory CustomerBalanceSummary.zero() {
    return CustomerBalanceSummary(
      debitTotal: Decimal.zero,
      creditTotal: Decimal.zero,
      balance: Decimal.zero,
    );
  }

  factory CustomerBalanceSummary.fromRow(Map<String, dynamic> row) {
    return CustomerBalanceSummary(
      debitTotal: parseDecimal(row['debit_total']),
      creditTotal: parseDecimal(row['credit_total']),
      balance: parseDecimal(row['balance']),
    );
  }
}
