import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/accounting_permissions.dart';
import '../domain/chart_account.dart';
import '../domain/chart_account_tree.dart';
import 'chart_account_display_helpers.dart';
import 'chart_account_error_messages.dart';
import '../domain/chart_account_form_state.dart';
import 'chart_account_list_controller.dart';
import 'chart_account_submit_result.dart';
import 'widgets/accounting_setup_banner.dart';
import 'widgets/chart_account_filters_bar.dart';
import 'widgets/chart_account_form_dialog.dart';
import 'widgets/chart_account_tree_view.dart';

class ChartOfAccountsScreen extends ConsumerWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = ref.watch(localeProvider).languageCode;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(chartAccountListControllerProvider);
    final controller = ref.read(chartAccountListControllerProvider.notifier);

    final canCreate =
        session != null && canCreateChartAccount(session);

    Widget body;
    if (state.isLoading && state.allAccounts.isEmpty) {
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
    } else if (state.hasError && state.allAccounts.isEmpty) {
      body = _ErrorState(
        message: chartAccountErrorMessage(l10n, state.errorCode!),
        onRetry: controller.refresh,
      );
    } else if (!state.isLoading && state.treeNodes.isEmpty) {
      body = Center(
        child: Text(
          state.filters.hasNonDefaultFilters
              ? l10n.chartAccountListEmptyFiltered
              : l10n.chartAccountListEmpty,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      );
    } else if (session != null) {
      body = ChartAccountTreeView(
        nodes: state.treeNodes,
        expandedIds: state.effectiveExpandedIds,
        languageCode: languageCode,
        session: session,
        onToggleExpanded: controller.toggleExpanded,
        onEdit: (node) => _showEditDialog(context, ref, node.account),
        onDeactivate: (node) => _confirmDeactivate(context, ref, node),
      );
    } else {
      body = const SizedBox.shrink();
    }

    return AppShell(
      key: const Key('chart-of-accounts-screen'),
      title: l10n.chartOfAccounts,
      currentRoute: AppRoutes.accounts,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountingSetupBanner(issues: state.setupIssues),
          Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ChartAccountFiltersBar(
                    filters: state.filters,
                    onSearchSubmitted: controller.setSearch,
                    onTypeChanged: controller.setType,
                    onActiveChanged: controller.setIsActive,
                    onClear: controller.clearFilters,
                  ),
                ),
                if (canCreate) ...[
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    key: const Key('chart-account-create-button'),
                    onPressed: () => _showCreateDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.chartAccountAdd),
                  ),
                ],
              ],
            ),
          ),
          if (state.treeNodes.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: controller.expandAll,
                    icon: const Icon(Icons.unfold_more, size: 18),
                    label: Text(l10n.chartAccountExpandAll),
                  ),
                  TextButton.icon(
                    onPressed: controller.collapseAll,
                    icon: const Icon(Icons.unfold_less, size: 18),
                    label: Text(l10n.chartAccountCollapseAll),
                  ),
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
                if (state.isLoading && state.allAccounts.isNotEmpty)
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
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.read(chartAccountListControllerProvider);
    final controller = ref.read(chartAccountListControllerProvider.notifier);

    final result = await showChartAccountFormDialog(
      context: context,
      title: l10n.chartAccountCreateTitle,
      submitLabel: MaterialLocalizations.of(context).saveButtonLabel,
      parentOptions: allEligibleParentOptions(state.allAccounts),
      onSubmit: controller.submitCreate,
    );

    if (result is ChartAccountSubmitSuccess && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chartAccountCreated)),
      );
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    ChartAccount account,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(chartAccountListControllerProvider.notifier);

    final result = await showChartAccountFormDialog(
      context: context,
      title: l10n.chartAccountEditTitle,
      submitLabel: MaterialLocalizations.of(context).saveButtonLabel,
      initialAccount: account,
      onSubmit: (ChartAccountFormState formState) =>
          controller.submitUpdate(account.id, formState),
    );

    if (result is ChartAccountSubmitSuccess && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chartAccountUpdated)),
      );
    }
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    WidgetRef ref,
    ChartAccountTreeNode node,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chartAccountDeactivateConfirmTitle),
        content: Text(l10n.chartAccountDeactivateConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.chartAccountDeactivate),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final errorCode = await ref
        .read(chartAccountListControllerProvider.notifier)
        .deactivateAccount(node.account.id);

    if (!context.mounted) return;
    if (errorCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chartAccountDeactivated)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chartAccountErrorMessage(l10n, errorCode))),
      );
    }
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
