import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import 'supplier_detail_controller.dart';
import 'supplier_detail_state.dart';
import 'supplier_error_messages.dart';
import 'supplier_payment_vouchers_controller.dart';
import 'supplier_purchase_invoices_controller.dart';
import 'widgets/supplier_detail_header.dart';
import 'widgets/supplier_payment_vouchers_tab.dart';
import 'widgets/supplier_profile_tab.dart';
import 'widgets/supplier_purchase_invoices_tab.dart';
import 'widgets/supplier_statement_tab.dart';

class SupplierDetailScreen extends ConsumerStatefulWidget {
  const SupplierDetailScreen({required this.supplierId, super.key});

  final String supplierId;

  static const purchaseInvoicesTabIndex = 1;
  static const paymentVouchersTabIndex = 2;

  @override
  ConsumerState<SupplierDetailScreen> createState() =>
      _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends ConsumerState<SupplierDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  var _invoicesLoadTriggered = false;
  var _vouchersLoadTriggered = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final index = _tabController.index;
    _maybeLoadInvoices(index);
    _maybeLoadVouchers(index);
  }

  void _maybeLoadInvoices(int index) {
    if (_invoicesLoadTriggered ||
        index != SupplierDetailScreen.purchaseInvoicesTabIndex) {
      return;
    }
    _invoicesLoadTriggered = true;
    ref
        .read(
          supplierPurchaseInvoicesControllerProvider(widget.supplierId).notifier,
        )
        .load();
  }

  void _maybeLoadVouchers(int index) {
    if (_vouchersLoadTriggered ||
        index != SupplierDetailScreen.paymentVouchersTabIndex) {
      return;
    }
    _vouchersLoadTriggered = true;
    ref
        .read(
          supplierPaymentVouchersControllerProvider(widget.supplierId).notifier,
        )
        .load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(
      supplierDetailControllerProvider(widget.supplierId),
    );
    final controller = ref.read(
      supplierDetailControllerProvider(widget.supplierId).notifier,
    );

    return AppShell(
      title: l10n.suppliers,
      currentRoute: AppRoutes.suppliers,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.suppliers),
        ),
      ],
      body: _buildBody(context, l10n, state, controller),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    SupplierDetailState state,
    SupplierDetailController controller,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorCode != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MessageBanner(
                variant: MessageBannerVariant.error,
                message: supplierErrorMessage(l10n, state.errorCode!),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => controller.load(widget.supplierId),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (state.notFound) {
      return Center(
        child: Text(
          l10n.supplierNotFound,
          key: const Key('supplier-detail-not-found'),
        ),
      );
    }

    final supplier = state.supplier!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SupplierDetailHeader(supplier: supplier),
        TabBar(
          key: const Key('supplier-detail-tabs'),
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(
              key: const Key('supplier-tab-profile'),
              text: l10n.customerProfile,
            ),
            Tab(
              key: const Key('supplier-tab-invoices'),
              text: l10n.supplierPurchaseInvoices,
            ),
            Tab(
              key: const Key('supplier-tab-vouchers'),
              text: l10n.supplierPaymentVouchers,
            ),
            Tab(
              key: const Key('supplier-tab-statement'),
              text: l10n.supplierStatement,
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              SupplierProfileTab(supplier: supplier),
              SupplierPurchaseInvoicesTab(supplierId: supplier.id),
              SupplierPaymentVouchersTab(supplierId: supplier.id),
              const SupplierStatementTab(),
            ],
          ),
        ),
      ],
    );
  }
}
