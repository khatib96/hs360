import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/customer_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';
import '../domain/customer_form_state.dart';
import '../domain/customer_permissions.dart';
import 'customer_error_messages.dart';
import 'customer_form_draft.dart';
import 'customer_list_controller.dart';
import 'widgets/customer_form.dart';

class CustomerEditScreen extends ConsumerStatefulWidget {
  const CustomerEditScreen({required this.customerId, super.key});

  final String customerId;

  @override
  ConsumerState<CustomerEditScreen> createState() => _CustomerEditScreenState();
}

class _CustomerEditScreenState extends ConsumerState<CustomerEditScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isEnsuringAccount = false;
  String? _errorCode;
  Customer? _customer;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
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

  Future<void> _onSubmit(CustomerFormState formState) async {
    final customer = _customer;
    if (customer == null) return;
    setState(() => _isSubmitting = true);
    final errorCode = await ref
        .read(customerListControllerProvider.notifier)
        .updateCustomer(customer.id, formState);

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (errorCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.customerUpdated)),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.customers);
      }
      return;
    }
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(customerErrorMessage(l10n, errorCode))),
    );
  }

  Future<void> _onEnsureAccount() async {
    final customer = _customer;
    if (customer == null) return;
    setState(() => _isEnsuringAccount = true);
    final errorCode = await ref
        .read(customerListControllerProvider.notifier)
        .ensureAccount(customer.id);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (errorCode == null) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.customerAccountLinked)),
      );
      return;
    }
    setState(() => _isEnsuringAccount = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(customerErrorMessage(l10n, errorCode))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authControllerProvider).valueOrNull;

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_customer == null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              customerErrorMessage(l10n, _errorCode ?? CustomerException.unknown),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorCode = null;
                });
                _load();
              },
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    } else {
      final customer = _customer!;
      body = SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: CustomerForm(
              initialDraft: CustomerFormDraft.fromCustomer(customer),
              isEdit: true,
              code: customer.code,
              hasLinkedAccount: customer.hasLinkedAccount,
              canEnsureAccount: session != null && canEditCustomer(session),
              isEnsuringAccount: _isEnsuringAccount,
              onEnsureAccount: _onEnsureAccount,
              isSubmitting: _isSubmitting,
              submitLabel: MaterialLocalizations.of(context).saveButtonLabel,
              onSubmit: _onSubmit,
              onCancel: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.customers);
                }
              },
            ),
          ),
        ),
      );
    }

    return AppShell(
      title: l10n.editCustomer,
      currentRoute: AppRoutes.customers,
      body: body,
    );
  }
}
