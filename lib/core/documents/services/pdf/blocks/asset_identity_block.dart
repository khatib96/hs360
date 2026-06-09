import 'package:pdf/widgets.dart' as pw;

import '../../../domain/document_template.dart';
import '../pdf_bilingual_text.dart';
import '../pdf_font_registry.dart';
import '../pdf_render_context.dart';

class AssetIdentityBlock {
  const AssetIdentityBlock();

  pw.Widget build(
    PdfRenderContext ctx,
    TemplateBlock block, {
    bool includeTenantName = true,
  }) {
    final children = <pw.Widget>[];
    var tenantNameAdded = false;
    var productNameAdded = false;
    for (final field in block.fields) {
      if (field == 'tenant.company_name_ar' ||
          field == 'tenant.company_name_en') {
        if (!includeTenantName || tenantNameAdded) {
          continue;
        }
        tenantNameAdded = true;
        final ar = ctx.resolver.resolve('tenant.company_name_ar');
        final en = ctx.resolver.resolve('tenant.company_name_en');
        if (ar.isNotEmpty || en.isNotEmpty) {
          children.add(
            localizedPdfText(
              languageCode: ctx.languageCode,
              ar: ar,
              en: en,
              style: PdfFontRegistry.textStyle(
                languageCode: ctx.languageCode,
                bold: true,
                fontSize: ctx.layout.baseFontSizePt,
              ),
            ),
          );
        }
        continue;
      }
      if (field == 'product.name_ar' || field == 'product.name_en') {
        if (productNameAdded) {
          continue;
        }
        productNameAdded = true;
        final ar = ctx.resolver.resolve('product.name_ar');
        final en = ctx.resolver.resolve('product.name_en');
        if (ar.isNotEmpty || en.isNotEmpty) {
          children.add(
            localizedPdfText(
              languageCode: ctx.languageCode,
              ar: ar,
              en: en,
              style: PdfFontRegistry.textStyle(
                languageCode: ctx.languageCode,
                fontSize: ctx.layout.baseFontSizePt,
              ),
            ),
          );
        }
        continue;
      }
      final value = ctx.resolver.resolve(field);
      if (value.isEmpty) continue;
      children.add(
        directedPdfText(
          value,
          languageCode: ctx.languageCode,
          style: PdfFontRegistry.textStyle(
            languageCode: ctx.languageCode,
            fontSize: field == 'unit.serial'
                ? ctx.layout.baseFontSizePt + 2
                : ctx.layout.baseFontSizePt,
            bold: field == 'unit.serial',
          ),
        ),
      );
    }
    if (children.isEmpty) return pw.SizedBox.shrink();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    );
  }
}
