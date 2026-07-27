import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/domain/app_session.dart';
import '../../calendar/domain/calendar_permissions.dart';
import '../../contracts/domain/contract_permissions.dart';
import '../../customers/domain/customer_permissions.dart';
import '../../customers/presentation/widgets/customer_form_dialog.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import '../../inventory/domain/inventory_permissions.dart';
import '../../inventory/domain/warehouse_permissions.dart';
import '../../inventory/presentation/inventory_error_messages.dart';
import '../../inventory/presentation/warehouses_controller.dart';
import '../../inventory/presentation/widgets/warehouse_form_dialog.dart';
import '../../products/domain/product_permissions.dart';
import '../../suppliers/domain/supplier_permissions.dart';
import '../../suppliers/presentation/widgets/supplier_form_dialog.dart';

Future<void> showQuickCreateDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AppSession session,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _QuickCreateDialog(
      session: session,
      onSelected: (action) async {
        Navigator.of(context, rootNavigator: true).pop();
        await Future<void>.delayed(Duration.zero);
        if (!context.mounted) return;
        await _runQuickCreateAction(context, ref, action);
      },
    ),
  );
}

enum _QuickCreateAction {
  customer,
  supplier,
  product,
  warehouse,
  salesInvoice,
  purchaseInvoice,
  salesReturn,
  purchaseReturn,
  receiptVoucher,
  paymentVoucher,
  contract,
  calendarEvent,
  inventoryTransfer,
  openingStock,
  stockIn,
  stockOut,
  stockCount,
}

class _QuickCreateItem {
  const _QuickCreateItem(this.action, this.label, this.icon);

  final _QuickCreateAction action;
  final String label;
  final IconData icon;
}

class _QuickCreateDialog extends StatelessWidget {
  const _QuickCreateDialog({required this.session, required this.onSelected});

  final AppSession session;
  final ValueChanged<_QuickCreateAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = <_QuickCreateItem>[
      if (canCreateCustomer(session))
        _QuickCreateItem(
          _QuickCreateAction.customer,
          l10n.quickCreateCustomer,
          Icons.person_add_alt_1_outlined,
        ),
      if (canCreateSupplier(session))
        _QuickCreateItem(
          _QuickCreateAction.supplier,
          l10n.quickCreateSupplier,
          Icons.local_shipping_outlined,
        ),
      if (canCreateProduct(session))
        _QuickCreateItem(
          _QuickCreateAction.product,
          l10n.quickCreateProduct,
          Icons.inventory_2_outlined,
        ),
      if (canCreateWarehouse(session))
        _QuickCreateItem(
          _QuickCreateAction.warehouse,
          l10n.quickCreateWarehouse,
          Icons.warehouse_outlined,
        ),
      if (canCreateSalesInvoice(session))
        _QuickCreateItem(
          _QuickCreateAction.salesInvoice,
          l10n.quickCreateSalesInvoice,
          Icons.receipt_long_outlined,
        ),
      if (canCreatePurchaseInvoice(session))
        _QuickCreateItem(
          _QuickCreateAction.purchaseInvoice,
          l10n.quickCreatePurchaseInvoice,
          Icons.shopping_cart_outlined,
        ),
      if (canCreateSalesReturn(session))
        _QuickCreateItem(
          _QuickCreateAction.salesReturn,
          l10n.quickCreateSalesReturn,
          Icons.keyboard_return,
        ),
      if (canCreatePurchaseReturn(session))
        _QuickCreateItem(
          _QuickCreateAction.purchaseReturn,
          l10n.quickCreatePurchaseReturn,
          Icons.assignment_return_outlined,
        ),
      if (canCreateReceiptVoucher(session))
        _QuickCreateItem(
          _QuickCreateAction.receiptVoucher,
          l10n.quickCreateReceiptVoucher,
          Icons.south_west,
        ),
      if (canCreatePaymentVoucher(session))
        _QuickCreateItem(
          _QuickCreateAction.paymentVoucher,
          l10n.quickCreatePaymentVoucher,
          Icons.north_east,
        ),
      if (canCreateContract(session))
        _QuickCreateItem(
          _QuickCreateAction.contract,
          l10n.quickCreateContract,
          Icons.description_outlined,
        ),
      if (canCreateCalendarEvent(session))
        _QuickCreateItem(
          _QuickCreateAction.calendarEvent,
          l10n.quickCreateCalendarEvent,
          Icons.event_outlined,
        ),
      if (canCreateInventoryMovements(session))
        _QuickCreateItem(
          _QuickCreateAction.inventoryTransfer,
          l10n.quickCreateInventoryTransfer,
          Icons.swap_horiz,
        ),
      if (canCreateOpeningStock(session))
        _QuickCreateItem(
          _QuickCreateAction.openingStock,
          l10n.quickCreateOpeningStock,
          Icons.inventory_outlined,
        ),
      if (canCreateInventoryAdjustment(session)) ...[
        _QuickCreateItem(
          _QuickCreateAction.stockIn,
          l10n.inventoryDocumentCreateStockIn,
          Icons.add_box_outlined,
        ),
        _QuickCreateItem(
          _QuickCreateAction.stockOut,
          l10n.inventoryDocumentCreateStockOut,
          Icons.indeterminate_check_box_outlined,
        ),
      ],
      if (canCreateStockCount(session))
        _QuickCreateItem(
          _QuickCreateAction.stockCount,
          l10n.quickCreateStockCount,
          Icons.fact_check_outlined,
        ),
    ];

