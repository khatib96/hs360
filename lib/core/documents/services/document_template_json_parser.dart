import '../domain/document_kind.dart';
import '../domain/document_template.dart';
import 'document_template_validator.dart';

/// Validates raw template JSON before typed parsing — mirrors SQL
/// [validate_document_template_body].
class DocumentTemplateJsonParser {
  const DocumentTemplateJsonParser();

  static const rootKeys = {'schema_version', 'settings', 'blocks'};

  static const singletonBlockTypes = {
    'tenant_header',
    'document_meta',
    'party_details',
    'line_table',
    'totals',
    'payment_details',
    'notes',
    'footer',
    'asset_identity',
    'qr_code',
  };

  static const blockAllowedKeys = {
    'spacer': {'type', 'id', 'height_mm'},
    'divider': {'type', 'id'},
    'tenant_header': {'type', 'id'},
    'document_meta': {'type', 'id', 'fields'},
    'party_details': {'type', 'id', 'party_role', 'fields'},
    'line_table': {'type', 'id', 'columns', 'fields'},
    'totals': {'type', 'id', 'fields'},
    'payment_details': {'type', 'id', 'fields'},
    'notes': {'type', 'id', 'fields'},
    'footer': {'type', 'id', 'source'},
    'asset_identity': {'type', 'id', 'fields'},
    'qr_code': {'type', 'id', 'payload_field', 'caption_field'},
  };

  static const columnKeys = {
    'field',
    'label_key',
    'label_ar',
    'label_en',
    'width_pct',
    'align',
  };

  static const labelTextGapMm = 1.0;

  /// Validates [raw] then returns a typed [TemplateBody].
  TemplateBody parse({
    required DocumentKind documentType,
    required Map<String, dynamic> raw,
    required PaperKind paperKind,
    int schemaVersion = 1,
  }) {
    validateRaw(
      documentType: documentType,
      raw: raw,
      paperKind: paperKind,
      schemaVersion: schemaVersion,
    );
    return TemplateBody.fromJson(raw);
  }

