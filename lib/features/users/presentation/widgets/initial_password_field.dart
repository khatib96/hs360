import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../users_messages.dart';

/// Password set by an admin for someone else: visible so it can be handed
/// over, with a generator for a strong random value.
class InitialPasswordField extends StatelessWidget {
  const InitialPasswordField({
    required this.label,
    required this.controller,
    super.key,
  });

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField(
            label: label,
            controller: controller,
            validator: (value) => validateNewPassword(l10n, value),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
          child: IconButton.outlined(
            key: const Key('generate-password'),
            tooltip: l10n.usersGeneratePassword,
            onPressed: () => controller.text = generatePassword(),
            icon: const Icon(Icons.casino_outlined),
          ),
        ),
      ],
    );
  }
}
