import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/products/domain/asset_label_document_mapper.dart';

void main() {
  test('maps product unit fields to label payload', () {
    final payload = mapProductUnitToLabelPayload(
      serial: 'SN-001',
      barcode: '1234567890',
      status: 'available',
      productNameAr: 'منتج',
      productNameEn: 'Product',
      productSku: 'SKU-1',
      companyNameAr: 'شركة',
      companyNameEn: 'Company',
    );

    expect(payload.unit['serial'], 'SN-001');
    expect(payload.product['sku'], 'SKU-1');
    expect(payload.tenant['company_name_ar'], 'شركة');
  });
}
