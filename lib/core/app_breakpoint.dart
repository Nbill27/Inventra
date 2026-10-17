/// Ambang lebar layar (dp) dan turunannya.
///
/// Tata letak responsif di aplikasi ini hanya berarti dua hal: konten dibatasi
/// lebarnya lalu dipusatkan (lihat `ContentWidth`), dan tinggi target sentuh
/// sengaja **tetap** supaya tidak jatuh di bawah ambang 44 dp di layar sempit.
abstract final class AppBreakpoint {
  /// Lebar maksimum kolom konten agar baris teks tetap nyaman dibaca.
  static const double contentWidth = 560;
}
