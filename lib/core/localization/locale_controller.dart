import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';

final localeProvider = StateProvider<Locale>((ref) {
  return Locale(Env.defaultLocale);
});

void toggleLocale(WidgetRef ref) {
  final current = ref.read(localeProvider);
  final next = current.languageCode == 'ar'
      ? const Locale('en')
      : const Locale('ar');
  ref.read(localeProvider.notifier).state = next;
}

TextDirection localeTextDirection(Locale locale) {
  return locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
}
