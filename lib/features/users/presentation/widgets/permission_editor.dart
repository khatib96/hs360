import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_detail_surface.dart';
import '../../../../shared/widgets/app_status_badge.dart';
import '../../domain/permission_catalog.dart';

String permissionCategoryLabel(AppLocalizations l10n, String category) {
  return switch (category) {
    'core' => l10n.permCategoryCore,
    'sales' => l10n.permCategorySales,
    'purchasing' => l10n.permCategoryPurchasing,
    'finance' => l10n.permCategoryFinance,
    'accounting' => l10n.permCategoryAccounting,
    'inventory' => l10n.permCategoryInventory,
    'calendar' => l10n.permCategoryCalendar,
    'communications' => l10n.permCategoryCommunications,
    'settings' => l10n.permCategorySettings,
    'security' => l10n.permCategorySecurity,
    _ => l10n.permCategoryOther,
  };
}

/// Grouped permission checkboxes with an explicit save step.
class PermissionEditor extends StatefulWidget {
  const PermissionEditor({
    required this.groups,
    required this.initial,
    required this.canChange,
    required this.onSave,
    required this.languageCode,
    super.key,
  });

  final List<PermissionGroup> groups;
  final Set<String> initial;
  final bool Function(String permissionId) canChange;
  final Future<bool> Function(Set<String> selected) onSave;
  final String languageCode;

  @override
  State<PermissionEditor> createState() => _PermissionEditorState();
}

class _PermissionEditorState extends State<PermissionEditor> {
  late Set<String> _selected = {...widget.initial};
  bool _saving = false;
  String _query = '';
  bool _sensitiveOnly = false;

  @override
  void didUpdateWidget(covariant PermissionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_setEquals(oldWidget.initial, widget.initial)) {
      _selected = {...widget.initial};
    }
  }

  int get _pendingChanges =>
      _selected.difference(widget.initial).length +
      widget.initial.difference(_selected).length;

  void _toggle(String id, bool value) {
    setState(() => value ? _selected.add(id) : _selected.remove(id));
  }

  /// Entries shown under the current search and sensitive-only filter.
  List<PermissionCatalogEntry> _visible(PermissionGroup group) {
    final query = _query.trim().toLowerCase();
    return [
      for (final entry in group.entries)
        if ((!_sensitiveOnly || entry.isSensitive) &&
            (query.isEmpty ||
                entry.id.toLowerCase().contains(query) ||
                entry.label(widget.languageCode).toLowerCase().contains(query)))
          entry,
    ];
  }

  void _setGroup(List<PermissionCatalogEntry> entries, bool value) {
    setState(() {
      for (final entry in entries) {
        if (!widget.canChange(entry.id)) continue;
        value ? _selected.add(entry.id) : _selected.remove(entry.id);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Permissions hidden from the editor keep their stored value.
    await widget.onSave({..._selected});
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final pending = _pendingChanges;
    final offered = {
      for (final group in widget.groups)
        for (final entry in group.entries) entry.id,
    };
    final visibleGroups = [
      for (final group in widget.groups)
        if (_visible(group).isNotEmpty)
          PermissionGroup(category: group.category, entries: _visible(group)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                key: const Key('permissions-search'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.usersSearchPermissions,
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            FilterChip(
              key: const Key('permissions-sensitive-only'),
              label: Text(l10n.usersSensitiveOnly),
              selected: _sensitiveOnly,
              onSelected: (value) => setState(() => _sensitiveOnly = value),
            ),
            Text(
              l10n.usersGrantedOf(
                _selected.intersection(offered).length,
                offered.length,
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (visibleGroups.isEmpty)
          Padding(
            padding: AppSpacing.cardCompact,
            child: Text(l10n.usersNoMatchingPermissions),
          ),
        for (final group in visibleGroups) ...[
          AppDetailSection(
            key: Key('permission-group-${group.category}'),
            title: permissionCategoryLabel(l10n, group.category),
            trailing: Wrap(
              spacing: AppSpacing.xs,
              children: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => _setGroup(group.entries, true),
                  child: Text(l10n.usersSelectAll),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => _setGroup(group.entries, false),
                  child: Text(l10n.usersClearAll),
                ),
              ],
            ),
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.xs,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (final entry in group.entries)
                    _PermissionTile(
                      entry: entry,
                      label: entry.label(widget.languageCode),
                      selected: _selected.contains(entry.id),
                      changeable: widget.canChange(entry.id),
                      busy: _saving,
                      notHeldHint: l10n.usersNotHeldHint,
                      sensitiveLabel: l10n.usersSensitive,
                      onChanged: (value) => _toggle(entry.id, value),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Material(
          color: AppColors.offWhite,
          borderRadius: AppRadii.surfaceRadius,
          child: Padding(
            padding: AppSpacing.cardCompact,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    pending == 0
                        ? l10n.usersNoPendingChanges
                        : l10n.usersPendingChanges(pending),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                FilledButton.icon(
                  key: const Key('permissions-save'),
                  onPressed: pending == 0 || _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(l10n.usersSavePermissions),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.entry,
    required this.label,
    required this.selected,
    required this.changeable,
    required this.busy,
    required this.notHeldHint,
    required this.sensitiveLabel,
    required this.onChanged,
  });

  final PermissionCatalogEntry entry;
  final String label;
  final bool selected;
  final bool changeable;
  final bool busy;
  final String notHeldHint;
  final String sensitiveLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tile = CheckboxListTile(
      key: Key('permission-${entry.id}'),
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: selected,
      onChanged: changeable && !busy
          ? (value) => onChanged(value ?? false)
          : null,
      title: Row(
        children: [
          Flexible(child: Text(label)),
          if (entry.isSensitive) ...[
            const SizedBox(width: AppSpacing.xs),
            AppStatusBadge(label: sensitiveLabel, tone: AppStatusTone.warning),
          ],
        ],
      ),
    );
    return changeable ? tile : Tooltip(message: notHeldHint, child: tile);
  }
}

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
