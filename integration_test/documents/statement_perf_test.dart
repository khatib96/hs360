import 'dart:async';
import 'dart:convert';
import 'dart:developer' show registerExtension, ServiceExtensionResponse;
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_payload.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/services/document_render_service.dart';
import 'package:hs360/core/documents/services/document_template_json_parser.dart';
import 'package:integration_test/integration_test.dart';

const _statementRowCap = int.fromEnvironment(
  'STATEMENT_ROW_CAP',
  defaultValue: 1000,
);
const _warmupRuns = int.fromEnvironment(
  'BENCHMARK_WARMUP_RUNS',
  defaultValue: 1,
);
const _measuredRuns = int.fromEnvironment(
  'BENCHMARK_MEASURED_RUNS',
  defaultValue: 3,
);
const _flutterVersion = String.fromEnvironment(
  'BENCHMARK_FLUTTER_VERSION',
  defaultValue: 'unknown',
);
const _gitSha = String.fromEnvironment(
  'BENCHMARK_GIT_SHA',
  defaultValue: 'unknown',
);
const _adbPath = String.fromEnvironment(
  'BENCHMARK_ADB_PATH',
  defaultValue: 'adb',
);

void registerBenchmarkExtensions({
  required void Function() onFinish,
  required DocumentRenderService renderService,
  required EffectiveDocumentContext context,
  required StatementPayload payload,
}) {
  registerExtension('ext.benchmark.metadata', (
    String method,
    Map<String, String> params,
  ) async {
    return ServiceExtensionResponse.result(
      jsonEncode({
        'pid': pid,
        'platform': Platform.operatingSystem,
        'statement_row_cap': _statementRowCap,
        'warmup_runs': _warmupRuns,
        'measured_runs': _measuredRuns,
        'flutter_version': _flutterVersion,
        'git_sha': _gitSha,
        'adb_path': _adbPath,
      }),
    );
  });

  registerExtension('ext.benchmark.runRender', (
    String method,
    Map<String, String> params,
  ) async {
    final run = int.tryParse(params['run'] ?? '') ?? 0;
    final kind = params['kind'] ?? 'measured';

    final stopwatch = Stopwatch()..start();
    final result = await renderService.render(
      context: context,
      payload: payload,
      userLocale: 'en',
    );
    stopwatch.stop();

    return ServiceExtensionResponse.result(
      jsonEncode({
        'run': run,
        'kind': kind,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'pdf_bytes': result.bytes.length,
        'page_count': result.pageCount,
        'line_count': payload.lines.length,
      }),
    );
  });

  registerExtension('ext.benchmark.finish', (
    String method,
    Map<String, String> params,
  ) async {
    onFinish();
    return ServiceExtensionResponse.result(jsonEncode({'finished': true}));
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('statement render benchmark handshake', (tester) async {
    final finishCompleter = Completer<void>();
    final context = _statementContext();
    final payload = _statementPayload(_statementRowCap);

    expect(payload.lines.length, _statementRowCap);
    expect(payload.rowCount, _statementRowCap);

    final renderService = DocumentRenderService();
    registerBenchmarkExtensions(
      onFinish: finishCompleter.complete,
      renderService: renderService,
      context: context,
      payload: payload,
    );

    await finishCompleter.future;
  });
}

EffectiveDocumentContext _statementContext() {
  const parser = DocumentTemplateJsonParser();
  final body = parser.parse(
    documentType: DocumentKind.customerStatement,
    paperKind: PaperKind.a4,
    raw: {
      'schema_version': 1,
      'settings': {
        'page_margin_mm': {'top': 12, 'right': 12, 'bottom': 12, 'left': 12},
        'base_font_size_pt': 10,
        'line_height': 1.35,
        'show_logo': true,
        'logo_max_height_mm': 18,
        'table_header_repeat': true,
        'digit_style': 'western',
      },
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
        {'type': 'footer', 'id': 'ftr', 'source': 'tenant_footer'},
      ],
    },
  );

  return EffectiveDocumentContext(
    template: DocumentTemplate(
      id: 'tpl-bench',
      templateKey: 'customer_statement_a4',
      documentType: DocumentKind.customerStatement,
      languageMode: DocumentLanguageMode.bilingual,
      paperKind: PaperKind.a4,
      schemaVersion: 1,
      body: body,
      nameAr: 'كشف حساب',
      nameEn: 'Customer Statement',
    ),
    settings: const {
      'default_language': 'bilingual',
      'footer_json': {'text_ar': 'تذييل', 'text_en': 'Footer'},
    },
    currency: {
      'code': 'KWD',
      'symbol': 'KWD',
      'symbol_position': 'after',
      'decimal_places': 3,
    },
    resolvedLogoUrl: null,
    companyNames: const {'ar': 'شركة تجريبية', 'en': 'Sample Co'},
  );
}

StatementPayload _statementPayload(int lineCount) {
  final lines = List<StatementLine>.generate(lineCount, (index) {
    final day = (index % 28) + 1;
    final month = (index % 12) + 1;
    final debit = index.isEven ? Decimal.parse('10.000') : Decimal.zero;
    final credit = index.isOdd ? Decimal.parse('5.000') : Decimal.zero;
    final balance =
        Decimal.parse('100.000') +
        Decimal.parse((index * 2.5).toStringAsFixed(3));
    return StatementLine(
      entryDate: DateTime(2025, month, day),
      entryNumber: 'JE-${index.toString().padLeft(5, '0')}',
      source: 'journal_entry',
      description: 'Movement $index',
      debit: debit,
      credit: credit,
      runningBalance: balance,
    );
  });

  return StatementPayload(
    customer: const {
      'id': 'c-bench',
      'code': 'C-BENCH',
      'name_ar': 'عميل أداء',
      'name_en': 'Perf Customer',
    },
    fromDate: DateTime(2025, 1, 1),
    toDate: DateTime(2025, 12, 31),
    generatedAt: DateTime(2026, 6, 1),
    summary: StatementSummary(
      openingBalance: Decimal.parse('100.000'),
      totalDebit: Decimal.parse('${lineCount ~/ 2 * 10}.000'),
      totalCredit: Decimal.parse('${(lineCount + 1) ~/ 2 * 5}.000'),
      closingBalance: Decimal.parse('1000.000'),
    ),
    lines: lines,
    rowCount: lineCount,
  );
}
