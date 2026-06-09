import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/document_render_service.dart';
import 'logo_loader.dart';

part 'document_providers.g.dart';

@Riverpod(keepAlive: true)
http.Client httpClient(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
}

@Riverpod(keepAlive: true)
LogoLoader logoLoader(Ref ref) {
  return NetworkLogoLoader(client: ref.watch(httpClientProvider));
}

@Riverpod(keepAlive: true)
DocumentRenderService documentRenderService(Ref ref) {
  return DocumentRenderService(logoLoader: ref.watch(logoLoaderProvider));
}
