import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/tenant_currency_format.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/core/localization/locale_controller.dart';
import 'package:hs360/features/finance_shared/domain/finance_idempotency.dart';
import 'package:hs360/features/finance_shared/presentation/money_display.dart';
import 'package:hs360/features/finance_shared/presentation/tenant_currency_provider.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:decimal/decimal.dart';

void main() {
  group('FinanceIdempotencySession', () {
    test('preserves key on unknown errors', () {
      final session = FinanceIdempotencySession();
      final key = session.key;
      expect(
        session.shouldPreserveKeyOn(
          const FinanceException(code: FinanceException.unknown),
        ),
        isTrue,
      );
      expect(session.key, key);
    });

    test('clears policy on validation_failed', () {
      final session = FinanceIdempotencySession();
      expect(
        session.shouldPreserveKeyOn(
          const FinanceException(code: FinanceException.validationFailed),
        ),
        isFalse,
      );
    });
  });

  group('MoneyDisplay', () {
    Widget wrap(Widget child, TenantCurrencyFormat format, Locale locale) {
      return ProviderScope(
        overrides: [
          tenantCurrencyFormatProvider.overrideWith((ref) async => format),
          localeProvider.overrideWith((ref) => locale),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('symbol after with 3 decimals', (tester) async {
      await tester.pumpWidget(
        wrap(
          MoneyDisplay(amount: Decimal.parse('1234.567')),
          const TenantCurrencyFormat(
            isoCode: 'KWD',
            majorSymbolAr: 'د.ك',
            majorSymbolEn: 'KWD',
            decimalPlaces: 3,
            symbolPosition: 'after',
            thousandSeparator: ',',
            decimalSeparator: '.',
          ),
          const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('1,234.567 KWD'), findsOneWidget);
    });

    testWidgets('symbol before in Arabic', (tester) async {
      await tester.pumpWidget(
        wrap(
          MoneyDisplay(amount: Decimal.parse('10.5')),
          const TenantCurrencyFormat(
            isoCode: 'KWD',
            majorSymbolAr: 'د.ك',
            majorSymbolEn: 'KWD',
            decimalPlaces: 3,
            symbolPosition: 'before',
            thousandSeparator: ',',
            decimalSeparator: '.',
          ),
          const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('د.ك'), findsOneWidget);
    });
  });
}
