import '../core/dates.dart';
import 'loan.dart';

/// Kategori daftar peminjaman.
///
/// "Terlambat" tidak disimpan di database — barisnya tetap berstatus `dipinjam`
/// dan hanya tanggal rencana kembalinya yang sudah lewat, jadi kategori ini
/// diturunkan saat query.
///
/// "Dipinjam" mencakup yang sudah lewat tenggat; "Terlambat" mempersempitnya ke
/// bagian itu saja.
enum LoanFilter {
  borrowed('Dipinjam'),
  late('Terlambat'),
  returned('Selesai');

  const LoanFilter(this.label);

  final String label;

  /// Padanan Dart dari kondisi SQL di [LoanRepository.getAllDetailed], dipakai
  /// saat layar menyaring daftar di memori.
  bool matches(Loan loan, DateTime today) {
    return switch (this) {
      LoanFilter.borrowed => loan.status == LoanStatus.borrowed,
      LoanFilter.returned => loan.status == LoanStatus.returned,
      LoanFilter.late => loan.status == LoanStatus.borrowed &&
          isBeforeDay(loan.dueDate, today),
    };
  }
}
