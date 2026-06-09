import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/products_exception.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/inventory_permissions.dart';
import '../domain/warehouse.dart';
import '../domain/warehouse_form_state.dart';
import '../domain/warehouse_permissions.dart';
import 'inventory_error_messages.dart';
import 'warehouses_controller.dart';
import 'warehouses_state.dart';
import 'widgets/warehouse_form_dialog.dart';
import 'widgets/warehouse_table.dart';

class WarehousesScreen extends ConsumerWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final languageCode = locale.languageCode;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(warehousesControllerProvider);
    final controller = ref.read(warehousesControllerProvider.notifier);

    final canCreate = session != null && canCreateWarehouse(session);
    final canEdit = session != null && canEditWarehouse(session);
    final canViewStock = session != null && canViewInventoryBalances(session);

    Widget body;
    if (state.isLoading && state.warehouses.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.loading),
          ],
        ),
      );
    } else if (state.hasError && state.warehouses.isEmpty) {
      body = _WarehousesErrorState(
        message: _errorMessage(l10n, state.errorCode),
        onRetry: controller.refresh,
      );
    } else if (!state.isLoading && state.warehouses.isEmpty) {
      body = _WarehousesEmptyState(canCreate: canCreate);
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.hasEmployeeLookupWarning) ...[
            MessageBanner(
              variant: MessageBannerVariant.info,
              message: warehouseEmployeeLookupErrorMessage(
                l10n,
                state.employeeLookupErrorCode!,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: controller.refresh,
                child: Text(l10n.warehouseEmployeeLookupRetry),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: WarehouseTable(
              warehouses: state.warehouses,
              languageCode: languageCode,
              employeesById: state.employeesById,
              inactiveEmployeeHint: l10n.warehouseEmployeeInactiveHint,
              canEdit: canEdit,
              canViewStock: canViewStock,
              onViewStock: (warehouse) => context.go(
                '${AppRoutes.inventory}?warehouseId=${Uri.encodeComponent(warehouse.id)}',
              ),
              onEdit: (warehouse) => _showFormDialog(
                context,
                ref,
                languageCode,
                state: state,
                initial: warehouse,
              ),
              onDeactivate: (warehouse) =>
                  _confirmDeactivate(context, ref, warehouse),
            ),
          ),
        ],
      );
    }

    return AppShell(
      title: l10n.warehouses,
      currentRoute: AppRoutes.warehouses,
      actions: [
        if (canCreate)
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.warehouseAdd,
            onPressed: () =>
                _showFormDialog(context, ref, languageCode, state: state),
          ),
      ],
      body: SizedBox.expand(
        child: Stack(
          children: [
            Padding(padding: const EdgeInsetsDirectional.all(24), child: body),
            if (state.isLoading && state.warehouses.isNotEmpty)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }

  String _errorMessage(AppLocalizations l10n, String? code) {
    if (code == ProductsException.supabaseNotConfigured) {
      return l10n.authErrorSupabaseNotConfigured;
    }
    if (code != null) return warehouseErrorMessage(l10n, code);
    return l10n.warehouseListError;
  }

  Future<void> _showFormDialog(
    BuildContext context,
    WidgetRef ref,
    String languageCode, {
    required WarehousesState state,
    Warehouse? initial,
  }) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;

    final isCreate = initial == null;
    if (isCreate && !canCreateWarehouse(session)) return;
    if (!isCreate && !canEditWarehouse(session)) return;

    final result = await showDialog<WarehouseFormState>(
      context: context,
      builder: (context) => WarehouseFormDialog(
        languageCode: languageCode,
        employees: state.employees,
        warehouses: state.warehouses,
        initial: initial,
      ),
    );

    if (result == null || !context.mounted) return;

    final controller = ref.read(warehousesControllerProvider.notifier);
    final errorCode = initial == null
        ? await controller.createWarehouse(result)
        : await controller.updateWarehouse(initial.id, result);

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

  Future<void> _confirmDeactivate(
    BuildContext context,
    WidgetRef ref,
    Warehouse warehouse,
  ) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canDeactivateWarehouse(session)) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.warehouseDeactivate),
        content: Text(l10n.warehouseDeactivateConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.warehouseDeactivate),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final errorCode = await ref
        .read(warehousesControllerProvider.notifier)
        .deactivateWarehouse(warehouse.id);

    if (errorCode != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(warehouseErrorMessage(l10n, errorCode))),
      );
    }
  }
}

class _WarehousesEmptyState extends StatelessWidget {
  const _WarehousesEmptyState({required this.canCreate});

  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warehouse_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(l10n.warehouseListEmpty),
          if (canCreate) ...[
            const SizedBox(height: 8),
            Text(
              l10n.warehouseAdd,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _WarehousesErrorState extends StatelessWidget {
  const _WarehousesErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}
