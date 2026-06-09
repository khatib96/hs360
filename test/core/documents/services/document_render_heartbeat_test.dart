import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/services/document_render_service.dart';
import 'package:hs360/features/invoices/domain/sales_invoice_document_fixture.dart';

import 'pdf/test_render_helpers.dart';

/// Stub heartbeat test: UI isolate remains responsive during PDF render.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('UI isolate heartbeat during render', () async {
    final service = DocumentRenderService();
    final context = testContext(kind: DocumentKind.salesInvoice);

    var heartbeats = 0;
    final ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      heartbeats++;
    });

    try {
      final renderFuture = service.render(
        context: context,
        payload: salesInvoiceDocumentFixture(),
        userLocale: 'en',
      );

      final completed = await Future.any([
        renderFuture.then((_) => 'render'),
        Future.delayed(const Duration(seconds: 45), () => 'timeout'),
      ]);

      expect(completed, 'render');
      expect(heartbeats, greaterThan(0));
    } finally {
      ticker.cancel();
    }
  });
}
