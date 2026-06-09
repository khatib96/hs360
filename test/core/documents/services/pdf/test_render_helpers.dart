import 'package:decimal/decimal.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_payload.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/services/document_render_dto.dart';
import 'package:hs360/core/documents/services/document_template_json_parser.dart';
import 'package:hs360/core/documents/services/pdf/pdf_font_registry.dart';
import 'package:hs360/core/documents/services/pdf/pdf_render_context.dart';

const testParser = DocumentTemplateJsonParser();

Map<String, dynamic> a4Settings() => {
  'page_margin_mm': {'top': 12, 'right': 12, 'bottom': 12, 'left': 12},
  'base_font_size_pt': 10,
  'line_height': 1.35,
  'show_logo': true,
  'logo_max_height_mm': 18,
  'table_header_repeat': true,
  'digit_style': 'western',
};

Map<String, dynamic> thermalSettings() => {
  'page_margin_mm': {'top': 4, 'right': 4, 'bottom': 4, 'left': 4},
  'base_font_size_pt': 9,
  'line_height': 1.35,
  'show_logo': true,
  'logo_max_height_mm': 12,
  'digit_style': 'western',
  'thermal_content_width_mm': 72,
};

Map<String, dynamic> labelSettings({
  double width = 50,
  double height = 30,
  double qrSize = 14,
}) => {
  'page_margin_mm': {'top': 2, 'right': 2, 'bottom': 2, 'left': 2},
  'base_font_size_pt': 6,
  'line_height': 1.35,
  'show_logo': true,
  'logo_max_height_mm': 5,
  'digit_style': 'western',
  'label_width_mm': width,
  'label_height_mm': height,
  'qr_size_mm': qrSize,
  'label_layout': 'horizontal',
};

EffectiveDocumentContext testContext({
  required DocumentKind kind,
  PaperKind? paper,
  TemplateBody? bodyOverride,
}) {
  final resolvedPaper = paper ?? _defaultPaper(kind);
  final body = bodyOverride ?? _defaultBody(kind: kind, paper: resolvedPaper);
  return EffectiveDocumentContext(
    template: DocumentTemplate(
      id: 'tpl-1',
      templateKey: '${kind.documentType}_${resolvedPaper.value}',
      documentType: kind,
      languageMode: DocumentLanguageMode.bilingual,
      paperKind: resolvedPaper,
      schemaVersion: 1,
      body: body,
      nameAr: 'اختبار',
      nameEn: 'Test',
    ),
    settings: const {'default_language': 'bilingual', 'footer_json': {}},
    currency: {
      'code': 'KWD',
      'symbol': 'KWD',
      'major_symbol_ar': 'د.ك',
      'major_symbol_en': 'KWD',
      'decimal_places': 3,
      'symbol_position': 'after',
      'thousand_separator': ',',
      'decimal_separator': '.',
    },
    resolvedLogoUrl: null,
    companyNames: const {'ar': 'شركة تجريبية', 'en': 'Sample Co'},
  );
}

PaperKind _defaultPaper(DocumentKind kind) {
  return switch (kind) {
    DocumentKind.assetTagLabel => PaperKind.labelSheet,
    _ => PaperKind.a4,
  };
}

