import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../domain/journal_permissions.dart';
import 'journal_detail_controller.dart';
import 'journal_display_helpers.dart';
import 'widgets/journal_detail_sections.dart';
import 'widgets/journal_shared_widgets.dart';

class JournalDetailScreen extends ConsumerWidget {
  const JournalDetailScreen({required this.entryId, super.key});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final provider = journalDetailControllerProvider(entryId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    if (session != null && !canViewJournal(session)) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => l.journalDetailTitle,
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: AppRoutes.journalDetailPath(entryId),
      );
    }

    Widget body;
    if (state.isLoading && state.detail == null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.loading),
          ],
        ),
      );
    } else if (state.errorCode != null && state.detail == null) {
      body = JournalErrorState(
        message: journalErrorMessage(l10n, state.errorCode!),
        onRetry: () => controller.load(entryId),
      );
    } else if (state.detail == null) {
      body = Center(child: Text(l10n.financeErrorNotFound));
    } else {
      final detail = state.detail!;
      final isWide = MediaQuery.sizeOf(context).width > 768;

      body = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JournalDetailHeader(
              detail: detail,
              languageCode: locale.languageCode,
            ),
            const SizedBox(height: 16),
            JournalDetailTotals(detail: detail),
            const SizedBox(height: 16),
            Text(
              l10n.inventoryDocumentLines,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            JournalDetailLinesTable(
              lines: detail.lines,
              languageCode: locale.languageCode,
              isWide: isWide,
            ),
            const SizedBox(height: 16),
            JournalSourceDocumentLink(detail: detail),
            JournalReversalLinks(detail: detail),
          ],
        ),
      );
    }

    return AppShell(
      title: l10n.journalDetailTitle,
      currentRoute: AppRoutes.journal,
      body: Padding(padding: const EdgeInsetsDirectional.all(24), child: body),
    );
  }
}
