import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_permissions.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';

void main() {
  AppSession session({
    Set<String> permissions = const {},
    bool manager = false,
  }) {
    return AppSession(
      userId: 'u1',
      email: 't@example.com',
      tenantId: 't1',
      tenantUserId: 'tu1',
      accountType: manager ? 'manager' : 'user',
      displayName: 'Test',
      preferredLocale: 'en',
      permissions: AppPermissions(isManager: manager, permissions: permissions),
    );
  }

  group('canPreviewDocument', () {
    test('manager previews finance documents without print permission', () {
      final mgr = session(manager: true);
      for (final kind in [
        DocumentKind.salesInvoice,
        DocumentKind.purchaseInvoice,
        DocumentKind.receiptVoucher,
      ]) {
        expect(canPreviewDocument(mgr, kind), isTrue, reason: kind.name);
        expect(canExportDocument(mgr, kind), isTrue, reason: kind.name);
      }
      expect(canPreviewDocument(mgr, DocumentKind.paymentVoucher), isFalse);
      expect(canExportDocument(mgr, DocumentKind.paymentVoucher), isFalse);
    });

    test('manager can preview all except payment_voucher', () {
      final s = session(manager: true);
      for (final kind in DocumentKind.values) {
        if (kind == DocumentKind.paymentVoucher) {
          expect(canPreviewDocument(s, kind), isFalse);
        } else {
          expect(canPreviewDocument(s, kind), isTrue, reason: kind.name);
        }
      }
    });

    test('payment_voucher is always false', () {
      expect(
        canPreviewDocument(
          session(permissions: {'vouchers.view'}),
          DocumentKind.paymentVoucher,
        ),
        isFalse,
      );
    });

    test('sales requires view and print', () {
      expect(canPreviewDocument(session(), DocumentKind.salesInvoice), isFalse);
      expect(
        canPreviewDocument(
          session(permissions: {'invoices.view_sales'}),
          DocumentKind.salesInvoice,
        ),
        isFalse,
      );
      expect(
        canPreviewDocument(
          session(permissions: {'invoices.view_sales', 'invoices.print'}),
          DocumentKind.salesInvoice,
        ),
        isTrue,
      );
      expect(
        canPreviewDocument(
          session(permissions: {'invoices.view', 'invoices.print'}),
          DocumentKind.salesInvoice,
        ),
        isTrue,
      );
    });

    test('purchase requires view and print', () {
      expect(
        canPreviewDocument(session(), DocumentKind.purchaseInvoice),
        isFalse,
      );
      expect(
        canPreviewDocument(
          session(permissions: {'invoices.view_purchase', 'invoices.print'}),
          DocumentKind.purchaseInvoice,
        ),
        isTrue,
      );
    });

    test('receipt requires vouchers.view and vouchers.print', () {
      expect(
        canPreviewDocument(
          session(permissions: {'vouchers.view'}),
          DocumentKind.receiptVoucher,
        ),
        isFalse,
      );
      expect(
        canPreviewDocument(
          session(permissions: {'vouchers.view', 'vouchers.print'}),
          DocumentKind.receiptVoucher,
        ),
        isTrue,
      );
      expect(
        canPreviewDocument(session(), DocumentKind.receiptVoucher),
        isFalse,
      );
    });

    test('customer statement requires ledger permission', () {
      expect(
        canPreviewDocument(
          session(permissions: {'customers.view_ledger'}),
          DocumentKind.customerStatement,
        ),
        isTrue,
      );
    });

    test('asset label requires product_units.view not print_label alone', () {
      expect(
        canPreviewDocument(
          session(permissions: {'product_units.print_label'}),
          DocumentKind.assetTagLabel,
        ),
        isFalse,
      );
      expect(
        canPreviewDocument(
          session(permissions: {'product_units.view'}),
          DocumentKind.assetTagLabel,
        ),
        isTrue,
      );
    });

    test('contract requires contracts.view and contracts.print', () {
      expect(canPreviewDocument(session(), DocumentKind.contract), isFalse);
      expect(
        canPreviewDocument(
          session(permissions: {'contracts.view'}),
          DocumentKind.contract,
        ),
        isFalse,
      );
      expect(
        canPreviewDocument(
          session(permissions: {'contracts.view', 'contracts.print'}),
          DocumentKind.contract,
        ),
        isTrue,
      );
    });
  });

  group('canExportDocument', () {
    test('payment_voucher is always false', () {
      expect(
        canExportDocument(session(manager: true), DocumentKind.paymentVoucher),
        isFalse,
      );
    });

    test('sales export requires preview and invoices.print', () {
      final previewOnly = session(permissions: {'invoices.view_sales'});
      expect(
        canExportDocument(previewOnly, DocumentKind.salesInvoice),
        isFalse,
      );
      final withPrint = session(
        permissions: {'invoices.view_sales', 'invoices.print'},
      );
      expect(canExportDocument(withPrint, DocumentKind.salesInvoice), isTrue);
    });

    test('purchase export requires preview and invoices.print', () {
      final withPrint = session(
        permissions: {'invoices.view_purchase', 'invoices.print'},
      );
      expect(
        canExportDocument(withPrint, DocumentKind.purchaseInvoice),
        isTrue,
      );
    });

    test('receipt export requires preview and vouchers.print', () {
      final previewOnly = session(permissions: {'vouchers.view'});
      expect(
        canExportDocument(previewOnly, DocumentKind.receiptVoucher),
        isFalse,
      );
      final withPrint = session(
        permissions: {'vouchers.view', 'vouchers.print'},
      );
      expect(canExportDocument(withPrint, DocumentKind.receiptVoucher), isTrue);
    });

    test('customer statement export mirrors preview', () {
      final s = session(permissions: {'customers.view_ledger'});
      expect(canExportDocument(s, DocumentKind.customerStatement), isTrue);
      expect(
        canExportDocument(session(), DocumentKind.customerStatement),
        isFalse,
      );
    });

    test('asset label export requires preview and print_label', () {
      final viewOnly = session(permissions: {'product_units.view'});
      expect(canExportDocument(viewOnly, DocumentKind.assetTagLabel), isFalse);
      final withPrint = session(
        permissions: {'product_units.view', 'product_units.print_label'},
      );
      expect(canExportDocument(withPrint, DocumentKind.assetTagLabel), isTrue);
    });

    test('contract export requires preview permissions', () {
      final previewOnly = session(permissions: {'contracts.view'});
      expect(canExportDocument(previewOnly, DocumentKind.contract), isFalse);
      final withPrint = session(
        permissions: {'contracts.view', 'contracts.print'},
      );
      expect(canExportDocument(withPrint, DocumentKind.contract), isTrue);
    });

    test('manager can export when preview allowed', () {
      expect(
        canExportDocument(session(manager: true), DocumentKind.salesInvoice),
        isTrue,
      );
    });
  });

  group('template settings permissions', () {
    test('template settings view permission', () {
      expect(canViewTemplateSettings(session()), isFalse);
      expect(
        canViewTemplateSettings(
          session(permissions: {'settings.templates.view'}),
        ),
        isTrue,
      );
      expect(canEditTemplateSettings(session()), isFalse);
      expect(
        canEditTemplateSettings(
          session(permissions: {'settings.templates.edit'}),
        ),
        isTrue,
      );
    });
  });
}