TemplateBody _defaultBody({
  required DocumentKind kind,
  required PaperKind paper,
}) {
  if (kind == DocumentKind.assetTagLabel) {
    return testParser.parse(
      documentType: kind,
      paperKind: PaperKind.labelSheet,
      raw: {
        'schema_version': 1,
        'settings': labelSettings(),
        'blocks': [
          {'type': 'tenant_header', 'id': 'hdr'},
          {
            'type': 'asset_identity',
            'id': 'idn',
            'fields': [
              'tenant.company_name_ar',
              'product.name_ar',
              'product.name_en',
              'unit.serial',
            ],
          },
          {
            'type': 'qr_code',
            'id': 'qr',
            'payload_field': 'unit.serial',
            'caption_field': 'unit.serial',
          },
        ],
      },
    );
  }
  if (kind == DocumentKind.receiptVoucher && paper == PaperKind.thermal80mm) {
    return testParser.parse(
      documentType: kind,
      paperKind: paper,
      raw: {
        'schema_version': 1,
        'settings': thermalSettings(),
        'blocks': [
          {'type': 'tenant_header', 'id': 'hdr'},
          {
            'type': 'document_meta',
            'id': 'meta',
            'fields': ['document.number', 'document.date'],
          },
          {
            'type': 'payment_details',
            'id': 'pay',
            'fields': ['payment.amount', 'payment.method', 'payment.reference'],
          },
          {'type': 'footer', 'id': 'ftr', 'source': 'tenant_footer'},
        ],
      },
    );
  }
  if (kind == DocumentKind.customerStatement) {
    return testParser.parse(
      documentType: kind,
      paperKind: paper,
      raw: {
        'schema_version': 1,
        'settings': a4Settings(),
        'blocks': [
          {'type': 'tenant_header', 'id': 'hdr'},
          {
            'type': 'document_meta',
            'id': 'meta',
            'fields': [
              'document.from_date',
              'document.to_date',
              'document.generated_at',
            ],
          },
          {
            'type': 'party_details',
            'id': 'party',
            'party_role': 'customer',
            'fields': ['party.name_ar', 'party.name_en', 'party.code'],
          },
          {
            'type': 'line_table',
            'id': 'lines',
            'columns': [
              {
                'field': 'line.date',
                'label_key': 'col.date',
                'label_ar': 'التاريخ',
                'label_en': 'Date',
                'width_pct': 20,
                'align': 'start',
              },
              {
                'field': 'line.description',
                'label_key': 'col.description',
                'label_ar': 'الوصف',
                'label_en': 'Description',
                'width_pct': 20,
                'align': 'start',
              },
              {
                'field': 'line.debit',
                'label_key': 'col.debit',
                'label_ar': 'مدين',
                'label_en': 'Debit',
                'width_pct': 20,
                'align': 'end',
              },
              {
                'field': 'line.credit',
                'label_key': 'col.credit',
                'label_ar': 'دائن',
                'label_en': 'Credit',
                'width_pct': 20,
                'align': 'end',
              },
              {
                'field': 'line.balance',
                'label_key': 'col.balance',
                'label_ar': 'الرصيد',
                'label_en': 'Balance',
                'width_pct': 20,
                'align': 'end',
              },
            ],
            'fields': [
              'line.date',
              'line.description',
              'line.debit',
              'line.credit',
              'line.balance',
            ],
          },
          {
            'type': 'totals',
            'id': 'totals',
            'fields': [
              'summary.opening_balance',
              'summary.total_debit',
              'summary.total_credit',
              'summary.closing_balance',
            ],
          },
          {
            'type': 'notes',
            'id': 'notes',
            'fields': ['document.notes'],
          },
          {'type': 'footer', 'id': 'ftr', 'source': 'tenant_footer'},
        ],
      },
    );
  }
  final partyRole = kind == DocumentKind.purchaseInvoice
      ? 'supplier'
      : 'customer';
  return testParser.parse(
    documentType: kind,
    paperKind: paper,
    raw: {
      'schema_version': 1,
      'settings': a4Settings(),
      'blocks': [
        {'type': 'tenant_header', 'id': 'hdr'},
        {
          'type': 'document_meta',
          'id': 'meta',
          'fields': ['document.number', 'document.date', 'document.due_date'],
        },
        {
          'type': 'party_details',
          'id': 'party',
          'party_role': partyRole,
          'fields': ['party.name_ar', 'party.name_en', 'party.code'],
        },
        {
          'type': 'line_table',
          'id': 'lines',
          'columns': [
            {
              'field': 'line.description',
              'label_key': 'col.description',
              'label_ar': 'الوصف',
              'label_en': 'Description',
              'width_pct': 40,
              'align': 'start',
            },
            {
              'field': 'line.qty',
              'label_key': 'col.qty',
              'label_ar': 'الكمية',
              'label_en': 'Qty',
              'width_pct': 15,
              'align': 'end',
            },
            {
              'field': 'line.unit_price',
              'label_key': 'col.unit_price',
              'label_ar': 'السعر',
              'label_en': 'Price',
              'width_pct': 20,
              'align': 'end',
            },
            {
              'field': 'line.total',
              'label_key': 'col.total',
              'label_ar': 'الإجمالي',
              'label_en': 'Total',
              'width_pct': 25,
              'align': 'end',
            },
          ],
          'fields': [
            'line.description',
            'line.qty',
            'line.unit_price',
            'line.total',
          ],
        },
        {
          'type': 'totals',
          'id': 'totals',
          'fields': [
            'totals.subtotal',
            'totals.discount',
            'totals.tax',
            'totals.total',
          ],
        },
        {'type': 'footer', 'id': 'ftr', 'source': 'tenant_footer'},
      ],
    },
  );
}

