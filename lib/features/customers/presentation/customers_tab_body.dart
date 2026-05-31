import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/customer.dart';
import '../domain/customer_permissions.dart';
import 'customer_error_messages.dart';
import 'customer_list_controller.dart';
import 'widgets/customer_filters_bar.dart';
import 'widgets/customer_form_dialog.dart';
import 'widgets/customer_list_empty_state.dart';
import 'widgets/customer_table.dart';

/// Customers tab content: filters, create action, list/loading/error/empty.
class CustomersTabBody extends ConsumerWidget {
  const CustomersTabBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = ref.watch(localeProvider).languageCode;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(customerListControllerProvider);
    final controller = ref.read(customerListControllerProvider.notifier);

    final canCreate = session != null && canCreateCustomer(session);
    final canEdit = session != null && canEditCustomer(session);
    final canDeactivate = session != null && canDeactivateCustomer(session);

    Widget body;
    if (state.isLoading && state.customers.isEmpty) {
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
    } else if (state.hasError && state.customers.isEmpty) {
      body = _ErrorState(
        message: customerErrorMessage(l10n, state.errorCode!),
        onRetry: controller.refresh,
      );
    } else if (!state.isLoading && state.customers.isEmpty) {
      body = CustomerListEmptyState(
        isFiltered: state.filters.hasNonDefaultFilters,
        canCreate: canCreate,
      );
    } else {
      body = CustomerTable(
        customers: state.customers,
        languageCode: languageCode,
        canEdit: canEdit,
        canDeactivate: canDeactivate,
        onView: (customer) =>
            context.go(AppRoutes.customerDetailPath(customer.id)),
        onEdit: (customer) => _showFormDialog(context, ref, initial: customer),
        onDeactivate: (customer) => _confirmDeactivate(context, ref, customer),
      );
    }

    return Column(
      key: const Key('customers-tab-body'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Row(
            children: [
              Expanded(
                child: CustomerFiltersBar(
                  filters: state.filters,
                  onSearchSubmitted: controller.setSearch,
                  onActiveChanged: controller.setIsActive,
                  onVipChanged: controller.setIsVip,
                  onTypeChanged: controller.setCustomerType,
                  onAreaSubmitted: controller.setArea,
                  onCitySubmitted: controller.setCity,
                  onClear: controller.clearFilters,
                ),
              ),
              if (canCreate) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  key: const Key('customer-create-button'),
                  onPressed: () => _showFormDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.customerAdd),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
                child: body,
              ),
              if (state.isLoading && state.customers.isNotEmpty)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _showFormDialog(
    BuildContext context,
    WidgetRef ref, {
    Customer? initial,
  }) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;
    final isCreate = initial == null;
    if (isCreate && !canCreateCustomer(session)) return;
    if (!isCreate && !canEditCustomer(session)) return;

    await showDialog<void>(
      context: context,
      builder: (_) => CustomerFormDialog(initial: initial),
    );
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canDeactivateCustomer(session)) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.customerDeactivateConfirmTitle),
        content: Text(l10n.customerDeactivateConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.customerActionDeactivate),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final errorCode = await ref
        .read(customerListControllerProvider.notifier)
        .deactivateCustomer(customer.id);

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final messageL10n = AppLocalizations.of(context)!;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          errorCode == null
              ? messageL10n.customerDeactivated
              : customerErrorMessage(messageL10n, errorCode),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
