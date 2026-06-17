// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$invoiceFormControllerHash() =>
    r'3ad3cc50ef98efa604a8225f98defe817947e551';

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

abstract class _$InvoiceFormController
    extends BuildlessAutoDisposeNotifier<InvoiceFormUiState> {
  late final InvoiceType invoiceType;

  InvoiceFormUiState build(InvoiceType invoiceType);
}

/// See also [InvoiceFormController].
@ProviderFor(InvoiceFormController)
const invoiceFormControllerProvider = InvoiceFormControllerFamily();

/// See also [InvoiceFormController].
class InvoiceFormControllerFamily extends Family<InvoiceFormUiState> {
  /// See also [InvoiceFormController].
  const InvoiceFormControllerFamily();

  /// See also [InvoiceFormController].
  InvoiceFormControllerProvider call(InvoiceType invoiceType) {
    return InvoiceFormControllerProvider(invoiceType);
  }

  @override
  InvoiceFormControllerProvider getProviderOverride(
    covariant InvoiceFormControllerProvider provider,
  ) {
    return call(provider.invoiceType);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'invoiceFormControllerProvider';
}

/// See also [InvoiceFormController].
class InvoiceFormControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          InvoiceFormController,
          InvoiceFormUiState
        > {
  /// See also [InvoiceFormController].
  InvoiceFormControllerProvider(InvoiceType invoiceType)
    : this._internal(
        () => InvoiceFormController()..invoiceType = invoiceType,
        from: invoiceFormControllerProvider,
        name: r'invoiceFormControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$invoiceFormControllerHash,
        dependencies: InvoiceFormControllerFamily._dependencies,
        allTransitiveDependencies:
            InvoiceFormControllerFamily._allTransitiveDependencies,
        invoiceType: invoiceType,
      );

  InvoiceFormControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.invoiceType,
  }) : super.internal();

  final InvoiceType invoiceType;

  @override
  InvoiceFormUiState runNotifierBuild(
    covariant InvoiceFormController notifier,
  ) {
    return notifier.build(invoiceType);
  }

  @override
  Override overrideWith(InvoiceFormController Function() create) {
    return ProviderOverride(
      origin: this,
      override: InvoiceFormControllerProvider._internal(
        () => create()..invoiceType = invoiceType,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        invoiceType: invoiceType,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<InvoiceFormController, InvoiceFormUiState>
  createElement() {
    return _InvoiceFormControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is InvoiceFormControllerProvider &&
        other.invoiceType == invoiceType;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, invoiceType.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin InvoiceFormControllerRef
    on AutoDisposeNotifierProviderRef<InvoiceFormUiState> {
  /// The parameter `invoiceType` of this provider.
  InvoiceType get invoiceType;
}

class _InvoiceFormControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          InvoiceFormController,
          InvoiceFormUiState
        >
    with InvoiceFormControllerRef {
  _InvoiceFormControllerProviderElement(super.provider);

  @override
  InvoiceType get invoiceType =>
      (origin as InvoiceFormControllerProvider).invoiceType;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
