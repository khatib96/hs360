import 'dart:isolate';
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../domain/document_kind.dart';
import '../../domain/document_template.dart';
import '../../domain/effective_language.dart';
import '../document_render_dto.dart';
import '../document_render_result_dto.dart';
import '../document_template_validator.dart';
import '../qr_encoder.dart';
import 'blocks/draft_watermark.dart';
import 'label_renderer.dart';
import 'pdf_block_renderer.dart';
import 'pdf_font_registry.dart';
import 'pdf_render_context.dart';
import 'thermal_voucher_renderer.dart';

/// Orchestrates block-based PDF rendering for M3 document types.
class PdfDocumentRenderer {
  PdfDocumentRenderer({
    QrEncoder? qrEncoder,
    DocumentTemplateValidator? validator,
    PdfBlockRenderer? blockRenderer,
    ThermalVoucherRenderer? thermalRenderer,
    LabelRenderer? labelRenderer,
  }) : _validator = validator ?? const DocumentTemplateValidator(),
       _blockRenderer =
           blockRenderer ??
           PdfBlockRenderer(qrEncoder: qrEncoder ?? const BarcodeQrEncoder()),
       _thermalRenderer = thermalRenderer ?? ThermalVoucherRenderer(),
       _labelRenderer =
           labelRenderer ??
           LabelRenderer(qrEncoder: qrEncoder ?? const BarcodeQrEncoder());

  final DocumentTemplateValidator _validator;
  final PdfBlockRenderer _blockRenderer;
  final ThermalVoucherRenderer _thermalRenderer;
  final LabelRenderer _labelRenderer;

  int _tabularMaxPages(int lineCount) {
    final estimated = (lineCount / 22).ceil() + 8;
    return estimated.clamp(20, 400);
  }

  Future<DocumentRenderResultDto> renderDto(DocumentRenderDto dto) async {
    PdfFontRegistry.installFromBundle(dto.fontBundle);
    final logoBytes = dto.logoBytes?.materialize().asUint8List();
    final signatureBytes = dto.signatureBytes?.materialize().asUint8List();

    final ctx = PdfRenderContext.fromDto(
      documentType: dto.documentType,
      paperKind: dto.paperKind,
      languageCode: dto.languageCode,
      templateBodyJson: dto.templateBodyJson,
      tenantSettings: dto.tenantSettings,
      companyNames: dto.companyNames,
      payloadJson: dto.payloadJson,
      currencyJson: dto.currencyJson,
      logoBytes: logoBytes,
      signatureBytes: signatureBytes,
    );

    _validator.validate(
      documentType: ctx.documentType,
      body: ctx.body,
      paperKind: ctx.paperKind,
      schemaVersion: ctx.body.schemaVersion,
    );

    final title = pickLocalized(
      languageCode: dto.languageCode,
      ar: dto.templateNameAr,
      en: dto.templateNameEn,
    );

    final doc = pw.Document(theme: PdfFontRegistry.theme(dto.languageCode));

    double? thermalHeightMm;
    var pageCount = 0;

    if (ctx.paperKind == PaperKind.labelSheet) {
      pageCount = _renderLabel(doc, ctx);
    } else if (ctx.paperKind == PaperKind.thermal80mm) {
      final result = _renderThermal(doc, ctx);
      pageCount = result.pageCount;
      thermalHeightMm = result.thermalHeightMm;
    } else {
      pageCount = _renderTabular(doc, ctx);
    }

    final bytes = await doc.save();
    final layout = ctx.layout;

    return DocumentRenderResultDto(
      pdfBytes: TransferableTypedData.fromList([Uint8List.fromList(bytes)]),
      pageCount: pageCount,
      paperKind: dto.paperKind,
      title: title,
      pageWidthMm: layout.pageWidthMm,
      pageHeightMm: thermalHeightMm ?? layout.pageHeightMm,
      thermalHeightMm: thermalHeightMm,
    );
  }

