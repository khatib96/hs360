// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_document_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$inventoryDocumentDetailControllerHash() =>
    r'e6da5034eed3ee3d98d066be6a934ae6dd2aaf38';

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

abstract class _$InventoryDocumentDetailController
    extends BuildlessAutoDisposeNotifier<InventoryDocumentDetailState> {
  late final String documentId;

  InventoryDocumentDetailState build(String documentId);
}

/// See also [InventoryDocumentDetailController].
@ProviderFor(InventoryDocumentDetailController)
const inventoryDocumentDetailControllerProvider =
    InventoryDocumentDetailControllerFamily();

/// See also [InventoryDocumentDetailController].
class InventoryDocumentDetailControllerFamily
    extends Family<InventoryDocumentDetailState> {
  /// See also [InventoryDocumentDetailController].
  const InventoryDocumentDetailControllerFamily();

  /// See also [InventoryDocumentDetailController].
  InventoryDocumentDetailControllerProvider call(String documentId) {
    return InventoryDocumentDetailControllerProvider(documentId);
  }

  @override
  InventoryDocumentDetailControllerProvider getProviderOverride(
    covariant InventoryDocumentDetailControllerProvider provider,
  ) {
    return call(provider.documentId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'inventoryDocumentDetailControllerProvider';
}

/// See also [InventoryDocumentDetailController].
class InventoryDocumentDetailControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          InventoryDocumentDetailController,
          InventoryDocumentDetailState
        > {
  /// See also [InventoryDocumentDetailController].
  InventoryDocumentDetailControllerProvider(String documentId)
    : this._internal(
        () => InventoryDocumentDetailController()..documentId = documentId,
        from: inventoryDocumentDetailControllerProvider,
        name: r'inventoryDocumentDetailControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$inventoryDocumentDetailControllerHash,
        dependencies: InventoryDocumentDetailControllerFamily._dependencies,
        allTransitiveDependencies:
            InventoryDocumentDetailControllerFamily._allTransitiveDependencies,
        documentId: documentId,
      );

  InventoryDocumentDetailControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.documentId,
  }) : super.internal();

  final String documentId;

  @override
  InventoryDocumentDetailState runNotifierBuild(
    covariant InventoryDocumentDetailController notifier,
  ) {
    return notifier.build(documentId);
  }

  @override
  Override overrideWith(InventoryDocumentDetailController Function() create) {
    return ProviderOverride(
      origin: this,
      override: InventoryDocumentDetailControllerProvider._internal(
        () => create()..documentId = documentId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        documentId: documentId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    InventoryDocumentDetailController,
    InventoryDocumentDetailState
  >
  createElement() {
    return _InventoryDocumentDetailControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is InventoryDocumentDetailControllerProvider &&
        other.documentId == documentId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, documentId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin InventoryDocumentDetailControllerRef
    on AutoDisposeNotifierProviderRef<InventoryDocumentDetailState> {
  /// The parameter `documentId` of this provider.
  String get documentId;
}

class _InventoryDocumentDetailControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          InventoryDocumentDetailController,
          InventoryDocumentDetailState
        >
    with InventoryDocumentDetailControllerRef {
  _InventoryDocumentDetailControllerProviderElement(super.provider);

  @override
  String get documentId =>
      (origin as InventoryDocumentDetailControllerProvider).documentId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
