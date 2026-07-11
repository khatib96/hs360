import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../../invoices/presentation/widgets/invoice_sheet.dart';
import '../../domain/contract_type.dart';
import '../contract_display_helpers.dart';
import '../contract_form_controller.dart';
import '../contract_form_draft_builder.dart';
import 'contract_detail_panel.dart';

class ContractFormHeader extends ConsumerWidget {
  const ContractFormHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(contractFormControllerProvider);
    final controller = ref.read(contractFormControllerProvider.notifier);
    final draft = buildContractDraft(state);
    final durationMonths = contractDraftDurationMonths(draft);
    final durationLabel = contractDurationLabel(l10n, durationMonths);
    final isDesktop = InvoiceDesign.isDesktop(context);

    final typeSelector = SegmentedButton<ContractType>(
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: [
        ButtonSegment(
          value: ContractType.trial,
          label: Text(l10n.contractTypeTrial),
        ),
        ButtonSegment(
          value: ContractType.rental,
          label: Text(l10n.contractTypeRental),
        ),
      ],
      selected: {state.type},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => controller.setType(selection.first),
    );

    final startDateField = _LabeledField(
      label: l10n.contractColumnStartDate,
      child: _DatePickerField(
        value: state.startDate,
        onPick: (date) {
          if (date != null) controller.setStartDate(date);
        },
      ),
    );

    final termField = state.type == ContractType.trial
        ? _LabeledField(
            label: l10n.contractTrialDaysLabel,
            child: TextFormField(
              key: const Key('contract-trial-days'),
              initialValue: state.trialDays.toString(),
              keyboardType: TextInputType.number,
              decoration: InvoiceDesign.denseField(context),
              onChanged: (value) {
                final days = int.tryParse(value.trim());
                if (days != null) controller.setTrialDays(days);
              },
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LabeledField(
                label: l10n.contractFieldEndDate,
                child: _DatePickerField(
                  value: state.endDate,
                  onPick: controller.setEndDate,
                  allowClear: true,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: controller.applyTwelveMonthTerm,
                  child: Text(l10n.contractTermTwelveMonths),
                ),
              ),
            ],
          );

    final previewEnd = contractDraftEffectiveEndDate(draft);
    final previewEndRow = previewEnd == null
        ? null
        : _LabeledField(
            label: state.type == ContractType.trial
                ? l10n.contractFieldTrialEndDate
                : l10n.contractFieldEndDate,
            child: Text(
              formatContractDate(previewEnd),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );

    final billingField = state.type == ContractType.rental
        ? _LabeledField(
            label: l10n.contractFieldBillingDay,
            child: _CycleDayPickerField(
              key: const Key('contract-billing-day'),
              startDate: state.startDate,
              day: state.billingDay,
              onPick: controller.setBillingDate,
            ),
          )
        : null;

    final refillField = state.type == ContractType.rental
        ? _LabeledField(
            label: l10n.contractFieldRefillDay,
            child: _CycleDayPickerField(
              key: const Key('contract-refill-day'),
              startDate: state.startDate,
              day: state.refillDay,
              onPick: controller.setRefillDate,
            ),
          )
        : null;

    final notesField = _LabeledField(
      label: l10n.contractFieldNotes,
      child: TextFormField(
        key: const Key('contract-notes'),
        initialValue: state.notes,
        decoration: InvoiceDesign.denseField(context),
        maxLines: 2,
        onChanged: controller.setNotes,
      ),
    );

    final monthlyField = state.type == ContractType.rental
        ? _LabeledField(
            label: l10n.contractFieldMonthlyRentalValue,
            child: TextFormField(
              key: const Key('contract-monthly-rental'),
              initialValue: state.monthlyRentalValue?.toString() ?? '',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InvoiceDesign.denseField(context),
              onChanged: controller.setMonthlyRentalValueFromText,
            ),
          )
        : null;

    final fields = <Widget>[
      _LabeledField(label: l10n.contractColumnType, child: typeSelector),
      startDateField,
      termField,
      ?previewEndRow,
      if (durationLabel != null)
        _LabeledField(
          label: l10n.contractFieldContractDuration,
          child: Text(durationLabel),
        ),
      ?billingField,
      ?refillField,
      ?monthlyField,
    ];

    return InvoiceSectionCard(
      title: l10n.contractSectionOverview,
      child: isDesktop
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderGrid(columns: 3, children: fields),
                const SizedBox(height: 12),
                notesField,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final field in fields) ...[
                  field,
                  const SizedBox(height: 12),
                ],
                notesField,
              ],
            ),
    );
  }
}

class _HeaderGrid extends StatelessWidget {
  const _HeaderGrid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final slice = children.sublist(
        i,
        (i + columns) > children.length ? children.length : i + columns,
      );
      rows.add(
        Padding(
          padding: EdgeInsetsDirectional.only(
            bottom: (i + columns) < children.length ? 14 : 0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: 14),
                Expanded(
                  child: j < slice.length ? slice[j] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: InvoiceDesign.fieldLabelStyle(context)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.value,
    required this.onPick,
    this.allowClear = false,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onPick;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    final display = value == null ? '—' : formatContractDate(value!);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InvoiceDesign.denseField(context),
        child: Row(
          children: [
            Expanded(child: Text(display)),
            if (allowClear && value != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => onPick(null),
                visualDensity: VisualDensity.compact,
              ),
            const Icon(Icons.calendar_today, size: 16),
          ],
        ),
      ),
    );
  }
}

class _CycleDayPickerField extends StatelessWidget {
  const _CycleDayPickerField({
    super.key,
    required this.startDate,
    required this.day,
    required this.onPick,
  });

  final DateTime? startDate;
  final int? day;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    final base = startDate ?? DateTime.now();
    final displayDay = day ?? (base.day > 28 ? 28 : base.day);
    final displayDate = DateTime(base.year, base.month, displayDay);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: displayDate,
          firstDate: DateTime(base.year - 1),
          lastDate: DateTime(base.year + 1),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InvoiceDesign.denseField(context),
        child: Row(
          children: [
            Expanded(child: Text(formatContractDate(displayDate))),
            const Icon(Icons.calendar_today, size: 16),
          ],
        ),
      ),
    );
  }
}
