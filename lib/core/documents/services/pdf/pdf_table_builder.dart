import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/document_kind.dart';
import '../../domain/document_template.dart';
import 'pdf_bilingual_text.dart';
import 'pdf_field_resolver.dart';
import 'pdf_font_registry.dart';
import 'pdf_render_context.dart';

class PdfTableBuilder {
  const PdfTableBuilder();

  pw.Widget buildLineTable({
    required PdfRenderContext ctx,
    required TemplateBlock block,
  }) {
    final lines = ctx.payload['lines'];
    if (lines is! List || lines.isEmpty) {
      return pw.SizedBox.shrink();
    }

    final lineMaps = lines
        .map((l) => Map<String, dynamic>.from(l as Map))
        .toList();
    final columns = ctx.visibleColumns(block);
    final rows = ctx.resolver.resolveLineRows(
      columns.map((column) => column.field).toList(growable: false),
      lineMaps,
    );
    final headerStyle = PdfFontRegistry.textStyle(
      languageCode: ctx.languageCode,
      bold: true,
      fontSize: ctx.layout.baseFontSizePt - 1,
    );
    final cellStyle = PdfFontRegistry.textStyle(
      languageCode: ctx.languageCode,
      fontSize: ctx.layout.baseFontSizePt - 1,
    );

    return pw.TableHelper.fromTextArray(
      headerStyle: headerStyle,
      cellStyle: cellStyle,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      headers: columns.map((column) {
        var ar = column.labelAr;
        var en = column.labelEn;
        if (ctx.documentType == DocumentKind.customerStatement &&
            PdfFieldResolver.statementLineMoneyFields.contains(column.field)) {
          ar = '$ar ${ctx.currency.majorSymbolAr}';
          en = '$en (${ctx.currency.majorSymbolEn})';
        }
        return localizedPdfText(
          languageCode: ctx.languageCode,
          ar: ar,
          en: en,
          style: headerStyle,
          textAlign: pw.TextAlign.center,
        );
      }).toList(),
      data: rows.map((row) {
        return columns.map((column) {
          final value = row[column.field] ?? '';
          if (ctx.languageCode != 'ar' && !containsArabicText(value)) {
            return value;
          }
          return directedPdfText(
            value,
            languageCode: ctx.languageCode,
            style: cellStyle,
          );
        }).toList();
      }).toList(),
    );
  }
}
