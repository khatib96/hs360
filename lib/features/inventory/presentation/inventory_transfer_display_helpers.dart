import 'package:decimal/decimal.dart';

import '../../../domain/services/stock_engine.dart';
import '../domain/movement_type.dart';
import '../domain/transfer_product_option.dart';
import '../domain/transfer_warehouse_option.dart';

String localizedTransferWarehouseName(
  TransferWarehouseOption warehouse,
  String languageCode,
) {
  if (languageCode.toLowerCase() == 'ar') {
    return warehouse.nameAr;
  }
  return warehouse.nameEn;
}

String localizedTransferProductName(
  TransferProductOption product,
  String languageCode,
) {
  if (languageCode.toLowerCase() == 'ar') {
    return product.nameAr;
  }
  return product.nameEn;
}

String formatTransferSourceDelta(Decimal qty) {
  return formatSignedTransferDelta(
    const StockEngine().previewAdjustmentDelta(MovementType.transferOut, qty),
  );
}

String formatTransferDestinationDelta(Decimal qty) {
  return formatSignedTransferDelta(
    const StockEngine().previewAdjustmentDelta(MovementType.transferIn, qty),
  );
}

String formatSignedTransferDelta(Decimal delta) {
  if (delta >= Decimal.zero) {
    return '+$delta';
  }
  return delta.toString();
}
