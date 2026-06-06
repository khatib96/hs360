import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/errors/customer_exception.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/google_maps_url_resolver.dart';
import '../../domain/google_maps_coordinates.dart';
import '../customer_error_messages.dart';

class GoogleMapsLinkField extends ConsumerStatefulWidget {
  const GoogleMapsLinkField({
    required this.controller,
    this.initialLatitude,
    this.initialLongitude,
    this.initialResolvedAt,
    this.onBusyChanged,
    super.key,
  });

  final TextEditingController controller;
  final double? initialLatitude;
  final double? initialLongitude;
  final DateTime? initialResolvedAt;
  final ValueChanged<bool>? onBusyChanged;

  @override
  ConsumerState<GoogleMapsLinkField> createState() =>
      GoogleMapsLinkFieldState();
}

class GoogleMapsLinkFieldState extends ConsumerState<GoogleMapsLinkField> {
  Timer? _debounce;
  GoogleMapsCoordinates? _coordinates;
  String? _resolvedInput;
  String? _errorCode;
  bool _isResolving = false;
  Future<GoogleMapsCoordinates?>? _activeResolution;

  @override
  void initState() {
    super.initState();
    final initialUrl = widget.controller.text.trim();
    if (initialUrl.isNotEmpty &&
        widget.initialLatitude != null &&
        widget.initialLongitude != null) {
      _coordinates = GoogleMapsCoordinates(
        latitude: widget.initialLatitude!,
        longitude: widget.initialLongitude!,
        resolvedAt: widget.initialResolvedAt ?? DateTime.now(),
        resolvedUrl: initialUrl,
      );
      _resolvedInput = initialUrl;
    }
    widget.controller.addListener(_onLinkChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onLinkChanged);
    super.dispose();
  }

  Future<GoogleMapsCoordinates?> resolveForSubmit() async {
    final value = widget.controller.text.trim();
    if (value.isEmpty) {
      return null;
    }
    if (_coordinates != null && _resolvedInput == value) {
      return _coordinates;
    }
    return _resolve(showError: true);
  }

  void _onLinkChanged() {
    final value = widget.controller.text.trim();
    _debounce?.cancel();
    if (_resolvedInput != value && mounted) {
      setState(() {
        _coordinates = null;
        _resolvedInput = null;
        _errorCode = null;
      });
    }
    final uri = Uri.tryParse(value);
    if (uri != null && isSupportedGoogleMapsUri(uri)) {
      _debounce = Timer(
        const Duration(milliseconds: 700),
        () => _resolve(showError: true),
      );
    }
  }

  Future<GoogleMapsCoordinates?> _resolve({required bool showError}) {
    final active = _activeResolution;
    if (active != null) return active;

    final future = _performResolve(showError: showError);
    _activeResolution = future;
    return future.whenComplete(() => _activeResolution = null);
  }

  Future<GoogleMapsCoordinates?> _performResolve({
    required bool showError,
  }) async {
    final value = widget.controller.text.trim();
    if (value.isEmpty) return null;

    _setResolving(true);
    try {
      final coordinates = await ref
          .read(googleMapsUrlResolverProvider)
          .resolve(value);
      if (!mounted || widget.controller.text.trim() != value) return null;
      setState(() {
        _coordinates = coordinates;
        _resolvedInput = value;
        _errorCode = null;
      });
      return coordinates;
    } on CustomerException catch (error) {
      if (mounted && widget.controller.text.trim() == value && showError) {
        setState(() => _errorCode = error.code);
      }
      return null;
    } catch (_) {
      if (mounted && widget.controller.text.trim() == value && showError) {
        setState(
          () => _errorCode = CustomerException.googleMapsResolutionFailed,
        );
      }
      return null;
    } finally {
      if (mounted) _setResolving(false);
    }
  }

  void _setResolving(bool value) {
    setState(() => _isResolving = value);
    widget.onBusyChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          key: const Key('google-maps-link-field'),
          label: l10n.customerFieldGoogleMapsUrl,
          controller: widget.controller,
          keyboardType: TextInputType.url,
          helperText: l10n.googleMapsLinkResolutionHint,
          errorText: _errorCode == null
              ? null
              : customerErrorMessage(l10n, _errorCode!),
          onFieldSubmitted: (_) => _resolve(showError: true),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const Key('resolve-google-maps-link'),
            onPressed: _isResolving || widget.controller.text.trim().isEmpty
                ? null
                : () => _resolve(showError: true),
            icon: _isResolving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.location_searching, size: 18),
            label: Text(l10n.googleMapsResolveLink),
          ),
        ),
        if (_coordinates != null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.googleMapsCoordinatesResolved(
              _coordinates!.latitude.toStringAsFixed(6),
              _coordinates!.longitude.toStringAsFixed(6),
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}
