// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$productFormControllerHash() =>
    r'15081a9d5302cf5556bd5310c4aa8351d6cd6fad';

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

abstract class _$ProductFormController
    extends BuildlessAutoDisposeNotifier<ProductFormUiState> {
  late final String? productId;

  ProductFormUiState build({String? productId});
}

/// See also [ProductFormController].
@ProviderFor(ProductFormController)
const productFormControllerProvider = ProductFormControllerFamily();

/// See also [ProductFormController].
class ProductFormControllerFamily extends Family<ProductFormUiState> {
  /// See also [ProductFormController].
  const ProductFormControllerFamily();

  /// See also [ProductFormController].
  ProductFormControllerProvider call({String? productId}) {
    return ProductFormControllerProvider(productId: productId);
  }

  @override
  ProductFormControllerProvider getProviderOverride(
    covariant ProductFormControllerProvider provider,
  ) {
    return call(productId: provider.productId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'productFormControllerProvider';
}

/// See also [ProductFormController].
class ProductFormControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          ProductFormController,
          ProductFormUiState
        > {
  /// See also [ProductFormController].
  ProductFormControllerProvider({String? productId})
    : this._internal(
        () => ProductFormController()..productId = productId,
        from: productFormControllerProvider,
        name: r'productFormControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$productFormControllerHash,
        dependencies: ProductFormControllerFamily._dependencies,
        allTransitiveDependencies:
            ProductFormControllerFamily._allTransitiveDependencies,
        productId: productId,
      );

  ProductFormControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.productId,
  }) : super.internal();

  final String? productId;

  @override
  ProductFormUiState runNotifierBuild(
    covariant ProductFormController notifier,
  ) {
    return notifier.build(productId: productId);
  }

  @override
  Override overrideWith(ProductFormController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ProductFormControllerProvider._internal(
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
  AutoDisposeNotifierProviderElement<ProductFormController, ProductFormUiState>
  createElement() {
    return _ProductFormControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductFormControllerProvider &&
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
mixin ProductFormControllerRef
    on AutoDisposeNotifierProviderRef<ProductFormUiState> {
  /// The parameter `productId` of this provider.
  String? get productId;
}

class _ProductFormControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          ProductFormController,
          ProductFormUiState
        >
    with ProductFormControllerRef {
  _ProductFormControllerProviderElement(super.provider);

  @override
  String? get productId => (origin as ProductFormControllerProvider).productId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
