import 'account_type.dart';

/// Full create/edit chart account form. Repository maps to M2 RPC payloads.
class ChartAccountFormState {
  const ChartAccountFormState({
    this.code,
    required this.nameAr,
    required this.nameEn,
    required this.type,
    this.parentId,
  });

  final String? code;
  final String nameAr;
  final String nameEn;
  final AccountType type;
  final String? parentId;

  Map<String, dynamic> toCreatePayload() {
    return {
      'code': code!.trim(),
      'name_ar': nameAr.trim(),
      'name_en': nameEn.trim(),
      'type': type.toDb(),
      if (parentId != null) 'parent_id': parentId,
    };
  }

  Map<String, dynamic> toUpdatePayload() {
    return {
      'name_ar': nameAr.trim(),
      'name_en': nameEn.trim(),
      'type': type.toDb(),
    };
  }
}
