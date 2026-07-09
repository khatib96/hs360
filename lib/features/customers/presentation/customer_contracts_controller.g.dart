// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_contracts_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$customerContractsControllerHash() =>
    r'e32e26185882dfe526c30ca4e5c22b47eb0e519e';

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

abstract class _$CustomerContractsController
    extends BuildlessAutoDisposeNotifier<CustomerContractsState> {
  late final String customerId;

  CustomerContractsState build(String customerId);
}

/// See also [CustomerContractsController].
@ProviderFor(CustomerContractsController)
const customerContractsControllerProvider = CustomerContractsControllerFamily();

/// See also [CustomerContractsController].
class CustomerContractsControllerFamily extends Family<CustomerContractsState> {
  /// See also [CustomerContractsController].
  const CustomerContractsControllerFamily();

  /// See also [CustomerContractsController].
  CustomerContractsControllerProvider call(String customerId) {
    return CustomerContractsControllerProvider(customerId);
  }

  @override
  CustomerContractsControllerProvider getProviderOverride(
    covariant CustomerContractsControllerProvider provider,
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
  String? get name => r'customerContractsControllerProvider';
}

/// See also [CustomerContractsController].
class CustomerContractsControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          CustomerContractsController,
          CustomerContractsState
        > {
  /// See also [CustomerContractsController].
  CustomerContractsControllerProvider(String customerId)
    : this._internal(
        () => CustomerContractsController()..customerId = customerId,
        from: customerContractsControllerProvider,
        name: r'customerContractsControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$customerContractsControllerHash,
        dependencies: CustomerContractsControllerFamily._dependencies,
        allTransitiveDependencies:
            CustomerContractsControllerFamily._allTransitiveDependencies,
        customerId: customerId,
      );

  CustomerContractsControllerProvider._internal(
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
  CustomerContractsState runNotifierBuild(
    covariant CustomerContractsController notifier,
  ) {
    return notifier.build(customerId);
  }

  @override
  Override overrideWith(CustomerContractsController Function() create) {
    return ProviderOverride(
      origin: this,
      override: CustomerContractsControllerProvider._internal(
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
    CustomerContractsController,
    CustomerContractsState
  >
  createElement() {
    return _CustomerContractsControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerContractsControllerProvider &&
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
mixin CustomerContractsControllerRef
    on AutoDisposeNotifierProviderRef<CustomerContractsState> {
  /// The parameter `customerId` of this provider.
  String get customerId;
}

class _CustomerContractsControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          CustomerContractsController,
          CustomerContractsState
        >
    with CustomerContractsControllerRef {
  _CustomerContractsControllerProviderElement(super.provider);

  @override
  String get customerId =>
      (origin as CustomerContractsControllerProvider).customerId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
