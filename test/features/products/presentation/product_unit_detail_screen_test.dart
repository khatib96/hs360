import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/core/localization/locale_controller.dart';
import 'package:hs360/features/inventory/data/warehouse_repository.dart';
import 'package:hs360/features/products/data/product_unit_repository.dart';
import 'package:hs360/features/products/domain/product_unit.dart';
import 'package:hs360/features/products/domain/product_unit_health_status.dart';
import 'package:hs360/features/products/domain/unit_status.dart';
import 'package:hs360/features/products/domain/unit_timeline_event.dart';
import 'package:hs360/features/products/presentation/product_unit_detail_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_product_unit_repository.dart';
import '../../inventory/fake_warehouse_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}

ProductUnit _sampleUnit() {
  return ProductUnit(
    id: 'unit-1',
    tenantId: 'tenant-1',
    productId: 'product-1',
    serialNumber: 'SN-001',
    barcode: 'BC-001',
    status: UnitStatus.availableNew,
    currentWarehouseId: 'wh-1',
    warehouseNameAr: 'المخزن',
    warehouseNameEn: 'Warehouse',
    healthStatus: ProductUnitHealthStatus.good,
    acquiredAt: DateTime(2026, 1, 1),
    totalMaintenanceCount: 2,
  );
}

UnitTimelineEvent _sampleEvent() {
  return UnitTimelineEvent(
    tenantId: 'tenant-1',
    productUnitId: 'unit-1',
    eventType: 'acquisition',
    occurredAt: DateTime(2026, 1, 1),
    titleKey: 'unit_timeline.acquisition',
  );
}

void main() {
  AppSession session({Set<String> permissions = const {'product_units.view'}}) {
    return AppSession(
      userId: 'user-1',
      email: 'test@example.com',
      tenantId: 'tenant-1',
      tenantUserId: 'tu-1',
      accountType: 'user',
      displayName: 'Test User',
      preferredLocale: 'en',
      permissions: AppPermissions(isManager: false, permissions: permissions),
    );
  }

  Widget buildScreen({
    required AppSession appSession,
    required FakeProductUnitRepository unitRepo,
    Locale locale = const Locale('en'),
    Size size = const Size(1600, 900),
  }) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => TestAuthController(appSession),
        ),
        productUnitRepositoryProvider.overrideWith((ref) => unitRepo),
        warehouseRepositoryProvider.overrideWith(
          (ref) => FakeWarehouseRepository(
            warehouses: [sampleWarehouse(id: 'wh-1')],
          ),
        ),
        localeProvider.overrideWith((ref) => locale),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(size: size),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const ProductUnitDetailScreen(unitId: 'unit-1'),
      ),
    );
  }

  testWidgets('mobile Arabic shows unit metadata without correction card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final unitRepo = FakeProductUnitRepository(
      unitById: _sampleUnit(),
      timelineEvents: [_sampleEvent()],
    );

    await tester.pumpWidget(
      buildScreen(
        appSession: session(),
        unitRepo: unitRepo,
        locale: const Locale('ar'),
        size: const Size(360, 800),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SN-001'), findsWidgets);
    expect(find.text('المخزن'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      find.byKey(const Key('product-unit-serial-correction-hidden')),
      findsOneWidget,
    );
    expect(find.text('اكتساب الوحدة'), findsOneWidget);
  });

  testWidgets('desktop English shows correction card when permitted', (
    tester,
  ) async {
    final unitRepo = FakeProductUnitRepository(
      unitById: _sampleUnit(),
      timelineEvents: [_sampleEvent()],
    );

    await tester.pumpWidget(
      buildScreen(
        appSession: session(
          permissions: const {
            'product_units.view',
            'product_units.correct_serial',
          },
        ),
        unitRepo: unitRepo,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('product-unit-serial-correction-card')),
      findsOneWidget,
    );
    expect(find.text('Correct serial number'), findsOneWidget);
  });
}