    final narrow = MediaQuery.sizeOf(context).width < 600;
    return AlertDialog(
      title: Text(l10n.quickCreateTitle),
      content: SizedBox(
        width: narrow ? double.maxFinite : 600,
        child: GridView.builder(
          key: const Key('quick-create-grid'),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: narrow ? 1 : 2,
            childAspectRatio: narrow ? 5.2 : 4.2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: Key('quick-create-${item.action.name}'),
                onTap: () => onSelected(item.action),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(item.icon),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item.label)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}

Future<void> _runQuickCreateAction(
  BuildContext context,
  WidgetRef ref,
  _QuickCreateAction action,
) async {
  switch (action) {
    case _QuickCreateAction.customer:
      await showDialog<void>(
        context: context,
        builder: (_) => const CustomerFormDialog(),
      );
      return;
    case _QuickCreateAction.supplier:
      await showDialog<void>(
        context: context,
        builder: (_) => const SupplierFormDialog(),
      );
      return;
    case _QuickCreateAction.warehouse:
      await _showWarehouseCreate(context, ref);
      return;
    case _QuickCreateAction.product:
      context.go(AppRoutes.productsNew);
      return;
    case _QuickCreateAction.salesInvoice:
      context.go(AppRoutes.invoicesNewSales);
      return;
    case _QuickCreateAction.purchaseInvoice:
      context.go(AppRoutes.invoicesNewPurchase);
      return;
    case _QuickCreateAction.salesReturn:
      context.go(AppRoutes.invoicesNewSalesReturn);
      return;
    case _QuickCreateAction.purchaseReturn:
      context.go(AppRoutes.invoicesNewPurchaseReturn);
      return;
    case _QuickCreateAction.receiptVoucher:
      context.go(AppRoutes.vouchersNewReceipt);
      return;
    case _QuickCreateAction.paymentVoucher:
      context.go(AppRoutes.vouchersNewPayment);
      return;
    case _QuickCreateAction.contract:
      context.go(AppRoutes.contractsNew);
      return;
    case _QuickCreateAction.calendarEvent:
      context.go('${AppRoutes.calendar}?create=1');
      return;
    case _QuickCreateAction.inventoryTransfer:
      context.go(AppRoutes.inventoryTransfers);
      return;
    case _QuickCreateAction.openingStock:
      context.go(AppRoutes.inventoryDocumentsOpeningStock);
      return;
    case _QuickCreateAction.stockIn:
      context.go(AppRoutes.inventoryDocumentsStockIn);
      return;
    case _QuickCreateAction.stockOut:
      context.go(AppRoutes.inventoryDocumentsStockOut);
      return;
    case _QuickCreateAction.stockCount:
      context.go(AppRoutes.inventoryDocumentsStockCount);
      return;
  }
}

Future<void> _showWarehouseCreate(BuildContext context, WidgetRef ref) async {
  final state = ref.read(warehousesControllerProvider);
  final languageCode = ref.read(localeProvider).languageCode;
  final result = await showDialog(
    context: context,
    builder: (_) => WarehouseFormDialog(
      languageCode: languageCode,
      employees: state.employees,
      warehouses: state.warehouses,
    ),
  );
  if (result == null || !context.mounted) return;
  final errorCode = await ref
      .read(warehousesControllerProvider.notifier)
      .createWarehouse(result);
  if (errorCode != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          warehouseErrorMessage(AppLocalizations.of(context)!, errorCode),
        ),
      ),
    );
  }
}
