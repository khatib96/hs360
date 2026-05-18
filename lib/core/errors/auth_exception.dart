import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import 'app_exception.dart';

/// Auth failures with stable [code] values. User-facing text comes from ARB in M4.
class AuthException extends AppException {
  const AuthException({required super.code, super.technicalDetail});

  static const invalidCredentials = 'invalidCredentials';
  static const networkUnavailable = 'networkUnavailable';
  static const noActiveTenantUser = 'noActiveTenantUser';
  static const userInactive = 'userInactive';
  static const supabaseNotConfigured = 'supabaseNotConfigured';
  static const unknown = 'unknown';

  factory AuthException.fromSupabase(Object error, [StackTrace? stackTrace]) {
    if (error is AuthException) return error;

    if (error is AuthApiException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials') ||
          message.contains('invalid email or password')) {
        return AuthException(
          code: invalidCredentials,
          technicalDetail: error.message,
        );
      }
      if (message.contains('network') ||
          message.contains('socket') ||
          message.contains('connection')) {
        return AuthException(
          code: networkUnavailable,
          technicalDetail: error.message,
        );
      }
      return AuthException(code: unknown, technicalDetail: error.message);
    }

    if (error is PostgrestException) {
      return AuthException(code: unknown, technicalDetail: error.message);
    }

    if (error is SocketException) {
      return AuthException(
        code: networkUnavailable,
        technicalDetail: error.message,
      );
    }

    final message = error.toString().toLowerCase();
    if (message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection refused') ||
        message.contains('failed host lookup')) {
      return AuthException(
        code: networkUnavailable,
        technicalDetail: error.toString(),
      );
    }

    return AuthException(code: unknown, technicalDetail: error.toString());
  }

  factory AuthException.notConfigured() {
    return const AuthException(code: supabaseNotConfigured);
  }

  factory AuthException.noTenantUser() {
    return const AuthException(code: noActiveTenantUser);
  }

  factory AuthException.inactiveTenantUser() {
    return const AuthException(code: userInactive);
  }
}
