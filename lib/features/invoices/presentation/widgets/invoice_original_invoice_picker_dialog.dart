import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../finance_shared/domain/pagination_cursor.dart';
import '../../data/invoice_repository.dart';
import '../../domain/invoice_filters.dart';
import '../../domain/invoice_status.dart';
import '../../domain/invoice_summary.dart';
import '../../domain/invoice_type.dart';
import '../invoice_display_helpers.dart';
import 'invoice_design.dart';

/// Compact picker for an original invoice when starting a return from the list.
///
/// Returns are always tied to a confirmed (or partially paid/paid) original
/// invoice; this dialog searches the list RPC and navigates to the existing
/// `/invoices/:id/return` route. No standalone return creation.
Future<void> showInvoiceOriginalPicker(
  BuildContext context, {
  required InvoiceType originalType,
}) async {
  final selectedId = await showDialog<String>(
    context: context,
    builder: (_) =>
        InvoiceOriginalInvoicePickerDialog(originalType: originalType),
  );
  if (selectedId == null || !context.mounted) return;
  context.go(AppRoutes.invoiceReturnPath(selectedId));
}

class InvoiceOriginalInvoicePickerDialog extends ConsumerStatefulWidget {
  const InvoiceOriginalInvoicePickerDialog({
    required this.originalType,
    super.key,
  });

  /// [InvoiceType.sales] or [InvoiceType.purchase] — the type to return against.
  final InvoiceType originalType;

  @override
  ConsumerState<InvoiceOriginalInvoicePickerDialog> createState() =>
      _InvoiceOriginalInvoicePickerDialogState();
}

class _InvoiceOriginalInvoicePickerDialogState
    extends ConsumerState<InvoiceOriginalInvoicePickerDialog> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<InvoiceSummary> _results = const [];
  bool _isLoading = false;
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool _isEligible(InvoiceSummary invoice) {
    if (invoice.type != widget.originalType) return false;
    return invoice.status == InvoiceStatus.confirmed ||
        invoice.status == InvoiceStatus.partiallyPaid ||
        invoice.status == InvoiceStatus.paid;
  }

  Future<void> _search(String query) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;

    setState(() {
      _isLoading = true;
      _errorCode = null;
    });

    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final filters = InvoiceFilters(
        type: widget.originalType,
        search: query.trim().isEmpty ? null : query.trim(),
      );
      final rows = switch (widget.originalType) {
        InvoiceType.sales => await repo.listSalesInvoices(
          session,
          filters: filters,
          page: const PaginationCursor(limit: 50),
        ),
        InvoiceType.purchase => await repo.listPurchaseInvoices(
          session,
          filters: filters,
          page: const PaginationCursor(limit: 50),
        ),
        _ => const <InvoiceSummary>[],
      };
      if (!mounted) return;
      setState(() {
        _results = rows.where(_isEligible).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorCode = 'load_failed';
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.invoicePickOriginalInvoiceTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InvoiceDesign.denseField(
                  context,
                  hint: l10n.invoicePickOriginalInvoiceSearch,
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 8),
              if (_isLoading) const LinearProgressIndicator(),
              if (_errorCode != null)
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
                  child: Text(
                    l10n.financeErrorUnknown,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Expanded(
                child: _results.isEmpty && !_isLoading
                    ? Center(
                        child: Text(
                          l10n.invoicePickOriginalInvoiceEmpty,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final invoice = _results[index];
                          final party = invoice.party == null
                              ? '—'
                              : partyDisplayName(
                                  locale,
                                  nameAr: invoice.party!.nameAr,
                                  nameEn: invoice.party!.nameEn,
                                );
                          return ListTile(
                            dense: true,
                            title: Text(
                              invoice.invoiceNumber ??
                                  invoiceTypeLabel(l10n, invoice.type),
                            ),
                            subtitle: Text(
                              '$party · ${MaterialLocalizations.of(context).formatMediumDate(invoice.date)}',
                            ),
                            trailing: Text(
                              invoiceStatusLabel(l10n, invoice.status),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            onTap: () => Navigator.pop(context, invoice.id),
                          );
                        },
                      ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
