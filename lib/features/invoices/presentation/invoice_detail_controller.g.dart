// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$invoiceDetailControllerHash() =>
    r'284f68ce7768b2890a20e39e9129b179b70eebc5';

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

abstract class _$InvoiceDetailController
    extends BuildlessAutoDisposeNotifier<InvoiceDetailState> {
  late final String invoiceId;
  late final InvoiceType? type;

  InvoiceDetailState build(String invoiceId, {InvoiceType? type});
}

/// See also [InvoiceDetailController].
@ProviderFor(InvoiceDetailController)
const invoiceDetailControllerProvider = InvoiceDetailControllerFamily();

/// See also [InvoiceDetailController].
class InvoiceDetailControllerFamily extends Family<InvoiceDetailState> {
  /// See also [InvoiceDetailController].
  const InvoiceDetailControllerFamily();

  /// See also [InvoiceDetailController].
  InvoiceDetailControllerProvider call(String invoiceId, {InvoiceType? type}) {
    return InvoiceDetailControllerProvider(invoiceId, type: type);
  }

  @override
  InvoiceDetailControllerProvider getProviderOverride(
    covariant InvoiceDetailControllerProvider provider,
  ) {
    return call(provider.invoiceId, type: provider.type);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'invoiceDetailControllerProvider';
}

/// See also [InvoiceDetailController].
class InvoiceDetailControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          InvoiceDetailController,
          InvoiceDetailState
        > {
  /// See also [InvoiceDetailController].
  InvoiceDetailControllerProvider(String invoiceId, {InvoiceType? type})
    : this._internal(
        () => InvoiceDetailController()
          ..invoiceId = invoiceId
          ..type = type,
        from: invoiceDetailControllerProvider,
        name: r'invoiceDetailControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$invoiceDetailControllerHash,
        dependencies: InvoiceDetailControllerFamily._dependencies,
        allTransitiveDependencies:
            InvoiceDetailControllerFamily._allTransitiveDependencies,
        invoiceId: invoiceId,
        type: type,
      );

  InvoiceDetailControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.invoiceId,
    required this.type,
  }) : super.internal();

  final String invoiceId;
  final InvoiceType? type;

  @override
  InvoiceDetailState runNotifierBuild(
    covariant InvoiceDetailController notifier,
  ) {
    return notifier.build(invoiceId, type: type);
  }

  @override
  Override overrideWith(InvoiceDetailController Function() create) {
    return ProviderOverride(
      origin: this,
      override: InvoiceDetailControllerProvider._internal(
        () => create()
          ..invoiceId = invoiceId
          ..type = type,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        invoiceId: invoiceId,
        type: type,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    InvoiceDetailController,
    InvoiceDetailState
  >
  createElement() {
    return _InvoiceDetailControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is InvoiceDetailControllerProvider &&
        other.invoiceId == invoiceId &&
        other.type == type;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, invoiceId.hashCode);
    hash = _SystemHash.combine(hash, type.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin InvoiceDetailControllerRef
    on AutoDisposeNotifierProviderRef<InvoiceDetailState> {
  /// The parameter `invoiceId` of this provider.
  String get invoiceId;

  /// The parameter `type` of this provider.
  InvoiceType? get type;
}

class _InvoiceDetailControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          InvoiceDetailController,
          InvoiceDetailState
        >
    with InvoiceDetailControllerRef {
  _InvoiceDetailControllerProviderElement(super.provider);

  @override
  String get invoiceId => (origin as InvoiceDetailControllerProvider).invoiceId;
  @override
  InvoiceType? get type => (origin as InvoiceDetailControllerProvider).type;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
