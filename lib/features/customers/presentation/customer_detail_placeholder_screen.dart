import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/customer_exception.dart';
import '../../../core/localization/locale_controller.dart' show localeProvider;
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';
import 'customer_error_messages.dart';
import 'widgets/customer_service_locations_section.dart';

/// Customer detail shell (M5.6): Locations tab functional; other tabs placeholders.
class CustomerDetailPlaceholderScreen extends ConsumerStatefulWidget {
  const CustomerDetailPlaceholderScreen({required this.customerId, super.key});

  final String customerId;

  @override
  ConsumerState<CustomerDetailPlaceholderScreen> createState() =>
      _CustomerDetailPlaceholderScreenState();
}

class _CustomerDetailPlaceholderScreenState
    extends ConsumerState<CustomerDetailPlaceholderScreen> {
  bool _isLoading = true;
  String? _errorCode;
  Customer? _customer;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCustomer);
  }

  Future<void> _loadCustomer() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      setState(() {
        _isLoading = false;
        _errorCode = CustomerException.permissionDenied;
      });
      return;
    }
    try {
      final customer = await ref
          .read(customerRepositoryProvider)
          .fetchCustomerById(session, widget.customerId);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _customer = customer;
        _errorCode = customer == null ? CustomerException.unknown : null;
      });
    } on CustomerException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorCode = e.code;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorCode = CustomerException.unknown;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
      body: _buildBody(context, l10n),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorCode != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: MessageBanner(
            variant: MessageBannerVariant.error,
            message: customerErrorMessage(l10n, _errorCode!),
          ),
        ),
      );
    }
    final customer = _customer;
    if (customer == null) {
      return Center(child: Text(l10n.customerDetailsUnavailable));
    }

    final locale = ref.watch(localeProvider).languageCode;

    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.displayName(locale),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${customer.code} · ${customer.phonePrimary}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          TabBar(
            tabs: [
              Tab(text: l10n.customerOverview),
              Tab(text: l10n.customerLocations),
              Tab(text: l10n.customerStatement),
              Tab(text: l10n.customerTimeline),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SectionPlaceholder(message: l10n.moduleSectionUnavailable),
                CustomerServiceLocationsSection(customerId: customer.id),
                _SectionPlaceholder(message: l10n.moduleSectionUnavailable),
                _SectionPlaceholder(message: l10n.moduleSectionUnavailable),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
