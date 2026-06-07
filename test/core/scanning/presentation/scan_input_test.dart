import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/scanning/data/scan_repository.dart';
import 'package:hs360/core/scanning/domain/scan_result.dart';
import 'package:hs360/core/scanning/presentation/scan_input.dart';
import 'package:hs360/l10n/app_localizations.dart';

class FakeScanRepository extends ScanRepository {
  FakeScanRepository(this.result) : super(null);

  final ScanResult result;
  String? lastCode;

  @override
  Future<ScanResult> resolveScanCode(String code) async {
    lastCode = code;
    return result;
  }
}

void main() {
  testWidgets('ScanInput resolves on Enter and clears field', (tester) async {
    const result = ScanResult(
      id: 'unit-1',
      productId: 'product-1',
      kind: ScanResultKind.productUnit,
      matchedBy: ScanMatchedBy.unitBarcode,
      displayCode: 'BC-1',
      isActiveOrAvailable: true,
    );

    final fakeRepo = FakeScanRepository(result);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scanRepositoryProvider.overrideWith((ref) => fakeRepo),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ScanInput()),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('scan-input-field')), 'BC-1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(fakeRepo.lastCode, 'BC-1');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('scan-input-field')))
          .controller!
          .text,
      isEmpty,
    );
  });
}
