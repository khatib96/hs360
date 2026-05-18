import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Labeled form field with optional password visibility toggle.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.enablePasswordToggle = false,
    this.showPasswordLabel,
    this.hidePasswordLabel,
    this.onFieldSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool enablePasswordToggle;
  final String? showPasswordLabel;
  final String? hidePasswordLabel;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget? suffix;
    if (widget.enablePasswordToggle) {
      final showLabel = widget.showPasswordLabel ?? '';
      final hideLabel = widget.hidePasswordLabel ?? '';
      final tooltip = _obscured ? showLabel : hideLabel;
      suffix = Semantics(
        label: tooltip,
        button: true,
        child: IconButton(
          tooltip: tooltip,
          onPressed: () => setState(() => _obscured = !_obscured),
          icon: Icon(
            _obscured ? LucideIcons.eye : LucideIcons.eyeOff,
            size: 20,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: TextFormField(
            controller: widget.controller,
            validator: widget.validator,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            obscureText: widget.enablePasswordToggle
                ? _obscured
                : widget.obscureText,
            onFieldSubmitted: widget.onFieldSubmitted,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsetsDirectional.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    );
  }
}
