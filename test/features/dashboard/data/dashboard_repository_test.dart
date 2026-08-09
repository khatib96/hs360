import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/dashboard/data/dashboard_repository.dart';

void main() {
  final session = AppSession(
    userId: 'user-1',
    email: 'user@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tenant-user-1',
    accountType: 'user',
    displayName: 'User',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: {'dashboard.view'},
    ),
  );

  test('maps Dashboard v1 and sends a date-only parameter', () async {
    String? calledName;
    Map<String, dynamic>? calledParams;
    final repository = DashboardRepository(
      null,
      rpcInvoker: (name, params) async {
        calledName = name;
        calledParams = params;
        return _dashboardJson;
      },
    );

    final result = await repository.getDashboard(
      session,
      businessDate: DateTime(2026, 8, 5, 23, 30),
    );

    expect(calledName, 'get_phase_7_5_dashboard');
    expect(calledParams?['p_business_date'], '2026-08-05');
    expect(result.businessDate, DateTime(2026, 8, 5));
    expect(result.todaySchedule.total, 7);
    expect(result.contracts.assetsAttention, 2);
    expect(result.financial.outstanding, 75);
    expect(result.currencyCode, 'KWD');
  });

  test('maps safe paginated activity and drops unsafe routes', () async {
    final repository = DashboardRepository(
      null,
      rpcInvoker: (_, _) async => {
        'business_date': '2026-08-05',
        'timezone_name': 'Asia/Kuwait',
        'currency_code': 'KWD',
        'total_count': 2,
        'has_more': true,
        'items': [
          {
            'kind': 'invoice',
            'entity_id': 'invoice-1',
            'occurred_at': '2026-08-05T08:00:00Z',
            'local_time': '11:00',
            'title_ar': 'فاتورة',
            'title_en': 'Invoice',
            'identifier': 'SI-1',
            'status': 'confirmed',
            'amount': '25.500',
            'source_route': '/invoices/invoice-1?type=sales',
          },
          {
            'kind': 'visit_outcome',
            'entity_id': 'visit-1',
            'occurred_at': '2026-08-05T07:00:00Z',
            'title_ar': 'زيارة',
            'title_en': 'Visit',
            'identifier': 'V-1',
            'status': 'completed',
            'source_route': 'https://unsafe.example',
          },
        ],
      },
    );

    final page = await repository.listDailyActivity(session);

    expect(page.items, hasLength(2));
    expect(page.items.first.amount, 25.5);
    expect(page.items.first.localTime, '11:00');
    expect(page.items.first.sourceRoute, startsWith('/invoices/'));
    expect(page.items.last.sourceRoute, isNull);
    expect(page.hasMore, isTrue);
    expect(page.currencyCode, 'KWD');
  });

  test('normalizes server timezone errors', () async {
    final repository = DashboardRepository(
      null,
      rpcInvoker: (_, _) async =>
          throw Exception('calendar_timezone_unconfigured'),
    );

    await expectLater(
      repository.getDashboard(session),
      throwsA(
        isA<DashboardException>().having(
          (error) => error.code,
          'code',
          DashboardException.timezoneUnconfigured,
        ),
      ),
    );
  });
}

const _dashboardJson = {
  'business_date': '2026-08-05',
  'timezone_name': 'Asia/Kuwait',
  'currency_code': 'KWD',
  'today_schedule': {
    'visible': true,
    'total': 7,
    'completed': 3,
    'remaining': 4,
  },
  'overdue': {'visible': true, 'count': 1},
  'contracts': {
    'visible': true,
    'active': 6,
    'trials': 2,
    'rentals': 4,
    'asset_condition_visible': true,
    'assets_rented': 4,
    'assets_trial': 2,
    'assets_attention': 2,
  },
  'financial': {
    'collections_visible': true,
    'collections': 25,
    'outstanding_visible': true,
    'outstanding': 75,
    'month_start': '2026-08-01',
  },
};
