import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/module_reference_line.dart';

class SupplierDetailPlaceholderScreen extends StatelessWidget {
  const SupplierDetailPlaceholderScreen({required this.supplierId, super.key});

  final String supplierId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.suppliers,
      currentRoute: AppRoutes.customers,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.suppliers),
        ),
      ],
      body: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.supplierDetailsUnavailable,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ModuleReferenceLine(referenceId: supplierId),
            ],
          ),
        ),
      ),
    );
  }
}
