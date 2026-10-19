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

/// Batas panjang kontak, dipakai layar dan repository supaya sama.
const int contactMaxLength = 30;

/// Karakter yang masuk akal untuk "nomor HP atau email": huruf, angka, spasi,
/// dan tanda pemisah nomor, ditambah `@`, `_`, dan `.` supaya alamat email ikut
/// diterima. Sisanya ditolak supaya kolom ini tidak diisi sembarangan.
final RegExp _contactAllowed = RegExp(r'^[A-Za-z0-9 +()@._/\-]+$');

/// Bentuk email yang longgar: ada isi, satu `@`, lalu domain bertitik.
///
/// Sengaja tidak seketat RFC: yang penting salah ketik seperti tanpa `@` atau
/// tanpa domain ketahuan sebelum disimpan.
final RegExp _contactEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Kenapa kontak belum bisa diterima, atau null kalau isinya sudah oke.
///
/// Dipisah dari [optionalContact] supaya layar bisa memakai kalimat yang sama
/// di bawah kolom, bukan lewat exception.
String? contactProblem(String? value) {
  final text = optionalText(value);
  if (text == null) {
    return null;
  }
  if (text.length > contactMaxLength) {
    return 'Kontak maksimal $contactMaxLength karakter.';
  }
  if (!_contactAllowed.hasMatch(text)) {
    return 'Kontak hanya boleh huruf, angka, spasi, dan tanda + - ( ) . / @ _';
  }
  // `@` hanya masuk akal sebagai email, jadi bentuknya diperiksa; nomor
  // telepon tidak punya tanda itu.
  if (text.contains('@') && !_contactEmail.hasMatch(text)) {
    return 'Kontak berupa email harus berformat nama@domain.';
  }
  return null;
}

/// Optional contact: blank stays null, and a filled value must look like a
/// phone number or an email address.
///
/// Panjang minimum hanya ditegakkan di layar, bukan di sini, supaya data lama
/// yang pendek masih bisa disunting.
String? optionalContact(String? value) {
  final problem = contactProblem(value);
  if (problem != null) {
    throw ValidationException(problem);
  }
  return optionalText(value);
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
