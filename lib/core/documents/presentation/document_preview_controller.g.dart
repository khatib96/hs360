// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_preview_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$documentPreviewControllerHash() =>
    r'135f3ca86c5a647d82532f5f0c863c5ed5ebc1dd';

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

abstract class _$DocumentPreviewController
    extends BuildlessAutoDisposeNotifier<DocumentPreviewState> {
  late final DocumentPreviewArgs args;

  DocumentPreviewState build(DocumentPreviewArgs args);
}

/// See also [DocumentPreviewController].
@ProviderFor(DocumentPreviewController)
const documentPreviewControllerProvider = DocumentPreviewControllerFamily();

/// See also [DocumentPreviewController].
class DocumentPreviewControllerFamily extends Family<DocumentPreviewState> {
  /// See also [DocumentPreviewController].
  const DocumentPreviewControllerFamily();

  /// See also [DocumentPreviewController].
  DocumentPreviewControllerProvider call(DocumentPreviewArgs args) {
    return DocumentPreviewControllerProvider(args);
  }

  @override
  DocumentPreviewControllerProvider getProviderOverride(
    covariant DocumentPreviewControllerProvider provider,
  ) {
    return call(provider.args);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'documentPreviewControllerProvider';
}

/// See also [DocumentPreviewController].
class DocumentPreviewControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          DocumentPreviewController,
          DocumentPreviewState
        > {
  /// See also [DocumentPreviewController].
  DocumentPreviewControllerProvider(DocumentPreviewArgs args)
    : this._internal(
        () => DocumentPreviewController()..args = args,
        from: documentPreviewControllerProvider,
        name: r'documentPreviewControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$documentPreviewControllerHash,
        dependencies: DocumentPreviewControllerFamily._dependencies,
        allTransitiveDependencies:
            DocumentPreviewControllerFamily._allTransitiveDependencies,
        args: args,
      );

  DocumentPreviewControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.args,
  }) : super.internal();

  final DocumentPreviewArgs args;

  @override
  DocumentPreviewState runNotifierBuild(
    covariant DocumentPreviewController notifier,
  ) {
    return notifier.build(args);
  }

  @override
  Override overrideWith(DocumentPreviewController Function() create) {
    return ProviderOverride(
      origin: this,
      override: DocumentPreviewControllerProvider._internal(
        () => create()..args = args,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        args: args,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    DocumentPreviewController,
    DocumentPreviewState
  >
  createElement() {
    return _DocumentPreviewControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentPreviewControllerProvider && other.args == args;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, args.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DocumentPreviewControllerRef
    on AutoDisposeNotifierProviderRef<DocumentPreviewState> {
  /// The parameter `args` of this provider.
  DocumentPreviewArgs get args;
}

class _DocumentPreviewControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          DocumentPreviewController,
          DocumentPreviewState
        >
    with DocumentPreviewControllerRef {
  _DocumentPreviewControllerProviderElement(super.provider);

  @override
  DocumentPreviewArgs get args =>
      (origin as DocumentPreviewControllerProvider).args;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
