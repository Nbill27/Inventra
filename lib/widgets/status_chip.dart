import 'package:flutter/material.dart';

import '../models/loan.dart';

/// Shows the loan status, with "Terlambat" derived at render time (FR-L12):
/// the database only ever stores `dipinjam` or `selesai`.
///
/// The label changes as well as the color, so the state is readable without
/// relying on color alone (WCAG AA, also for red and green color blindness).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.loan, this.today});

  final Loan loan;

  /// Injectable so a test can pin the day the chip is rendered on.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final isLate = loan.isLateOn(today ?? DateTime.now());
    final label = switch (loan.status) {
      LoanStatus.returned => 'Selesai',
      LoanStatus.borrowed => isLate ? 'Terlambat' : 'Dipinjam',
    };
    final style = _Styles.of(label, Theme.of(context).brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: style.foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Colors are fixed rather than derived from the seed, because a status must
/// keep its meaning in both brightnesses and the seed only owns the brand hue.
class _Styles {
  const _Styles({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;

  static const _lightBorrowed = _Styles(
    background: Color(0xFFD7E7F3),
    foreground: Color(0xFF123B52),
    border: Color(0xFF9CC3DA),
  );
  static const _lightReturned = _Styles(
    background: Color(0xFFD8EFDC),
    foreground: Color(0xFF1B4D28),
    border: Color(0xFF9CCFA6),
  );
  static const _lightLate = _Styles(
    background: Color(0xFFFBDAD8),
    foreground: Color(0xFF7A1C16),
    border: Color(0xFFE0A19B),
  );

  static const _darkBorrowed = _Styles(
    background: Color(0xFF1B3A4B),
    foreground: Color(0xFFBBDDF0),
    border: Color(0xFF33586D),
  );
  static const _darkReturned = _Styles(
    background: Color(0xFF1E3F26),
    foreground: Color(0xFFB6E3BF),
    border: Color(0xFF38623F),
  );
  static const _darkLate = _Styles(
    background: Color(0xFF4A211C),
    foreground: Color(0xFFF8C2BC),
    border: Color(0xFF6E3A34),
  );

  static _Styles of(String label, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (label) {
      'Selesai' => dark ? _darkReturned : _lightReturned,
      'Terlambat' => dark ? _darkLate : _lightLate,
      _ => dark ? _darkBorrowed : _lightBorrowed,
    };
  }
}
