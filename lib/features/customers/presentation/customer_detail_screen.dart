import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import 'customer_detail_controller.dart';
import 'customer_detail_state.dart';
import 'customer_error_messages.dart';
import 'customer_statement_controller.dart';
import 'widgets/customer_contracts_tab.dart';
import 'widgets/customer_detail_header.dart';
import 'widgets/customer_invoices_tab.dart';
import 'widgets/customer_profile_tab.dart';
import 'widgets/customer_service_locations_section.dart';
import 'widgets/customer_statement_tab.dart';
import 'widgets/customer_timeline_tab.dart';
import 'widgets/customer_vouchers_tab.dart';

/// Customer 360 shell (M6): profile, locations, placeholders, statement, timeline.
class CustomerDetailScreen extends ConsumerStatefulWidget {
  const CustomerDetailScreen({required this.customerId, super.key});

  final String customerId;

  static const statementTabIndex = 5;

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  var _statementLoadTriggered = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
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
    _maybeLoadStatement(_tabController.index);
  }

  void _maybeLoadStatement(int index) {
    if (_statementLoadTriggered ||
        index != CustomerDetailScreen.statementTabIndex) {
      return;
    }
    _statementLoadTriggered = true;
    ref
        .read(customerStatementControllerProvider(widget.customerId).notifier)
        .load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(
      customerDetailControllerProvider(widget.customerId),
    );
    final controller = ref.read(
      customerDetailControllerProvider(widget.customerId).notifier,
    );

    return AppShell(
      title: l10n.customerDetails,
      currentRoute: AppRoutes.customers,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.customers),
        ),
      ],
      body: _buildBody(context, l10n, state, controller),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    CustomerDetailState state,
    CustomerDetailController controller,
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
                message: customerErrorMessage(l10n, state.errorCode!),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => controller.load(widget.customerId),
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
          l10n.customerNotFound,
          key: const Key('customer-detail-not-found'),
        ),
      );
    }

    final customer = state.customer!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomerDetailHeader(customer: customer, customerId: widget.customerId),
        TabBar(
          key: const Key('customer-detail-tabs'),
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(
              key: const Key('customer-tab-profile'),
              text: l10n.customerProfile,
            ),
            Tab(
              key: const Key('customer-tab-locations'),
              text: l10n.customerLocations,
            ),
            Tab(
              key: const Key('customer-tab-contracts'),
              text: l10n.customerContracts,
            ),
            Tab(
              key: const Key('customer-tab-invoices'),
              text: l10n.customerInvoices,
            ),
            Tab(
              key: const Key('customer-tab-vouchers'),
              text: l10n.customerVouchers,
            ),
            Tab(
              key: const Key('customer-tab-statement'),
              text: l10n.customerStatement,
            ),
            Tab(
              key: const Key('customer-tab-timeline'),
              text: l10n.customerTimeline,
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              CustomerProfileTab(customer: customer),
              CustomerServiceLocationsSection(customerId: customer.id),
              const CustomerContractsTab(),
              const CustomerInvoicesTab(),
              const CustomerVouchersTab(),
              CustomerStatementTab(customerId: customer.id),
              CustomerTimelineTab(customer: customer),
            ],
          ),
        ),
      ],
    );
  }
}
