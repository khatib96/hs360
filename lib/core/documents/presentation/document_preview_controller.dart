import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization/locale_controller.dart';
import '../../errors/document_exception.dart';
import '../data/document_template_repository.dart';
import '../../../features/finance_shared/documents/finance_document_payload_loader.dart';
import '../domain/document_kind.dart';
import '../domain/document_permissions.dart';
import '../domain/document_render_result.dart';
import '../data/document_providers.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import 'document_preview_state.dart';

part 'document_preview_controller.g.dart';

@riverpod
class DocumentPreviewController extends _$DocumentPreviewController {
  @override
  DocumentPreviewState build(DocumentPreviewArgs args) {
    Future.microtask(load);
    return const DocumentPreviewState(isLoading: true);
  }

  Future<void> load({bool force = false}) async {
    if (!force && state.renderResult != null) return;

    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      state = const DocumentPreviewState(
        isLoading: false,
        permissionDenied: true,
      );
      return;
    }

    if (!canPreviewDocument(session, args.kind)) {
      state = const DocumentPreviewState(
        isLoading: false,
        permissionDenied: true,
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(documentTemplateRepositoryProvider);
      final renderService = ref.read(documentRenderServiceProvider);
      final locale = ref.read(localeProvider).languageCode;

      final context = await repo.fetchEffectiveTemplate(
        documentType: args.kind,
      );

      final payload = args.fixturePayload ?? await _fetchPayload(repo, args);

      final result = await renderService.render(
        context: context,
        payload: payload,
        userLocale: locale,
      );

      state = DocumentPreviewState(
        isLoading: false,
        renderResult: result,
        canExport: canExportDocument(session, args.kind),
      );
    } on DocumentRenderException catch (e) {
      state = state.copyWith(isLoading: false, errorCode: e.code);
    } on DocumentException catch (e) {
      state = state.copyWith(isLoading: false, errorCode: e.code);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorCode: DocumentException.unknown,
      );
    }
  }

  Future<dynamic> _fetchPayload(
    DocumentTemplateRepository repo,
    DocumentPreviewArgs args,
  ) {
    return switch (args.kind) {
      DocumentKind.customerStatement => repo.fetchCustomerStatementPayload(
        customerId: args.entityId,
        from: args.fromDate ?? _defaultFrom(),
        to: args.toDate ?? DateTime.now(),
      ),
      DocumentKind.assetTagLabel => repo.fetchProductUnitLabelPayload(
        unitId: args.entityId,
      ),
      DocumentKind.salesInvoice ||
      DocumentKind.purchaseInvoice ||
      DocumentKind.receiptVoucher => loadFinanceDocumentPayload(
        ref: ref,
        kind: args.kind,
        entityId: args.entityId,
        invoiceType: args.invoiceType,
      ),
      _ => throw DocumentException(
        code: DocumentException.unsupportedDocumentType,
      ),
    };
  }

  DateTime _defaultFrom() {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 364));
  }
}
