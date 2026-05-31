import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/supplier_exception.dart';
import 'package:hs360/features/suppliers/presentation/supplier_form_draft.dart';

void main() {
  group('SupplierFormDraft.validate', () {
    test('valid minimal draft has no errors', () {
      const draft = SupplierFormDraft(nameAr: 'مورّد');
      expect(draft.validate(), isEmpty);
    });

    test('requires name_ar', () {
      const draft = SupplierFormDraft();
      expect(draft.validate(), contains(SupplierException.nameArRequired));
    });

    test('invalid email is reported', () {
      const draft = SupplierFormDraft(nameAr: 'مورّد', email: 'bad');
      expect(draft.validate(), contains(SupplierException.emailInvalid));
    });

    test('toFormState trims and nulls blanks', () {
      const draft = SupplierFormDraft(nameAr: '  مورّد  ', phone: '');
      final state = draft.toFormState();
      expect(state.nameAr, 'مورّد');
      expect(state.phone, isNull);
    });
  });
}
