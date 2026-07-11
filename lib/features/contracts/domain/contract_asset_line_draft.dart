/// Editable asset line for contract creation payloads.
class ContractAssetLineDraft {
  const ContractAssetLineDraft({required this.productId, this.productUnitId});

  final String productId;
  final String? productUnitId;

  Map<String, dynamic> toPayload() {
    return {
      'product_id': productId,
      if (productUnitId?.trim().isNotEmpty == true)
        'product_unit_id': productUnitId,
    };
  }
}
