// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$localeRepositoryHash() => r'2c0f1f0a7fe1a5a091b5e9da420d7202828cae05';

/// See also [localeRepository].
@ProviderFor(localeRepository)
final localeRepositoryProvider = Provider<LocaleRepository>.internal(
  localeRepository,
  name: r'localeRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$localeRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LocaleRepositoryRef = ProviderRef<LocaleRepository>;
String _$localeHash() => r'98716d912893619b024193576e1622971f360e7c';

/// See also [locale].
@ProviderFor(locale)
final localeProvider = Provider<Locale>.internal(
  locale,
  name: r'localeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$localeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LocaleRef = ProviderRef<Locale>;
String _$localeControllerHash() => r'cb8412ee50442e0ff7ae0d938d476711fb7c9d23';

/// See also [LocaleController].
@ProviderFor(LocaleController)
final localeControllerProvider =
    AsyncNotifierProvider<LocaleController, Locale>.internal(
      LocaleController.new,
      name: r'localeControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$localeControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LocaleController = AsyncNotifier<Locale>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
