import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../shared/widgets/message_banner.dart';
import '../../domain/chart_account_setup.dart';

/// Setup diagnostic banner for missing A/R or A/P parent accounts.
/// Uses [ChartAccountSetupIssues] only — no chart_account_policy import.
class AccountingSetupBanner extends StatelessWidget {
  const AccountingSetupBanner({required this.issues, super.key});

  final ChartAccountSetupIssues issues;

  @override
  Widget build(BuildContext context) {
    if (!issues.hasAnyIssue) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final messages = <Widget>[];

    if (issues.missingArParent) {
      messages.add(
        Padding(
          padding: EdgeInsetsDirectional.only(bottom: messages.isEmpty ? 0 : 8),
          child: MessageBanner(
            key: const Key('chart-account-setup-ar-missing'),
            variant: MessageBannerVariant.info,
            message: l10n.chartAccountSetupArMissing,
          ),
        ),
      );
    }
    if (issues.missingApParent) {
      messages.add(
        MessageBanner(
          key: const Key('chart-account-setup-ap-missing'),
          variant: MessageBannerVariant.info,
          message: l10n.chartAccountSetupApMissing,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: messages,
      ),
    );
  }
}
