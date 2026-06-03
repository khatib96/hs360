import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../auth/presentation/auth_controller.dart';
import '../../domain/customer_permissions.dart';
import 'customer_module_empty_state.dart';

class CustomerVouchersTab extends ConsumerWidget {
  const CustomerVouchersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final canView = session != null && canViewVouchers(session);

    return CustomerModuleEmptyState(
      key: const Key('customer-vouchers-tab'),
      denied: !canView,
      deniedMessage: l10n.moduleAccessUnavailable,
      emptyMessage: l10n.customerVouchersEmpty,
    );
  }
}
