import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/products_exception.dart';
import 'package:hs360/features/products/domain/product_image_validation.dart';

void main() {
  group('validateProductImageFile', () {
    test('accepts when MIME and extension both valid', () {
      expect(
        validateProductImageFile(
          mimeType: 'image/png',
          fileExtension: 'png',
          byteLength: 1024,
        ),
        isNull,
      );
    });

    test('rejects invalid extension with valid MIME', () {
      expect(
        validateProductImageFile(
          mimeType: 'image/png',
          fileExtension: 'gif',
          byteLength: 1024,
        )?.code,
        ProductsException.imageTypeInvalid,
      );
    });

    test('rejects invalid MIME with valid extension', () {
      expect(
        validateProductImageFile(
          mimeType: 'image/gif',
          fileExtension: 'png',
          byteLength: 1024,
        )?.code,
        ProductsException.imageTypeInvalid,
      );
    });

    test('rejects missing MIME even when extension is valid', () {
      expect(
        validateProductImageFile(
          mimeType: null,
          fileExtension: 'png',
          byteLength: 1024,
        )?.code,
        ProductsException.imageTypeInvalid,
      );
    });

    test('rejects missing extension even when MIME is valid', () {
      expect(
        validateProductImageFile(
          mimeType: 'image/png',
          fileExtension: null,
          byteLength: 1024,
        )?.code,
        ProductsException.imageTypeInvalid,
      );
    });

    test('rejects MIME and extension mismatch', () {
      expect(
        validateProductImageFile(
          mimeType: 'image/png',
          fileExtension: 'jpg',
          byteLength: 1024,
        )?.code,
        ProductsException.imageTypeInvalid,
      );
    });

    test('rejects over 5MB', () {
      expect(
        validateProductImageFile(
          mimeType: 'image/jpeg',
          fileExtension: 'jpg',
          byteLength: productImageMaxBytes + 1,
        )?.code,
        ProductsException.imageTooLarge,
      );
    });
  });

  group('buildProductImageStoragePath', () {
    test('includes tenant product and versioned primary', () {
      final path = buildProductImageStoragePath(
        tenantId: 't-1',
        productId: 'p-1',
        extension: 'jpg',
      );
      expect(path, startsWith('t-1/products/p-1/primary-'));
      expect(path, endsWith('.jpg'));
    });
  });
}
