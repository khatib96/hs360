import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/finance_shared/presentation/finance_error_messages.dart';
import 'package:hs360/l10n/app_localizations.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations ar;

  setUpAll(() {
    en = lookupAppLocalizations(const Locale('en'));
    ar = lookupAppLocalizations(const Locale('ar'));
  });

  // Every known code that the invoice confirm/validation flow can surface must
  // resolve to a specific message — never the generic "unknown" fallback.
  const knownCodes = <String>[
    FinanceException.tenantNotFound,
    FinanceException.permissionDenied,
    FinanceException.validationFailed,
    FinanceException.insufficientStock,
    FinanceException.correctionDocumentRequired,
    FinanceException.returnDocumentRequired,
    FinanceException.serializedAdjustmentNotSupported,
    FinanceException.backendMigrationRequired,
    FinanceException.validationCustomerRequired,
    FinanceException.validationSupplierRequired,
    FinanceException.validationWarehouseRequired,
    FinanceException.validationPartyRequired,
    FinanceException.validationLinesRequired,
    FinanceException.validationProductRequired,
    FinanceException.validationLineQtyInvalid,
    FinanceException.validationLinePriceInvalid,
    FinanceException.validationDiscountOutOfRange,
    FinanceException.validationDueDateBeforeInvoiceDate,
    FinanceException.validationSerializedUnitRequired,
    FinanceException.validationSerialCountMismatch,
    FinanceException.validationOriginalInvoiceRequired,
    FinanceException.validationReturnReasonRequired,
    FinanceException.validationReturnQtyExceedsReturnable,
    FinanceException.validationCashAccountRequired,
    FinanceException.validationAccountRequired,
    FinanceException.belowMinProfit,
  ];

  group('financeErrorMessage', () {
    test('known codes never render the generic unknown message', () {
      for (final code in knownCodes) {
        final message = financeErrorMessage(en, code);
        expect(
          message,
          isNot(en.financeErrorUnknown),
          reason: 'code "$code" fell through to the generic message',
        );
        expect(message.trim(), isNotEmpty);
      }
    });

    test('specific finance codes map to the expected reason', () {
      expect(
        financeErrorMessage(en, FinanceException.validationLineQtyInvalid),
        en.financeValidationLineQtyInvalid,
      );
      expect(
        financeErrorMessage(en, FinanceException.insufficientStock),
        en.inventoryErrorInsufficientStock,
      );
      expect(
        financeErrorMessage(ar, FinanceException.validationCustomerRequired),
        ar.financeValidationCustomerRequired,
      );
      expect(
        financeErrorMessage(ar, FinanceException.backendMigrationRequired),
        ar.financeErrorBackendMigrationRequired,
      );
      expect(
        financeErrorMessage(en, FinanceException.belowMinProfit),
        en.financeErrorBelowMinProfit,
      );
    });

    test('unknown without detail uses the plain generic message', () {
      expect(
        financeErrorMessage(en, FinanceException.unknown),
        en.financeErrorUnknown,
      );
    });

    test('unknown WITH technical detail surfaces a diagnostic reference', () {
      final message = financeErrorMessage(
        en,
        FinanceException.unknown,
        technicalDetail: 'record_sales_invoice failed: weird_backend_token',
      );
      expect(message, isNot(en.financeErrorUnknown));
      expect(message, contains('weird_backend_token'));
    });

    test('diagnostic reference is whitespace-collapsed and length-capped', () {
      final long = 'x' * 400;
      final ref = financeDiagnosticReference(FinanceException.unknown, long);
      expect(ref, isNotNull);
      expect(ref!.length, lessThanOrEqualTo(120));

      final collapsed = financeDiagnosticReference(
        FinanceException.unknown,
        'line1\n   line2\t\tline3',
      );
      expect(collapsed, 'line1 line2 line3');
    });
  });

  group('financeErrorMessages (list)', () {
    test('joins each validation code to its specific reason', () {
      final message = financeErrorMessages(en, const [
        FinanceException.validationCustomerRequired,
        FinanceException.validationLineQtyInvalid,
      ]);
      expect(message, contains(en.financeValidationCustomerRequired));
      expect(message, contains(en.financeValidationLineQtyInvalid));
      expect(message, isNot(contains(en.financeErrorUnknown)));
    });
  });
}
