import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/audit/data/audit_log_repository.dart';
import 'package:hs360/features/audit/domain/audit_log_filters.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';

void main() {
  final session = AppSession(
    userId: 'user-1',
    email: 'audit@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tenant-user-1',
    accountType: 'user',
    displayName: 'Audit User',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: {'audit_log.view'},
    ),
  );

  test('sends normalized filters and maps cursor response', () async {
    String? calledName;
    Map<String, dynamic>? calledParams;
    final repository = AuditLogRepository(
      null,
      rpcInvoker: (name, params) async {
        calledName = name;
        calledParams = params;
        return _pageJson;
      },
    );

    final page = await repository.list(
      session,
      filters: AuditLogFilters(
        module: 'finance',
        action: 'cancel',
        dateFrom: DateTime(2026, 8, 1, 18),
        dateTo: DateTime(2026, 8, 9, 22),
        search: '  INV-100  ',
      ),
      beforeAt: DateTime.utc(2026, 8, 8, 9),
      beforeId: 40,
    );

    expect(calledName, 'list_phase_7_5_audit_log');
    expect(calledParams?['p_module'], 'finance');
    expect(calledParams?['p_date_from'], '2026-08-01');
    expect(calledParams?['p_date_to'], '2026-08-09');
    expect(calledParams?['p_search'], 'INV-100');
    expect(calledParams?['p_before_id'], 40);
    expect(page.timezoneName, 'Asia/Dubai');
    expect(page.items.single.reason, 'Customer request');
    expect(page.items.single.beforeSummary, {'status': 'confirmed'});
    expect(page.items.single.sourceRoute, '/invoices/invoice-1?type=sales');
    expect(page.hasMore, isTrue);
    expect(page.nextBeforeId, 39);
  });

  test('does not accept external or authority-style source routes', () async {
    for (final route in [
      'https://unsafe.example/invoices/1',
      '//unsafe.example/invoices/1',
      r'\\unsafe.example\invoices\1',
    ]) {
      final repository = AuditLogRepository(
        null,
        rpcInvoker: (_, _) async => {
          ..._pageJson,
          'items': [
            {
              ...(_pageJson['items']! as List).single as Map,
              'source_route': route,
            },
          ],
        },
      );
      final page = await repository.list(session);
      expect(page.items.single.sourceRoute, isNull, reason: route);
    }
  });

  test('normalizes permission failures', () async {
    final repository = AuditLogRepository(
      null,
      rpcInvoker: (_, _) async => throw Exception('permission_denied'),
    );
    await expectLater(
      repository.list(session),
      throwsA(
        isA<AuditLogException>().having(
          (error) => error.code,
          'code',
          AuditLogException.permissionDenied,
        ),
      ),
    );
  });
}

const _pageJson = <String, dynamic>{
  'timezone_name': 'Asia/Dubai',
  'has_more': true,
  'next_before_at': '2026-08-08T08:00:00Z',
  'next_before_id': 39,
  'items': [
    {
      'id': 40,
      'at': '2026-08-08T09:00:00Z',
      'local_time': '2026-08-08 13:00',
      'actor_id': 'actor-1',
      'actor_name': 'Audit User',
      'actor_account_type': 'user',
      'action': 'cancel',
      'module': 'finance',
      'entity_type': 'invoices',
      'entity_id': 'invoice-1',
      'reason': 'Customer request',
      'source_visible': true,
      'before_summary': {'status': 'confirmed'},
      'after_summary': {'status': 'cancelled'},
      'changed_fields': ['status'],
      'source_route': '/invoices/invoice-1?type=sales',
    },
  ],
};