  _ThermalResult _renderThermal(pw.Document doc, PdfRenderContext ctx) {
    final plan = _thermalRenderer.plan(document: doc, ctx: ctx);
    final pageFormat = ctx.layout.pageFormat(
      thermalHeightMm: plan.measuredHeightMm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: ctx.layout.margins,
        textDirection: ctx.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: _thermalRenderer.buildContent(ctx),
          );
        },
      ),
    );
    return _ThermalResult(pageCount: 1, thermalHeightMm: plan.measuredHeightMm);
  }

  int _renderLabel(pw.Document doc, PdfRenderContext ctx) {
    final pageFormat = ctx.layout.pageFormat();
    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: ctx.layout.margins,
        textDirection: ctx.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (context) => _labelRenderer.build(ctx),
      ),
    );
    return 1;
  }

  int _renderTabular(pw.Document doc, PdfRenderContext ctx) {
    final pageFormat = ctx.layout.pageFormat();
    final lineCount = _lineCount(ctx);
    var pageCount = 1;

    TemplateBlock? headerBlock;
    TemplateBlock? footerBlock;
    for (final block in ctx.body.blocks) {
      if (block.type == 'tenant_header') headerBlock = block;
      if (block.type == 'footer') footerBlock = block;
    }
    final bodyBlocks = ctx.body.blocks
        .where((b) => b.type != 'tenant_header' && b.type != 'footer')
        .toList();
    final isDraft = _isDraftPayload(ctx);

    if (isDraft) {
      doc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: pageFormat,
            margin: ctx.layout.margins,
            textDirection: ctx.rtl
                ? pw.TextDirection.rtl
                : pw.TextDirection.ltr,
            buildBackground: (context) => buildDraftWatermark(ctx),
          ),
          maxPages: _tabularMaxPages(lineCount),
          header: headerBlock != null
              ? (context) => _blockRenderer.renderBlock(ctx, headerBlock!)
              : null,
          footer: footerBlock != null
              ? (context) {
                  pageCount = context.pagesCount;
                  return _blockRenderer.renderBlock(ctx, footerBlock!);
                }
              : (context) {
                  pageCount = context.pagesCount;
                  return pw.SizedBox.shrink();
                },
          build: (context) {
            final widgets = <pw.Widget>[];
            for (final block in bodyBlocks) {
              widgets.add(_blockRenderer.renderBlock(ctx, block));
              widgets.add(pw.SizedBox(height: 8));
            }
            if (widgets.isNotEmpty) widgets.removeLast();
            return widgets;
          },
        ),
      );
      return pageCount;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: ctx.layout.margins,
        maxPages: _tabularMaxPages(lineCount),
        textDirection: ctx.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        pageTheme: null,
        header: headerBlock != null
            ? (context) => _blockRenderer.renderBlock(ctx, headerBlock!)
            : null,
        footer: footerBlock != null
            ? (context) {
                pageCount = context.pagesCount;
                return _blockRenderer.renderBlock(ctx, footerBlock!);
              }
            : (context) {
                pageCount = context.pagesCount;
                return pw.SizedBox.shrink();
              },
        build: (context) {
          final widgets = <pw.Widget>[];
          for (final block in bodyBlocks) {
            widgets.add(_blockRenderer.renderBlock(ctx, block));
            widgets.add(pw.SizedBox(height: 8));
          }
          if (widgets.isNotEmpty) widgets.removeLast();
          return widgets;
        },
      ),
    );
    return pageCount;
  }

  int _lineCount(PdfRenderContext ctx) {
    final lines = ctx.payload['lines'];
    if (lines is List) return lines.length;
    return 0;
  }

  bool _isDraftPayload(PdfRenderContext ctx) {
    final document = ctx.payload['document'];
    if (document is! Map) return false;
    return document['is_draft'] == true;
  }
}

class _ThermalResult {
  const _ThermalResult({
    required this.pageCount,
    required this.thermalHeightMm,
  });

  final int pageCount;
  final double thermalHeightMm;
}
