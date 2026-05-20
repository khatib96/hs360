import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProductImagePicker extends StatelessWidget {
  const ProductImagePicker({
    required this.imageUrl,
    required this.canEdit,
    required this.isUploading,
    required this.onPick,
    required this.addLabel,
    required this.changeLabel,
    required this.uploadingLabel,
    super.key,
  });

  final String? imageUrl;
  final bool canEdit;
  final bool isUploading;
  final Future<void> Function(XFile file) onPick;
  final String addLabel;
  final String changeLabel;
  final String uploadingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? Image.network(
                  imageUrl!,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _placeholder(theme),
                )
              : _placeholder(theme),
        ),
        if (canEdit) ...[
          const SizedBox(height: 8),
          if (isUploading)
            Text(uploadingLabel, style: theme.textTheme.bodySmall)
          else
            TextButton.icon(
              onPressed: () async {
                final picker = ImagePicker();
                final file = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1600,
                  maxHeight: 1600,
                );
                if (file != null) await onPick(file);
              },
              icon: const Icon(Icons.image_outlined),
              label: Text(
                imageUrl != null && imageUrl!.isNotEmpty
                    ? changeLabel
                    : addLabel,
              ),
            ),
        ],
      ],
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      width: 120,
      height: 120,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.inventory_2_outlined,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
