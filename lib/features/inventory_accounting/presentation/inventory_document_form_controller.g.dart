// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_document_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$inventoryDocumentFormControllerHash() =>
    r'aefdd78ffb5f1815da6b601213a0ede47eeaecb8';

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

abstract class _$InventoryDocumentFormController
    extends BuildlessAutoDisposeNotifier<InventoryDocumentFormState> {
  late final InventoryDocumentFormMode mode;

  InventoryDocumentFormState build(InventoryDocumentFormMode mode);
}

/// See also [InventoryDocumentFormController].
@ProviderFor(InventoryDocumentFormController)
const inventoryDocumentFormControllerProvider =
    InventoryDocumentFormControllerFamily();

/// See also [InventoryDocumentFormController].
class InventoryDocumentFormControllerFamily
    extends Family<InventoryDocumentFormState> {
  /// See also [InventoryDocumentFormController].
  const InventoryDocumentFormControllerFamily();

  /// See also [InventoryDocumentFormController].
  InventoryDocumentFormControllerProvider call(InventoryDocumentFormMode mode) {
    return InventoryDocumentFormControllerProvider(mode);
  }

  @override
  InventoryDocumentFormControllerProvider getProviderOverride(
    covariant InventoryDocumentFormControllerProvider provider,
  ) {
    return call(provider.mode);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'inventoryDocumentFormControllerProvider';
}

/// See also [InventoryDocumentFormController].
class InventoryDocumentFormControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          InventoryDocumentFormController,
          InventoryDocumentFormState
        > {
  /// See also [InventoryDocumentFormController].
  InventoryDocumentFormControllerProvider(InventoryDocumentFormMode mode)
    : this._internal(
        () => InventoryDocumentFormController()..mode = mode,
        from: inventoryDocumentFormControllerProvider,
        name: r'inventoryDocumentFormControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$inventoryDocumentFormControllerHash,
        dependencies: InventoryDocumentFormControllerFamily._dependencies,
        allTransitiveDependencies:
            InventoryDocumentFormControllerFamily._allTransitiveDependencies,
        mode: mode,
      );

  InventoryDocumentFormControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.mode,
  }) : super.internal();

  final InventoryDocumentFormMode mode;

  @override
  InventoryDocumentFormState runNotifierBuild(
    covariant InventoryDocumentFormController notifier,
  ) {
    return notifier.build(mode);
  }

  @override
  Override overrideWith(InventoryDocumentFormController Function() create) {
    return ProviderOverride(
      origin: this,
      override: InventoryDocumentFormControllerProvider._internal(
        () => create()..mode = mode,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        mode: mode,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    InventoryDocumentFormController,
    InventoryDocumentFormState
  >
  createElement() {
    return _InventoryDocumentFormControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is InventoryDocumentFormControllerProvider &&
        other.mode == mode;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, mode.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin InventoryDocumentFormControllerRef
    on AutoDisposeNotifierProviderRef<InventoryDocumentFormState> {
  /// The parameter `mode` of this provider.
  InventoryDocumentFormMode get mode;
}

class _InventoryDocumentFormControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          InventoryDocumentFormController,
          InventoryDocumentFormState
        >
    with InventoryDocumentFormControllerRef {
  _InventoryDocumentFormControllerProviderElement(super.provider);

  @override
  InventoryDocumentFormMode get mode =>
      (origin as InventoryDocumentFormControllerProvider).mode;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
