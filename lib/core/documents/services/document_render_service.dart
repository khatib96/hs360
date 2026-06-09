import 'dart:isolate';
import 'dart:typed_data';

import '../data/logo_loader.dart';
import '../domain/document_kind.dart';
import '../domain/document_payload.dart';
import '../domain/document_render_result.dart';
import '../domain/document_template.dart';
import 'document_render_dto.dart';
import 'document_render_worker.dart';
import 'pdf/pdf_font_registry.dart';

/// Root-isolate entry point for document PDF rendering (M3).
class DocumentRenderService {
  DocumentRenderService({LogoLoader? logoLoader}) : _logoLoader = logoLoader;

  final LogoLoader? _logoLoader;

  Future<DocumentRenderResult> render({
    required EffectiveDocumentContext context,
    required DocumentPayload payload,
    required String userLocale,
    String? previewLanguageOverride,
  }) async {
    if (context.template.documentType == DocumentKind.paymentVoucher ||
        payload.kind == DocumentKind.paymentVoucher) {
      throw const DocumentRenderException(
        DocumentRenderException.unsupportedKind,
      );
    }

    await PdfFontRegistry.ensureLoaded();
    final fontBundle = await PdfFontRegistry.exportForIsolate();

    Uint8List? logoBytes;
    if (context.resolvedLogoUrl != null && _logoLoader != null) {
      try {
        logoBytes = await _logoLoader.loadValidated(context.resolvedLogoUrl);
      } on LogoLoadException {
        logoBytes = null;
      }
    }

    final dto = buildDocumentRenderDto(
      context: context,
      payload: payload,
      userLocale: userLocale,
      previewLanguageOverride: previewLanguageOverride,
      fontBundle: fontBundle,
      logoBytes: logoBytes,
    );

    final resultDto = await Isolate.run(() => documentRenderWorker(dto));

    final bytes = resultDto.materializePdfBytes();
    final paperKind = PaperKind.fromValue(resultDto.paperKind);

    return DocumentRenderResult(
      bytes: bytes,
      pageCount: resultDto.pageCount,
      paperKind: paperKind ?? context.template.paperKind,
      title: resultDto.title,
    );
  }
}
