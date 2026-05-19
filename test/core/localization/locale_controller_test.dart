import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/localization/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('localeFromCode', () {
    test('null returns default ar', () {
      expect(localeFromCode(null), supportedLocaleAr);
    });

    test('en returns English locale', () {
      expect(localeFromCode('en'), supportedLocaleEn);
    });

    test('EN uppercase returns English locale', () {
      expect(localeFromCode('EN'), supportedLocaleEn);
    });

    test('invalid code returns default ar', () {
      expect(localeFromCode('fr'), supportedLocaleAr);
    });
  });

  group('normalizeLocale', () {
    test('normalizes ar', () {
      expect(normalizeLocale(const Locale('ar')), supportedLocaleAr);
    });

    test('unknown locale falls back to default', () {
      expect(normalizeLocale(const Locale('de')), supportedLocaleAr);
    });
  });

  group('localeTextDirection', () {
    test('Arabic is RTL', () {
      expect(localeTextDirection(supportedLocaleAr), TextDirection.rtl);
    });

    test('English is LTR', () {
      expect(localeTextDirection(supportedLocaleEn), TextDirection.ltr);
    });
  });

  group('LocaleRepository', () {
    test('load returns default when prefs empty', () async {
      final repo = LocaleRepository();
      expect(await repo.load(), supportedLocaleAr);
    });

    test('load returns saved en', () async {
      SharedPreferences.setMockInitialValues({preferredLocaleKey: 'en'});
      final repo = LocaleRepository();
      expect(await repo.load(), supportedLocaleEn);
    });

    test('save persists language code', () async {
      final repo = LocaleRepository();
      await repo.save(supportedLocaleEn);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(preferredLocaleKey), 'en');
    });
  });

  group('LocaleController', () {
    test('loads saved locale on startup', () async {
      SharedPreferences.setMockInitialValues({preferredLocaleKey: 'en'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final locale = await container.read(localeControllerProvider.future);
      expect(locale, supportedLocaleEn);
    });

    test('setLocale persists and updates state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(localeControllerProvider.future);
      await container
          .read(localeControllerProvider.notifier)
          .setLocale(supportedLocaleEn);

      expect(
        container.read(localeControllerProvider).valueOrNull,
        supportedLocaleEn,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(preferredLocaleKey), 'en');
    });

    test('localeProvider returns sync locale from controller', () async {
      SharedPreferences.setMockInitialValues({preferredLocaleKey: 'en'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(localeControllerProvider.future);
      expect(container.read(localeProvider), supportedLocaleEn);
    });

    test('localeProvider falls back to default while loading', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(localeProvider), supportedLocaleAr);
    });
  });
}
