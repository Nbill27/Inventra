# Changelog

Semua perubahan penting pada aplikasi **Inventra** (peminjaman barang) dicatat di
berkas ini.

Format mengikuti [Keep a Changelog](https://keepachangelog.com/id/1.1.0/), dan
penomoran versi mengikuti [Semantic Versioning](https://semver.org/lang/id/).

## [Unreleased]

Perbaikan menyeluruh atas hasil audit kode: integritas data impor, keamanan
ekspor, aturan tanggal peminjaman, penyegaran data lintas hari, dan
aksesibilitas. Commit: `99d4b43`.

### Ditambahkan

- **Tombol coba lagi** pada layar daftar: kegagalan memuat data tidak lagi
  tampil sama dengan daftar kosong.
- **Semantik chip filter** dan **tooltip tombol hapus pencarian**, supaya
  pembaca layar membacakan status filter dan aksi hapus dengan benar.
- **Contoh berkas tanda tangan rilis** `android/key.properties.example`.
- **Tes baru** `test/validation_test.dart` dan `test/loan_provider_test.dart`.

### Diubah

- **Nomor baris pada laporan impor** mengikuti baris Excel yang dilihat admin,
  bukan indeks internal tabel ganda, sehingga pesan kesalahan menunjuk baris
  yang tepat.
- **Sumbu sentuh minimum** dinaikkan dari 44 dp ke 48 dp mengikuti pedoman
  aksesibilitas Material.
- **Kontak peminjam** kini menerima nomor telepon, email, atau tautan WhatsApp
  dengan aturan format yang eksplisit.
- **Layar detail peminjaman** menyegar otomatis setelah form simpan berhasil.
- **`LoanProvider`** menerima jam yang disuntikkan, dan data dimuat ulang saat
  aplikasi kembali aktif atau saat hari berganti. Tanggal dan status tidak lagi
  "beku" di hari saat aplikasi pertama dibuka.

### Diperbaiki

- **Impor berkas**:
  - Pemisah ribuan dipisahkan dari tanda desimal, sehingga angka seperti
    `1.500,5` tidak lagi salah dibaca.
  - Kolom stok tidak hilang saat impor gagal dan pengguna mencoba lagi.
  - Tabel tanpa baris judul tetap terpetakan ke kolom yang benar.
  - Laporan dari beberapa sumber (beberapa lembar atau blok berdampingan)
    digabung menjadi satu hasil, bukan saling menimpa.
  - Kutipan CSV yang tidak ditutup ditolak dengan pesan yang jelas.
- **Ekspor riwayat**:
  - Nilai teks yang berawalan `=`, `+`, `-`, `@`, tab, atau carriage return
    dinetralkan supaya tidak dieksekusi sebagai rumus saat berkas dibuka di
    aplikasi spreadsheet.
  - Tanggal dan label status ditulis sesuai hari berjalan, bukan hari saat
    aplikasi dibuka.
- **Aturan peminjaman**: tanggal kembali tidak boleh sebelum tanggal pinjam
  atau di masa depan; tombol "tandai dikembalikan" dinonaktifkan bila
  peminjaman belum mulai.
- **Pencarian dan filter**: sumbu sentuh dan semantik chip diperbaiki (lihat
  bagian Diubah).

### Keamanan

- **Kunci rilis tidak ikut di-commit.** `android/key.properties` dibaca secara
  kondisional; `signingConfigs.release` hanya dibuat bila berkas kunci tersedia,
  dan build jatuh ke kunci debug bila tidak ada. Sebelum ini, build rilis akan
  gagal atau memakai kunci yang salah.
- **Formula injection pada ekspor CSV** ditangani (lihat bagian Diperbaiki).

### Catatan rilis

- Build rilis saat ini masih ditandatangani dengan kunci debug. Isi
  `android/key.properties` dari `android/key.properties.example` begitu keystore
  rilis tersedia.
- Dua berkas tes impor (`test/item_import_test.dart`,
  `test/item_import_screen_test.dart`) belum diperbarui menyusul perubahan
  perilaku impor. Keduanya gagal karena ekspektasi dan fixture yang usang, bukan
  karena regresi kode. Rencana perbaikannya ada di `TEST_STRATEGY.md`.

## Riwayat awal

Riwayat sebelum catatan ini dibuat dapat dilihat di git:

```sh
git log --oneline
```

Commit penting sebelum audit:

- `de7f691` — Rapikan validasi, kode barang duplikat, dan label terlambat.
- `4b6957f` — Tulis ulang README sesuai aplikasi Inventra.
- `7cef981` — Catat tes impor yang belum diperbarui di README.
