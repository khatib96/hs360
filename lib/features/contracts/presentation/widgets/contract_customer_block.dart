import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../customers/domain/customer.dart';
import '../../../customers/domain/customer_permissions.dart';
import '../../../customers/presentation/widgets/customer_quick_create_dialog.dart';
import '../../../invoices/presentation/invoice_display_helpers.dart';
import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../../invoices/presentation/widgets/invoice_sheet.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../contract_form_controller.dart';

class ContractCustomerBlock extends ConsumerStatefulWidget {
  const ContractCustomerBlock({required this.languageCode, super.key});

  final String languageCode;

  @override
  ConsumerState<ContractCustomerBlock> createState() =>
      _ContractCustomerBlockState();
}

class _ContractCustomerBlockState extends ConsumerState<ContractCustomerBlock> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(contractFormControllerProvider.notifier).searchCustomers(query);
    });
  }

  Future<void> _quickCreateCustomer() async {
    final created = await showDialog<Customer>(
      context: context,
      builder: (_) => const CustomerQuickCreateDialog(),
    );
    if (created == null || !mounted) return;
    final controller = ref.read(contractFormControllerProvider.notifier);
    await controller.selectCustomer(created);
    _searchController.text = partyDisplayName(
      widget.languageCode,
      nameAr: created.nameAr,
      nameEn: created.nameEn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(contractFormControllerProvider);
    final controller = ref.read(contractFormControllerProvider.notifier);
    final selected = state.selectedCustomer;

    if (selected != null) {
      _searchController.text = partyDisplayName(
        widget.languageCode,
        nameAr: selected.nameAr,
        nameEn: selected.nameEn,
      );
    }

    final showQuickCreate = session != null && canCreateCustomer(session);

    return InvoiceSectionCard(
      title: l10n.contractColumnCustomer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('contract-customer-search'),
                  controller: _searchController,
                  decoration: InvoiceDesign.denseField(
                    context,
                    hint: l10n.contractFilterSearchHint,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              if (showQuickCreate) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: l10n.contractCreateNew,
                  onPressed: _quickCreateCustomer,
                  icon: const Icon(Icons.person_add_outlined),
                ),
              ],
              if (selected != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {
                    controller.clearCustomer();
                    _searchController.clear();
                  },
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ],
          ),
          if (state.isSearchingCustomers)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (state.customerSearchResults.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.customerSearchResults.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final customer = state.customerSearchResults[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      partyDisplayName(
                        widget.languageCode,
                        nameAr: customer.nameAr,
                        nameEn: customer.nameEn,
                      ),
                    ),
                    onTap: () async {
                      await controller.selectCustomer(customer);
                      _searchController.text = partyDisplayName(
                        widget.languageCode,
                        nameAr: customer.nameAr,
                        nameEn: customer.nameEn,
                      );
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Text(
            l10n.contractColumnServiceLocation,
            style: InvoiceDesign.fieldLabelStyle(context),
          ),
          const SizedBox(height: 6),
          if (state.customerId == null)
            Text(
              l10n.contractCustomerSelectFirst,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else if (state.isLoadingLocations)
            const LinearProgressIndicator()
          else if (state.serviceLocations.isEmpty)
            Text(l10n.serviceLocationEmpty)
          else
            DropdownButtonFormField<String>(
              key: ValueKey('contract-location-${state.serviceLocationId}'),
              initialValue: state.serviceLocationId,
              isExpanded: true,
              isDense: true,
              decoration: InvoiceDesign.denseField(context),
              items: [
                for (final location in state.serviceLocations)
                  DropdownMenuItem(
                    value: location.id,
                    child: Text(location.name),
                  ),
              ],
              onChanged: controller.selectServiceLocation,
            ),
        ],
      ),
    );
  }
}
