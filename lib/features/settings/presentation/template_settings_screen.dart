import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/documents/domain/document_kind.dart';
import '../../../core/documents/presentation/document_error_messages.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import 'template_settings_controller.dart';
import 'template_settings_state.dart';

class TemplateSettingsScreen extends ConsumerStatefulWidget {
  const TemplateSettingsScreen({super.key});

  @override
  ConsumerState<TemplateSettingsScreen> createState() =>
      _TemplateSettingsScreenState();
}

class _TemplateSettingsScreenState
    extends ConsumerState<TemplateSettingsScreen> {
  late final TextEditingController _logoUrl;
  late final TextEditingController _primaryColor;
  late final TextEditingController _secondaryColor;
  late final TextEditingController _headerAr;
  late final TextEditingController _headerEn;
  late final TextEditingController _footerAr;
  late final TextEditingController _footerEn;

  @override
  void initState() {
    super.initState();
    _logoUrl = TextEditingController();
    _primaryColor = TextEditingController();
    _secondaryColor = TextEditingController();
    _headerAr = TextEditingController();
    _headerEn = TextEditingController();
    _footerAr = TextEditingController();
    _footerEn = TextEditingController();

    ref.listenManual(templateSettingsControllerProvider, (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncController(_logoUrl, next.logoUrl);
        _syncController(_primaryColor, next.primaryColor);
        _syncController(_secondaryColor, next.secondaryColor);
        _syncController(_headerAr, next.headerTextAr);
        _syncController(_headerEn, next.headerTextEn);
        _syncController(_footerAr, next.footerTextAr);
        _syncController(_footerEn, next.footerTextEn);
      });
    });
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.value = controller.value.copyWith(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
        composing: TextRange.empty,
      );
    }
  }

  @override
  void dispose() {
    _logoUrl.dispose();
    _primaryColor.dispose();
    _secondaryColor.dispose();
    _headerAr.dispose();
    _headerEn.dispose();
    _footerAr.dispose();
    _footerEn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(templateSettingsControllerProvider);
    final notifier = ref.read(templateSettingsControllerProvider.notifier);

    return AppShell(
      title: l10n.templateSettingsTitle,
      currentRoute: AppRoutes.templateSettings,
      body: _buildBody(context, l10n, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    TemplateSettingsState state,
    TemplateSettingsController notifier,
  ) {
    if (state.permissionDenied) {
      return Center(
        child: MessageBanner(
          variant: MessageBannerVariant.info,
          message: l10n.templateSettingsPermissionDenied,
        ),
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorCode != null) {
      return Center(
        child: MessageBanner(
          variant: MessageBannerVariant.error,
          message: documentErrorMessage(l10n, state.errorCode!),
        ),
      );
    }

    return ListView(
      key: const Key('template-settings-list'),
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        TextField(
          key: const Key('template-settings-logo-url'),
          enabled: state.canEdit,
          decoration: InputDecoration(labelText: l10n.templateSettingsLogoUrl),
          controller: _logoUrl,
          onChanged: notifier.updateLogoUrl,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('template-settings-primary-color'),
          enabled: state.canEdit,
          decoration: InputDecoration(
            labelText: l10n.templateSettingsPrimaryColor,
          ),
          controller: _primaryColor,
          onChanged: notifier.updatePrimaryColor,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('template-settings-secondary-color'),
          enabled: state.canEdit,
          decoration: InputDecoration(
            labelText: l10n.templateSettingsSecondaryColor,
          ),
          controller: _secondaryColor,
          onChanged: notifier.updateSecondaryColor,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<DocumentLanguageMode>(
          key: const Key('template-settings-default-language'),
          initialValue: state.defaultLanguage,
          decoration: InputDecoration(
            labelText: l10n.templateSettingsDefaultLanguage,
          ),
          items: DocumentLanguageMode.values
              .map(
                (mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(_languageLabel(l10n, mode)),
                ),
              )
              .toList(),
          onChanged: state.canEdit
              ? (value) {
                  if (value != null) notifier.updateDefaultLanguage(value);
                }
              : null,
        ),
        const SizedBox(height: 12),
        InputDecorator(
          key: const Key('template-settings-invoice-paper'),
          decoration: InputDecoration(
            labelText: l10n.templateSettingsInvoicePaper,
          ),
          child: Text(_paperLabel(l10n, state.invoicePaperKind)),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<PaperKind>(
          key: const Key('template-settings-voucher-paper'),
          initialValue: state.voucherPaperKind,
          decoration: InputDecoration(
            labelText: l10n.templateSettingsVoucherPaper,
          ),
          items: const [PaperKind.a4, PaperKind.thermal80mm]
              .map(
                (kind) => DropdownMenuItem(
                  value: kind,
                  child: Text(_paperLabel(l10n, kind)),
                ),
              )
              .toList(),
          onChanged: state.canEdit
              ? (value) {
                  if (value != null) notifier.updateVoucherPaperKind(value);
                }
              : null,
        ),
        const SizedBox(height: 12),
        InputDecorator(
          key: const Key('template-settings-asset-label-paper'),
          decoration: InputDecoration(
            labelText: l10n.templateSettingsAssetLabelPaper,
          ),
          child: Text(_paperLabel(l10n, state.assetLabelPaperKind)),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.templateSettingsHeaderSection,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('template-settings-header-ar'),
          enabled: state.canEdit,
          decoration: InputDecoration(labelText: l10n.templateSettingsHeaderAr),
          controller: _headerAr,
          onChanged: notifier.updateHeaderTextAr,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('template-settings-header-en'),
          enabled: state.canEdit,
          decoration: InputDecoration(labelText: l10n.templateSettingsHeaderEn),
          controller: _headerEn,
          onChanged: notifier.updateHeaderTextEn,
        ),
        const SizedBox(height: 24),
        Text(
          l10n.templateSettingsFooterSection,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('template-settings-footer-ar'),
          enabled: state.canEdit,
          decoration: InputDecoration(labelText: l10n.templateSettingsFooterAr),
          controller: _footerAr,
          onChanged: notifier.updateFooterTextAr,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('template-settings-footer-en'),
          enabled: state.canEdit,
          decoration: InputDecoration(labelText: l10n.templateSettingsFooterEn),
          controller: _footerEn,
          onChanged: notifier.updateFooterTextEn,
        ),
        const SizedBox(height: 24),
        Text(
          l10n.templateSettingsOptionalColumnsSection,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ..._optionalColumnSwitches(l10n, state, notifier),
        if (state.saveErrorCode != null) ...[
          const SizedBox(height: 12),
          MessageBanner(
            variant: MessageBannerVariant.error,
            message: documentErrorMessage(l10n, state.saveErrorCode!),
          ),
        ],
        if (state.saveSuccess) ...[
          const SizedBox(height: 12),
          MessageBanner(
            variant: MessageBannerVariant.success,
            message: l10n.templateSettingsSaved,
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('template-settings-save'),
          onPressed: state.canEdit && !state.isSaving ? notifier.save : null,
          child: state.isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.templateSettingsSave),
        ),
      ],
    );
  }

  List<Widget> _optionalColumnSwitches(
    AppLocalizations l10n,
    TemplateSettingsState state,
    TemplateSettingsController notifier,
  ) {
    const columns = <String, List<({String field, String labelKey})>>{
      'sales_invoice': [
        (field: 'line.qty', labelKey: 'qty'),
        (field: 'line.unit_price', labelKey: 'unitPrice'),
      ],
      'purchase_invoice': [
        (field: 'line.qty', labelKey: 'qty'),
        (field: 'line.unit_price', labelKey: 'unitPrice'),
      ],
      'customer_statement': [
        (field: 'line.debit', labelKey: 'debit'),
        (field: 'line.credit', labelKey: 'credit'),
      ],
    };

    final widgets = <Widget>[];
    for (final entry in columns.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 8, bottom: 4),
          child: Text(
            _optionalDocTypeLabel(l10n, entry.key),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      );
      for (final column in entry.value) {
        widgets.add(
          SwitchListTile(
            key: Key('template-settings-optional-${entry.key}-${column.field}'),
            contentPadding: EdgeInsets.zero,
            title: Text(_optionalColumnLabel(l10n, column.labelKey)),
            value: state.optionalColumnEnabled(entry.key, column.field),
            onChanged: state.canEdit
                ? (value) => notifier.updateOptionalColumn(
                    entry.key,
                    column.field,
                    value,
                  )
                : null,
          ),
        );
      }
    }
    return widgets;
  }

  String _optionalDocTypeLabel(AppLocalizations l10n, String docType) {
    return switch (docType) {
      'sales_invoice' => l10n.templateSettingsOptionalSalesInvoice,
      'purchase_invoice' => l10n.templateSettingsOptionalPurchaseInvoice,
      'customer_statement' => l10n.templateSettingsOptionalCustomerStatement,
      _ => docType,
    };
  }

  String _optionalColumnLabel(AppLocalizations l10n, String key) {
    return switch (key) {
      'qty' => l10n.templateSettingsOptionalQty,
      'unitPrice' => l10n.templateSettingsOptionalUnitPrice,
      'debit' => l10n.templateSettingsOptionalDebit,
      'credit' => l10n.templateSettingsOptionalCredit,
      _ => key,
    };
  }

  String _languageLabel(AppLocalizations l10n, DocumentLanguageMode mode) {
    return switch (mode) {
      DocumentLanguageMode.ar => l10n.templateSettingsLanguageAr,
      DocumentLanguageMode.en => l10n.templateSettingsLanguageEn,
      DocumentLanguageMode.bilingual => l10n.templateSettingsLanguageBilingual,
    };
  }

  String _paperLabel(AppLocalizations l10n, PaperKind kind) {
    return switch (kind) {
      PaperKind.a4 => l10n.templateSettingsPaperA4,
      PaperKind.thermal80mm => l10n.templateSettingsPaperThermal,
      PaperKind.labelSheet => l10n.templateSettingsPaperLabel,
    };
  }
}
