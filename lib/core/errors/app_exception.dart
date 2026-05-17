/// Base application exception with a stable code for localization lookup (M4+).
abstract class AppException implements Exception {
  const AppException({
    required this.code,
    this.technicalDetail,
  });

  final String code;
  final String? technicalDetail;

  @override
  String toString() =>
      'AppException($code${technicalDetail != null ? ': $technicalDetail' : ''})';
}
