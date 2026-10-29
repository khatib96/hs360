import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_detail_surface.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_state_view.dart';
import '../../../shared/widgets/app_table_frame.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../finance_shared/presentation/finance_error_messages.dart';
import '../../finance_shared/presentation/money_display.dart';
import '../data/rental_billing_repository.dart';
import '../domain/rental_billing.dart';

/// Uncollected rental months per contract (payment-confirmed billing).
class RentalArrearsScreen extends ConsumerWidget {
  const RentalArrearsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final report = ref.watch(rentalArrearsProvider);

    return AppShell(
      title: l10n.rentalArrearsTitle,
      currentRoute: AppRoutes.rentalArrears,
      moduleActions: [
        IconButton(
          key: const Key('rental-arrears-refresh'),
          tooltip: l10n.retry,
          onPressed: () => ref.invalidate(rentalArrearsProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: report.when(
        loading: () => AppStateView.loading(message: l10n.loading),
        error: (error, _) => AppStateView.error(
          message:
              '${l10n.rentalArrearsLoadError}\n'
              '${financeErrorMessage(l10n, error is FinanceException ? error.code : FinanceException.unknown)}',
          action: FilledButton(
            onPressed: () => ref.invalidate(rentalArrearsProvider),
            child: Text(l10n.retry),
          ),
        ),
        data: (data) => _ArrearsBody(report: data),
      ),
    );
  }
}

class _ArrearsBody extends StatelessWidget {
  const _ArrearsBody({required this.report});

  final RentalArrearsReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Padding(
      padding: AppSpacing.page,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MessageBanner(
            variant: MessageBannerVariant.info,
            message: l10n.rentalArrearsHint,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppDetailSection(
            key: const Key('rental-arrears-total'),
            title: l10n.rentalArrearsTotal,
            trailing: MoneyDisplay(
              amount: report.totalAmount,
              style: theme.textTheme.titleMedium,
            ),
            child: Text(
              l10n.rentalArrearsSummary(
                report.items.length,
                report.totalMonths,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: report.items.isEmpty
                ? AppStateView.empty(
                    icon: Icons.task_alt_rounded,
                    message: l10n.rentalArrearsEmpty,
                  )
                : AppTableFrame(
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListView.separated(
                        key: const Key('rental-arrears-list'),
                        itemCount: report.items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = report.items[index];
                          final months = item.months
                              .map(DateFormat.yMMM(locale).format)
                              .join('، ');
                          return ListTile(
                            key: Key('rental-arrears-${item.contractId}'),
                            onTap: () => context.push(
                              AppRoutes.contractDetailPath(item.contractId),
                            ),
                            title: Text(
                              '${item.contractNumber} · ${item.customerName(languageCode)}',
                            ),
                            subtitle: Text(
                              '${l10n.rentalArrearsMonthsCount(item.months.length)}: $months\n'
                              '${l10n.rentalArrearsOldestDue}: ${DateFormat.yMd(locale).format(item.oldestDueDate)}',
                            ),
                            isThreeLine: true,
                            trailing: MoneyDisplay(
                              amount: item.amount,
                              style: theme.textTheme.titleSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
