// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contract_rental_collection_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$contractRentalCollectionControllerHash() =>
    r'1f0dd01b34836ae372426f86140d80362e64903f';

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

abstract class _$ContractRentalCollectionController
    extends BuildlessAutoDisposeNotifier<ContractRentalCollectionUiState> {
  late final String contractId;

  ContractRentalCollectionUiState build(String contractId);
}

/// See also [ContractRentalCollectionController].
@ProviderFor(ContractRentalCollectionController)
const contractRentalCollectionControllerProvider =
    ContractRentalCollectionControllerFamily();

/// See also [ContractRentalCollectionController].
class ContractRentalCollectionControllerFamily
    extends Family<ContractRentalCollectionUiState> {
  /// See also [ContractRentalCollectionController].
  const ContractRentalCollectionControllerFamily();

  /// See also [ContractRentalCollectionController].
  ContractRentalCollectionControllerProvider call(String contractId) {
    return ContractRentalCollectionControllerProvider(contractId);
  }

  @override
  ContractRentalCollectionControllerProvider getProviderOverride(
    covariant ContractRentalCollectionControllerProvider provider,
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
  String? get name => r'contractRentalCollectionControllerProvider';
}

/// See also [ContractRentalCollectionController].
class ContractRentalCollectionControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          ContractRentalCollectionController,
          ContractRentalCollectionUiState
        > {
  /// See also [ContractRentalCollectionController].
  ContractRentalCollectionControllerProvider(String contractId)
    : this._internal(
        () => ContractRentalCollectionController()..contractId = contractId,
        from: contractRentalCollectionControllerProvider,
        name: r'contractRentalCollectionControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$contractRentalCollectionControllerHash,
        dependencies: ContractRentalCollectionControllerFamily._dependencies,
        allTransitiveDependencies:
            ContractRentalCollectionControllerFamily._allTransitiveDependencies,
        contractId: contractId,
      );

  ContractRentalCollectionControllerProvider._internal(
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
  ContractRentalCollectionUiState runNotifierBuild(
    covariant ContractRentalCollectionController notifier,
  ) {
    return notifier.build(contractId);
  }

  @override
  Override overrideWith(ContractRentalCollectionController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ContractRentalCollectionControllerProvider._internal(
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
    ContractRentalCollectionController,
    ContractRentalCollectionUiState
  >
  createElement() {
    return _ContractRentalCollectionControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ContractRentalCollectionControllerProvider &&
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
mixin ContractRentalCollectionControllerRef
    on AutoDisposeNotifierProviderRef<ContractRentalCollectionUiState> {
  /// The parameter `contractId` of this provider.
  String get contractId;
}

class _ContractRentalCollectionControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          ContractRentalCollectionController,
          ContractRentalCollectionUiState
        >
    with ContractRentalCollectionControllerRef {
  _ContractRentalCollectionControllerProviderElement(super.provider);

  @override
  String get contractId =>
      (origin as ContractRentalCollectionControllerProvider).contractId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
