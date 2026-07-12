import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/services/document_template_json_parser.dart';
import 'package:hs360/core/documents/services/document_template_validator.dart';

void main() {
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

  Map<String, dynamic> validStatementBody() => {
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
  };

  test('accepts valid customer statement template', () {
    expect(
      () => parser.parse(
        documentType: DocumentKind.customerStatement,
        raw: validStatementBody(),
        paperKind: PaperKind.a4,
      ),
      returnsNormally,
    );
  });

  test('rejects unknown root key before typed parse', () {
    final raw = validStatementBody()..['extra'] = true;
    expect(
      () => parser.validateRaw(
        documentType: DocumentKind.customerStatement,
        raw: raw,
        paperKind: PaperKind.a4,
      ),
      throwsA(
        predicate(
          (e) =>
              e is DocumentTemplateValidationException &&
              e.message.contains('unknown root key'),
        ),
      ),
    );
  });

  test('rejects payment_voucher document type', () {
    expect(
      () => parser.validateRaw(
        documentType: DocumentKind.paymentVoucher,
        raw: validStatementBody(),
        paperKind: PaperKind.a4,
      ),
      throwsA(
        predicate(
          (e) =>
              e is DocumentTemplateValidationException &&
              e.message == 'unsupported_document_type',
        ),
      ),
    );
  });

  test('rejects payment_details on sales invoice', () {
    final raw = validStatementBody();
    (raw['blocks'] as List).insert(1, {
      'type': 'payment_details',
      'id': 'pay',
      'fields': ['payment.amount'],
    });
    expect(
      () => parser.validateRaw(
        documentType: DocumentKind.salesInvoice,
        raw: raw,
        paperKind: PaperKind.a4,
      ),
      throwsA(isA<DocumentTemplateValidationException>()),
    );
  });

  test('rejects line_table on thermal receipt', () {
    final raw = {
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
          'type': 'line_table',
          'id': 'lines',
          'columns': [
            {
              'field': 'line.description',
              'label_key': 'c',
              'label_ar': 'و',
              'label_en': 'D',
              'width_pct': 100,
              'align': 'start',
            },
          ],
        },
        {
          'type': 'payment_details',
          'id': 'pay',
          'fields': ['payment.amount', 'payment.method', 'payment.reference'],
        },
        {'type': 'footer', 'id': 'ftr', 'source': 'tenant_footer'},
      ],
    };
    expect(
      () => parser.validateRaw(
        documentType: DocumentKind.receiptVoucher,
        raw: raw,
        paperKind: PaperKind.thermal80mm,
      ),
      throwsA(
        predicate(
          (e) =>
              e is DocumentTemplateValidationException &&
              e.message.contains('line_table'),
        ),
      ),
    );
  });

  test('rejects notes field other than document.notes', () {
    final raw = validStatementBody();
    (raw['blocks'] as List).insert(5, {
      'type': 'notes',
      'id': 'nts',
      'fields': ['document.number'],
    });
    expect(
      () => parser.validateRaw(
        documentType: DocumentKind.customerStatement,
        raw: raw,
        paperKind: PaperKind.a4,
      ),
      throwsA(
        predicate(
          (e) =>
              e is DocumentTemplateValidationException &&
              e.message.contains('notes field'),
        ),
      ),
    );
  });

  test('rejects label usable width below 18mm', () {
    final raw = {
      'schema_version': 1,
      'settings': {
        'page_margin_mm': {'top': 2, 'right': 2, 'bottom': 2, 'left': 2},
        'base_font_size_pt': 6,
        'line_height': 1.35,
        'show_logo': false,
        'logo_max_height_mm': 5,
        'digit_style': 'western',
        'label_width_mm': 30,
        'label_height_mm': 30,
        'qr_size_mm': 14,
        'label_layout': 'horizontal',
      },
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
    };
    expect(
      () => parser.validateRaw(
        documentType: DocumentKind.assetTagLabel,
        raw: raw,
        paperKind: PaperKind.labelSheet,
      ),
      throwsA(
        predicate(
          (e) =>
              e is DocumentTemplateValidationException &&
              e.message.contains('usable width'),
        ),
      ),
    );
  });

  test('rejects schema_version mismatch with table column', () {
    final raw = validStatementBody()..['schema_version'] = 2;
    expect(
      () => parser.validateRaw(
        documentType: DocumentKind.customerStatement,
        raw: raw,
        paperKind: PaperKind.a4,
        schemaVersion: 1,
      ),
      throwsA(
        predicate(
          (e) =>
              e is DocumentTemplateValidationException &&
              e.message.contains('schema_version'),
        ),
      ),
    );
  });

  test('rejects numeric settings encoded as strings', () {
    final raw = validStatementBody();
    (raw['settings'] as Map<String, dynamic>)['base_font_size_pt'] = '10';
    expect(
      () => parser.parse(
        documentType: DocumentKind.customerStatement,
        paperKind: PaperKind.a4,
        raw: raw,
      ),
      throwsA(isA<DocumentTemplateValidationException>()),
    );
  });

  Map<String, dynamic> validContractBody() => {
    'schema_version': 1,
    'settings': a4Settings(),
    'blocks': [
      {'type': 'tenant_header', 'id': 'hdr'},
      {
        'type': 'document_meta',
        'id': 'meta',
        'fields': [
          'document.number',
          'document.type',
          'document.status',
          'document.printed_at',
        ],
      },
      {
        'type': 'party_details',
        'id': 'party',
        'party_role': 'customer',
        'fields': [
          'party.name_ar',
          'party.name_en',
          'party.contact_person',
          'party.phone',
          'party.email',
          'location.name',
          'location.governorate',
          'location.area',
        ],
      },
      {
        'type': 'contract_terms',
        'id': 'terms',
        'fields': [
          'document.start_date',
          'document.end_date',
          'document.duration_months',
        ],
      },
      {
        'type': 'line_table',
        'id': 'lines',
        'columns': [
          {
            'field': 'line.product_name',
            'label_key': 'col.product',
            'label_ar': 'المنتج',
            'label_en': 'Product',
            'width_pct': 40,
            'align': 'start',
          },
          {
            'field': 'line.serial',
            'label_key': 'col.serial',
            'label_ar': 'التسلسلي',
            'label_en': 'Serial',
            'width_pct': 20,
            'align': 'start',
          },
          {
            'field': 'line.qty',
            'label_key': 'col.qty',
            'label_ar': 'الكمية',
            'label_en': 'Qty',
            'width_pct': 20,
            'align': 'end',
          },
          {
            'field': 'line.unit',
            'label_key': 'col.unit',
            'label_ar': 'الوحدة',
            'label_en': 'Unit',
            'width_pct': 20,
            'align': 'end',
          },
        ],
        'fields': ['line.product_name', 'line.serial', 'line.qty', 'line.unit'],
      },
      {
        'type': 'contract_totals',
        'id': 'totals',
        'fields': [
          'totals.monthly_rental',
          'totals.total_value',
          'totals.is_trial',
        ],
      },
      {'type': 'footer', 'id': 'ftr', 'source': 'tenant_footer'},
    ],
  };

  test('accepts valid contract template with four line columns', () {
    expect(
      () => parser.parse(
        documentType: DocumentKind.contract,
        paperKind: PaperKind.a4,
        raw: validContractBody(),
      ),
      returnsNormally,
    );
  });

  test('rejects contract line_table with forbidden line.group column', () {
    final raw = validContractBody();
    final blocks = raw['blocks'] as List<dynamic>;
    final table =
        blocks.firstWhere((block) => (block as Map)['type'] == 'line_table')
            as Map<String, dynamic>;
    final columns = List<Map<String, dynamic>>.from(
      table['columns'] as List<dynamic>,
    );
    columns[0] = {
      ...columns[0],
      'field': 'line.group',
      'label_key': 'col.group',
      'label_ar': 'مجموعة',
      'label_en': 'Group',
    };
    table['columns'] = columns;
    table['fields'] = ['line.group', 'line.serial', 'line.qty', 'line.unit'];

    expect(
      () => parser.validateRaw(
        documentType: DocumentKind.contract,
        raw: raw,
        paperKind: PaperKind.a4,
      ),
      throwsA(
        predicate(
          (e) =>
              e is DocumentTemplateValidationException &&
              e.message.contains('line.group'),
        ),
      ),
    );
  });

  test('rejects missing or non-string column labels', () {
    final raw = validStatementBody();
    final blocks = raw['blocks'] as List<dynamic>;
    final table =
        blocks.firstWhere((block) => (block as Map)['type'] == 'line_table')
            as Map<String, dynamic>;
    final columns = table['columns'] as List<dynamic>;
    (columns.first as Map<String, dynamic>).remove('label_ar');

    expect(
      () => parser.parse(
        documentType: DocumentKind.customerStatement,
        paperKind: PaperKind.a4,
        raw: raw,
      ),
      throwsA(isA<DocumentTemplateValidationException>()),
    );
  });
}
