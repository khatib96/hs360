import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../customers/domain/customer.dart';
import '../../../customers/domain/customer_permissions.dart';
import '../../../customers/presentation/widgets/customer_quick_create_dialog.dart';
import '../../../suppliers/domain/supplier.dart';
import '../../domain/invoice_type.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../invoice_form_controller.dart';
import '../invoice_display_helpers.dart';
import 'invoice_design.dart';

class InvoicePartyPicker extends ConsumerStatefulWidget {
  const InvoicePartyPicker({
    required this.invoiceType,
    required this.languageCode,
    super.key,
  });

  final InvoiceType invoiceType;
  final String languageCode;

  @override
  ConsumerState<InvoicePartyPicker> createState() => _InvoicePartyPickerState();
}

class _InvoicePartyPickerState extends ConsumerState<InvoicePartyPicker> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _quickCreateCustomer() async {
    final created = await showDialog<Customer>(
      context: context,
      builder: (_) => const CustomerQuickCreateDialog(),
    );
    if (created == null || !mounted) return;

    final formController = ref.read(
      invoiceFormControllerProvider(widget.invoiceType).notifier,
    );
    formController.setCustomer(created);
    _controller.text = partyDisplayName(
      widget.languageCode,
      nameAr: created.nameAr,
      nameEn: created.nameEn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(invoiceFormControllerProvider(widget.invoiceType));
    final formController = ref.read(
      invoiceFormControllerProvider(widget.invoiceType).notifier,
    );

    final selected = widget.invoiceType.isSalesDirection
        ? state.selectedCustomer
        : state.selectedSupplier;

    if (selected != null) {
      final name = widget.invoiceType.isSalesDirection
          ? partyDisplayName(
              widget.languageCode,
              nameAr: (selected as Customer).nameAr,
              nameEn: selected.nameEn,
            )
          : partyDisplayName(
              widget.languageCode,
              nameAr: (selected as Supplier).nameAr,
              nameEn: selected.nameEn,
            );
      _controller.text = name;
    }

    final showQuickCreate =
        widget.invoiceType.isSalesDirection &&
        session != null &&
        canCreateCustomer(session);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _controller,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InvoiceDesign.denseField(
                  context,
                  hint: widget.invoiceType.isSalesDirection
                      ? l10n.invoiceFormCustomer
                      : l10n.invoiceFormSupplier,
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    formController.searchParty(value);
                  });
                },
              ),
            ),
            if (showQuickCreate) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _quickCreateCustomer,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
                ),
                child: Text(l10n.invoiceFormNewCustomer),
              ),
            ],
          ],
        ),
        if (state.isSearchingParty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        if (state.partySearchResults.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                for (final party in state.partySearchResults)
                  ListTile(
                    title: Text(
                      party is Customer
                          ? partyDisplayName(
                              widget.languageCode,
                              nameAr: party.nameAr,
                              nameEn: party.nameEn,
                            )
                          : partyDisplayName(
                              widget.languageCode,
                              nameAr: (party as Supplier).nameAr,
                              nameEn: party.nameEn,
                            ),
                    ),
                    onTap: () {
                      if (party is Customer) {
                        formController.setCustomer(party);
                      } else {
                        formController.setSupplier(party as Supplier);
                      }
                      _controller.text = party is Customer
                          ? partyDisplayName(
                              widget.languageCode,
                              nameAr: party.nameAr,
                              nameEn: party.nameEn,
                            )
                          : partyDisplayName(
                              widget.languageCode,
                              nameAr: (party as Supplier).nameAr,
                              nameEn: party.nameEn,
                            );
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
