import 'exceptions.dart';

/// Trimmed non-empty text with an upper length bound.
String requireText(String? value, {required String field, int maxLength = 100}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    throw ValidationException('$field wajib diisi.');
  }
  if (text.length > maxLength) {
    throw ValidationException('$field maksimal $maxLength karakter.');
  }
  return text;
}

/// Optional text: blank input is stored as null rather than an empty string.
String? optionalText(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}

int requireNonNegativeInt(int value, {required String field}) {
  if (value < 0) {
    throw ValidationException('$field tidak boleh negatif.');
  }
  return value;
}

int requirePositiveInt(int value, {required String field}) {
  if (value < 1) {
    throw ValidationException('$field minimal 1.');
  }
  return value;
}
