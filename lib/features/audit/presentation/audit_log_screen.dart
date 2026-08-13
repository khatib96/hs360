import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_state_view.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/audit_log_repository.dart';
import '../domain/audit_log_entry.dart';
import '../domain/audit_log_filters.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  final _searchController = TextEditingController();
  late DateTimeRange _range;
  AuditLogFilters _filters = const AuditLogFilters();
  String? _draftModule;
  String? _draftAction;
  AuditLogPage? _page;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    _range = DateTimeRange(
      start: day.subtract(const Duration(days: 29)),
      end: day,
    );
    _filters = AuditLogFilters(dateFrom: _range.start, dateTo: _range.end);
    ref.listenManual(authControllerProvider, (previous, next) {
      final before = previous?.valueOrNull;
      final after = next.valueOrNull;
      if (after != null && _identityChanged(before, after)) _refresh();
    });
    Future.microtask(_refresh);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _identityChanged(AppSession? before, AppSession after) {
    return before == null ||
        before.userId != after.userId ||
        before.tenantId != after.tenantId ||
        before.tenantUserId != after.tenantUserId ||
        before.permissions != after.permissions;
  }

  Future<void> _refresh() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;
    final serial = ++_requestSerial;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final page = await ref
          .read(auditLogRepositoryProvider)
          .list(session, filters: _filters);
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } on AuditLogException catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _loading = false;
        _error = error.code;
      });
    } catch (_) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _loading = false;
        _error = AuditLogException.unavailable;
      });
    }
  }

  Future<void> _loadMore() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    final current = _page;
    if (session == null ||
        current == null ||
        !current.hasMore ||
        current.nextBeforeAt == null ||
        current.nextBeforeId == null ||
        _loadingMore) {
      return;
    }
    final serial = _requestSerial;
    setState(() => _loadingMore = true);
    try {
      final next = await ref
          .read(auditLogRepositoryProvider)
          .list(
            session,
            filters: _filters,
            beforeAt: current.nextBeforeAt,
            beforeId: current.nextBeforeId,
          );
      if (!mounted || serial != _requestSerial || current != _page) return;
      setState(() {
        _page = AuditLogPage(
          timezoneName: next.timezoneName,
          items: [...current.items, ...next.items],
          hasMore: next.hasMore,
          nextBeforeAt: next.nextBeforeAt,
          nextBeforeId: next.nextBeforeId,
        );
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && serial == _requestSerial) {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _applyFilters() {
    _filters = AuditLogFilters(
      module: _draftModule,
      action: _draftAction,
      dateFrom: _range.start,
      dateTo: _range.end,
      search: _searchController.text.trim(),
    );
    _refresh();
  }

  void _clearFilters() {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    setState(() {
      _draftModule = null;
      _draftAction = null;
      _searchController.clear();
      _range = DateTimeRange(
        start: day.subtract(const Duration(days: 29)),
        end: day,
      );
      _filters = AuditLogFilters(dateFrom: _range.start, dateTo: _range.end);
    });
    _refresh();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppShell(
      title: l10n.auditLogTitle,
      currentRoute: AppRoutes.auditLog,
      moduleActions: [
        IconButton(
          key: const Key('audit-log-refresh'),
          tooltip: l10n.auditRefresh,
          onPressed: _loading ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Padding(
        padding: AppSpacing.pageWide,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPageHeader(
                  title: l10n.auditLogTitle,
                  subtitle: l10n.auditLogSubtitle,
                  eyebrow: _page?.timezoneName.isNotEmpty == true
                      ? l10n.auditTimezone(_page!.timezoneName)
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildFilters(l10n),
                const SizedBox(height: AppSpacing.md),
                Expanded(child: _buildBody(l10n)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(AppLocalizations l10n) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMd(locale);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppSpacing.cardCompact,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                key: const Key('audit-search'),
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: l10n.auditSearchLabel,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onSubmitted: (_) => _applyFilters(),
              ),
            ),
            _AuditDropdown(
              key: const Key('audit-module-filter'),
              label: l10n.auditModuleFilter,
              value: _draftModule,
              options: _auditModules,
              labelFor: (value) => auditModuleLabel(l10n, value),
              onChanged: (value) => setState(() => _draftModule = value),
            ),
            _AuditDropdown(
              key: const Key('audit-action-filter'),
              label: l10n.auditActionFilter,
              value: _draftAction,
              options: _auditActions,
              labelFor: (value) => auditActionLabel(l10n, value),
              onChanged: (value) => setState(() => _draftAction = value),
            ),
            OutlinedButton.icon(
              key: const Key('audit-date-filter'),
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                '${date.format(_range.start)} – ${date.format(_range.end)}',
              ),
            ),
            FilledButton.icon(
              key: const Key('audit-apply-filters'),
              onPressed: _loading ? null : _applyFilters,
              icon: const Icon(Icons.filter_alt_outlined),
              label: Text(l10n.auditApplyFilters),
            ),
            TextButton(
              key: const Key('audit-clear-filters'),
              onPressed: _loading ? null : _clearFilters,
              child: Text(l10n.auditClearFilters),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading && _page == null) {
      return AppStateView.loading(message: l10n.loading);
    }
    if (_error != null && _page == null) {
      return AppStateView.error(
        message: _error == AuditLogException.permissionDenied
            ? l10n.auditPermissionDenied
            : l10n.auditLoadError,
        action: FilledButton(onPressed: _refresh, child: Text(l10n.retry)),
      );
    }
    final page = _page;
    if (page == null || page.items.isEmpty) {
      return AppStateView.empty(
        message: l10n.auditEmpty,
        icon: Icons.fact_check_outlined,
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            key: const Key('audit-log-list'),
            itemCount: page.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _AuditEntryCard(
              entry: page.items[index],
              onOpen: (route) => context.push(route),
            ),
          ),
        ),
        if (page.hasMore) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const Key('audit-load-more'),
            onPressed: _loadingMore ? null : _loadMore,
            icon: _loadingMore
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: Text(l10n.loadMore),
          ),
        ],
      ],
    );
  }
}

class _AuditDropdown extends StatelessWidget {
  const _AuditDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.labelFor,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String? value;
  final List<String> options;
  final String Function(String value) labelFor;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: value ?? '',
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem(value: '', child: Text(l10n.auditAll)),
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(labelFor(option))),
        ],
        onChanged: (next) =>
            onChanged(next == null || next.isEmpty ? null : next),
      ),
    );
  }
}

