import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../errors/scan_exception.dart';
import '../../network/supabase_providers.dart';
import '../domain/scan_result.dart';

part 'scan_repository.g.dart';

@Riverpod(keepAlive: true)
ScanRepository scanRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return ScanRepository(client);
}

class ScanRepository {
  ScanRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw ScanException.notConfigured();
    return client;
  }

  Future<ScanResult> resolveScanCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      throw const ScanException(code: ScanException.validationFailed);
    }

    try {
      final response = await _requireClient.rpc(
        'resolve_scan_code',
        params: {'p_code': trimmed},
      );
      return ScanResult.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e, st) {
      throw ScanException.fromSupabase(e, st);
    }
  }
}
