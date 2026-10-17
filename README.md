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
  providers/     state ChangeNotifier untuk barang dan peminjaman
  repositories/  query dan transaksi
  services/      baca Excel/CSV, importer, parser CSV, ekspor riwayat
  screens/       layar tiap tab, formulir, dan detail
  widgets/       komponen bersama (kartu, chip status, panel, dsb.)
test/            tes unit, repository, impor, dan render layar
```

Basis data: `peminjaman_barang.db`, skema versi 2.

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

## Catatan teknis

- `dependency_overrides: jni_flutter 1.0.3` di `pubspec.yaml`: versi 1.0.4+1
  dibangun terhadap android-35 sementara `jni` menuntut compileSdk 36. Lepas pin
  ini setelah upstream beres.
- Font Poppins dibundel di `assets/fonts/` supaya tampilan sama tanpa unduhan saat
  runtime.
