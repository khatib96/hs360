// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_unit_timeline_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$productUnitTimelineControllerHash() =>
    r'2d806665b28d81a62f63f45fa2e1ea542a6ea53f';

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

abstract class _$ProductUnitTimelineController
    extends BuildlessAutoDisposeNotifier<ProductUnitTimelineState> {
  late final String unitId;

  ProductUnitTimelineState build(String unitId);
}

/// See also [ProductUnitTimelineController].
@ProviderFor(ProductUnitTimelineController)
const productUnitTimelineControllerProvider =
    ProductUnitTimelineControllerFamily();

/// See also [ProductUnitTimelineController].
class ProductUnitTimelineControllerFamily
    extends Family<ProductUnitTimelineState> {
  /// See also [ProductUnitTimelineController].
  const ProductUnitTimelineControllerFamily();

  /// See also [ProductUnitTimelineController].
  ProductUnitTimelineControllerProvider call(String unitId) {
    return ProductUnitTimelineControllerProvider(unitId);
  }

  @override
  ProductUnitTimelineControllerProvider getProviderOverride(
    covariant ProductUnitTimelineControllerProvider provider,
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
  String? get name => r'productUnitTimelineControllerProvider';
}

/// See also [ProductUnitTimelineController].
class ProductUnitTimelineControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          ProductUnitTimelineController,
          ProductUnitTimelineState
        > {
  /// See also [ProductUnitTimelineController].
  ProductUnitTimelineControllerProvider(String unitId)
    : this._internal(
        () => ProductUnitTimelineController()..unitId = unitId,
        from: productUnitTimelineControllerProvider,
        name: r'productUnitTimelineControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$productUnitTimelineControllerHash,
        dependencies: ProductUnitTimelineControllerFamily._dependencies,
        allTransitiveDependencies:
            ProductUnitTimelineControllerFamily._allTransitiveDependencies,
        unitId: unitId,
      );

  ProductUnitTimelineControllerProvider._internal(
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
  ProductUnitTimelineState runNotifierBuild(
    covariant ProductUnitTimelineController notifier,
  ) {
    return notifier.build(unitId);
  }

  @override
  Override overrideWith(ProductUnitTimelineController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ProductUnitTimelineControllerProvider._internal(
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
    ProductUnitTimelineController,
    ProductUnitTimelineState
  >
  createElement() {
    return _ProductUnitTimelineControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductUnitTimelineControllerProvider &&
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
mixin ProductUnitTimelineControllerRef
    on AutoDisposeNotifierProviderRef<ProductUnitTimelineState> {
  /// The parameter `unitId` of this provider.
  String get unitId;
}

class _ProductUnitTimelineControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          ProductUnitTimelineController,
          ProductUnitTimelineState
        >
    with ProductUnitTimelineControllerRef {
  _ProductUnitTimelineControllerProviderElement(super.provider);

  @override
  String get unitId => (origin as ProductUnitTimelineControllerProvider).unitId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
