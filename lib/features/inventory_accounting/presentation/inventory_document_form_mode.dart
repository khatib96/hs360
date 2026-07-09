enum InventoryDocumentFormMode { openingStock, stockIn, stockOut, stockCount }

extension InventoryDocumentFormModeX on InventoryDocumentFormMode {
  bool get blocksSerialized =>
      this == InventoryDocumentFormMode.openingStock ||
      this == InventoryDocumentFormMode.stockCount;

  bool get supportsSerialized =>
      this == InventoryDocumentFormMode.stockIn ||
      this == InventoryDocumentFormMode.stockOut;
}
