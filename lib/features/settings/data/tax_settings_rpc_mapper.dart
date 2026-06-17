import '../../../core/utils/decimal_parser.dart';
import '../../../domain/finance/tax_rate.dart';

abstract final class TaxRateColumns {
  static const list = '''
id, code, name_ar, name_en, rate, effective_from, effective_to,
output_account_id, input_account_id, expense_account_id,
is_recoverable, is_active, created_at, updated_at
''';
}

TaxRateVersion mapTaxRateRow(Map<String, dynamic> row) {
  return TaxRateVersion(
    id: row['id'] as String,
    code: row['code'] as String,
    rate: parseDecimal(row['rate']),
    effectiveFrom: DateTime.parse(row['effective_from'] as String),
    effectiveTo: row['effective_to'] != null
        ? DateTime.parse(row['effective_to'] as String)
        : null,
    isActive: row['is_active'] as bool? ?? true,
  );
}
