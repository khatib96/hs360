import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_payload.dart';
import 'package:hs360/core/errors/document_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/finance_shared/documents/finance_document_payload_loader.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';

import '../../invoices/fake_invoice_repository.dart';
import '../../vouchers/fake_voucher_repository.dart';

AppSession _session() {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: {'invoices.view_sales', 'vouchers.view'},
    ),
  );
}

void main() {
  test('loads invoice payload when invoiceType is provided', () async {
    final invoiceRepo = FakeInvoiceRepository(
      detailById: {'inv-1': sampleInvoiceDetail()},
    );
    final voucherRepo = FakeVoucherRepository();

    final payload = await loadFinanceDocumentPayloadForSession(
      invoiceRepository: invoiceRepo,
      voucherRepository: voucherRepo,
      session: _session(),
      kind: DocumentKind.salesInvoice,
      entityId: 'inv-1',
      invoiceType: InvoiceType.sales,
    );

    expect(payload, isA<InvoicePayload>());
    expect((payload as InvoicePayload).document['number'], 'SI-001');
  });

  test('rejects invoice preview without invoiceType', () async {
    final invoiceRepo = FakeInvoiceRepository(
      detailById: {'inv-1': sampleInvoiceDetail()},
    );
    final voucherRepo = FakeVoucherRepository();

    expect(
      () => loadFinanceDocumentPayloadForSession(
        invoiceRepository: invoiceRepo,
        voucherRepository: voucherRepo,
        session: _session(),
        kind: DocumentKind.salesInvoice,
        entityId: 'inv-1',
      ),
      throwsA(
        isA<DocumentException>().having(
          (e) => e.code,
          'code',
          DocumentException.unsupportedDocumentType,
        ),
      ),
    );
  });

  test('rejects invoice preview when invoiceType mismatches kind', () async {
    final invoiceRepo = FakeInvoiceRepository(
      detailById: {'inv-1': sampleInvoiceDetail()},
    );
    final voucherRepo = FakeVoucherRepository();

    expect(
      () => loadFinanceDocumentPayloadForSession(
        invoiceRepository: invoiceRepo,
        voucherRepository: voucherRepo,
        session: _session(),
        kind: DocumentKind.purchaseInvoice,
        entityId: 'inv-1',
        invoiceType: InvoiceType.sales,
      ),
      throwsA(
        isA<DocumentException>().having(
          (e) => e.code,
          'code',
          DocumentException.unsupportedDocumentType,
        ),
      ),
    );
  });

  test('loads voucher payload via voucher repository', () async {
    final invoiceRepo = FakeInvoiceRepository();
    final voucherRepo = FakeVoucherRepository(
      detailById: {'v-1': sampleVoucherDetail()},
    );

    final payload = await loadFinanceDocumentPayloadForSession(
      invoiceRepository: invoiceRepo,
      voucherRepository: voucherRepo,
      session: _session(),
      kind: DocumentKind.receiptVoucher,
      entityId: 'v-1',
    );

    expect(payload, isA<VoucherPayload>());
    expect((payload as VoucherPayload).document['number'], 'RV-001');
  });
}
