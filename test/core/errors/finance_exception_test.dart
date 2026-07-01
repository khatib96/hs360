import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('FinanceException.fromSupabase', () {
    test('maps permission_denied from PostgrestException message', () {
      final error = FinanceException.fromSupabase(
        const PostgrestException(message: 'permission_denied'),
      );
      expect(error.code, FinanceException.permissionDenied);
    });

    test('maps idempotency_payload_mismatch', () {
      final error = FinanceException.fromSupabase(
        Exception('idempotency_payload_mismatch on retry'),
      );
      expect(error.code, FinanceException.idempotencyPayloadMismatch);
    });

    test('maps books_locked and duplicate_serial', () {
      expect(
        FinanceException.fromSupabase(Exception('books_locked')).code,
        FinanceException.booksLocked,
      );
      expect(
        FinanceException.fromSupabase(Exception('duplicate_serial')).code,
        FinanceException.duplicateSerial,
      );
    });

    test('maps inventory accounting errors', () {
      expect(
        FinanceException.fromSupabase(Exception('insufficient_stock')).code,
        FinanceException.insufficientStock,
      );
      expect(
        FinanceException.fromSupabase(
          Exception('correction_document_required'),
        ).code,
        FinanceException.correctionDocumentRequired,
      );
    });

    test('maps tax errors and validation_failed', () {
      expect(
        FinanceException.fromSupabase(Exception('tax_rate_not_found')).code,
        FinanceException.taxRateNotFound,
      );
      expect(
        FinanceException.fromSupabase(Exception('tax_rate_in_use')).code,
        FinanceException.taxRateInUse,
      );
      expect(
        FinanceException.fromSupabase(Exception('validation_failed')).code,
        FinanceException.validationFailed,
      );
    });

    test('maps missing cash invoice RPC to backend migration required', () {
      final error = FinanceException.fromSupabase(
        const PostgrestException(
          message:
              'could not find the function public.record_cash_sales_invoice(p_data, p_idempotency_key) in the schema cache',
        ),
      );
      expect(error.code, FinanceException.backendMigrationRequired);
    });

    test(
      'maps stale cash invoice conflict target to backend migration required',
      () {
        final error = FinanceException.fromSupabase(
          const PostgrestException(
            message:
                'there is no unique or exclusion constraint matching the on conflict specification',
          ),
        );
        expect(error.code, FinanceException.backendMigrationRequired);
      },
    );

    test('returns same instance when already FinanceException', () {
      const original = FinanceException(code: FinanceException.tenantNotFound);
      expect(FinanceException.fromSupabase(original), same(original));
    });

    test('falls back to unknown for unrecognized messages', () {
      final error = FinanceException.fromSupabase(Exception('network timeout'));
      expect(error.code, FinanceException.unknown);
    });
  });
}
