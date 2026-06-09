import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/tenant_document_settings.dart';

void main() {
  Map<String, dynamic> validRpc() => {
    'tenant_id': '00000000-0000-0000-0000-000000000001',
    'default_language': 'bilingual',
    'invoice_paper_kind': 'a4',
    'voucher_paper_kind': 'a4',
    'asset_label_paper_kind': 'label_sheet',
    'header_json': {'text_ar': 'رأس', 'text_en': 'Header'},
    'footer_json': {'text_en': 'Footer'},
    'optional_columns_json': {
      'sales_invoice': {'line.qty': true},
    },
  };

  test('fromRpc accepts valid settings', () {
    final settings = TenantDocumentSettings.fromRpc(validRpc());
    expect(settings.tenantId, isNotEmpty);
    expect(settings.headerJson['text_ar'], 'رأس');
    expect(settings.optionalColumnsJson['sales_invoice'], isA<Map>());
  });

  test('fromRpc throws on unknown header key', () {
    final rpc = validRpc();
    (rpc['header_json'] as Map)['bad'] = 'x';
    expect(
      () => TenantDocumentSettings.fromRpc(rpc),
      throwsA(isA<TenantDocumentSettingsException>()),
    );
  });

  test('fromRpc throws on control characters in header text', () {
    final rpc = validRpc();
    (rpc['header_json'] as Map)['text_en'] = 'bad\x00char';
    expect(
      () => TenantDocumentSettings.fromRpc(rpc),
      throwsA(isA<TenantDocumentSettingsException>()),
    );
  });

  test('fromRpc throws when optional column value is not boolean', () {
    final rpc = validRpc();
    rpc['optional_columns_json'] = {
      'sales_invoice': {'line.qty': 'yes'},
    };
    expect(
      () => TenantDocumentSettings.fromRpc(rpc),
      throwsA(isA<TenantDocumentSettingsException>()),
    );
  });

  test('fromRpc throws when mandatory column patched to false', () {
    final rpc = validRpc();
    (rpc['optional_columns_json'] as Map)['customer_statement'] = {
      'line.date': false,
    };
    expect(
      () => TenantDocumentSettings.fromRpc(rpc),
      throwsA(isA<TenantDocumentSettingsException>()),
    );
  });

  test('fromRpc throws on unknown document type in optional columns', () {
    final rpc = validRpc();
    rpc['optional_columns_json'] = {
      ...validRpc()['optional_columns_json'] as Map,
      'payment_voucher': <String, dynamic>{},
    };
    expect(
      () => TenantDocumentSettings.fromRpc(rpc),
      throwsA(isA<TenantDocumentSettingsException>()),
    );
  });

  test('fromRpc throws on missing tenant_id', () {
    final rpc = validRpc()..remove('tenant_id');
    expect(
      () => TenantDocumentSettings.fromRpc(rpc),
      throwsA(isA<TenantDocumentSettingsException>()),
    );
  });
}
