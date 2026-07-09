import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/documents/domain/document_kind.dart';
import '../../../core/documents/domain/document_payload.dart';
import '../../../core/errors/document_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../invoices/data/invoice_repository.dart';
import '../../invoices/domain/invoice_document_payload_mapper.dart';
import '../../invoices/domain/invoice_type.dart';
import '../../vouchers/data/voucher_repository.dart';
import '../../vouchers/domain/voucher_document_payload_mapper.dart';

/// Single bridge from document preview to invoice/voucher detail repositories.
Future<DocumentPayload> loadFinanceDocumentPayload({
  required Ref ref,
  required DocumentKind kind,
  required String entityId,
  InvoiceType? invoiceType,
}) {
  final session = ref.read(authControllerProvider).valueOrNull;
  if (session == null) {
    throw const DocumentException(code: DocumentException.permissionDenied);
  }
  return loadFinanceDocumentPayloadForSession(
    invoiceRepository: ref.read(invoiceRepositoryProvider),
    voucherRepository: ref.read(voucherRepositoryProvider),
    session: session,
    kind: kind,
    entityId: entityId,
    invoiceType: invoiceType,
  );
}

Future<DocumentPayload> loadFinanceDocumentPayloadForSession({
  required InvoiceRepository invoiceRepository,
  required VoucherRepository voucherRepository,
  required AppSession session,
  required DocumentKind kind,
  required String entityId,
  InvoiceType? invoiceType,
}) {
  return switch (kind) {
    DocumentKind.salesInvoice || DocumentKind.purchaseInvoice => () async {
      final type = invoiceType;
      if (type == null || !_invoiceTypeMatchesKind(kind, type)) {
        throw const DocumentException(
          code: DocumentException.unsupportedDocumentType,
        );
      }
      final detail = await invoiceRepository.fetchInvoiceDetail(
        entityId,
        session,
        type: type,
      );
      return mapInvoiceDetailToPayload(detail);
    }(),
    DocumentKind.receiptVoucher => () async {
      final detail = await voucherRepository.getVoucherDetail(
        session,
        entityId,
      );
      return mapVoucherDetailToPayload(detail);
    }(),
    _ => throw const DocumentException(
      code: DocumentException.unsupportedDocumentType,
    ),
  };
}

bool _invoiceTypeMatchesKind(DocumentKind kind, InvoiceType type) {
  return switch (kind) {
    DocumentKind.salesInvoice => type.isSalesDirection,
    DocumentKind.purchaseInvoice => type.isPurchaseDirection,
    _ => false,
  };
}
