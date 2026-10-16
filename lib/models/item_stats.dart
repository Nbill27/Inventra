/// Ringkasan isi tabel `items`, dihitung oleh database bukan di memori.
///
/// Dihitung dengan satu query agregat supaya beranda tetap murah walau daftar
/// barangnya berisi puluhan ribu baris.
class ItemStats {
  const ItemStats({
    this.totalItems = 0,
    this.totalUnits = 0,
    this.availableUnits = 0,
    this.outOfStock = 0,
  });

  /// Jumlah baris barang.
  final int totalItems;

  /// Jumlah unit dari seluruh barang.
  final int totalUnits;

  /// Unit yang sedang ada di tempat (tidak dipinjam).
  final int availableUnits;

  /// Barang yang stok tersedianya nol.
  final int outOfStock;

  /// Unit yang sedang dipinjam, diturunkan dari selisih total dan tersedia.
  int get borrowedUnits => totalUnits - availableUnits;

  bool get isEmpty => totalItems == 0;
}
