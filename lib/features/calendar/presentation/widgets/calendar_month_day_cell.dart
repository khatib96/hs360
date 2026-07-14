import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/app_theme.dart';

class CalendarMonthDayCell extends StatelessWidget {
  const CalendarMonthDayCell({
    required this.date,
    required this.isOutsideMonth,
    required this.isToday,
    required this.isSelected,
    required this.isDayOff,
    required this.hasConflict,
    required this.eventCountLabel,
    required this.overdueCountLabel,
    required this.unassignedCountLabel,
    required this.semanticsLabel,
    required this.onTap,
    this.isKeyboardFocused = false,
    super.key,
  });

  final DateTime date;
  final bool isOutsideMonth;
  final bool isToday;
  final bool isSelected;
  final bool isKeyboardFocused;
  final bool isDayOff;
  final bool hasConflict;
  final String? eventCountLabel;
  final String? overdueCountLabel;
  final String? unassignedCountLabel;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color? bg;
    if (isSelected) {
      bg = AppColors.gold.withValues(alpha: 0.2);
    } else if (isDayOff) {
      bg = AppColors.neutral100;
    }

    final Color borderColor;
    final double borderWidth;
    if (isKeyboardFocused) {
      borderColor = AppColors.gold;
      borderWidth = 3;
    } else if (isToday) {
      borderColor = AppColors.gold;
      borderWidth = 2;
    } else if (isSelected) {
      borderColor = AppColors.goldDeep;
      borderWidth = 2;
    } else {
      borderColor = AppColors.neutral200;
      borderWidth = 1;
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
      child: InkWell(
        key: Key('calendar-day-${date.year}-${date.month}-${date.day}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${date.day}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isOutsideMonth
                            ? AppColors.neutral400
                            : AppColors.ink,
                        fontWeight: isToday || isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (hasConflict)
                    Icon(
                      LucideIcons.triangle_alert,
                      size: 12,
                      color: AppColors.warning,
                    )
                  else if (isDayOff)
                    Icon(
                      LucideIcons.moon,
                      size: 12,
                      color: AppColors.neutral600,
                    ),
                ],
              ),
              if (eventCountLabel != null)
                Text(
                  eventCountLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              if (overdueCountLabel != null)
                Text(
                  overdueCountLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.error,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              if (unassignedCountLabel != null)
                Text(
                  unassignedCountLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.info,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
