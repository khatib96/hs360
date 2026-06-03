import 'package:flutter/material.dart';

import '../../../../shared/widgets/message_banner.dart';

class CustomerModuleEmptyState extends StatelessWidget {
  const CustomerModuleEmptyState({
    required this.denied,
    required this.deniedMessage,
    required this.emptyMessage,
    super.key,
  });

  final bool denied;
  final String deniedMessage;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (denied) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: MessageBanner(
            variant: MessageBannerVariant.info,
            message: deniedMessage,
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Text(
          emptyMessage,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
