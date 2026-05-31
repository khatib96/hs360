import '../../core/errors/accounting_exception.dart';
import '../../features/accounting/domain/account_type.dart';
import '../../features/accounting/domain/chart_account_form_state.dart';
import 'validation_result.dart';

class ChartAccountValidator {
  const ChartAccountValidator();

  ValidationResult validateCreate(
    ChartAccountFormState input, {
    AccountType? parentType,
  }) {
    final codes = <String>[];

    if (input.code == null || input.code!.trim().isEmpty) {
      codes.add(AccountingException.codeRequired);
    }
    if (input.nameAr.trim().isEmpty) {
      codes.add(AccountingException.nameArRequired);
    }
    if (input.nameEn.trim().isEmpty) {
      codes.add(AccountingException.nameEnRequired);
    }

    _validateParentType(input.parentId, parentType, input.type, codes);

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }

  ValidationResult validateUpdate(
    ChartAccountFormState input, {
    AccountType? currentType,
    String? currentParentId,
    AccountType? parentType,
  }) {
    final codes = <String>[];

    if (input.nameAr.trim().isEmpty) {
      codes.add(AccountingException.nameArRequired);
    }
    if (input.nameEn.trim().isEmpty) {
      codes.add(AccountingException.nameEnRequired);
    }

    final typeChanged = currentType != null && input.type != currentType;
    if (typeChanged && currentParentId != null) {
      _validateParentType(currentParentId, parentType, input.type, codes);
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }

  void _validateParentType(
    String? parentId,
    AccountType? parentType,
    AccountType childType,
    List<String> codes,
  ) {
    if (parentId == null) return;
    if (parentType == null) {
      codes.add(AccountingException.parentTypeMismatch);
      return;
    }
    if (parentType != childType) {
      codes.add(AccountingException.parentTypeMismatch);
    }
  }
}
