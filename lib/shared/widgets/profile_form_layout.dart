import 'package:flutter/material.dart';

/// Responsive two-column form layout for profile dialogs.
class ProfileFormLayout extends StatelessWidget {
  const ProfileFormLayout({
    required this.children,
    super.key,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useTwoColumns = width >= 720;

    if (!useTwoColumns) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _withSpacing(children, 16),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      if (i + 1 < children.length) {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 16),
              Expanded(child: children[i + 1]),
            ],
          ),
        );
        rows.add(const SizedBox(height: 16));
      } else {
        rows.add(children[i]);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  List<Widget> _withSpacing(List<Widget> items, double gap) {
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) result.add(SizedBox(height: gap));
    }
    return result;
  }
}

class ProfileFormSection extends StatelessWidget {
  const ProfileFormSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 24),
      ],
    );
  }
}

class ProfileLabeledField extends StatelessWidget {
  const ProfileLabeledField({
    required this.label,
    required this.child,
    super.key,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: child,
        ),
      ],
    );
  }
}

class ProfileMetadataRow extends StatelessWidget {
  const ProfileMetadataRow({required this.label, required this.value, super.key});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = (value == null || value!.trim().isEmpty) ? '—' : value!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: theme.textTheme.labelMedium),
        ),
        Expanded(child: Text(display, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
