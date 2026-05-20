import '../../../core/errors/products_exception.dart';

const productImageMaxBytes = 5 * 1024 * 1024;

const _allowedMimeTypes = {
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
};

const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

/// Validates MIME and extension together; both must be present and aligned.
ProductsException? validateProductImageFile({
  required String? mimeType,
  required String? fileExtension,
  required int byteLength,
}) {
  final mime = mimeType?.toLowerCase().trim();
  final ext = fileExtension?.toLowerCase().replaceAll('.', '').trim();

  if (mime == null ||
      ext == null ||
      mime.isEmpty ||
      ext.isEmpty ||
      !_allowedMimeTypes.contains(mime) ||
      !_allowedExtensions.contains(ext)) {
    return const ProductsException(code: ProductsException.imageTypeInvalid);
  }

  if (!extensionsForMime(mime).contains(ext)) {
    return const ProductsException(code: ProductsException.imageTypeInvalid);
  }

  if (byteLength > productImageMaxBytes) {
    return const ProductsException(code: ProductsException.imageTooLarge);
  }

  return null;
}

Set<String> extensionsForMime(String mimeType) {
  return switch (mimeType.toLowerCase().trim()) {
    'image/jpeg' || 'image/jpg' => const {'jpg', 'jpeg'},
    'image/png' => const {'png'},
    'image/webp' => const {'webp'},
    _ => const {},
  };
}

String extensionForMime(String mimeType) {
  return switch (mimeType.toLowerCase().trim()) {
    'image/jpeg' || 'image/jpg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
}

String buildProductImageStoragePath({
  required String tenantId,
  required String productId,
  required String extension,
}) {
  final ms = DateTime.now().millisecondsSinceEpoch;
  return '$tenantId/products/$productId/primary-$ms.$extension';
}
