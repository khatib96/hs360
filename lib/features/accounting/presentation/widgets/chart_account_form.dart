import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../domain/account_type.dart';
import '../../domain/chart_account.dart';
import '../../domain/chart_account_form_state.dart';
import '../chart_account_display_helpers.dart';
import '../chart_account_error_messages.dart';

/// Collects chart account fields; displays error codes from parent only.
class ChartAccountForm extends StatefulWidget {
  const ChartAccountForm({
    required this.isEdit,
    required this.isSubmitting,
    required this.submitLabel,
    required this.onSubmit,
    required this.onCancel,
    this.initialCode,
    this.initialNameAr = '',
    this.initialNameEn = '',
    this.initialType = AccountType.expense,
    this.initialParentId,
    this.parentOptions = const [],
    this.errorCodes = const [],
    super.key,
  });

  final bool isEdit;
  final bool isSubmitting;
  final String submitLabel;
  final ValueChanged<ChartAccountFormState> onSubmit;
  final VoidCallback onCancel;
  final String? initialCode;
  final String initialNameAr;
  final String initialNameEn;
  final AccountType initialType;
  final String? initialParentId;
  final List<ChartAccount> parentOptions;
  final List<String> errorCodes;

  @override
  State<ChartAccountForm> createState() => _ChartAccountFormState();
}

class _ChartAccountFormState extends State<ChartAccountForm> {
  late final TextEditingController _code;
  late final TextEditingController _nameAr;
  late final TextEditingController _nameEn;
  late AccountType _type;
  String? _parentId;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.initialCode ?? '');
    _nameAr = TextEditingController(text: widget.initialNameAr);
    _nameEn = TextEditingController(text: widget.initialNameEn);
    _type = widget.initialType;
    _parentId = widget.initialParentId;
  }

  @override
  void dispose() {
    _code.dispose();
    _nameAr.dispose();
    _nameEn.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    widget.onSubmit(
      ChartAccountFormState(
        code: widget.isEdit ? null : _code.text.trim(),
        nameAr: _nameAr.text,
        nameEn: _nameEn.text,
        type: _type,
        parentId: widget.isEdit ? null : _parentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.errorCodes.isNotEmpty) ...[
          MessageBanner(
            variant: MessageBannerVariant.error,
            message: chartAccountErrorMessages(l10n, widget.errorCodes),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.isEdit && widget.initialCode != null) ...[
          TextFormField(
            key: const Key('chart-account-code-readonly'),
            initialValue: widget.initialCode,
            readOnly: true,
            enabled: false,
            decoration: InputDecoration(
              labelText: l10n.chartAccountFieldCode,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.chartAccountCodeReadOnlyHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ] else ...[
          AppTextField(
            label: l10n.chartAccountFieldCode,
            controller: _code,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
        ],
        AppTextField(
          label: l10n.chartAccountFieldNameAr,
          controller: _nameAr,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: l10n.chartAccountFieldNameEn,
          controller: _nameEn,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AccountType>(
          isExpanded: true,
          initialValue: _type,
          decoration: InputDecoration(labelText: l10n.chartAccountFieldType),
          items: AccountType.values
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(localizedAccountType(l10n, type)),
                ),
              )
              .toList(),
          onChanged: widget.isSubmitting
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() {
                    _type = value;
                    if (!widget.isEdit &&
                        _parentId != null &&
                        !widget.parentOptions.any((p) => p.id == _parentId)) {
                      _parentId = null;
                    }
                  });
                },
        ),
        if (!widget.isEdit) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            isExpanded: true,
            initialValue: _parentId,
            decoration: InputDecoration(labelText: l10n.chartAccountFieldParent),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(l10n.chartAccountParentNone),
              ),
              ...widget.parentOptions
                  .where((p) => p.type == _type)
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.code} — ${p.nameEn}'),
                    ),
                  ),
            ],
            onChanged: widget.isSubmitting
                ? null
                : (value) => setState(() => _parentId = value),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.isSubmitting ? null : widget.onCancel,
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: widget.isSubmitting ? null : _handleSubmit,
              child: widget.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.submitLabel),
            ),
          ],
        ),
      ],
    );
  }
}
