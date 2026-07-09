import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/app_routes.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../domain/contract_permissions.dart';

class ContractCreateScreen extends ConsumerWidget {
  const ContractCreateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FinancePlaceholderScreen(
      titleGetter: (l) => l.contractCreateTitle,
      bodyGetter: (l) => l.contractCreatePrepared,
      canView: canCreateContract,
      currentRoute: AppRoutes.contracts,
      showBackButton: true,
      fallbackRoute: AppRoutes.contracts,
    );
  }
}
