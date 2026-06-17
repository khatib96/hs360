import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';

class JournalListPlaceholderScreen extends FinancePlaceholderScreen {
  JournalListPlaceholderScreen({super.key})
    : super(
        titleGetter: (l10n) => l10n.journalTitle,
        bodyGetter: (l10n) => l10n.financePlaceholderM9Body,
        canView: canViewJournal,
        currentRoute: AppRoutes.journal,
      );
}
