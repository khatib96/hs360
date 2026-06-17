// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$journalDetailControllerHash() =>
    r'24761d5b255065dc69e5aa4b58de19e2730e392c';

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

abstract class _$JournalDetailController
    extends BuildlessAutoDisposeNotifier<JournalDetailState> {
  late final String entryId;

  JournalDetailState build(String entryId);
}

/// See also [JournalDetailController].
@ProviderFor(JournalDetailController)
const journalDetailControllerProvider = JournalDetailControllerFamily();

/// See also [JournalDetailController].
class JournalDetailControllerFamily extends Family<JournalDetailState> {
  /// See also [JournalDetailController].
  const JournalDetailControllerFamily();

  /// See also [JournalDetailController].
  JournalDetailControllerProvider call(String entryId) {
    return JournalDetailControllerProvider(entryId);
  }

  @override
  JournalDetailControllerProvider getProviderOverride(
    covariant JournalDetailControllerProvider provider,
  ) {
    return call(provider.entryId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'journalDetailControllerProvider';
}

/// See also [JournalDetailController].
class JournalDetailControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          JournalDetailController,
          JournalDetailState
        > {
  /// See also [JournalDetailController].
  JournalDetailControllerProvider(String entryId)
    : this._internal(
        () => JournalDetailController()..entryId = entryId,
        from: journalDetailControllerProvider,
        name: r'journalDetailControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$journalDetailControllerHash,
        dependencies: JournalDetailControllerFamily._dependencies,
        allTransitiveDependencies:
            JournalDetailControllerFamily._allTransitiveDependencies,
        entryId: entryId,
      );

  JournalDetailControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.entryId,
  }) : super.internal();

  final String entryId;

  @override
  JournalDetailState runNotifierBuild(
    covariant JournalDetailController notifier,
  ) {
    return notifier.build(entryId);
  }

  @override
  Override overrideWith(JournalDetailController Function() create) {
    return ProviderOverride(
      origin: this,
      override: JournalDetailControllerProvider._internal(
        () => create()..entryId = entryId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        entryId: entryId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    JournalDetailController,
    JournalDetailState
  >
  createElement() {
    return _JournalDetailControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is JournalDetailControllerProvider && other.entryId == entryId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, entryId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin JournalDetailControllerRef
    on AutoDisposeNotifierProviderRef<JournalDetailState> {
  /// The parameter `entryId` of this provider.
  String get entryId;
}

class _JournalDetailControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          JournalDetailController,
          JournalDetailState
        >
    with JournalDetailControllerRef {
  _JournalDetailControllerProviderElement(super.provider);

  @override
  String get entryId => (origin as JournalDetailControllerProvider).entryId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
