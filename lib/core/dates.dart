/// Loan dates are persisted as date-only ISO 8601 strings (`YYYY-MM-DD`), so the
/// database never carries a time component that only the UI cares about.
String formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime parseDate(String value) => DateTime.parse(value);

DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

/// Compares by calendar day, so a due date equal to today is not overdue.
bool isBeforeDay(DateTime value, DateTime other) =>
    dateOnly(value).isBefore(dateOnly(other));
