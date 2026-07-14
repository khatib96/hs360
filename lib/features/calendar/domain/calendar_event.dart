import 'package:decimal/decimal.dart';

import 'calendar_available_actions.dart';
import 'calendar_enums.dart';
import 'calendar_execution_summary.dart';
import 'calendar_operational_metadata.dart';
import 'calendar_working_day.dart';

/// Calendar event summary row from list/range read RPCs.
///
/// Never includes `source_key`, `source_metadata`, or `scheduled_time`.
class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.type,
    required this.status,
    required this.sourceKind,
    required this.scheduledDate,
    required this.originalDueDate,
    required this.titleAr,
    this.titleEn,
    required this.isRescheduled,
    this.assignedAgentId,
    this.assignedAgentNameAr,
    this.assignedAgentNameEn,
    this.customerId,
    this.customerNameAr,
    this.customerNameEn,
    this.serviceLocationId,
    this.serviceLocationName,
    this.locationGovernorate,
    this.locationArea,
    this.contractId,
    this.contractNumber,
    this.contractLineId,
    this.productNameAr,
    this.productNameEn,
    this.qtyPerRefill,
    this.qtyUnit,
    this.operationalMetadata,
    required this.directionsAvailable,
    required this.scheduleState,
    required this.workingDay,
    required this.isOverdue,
    required this.overdueDays,
    required this.overdueState,
    required this.availableActions,
    this.executionSummary,
  });

  final String id;
  final CalendarEventType type;
  final CalendarEventStatus status;
  final CalendarEventSourceKind sourceKind;
  final DateTime scheduledDate;
  final DateTime originalDueDate;
  final String titleAr;
  final String? titleEn;
  final bool isRescheduled;
  final String? assignedAgentId;
  final String? assignedAgentNameAr;
  final String? assignedAgentNameEn;
  final String? customerId;
  final String? customerNameAr;
  final String? customerNameEn;
  final String? serviceLocationId;
  final String? serviceLocationName;
  final String? locationGovernorate;
  final String? locationArea;
  final String? contractId;
  final String? contractNumber;
  final String? contractLineId;
  final String? productNameAr;
  final String? productNameEn;
  final Decimal? qtyPerRefill;
  final String? qtyUnit;
  final CalendarOperationalMetadata? operationalMetadata;
  final bool directionsAvailable;
  final CalendarScheduleState scheduleState;
  final CalendarWorkingDay workingDay;
  final bool isOverdue;
  final int overdueDays;
  final CalendarOverdueState overdueState;
  final CalendarAvailableActions availableActions;
  final CalendarExecutionSummary? executionSummary;
}
