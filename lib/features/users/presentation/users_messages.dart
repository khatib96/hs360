import 'dart:math';

import 'package:hs360/l10n/app_localizations.dart';

import '../data/users_repository.dart';

/// Matches the minimum enforced by the admin-users function.
const minPasswordLength = 10;

final _loginPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateLogin(AppLocalizations l10n, String? value) {
  final login = value?.trim() ?? '';
  if (login.isEmpty) return l10n.usersFieldRequired;
  if (!_loginPattern.hasMatch(login)) return l10n.usersLoginInvalid;
  return null;
}

String? validateNewPassword(AppLocalizations l10n, String? value) {
  if ((value ?? '').length < minPasswordLength) {
    return l10n.usersPasswordTooShort;
  }
  return null;
}

/// Readable random password without look-alike characters.
String generatePassword({int length = 12}) {
  const alphabet = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}

String usersErrorMessage(AppLocalizations l10n, Object error) {
  final code = error is UsersException ? error.code : UsersException.unknown;
  return switch (code) {
    UsersException.permissionDenied => l10n.usersErrorPermissionDenied,
    UsersException.managerRequired ||
    'target_is_manager' => l10n.usersErrorManagerRequired,
    UsersException.permissionNotHeld => l10n.usersErrorNotHeld,
    UsersException.cannotModifySelf => l10n.usersErrorSelf,
    UsersException.loginTaken ||
    'login_already_member' => l10n.usersErrorLoginTaken,
    UsersException.weakPassword => l10n.usersErrorWeakPassword,
    'invalid_login' => l10n.usersLoginInvalid,
    UsersException.unavailable ||
    UsersException.notConfigured => l10n.usersErrorUnavailable,
    _ => l10n.usersErrorGeneric,
  };
}
