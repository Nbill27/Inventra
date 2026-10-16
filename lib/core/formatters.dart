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
