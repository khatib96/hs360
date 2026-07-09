import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../domain/journal_permissions.dart';
import 'journal_display_helpers.dart';
import 'journal_list_controller.dart';
import 'widgets/journal_filters_bar.dart';
import 'widgets/journal_shared_widgets.dart';
import 'widgets/journal_table.dart';

class JournalListScreen extends ConsumerWidget {
  const JournalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(journalListControllerProvider);
    final controller = ref.read(journalListControllerProvider.notifier);

    if (session != null && !canViewJournal(session)) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => l.journalTitle,
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: AppRoutes.journal,
      );
    }

    Widget content;
    if (state.isLoading && state.entries.isEmpty) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.loading),
          ],
        ),
      );
    } else if (state.hasError && state.entries.isEmpty) {
      content = JournalErrorState(
        message: journalErrorMessage(l10n, state.errorCode!),
        onRetry: controller.refresh,
      );
    } else if (!state.isLoading && state.entries.isEmpty) {
      content = Center(
        child: Text(
          state.filters.hasActiveFilters
              ? l10n.journalListEmptyFiltered
              : l10n.journalListEmpty,
        ),
      );
    } else {
      final isWide = MediaQuery.sizeOf(context).width > 768;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: isWide
                ? JournalTable(
                    entries: state.entries,
                    languageCode: locale.languageCode,
                  )
                : JournalCardList(
                    entries: state.entries,
                    languageCode: locale.languageCode,
                  ),
          ),
          if (state.hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: state.isLoadingMore
                  ? const Center(child: CircularProgressIndicator())
                  : Center(
                      child: OutlinedButton(
                        onPressed: controller.loadMore,
                        child: Text(l10n.loadMore),
                      ),
                    ),
            ),
        ],
      );
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JournalFiltersBar(
          key: const Key('journal-filters-bar'),
          filters: state.filters,
          onSourceChanged: controller.setSource,
          onSearchChanged: controller.setSearch,
          onDateFromChanged: controller.setDateFrom,
          onDateToChanged: controller.setDateTo,
        ),
        const SizedBox(height: 16),
        Expanded(child: content),
      ],
    );

    return AppShell(
      title: l10n.journalTitle,
      currentRoute: AppRoutes.journal,
      body: Stack(
        children: [
          Padding(padding: const EdgeInsetsDirectional.all(24), child: body),
          if (state.isLoading && state.entries.isNotEmpty)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