  void validateRaw({
    required DocumentKind documentType,
    required Map<String, dynamic> raw,
    required PaperKind paperKind,
    int schemaVersion = 1,
  }) {
    if (documentType == DocumentKind.paymentVoucher) {
      throw const DocumentTemplateValidationException(
        'unsupported_document_type',
      );
    }

    for (final key in raw.keys) {
      if (!rootKeys.contains(key)) {
        throw DocumentTemplateValidationException(
          'invalid_document_template: unknown root key $key',
        );
      }
    }

    final bodySchemaVersion = raw['schema_version'];
    if (bodySchemaVersion is! int || bodySchemaVersion != 1) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: schema_version must be 1',
      );
    }
    if (bodySchemaVersion != schemaVersion) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: schema_version mismatch',
      );
    }

    final settings = raw['settings'];
    if (settings is! Map) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: settings must be object',
      );
    }
    _validateSettings(Map<String, dynamic>.from(settings), paperKind);

    final blocks = raw['blocks'];
    if (blocks is! List) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: blocks must be array',
      );
    }
    if (blocks.isEmpty || blocks.length > 40) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: blocks length out of range',
      );
    }

    final allowedTypes = _allowedBlockTypes(documentType, paperKind);
    if (allowedTypes.isEmpty) {
      throw const DocumentTemplateValidationException(
        'unsupported_document_type',
      );
    }

    final seenTypes = <String>[];
    final seenIds = <String>{};

    for (final blockRaw in blocks) {
      if (blockRaw is! Map) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: block must be object',
        );
      }
      final block = Map<String, dynamic>.from(blockRaw);
      final type = block['type'];
      if (type is! String) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: block missing type',
        );
      }

      if (!allowedTypes.contains(type)) {
        throw DocumentTemplateValidationException(
          'invalid_document_template: block type $type not allowed',
        );
      }
      seenTypes.add(type);

      final allowedKeys = blockAllowedKeys[type];
      if (allowedKeys == null) {
        throw DocumentTemplateValidationException(
          'invalid_document_template: unknown block type $type',
        );
      }
      for (final key in block.keys) {
        if (!allowedKeys.contains(key)) {
          throw DocumentTemplateValidationException(
            'invalid_document_template: unknown key $key in block $type',
          );
        }
      }

      final id = block['id'];
      if (id is! String || !_isValidBlockId(id)) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: invalid block id',
        );
      }
      if (seenIds.contains(id)) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: duplicate block id',
        );
      }
      seenIds.add(id);

      if (type == 'spacer') {
        _validateSpacer(block);
      }
      if (type == 'party_details') {
        _validatePartyRole(documentType, paperKind, block);
      }
      if (type == 'footer') {
        if (block['source'] != 'tenant_footer') {
          throw const DocumentTemplateValidationException(
            'invalid_document_template: footer source must be tenant_footer',
          );
        }
      }
      if (type == 'qr_code') {
        _validateQrCode(block);
      }
      if (type == 'line_table') {
        _validateLineTable(block);
      }

      final allowlist = _blockFieldAllowlist(documentType, paperKind, type);
      if (type == 'document_meta' ||
          type == 'party_details' ||
          type == 'totals' ||
          type == 'payment_details' ||
          type == 'asset_identity') {
        _validateRequiredFields(block, type, allowlist);
      } else if (type == 'notes' && block.containsKey('fields')) {
        _validateNotesFields(block);
      }
    }

    for (final singleton in singletonBlockTypes) {
      if (seenTypes.where((t) => t == singleton).length > 1) {
        throw DocumentTemplateValidationException(
          'invalid_document_template: duplicate singleton block $singleton',
        );
      }
    }

    final required = _requiredBlocks(documentType, paperKind);
    for (final requiredType in required) {
      if (!seenTypes.contains(requiredType)) {
        throw DocumentTemplateValidationException(
          'invalid_document_template: missing required block $requiredType',
        );
      }
    }
  }

  void _validateSettings(Map<String, dynamic> settings, PaperKind paperKind) {
    final allowed = switch (paperKind) {
      PaperKind.a4 => {
        'page_margin_mm',
        'base_font_size_pt',
        'line_height',
        'show_logo',
        'logo_max_height_mm',
        'table_header_repeat',
        'digit_style',
      },
      PaperKind.thermal80mm => {
        'page_margin_mm',
        'base_font_size_pt',
        'line_height',
        'show_logo',
        'logo_max_height_mm',
        'digit_style',
        'thermal_content_width_mm',
      },
      PaperKind.labelSheet => {
        'page_margin_mm',
        'base_font_size_pt',
        'line_height',
        'show_logo',
        'logo_max_height_mm',
        'digit_style',
        'label_width_mm',
        'label_height_mm',
        'qr_size_mm',
        'label_layout',
      },
    };

    for (final key in settings.keys) {
      if (!allowed.contains(key)) {
        throw DocumentTemplateValidationException(
          'invalid_document_template: unknown settings key $key',
        );
      }
    }

    const baseRequired = {
      'page_margin_mm',
      'base_font_size_pt',
      'line_height',
      'show_logo',
      'logo_max_height_mm',
      'digit_style',
    };
    for (final key in baseRequired) {
      if (!settings.containsKey(key)) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: missing required settings keys',
        );
      }
    }

    if (paperKind == PaperKind.a4 &&
        !settings.containsKey('table_header_repeat')) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: missing table_header_repeat',
      );
    }
    if (paperKind == PaperKind.thermal80mm &&
        !settings.containsKey('thermal_content_width_mm')) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: missing thermal_content_width_mm',
      );
    }
    if (paperKind == PaperKind.labelSheet) {
      for (final key in [
        'label_width_mm',
        'label_height_mm',
        'qr_size_mm',
        'label_layout',
      ]) {
        if (!settings.containsKey(key)) {
          throw const DocumentTemplateValidationException(
            'invalid_document_template: missing label settings keys',
          );
        }
      }
    }

    final margin = settings['page_margin_mm'];
    if (margin is! Map) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: page_margin_mm must be object',
      );
    }
    final marginMap = Map<String, dynamic>.from(margin);
    for (final key in marginMap.keys) {
      if (!{'top', 'right', 'bottom', 'left'}.contains(key)) {
        throw DocumentTemplateValidationException(
          'invalid_document_template: unknown margin key $key',
        );
      }
    }
    for (final side in ['top', 'right', 'bottom', 'left']) {
      if (!marginMap.containsKey(side)) {
        throw DocumentTemplateValidationException(
          'invalid_document_template: missing margin $side',
        );
      }
      final val = _asNum(marginMap[side]);
      if (val == null || val < 0 || val > 40) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: margin out of range',
        );
      }
    }

    final fontSize = _asNum(settings['base_font_size_pt']);
    if (fontSize == null || fontSize < 6 || fontSize > 24) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: base_font_size_pt out of range',
      );
    }

    final lineHeight = _asNum(settings['line_height']);
    if (lineHeight == null || lineHeight < 1.0 || lineHeight > 2.5) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: line_height out of range',
      );
    }

    if (settings['show_logo'] is! bool) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: show_logo must be boolean',
      );
    }
    final showLogo = settings['show_logo'] as bool;

    final logoMax = _asNum(settings['logo_max_height_mm']);
    if (logoMax == null || logoMax < 0 || logoMax > 40) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: logo_max_height_mm out of range',
      );
    }

    if (settings['digit_style'] != 'western') {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: digit_style must be western',
      );
    }

    if (paperKind == PaperKind.a4 && settings['table_header_repeat'] is! bool) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: table_header_repeat must be boolean',
      );
    }

    final left = _asNum(marginMap['left'])!;
    final right = _asNum(marginMap['right'])!;
    final top = _asNum(marginMap['top'])!;
    final bottom = _asNum(marginMap['bottom'])!;

    if (paperKind == PaperKind.thermal80mm) {
      final thermalWidth = _asNum(settings['thermal_content_width_mm']);
      if (thermalWidth == null || thermalWidth < 40 || thermalWidth > 72) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: thermal_content_width_mm out of range',
        );
      }
      if (left + thermalWidth + right > 80) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: thermal geometry exceeds 80mm',
        );
      }
    }

    if (paperKind == PaperKind.labelSheet) {
      final labelWidth = _asNum(settings['label_width_mm']);
      final labelHeight = _asNum(settings['label_height_mm']);
      final qrSize = _asNum(settings['qr_size_mm']);
      if (labelWidth == null || labelWidth < 20 || labelWidth > 100) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: label_width_mm out of range',
        );
      }
      if (labelHeight == null || labelHeight < 10 || labelHeight > 80) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: label_height_mm out of range',
        );
      }
      if (qrSize == null || qrSize < 8 || qrSize > 40) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: qr_size_mm out of range',
        );
      }
      if (settings['label_layout'] != 'horizontal') {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: label_layout must be horizontal',
        );
      }
      if (left + qrSize + right > labelWidth) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: label horizontal geometry invalid',
        );
      }
      if (top + qrSize + bottom > labelHeight) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: label vertical geometry invalid',
        );
      }
      if (showLogo && top + logoMax + bottom > labelHeight) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: label logo geometry invalid',
        );
      }
      final usableWidth = labelWidth - left - right - qrSize - labelTextGapMm;
      final usableHeight = labelHeight - top - bottom;
      if (usableWidth < 18) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: label usable width too small',
        );
      }
      if (usableHeight < 10) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: label usable height too small',
        );
      }
    }
  }

  void _validateSpacer(Map<String, dynamic> block) {
    if (!block.containsKey('height_mm')) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: spacer missing height_mm',
      );
    }
    final height = _asNum(block['height_mm']);
    if (height == null || height < 1 || height > 200) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: spacer height_mm out of range',
      );
    }
  }

  void _validatePartyRole(
    DocumentKind documentType,
    PaperKind paperKind,
    Map<String, dynamic> block,
  ) {
    final required = _requiredPartyRole(documentType, paperKind);
    if (required == null || block['party_role'] != required) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: invalid party_role',
      );
    }
  }

  void _validateQrCode(Map<String, dynamic> block) {
    if (block['payload_field'] != 'unit.serial') {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: invalid qr_code payload_field',
      );
    }
    if (block.containsKey('caption_field') &&
        block['caption_field'] != null &&
        block['caption_field'] != 'unit.serial') {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: invalid qr_code caption_field',
      );
    }
  }

  void _validateLineTable(Map<String, dynamic> block) {
    final columns = block['columns'];
    if (columns is! List) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: line_table missing columns',
      );
    }
    if (columns.isEmpty || columns.length > 20) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: columns length out of range',
      );
    }

    var widthSum = 0;
    final colFields = <String>[];

    for (final colRaw in columns) {
      if (colRaw is! Map) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: column must be object',
        );
      }
      final col = Map<String, dynamic>.from(colRaw);
      for (final key in col.keys) {
        if (!columnKeys.contains(key)) {
          throw DocumentTemplateValidationException(
            'invalid_document_template: unknown column key $key',
          );
        }
      }

      final field = col['field'];
      if (field is! String || field.isEmpty) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: column missing field',
        );
      }
      if (colFields.contains(field)) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: duplicate column field',
        );
      }
      colFields.add(field);

      final widthPct = col['width_pct'];
      if (widthPct is! int || widthPct < 1 || widthPct > 100) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: width_pct out of range',
        );
      }
      widthSum += widthPct;

      final align = col['align'];
      if (align is! String || !{'start', 'center', 'end'}.contains(align)) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: invalid column align',
        );
      }

      final labelKey = col['label_key'];
      final labelAr = col['label_ar'];
      final labelEn = col['label_en'];
      if (labelKey is! String ||
          labelKey.isEmpty ||
          labelAr is! String ||
          labelEn is! String ||
          labelAr.length > 128 ||
          labelEn.length > 128) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: invalid column labels',
        );
      }
    }

    if (widthSum != 100) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: column widths must sum to 100',
      );
    }

    if (block.containsKey('fields')) {
      final fields = block['fields'];
      if (fields is! List) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: line_table fields must be array',
        );
      }
      if (fields.length != colFields.length) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: line_table fields must match columns',
        );
      }
      for (final field in fields) {
        if (field is! String || !colFields.contains(field)) {
          throw const DocumentTemplateValidationException(
            'invalid_document_template: line_table field not in columns',
          );
        }
      }
    }
  }

  void _validateRequiredFields(
    Map<String, dynamic> block,
    String type,
    List<String>? allowlist,
  ) {
    final fields = block['fields'];
    if (fields is! List) {
      throw DocumentTemplateValidationException(
        'invalid_document_template: block $type missing fields',
      );
    }
    if (fields.isEmpty || fields.length > 32) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: fields length out of range',
      );
    }
    final seen = <String>{};
    for (final field in fields) {
      if (field is! String) {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: fields length out of range',
        );
      }
      if (seen.contains(field)) {
        throw DocumentTemplateValidationException(
          'invalid_document_template: duplicate field $field',
        );
      }
      seen.add(field);
      if (allowlist == null || !allowlist.contains(field)) {
        throw DocumentTemplateValidationException(
          'invalid_document_template: field $field not allowed in $type',
        );
      }
    }
  }

  void _validateNotesFields(Map<String, dynamic> block) {
    final fields = block['fields'];
    if (fields is! List) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: notes fields must be array',
      );
    }
    if (fields.isEmpty || fields.length > 32) {
      throw const DocumentTemplateValidationException(
        'invalid_document_template: fields length out of range',
      );
    }
    for (final field in fields) {
      if (field != 'document.notes') {
        throw const DocumentTemplateValidationException(
          'invalid_document_template: notes field must be document.notes',
        );
      }
    }
  }

  static bool _isValidBlockId(String id) {
    return RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id);
  }

  static num? _asNum(dynamic value) {
    if (value is num) return value;
    return null;
  }

  static List<String> _allowedBlockTypes(
    DocumentKind documentType,
    PaperKind paperKind,
  ) {
    return switch (documentType) {
      DocumentKind.salesInvoice ||
      DocumentKind.purchaseInvoice when paperKind == PaperKind.a4 => [
        'tenant_header',
        'document_meta',
        'party_details',
        'line_table',
        'totals',
        'notes',
        'footer',
        'spacer',
        'divider',
      ],
      DocumentKind.receiptVoucher when paperKind == PaperKind.a4 => [
        'tenant_header',
        'document_meta',
        'party_details',
        'payment_details',
        'notes',
        'footer',
        'spacer',
        'divider',
      ],
      DocumentKind.receiptVoucher when paperKind == PaperKind.thermal80mm => [
        'tenant_header',
        'document_meta',
        'payment_details',
        'notes',
        'footer',
        'spacer',
        'divider',
      ],
      DocumentKind.customerStatement when paperKind == PaperKind.a4 => [
        'tenant_header',
        'document_meta',
        'party_details',
        'line_table',
        'totals',
        'notes',
        'footer',
        'spacer',
        'divider',
      ],
      DocumentKind.assetTagLabel when paperKind == PaperKind.labelSheet => [
        'tenant_header',
        'asset_identity',
        'qr_code',
        'spacer',
        'divider',
      ],
      _ => const [],
    };
  }

  static List<String> _requiredBlocks(
    DocumentKind documentType,
    PaperKind paperKind,
  ) {
    return switch (documentType) {
      DocumentKind.salesInvoice || DocumentKind.purchaseInvoice => [
        'tenant_header',
        'document_meta',
        'party_details',
        'line_table',
        'totals',
        'footer',
      ],
      DocumentKind.receiptVoucher when paperKind == PaperKind.thermal80mm => [
        'tenant_header',
        'document_meta',
        'payment_details',
        'footer',
      ],
      DocumentKind.receiptVoucher => [
        'tenant_header',
        'document_meta',
        'party_details',
        'payment_details',
        'footer',
      ],
      DocumentKind.customerStatement => [
        'tenant_header',
        'document_meta',
        'party_details',
        'line_table',
        'totals',
        'footer',
      ],
      DocumentKind.assetTagLabel => [
        'tenant_header',
        'asset_identity',
        'qr_code',
      ],
      DocumentKind.paymentVoucher => const [],
    };
  }

  static String? _requiredPartyRole(
    DocumentKind documentType,
    PaperKind paperKind,
  ) {
    return switch (documentType) {
      DocumentKind.salesInvoice => 'customer',
      DocumentKind.purchaseInvoice => 'supplier',
      DocumentKind.receiptVoucher when paperKind == PaperKind.a4 => 'customer',
      DocumentKind.customerStatement => 'customer',
      _ => null,
    };
  }

  static List<String>? _blockFieldAllowlist(
    DocumentKind documentType,
    PaperKind paperKind,
    String blockType,
  ) {
    return switch (blockType) {
      'document_meta'
          when documentType == DocumentKind.salesInvoice ||
              documentType == DocumentKind.purchaseInvoice =>
        ['document.number', 'document.date', 'document.due_date'],
      'document_meta' when documentType == DocumentKind.receiptVoucher => [
        'document.number',
        'document.date',
      ],
      'document_meta' when documentType == DocumentKind.customerStatement => [
        'document.from_date',
        'document.to_date',
        'document.generated_at',
      ],
      'party_details'
          when documentType == DocumentKind.salesInvoice ||
              documentType == DocumentKind.purchaseInvoice ||
              documentType == DocumentKind.customerStatement =>
        ['party.name_ar', 'party.name_en', 'party.code'],
      'party_details'
          when documentType == DocumentKind.receiptVoucher &&
              paperKind == PaperKind.a4 =>
        ['party.name_ar', 'party.name_en'],
      'line_table'
          when documentType == DocumentKind.salesInvoice ||
              documentType == DocumentKind.purchaseInvoice =>
        ['line.description', 'line.qty', 'line.unit_price', 'line.total'],
      'line_table' when documentType == DocumentKind.customerStatement => [
        'line.date',
        'line.description',
        'line.debit',
        'line.credit',
        'line.balance',
      ],
      'totals'
          when documentType == DocumentKind.salesInvoice ||
              documentType == DocumentKind.purchaseInvoice =>
        ['totals.subtotal', 'totals.discount', 'totals.tax', 'totals.total'],
      'totals' when documentType == DocumentKind.customerStatement => [
        'summary.opening_balance',
        'summary.total_debit',
        'summary.total_credit',
        'summary.closing_balance',
      ],
      'payment_details'
          when documentType == DocumentKind.receiptVoucher &&
              paperKind == PaperKind.a4 =>
        [
          'payment.amount',
          'payment.method',
          'payment.reference',
          'payment.collected_by',
        ],
      'payment_details'
          when documentType == DocumentKind.receiptVoucher &&
              paperKind == PaperKind.thermal80mm =>
        ['payment.amount', 'payment.method', 'payment.reference'],
      'notes' => ['document.notes'],
      'asset_identity' when documentType == DocumentKind.assetTagLabel => [
        'tenant.company_name_ar',
        'product.name_ar',
        'product.name_en',
        'unit.serial',
      ],
      _ => null,
    };
  }
}
