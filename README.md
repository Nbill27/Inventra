# Inventra — Peminjaman Barang

Aplikasi Android untuk mencatat peminjaman alat ukur: siapa yang meminjam, berapa
unit, kapan harus kembali, dan mana yang sudah lewat tenggat. Data disimpan di
perangkat dengan SQLite, jadi aplikasi berjalan penuh tanpa internet.

## Fitur

Navigasi bawah berisi tiga tab.

### Beranda

- Ringkasan jumlah peminjaman: Dipinjam, Terlambat, Selesai.
- Daftar peminjaman aktif dengan pencarian nama peminjam atau barang.
- Tombol **Catat pinjam** — satu-satunya tempat mencatat peminjaman baru.

### Barang

- Daftar alat ukur dengan pencarian nama/kode dan filter Semua, Tersedia, Habis,
  Dipinjam.
- Tambah dan ubah barang manual. Kode alat ukur wajib unik antar barang.
- **Impor dari berkas** `.xlsx` atau `.csv` mengikuti susunan kolom berkas induk
  "Daftar Alat Ukur".

### Riwayat

- Statistik arsip: total transaksi, tepat waktu, dan rerata lama pinjam.
- Pencarian, filter status (Dipinjam, Terlambat, Selesai), dan pemilih periode
  yang dibangun dari bulan yang benar-benar ada di data.
- **Ekspor** rekap ke XLSX atau CSV.

### Detail peminjaman

Ubah data pinjam, hapus peminjaman, atau tandai sudah dikembalikan.

Status "Terlambat" dihitung saat tampil dari tanggal rencana kembali; di database
barisnya tetap `dipinjam`, sehingga label tidak bisa melenceng dari tanggalnya.
Label seragam `Terlambat N hari`.

### Pengaturan

- **Pengingat pengembalian** — notifikasi pukul 09.00, 13.00, dan 15.00 WIB pada
  dan setelah tanggal tenggat, sampai barang ditandai dikembalikan. Satu
  notifikasi ringkasan per slot, bukan satu per transaksi.
- Peringatan bila Android masih membatasi aplikasi di latar belakang, dengan
  tombol menuju daftar pengecualian optimasi baterai.
- **Backup otomatis bulanan** dengan saklarnya, plus tombol backup manual.
  Salinan bisa dikeluarkan ke lokasi pilihan pengguna (Drive, Downloads, dan
  seterusnya) dan dipulihkan kembali dari berkas `.db`.
- Versi aplikasi yang sedang terpasang, dibaca dari paket Android.

## Menjalankan

Butuh Flutter SDK (Dart `^3.12`). Sasaran proyek hanya Android.

```bash
flutter pub get
flutter run                  # perangkat atau emulator Android
flutter build apk --release
```

## Impor barang

Kolom dikenali dari baris judul berkas, dan judulnya boleh bervariasi:

| Kolom | Judul yang diterima |
| --- | --- |
| Nama alat ukur (wajib) | `NAMA ALAT UKUR`, `Nama Barang`, `Nama Alat`, `Nama` |
| Kode | `KODE ALAT UKUR`, `Kode Barang`, `Kode` |
| No | `No`, `No urut`, `Nomor` |
| Range | `Range`, `Kapasitas` |
| Brand | `Brand`, `Merk`, `Merek` |
| PIC | `PIC`, `Penanggung jawab` |
| Status | `Status`, `Kondisi` |
| Stok total | `Stok`, `Stock`, `Jumlah`, `Qty`, `Kuantitas` |

Nama alat ukur wajib. Stok dibaca dari kolom stok; kalau berkasnya tidak punya
kolom stok, isi "Stok tiap barang" lebih dulu. Pilihan lanjutan menentukan lembar
mana yang dibaca, baris judul kolom, dan apakah impor berhenti di baris kosong.

Baris kosong dilewati tanpa dilaporkan. Baris bermasalah dilaporkan dengan nomor
barisnya, dan kode yang sudah dipakai barang lain dilewati.

## Struktur

```
lib/
  core/          tema, format tanggal/angka, validasi, pengecualian
  db/            koneksi SQLite dan migrasi skema
  models/        Item, Loan, filter, statistik, hasil impor
  providers/     state ChangeNotifier untuk barang, peminjaman, dan pengaturan
  repositories/  query dan transaksi
  services/      baca Excel/CSV, importer, ekspor riwayat, backup, dan pengingat
  screens/       layar tiap tab, formulir, detail, dan pengaturan
  widgets/       komponen bersama (kartu, chip status, panel, dsb.)
test/            tes unit, repository, impor, backup, pengingat, dan render layar
```

Basis data: `peminjaman_barang.db`, skema versi 3 (versi 3 menambahkan
`app_settings` untuk saklar backup dan pengingat).

## Validasi

- Nama peminjam dan nama alat ukur wajib diisi.
- Kontak boleh kosong; kalau diisi hanya huruf, angka, spasi, dan `+ - ( ) . /`,
  maksimal 30 karakter (layar juga menuntut minimal 6 karakter; batas bawah ini
  tidak ditegakkan di repository supaya data lama yang pendek masih bisa
  disunting).
- Jumlah pinjam minimal 1 dan tidak boleh melebihi stok tersedia.
- Tanggal rencana kembali tidak boleh sebelum tanggal pinjam, dan tanggal
  pengembalian tidak boleh melewati hari ini.
- Peminjaman yang sudah selesai tidak bisa diganti barang atau jumlahnya.

## Tes

```bash
flutter analyze
flutter test
```

Sebagian tes impor masih memakai pesan validasi versi lama, jadi `flutter test`
belum hijau seluruhnya: yang gagal adalah harapan di dalam
`test/item_import_test.dart` dan `test/item_import_screen_test.dart`, bukan
perilaku impor di aplikasi.

## Catatan teknis

- `dependency_overrides: jni_flutter 1.0.3` di `pubspec.yaml`: versi 1.0.4+1
  dibangun terhadap android-35 sementara `jni` menuntut compileSdk 36. Lepas pin
  ini setelah upstream beres.
- Font Poppins dibundel di `assets/fonts/` supaya tampilan sama tanpa unduhan saat
  runtime.
- AGP 9 mengaktifkan resource shrinking di build rilis. Ikon notifikasi
  (`ic_stat_reminder`) hanya dirujuk dari Dart sebagai nama resource, jadi tanpa
  `android/app/src/main/res/raw/keep.xml` ikon itu dibuang dari APK dan
  `flutter_local_notifications` gagal initialize — seluruh pengingat mati tanpa
  pesan di UI.
- Alarm memakai `inexactAllowWhileIdle`, sehingga tidak perlu izin exact alarm
  dan pengiriman bisa bergeser beberapa menit. Jadwal dipasang ulang setiap app
  dibuka: cache plugin masih mencatat alarm lama walau Android sudah membuangnya
  setelah app di-update atau di-force stop.
