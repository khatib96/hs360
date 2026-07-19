import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/presentation/widgets/contract_upcoming_schedule_section.dart';
import 'package:hs360/features/customers/data/customer_repository.dart';
import 'package:hs360/features/customers/data/customer_service_location_repository.dart';
import 'package:hs360/features/customers/presentation/customer_detail_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../contracts/fake_contract_repository.dart';
import '../../customers/fake_customer_repository.dart';
import '../../customers/fake_customer_service_location_repository.dart';

class _TestAuth extends AuthController {
  _TestAuth(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session({Set<String> permissions = const {'customers.view'}}) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

void main() {
  testWidgets('customer detail shows exactly one calendar entry when permitted', (
    tester,
  ) async {
    final customer = sampleCustomer();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuth(
              _session(permissions: const {'customers.view', 'calendar.view'}),
            ),
          ),
          customerRepositoryProvider.overrideWith(
            (ref) => FakeCustomerRepository(customers: [customer]),
          ),
          customerServiceLocationRepositoryProvider.overrideWith(
            (ref) => FakeCustomerServiceLocationRepository(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CustomerDetailScreen(customerId: customer.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer-view-in-calendar')), findsOneWidget);
    expect(find.byKey(const Key('customer-detail-open-calendar')), findsNothing);
  });

  testWidgets('customer detail hides calendar entry without calendar permission', (
    tester,
  ) async {
    final customer = sampleCustomer();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuth(_session(permissions: const {'customers.view'})),
          ),
          customerRepositoryProvider.overrideWith(
            (ref) => FakeCustomerRepository(customers: [customer]),
          ),
          customerServiceLocationRepositoryProvider.overrideWith(
            (ref) => FakeCustomerServiceLocationRepository(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CustomerDetailScreen(customerId: customer.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer-view-in-calendar')), findsNothing);
    expect(find.byKey(const Key('customer-detail-open-calendar')), findsNothing);
  });

  testWidgets('contract upcoming schedule exposes a single calendar link', (
    tester,
  ) async {
    final detail = sampleContractDetail();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuth(
              _session(permissions: const {'calendar.view'}),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ContractUpcomingScheduleSection(
              detail: detail,
              languageCode: 'en',
              session: _session(permissions: const {'calendar.view'}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contract-view-in-calendar')), findsOneWidget);
  });

  testWidgets('contract calendar link is hidden without calendar permission', (
    tester,
  ) async {
    final detail = sampleContractDetail();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ContractUpcomingScheduleSection(
            detail: detail,
            languageCode: 'en',
            session: _session(permissions: const {'customers.view'}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contract-view-in-calendar')), findsNothing);
  });
}