class _AuditEntryCard extends StatelessWidget {
  const _AuditEntryCard({required this.entry, required this.onOpen});

  final AuditLogEntry entry;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final route = entry.sourceRoute;
    final actor = entry.actorId == null
        ? l10n.auditSystemActor
        : entry.actorName;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Icon(auditModuleIcon(entry.module), size: 20),
        ),
        title: Text(
          '${auditActionLabel(l10n, entry.action)} · ${auditEntityLabel(l10n, entry.entityType)}',
        ),
        subtitle: Text('$actor · ${entry.localTime}'),
        trailing: route == null
            ? null
            : IconButton(
                tooltip: l10n.auditOpenSource,
                onPressed: () => onOpen(route),
                icon: const Icon(Icons.open_in_new_rounded),
              ),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entry.reason != null) ...[
            Text(
              l10n.auditReason,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(entry.reason!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (!entry.sourceVisible)
            Text(
              l10n.auditSourceRedacted,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            )
          else ...[
            if (entry.beforeSummary.isNotEmpty)
              _AuditSummary(
                label: l10n.auditBefore,
                values: entry.beforeSummary.values,
              ),
            if (entry.afterSummary.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _AuditSummary(
                label: l10n.auditAfter,
                values: entry.afterSummary.values,
              ),
            ],
            if (entry.changedFields.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.auditChangedFields(entry.changedFields.length)),
            ],
          ],
        ],
      ),
    );
  }
}

class _AuditSummary extends StatelessWidget {
  const _AuditSummary({required this.label, required this.values});

  final String label;
  final Iterable<Object?> values;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = values
        .where((value) => value != null)
        .map<String>((value) {
          if (value == true) return l10n.auditValueYes;
          if (value == false) return l10n.auditValueNo;
          return value.toString();
        })
        .where((value) => value.trim().isNotEmpty)
        .join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xxs),
        Text(text),
      ],
    );
  }
}

const _auditModules = <String>[
  'parties',
  'contracts',
  'finance',
  'inventory',
  'calendar',
  'settings',
  'security',
  'field_ops',
  'system',
];

const _auditActions = <String>[
  'insert',
  'update',
  'delete',
  'create',
  'cancel',
  'assign',
];

String auditModuleLabel(AppLocalizations l10n, String module) =>
    switch (module) {
      'parties' => l10n.navCustomersSuppliers,
      'contracts' => l10n.navContracts,
      'finance' => l10n.navFinance,
      'inventory' => l10n.navInventory,
      'calendar' => l10n.navCalendar,
      'settings' => l10n.navSettings,
      'security' => l10n.auditModuleSecurity,
      'field_ops' => l10n.navAppointmentsVisits,
      _ => l10n.auditModuleSystem,
    };

String auditActionLabel(AppLocalizations l10n, String action) =>
    switch (action) {
      'insert' || 'create' => l10n.auditActionCreate,
      'update' => l10n.auditActionUpdate,
      'delete' => l10n.auditActionDelete,
      'cancel' => l10n.auditActionCancel,
      'assign' => l10n.auditActionAssign,
      _ => l10n.auditActionOther,
    };

String auditEntityLabel(AppLocalizations l10n, String entityType) =>
    switch (entityType) {
      'customers' || 'customer_service_locations' => l10n.customers,
      'suppliers' => l10n.suppliers,
      'contracts' ||
      'contract_lines' ||
      'contract_oil_changes' => l10n.navContracts,
      'invoices' || 'invoice_lines' => l10n.navInvoices,
      'vouchers' || 'voucher_invoice_allocations' => l10n.navVouchers,
      'journal_entries' || 'journal_lines' => l10n.navJournal,
      'products' || 'product_groups' => l10n.products,
      'product_units' => l10n.auditEntityProductUnits,
      'warehouses' => l10n.warehouses,
      'inventory_documents' ||
      'inventory_document_lines' => l10n.inventoryDocumentsTitle,
      'inventory_movements' => l10n.inventoryMovements,
      'calendar_events' => l10n.navCalendar,
      'tenant_users' ||
      'user_permissions' ||
      'employees' => l10n.auditEntityUsers,
      'visits' => l10n.navAppointmentsVisits,
      _ => l10n.auditEntitySettings,
    };

IconData auditModuleIcon(String module) => switch (module) {
  'parties' => Icons.groups_outlined,
  'contracts' => Icons.assignment_outlined,
  'finance' => Icons.account_balance_outlined,
  'inventory' => Icons.inventory_2_outlined,
  'calendar' => Icons.calendar_month_outlined,
  'settings' => Icons.settings_outlined,
  'security' => Icons.admin_panel_settings_outlined,
  'field_ops' => Icons.route_outlined,
  _ => Icons.memory_outlined,
};
