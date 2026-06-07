// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_unit_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$productUnitDetailControllerHash() =>
    r'8facef70877ebdfb3fedd7b49aa7d4c62491fa31';

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

abstract class _$ProductUnitDetailController
    extends BuildlessAutoDisposeNotifier<ProductUnitDetailUiState> {
  late final String unitId;

  ProductUnitDetailUiState build(String unitId);
}

/// See also [ProductUnitDetailController].
@ProviderFor(ProductUnitDetailController)
const productUnitDetailControllerProvider = ProductUnitDetailControllerFamily();

/// See also [ProductUnitDetailController].
class ProductUnitDetailControllerFamily
    extends Family<ProductUnitDetailUiState> {
  /// See also [ProductUnitDetailController].
  const ProductUnitDetailControllerFamily();

  /// See also [ProductUnitDetailController].
  ProductUnitDetailControllerProvider call(String unitId) {
    return ProductUnitDetailControllerProvider(unitId);
  }

  @override
  ProductUnitDetailControllerProvider getProviderOverride(
    covariant ProductUnitDetailControllerProvider provider,
  ) {
    return call(provider.unitId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'productUnitDetailControllerProvider';
}

/// See also [ProductUnitDetailController].
class ProductUnitDetailControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          ProductUnitDetailController,
          ProductUnitDetailUiState
        > {
  /// See also [ProductUnitDetailController].
  ProductUnitDetailControllerProvider(String unitId)
    : this._internal(
        () => ProductUnitDetailController()..unitId = unitId,
        from: productUnitDetailControllerProvider,
        name: r'productUnitDetailControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$productUnitDetailControllerHash,
        dependencies: ProductUnitDetailControllerFamily._dependencies,
        allTransitiveDependencies:
            ProductUnitDetailControllerFamily._allTransitiveDependencies,
        unitId: unitId,
      );

  ProductUnitDetailControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.unitId,
  }) : super.internal();

  final String unitId;

  @override
  ProductUnitDetailUiState runNotifierBuild(
    covariant ProductUnitDetailController notifier,
  ) {
    return notifier.build(unitId);
  }

  @override
  Override overrideWith(ProductUnitDetailController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ProductUnitDetailControllerProvider._internal(
        () => create()..unitId = unitId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        unitId: unitId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    ProductUnitDetailController,
    ProductUnitDetailUiState
  >
  createElement() {
    return _ProductUnitDetailControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductUnitDetailControllerProvider &&
        other.unitId == unitId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, unitId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ProductUnitDetailControllerRef
    on AutoDisposeNotifierProviderRef<ProductUnitDetailUiState> {
  /// The parameter `unitId` of this provider.
  String get unitId;
}

class _ProductUnitDetailControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          ProductUnitDetailController,
          ProductUnitDetailUiState
        >
    with ProductUnitDetailControllerRef {
  _ProductUnitDetailControllerProviderElement(super.provider);

  @override
  String get unitId => (origin as ProductUnitDetailControllerProvider).unitId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
