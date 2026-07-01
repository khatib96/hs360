// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_purchase_invoices_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$supplierPurchaseInvoicesControllerHash() =>
    r'c697e428b74b04e092aac6371b537b504a0e6b0b';

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

abstract class _$SupplierPurchaseInvoicesController
    extends BuildlessAutoDisposeNotifier<SupplierPurchaseInvoicesState> {
  late final String supplierId;

  SupplierPurchaseInvoicesState build(String supplierId);
}

/// See also [SupplierPurchaseInvoicesController].
@ProviderFor(SupplierPurchaseInvoicesController)
const supplierPurchaseInvoicesControllerProvider =
    SupplierPurchaseInvoicesControllerFamily();

/// See also [SupplierPurchaseInvoicesController].
class SupplierPurchaseInvoicesControllerFamily
    extends Family<SupplierPurchaseInvoicesState> {
  /// See also [SupplierPurchaseInvoicesController].
  const SupplierPurchaseInvoicesControllerFamily();

  /// See also [SupplierPurchaseInvoicesController].
  SupplierPurchaseInvoicesControllerProvider call(String supplierId) {
    return SupplierPurchaseInvoicesControllerProvider(supplierId);
  }

  @override
  SupplierPurchaseInvoicesControllerProvider getProviderOverride(
    covariant SupplierPurchaseInvoicesControllerProvider provider,
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
  String? get name => r'supplierPurchaseInvoicesControllerProvider';
}

/// See also [SupplierPurchaseInvoicesController].
class SupplierPurchaseInvoicesControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          SupplierPurchaseInvoicesController,
          SupplierPurchaseInvoicesState
        > {
  /// See also [SupplierPurchaseInvoicesController].
  SupplierPurchaseInvoicesControllerProvider(String supplierId)
    : this._internal(
        () => SupplierPurchaseInvoicesController()..supplierId = supplierId,
        from: supplierPurchaseInvoicesControllerProvider,
        name: r'supplierPurchaseInvoicesControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$supplierPurchaseInvoicesControllerHash,
        dependencies: SupplierPurchaseInvoicesControllerFamily._dependencies,
        allTransitiveDependencies:
            SupplierPurchaseInvoicesControllerFamily._allTransitiveDependencies,
        supplierId: supplierId,
      );

  SupplierPurchaseInvoicesControllerProvider._internal(
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
  SupplierPurchaseInvoicesState runNotifierBuild(
    covariant SupplierPurchaseInvoicesController notifier,
  ) {
    return notifier.build(supplierId);
  }

  @override
  Override overrideWith(SupplierPurchaseInvoicesController Function() create) {
    return ProviderOverride(
      origin: this,
      override: SupplierPurchaseInvoicesControllerProvider._internal(
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
    SupplierPurchaseInvoicesController,
    SupplierPurchaseInvoicesState
  >
  createElement() {
    return _SupplierPurchaseInvoicesControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SupplierPurchaseInvoicesControllerProvider &&
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
mixin SupplierPurchaseInvoicesControllerRef
    on AutoDisposeNotifierProviderRef<SupplierPurchaseInvoicesState> {
  /// The parameter `supplierId` of this provider.
  String get supplierId;
}

class _SupplierPurchaseInvoicesControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          SupplierPurchaseInvoicesController,
          SupplierPurchaseInvoicesState
        >
    with SupplierPurchaseInvoicesControllerRef {
  _SupplierPurchaseInvoicesControllerProviderElement(super.provider);

  @override
  String get supplierId =>
      (origin as SupplierPurchaseInvoicesControllerProvider).supplierId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
