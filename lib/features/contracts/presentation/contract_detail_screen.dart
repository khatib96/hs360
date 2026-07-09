import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/app_routes.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../domain/contract_permissions.dart';

class ContractDetailScreen extends ConsumerWidget {
  const ContractDetailScreen({required this.contractId, super.key});

  final String contractId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FinancePlaceholderScreen(
      titleGetter: (l) => l.contractDetailTitle,
      bodyGetter: (l) => l.contractDetailPrepared,
      canView: canViewContracts,
      currentRoute: AppRoutes.contracts,
      showBackButton: true,
      fallbackRoute: AppRoutes.contracts,
      referenceId: contractId,
    );
  }
}
