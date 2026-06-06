import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/customer_exception.dart';

String customerErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    CustomerException.permissionDenied => l10n.customerErrorPermissionDenied,
    CustomerException.nameArRequired => l10n.customerValidationNameArRequired,
    CustomerException.phonePrimaryRequired =>
      l10n.customerValidationPhoneRequired,
    CustomerException.emailInvalid => l10n.customerValidationEmailInvalid,
    CustomerException.accountAlreadyLinked =>
      l10n.customerErrorAccountAlreadyLinked,
    CustomerException.validationFailed => l10n.customerValidationFailed,
    CustomerException.serviceLocationNameRequired =>
      l10n.serviceLocationValidationNameRequired,
    CustomerException.serviceLocationCoordinatePairRequired =>
      l10n.serviceLocationCoordinatePairRequired,
    CustomerException.serviceLocationLatitudeInvalid =>
      l10n.serviceLocationLatitudeInvalid,
    CustomerException.serviceLocationLongitudeInvalid =>
      l10n.serviceLocationLongitudeInvalid,
    CustomerException.serviceLocationCoordinateMetadataInvalid =>
      l10n.serviceLocationCoordinateMetadataInvalid,
    CustomerException.locationServicesDisabled =>
      l10n.serviceLocationServicesDisabled,
    CustomerException.locationPermissionDenied =>
      l10n.serviceLocationPermissionDenied,
    CustomerException.locationPermissionPermanentlyDenied =>
      l10n.serviceLocationPermissionPermanentlyDenied,
    CustomerException.locationUnavailable => l10n.serviceLocationUnavailable,
    CustomerException.googleMapsLinkInvalid => l10n.googleMapsLinkInvalid,
    CustomerException.googleMapsCoordinatesNotFound =>
      l10n.googleMapsCoordinatesNotFound,
    CustomerException.googleMapsResolutionFailed =>
      l10n.googleMapsResolutionFailed,
    CustomerException.locationInUse => l10n.serviceLocationInUse,
    CustomerException.primaryRequired => l10n.serviceLocationPrimaryRequired,
    CustomerException.supabaseNotConfigured =>
      l10n.authErrorSupabaseNotConfigured,
    _ => l10n.customerErrorUnknown,
  };
}
