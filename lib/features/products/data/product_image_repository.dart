import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/products_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../auth/domain/app_session.dart';
import '../domain/product_image_validation.dart';
import '../domain/product_permissions.dart';

part 'product_image_repository.g.dart';

@Riverpod(keepAlive: true)
ProductImageRepository productImageRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return ProductImageRepository(client);
}

class ProductImageRepository {
  ProductImageRepository(this._client);

  final SupabaseClient? _client;

  static const _bucket = 'product_images';

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw ProductsException.notConfigured();
    return client;
  }

  Future<String> uploadPrimaryImage({
    required AppSession session,
    required String productId,
    required Uint8List bytes,
    required String? mimeType,
    String? fileExtension,
  }) async {
    if (!canEditProduct(session)) {
      throw const ProductsException(code: ProductsException.permissionDenied);
    }

    final ext = fileExtension?.replaceAll('.', '').toLowerCase();
    final validationError = validateProductImageFile(
      mimeType: mimeType,
      fileExtension: ext,
      byteLength: bytes.length,
    );
    if (validationError != null) throw validationError;

    final contentType = mimeType!.toLowerCase().trim();
    final path = buildProductImageStoragePath(
      tenantId: session.tenantId,
      productId: productId,
      extension: ext!,
    );

    try {
      await _requireClient.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      return _requireClient.storage.from(_bucket).getPublicUrl(path);
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }
}
