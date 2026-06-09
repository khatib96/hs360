import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/tenant_currency_format.dart';
import 'package:hs360/core/documents/services/pdf/pdf_field_resolver.dart';

void main() {
  test('maps line.balance to the serialized running_balance field', () {
    final resolver = PdfFieldResolver(
      payload: const {},
      currency: TenantCurrencyFormat.defaults(),
      languageCode: 'en',
    );

    final rows = resolver.resolveLineRows(
      const ['line.balance'],
      const [
        {'running_balance': '150.000'},
      ],
    );

    expect(rows.single['line.balance'], '150.000');
  });

  test('omits repeated symbols only for statement money columns', () {
    final resolver = PdfFieldResolver(
      payload: const {},
      currency: TenantCurrencyFormat.defaults(),
      languageCode: 'en',
    );

    final rows = resolver.resolveLineRows(
      const ['line.debit', 'line.credit', 'line.total'],
      const [
        {'debit': '50.000', 'credit': '0.000', 'total': '50.000'},
      ],
    );

    expect(rows.single['line.debit'], '50.000');
    expect(rows.single['line.credit'], '0.000');
    expect(rows.single['line.total'], '50.000 KWD');
  });

  test('formats the same money field with Arabic and English symbols', () {
    final resolver = PdfFieldResolver(
      payload: const {
        'summary': {'opening_balance': '100.000'},
      },
      currency: TenantCurrencyFormat.defaults(),
      languageCode: 'bilingual',
    );

    expect(
      resolver.resolveMoney('summary.opening_balance', languageCode: 'ar'),
      '100.000 د.ك',
    );
    expect(
      resolver.resolveMoney('summary.opening_balance', languageCode: 'en'),
      '100.000 KWD',
    );
  });
}
