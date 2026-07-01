// Supporting (NOT live-app) Arabic RTL screenshot harness for the invoice
// redesign. Renders the real screens through AppShell with the bundled Noto
// fonts and seeded sample data, then writes PNGs to build/screenshots/.
//
// These are supporting renders only. Visual acceptance still requires live
// macOS app screenshots in Arabic from an authenticated session.
//
// Run: flutter test test/screenshots/invoice_screenshots.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/theme/app_theme.dart';
import 'package:hs360/domain/finance/tax_class.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/customers/domain/customer.dart';
import 'package:hs360/features/customers/domain/customer_type.dart';
import 'package:hs360/features/finance_shared/domain/party_reference.dart';
import 'package:hs360/features/inventory/data/warehouse_repository.dart';
import 'package:hs360/features/inventory/domain/warehouse.dart';
import 'package:hs360/features/inventory/domain/warehouse_type.dart';
import 'package:hs360/features/invoices/data/invoice_repository.dart';
import 'package:hs360/features/invoices/domain/invoice_detail.dart';
import 'package:hs360/features/invoices/domain/invoice_line.dart';
import 'package:hs360/features/invoices/domain/invoice_status.dart';
import 'package:hs360/features/invoices/domain/invoice_summary.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';
import 'package:hs360/features/invoices/presentation/invoice_detail_screen.dart';
import 'package:hs360/features/invoices/presentation/invoice_form_controller.dart';
import 'package:hs360/features/invoices/presentation/invoice_form_screen.dart';
import 'package:hs360/features/invoices/presentation/invoice_list_screen.dart';
import 'package:hs360/features/products/domain/product.dart';
import 'package:hs360/features/products/domain/product_type.dart';
import 'package:hs360/features/products/domain/unit_of_measure.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../features/invoices/fake_invoice_repository.dart';

final _rootKey = GlobalKey();
const _d = Size(1440, 1280);
const _narrow = Size(390, 844);

void main() {
  setUpAll(_loadFonts);

  testWidgets('invoice list desktop (AR) with add menu', (tester) async {
    await _pump(
      tester,
      size: const Size(1440, 1000),
      overrides: [
        invoiceRepositoryProvider.overrideWith(
          (ref) => FakeInvoiceRepository(salesInvoices: _sampleSummaries()),
        ),
      ],
      session: _session({
        'invoices.view_sales',
        'invoices.create_sales',
        'invoices.create_purchase',
        'invoices.create_sales_return',
        'invoices.create_purchase_return',
      }),
      child: const InvoiceListScreen(),
    );
    // Open the single "+ إضافة" command-menu for the screenshot.
    await tester.tap(find.widgetWithIcon(FilledButton, Icons.add));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _capture(tester, 'invoice_list_desktop_ar');
  });

  testWidgets('invoice form desktop (AR)', (tester) async {
    await _pump(
      tester,
      size: _d,
      overrides: [
        invoiceRepositoryProvider.overrideWith((ref) => FakeInvoiceRepository()),
        warehouseRepositoryProvider.overrideWith(
          (ref) => _FakeWarehouseRepo([_warehouse()]),
        ),
      ],
      session: _session({'invoices.create_sales'}),
      child: const InvoiceFormScreen(invoiceType: InvoiceType.sales),
    );
    await tester.pumpAndSettle();
    _seedForm(tester);
    await tester.pumpAndSettle();
    // Regression: editing qty then deleting a line must not crash.
    _editQtyAndDeleteLine(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _capture(tester, 'invoice_form_desktop_ar');
  });

  testWidgets('invoice detail desktop (AR)', (tester) async {
    await _pump(
      tester,
      size: _d,
      overrides: [
        invoiceRepositoryProvider.overrideWith(
          (ref) => FakeInvoiceRepository(detailById: {'inv-1': _sampleDetail()}),
        ),
      ],
      session: _session({'invoices.view_sales', 'invoices.print'}),
      child: const InvoiceDetailScreen(invoiceId: 'inv-1'),
    );
    await _capture(tester, 'invoice_detail_desktop_ar');
  });

  testWidgets('invoice detail narrow (AR)', (tester) async {
    await _pump(
      tester,
      size: _narrow,
      overrides: [
        invoiceRepositoryProvider.overrideWith(
          (ref) => FakeInvoiceRepository(detailById: {'inv-1': _sampleDetail()}),
        ),
      ],
      session: _session({'invoices.view_sales', 'invoices.print'}),
      child: const InvoiceDetailScreen(invoiceId: 'inv-1'),
    );
    await _capture(tester, 'invoice_detail_narrow_ar');
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required List<Override> overrides,
  required AppSession session,
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final base = AppTheme.light();
  final theme = base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'NotoSans',
      fontFamilyFallback: const ['NotoSansArabic'],
    ),
    primaryTextTheme: base.primaryTextTheme.apply(
      fontFamily: 'NotoSans',
      fontFamilyFallback: const ['NotoSansArabic'],
    ),
  );

  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _TestAuth(session)),
          ...overrides,
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme,
          home: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _seedForm(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(InvoiceFormScreen)),
  );
  final c = container.read(
    invoiceFormControllerProvider(InvoiceType.sales).notifier,
  );
  c.setCustomer(_customer());
  c.setWarehouseId(_warehouse().id);
  c.setDate(DateTime(2026, 6, 17));
  c.setDueDate(DateTime(2026, 7, 1));
  c.setNotes('دفعة أولى عند التسليم والباقي خلال ١٥ يومًا');

  final products = _sampleProducts();
  c.selectProduct(0, products[0]);
  c.setLineQty(0, Decimal.fromInt(2));
  c.addLine();
  c.selectProduct(1, products[1]);
  c.setLineQty(1, Decimal.fromInt(3));
  c.setLineDiscountPct(1, Decimal.fromInt(10));
  c.addLine();
  c.selectProduct(2, products[2]);
  c.setLineQty(2, Decimal.fromInt(1));
}

