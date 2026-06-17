// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voucher_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$voucherDetailControllerHash() =>
    r'cf639dbb210a0deac847ac4492eda08ca15024e2';

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

abstract class _$VoucherDetailController
    extends BuildlessAutoDisposeNotifier<VoucherDetailState> {
  late final String voucherId;

  VoucherDetailState build(String voucherId);
}

/// See also [VoucherDetailController].
@ProviderFor(VoucherDetailController)
const voucherDetailControllerProvider = VoucherDetailControllerFamily();

/// See also [VoucherDetailController].
class VoucherDetailControllerFamily extends Family<VoucherDetailState> {
  /// See also [VoucherDetailController].
  const VoucherDetailControllerFamily();

  /// See also [VoucherDetailController].
  VoucherDetailControllerProvider call(String voucherId) {
    return VoucherDetailControllerProvider(voucherId);
  }

  @override
  VoucherDetailControllerProvider getProviderOverride(
    covariant VoucherDetailControllerProvider provider,
  ) {
    return call(provider.voucherId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'voucherDetailControllerProvider';
}

/// See also [VoucherDetailController].
class VoucherDetailControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          VoucherDetailController,
          VoucherDetailState
        > {
  /// See also [VoucherDetailController].
  VoucherDetailControllerProvider(String voucherId)
    : this._internal(
        () => VoucherDetailController()..voucherId = voucherId,
        from: voucherDetailControllerProvider,
        name: r'voucherDetailControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$voucherDetailControllerHash,
        dependencies: VoucherDetailControllerFamily._dependencies,
        allTransitiveDependencies:
            VoucherDetailControllerFamily._allTransitiveDependencies,
        voucherId: voucherId,
      );

  VoucherDetailControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.voucherId,
  }) : super.internal();

  final String voucherId;

  @override
  VoucherDetailState runNotifierBuild(
    covariant VoucherDetailController notifier,
  ) {
    return notifier.build(voucherId);
  }

  @override
  Override overrideWith(VoucherDetailController Function() create) {
    return ProviderOverride(
      origin: this,
      override: VoucherDetailControllerProvider._internal(
        () => create()..voucherId = voucherId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        voucherId: voucherId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    VoucherDetailController,
    VoucherDetailState
  >
  createElement() {
    return _VoucherDetailControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is VoucherDetailControllerProvider &&
        other.voucherId == voucherId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, voucherId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin VoucherDetailControllerRef
    on AutoDisposeNotifierProviderRef<VoucherDetailState> {
  /// The parameter `voucherId` of this provider.
  String get voucherId;
}

class _VoucherDetailControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          VoucherDetailController,
          VoucherDetailState
        >
    with VoucherDetailControllerRef {
  _VoucherDetailControllerProviderElement(super.provider);

  @override
  String get voucherId => (origin as VoucherDetailControllerProvider).voucherId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
