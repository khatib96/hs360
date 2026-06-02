// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_locations_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$customerLocationsControllerHash() =>
    r'0ae0783697ed7c293d387ad8c6c3c8e41fe33efe';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$CustomerLocationsController
    extends BuildlessAutoDisposeNotifier<CustomerLocationsState> {
  late final String customerId;

  CustomerLocationsState build(String customerId);
}

/// See also [CustomerLocationsController].
@ProviderFor(CustomerLocationsController)
const customerLocationsControllerProvider = CustomerLocationsControllerFamily();

/// See also [CustomerLocationsController].
class CustomerLocationsControllerFamily extends Family<CustomerLocationsState> {
  /// See also [CustomerLocationsController].
  const CustomerLocationsControllerFamily();

  /// See also [CustomerLocationsController].
  CustomerLocationsControllerProvider call(String customerId) {
    return CustomerLocationsControllerProvider(customerId);
  }

  @override
  CustomerLocationsControllerProvider getProviderOverride(
    covariant CustomerLocationsControllerProvider provider,
  ) {
    return call(provider.customerId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'customerLocationsControllerProvider';
}

/// See also [CustomerLocationsController].
class CustomerLocationsControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          CustomerLocationsController,
          CustomerLocationsState
        > {
  /// See also [CustomerLocationsController].
  CustomerLocationsControllerProvider(String customerId)
    : this._internal(
        () => CustomerLocationsController()..customerId = customerId,
        from: customerLocationsControllerProvider,
        name: r'customerLocationsControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$customerLocationsControllerHash,
        dependencies: CustomerLocationsControllerFamily._dependencies,
        allTransitiveDependencies:
            CustomerLocationsControllerFamily._allTransitiveDependencies,
        customerId: customerId,
      );

  CustomerLocationsControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.customerId,
  }) : super.internal();

  final String customerId;

  @override
  CustomerLocationsState runNotifierBuild(
    covariant CustomerLocationsController notifier,
  ) {
    return notifier.build(customerId);
  }

  @override
  Override overrideWith(CustomerLocationsController Function() create) {
    return ProviderOverride(
      origin: this,
      override: CustomerLocationsControllerProvider._internal(
        () => create()..customerId = customerId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        customerId: customerId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    CustomerLocationsController,
    CustomerLocationsState
  >
  createElement() {
    return _CustomerLocationsControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerLocationsControllerProvider &&
        other.customerId == customerId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, customerId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CustomerLocationsControllerRef
    on AutoDisposeNotifierProviderRef<CustomerLocationsState> {
  /// The parameter `customerId` of this provider.
  String get customerId;
}

class _CustomerLocationsControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          CustomerLocationsController,
          CustomerLocationsState
        >
    with CustomerLocationsControllerRef {
  _CustomerLocationsControllerProviderElement(super.provider);

  @override
  String get customerId =>
      (origin as CustomerLocationsControllerProvider).customerId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