void _editQtyAndDeleteLine(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(InvoiceFormScreen)),
  );
  final c = container.read(
    invoiceFormControllerProvider(InvoiceType.sales).notifier,
  );
  // Clear a qty (would previously crash the estimate), then delete that line.
  c.setLineQty(2, Decimal.zero);
  c.removeLine(2);
  // Edit a remaining line's qty.
  c.setLineQty(0, Decimal.fromInt(4));
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary =
      _rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/screenshots')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(
      bytes!.buffer.asUint8List(),
    );
    image.dispose();
  });
}

Future<void> _loadFonts() async {
  const families = {
    'NotoSans': [
      'assets/fonts/noto/NotoSans-Regular.ttf',
      'assets/fonts/noto/NotoSans-Bold.ttf',
    ],
    'NotoSansArabic': [
      'assets/fonts/noto/NotoSansArabic-Regular.ttf',
      'assets/fonts/noto/NotoSansArabic-Bold.ttf',
    ],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

class _TestAuth extends AuthController {
  _TestAuth(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session(Set<String> permissions) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'مستخدم تجريبي',
    preferredLocale: 'ar',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

class _FakeWarehouseRepo extends WarehouseRepository {
  _FakeWarehouseRepo(this.items) : super(null);
  final List<Warehouse> items;
  @override
  Future<List<Warehouse>> fetchWarehouses({bool activeOnly = true}) async =>
      items;
}

Warehouse _warehouse() => Warehouse(
  id: 'wh-1',
  tenantId: 't',
  nameAr: 'المستودع الرئيسي',
  nameEn: 'Main warehouse',
  type: WarehouseType.values.first,
  isActive: true,
);

Customer _customer() => Customer(
  id: 'cust-1',
  tenantId: 't',
  code: 'CUST-0001',
  customerType: CustomerType.values.first,
  nameAr: 'مؤسسة النخبة لقطع غيار السيارات',
  nameEn: 'Elite Auto Parts',
  phonePrimary: '0500000000',
  isActive: true,
  isVip: false,
);

List<Product> _sampleProducts() => [
  _product('p1', 'OIL-5L', 'زيت محرك تخليقي ٥ لتر', UnitOfMeasure.liter, '85'),
  _product('p2', 'FLT-100', 'فلتر زيت أصلي', UnitOfMeasure.piece, '45'),
  _product('p3', 'CLN-200', 'بخاخ تنظيف محرك', UnitOfMeasure.bottle, '30'),
];

Product _product(
  String id,
  String sku,
  String nameAr,
  UnitOfMeasure unit,
  String price,
) {
  return Product(
    id: id,
    tenantId: 't',
    sku: sku,
    nameAr: nameAr,
    nameEn: nameAr,
    groupId: 'g',
    productType: ProductType.saleOnly,
    canBeSold: true,
    canBeRented: false,
    unitPrimary: unit,
    conversionFactor: Decimal.one,
    salePrice: Decimal.parse(price),
    isSerialized: false,
    trackableForMaintenance: false,
    isActive: true,
  );
}

List<InvoiceSummary> _sampleSummaries() {
  InvoiceSummary s(
    String id,
    String number,
    String nameAr,
    String total,
    InvoiceStatus status,
    int day,
  ) {
    return InvoiceSummary(
      id: id,
      invoiceNumber: number,
      type: InvoiceType.sales,
      status: status,
      date: DateTime(2026, 6, day),
      dueDate: DateTime(2026, 6, day + 14),
      party: PartyReference(customerId: id, nameAr: nameAr, nameEn: nameAr),
      total: Decimal.parse(total),
      paidAmount: Decimal.zero,
      outstanding: Decimal.parse(total),
    );
  }

  return [
    s('a', 'SI-2026-014', 'مؤسسة النخبة لقطع غيار السيارات', '335.000',
        InvoiceStatus.confirmed, 14),
    s('b', 'SI-2026-013', 'ورشة الفهد للصيانة', '1240.500',
        InvoiceStatus.partiallyPaid, 12),
    s('c', 'SI-2026-012', 'شركة المسار للنقل', '780.000', InvoiceStatus.paid, 9),
    s('d', 'SI-2026-011', 'محطة الواحة', '95.250', InvoiceStatus.confirmed, 7),
    s('e', 'SI-2026-010', 'مركز السرعة للزيوت', '460.000', InvoiceStatus.paid, 4),
    s('f', 'SI-2026-009', 'مؤسسة الإتقان', '210.000', InvoiceStatus.cancelled, 2),
  ];
}

InvoiceDetail _sampleDetail() {
  InvoiceLine line(
    int order,
    String desc,
    String qty,
    String price,
    String discPct,
    String total,
  ) {
    return InvoiceLine(
      id: 'l$order',
      lineOrder: order,
      productId: 'p$order',
      description: desc,
      qty: Decimal.parse(qty),
      unitPrice: Decimal.parse(price),
      discountPct: Decimal.parse(discPct),
      grossAmount: Decimal.parse(total),
      discountAmount: Decimal.zero,
      beforeTaxAmount: Decimal.parse(total),
      taxRate: Decimal.zero,
      taxClass: ProductTaxClass.nonTaxable,
      taxableAmount: Decimal.zero,
      taxAmount: Decimal.zero,
      afterTaxAmount: Decimal.parse(total),
      lineTotal: Decimal.parse(total),
    );
  }

  return InvoiceDetail(
    id: 'inv-1',
    invoiceNumber: 'SI-2026-014',
    type: InvoiceType.sales,
    status: InvoiceStatus.partiallyPaid,
    date: DateTime(2026, 6, 14),
    dueDate: DateTime(2026, 6, 28),
    customer: const PartyReference(
      customerId: 'cust-1',
      nameAr: 'مؤسسة النخبة لقطع غيار السيارات',
      nameEn: 'Elite Auto Parts',
    ),
    warehouse: const InvoiceWarehouseRef(
      id: 'wh-1',
      nameAr: 'المستودع الرئيسي',
      nameEn: 'Main warehouse',
    ),
    notes: 'تسليم خلال يومين، الدفع نقدًا عند الاستلام.',
    subtotal: Decimal.parse('335.000'),
    discountAmount: Decimal.parse('13.500'),
    taxAmount: Decimal.zero,
    total: Decimal.parse('321.500'),
    paidAmount: Decimal.parse('150.000'),
    outstanding: Decimal.parse('171.500'),
    journalEntryId: 'je-1',
    lines: [
      line(1, 'زيت محرك تخليقي ٥ لتر', '2', '85.000', '0', '170.000'),
      line(2, 'فلتر زيت أصلي', '3', '45.000', '10', '121.500'),
      line(3, 'بخاخ تنظيف محرك', '1', '30.000', '0', '30.000'),
    ],
  );
}
