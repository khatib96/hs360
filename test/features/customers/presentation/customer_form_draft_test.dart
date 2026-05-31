import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/customer_exception.dart';
import 'package:hs360/features/customers/presentation/customer_form_draft.dart';

void main() {
  group('CustomerFormDraft.validate', () {
    test('valid minimal draft has no errors', () {
      const draft = CustomerFormDraft(nameAr: 'عميل', phonePrimary: '99000000');
      expect(draft.validate(), isEmpty);
    });

    test('requires name_ar and phone_primary', () {
      const draft = CustomerFormDraft();
      final codes = draft.validate();
      expect(codes, contains(CustomerException.nameArRequired));
      expect(codes, contains(CustomerException.phonePrimaryRequired));
    });

    test('unparseable credit limit reports invalid_decimal (not silent)', () {
      const draft = CustomerFormDraft(
        nameAr: 'عميل',
        phonePrimary: '1',
        creditLimit: 'abc',
      );
      expect(draft.validate(), contains(CustomerFormDraft.invalidDecimal));
    });

    test('negative credit limit reports negative_credit_limit', () {
      const draft = CustomerFormDraft(
        nameAr: 'عميل',
        phonePrimary: '1',
        creditLimit: '-5',
      );
      expect(draft.validate(), contains(CustomerException.negativeCreditLimit));
    });

    test('unparseable payment terms reports invalid_integer', () {
      const draft = CustomerFormDraft(
        nameAr: 'عميل',
        phonePrimary: '1',
        paymentTermsDays: '3.5',
      );
      expect(draft.validate(), contains(CustomerFormDraft.invalidInteger));
    });

    test('negative payment terms reports negative_payment_terms', () {
      const draft = CustomerFormDraft(
        nameAr: 'عميل',
        phonePrimary: '1',
        paymentTermsDays: '-1',
      );
      expect(draft.validate(), contains(CustomerException.negativePaymentTerms));
    });

    test('one GPS field without the other is invalid', () {
      const draft = CustomerFormDraft(
        nameAr: 'عميل',
        phonePrimary: '1',
        gpsLat: '29.3',
      );
      expect(draft.validate(), contains(CustomerException.gpsInvalid));
    });

    test('unparseable GPS pair is invalid', () {
      const draft = CustomerFormDraft(
        nameAr: 'عميل',
        phonePrimary: '1',
        gpsLat: 'x',
        gpsLng: 'y',
      );
      expect(draft.validate(), contains(CustomerException.gpsInvalid));
    });

    test('out-of-range GPS is invalid', () {
      const draft = CustomerFormDraft(
        nameAr: 'عميل',
        phonePrimary: '1',
        gpsLat: '200',
        gpsLng: '50',
      );
      expect(draft.validate(), contains(CustomerException.gpsInvalid));
    });

    test('invalid email is reported', () {
      const draft = CustomerFormDraft(
        nameAr: 'عميل',
        phonePrimary: '1',
        email: 'not-an-email',
      );
      expect(draft.validate(), contains(CustomerException.emailInvalid));
    });

    test('toFormState parses numeric fields after a valid draft', () {
      const draft = CustomerFormDraft(
        nameAr: 'عميل',
        phonePrimary: '99',
        creditLimit: '150.5',
        paymentTermsDays: '30',
        gpsLat: '29.3',
        gpsLng: '48.0',
      );
      expect(draft.validate(), isEmpty);
      final state = draft.toFormState();
      expect(state.creditLimit.toString(), '150.5');
      expect(state.paymentTermsDays, 30);
      expect(state.gpsLat?.toString(), '29.3');
    });
  });
}
