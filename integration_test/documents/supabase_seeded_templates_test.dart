import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/config/env.dart';
import 'package:hs360/core/documents/data/document_template_repository.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/errors/document_exception.dart';
import 'package:hs360/core/network/supabase_client.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('local Supabase exposes seven seeded document templates', () async {
    if (Env.supabaseAnonKey.isEmpty) {
      fail('SUPABASE_ANON_KEY is required for this integration gate');
    }

    await SupabaseClientProvider.initialize();
    if (!SupabaseClientProvider.isInitialized) {
      fail('Supabase client failed to initialize');
    }

    final client = Supabase.instance.client;
    try {
      await client.auth.signOut();
    } catch (_) {
      // Ignore stale persisted session cleanup failures.
    }

    final auth = await _signInWithRetry(client);
    expect(auth.session, isNotNull, reason: 'seed owner sign-in failed');

    final repo = DocumentTemplateRepository(client);

    final cases = [
      (DocumentKind.salesInvoice, PaperKind.a4, 'sales_invoice_a4'),
      (DocumentKind.purchaseInvoice, PaperKind.a4, 'purchase_invoice_a4'),
      (DocumentKind.receiptVoucher, PaperKind.a4, 'receipt_voucher_a4'),
      (
        DocumentKind.receiptVoucher,
        PaperKind.thermal80mm,
        'receipt_voucher_80mm',
      ),
      (DocumentKind.customerStatement, PaperKind.a4, 'customer_statement_a4'),
      (DocumentKind.assetTagLabel, PaperKind.labelSheet, 'asset_tag_label'),
      (DocumentKind.contract, PaperKind.a4, 'contract_a4'),
    ];

    for (final entry in cases) {
      final kind = entry.$1;
      final paper = entry.$2;
      final key = entry.$3;
      final ctx = await repo.fetchEffectiveTemplate(
        documentType: kind,
        paperKind: paper,
      );
      expect(ctx.template.templateKey, key);
      expect(ctx.template.body.blocks, isNotEmpty);
      expect(ctx.template.body.schemaVersion, 1);
    }

    expect(
      () => repo.fetchEffectiveTemplate(
        documentType: DocumentKind.paymentVoucher,
      ),
      throwsA(isA<DocumentException>()),
    );

    await client.auth.signOut();
  });
}

Future<AuthResponse> _signInWithRetry(SupabaseClient client) async {
  Object? lastError;
  for (var attempt = 1; attempt <= 3; attempt++) {
    try {
      return await client.auth
          .signInWithPassword(
            email: 'owner@hayat-secret.test',
            password: 'Password123!',
          )
          .timeout(const Duration(seconds: 30));
    } catch (error) {
      lastError = error;
      if (attempt < 3) {
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
  }
  throw StateError('seed owner sign-in failed after retries: $lastError');
}
