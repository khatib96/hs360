// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_vouchers_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$customerVouchersControllerHash() =>
    r'22856784f02013f40429fa96dff1f3bdd93fb830';

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

abstract class _$CustomerVouchersController
    extends BuildlessAutoDisposeNotifier<CustomerVouchersState> {
  late final String customerId;

  CustomerVouchersState build(String customerId);
}

/// See also [CustomerVouchersController].
@ProviderFor(CustomerVouchersController)
const customerVouchersControllerProvider = CustomerVouchersControllerFamily();

/// See also [CustomerVouchersController].
class CustomerVouchersControllerFamily extends Family<CustomerVouchersState> {
  /// See also [CustomerVouchersController].
  const CustomerVouchersControllerFamily();

  /// See also [CustomerVouchersController].
  CustomerVouchersControllerProvider call(String customerId) {
    return CustomerVouchersControllerProvider(customerId);
  }

  @override
  CustomerVouchersControllerProvider getProviderOverride(
    covariant CustomerVouchersControllerProvider provider,
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
  String? get name => r'customerVouchersControllerProvider';
}

/// See also [CustomerVouchersController].
class CustomerVouchersControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          CustomerVouchersController,
          CustomerVouchersState
        > {
  /// See also [CustomerVouchersController].
  CustomerVouchersControllerProvider(String customerId)
    : this._internal(
        () => CustomerVouchersController()..customerId = customerId,
        from: customerVouchersControllerProvider,
        name: r'customerVouchersControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$customerVouchersControllerHash,
        dependencies: CustomerVouchersControllerFamily._dependencies,
        allTransitiveDependencies:
            CustomerVouchersControllerFamily._allTransitiveDependencies,
        customerId: customerId,
      );

  CustomerVouchersControllerProvider._internal(
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
  CustomerVouchersState runNotifierBuild(
    covariant CustomerVouchersController notifier,
  ) {
    return notifier.build(customerId);
  }

  @override
  Override overrideWith(CustomerVouchersController Function() create) {
    return ProviderOverride(
      origin: this,
      override: CustomerVouchersControllerProvider._internal(
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
    CustomerVouchersController,
    CustomerVouchersState
  >
  createElement() {
    return _CustomerVouchersControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerVouchersControllerProvider &&
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
mixin CustomerVouchersControllerRef
    on AutoDisposeNotifierProviderRef<CustomerVouchersState> {
  /// The parameter `customerId` of this provider.
  String get customerId;
}

class _CustomerVouchersControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          CustomerVouchersController,
          CustomerVouchersState
        >
    with CustomerVouchersControllerRef {
  _CustomerVouchersControllerProviderElement(super.provider);

  @override
  String get customerId =>
      (origin as CustomerVouchersControllerProvider).customerId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
