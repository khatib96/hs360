// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$supplierDetailControllerHash() =>
    r'9c2bd0e893a005ac823d7f724f7cfb812bf4cb97';

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

abstract class _$SupplierDetailController
    extends BuildlessAutoDisposeNotifier<SupplierDetailState> {
  late final String supplierId;

  SupplierDetailState build(String supplierId);
}

/// See also [SupplierDetailController].
@ProviderFor(SupplierDetailController)
const supplierDetailControllerProvider = SupplierDetailControllerFamily();

/// See also [SupplierDetailController].
class SupplierDetailControllerFamily extends Family<SupplierDetailState> {
  /// See also [SupplierDetailController].
  const SupplierDetailControllerFamily();

  /// See also [SupplierDetailController].
  SupplierDetailControllerProvider call(String supplierId) {
    return SupplierDetailControllerProvider(supplierId);
  }

  @override
  SupplierDetailControllerProvider getProviderOverride(
    covariant SupplierDetailControllerProvider provider,
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
  String? get name => r'supplierDetailControllerProvider';
}

/// See also [SupplierDetailController].
class SupplierDetailControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          SupplierDetailController,
          SupplierDetailState
        > {
  /// See also [SupplierDetailController].
  SupplierDetailControllerProvider(String supplierId)
    : this._internal(
        () => SupplierDetailController()..supplierId = supplierId,
        from: supplierDetailControllerProvider,
        name: r'supplierDetailControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$supplierDetailControllerHash,
        dependencies: SupplierDetailControllerFamily._dependencies,
        allTransitiveDependencies:
            SupplierDetailControllerFamily._allTransitiveDependencies,
        supplierId: supplierId,
      );

  SupplierDetailControllerProvider._internal(
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
  SupplierDetailState runNotifierBuild(
    covariant SupplierDetailController notifier,
  ) {
    return notifier.build(supplierId);
  }

  @override
  Override overrideWith(SupplierDetailController Function() create) {
    return ProviderOverride(
      origin: this,
      override: SupplierDetailControllerProvider._internal(
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
    SupplierDetailController,
    SupplierDetailState
  >
  createElement() {
    return _SupplierDetailControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SupplierDetailControllerProvider &&
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
mixin SupplierDetailControllerRef
    on AutoDisposeNotifierProviderRef<SupplierDetailState> {
  /// The parameter `supplierId` of this provider.
  String get supplierId;
}

class _SupplierDetailControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          SupplierDetailController,
          SupplierDetailState
        >
    with SupplierDetailControllerRef {
  _SupplierDetailControllerProviderElement(super.provider);

  @override
  String get supplierId =>
      (origin as SupplierDetailControllerProvider).supplierId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
