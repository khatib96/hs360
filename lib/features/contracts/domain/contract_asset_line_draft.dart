/// Editable asset line for contract creation payloads.
class ContractAssetLineDraft {
  const ContractAssetLineDraft({
    required this.productId,
    required this.productUnitId,
  });

  final String productId;
  final String productUnitId;

  Map<String, dynamic> toPayload() {
    return {'product_id': productId, 'product_unit_id': productUnitId};
  }
}
