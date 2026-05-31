import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../domain/customer.dart';

/// Renders the customer list as a dense desktop table or mobile cards.
class CustomerTable extends StatelessWidget {
  const CustomerTable({
    required this.customers,
    required this.languageCode,
    required this.canEdit,
    required this.canDeactivate,
    required this.onView,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
  });

  final List<Customer> customers;
  final String languageCode;
  final bool canEdit;
  final bool canDeactivate;
  final ValueChanged<Customer> onView;
  final ValueChanged<Customer> onEdit;
  final ValueChanged<Customer> onDeactivate;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 768;
    if (isWide) {
      return _DesktopCustomerTable(
        customers: customers,
        languageCode: languageCode,
        canEdit: canEdit,
        canDeactivate: canDeactivate,
        onView: onView,
        onEdit: onEdit,
        onDeactivate: onDeactivate,
      );
    }
    return _MobileCustomerList(
      customers: customers,
      languageCode: languageCode,
      canEdit: canEdit,
      canDeactivate: canDeactivate,
      onView: onView,
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}

String _formatCredit(Decimal value, String languageCode) =>
    formatMoney(value, locale: languageCode);

class _DesktopCustomerTable extends StatefulWidget {
  const _DesktopCustomerTable({
    required this.customers,
    required this.languageCode,
    required this.canEdit,
    required this.canDeactivate,
    required this.onView,
    required this.onEdit,
    required this.onDeactivate,
  });

  final List<Customer> customers;
  final String languageCode;
  final bool canEdit;
  final bool canDeactivate;
  final ValueChanged<Customer> onView;
  final ValueChanged<Customer> onEdit;
  final ValueChanged<Customer> onDeactivate;

  @override
  State<_DesktopCustomerTable> createState() => _DesktopCustomerTableState();
}

class _DesktopCustomerTableState extends State<_DesktopCustomerTable> {
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          notificationPredicate: (notification) => notification.depth == 1,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.neutral50),
              columns: [
                DataColumn(label: Text(l10n.customerColumnCode)),
                DataColumn(label: Text(l10n.customerColumnName)),
                DataColumn(label: Text(l10n.customerColumnPhone)),
                DataColumn(label: Text(l10n.customerColumnWhatsapp)),
                DataColumn(label: Text(l10n.customerColumnLocation)),
                DataColumn(label: Text(l10n.customerColumnPaymentTerms)),
                DataColumn(label: Text(l10n.customerColumnCreditLimit)),
                DataColumn(label: Text(l10n.customerColumnStatus)),
                const DataColumn(label: SizedBox(width: 120)),
              ],
              rows: widget.customers.map((customer) {
                return DataRow(
                  cells: [
                    DataCell(Text(customer.code)),
                    DataCell(
                      _NameCell(
                        customer: customer,
                        languageCode: widget.languageCode,
                        vipLabel: l10n.customerVip,
                      ),
                    ),
                    DataCell(Text(customer.phonePrimary)),
                    DataCell(Text(customer.whatsapp ?? l10n.productsNotAvailable)),
                    DataCell(Text(_location(customer, l10n))),
                    DataCell(Text(customer.paymentTermsDays.toString())),
                    DataCell(
                      Text(_formatCredit(customer.creditLimit, widget.languageCode)),
                    ),
                    DataCell(
                      Text(
                        customer.isActive
                            ? l10n.customerStatusActive
                            : l10n.customerStatusInactive,
                        style: customer.isActive
                            ? null
                            : theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.neutral400),
                      ),
                    ),
                    DataCell(
                      _RowActions(
                        customer: customer,
                        canEdit: widget.canEdit,
                        canDeactivate: widget.canDeactivate,
                        onView: widget.onView,
                        onEdit: widget.onEdit,
                        onDeactivate: widget.onDeactivate,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

String _location(Customer customer, AppLocalizations l10n) {
  final parts = [customer.area, customer.city]
      .where((p) => p != null && p.trim().isNotEmpty)
      .cast<String>()
      .toList();
  return parts.isEmpty ? l10n.productsNotAvailable : parts.join(' / ');
}

class _NameCell extends StatelessWidget {
  const _NameCell({
    required this.customer,
    required this.languageCode,
    required this.vipLabel,
  });

  final Customer customer;
  final String languageCode;
  final String vipLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(customer.displayName(languageCode))),
        if (customer.isVip) ...[
          const SizedBox(width: 6),
          _VipBadge(label: vipLabel),
        ],
      ],
    );
  }
}

class _VipBadge extends StatelessWidget {
  const _VipBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.customer,
    required this.canEdit,
    required this.canDeactivate,
    required this.onView,
    required this.onEdit,
    required this.onDeactivate,
  });

  final Customer customer;
  final bool canEdit;
  final bool canDeactivate;
  final ValueChanged<Customer> onView;
  final ValueChanged<Customer> onEdit;
  final ValueChanged<Customer> onDeactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.visibility_outlined, size: 20),
          tooltip: l10n.customerActionView,
          onPressed: () => onView(customer),
        ),
        if (canEdit)
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: l10n.customerActionEdit,
            onPressed: () => onEdit(customer),
          ),
        if (canDeactivate && customer.isActive)
          IconButton(
            icon: const Icon(Icons.block, size: 20),
            tooltip: l10n.customerActionDeactivate,
            onPressed: () => onDeactivate(customer),
          ),
      ],
    );
  }
}

class _MobileCustomerList extends StatelessWidget {
  const _MobileCustomerList({
    required this.customers,
    required this.languageCode,
    required this.canEdit,
    required this.canDeactivate,
    required this.onView,
    required this.onEdit,
    required this.onDeactivate,
  });

  final List<Customer> customers;
  final String languageCode;
  final bool canEdit;
  final bool canDeactivate;
  final ValueChanged<Customer> onView;
  final ValueChanged<Customer> onEdit;
  final ValueChanged<Customer> onDeactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.separated(
      itemCount: customers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final customer = customers[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            onTap: () => onView(customer),
            title: _NameCell(
              customer: customer,
              languageCode: languageCode,
              vipLabel: l10n.customerVip,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${customer.code} · ${customer.phonePrimary}'),
                Text(_location(customer, l10n)),
                Text(
                  customer.isActive
                      ? l10n.customerStatusActive
                      : l10n.customerStatusInactive,
                ),
              ],
            ),
            trailing: _RowActions(
              customer: customer,
              canEdit: canEdit,
              canDeactivate: canDeactivate,
              onView: onView,
              onEdit: onEdit,
              onDeactivate: onDeactivate,
            ),
          ),
        );
      },
    );
  }
}
