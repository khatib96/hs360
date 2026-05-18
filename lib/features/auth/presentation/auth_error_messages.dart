import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/auth_exception.dart';
import '../../../core/network/supabase_providers.dart';

String authErrorCode(Object? error) {
  if (error is AuthException) return error.code;
  return AuthException.unknown;
}

String authErrorMessage(AppLocalizations l10n, String code) {
  switch (code) {
    case AuthException.invalidCredentials:
      return l10n.authErrorInvalidCredentials;
    case AuthException.networkUnavailable:
      return l10n.authErrorNetworkUnavailable;
    case AuthException.noActiveTenantUser:
      return l10n.authErrorNoActiveTenantUser;
    case AuthException.userInactive:
      return l10n.authErrorUserInactive;
    case AuthException.supabaseNotConfigured:
      return l10n.authErrorSupabaseNotConfigured;
    default:
      return l10n.authErrorUnknown;
  }
}

String? supabaseConfigBannerMessage(
  AppLocalizations l10n,
  SupabaseConfigStatus status,
) {
  return switch (status) {
    SupabaseConfigStatus.missingAnonKey => l10n.authMissingAnonKey,
    SupabaseConfigStatus.initFailed => l10n.authInitFailed,
    SupabaseConfigStatus.ready => null,
  };
}

bool isValidEmail(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  return emailPattern.hasMatch(trimmed);
}
