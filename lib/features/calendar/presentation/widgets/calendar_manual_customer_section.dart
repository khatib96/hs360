import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../contracts/domain/contract_summary.dart';
import '../../../customers/domain/customer.dart';
import '../../../customers/domain/customer_service_location.dart';

/// Customer search plus optional service-location and contract pickers.
class CalendarManualCustomerSection extends StatelessWidget {
  const CalendarManualCustomerSection({
    required this.customerId,
    required this.customerLabel,
    required this.customerSearch,
    required this.customerResults,
    required this.locations,
    required this.contracts,
    required this.serviceLocationId,
    required this.contractId,
    required this.loadingLookups,
    required this.canPickContract,
    required this.locale,
    required this.onClearCustomer,
    required this.onSearchCustomers,
    required this.onSelectCustomer,
    required this.onServiceLocationChanged,
    required this.onContractChanged,
    super.key,
  });

  final String? customerId;
  final String? customerLabel;
  final TextEditingController customerSearch;
  final List<Customer> customerResults;
  final List<CustomerServiceLocation> locations;
  final List<ContractSummary> contracts;
  final String? serviceLocationId;
  final String? contractId;
  final bool loadingLookups;
  final bool canPickContract;
  final String locale;
  final VoidCallback onClearCustomer;
  final ValueChanged<String> onSearchCustomers;
  final ValueChanged<Customer> onSelectCustomer;
  final ValueChanged<String?> onServiceLocationChanged;
  final ValueChanged<String?> onContractChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(l10n.calendarFilterCustomer),
        if (customerId != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(customerLabel ?? customerId!),
            trailing: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: onClearCustomer,
            ),
          )
        else
          TextField(
            key: const Key('calendar-manual-customer-search'),
            controller: customerSearch,
            decoration: InputDecoration(
              hintText: l10n.calendarFilterSearch,
              suffixIcon: loadingLookups
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => onSearchCustomers(customerSearch.text),
                    ),
            ),
            onSubmitted: onSearchCustomers,
          ),
        for (final c in customerResults)
          ListTile(
            dense: true,
            title: Text(locale == 'ar' ? c.nameAr : (c.nameEn ?? c.nameAr)),
            onTap: () => onSelectCustomer(c),
          ),
        if (customerId != null && locations.isNotEmpty)
          DropdownButtonFormField<String?>(
            key: const Key('calendar-manual-location'),
            initialValue: serviceLocationId,
            decoration: InputDecoration(
              labelText: l10n.calendarFilterServiceLocation,
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(l10n.calendarManualNone),
              ),
              for (final loc in locations)
                DropdownMenuItem(value: loc.id, child: Text(loc.name)),
            ],
            onChanged: onServiceLocationChanged,
          ),
        if (customerId != null && canPickContract && contracts.isNotEmpty)
          DropdownButtonFormField<String?>(
            key: const Key('calendar-manual-contract'),
            initialValue: contractId,
            decoration: InputDecoration(labelText: l10n.calendarFilterContract),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(l10n.calendarManualNone),
              ),
              for (final c in contracts)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(c.contractNumber ?? c.id),
                ),
            ],
            onChanged: onContractChanged,
          ),
      ],
    );
  }
}
