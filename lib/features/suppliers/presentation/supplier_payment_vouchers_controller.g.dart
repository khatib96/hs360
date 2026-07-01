// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_payment_vouchers_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$supplierPaymentVouchersControllerHash() =>
    r'53a7c5a7b2803b3f119deb90824a06c6380c93cd';

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

abstract class _$SupplierPaymentVouchersController
    extends BuildlessAutoDisposeNotifier<SupplierPaymentVouchersState> {
  late final String supplierId;

  SupplierPaymentVouchersState build(String supplierId);
}

/// See also [SupplierPaymentVouchersController].
@ProviderFor(SupplierPaymentVouchersController)
const supplierPaymentVouchersControllerProvider =
    SupplierPaymentVouchersControllerFamily();

/// See also [SupplierPaymentVouchersController].
class SupplierPaymentVouchersControllerFamily
    extends Family<SupplierPaymentVouchersState> {
  /// See also [SupplierPaymentVouchersController].
  const SupplierPaymentVouchersControllerFamily();

  /// See also [SupplierPaymentVouchersController].
  SupplierPaymentVouchersControllerProvider call(String supplierId) {
    return SupplierPaymentVouchersControllerProvider(supplierId);
  }

  @override
  SupplierPaymentVouchersControllerProvider getProviderOverride(
    covariant SupplierPaymentVouchersControllerProvider provider,
  ) {
    return call(provider.supplierId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'supplierPaymentVouchersControllerProvider';
}

/// See also [SupplierPaymentVouchersController].
class SupplierPaymentVouchersControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          SupplierPaymentVouchersController,
          SupplierPaymentVouchersState
        > {
  /// See also [SupplierPaymentVouchersController].
  SupplierPaymentVouchersControllerProvider(String supplierId)
    : this._internal(
        () => SupplierPaymentVouchersController()..supplierId = supplierId,
        from: supplierPaymentVouchersControllerProvider,
        name: r'supplierPaymentVouchersControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$supplierPaymentVouchersControllerHash,
        dependencies: SupplierPaymentVouchersControllerFamily._dependencies,
        allTransitiveDependencies:
            SupplierPaymentVouchersControllerFamily._allTransitiveDependencies,
        supplierId: supplierId,
      );

  SupplierPaymentVouchersControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.supplierId,
  }) : super.internal();

  final String supplierId;

  @override
  SupplierPaymentVouchersState runNotifierBuild(
    covariant SupplierPaymentVouchersController notifier,
  ) {
    return notifier.build(supplierId);
  }

  @override
  Override overrideWith(SupplierPaymentVouchersController Function() create) {
    return ProviderOverride(
      origin: this,
      override: SupplierPaymentVouchersControllerProvider._internal(
        () => create()..supplierId = supplierId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        supplierId: supplierId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    SupplierPaymentVouchersController,
    SupplierPaymentVouchersState
  >
  createElement() {
    return _SupplierPaymentVouchersControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SupplierPaymentVouchersControllerProvider &&
        other.supplierId == supplierId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, supplierId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SupplierPaymentVouchersControllerRef
    on AutoDisposeNotifierProviderRef<SupplierPaymentVouchersState> {
  /// The parameter `supplierId` of this provider.
  String get supplierId;
}

class _SupplierPaymentVouchersControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          SupplierPaymentVouchersController,
          SupplierPaymentVouchersState
        >
    with SupplierPaymentVouchersControllerRef {
  _SupplierPaymentVouchersControllerProviderElement(super.provider);

  @override
  String get supplierId =>
      (origin as SupplierPaymentVouchersControllerProvider).supplierId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
