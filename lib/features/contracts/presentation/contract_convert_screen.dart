import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/app_routes.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../domain/contract_permissions.dart';

class ContractConvertScreen extends ConsumerWidget {
  const ContractConvertScreen({required this.contractId, super.key});

  final String contractId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FinancePlaceholderScreen(
      titleGetter: (l) => l.contractConvertTitle,
      bodyGetter: (l) => l.contractConvertPrepared,
      canView: canConvertTrial,
      currentRoute: AppRoutes.contracts,
      showBackButton: true,
      fallbackRoute: AppRoutes.contracts,
      referenceId: contractId,
    );
  }
}
