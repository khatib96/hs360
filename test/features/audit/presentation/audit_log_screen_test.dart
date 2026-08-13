import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/audit/data/audit_log_repository.dart';
import 'package:hs360/features/audit/domain/audit_log_entry.dart';
import 'package:hs360/features/audit/domain/audit_log_filters.dart';
import 'package:hs360/features/audit/presentation/audit_log_screen.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/l10n/app_localizations.dart';

class _TestAuth extends AuthController {
  _TestAuth(this.session);

  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}

class _FakeAuditRepository extends AuditLogRepository {
  _FakeAuditRepository(this.page) : super(null);

  final AuditLogPage page;
  int calls = 0;
  AuditLogFilters? lastFilters;

  @override
  Future<AuditLogPage> list(
    AppSession session, {
    AuditLogFilters filters = const AuditLogFilters(),
    DateTime? beforeAt,
    int? beforeId,
    int limit = AuditLogRepository.pageSize,
  }) async {
    calls++;
    lastFilters = filters;
    return page;
  }
}

void main() {
  testWidgets('renders safe audit history and explains redacted source data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeAuditRepository(
      AuditLogPage(
        timezoneName: 'Asia/Dubai',
        hasMore: false,
        items: [
          AuditLogEntry(
            id: 1,
            occurredAt: DateTime.utc(2026, 8, 9, 9),
            localTime: '2026-08-09 13:00',
            actorName: 'Audit User',
            action: 'update',
            module: 'parties',
            entityType: 'customers',
            entityId: 'customer-1',
            reason: 'Correction',
            sourceVisible: false,
            beforeSummary: const {},
            afterSummary: const {},
            changedFields: const [],
          ),
        ],
      ),
    );
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _TestAuth(session)),
          auditLogRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AuditLogScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Audit Log'), findsWidgets);
    expect(find.textContaining('Asia/Dubai'), findsOneWidget);
    expect(find.textContaining('Updated'), findsOneWidget);
    expect(find.byTooltip('Open source record'), findsNothing);
    await tester.tap(find.textContaining('Updated'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('details are hidden', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Correction'), findsOneWidget);
    expect(repository.calls, 1);
    expect(tester.takeException(), isNull);
  });
}
