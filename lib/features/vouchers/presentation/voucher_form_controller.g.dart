// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voucher_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$voucherFormControllerHash() =>
    r'24e9aec72a17ee005720437afe580c07c70c9cb2';

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

abstract class _$VoucherFormController
    extends BuildlessAutoDisposeNotifier<ui.VoucherFormUiState> {
  late final VoucherType voucherType;

  ui.VoucherFormUiState build(VoucherType voucherType);
}

/// See also [VoucherFormController].
@ProviderFor(VoucherFormController)
const voucherFormControllerProvider = VoucherFormControllerFamily();

/// See also [VoucherFormController].
class VoucherFormControllerFamily extends Family<ui.VoucherFormUiState> {
  /// See also [VoucherFormController].
  const VoucherFormControllerFamily();

  /// See also [VoucherFormController].
  VoucherFormControllerProvider call(VoucherType voucherType) {
    return VoucherFormControllerProvider(voucherType);
  }

  @override
  VoucherFormControllerProvider getProviderOverride(
    covariant VoucherFormControllerProvider provider,
  ) {
    return call(provider.voucherType);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'voucherFormControllerProvider';
}

/// See also [VoucherFormController].
class VoucherFormControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          VoucherFormController,
          ui.VoucherFormUiState
        > {
  /// See also [VoucherFormController].
  VoucherFormControllerProvider(VoucherType voucherType)
    : this._internal(
        () => VoucherFormController()..voucherType = voucherType,
        from: voucherFormControllerProvider,
        name: r'voucherFormControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$voucherFormControllerHash,
        dependencies: VoucherFormControllerFamily._dependencies,
        allTransitiveDependencies:
            VoucherFormControllerFamily._allTransitiveDependencies,
        voucherType: voucherType,
      );

  VoucherFormControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.voucherType,
  }) : super.internal();

  final VoucherType voucherType;

  @override
  ui.VoucherFormUiState runNotifierBuild(
    covariant VoucherFormController notifier,
  ) {
    return notifier.build(voucherType);
  }

  @override
  Override overrideWith(VoucherFormController Function() create) {
    return ProviderOverride(
      origin: this,
      override: VoucherFormControllerProvider._internal(
        () => create()..voucherType = voucherType,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        voucherType: voucherType,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    VoucherFormController,
    ui.VoucherFormUiState
  >
  createElement() {
    return _VoucherFormControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is VoucherFormControllerProvider &&
        other.voucherType == voucherType;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, voucherType.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin VoucherFormControllerRef
    on AutoDisposeNotifierProviderRef<ui.VoucherFormUiState> {
  /// The parameter `voucherType` of this provider.
  VoucherType get voucherType;
}

class _VoucherFormControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          VoucherFormController,
          ui.VoucherFormUiState
        >
    with VoucherFormControllerRef {
  _VoucherFormControllerProviderElement(super.provider);

  @override
  VoucherType get voucherType =>
      (origin as VoucherFormControllerProvider).voucherType;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
