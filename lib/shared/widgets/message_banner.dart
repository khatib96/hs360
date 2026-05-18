import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import 'error_banner.dart';

enum MessageBannerVariant { error, success, info }

/// Localized status banner for errors, success, or info messages.
class MessageBanner extends StatelessWidget {
  const MessageBanner({
    required this.variant,
    required this.message,
    super.key,
  });

  final MessageBannerVariant variant;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (variant == MessageBannerVariant.error) {
      return ErrorBanner(message: message);
    }

    final (Color color, IconData icon) = switch (variant) {
      MessageBannerVariant.success => (
        AppColors.success,
        LucideIcons.checkCircle2,
      ),
      MessageBannerVariant.info => (AppColors.info, LucideIcons.info),
      MessageBannerVariant.error => (AppColors.error, Icons.error_outline),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
