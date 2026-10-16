/// Ambang lebar layar (dp) dan turunannya.
///
/// Tata letak responsif di aplikasi ini hanya berarti dua hal: konten dibatasi
/// lebarnya lalu dipusatkan (lihat `ContentWidth`), dan tinggi target sentuh
/// sengaja **tetap** supaya tidak jatuh di bawah ambang 44 dp di layar sempit.
abstract final class AppBreakpoint {
  /// Ponsel sempit (mis. 320-359 dp).
  static const double kecil = 360;

  /// Batas ponsel ke tablet.
  static const double tablet = 600;

  /// Tablet besar / desktop.
  static const double lebar = 900;

  /// Lebar maksimum kolom konten agar baris teks tetap nyaman dibaca.
  static const double lebarKonten = 560;

  /// Apakah [lebarLayar] tergolong tablet ke atas.
  static bool isTablet(double lebarLayar) => lebarLayar >= tablet;

  /// Apakah [lebarLayar] tergolong ponsel sempit.
  static bool isSempit(double lebarLayar) => lebarLayar < kecil;
}
