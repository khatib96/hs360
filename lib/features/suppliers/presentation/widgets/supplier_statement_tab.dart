import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

class SupplierStatementTab extends StatelessWidget {
  const SupplierStatementTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      key: const Key('supplier-statement-tab'),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Text(
          l10n.supplierStatementUnavailable,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
