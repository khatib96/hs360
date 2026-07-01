// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_invoices_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$customerInvoicesControllerHash() =>
    r'f8ee6d74182b9dba33d134abcacbef7ef5187210';

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

abstract class _$CustomerInvoicesController
    extends BuildlessAutoDisposeNotifier<CustomerInvoicesState> {
  late final String customerId;

  CustomerInvoicesState build(String customerId);
}

/// See also [CustomerInvoicesController].
@ProviderFor(CustomerInvoicesController)
const customerInvoicesControllerProvider = CustomerInvoicesControllerFamily();

/// See also [CustomerInvoicesController].
class CustomerInvoicesControllerFamily extends Family<CustomerInvoicesState> {
  /// See also [CustomerInvoicesController].
  const CustomerInvoicesControllerFamily();

  /// See also [CustomerInvoicesController].
  CustomerInvoicesControllerProvider call(String customerId) {
    return CustomerInvoicesControllerProvider(customerId);
  }

  @override
  CustomerInvoicesControllerProvider getProviderOverride(
    covariant CustomerInvoicesControllerProvider provider,
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
  String? get name => r'customerInvoicesControllerProvider';
}

/// See also [CustomerInvoicesController].
class CustomerInvoicesControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          CustomerInvoicesController,
          CustomerInvoicesState
        > {
  /// See also [CustomerInvoicesController].
  CustomerInvoicesControllerProvider(String customerId)
    : this._internal(
        () => CustomerInvoicesController()..customerId = customerId,
        from: customerInvoicesControllerProvider,
        name: r'customerInvoicesControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$customerInvoicesControllerHash,
        dependencies: CustomerInvoicesControllerFamily._dependencies,
        allTransitiveDependencies:
            CustomerInvoicesControllerFamily._allTransitiveDependencies,
        customerId: customerId,
      );

  CustomerInvoicesControllerProvider._internal(
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
  CustomerInvoicesState runNotifierBuild(
    covariant CustomerInvoicesController notifier,
  ) {
    return notifier.build(customerId);
  }

  @override
  Override overrideWith(CustomerInvoicesController Function() create) {
    return ProviderOverride(
      origin: this,
      override: CustomerInvoicesControllerProvider._internal(
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
    CustomerInvoicesController,
    CustomerInvoicesState
  >
  createElement() {
    return _CustomerInvoicesControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerInvoicesControllerProvider &&
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
mixin CustomerInvoicesControllerRef
    on AutoDisposeNotifierProviderRef<CustomerInvoicesState> {
  /// The parameter `customerId` of this provider.
  String get customerId;
}

class _CustomerInvoicesControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          CustomerInvoicesController,
          CustomerInvoicesState
        >
    with CustomerInvoicesControllerRef {
  _CustomerInvoicesControllerProviderElement(super.provider);

  @override
  String get customerId =>
      (origin as CustomerInvoicesControllerProvider).customerId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
