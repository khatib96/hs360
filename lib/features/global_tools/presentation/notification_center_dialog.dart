import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../auth/domain/app_session.dart';
import '../domain/app_notification.dart';
import 'notification_center_controller.dart';

Future<void> showNotificationCenter({
  required BuildContext context,
  required AppSession session,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => NotificationCenterDialog(session: session),
  );
}

class NotificationCenterDialog extends ConsumerWidget {
  const NotificationCenterDialog({required this.session, super.key});

  final AppSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncPage = ref.watch(notificationCenterControllerProvider(session));
    final controller = ref.read(
      notificationCenterControllerProvider(session).notifier,
    );
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final unreadCount = asyncPage.valueOrNull?.unreadCount ?? 0;

    return Dialog(
      insetPadding: EdgeInsets.all(narrow ? 12 : 40),
      alignment: Alignment.topRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.notificationCenterTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (unreadCount > 0)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: Chip(
                        label: Text(
                          l10n.notificationCenterUnreadCount(unreadCount),
                        ),
                      ),
                    ),
                  IconButton(
                    key: const Key('notification-center-refresh'),
                    tooltip: l10n.notificationCenterRefresh,
                    onPressed: controller.refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: asyncPage.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
                error: (_, _) => _NotificationMessage(
                  icon: Icons.cloud_off_outlined,
                  message: l10n.notificationCenterError,
                  action: FilledButton.tonal(
                    onPressed: controller.refresh,
                    child: Text(l10n.retry),
                  ),
                ),
                data: (page) => page.items.isEmpty
                    ? _NotificationMessage(
                        icon: Icons.notifications_none,
                        message: l10n.notificationCenterEmpty,
                      )
                    : ListView.separated(
                        key: const Key('notification-center-list'),
                        shrinkWrap: true,
                        itemCount: page.items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = page.items[index];
                          return _NotificationTile(
                            item: item,
                            onToggleRead: () =>
                                controller.setRead(item.id, !item.isRead),
                            onOpen: item.sourceRoute == null
                                ? null
                                : () async {
                                    if (!item.isRead) {
                                      await controller.setRead(item.id, true);
                                    }
                                    if (!context.mounted) return;
                                    final route = item.sourceRoute;
                                    if (route == null ||
                                        !route.startsWith('/')) {
                                      return;
                                    }
                                    final router = GoRouter.of(context);
                                    Navigator.of(context).pop();
                                    router.go(route);
                                  },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onToggleRead,
    this.onOpen,
  });

  final AppNotification item;
  final VoidCallback onToggleRead;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final local = item.createdAt.toLocal();
    final date = MaterialLocalizations.of(context).formatShortDate(local);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));

    return ColoredBox(
      color: item.isRead
          ? Colors.transparent
          : Theme.of(context).colorScheme.primaryContainer.withAlpha(80),
      child: ListTile(
        key: Key('notification-${item.id}'),
        isThreeLine: true,
        leading: Icon(
          item.isRead
              ? Icons.notifications_none
              : Icons.notifications_active_outlined,
        ),
        title: Text(
          item.subject,
          style: item.isRead
              ? null
              : const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${item.body(languageCode)}\n$date · $time'),
        onTap: onOpen,
        trailing: PopupMenuButton<String>(
          tooltip: l10n.shellGlobalActions,
          onSelected: (_) => onToggleRead(),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(
                item.isRead
                    ? l10n.notificationCenterMarkUnread
                    : l10n.notificationCenterMarkRead,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
