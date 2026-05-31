import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/module_reference_line.dart';

class CustomerEditPlaceholderScreen extends StatelessWidget {
  const CustomerEditPlaceholderScreen({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.editCustomer,
      currentRoute: AppRoutes.customers,
      body: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.customerEditUnavailable,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ModuleReferenceLine(referenceId: customerId),
            ],
          ),
        ),
      ),
    );
  }
}
