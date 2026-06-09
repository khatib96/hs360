import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/accounting_exception.dart';
import 'package:hs360/domain/validators/chart_account_validator.dart';
import 'package:hs360/features/accounting/domain/account_type.dart';
import 'package:hs360/features/accounting/domain/chart_account_form_state.dart';

void main() {
  const validator = ChartAccountValidator();

  group('validateCreate', () {
    test('valid create returns no codes', () {
      const form = ChartAccountFormState(
        code: '3101',
        nameAr: 'مصروف',
        nameEn: 'Expense',
        type: AccountType.expense,
      );
      expect(validator.validateCreate(form).isValid, isTrue);
    });

    test('code_required when code empty', () {
      const form = ChartAccountFormState(
        code: '',
        nameAr: 'مصروف',
        nameEn: 'Expense',
        type: AccountType.expense,
      );
      expect(
        validator.validateCreate(form).codes,
        contains(AccountingException.codeRequired),
      );
    });

    test('parent_type_mismatch on create', () {
      const form = ChartAccountFormState(
        code: '3102',
        nameAr: 'مصروف',
        nameEn: 'Expense',
        type: AccountType.expense,
        parentId: 'parent-1',
      );
      expect(
        validator.validateCreate(form, parentType: AccountType.asset).codes,
        contains(AccountingException.parentTypeMismatch),
      );
    });
  });

  group('validateUpdate', () {
    test('valid update returns no codes', () {
      const form = ChartAccountFormState(
        nameAr: 'مصروف',
        nameEn: 'Expense',
        type: AccountType.expense,
      );
      expect(validator.validateUpdate(form).isValid, isTrue);
    });

    test('parent_type_mismatch when type changes under parent', () {
      const form = ChartAccountFormState(
        nameAr: 'مصروف',
        nameEn: 'Expense',
        type: AccountType.income,
      );
      expect(
        validator
            .validateUpdate(
              form,
              currentType: AccountType.expense,
              currentParentId: 'parent-1',
              parentType: AccountType.expense,
            )
            .codes,
        contains(AccountingException.parentTypeMismatch),
      );
    });

    test('type change allowed when parent types match', () {
      const form = ChartAccountFormState(
        nameAr: 'مصروف',
        nameEn: 'Expense',
        type: AccountType.expense,
      );
      expect(
        validator
            .validateUpdate(
              form,
              currentType: AccountType.income,
              currentParentId: 'parent-1',
              parentType: AccountType.expense,
            )
            .isValid,
        isTrue,
      );
    });
  });
}
