import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../customers/domain/customer.dart';
import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../../suppliers/domain/supplier.dart';
import '../../domain/voucher_type.dart';
import '../voucher_display_helpers.dart';
import '../voucher_form_controller.dart';

class VoucherPartyPicker extends ConsumerStatefulWidget {
  const VoucherPartyPicker({required this.voucherType, super.key});

  final VoucherType voucherType;

  @override
  ConsumerState<VoucherPartyPicker> createState() => _VoucherPartyPickerState();
}

class _VoucherPartyPickerState extends ConsumerState<VoucherPartyPicker> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final state = ref.watch(voucherFormControllerProvider(widget.voucherType));
    final formController = ref.read(
      voucherFormControllerProvider(widget.voucherType).notifier,
    );

    if (widget.voucherType == VoucherType.payment &&
        (state.form.paymentDestination ?? 'supplier') == 'account') {
      return const SizedBox.shrink();
    }

    final selected = widget.voucherType == VoucherType.receipt
        ? state.selectedCustomer
        : state.selectedSupplier;

    if (selected != null) {
      final name = widget.voucherType == VoucherType.receipt
          ? partyDisplayName(
              locale.languageCode,
              nameAr: (selected as Customer).nameAr,
              nameEn: selected.nameEn,
            )
          : partyDisplayName(
              locale.languageCode,
              nameAr: (selected as Supplier).nameAr,
              nameEn: selected.nameEn,
            );
      if (_controller.text != name) {
        _controller.text = name;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _controller,
          decoration: InvoiceDesign.denseField(
            context,
            label: widget.voucherType == VoucherType.receipt
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
        if (state.isSearchingParty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        if (state.partySearchResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: DecoratedBox(
              decoration: InvoiceDesign.panel,
              child: Column(
                children: [
                  for (final party in state.partySearchResults)
                    ListTile(
                      dense: true,
                      title: Text(
                        party is Customer
                            ? partyDisplayName(
                                locale.languageCode,
                                nameAr: party.nameAr,
                                nameEn: party.nameEn,
                              )
                            : partyDisplayName(
                                locale.languageCode,
                                nameAr: (party as Supplier).nameAr,
                                nameEn: party.nameEn,
                              ),
                      ),
                      onTap: () {
                        if (party is Customer) {
                          formController.selectCustomer(party);
                        } else {
                          formController.selectSupplier(party as Supplier);
                        }
                        _controller.text = party is Customer
                            ? partyDisplayName(
                                locale.languageCode,
                                nameAr: party.nameAr,
                                nameEn: party.nameEn,
                              )
                            : partyDisplayName(
                                locale.languageCode,
                                nameAr: (party as Supplier).nameAr,
                                nameEn: party.nameEn,
                              );
                      },
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
