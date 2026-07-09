import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/utils/quantity_formatter.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../../finance_shared/presentation/money_display.dart';
import '../domain/inventory_document_detail.dart';
import 'inventory_document_detail_controller.dart';
import 'inventory_document_display_helpers.dart';
import 'widgets/inventory_document_shared_widgets.dart';

class InventoryDocumentDetailScreen extends ConsumerWidget {
  const InventoryDocumentDetailScreen({required this.documentId, super.key});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(
      inventoryDocumentDetailControllerProvider(documentId),
    );
    final controller = ref.read(
      inventoryDocumentDetailControllerProvider(documentId).notifier,
    );

    if (session != null && !canViewInventoryDocuments(session)) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => l.inventoryDocumentsTitle,
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: AppRoutes.inventoryDocumentDetailPath(documentId),
      );
    }

    Widget body;
    if (state.isLoading && state.detail == null) {
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
    } else if (state.errorCode != null && state.detail == null) {
      body = InventoryDocumentErrorState(
        message: inventoryDocumentErrorMessage(l10n, state.errorCode!),
        onRetry: controller.load,
      );
    } else if (state.detail == null) {
      body = Center(child: Text(l10n.financeErrorNotFound));
    } else {
      final detail = state.detail!;
      final summary = detail.summary;
      final isWide = MediaQuery.sizeOf(context).width > 768;

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.errorCode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MessageBanner(
                variant: MessageBannerVariant.error,
                message: inventoryDocumentErrorMessage(l10n, state.errorCode!),
              ),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                summary.documentNumber ?? '—',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              inventoryDocumentStatusChip(
                context,
                inventoryDocumentStatusLabel(l10n, summary.status),
                cancelled: detail.isCancelled,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(inventoryDocumentKindLabel(l10n, summary.kind)),
          const SizedBox(height: 4),
          Text(
            MaterialLocalizations.of(context).formatMediumDate(summary.date),
          ),
          if (detail.notes != null && detail.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(detail.notes!),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.inventoryDocumentLines,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _LinesSection(
            detail: detail,
            labels: state.productLabels,
            isWide: isWide,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.inventoryDocumentMovements,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (detail.movements.isEmpty)
            Text(l10n.inventoryMovementsEmpty)
          else
            ...detail.movements.map(
              (m) => ListTile(
                title: Text(state.productLabels[m.productId] ?? m.productId),
                subtitle: Text(formatQuantity(m.qty)),
                trailing: m.unitCost == null
                    ? null
                    : MoneyDisplay(amount: m.unitCost!),
              ),
            ),
          if (detail.journalEntryId != null &&
              session != null &&
              canViewJournal(session)) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/journal/${detail.journalEntryId}'),
              child: Text(l10n.inventoryDocumentJournalEntry),
            ),
          ],
          if (detail.reversalJournalEntryId != null &&
              session != null &&
              canViewJournal(session)) ...[
            TextButton(
              onPressed: () =>
                  context.go('/journal/${detail.reversalJournalEntryId}'),
              child: Text(l10n.inventoryDocumentReversalJournal),
            ),
          ],
          if (session != null && controller.canShowCancelButton(session))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton(
                onPressed: state.isSubmitting
                    ? null
                    : () => _showCancelDialog(context, controller, l10n),
                child: Text(l10n.inventoryDocumentCancelAction),
              ),
            ),
        ],
      );
    }

    return AppShell(
      title: l10n.inventoryDocumentsTitle,
      currentRoute: AppRoutes.inventoryDocumentDetailPath(documentId),
      body: Padding(padding: const EdgeInsetsDirectional.all(24), child: body),
    );
  }

  Future<void> _showCancelDialog(
    BuildContext context,
    InventoryDocumentDetailController controller,
    AppLocalizations l10n,
  ) async {
    final reasonController = TextEditingController();
    final material = MaterialLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.inventoryDocumentCancelAction),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: l10n.inventoryDocumentCancelReason,
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.inventoryDocumentCancelAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await controller.cancel(reasonController.text);
    reasonController.dispose();
  }
}

class _LinesSection extends ConsumerWidget {
  const _LinesSection({
    required this.detail,
    required this.labels,
    required this.isWide,
  });

  final InventoryDocumentDetail detail;
  final Map<String, String> labels;
  final bool isWide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (isWide) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text(l10n.inventoryMovementProduct)),
            DataColumn(label: Text(l10n.inventoryMovementQuantity)),
            DataColumn(label: Text(l10n.inventoryDocumentUnitCost)),
            DataColumn(label: Text(l10n.financeColumnTotal)),
          ],
          rows: [
            for (final line in detail.lines)
              DataRow(
                cells: [
                  DataCell(Text(labels[line.productId] ?? line.productId)),
                  DataCell(Text(formatQuantity(line.qty))),
                  DataCell(
                    line.unitCost == null
                        ? const Text('—')
                        : MoneyDisplay(amount: line.unitCost!),
                  ),
                  DataCell(
                    line.totalValue == null
                        ? const Text('—')
                        : MoneyDisplay(amount: line.totalValue!),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final line in detail.lines)
          Card(
            child: ListTile(
              title: Text(labels[line.productId] ?? line.productId),
              subtitle: Text(formatQuantity(line.qty)),
              trailing: line.totalValue == null
                  ? null
                  : MoneyDisplay(amount: line.totalValue!),
            ),
          ),
      ],
    );
  }
}
