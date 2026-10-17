/// Kategori daftar barang, diturunkan dari kolom stok sehingga tidak perlu
/// disimpan dan tidak bisa melenceng dari stok.
///
/// Dipakai sebagai filter pilih-satu di layar Barang, jadi urutannya menentukan
/// urutan chip: Tersedia, Habis, lalu Dipinjam.
enum ItemFilter {
  available('Tersedia'),
  outOfStock('Habis'),
  borrowed('Dipinjam');

  const ItemFilter(this.label);

  final String label;
}
