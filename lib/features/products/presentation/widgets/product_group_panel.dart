import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/product_group.dart';
import '../../domain/product_group_tree.dart';
import '../product_display_helpers.dart';

class ProductGroupPanel extends StatelessWidget {
  const ProductGroupPanel({
    required this.groups,
    required this.selectedGroupId,
    required this.languageCode,
    required this.canCreateGroup,
    required this.canEditGroup,
    required this.onGroupSelected,
    required this.onAddGroup,
    required this.onEditGroup,
    required this.onDeactivateGroup,
    super.key,
  });

  final List<ProductGroup> groups;
  final String? selectedGroupId;
  final String languageCode;
  final bool canCreateGroup;
  final bool canEditGroup;
  final ValueChanged<String?> onGroupSelected;
  final VoidCallback onAddGroup;
  final ValueChanged<ProductGroup> onEditGroup;
  final ValueChanged<ProductGroup> onDeactivateGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tree = buildProductGroupTree(groups);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        border: const BorderDirectional(
          start: BorderSide(color: AppColors.neutral200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.productsGroupsTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (canCreateGroup)
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    tooltip: l10n.productGroupAdd,
                    onPressed: onAddGroup,
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _GroupTile(
                  label: l10n.productsAllGroups,
                  selected: selectedGroupId == null,
                  onTap: () => onGroupSelected(null),
                ),
                ...tree.map(
                  (node) => _GroupTreeTile(
                    node: node,
                    depth: 0,
                    selectedGroupId: selectedGroupId,
                    languageCode: languageCode,
                    canEditGroup: canEditGroup,
                    onSelected: onGroupSelected,
                    onEdit: onEditGroup,
                    onDeactivate: onDeactivateGroup,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductGroupPanelCompact extends StatelessWidget {
  const ProductGroupPanelCompact({
    required this.groups,
    required this.selectedGroupId,
    required this.languageCode,
    required this.canCreateGroup,
    required this.canEditGroup,
    required this.onGroupSelected,
    required this.onAddGroup,
    required this.onEditGroup,
    required this.onDeactivateGroup,
    super.key,
  });

  final List<ProductGroup> groups;
  final String? selectedGroupId;
  final String languageCode;
  final bool canCreateGroup;
  final bool canEditGroup;
  final ValueChanged<String?> onGroupSelected;
  final VoidCallback onAddGroup;
  final ValueChanged<ProductGroup> onEditGroup;
  final ValueChanged<ProductGroup> onDeactivateGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tree = buildProductGroupTree(groups);

    return ExpansionTile(
      title: Text(l10n.productsGroupsTitle),
      initiallyExpanded: selectedGroupId != null,
      children: [
        if (canCreateGroup)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onAddGroup,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.productGroupAdd),
            ),
          ),
        _GroupTile(
          label: l10n.productsAllGroups,
          selected: selectedGroupId == null,
          onTap: () => onGroupSelected(null),
        ),
        ...tree.map(
          (node) => _GroupTreeTile(
            node: node,
            depth: 0,
            selectedGroupId: selectedGroupId,
            languageCode: languageCode,
            canEditGroup: canEditGroup,
            onSelected: onGroupSelected,
            onEdit: onEditGroup,
            onDeactivate: onDeactivateGroup,
          ),
        ),
      ],
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(8));

    return Material(
      color: selected
          ? AppColors.goldSoft.withValues(alpha: 0.6)
          : Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        shape: const RoundedRectangleBorder(borderRadius: borderRadius),
        tileColor: Colors.transparent,
        selected: selected,
        selectedTileColor: Colors.transparent,
        title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        onTap: onTap,
      ),
    );
  }
}

class _GroupTreeTile extends StatelessWidget {
  const _GroupTreeTile({
    required this.node,
    required this.depth,
    required this.selectedGroupId,
    required this.languageCode,
    required this.canEditGroup,
    required this.onSelected,
    required this.onEdit,
    required this.onDeactivate,
  });

  final ProductGroupTreeNode node;
  final int depth;
  final String? selectedGroupId;
  final String languageCode;
  final bool canEditGroup;
  final ValueChanged<String?> onSelected;
  final ValueChanged<ProductGroup> onEdit;
  final ValueChanged<ProductGroup> onDeactivate;

  @override
  Widget build(BuildContext context) {
    final group = node.group;
    final label = localizedGroupName(group, languageCode);
    final selected = selectedGroupId == group.id;

    const borderRadius = BorderRadius.all(Radius.circular(8));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: selected
              ? AppColors.goldSoft.withValues(alpha: 0.6)
              : Colors.transparent,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            dense: true,
            shape: const RoundedRectangleBorder(borderRadius: borderRadius),
            tileColor: Colors.transparent,
            selected: selected,
            selectedTileColor: Colors.transparent,
            contentPadding: EdgeInsetsDirectional.only(
              start: 12 + depth * 16.0,
              end: 4,
            ),
            title: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: group.isActive ? null : AppColors.neutral600,
              ),
            ),
            trailing: canEditGroup
                ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          onEdit(group);
                        case 'deactivate':
                          if (group.isActive) onDeactivate(group);
                      }
                    },
                    itemBuilder: (context) {
                      final l10n = AppLocalizations.of(context)!;
                      return [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(l10n.productGroupEdit),
                        ),
                        if (group.isActive)
                          PopupMenuItem(
                            value: 'deactivate',
                            child: Text(l10n.productGroupDeactivate),
                          ),
                      ];
                    },
                  )
                : null,
            onTap: () => onSelected(group.id),
          ),
        ),
        ...node.children.map(
          (child) => _GroupTreeTile(
            node: child,
            depth: depth + 1,
            selectedGroupId: selectedGroupId,
            languageCode: languageCode,
            canEditGroup: canEditGroup,
            onSelected: onSelected,
            onEdit: onEdit,
            onDeactivate: onDeactivate,
          ),
        ),
      ],
    );
  }
}