StatementPayload arabicStatementPayload({String? notes}) {
  return StatementPayload(
    customer: const {
      'id': 'c1',
      'code': 'C-001',
      'name_ar': 'عميل عربي',
      'name_en': 'Arabic Customer',
    },
    fromDate: DateTime(2026, 1, 1),
    toDate: DateTime(2026, 6, 1),
    generatedAt: DateTime(2026, 6, 1),
    summary: StatementSummary(
      openingBalance: Decimal.parse('100.000'),
      totalDebit: Decimal.parse('50.000'),
      totalCredit: Decimal.parse('20.000'),
      closingBalance: Decimal.parse('130.000'),
    ),
    lines: [
      StatementLine(
        entryDate: DateTime(2026, 2, 1),
        entryNumber: 'JE-001',
        source: 'sales_invoice',
        description: 'فاتورة مبيعات',
        debit: Decimal.parse('50.000'),
        credit: Decimal.zero,
        runningBalance: Decimal.parse('150.000'),
      ),
    ],
    rowCount: 1,
    notes: notes,
  );
}

Future<DocumentRenderDto> buildTestDto({
  required EffectiveDocumentContext context,
  required DocumentPayload payload,
  String userLocale = 'en',
}) async {
  await PdfFontRegistry.ensureLoaded();
  final fontBundle = await PdfFontRegistry.exportForIsolate();
  return buildDocumentRenderDto(
    context: context,
    payload: payload,
    userLocale: userLocale,
    fontBundle: fontBundle,
  );
}

PdfRenderContext buildPdfContext({
  required EffectiveDocumentContext context,
  Map<String, dynamic>? payloadJson,
  String languageCode = 'en',
  TemplateBody? bodyOverride,
}) {
  final body = bodyOverride ?? context.template.body;
  return PdfRenderContext.fromDto(
    documentType: context.template.documentType.documentType,
    paperKind: context.template.paperKind.value,
    languageCode: languageCode,
    templateBodyJson: {
      'schema_version': body.schemaVersion,
      'settings': body.settings,
      'blocks': body.blocks
          .map(
            (b) => {
              'type': b.type,
              if (b.id != null) 'id': b.id,
              if (b.fields.isNotEmpty) 'fields': b.fields,
              if (b.columns.isNotEmpty)
                'columns': b.columns
                    .map(
                      (c) => {
                        'field': c.field,
                        'label_key': c.labelKey,
                        'label_ar': c.labelAr,
                        'label_en': c.labelEn,
                        'width_pct': c.widthPct,
                        'align': c.align,
                      },
                    )
                    .toList(),
              if (b.partyRole != null) 'party_role': b.partyRole,
              if (b.source != null) 'source': b.source,
              if (b.payloadField != null) 'payload_field': b.payloadField,
              if (b.captionField != null) 'caption_field': b.captionField,
              if (b.heightMm != null) 'height_mm': b.heightMm,
            },
          )
          .toList(),
    },
    tenantSettings: context.settings,
    companyNames: context.companyNames,
    payloadJson: payloadJson ?? const {},
    currencyJson: context.currency,
  );
}
