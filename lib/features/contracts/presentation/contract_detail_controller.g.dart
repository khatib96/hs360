// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contract_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$contractDetailControllerHash() =>
    r'b2366eb95d4f74193a47bed3c20f0e054b462c94';

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

abstract class _$ContractDetailController
    extends BuildlessAutoDisposeNotifier<ContractDetailState> {
  late final String contractId;

  ContractDetailState build(String contractId);
}

/// See also [ContractDetailController].
@ProviderFor(ContractDetailController)
const contractDetailControllerProvider = ContractDetailControllerFamily();

/// See also [ContractDetailController].
class ContractDetailControllerFamily extends Family<ContractDetailState> {
  /// See also [ContractDetailController].
  const ContractDetailControllerFamily();

  /// See also [ContractDetailController].
  ContractDetailControllerProvider call(String contractId) {
    return ContractDetailControllerProvider(contractId);
  }

  @override
  ContractDetailControllerProvider getProviderOverride(
    covariant ContractDetailControllerProvider provider,
  ) {
    return call(provider.contractId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'contractDetailControllerProvider';
}

/// See also [ContractDetailController].
class ContractDetailControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          ContractDetailController,
          ContractDetailState
        > {
  /// See also [ContractDetailController].
  ContractDetailControllerProvider(String contractId)
    : this._internal(
        () => ContractDetailController()..contractId = contractId,
        from: contractDetailControllerProvider,
        name: r'contractDetailControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$contractDetailControllerHash,
        dependencies: ContractDetailControllerFamily._dependencies,
        allTransitiveDependencies:
            ContractDetailControllerFamily._allTransitiveDependencies,
        contractId: contractId,
      );

  ContractDetailControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.contractId,
  }) : super.internal();

  final String contractId;

  @override
  ContractDetailState runNotifierBuild(
    covariant ContractDetailController notifier,
  ) {
    return notifier.build(contractId);
  }

  @override
  Override overrideWith(ContractDetailController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ContractDetailControllerProvider._internal(
        () => create()..contractId = contractId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        contractId: contractId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    ContractDetailController,
    ContractDetailState
  >
  createElement() {
    return _ContractDetailControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ContractDetailControllerProvider &&
        other.contractId == contractId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, contractId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ContractDetailControllerRef
    on AutoDisposeNotifierProviderRef<ContractDetailState> {
  /// The parameter `contractId` of this provider.
  String get contractId;
}

class _ContractDetailControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          ContractDetailController,
          ContractDetailState
        >
    with ContractDetailControllerRef {
  _ContractDetailControllerProviderElement(super.provider);

  @override
  String get contractId =>
      (origin as ContractDetailControllerProvider).contractId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
