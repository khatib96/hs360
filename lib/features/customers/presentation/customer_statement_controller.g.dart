// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_statement_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$customerStatementControllerHash() =>
    r'da6ff9eba38a1b46077a2b82ce11cb8bc3847138';

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

abstract class _$CustomerStatementController
    extends BuildlessAutoDisposeNotifier<CustomerStatementState> {
  late final String customerId;

  CustomerStatementState build(String customerId);
}

/// See also [CustomerStatementController].
@ProviderFor(CustomerStatementController)
const customerStatementControllerProvider = CustomerStatementControllerFamily();

/// See also [CustomerStatementController].
class CustomerStatementControllerFamily extends Family<CustomerStatementState> {
  /// See also [CustomerStatementController].
  const CustomerStatementControllerFamily();

  /// See also [CustomerStatementController].
  CustomerStatementControllerProvider call(String customerId) {
    return CustomerStatementControllerProvider(customerId);
  }

  @override
  CustomerStatementControllerProvider getProviderOverride(
    covariant CustomerStatementControllerProvider provider,
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
  String? get name => r'customerStatementControllerProvider';
}

/// See also [CustomerStatementController].
class CustomerStatementControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          CustomerStatementController,
          CustomerStatementState
        > {
  /// See also [CustomerStatementController].
  CustomerStatementControllerProvider(String customerId)
    : this._internal(
        () => CustomerStatementController()..customerId = customerId,
        from: customerStatementControllerProvider,
        name: r'customerStatementControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$customerStatementControllerHash,
        dependencies: CustomerStatementControllerFamily._dependencies,
        allTransitiveDependencies:
            CustomerStatementControllerFamily._allTransitiveDependencies,
        customerId: customerId,
      );

  CustomerStatementControllerProvider._internal(
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
  CustomerStatementState runNotifierBuild(
    covariant CustomerStatementController notifier,
  ) {
    return notifier.build(customerId);
  }

  @override
  Override overrideWith(CustomerStatementController Function() create) {
    return ProviderOverride(
      origin: this,
      override: CustomerStatementControllerProvider._internal(
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
    CustomerStatementController,
    CustomerStatementState
  >
  createElement() {
    return _CustomerStatementControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerStatementControllerProvider &&
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
mixin CustomerStatementControllerRef
    on AutoDisposeNotifierProviderRef<CustomerStatementState> {
  /// The parameter `customerId` of this provider.
  String get customerId;
}

class _CustomerStatementControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          CustomerStatementController,
          CustomerStatementState
        >
    with CustomerStatementControllerRef {
  _CustomerStatementControllerProviderElement(super.provider);

  @override
  String get customerId =>
      (origin as CustomerStatementControllerProvider).customerId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
