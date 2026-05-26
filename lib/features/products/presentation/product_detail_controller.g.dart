// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$productDetailControllerHash() =>
    r'0c10cc7a7296627e848a26c8a16c0f2de237dbe7';

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

abstract class _$ProductDetailController
    extends BuildlessAutoDisposeNotifier<ProductDetailUiState> {
  late final String productId;

  ProductDetailUiState build(String productId);
}

/// See also [ProductDetailController].
@ProviderFor(ProductDetailController)
const productDetailControllerProvider = ProductDetailControllerFamily();

/// See also [ProductDetailController].
class ProductDetailControllerFamily extends Family<ProductDetailUiState> {
  /// See also [ProductDetailController].
  const ProductDetailControllerFamily();

  /// See also [ProductDetailController].
  ProductDetailControllerProvider call(String productId) {
    return ProductDetailControllerProvider(productId);
  }

  @override
  ProductDetailControllerProvider getProviderOverride(
    covariant ProductDetailControllerProvider provider,
  ) {
    return call(provider.productId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'productDetailControllerProvider';
}

/// See also [ProductDetailController].
class ProductDetailControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          ProductDetailController,
          ProductDetailUiState
        > {
  /// See also [ProductDetailController].
  ProductDetailControllerProvider(String productId)
    : this._internal(
        () => ProductDetailController()..productId = productId,
        from: productDetailControllerProvider,
        name: r'productDetailControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$productDetailControllerHash,
        dependencies: ProductDetailControllerFamily._dependencies,
        allTransitiveDependencies:
            ProductDetailControllerFamily._allTransitiveDependencies,
        productId: productId,
      );

  ProductDetailControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.productId,
  }) : super.internal();

  final String productId;

  @override
  ProductDetailUiState runNotifierBuild(
    covariant ProductDetailController notifier,
  ) {
    return notifier.build(productId);
  }

  @override
  Override overrideWith(ProductDetailController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ProductDetailControllerProvider._internal(
        () => create()..productId = productId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        productId: productId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    ProductDetailController,
    ProductDetailUiState
  >
  createElement() {
    return _ProductDetailControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductDetailControllerProvider &&
        other.productId == productId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, productId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ProductDetailControllerRef
    on AutoDisposeNotifierProviderRef<ProductDetailUiState> {
  /// The parameter `productId` of this provider.
  String get productId;
}

class _ProductDetailControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          ProductDetailController,
          ProductDetailUiState
        >
    with ProductDetailControllerRef {
  _ProductDetailControllerProviderElement(super.provider);

  @override
  String get productId => (origin as ProductDetailControllerProvider).productId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
