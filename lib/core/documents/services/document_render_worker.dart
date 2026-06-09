import 'package:intl/date_symbol_data_local.dart';

import 'document_render_dto.dart';
import 'document_render_result_dto.dart';
import 'pdf/pdf_document_renderer.dart';

/// Pure isolate entry point — no Riverpod, HTTP, or rootBundle.
Future<DocumentRenderResultDto> documentRenderWorker(
  DocumentRenderDto dto,
) async {
  await initializeDateFormatting('en');
  await initializeDateFormatting('ar');
  final renderer = PdfDocumentRenderer();
  return renderer.renderDto(dto);
}
