/// Stable validation outcome for domain validators.
class ValidationResult {
  const ValidationResult({required this.codes});

  const ValidationResult.valid() : codes = const [];

  final List<String> codes;

  bool get isValid => codes.isEmpty;

  ValidationResult merge(ValidationResult other) {
    if (isValid && other.isValid) return const ValidationResult.valid();
    return ValidationResult(codes: [...codes, ...other.codes]);
  }
}
