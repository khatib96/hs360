import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../domain/inventory_document_permissions.dart';
import 'inventory_document_form_controller.dart';
import 'inventory_document_form_mode.dart';
import 'widgets/inventory_document_line_editor.dart';
import 'widgets/inventory_document_shared_widgets.dart';

class InventoryDocumentFormScreen extends ConsumerWidget {
  const InventoryDocumentFormScreen({required this.mode, super.key});

  final InventoryDocumentFormMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(inventoryDocumentFormControllerProvider(mode));
    final controller = ref.read(
      inventoryDocumentFormControllerProvider(mode).notifier,
    );

    final canAccess = switch (mode) {
      InventoryDocumentFormMode.openingStock =>
        session != null && canCreateOpeningStock(session),
      InventoryDocumentFormMode.stockIn || InventoryDocumentFormMode.stockOut =>
        session != null && canCreateInventoryAdjustment(session),
      InventoryDocumentFormMode.stockCount =>
        session != null && canCreateStockCount(session),
    };

    if (!canAccess) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => _title(l),
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: _route,
        showBackButton: true,
        fallbackRoute: AppRoutes.inventoryDocuments,
      );
    }

    return AppShell(
      title: _title(l10n),
      currentRoute: _route,
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.errorCode != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MessageBanner(
                  variant: MessageBannerVariant.error,
                  message: inventoryDocumentErrorMessage(
                    l10n,
                    state.errorCode!,
                  ),
                ),
              ),
            if (state.hasValidationErrors)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MessageBanner(
                  variant: MessageBannerVariant.error,
                  message: inventoryDocumentValidationMessages(
                    l10n,
                    state.validationCodes,
                  ),
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: state.warehouseId,
              decoration: InputDecoration(
                labelText: l10n.inventoryDocumentWarehouse,
              ),
              items: state.warehouses
                  .map(
                    (w) => DropdownMenuItem(
                      value: w.id,
                      child: Text(
                        locale.languageCode == 'ar' ? w.nameAr : w.nameEn,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: controller.setWarehouseId,
            ),
            const SizedBox(height: 12),
            _DatePickerField(
              label: l10n.inventoryDocumentDate,
              value: state.date,
              onChanged: controller.setDate,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: state.notes,
              decoration: InputDecoration(
                labelText: l10n.inventoryDocumentNotes,
              ),
              maxLines: 2,
              onChanged: controller.setNotes,
            ),
            const SizedBox(height: 16),
            InventoryDocumentReasonFields(mode: mode),
            const SizedBox(height: 16),
            for (var i = 0; i < state.lines.length; i++)
              InventoryDocumentLineEditor(
                mode: mode,
                lineIndex: i,
                line: state.lines[i],
                languageCode: locale.languageCode,
                canRemove: state.lines.length > 1,
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: controller.addLine,
                child: Text(l10n.inventoryDocumentAddLine),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: state.isSubmitting
                  ? null
                  : () => _confirmAndSubmit(context, controller, l10n),
              child: state.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.inventoryDocumentSubmit),
            ),
          ],
        ),
      ),
    );
  }

  String _title(AppLocalizations l10n) => switch (mode) {
    InventoryDocumentFormMode.openingStock =>
      l10n.inventoryDocumentOpeningStock,
    InventoryDocumentFormMode.stockIn => l10n.inventoryDocumentStockIn,
    InventoryDocumentFormMode.stockOut => l10n.inventoryDocumentStockOut,
    InventoryDocumentFormMode.stockCount => l10n.inventoryDocumentStockCount,
  };

  String get _route => switch (mode) {
    InventoryDocumentFormMode.openingStock =>
      AppRoutes.inventoryDocumentsOpeningStock,
    InventoryDocumentFormMode.stockIn => AppRoutes.inventoryDocumentsStockIn,
    InventoryDocumentFormMode.stockOut => AppRoutes.inventoryDocumentsStockOut,
    InventoryDocumentFormMode.stockCount =>
      AppRoutes.inventoryDocumentsStockCount,
  };

  Future<void> _confirmAndSubmit(
    BuildContext context,
    InventoryDocumentFormController controller,
    AppLocalizations l10n,
  ) async {
    final material = MaterialLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.inventoryDocumentConfirmSubmit),
        content: Text(l10n.inventoryDocumentConfirmSubmitMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.inventoryDocumentConfirmSubmit),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await controller.submit();
    if (!context.mounted || result == null) return;
    if (result.contains('-') && result.length >= 32) {
      context.go(AppRoutes.inventoryDocumentDetailPath(result));
    }
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      controller: TextEditingController(
        text: MaterialLocalizations.of(context).formatMediumDate(value),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
