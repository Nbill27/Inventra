/// Ringkasan isi tabel `loans`, dihitung oleh database.
///
/// "Terlambat" diturunkan saat query (bukan disimpan), sama seperti di layar
/// daftar: database hanya menyimpan `dipinjam` dan `selesai`.
class LoanStats {
  const LoanStats({
    this.active = 0,
    this.activeUnits = 0,
    this.late = 0,
    this.returned = 0,
    this.onTime = 0,
    this.averageLoanDays = 0,
  });

  /// Peminjaman yang belum dikembalikan.
  final int active;

  /// Unit yang sedang berada di tangan peminjam.
  final int activeUnits;

  /// Peminjaman aktif yang sudah melewati tanggal kembali rencana.
  final int late;

  /// Peminjaman yang sudah selesai.
  final int returned;

  /// Peminjaman selesai yang dikembalikan tidak melewati tanggal rencana.
  final int onTime;

  /// Rerata lama pinjam (hari) dari peminjaman yang sudah selesai.
  final double averageLoanDays;

  int get total => active + returned;

  /// Bagian peminjaman selesai yang tepat waktu, 0..1.
  double get onTimeRate => returned == 0 ? 0 : onTime / returned;
}
