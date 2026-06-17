import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';

class JournalDetailPlaceholderScreen extends FinancePlaceholderScreen {
  JournalDetailPlaceholderScreen({required this.entryId, super.key})
    : super(
        titleGetter: (l10n) => l10n.journalDetailTitle,
        bodyGetter: (l10n) => l10n.financePlaceholderM9Body,
        canView: canViewJournal,
        currentRoute: AppRoutes.journal,
        showBackButton: true,
        fallbackRoute: AppRoutes.journal,
        referenceId: entryId,
      );

  final String entryId;
}
