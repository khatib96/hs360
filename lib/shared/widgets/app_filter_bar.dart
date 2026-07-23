import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

/// A consistent surface for feature-owned search and filter controls.
///
/// It deliberately does not know filter fields or query behavior.
class AppFilterBar extends StatelessWidget {
  const AppFilterBar({
    required this.child,
    this.trailing,
    this.compact = false,
    super.key,
  });

  final Widget child;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          border: Border.all(color: AppColors.neutral100),
          borderRadius: AppRadii.surfaceRadius,
        ),
        child: Padding(
          padding: compact
              ? const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                )
              : AppSpacing.cardCompact,
          child: trailing == null
              ? child
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 720) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          child,
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: trailing!,
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: child),
                        const SizedBox(width: AppSpacing.sm),
                        trailing!,
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}
