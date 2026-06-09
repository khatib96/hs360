import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/services/document_template_json_parser.dart';
import 'package:hs360/core/documents/services/document_template_validator.dart';

void main() {
  const validator = DocumentTemplateValidator();
  const parser = DocumentTemplateJsonParser();

  Map<String, dynamic> a4Settings() => {
    'page_margin_mm': {'top': 12, 'right': 12, 'bottom': 12, 'left': 12},
    'base_font_size_pt': 10,
    'line_height': 1.35,
    'show_logo': true,
    'logo_max_height_mm': 18,
    'table_header_repeat': true,
    'digit_style': 'western',
  };

  TemplateBody validStatementBody() {
    return parser.parse(
      documentType: DocumentKind.customerStatement,
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
                'width_pct': 50,
                'align': 'start',
              },
              {
                'field': 'line.description',
                'label_key': 'col.description',
                'label_ar': 'الوصف',
                'label_en': 'Description',
                'width_pct': 50,
                'align': 'start',
              },
            ],
            'fields': ['line.date', 'line.description'],
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
          {'type': 'footer', 'id': 'ftr', 'source': 'tenant_footer'},
        ],
      },
      paperKind: PaperKind.a4,
    );
  }

  test('accepts valid customer statement template', () {
    expect(
      () => validator.validate(
        documentType: DocumentKind.customerStatement,
        body: validStatementBody(),
      ),
      returnsNormally,
    );
  });

  test('rejects unknown block type', () {
    final body = validStatementBody();
    final bad = TemplateBody(
      schemaVersion: body.schemaVersion,
      settings: body.settings,
      blocks: [
        ...body.blocks,
        const TemplateBlock(type: 'html_embed', id: 'x'),
      ],
    );
    expect(
      () => validator.validate(
        documentType: DocumentKind.customerStatement,
        body: bad,
      ),
      throwsA(isA<DocumentTemplateValidationException>()),
    );
  });

  test('rejects column widths not summing to 100', () {
    final body = validStatementBody();
    final blocks = body.blocks.map((b) {
      if (b.type != 'line_table') return b;
      return TemplateBlock(
        type: b.type,
        id: b.id,
        columns: [
          const TemplateColumn(
            field: 'line.date',
            labelKey: 'col.date',
            labelAr: 'التاريخ',
            labelEn: 'Date',
            widthPct: 40,
            align: 'start',
          ),
          const TemplateColumn(
            field: 'line.description',
            labelKey: 'col.description',
            labelAr: 'الوصف',
            labelEn: 'Description',
            widthPct: 40,
            align: 'start',
          ),
        ],
        fields: const ['line.date', 'line.description'],
      );
    }).toList();
    expect(
      () => validator.validate(
        documentType: DocumentKind.customerStatement,
        body: TemplateBody(
          schemaVersion: 1,
          settings: body.settings,
          blocks: blocks,
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is DocumentTemplateValidationException &&
              e.message.contains('column widths'),
        ),
      ),
    );
  });

  test('thermal receipt requires fewer blocks', () {
    final body = parser.parse(
      documentType: DocumentKind.receiptVoucher,
      raw: {
        'schema_version': 1,
        'settings': {
          'page_margin_mm': {'top': 4, 'right': 4, 'bottom': 4, 'left': 4},
          'base_font_size_pt': 9,
          'line_height': 1.35,
          'show_logo': true,
          'logo_max_height_mm': 12,
          'digit_style': 'western',
          'thermal_content_width_mm': 72,
        },
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
      paperKind: PaperKind.thermal80mm,
    );
    expect(
      () => validator.validate(
        documentType: DocumentKind.receiptVoucher,
        body: body,
        paperKind: PaperKind.thermal80mm,
      ),
      returnsNormally,
    );
  });
}
