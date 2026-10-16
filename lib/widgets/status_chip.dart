import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/loan.dart';
import 'status_pill.dart';

/// Menampilkan status peminjaman, dengan "Terlambat" dihitung saat render
/// (FR-L12): database hanya menyimpan `dipinjam` atau `selesai`.
///
/// Label ikut berubah, bukan hanya warnanya, sehingga status tetap terbaca
/// tanpa bergantung pada warna (WCAG AA, juga untuk buta warna merah-hijau).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.loan, this.today});

  final Loan loan;

  /// Bisa diisi supaya test bisa mematok hari saat chip dirender.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final isLate = loan.isLateOn(today ?? DateTime.now());
    final label = switch (loan.status) {
      LoanStatus.returned => 'Selesai',
      LoanStatus.borrowed => isLate ? 'Terlambat' : 'Dipinjam',
    };
    final style = _Styles.of(label);

    return StatusPill(
      label: label,
      background: style.background,
      // Teks memakai varian gelap (kontras >= 4.5:1), titik tetap warna terang.
      foreground: style.foreground,
      dotColor: style.dot,
      dot: true,
      upper: false,
      fontSize: 12,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space10,
        vertical: AppTheme.spaceXs,
      ),
    );
  }
}

/// Warna status sengaja tetap, bukan diturunkan dari warna brand: sebuah status
/// harus tetap berarti sama di semua layar, dan brand hanya memiliki satu hue.
class _Styles {
  const _Styles({
    required this.background,
    required this.foreground,
    required this.dot,
  });

  final Color background;
  final Color foreground;
  final Color dot;

  static const _borrowed = _Styles(
    background: AppTheme.primaryContainer,
    foreground: AppTheme.onPrimaryContainer,
    dot: AppTheme.primary,
  );
  static const _returned = _Styles(
    background: AppTheme.okSoft,
    foreground: AppTheme.ok,
    dot: AppTheme.ok,
  );
  static const _late = _Styles(
    background: AppTheme.dangerSoft,
    foreground: AppTheme.danger,
    dot: AppTheme.danger,
  );

  static _Styles of(String label) => switch (label) {
        'Selesai' => _returned,
        'Terlambat' => _late,
        _ => _borrowed,
      };
}
