import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/invoices/domain/invoice_status.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';
import 'package:hs360/features/invoices/presentation/invoice_display_helpers.dart';

void main() {
  group('statusFilterOptionsForType', () {
    test('sales excludes draft', () {
      final options = statusFilterOptionsForType(InvoiceType.sales);
      expect(options, contains(InvoiceStatus.confirmed));
      expect(options, isNot(contains(InvoiceStatus.draft)));
    });

    test('purchase includes draft', () {
      final options = statusFilterOptionsForType(InvoiceType.purchase);
      expect(options, contains(InvoiceStatus.draft));
    });

    test('returns only confirmed and cancelled', () {
      for (final type in [
        InvoiceType.salesReturn,
        InvoiceType.purchaseReturn,
      ]) {
        final options = statusFilterOptionsForType(type);
        expect(options, [InvoiceStatus.confirmed, InvoiceStatus.cancelled]);
      }
    });
  });
}
