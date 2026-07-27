import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/app_session.dart';
import '../data/global_tools_repository.dart';
import '../domain/app_notification.dart';

final notificationCenterControllerProvider = StateNotifierProvider.autoDispose
    .family<
      NotificationCenterController,
      AsyncValue<AppNotificationPage>,
      AppSession
    >((ref, session) {
      final controller = NotificationCenterController(
        ref.read(globalToolsRepositoryProvider),
        session,
      );
      controller.refresh();
      return controller;
    });

class NotificationCenterController
    extends StateNotifier<AsyncValue<AppNotificationPage>> {
  NotificationCenterController(this._repository, this._session)
    : super(const AsyncLoading());

  final GlobalToolsRepository _repository;
  final AppSession _session;
  int _requestSerial = 0;

  Future<void> refresh() async {
    final serial = ++_requestSerial;
    try {
      final page = await _repository.listNotifications(_session);
      if (!mounted || serial != _requestSerial) return;
      state = AsyncData(page);
    } catch (error, stackTrace) {
      if (!mounted || serial != _requestSerial) return;
      state = AsyncError(error, stackTrace);
    }
  }

  Future<bool> setRead(String notificationId, bool isRead) async {
    try {
      final changed = await _repository.setNotificationRead(
        _session,
        notificationId,
        isRead: isRead,
      );
      if (changed && mounted) await refresh();
      return changed;
    } catch (error, stackTrace) {
      if (mounted) state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
