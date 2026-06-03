// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$customerDetailControllerHash() =>
    r'e977012df037e2ca6467897dd2530691d3a9e4ce';

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

abstract class _$CustomerDetailController
    extends BuildlessAutoDisposeNotifier<CustomerDetailState> {
  late final String customerId;

  CustomerDetailState build(String customerId);
}

/// See also [CustomerDetailController].
@ProviderFor(CustomerDetailController)
const customerDetailControllerProvider = CustomerDetailControllerFamily();

/// See also [CustomerDetailController].
class CustomerDetailControllerFamily extends Family<CustomerDetailState> {
  /// See also [CustomerDetailController].
  const CustomerDetailControllerFamily();

  /// See also [CustomerDetailController].
  CustomerDetailControllerProvider call(String customerId) {
    return CustomerDetailControllerProvider(customerId);
  }

  @override
  CustomerDetailControllerProvider getProviderOverride(
    covariant CustomerDetailControllerProvider provider,
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
  String? get name => r'customerDetailControllerProvider';
}

/// See also [CustomerDetailController].
class CustomerDetailControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          CustomerDetailController,
          CustomerDetailState
        > {
  /// See also [CustomerDetailController].
  CustomerDetailControllerProvider(String customerId)
    : this._internal(
        () => CustomerDetailController()..customerId = customerId,
        from: customerDetailControllerProvider,
        name: r'customerDetailControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$customerDetailControllerHash,
        dependencies: CustomerDetailControllerFamily._dependencies,
        allTransitiveDependencies:
            CustomerDetailControllerFamily._allTransitiveDependencies,
        customerId: customerId,
      );

  CustomerDetailControllerProvider._internal(
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
  CustomerDetailState runNotifierBuild(
    covariant CustomerDetailController notifier,
  ) {
    return notifier.build(customerId);
  }

  @override
  Override overrideWith(CustomerDetailController Function() create) {
    return ProviderOverride(
      origin: this,
      override: CustomerDetailControllerProvider._internal(
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
    CustomerDetailController,
    CustomerDetailState
  >
  createElement() {
    return _CustomerDetailControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerDetailControllerProvider &&
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
mixin CustomerDetailControllerRef
    on AutoDisposeNotifierProviderRef<CustomerDetailState> {
  /// The parameter `customerId` of this provider.
  String get customerId;
}

class _CustomerDetailControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          CustomerDetailController,
          CustomerDetailState
        >
    with CustomerDetailControllerRef {
  _CustomerDetailControllerProviderElement(super.provider);

  @override
  String get customerId =>
      (origin as CustomerDetailControllerProvider).customerId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
