import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Loads the Indonesian month and weekday names used by the formatters below.
/// Called once from `main` before the first frame, because `intl` throws when a
/// locale-specific pattern is formatted before its data is loaded.
Future<void> initFormatters() => initializeDateFormatting('id_ID');

final DateFormat _dayMonthYear = DateFormat('d MMM yyyy', 'id_ID');
final DateFormat _fullDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID');

/// List and form fields: `16 Okt 2026`.
String formatDisplayDate(DateTime date) => _dayMonthYear.format(date);

/// Detail header: `Jumat, 16 Oktober 2026`.
String formatLongDate(DateTime date) => _fullDate.format(date);

/// Angka dengan pemisah ribuan gaya Indonesia: `100000` menjadi `100.000`.
///
/// Ditulis manual alih-alih lewat `NumberFormat` supaya tidak bergantung pada
/// data locale yang dimuat saat runtime.
String formatCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$buffer';
}
