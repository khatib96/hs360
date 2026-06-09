import '../../../core/documents/domain/document_payload.dart';

AssetLabelPayload mapProductUnitToLabelPayload({
  required String serial,
  String? barcode,
  required String status,
  required String productNameAr,
  required String productNameEn,
  required String productSku,
  required String companyNameAr,
  required String companyNameEn,
}) {
  return AssetLabelPayload(
    unit: {'serial': serial, 'barcode': barcode, 'status': status},
    product: {
      'name_ar': productNameAr,
      'name_en': productNameEn,
      'sku': productSku,
    },
    tenant: {
      'company_name_ar': companyNameAr,
      'company_name_en': companyNameEn,
    },
  );
}
