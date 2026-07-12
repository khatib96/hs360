// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contract_convert_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$contractConvertControllerHash() =>
    r'83c2af1eb4358dc9b827b766064efab1f2dba0de';

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

abstract class _$ContractConvertController
    extends BuildlessAutoDisposeNotifier<ContractConvertUiState> {
  late final String trialContractId;

  ContractConvertUiState build(String trialContractId);
}

/// See also [ContractConvertController].
@ProviderFor(ContractConvertController)
const contractConvertControllerProvider = ContractConvertControllerFamily();

/// See also [ContractConvertController].
class ContractConvertControllerFamily extends Family<ContractConvertUiState> {
  /// See also [ContractConvertController].
  const ContractConvertControllerFamily();

  /// See also [ContractConvertController].
  ContractConvertControllerProvider call(String trialContractId) {
    return ContractConvertControllerProvider(trialContractId);
  }

  @override
  ContractConvertControllerProvider getProviderOverride(
    covariant ContractConvertControllerProvider provider,
  ) {
    return call(provider.trialContractId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'contractConvertControllerProvider';
}

/// See also [ContractConvertController].
class ContractConvertControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          ContractConvertController,
          ContractConvertUiState
        > {
  /// See also [ContractConvertController].
  ContractConvertControllerProvider(String trialContractId)
    : this._internal(
        () => ContractConvertController()..trialContractId = trialContractId,
        from: contractConvertControllerProvider,
        name: r'contractConvertControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$contractConvertControllerHash,
        dependencies: ContractConvertControllerFamily._dependencies,
        allTransitiveDependencies:
            ContractConvertControllerFamily._allTransitiveDependencies,
        trialContractId: trialContractId,
      );

  ContractConvertControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.trialContractId,
  }) : super.internal();

  final String trialContractId;

  @override
  ContractConvertUiState runNotifierBuild(
    covariant ContractConvertController notifier,
  ) {
    return notifier.build(trialContractId);
  }

  @override
  Override overrideWith(ContractConvertController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ContractConvertControllerProvider._internal(
        () => create()..trialContractId = trialContractId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        trialContractId: trialContractId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    ContractConvertController,
    ContractConvertUiState
  >
  createElement() {
    return _ContractConvertControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ContractConvertControllerProvider &&
        other.trialContractId == trialContractId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, trialContractId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ContractConvertControllerRef
    on AutoDisposeNotifierProviderRef<ContractConvertUiState> {
  /// The parameter `trialContractId` of this provider.
  String get trialContractId;
}

class _ContractConvertControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          ContractConvertController,
          ContractConvertUiState
        >
    with ContractConvertControllerRef {
  _ContractConvertControllerProviderElement(super.provider);

  @override
  String get trialContractId =>
      (origin as ContractConvertControllerProvider).trialContractId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
