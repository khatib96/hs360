import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/module_reference_line.dart';

class CustomerDetailPlaceholderScreen extends StatelessWidget {
  const CustomerDetailPlaceholderScreen({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.customerDetails,
      currentRoute: AppRoutes.customers,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.customers),
        ),
      ],
      body: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
              child: ModuleReferenceLine(referenceId: customerId),
            ),
            TabBar(
              tabs: [
                Tab(text: l10n.customerOverview),
                Tab(text: l10n.customerStatement),
                Tab(text: l10n.customerTimeline),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SectionPlaceholder(message: l10n.moduleSectionUnavailable),
                  _SectionPlaceholder(message: l10n.moduleSectionUnavailable),
                  _SectionPlaceholder(message: l10n.moduleSectionUnavailable),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
