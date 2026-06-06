import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/app_session.dart';
import '../../domain/chart_account_policy.dart';
import '../../domain/chart_account_tree.dart';
import '../chart_account_display_helpers.dart';
import 'chart_account_badges.dart';

class ChartAccountTreeView extends StatelessWidget {
  const ChartAccountTreeView({
    required this.nodes,
    required this.expandedIds,
    required this.languageCode,
    required this.session,
    required this.onToggleExpanded,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
  });

  final List<ChartAccountTreeNode> nodes;
  final Set<String> expandedIds;
  final String languageCode;
  final AppSession session;
  final ValueChanged<String> onToggleExpanded;
  final ValueChanged<ChartAccountTreeNode> onEdit;
  final ValueChanged<ChartAccountTreeNode> onDeactivate;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) return const SizedBox.shrink();

    return ListView(
      key: const Key('chart-account-tree-view'),
      children: nodes
          .map(
            (node) => ChartAccountTreeTile(
              node: node,
              depth: 0,
              expandedIds: expandedIds,
              languageCode: languageCode,
              session: session,
              onToggleExpanded: onToggleExpanded,
              onEdit: onEdit,
              onDeactivate: onDeactivate,
            ),
          )
          .toList(),
    );
  }
}

class ChartAccountTreeTile extends StatelessWidget {
  const ChartAccountTreeTile({
    required this.node,
    required this.depth,
    required this.expandedIds,
    required this.languageCode,
    required this.session,
    required this.onToggleExpanded,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
  });

  final ChartAccountTreeNode node;
  final int depth;
  final Set<String> expandedIds;
  final String languageCode;
  final AppSession session;
  final ValueChanged<String> onToggleExpanded;
  final ValueChanged<ChartAccountTreeNode> onEdit;
  final ValueChanged<ChartAccountTreeNode> onDeactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final account = node.account;
    final hasChildren = node.children.isNotEmpty;
    final expanded = expandedIds.contains(account.id);
    final actions = deriveAllowedActions(account, session);
    final badges = deriveAccountBadges(account);
    final name = localizedAccountName(account, languageCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: Key('chart-account-tile-${account.id}'),
          dense: true,
          contentPadding: EdgeInsetsDirectional.only(
            start: 8 + depth * 20.0,
            end: 4,
          ),
          leading: hasChildren
              ? IconButton(
                  icon: Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                  ),
                  onPressed: () => onToggleExpanded(account.id),
                  tooltip: expanded
                      ? l10n.chartAccountCollapse
                      : l10n.chartAccountExpand,
                )
              : SizedBox(width: 40),
          title: Row(
            children: [
              Text(
                account.code,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: account.isActive ? null : AppColors.neutral600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: account.isActive ? null : AppColors.neutral600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsetsDirectional.only(top: 4),
            child: ChartAccountBadges(badges: badges),
          ),
          trailing: (actions.canEdit || actions.canDeactivate)
              ? PopupMenuButton<String>(
                  key: Key('chart-account-actions-${account.id}'),
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (action) {
                    switch (action) {
                      case 'edit':
                        if (actions.canEdit) onEdit(node);
                      case 'deactivate':
                        if (actions.canDeactivate) onDeactivate(node);
                    }
                  },
                  itemBuilder: (context) {
                    final l10n = AppLocalizations.of(context)!;
                    return [
                      if (actions.canEdit)
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(l10n.chartAccountEdit),
                        ),
                      if (actions.canDeactivate)
                        PopupMenuItem(
                          value: 'deactivate',
                          child: Text(l10n.chartAccountDeactivate),
                        ),
                    ];
                  },
                )
              : null,
        ),
        if (hasChildren && expanded)
          ...node.children.map(
            (child) => ChartAccountTreeTile(
              node: child,
              depth: depth + 1,
              expandedIds: expandedIds,
              languageCode: languageCode,
              session: session,
              onToggleExpanded: onToggleExpanded,
              onEdit: onEdit,
              onDeactivate: onDeactivate,
            ),
          ),
      ],
    );
  }
}
