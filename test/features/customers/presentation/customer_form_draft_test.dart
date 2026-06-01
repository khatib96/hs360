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

    test('invalid email is reported', () {
      const draft = CustomerFormDraft(
        nameAr: 'عميل',
        phonePrimary: '1',
        email: 'not-an-email',
      );
      expect(draft.validate(), contains(CustomerException.emailInvalid));
    });

    test('toFormState maps location and create_account', () {
      const draft = CustomerFormDraft(
        nameAr: 'عميل',
        phonePrimary: '99',
        governorate: 'hawalli',
        area: 'salmiya',
        googleMapsUrl: 'https://maps.example',
        createAccount: true,
      );
      expect(draft.validate(), isEmpty);
      final state = draft.toFormState();
      expect(state.governorate, 'hawalli');
      expect(state.area, 'salmiya');
      expect(state.googleMapsUrl, 'https://maps.example');
      expect(state.createAccount, isTrue);
    });

    test('custom area is resolved when useCustomArea is true', () {
      const draft = CustomerFormDraft(
        nameAr: 'عميل',
        phonePrimary: '99',
        governorate: 'hawalli',
        useCustomArea: true,
        customArea: 'منطقة خاصة',
      );
      final state = draft.toFormState();
      expect(state.area, 'منطقة خاصة');
    });
  });
}
