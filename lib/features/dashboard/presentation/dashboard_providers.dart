import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/app_session.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

final dashboardSummaryProvider = FutureProvider.autoDispose
    .family<DashboardSummary, AppSession>((ref, session) {
      return ref.watch(dashboardRepositoryProvider).getDashboard(session);
    });
