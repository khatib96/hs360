import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';

part 'locale_controller.g.dart';

const preferredLocaleKey = 'preferred_locale';

const supportedLocaleAr = Locale('ar');
const supportedLocaleEn = Locale('en');

Locale _defaultLocale() {
  switch (Env.defaultLocale.toLowerCase()) {
    case 'ar':
      return supportedLocaleAr;
    case 'en':
      return supportedLocaleEn;
    default:
      return supportedLocaleAr;
  }
}

Locale normalizeLocale(Locale locale) {
  switch (locale.languageCode.toLowerCase()) {
    case 'ar':
      return supportedLocaleAr;
    case 'en':
      return supportedLocaleEn;
    default:
      return _defaultLocale();
  }
}

Locale localeFromCode(String? code) {
  switch (code?.toLowerCase()) {
    case 'ar':
      return supportedLocaleAr;
    case 'en':
      return supportedLocaleEn;
    default:
      return _defaultLocale();
  }
}

TextDirection localeTextDirection(Locale locale) {
  return locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
}

class LocaleRepository {
  Future<Locale> load() async {
    final prefs = await SharedPreferences.getInstance();
    return localeFromCode(prefs.getString(preferredLocaleKey));
  }

  Future<void> save(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      preferredLocaleKey,
      normalizeLocale(locale).languageCode,
    );
  }
}

@Riverpod(keepAlive: true)
LocaleRepository localeRepository(Ref ref) => LocaleRepository();

@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  @override
  FutureOr<Locale> build() async {
    return ref.read(localeRepositoryProvider).load();
  }

  Future<void> setLocale(Locale locale) async {
    final next = normalizeLocale(locale);
    state = AsyncData(next);
    await ref.read(localeRepositoryProvider).save(next);
  }
}

@Riverpod(keepAlive: true)
Locale locale(Ref ref) {
  return ref.watch(localeControllerProvider).valueOrNull ?? _defaultLocale();
}
