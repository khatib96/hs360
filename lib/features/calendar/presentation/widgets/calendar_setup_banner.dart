import 'package:flutter/material.dart';

class CalendarSetupBanner extends StatelessWidget {
  const CalendarSetupBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MaterialBanner(
        key: const Key('calendar-settings-setup-banner'),
        content: Text(message),
        leading: const Icon(Icons.info_outline),
        actions: const [SizedBox.shrink()],
      ),
    );
  }
}
