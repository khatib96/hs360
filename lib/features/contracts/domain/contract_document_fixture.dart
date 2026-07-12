import 'package:decimal/decimal.dart';

import '../../../core/documents/domain/document_kind.dart';
import '../../../core/documents/domain/document_payload.dart';

/// Minimal contract payload for renderer smoke tests (M11).
ContractPayload contractDocumentFixture() {
  return ContractPayload(
    document: {
      'number': 'CON-00042',
      'type': 'rental',
      'status': 'active',
      'printed_at': '2026-07-01',
      'start_date': '2026-07-01',
      'end_date': '2027-07-01',
      'duration_months': 12,
      'billing_day': 5,
      'refill_day': 10,
      'is_draft': false,
    },
    party: {
      'name_ar': 'عميل تجريبي',
      'name_en': 'Sample Customer',
      'contact_person': 'Sara',
      'phone': '+965 5000 0000',
      'email': 'sara@example.com',
    },
    location: {
      'name': 'Main Site',
      'governorate': 'Hawalli',
      'area': 'Salmiya',
    },
    lines: [
      {
        'product_name': 'Diffuser\nDiffuser',
        'serial': 'SN-001',
        'qty': Decimal.one,
        'unit': 'piece',
      },
      {
        'product_name': 'Fragrance oil',
        'serial': '',
        'qty': Decimal.parse('500'),
        'unit': 'ml',
      },
    ],
    totals: {
      'monthly_rental': Decimal.parse('120.000'),
      'total_value': Decimal.parse('1440.000'),
      'is_trial': false,
    },
  );
}

DocumentKind get contractDocumentFixtureKind => DocumentKind.contract;
