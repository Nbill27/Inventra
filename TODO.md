# TODO Peminjaman Barang

Sumber kebutuhan: `PRD.md`. Status: `[x]` selesai dan teruji, `[~]` kode ada, belum diuji lewat UI, `[ ]` belum dikerjakan.

Aturan kerja: setiap item selesai harus punya bukti, yaitu tes yang lulus atau langkah klik yang dicatat.

## 1. Fondasi

- [~] Struktur folder sesuai PRD §10, ditambah `lib/core/` untuk utilitas bersama
- [~] Model: `Item`, `Loan`, `LoanDetail`
- [~] `database_helper`: skema v1, CHECK constraint stok, indeks `loans(item_id)` dan `loans(status)`, `PRAGMA foreign_keys = ON`
- [~] Repository barang dan peminjaman, seluruh perhitungan stok di dalam satu transaksi
- [~] Provider barang dan peminjaman, stale-guard `_requestId`
- [ ] `TODO(design)`: `DESIGN.md` belum ada, jadi seluruh UI saat ini adalah **draft tanpa arah**, dial ENERGY 1 / RHYTHM 1 / MOTION 1. Belum bisa disebut hasil akhir sampai arah desain ditentukan
- [ ] `TODO(icon)`: ikon aplikasi dan logo belum dibuat. Butuh konfirmasi pemilik sebelum digambar
- [ ] `TODO(prd-14)`: empat pertanyaan terbuka PRD §14 belum dijawab (jenis barang, multi-barang per transaksi, batas durasi/jumlah pinjam, barang rusak atau hilang)

## 2. Modul Barang

- [x] FR-B1 tambah barang: nama wajib, kode, kategori, stok total wajib, catatan
- [x] FR-B2 daftar barang dengan stok tersedia dan stok total
- [x] FR-B3 cari barang berdasarkan nama atau kode
- [ ] FR-B4 lihat detail barang
- [x] FR-B5 ubah data barang
- [ ] FR-B6 hapus barang dengan dialog konfirmasi
- [x] FR-B7 hapus diblokir selama barang masih dirujuk peminjaman (lebih ketat dari PRD: riwayat `selesai` juga memblokir, karena `loans.item_id` tidak ber-cascade)
- [x] FR-B8 ubah stok total menyesuaikan stok tersedia sebesar selisihnya, hasil tidak boleh negatif

## 3. Modul Peminjaman

- [x] FR-L1 catat peminjaman: barang, nama peminjam, kontak, jumlah, tanggal pinjam, tanggal kembali rencana, catatan
- [x] FR-L2 jumlah pinjam tidak melebihi stok tersedia
- [x] FR-L3 tanggal kembali rencana tidak sebelum tanggal pinjam
- [x] FR-L4 pembuatan peminjaman mengurangi stok tersedia
- [x] FR-L5 daftar peminjaman diurutkan terbaru dulu
- [ ] FR-L6 filter daftar berdasarkan status
- [ ] FR-L7 detail peminjaman
- [x] FR-L8 ubah data peminjaman
- [x] FR-L9 tandai dikembalikan: tanggal kembali aktual diisi, status `selesai`, stok tersedia bertambah
- [ ] FR-L10 hapus catatan peminjaman dengan konfirmasi
- [x] FR-L11 hapus `dipinjam` mengembalikan stok, hapus `selesai` tidak mengubah stok
- [ ] FR-L12 label "Terlambat" untuk peminjaman `dipinjam` yang lewat tanggal kembali rencana

## 4. Aturan stok (PRD §6.3)

- [x] 6.3.1 `stock_available` selalu di dalam rentang `0..stock_total`
- [x] 6.3.2 pembuatan, pengembalian, penghapusan, dan perubahan stok berjalan dalam satu transaksi
- [x] 6.3.3 ubah jumlah atau barang pada peminjaman `dipinjam` menghitung ulang kedua barang yang terdampak

## 5. Kebutuhan non-fungsional

- [x] NFR-1 seluruh fitur berjalan tanpa internet
- [~] NFR-2 CRUD terasa instan, daftar sampai sekitar 5.000 baris tetap lancar (indeks sudah ada, belum diuji dengan 5.000 baris nyata)
- [x] NFR-3 tidak ada inkonsistensi stok saat aplikasi tertutup mendadak, karena semua tulisan bertransaksi
- [ ] NFR-4 antarmuka Bahasa Indonesia, Material 3, maksimal 3 ketuk untuk mencatat peminjaman dari layar utama
- [~] NFR-5 Android 7.0 API 24 ke atas (perlu dicek di `build.gradle` sebelum rilis)
- [x] NFR-6 data hanya di perangkat, tidak ada pengiriman keluar
- [ ] NFR-7 error DB tampil lewat SnackBar tanpa membuat aplikasi berhenti
- [x] NFR-8 pemisahan UI, state, repository, dan database

## 6. Impor barang dari CSV

Diminta di luar PRD. Data barang akan dikirim mentor dalam bentuk CSV.

- [x] Parser CSV: deteksi pemisah otomatis (`,` `;` tab), dukungan tanda kutip, baris baru di dalam kutip, BOM, dan pemisah baris CRLF
- [x] Pembacaan file dari HP memakai `file_picker`, fallback decode latin1 kalau file bukan UTF-8
- [x] Langkah pemetaan kolom: header dibaca, admin memilih kolom mana ke field mana, jadi nama kolom dari mentor tidak perlu ditebak
- [x] Baris pertama bisa ditandai sebagai header atau sebagai data
- [x] Duplikat dilewati berdasarkan kode barang, lalu ditampilkan ringkasan sebelum dan sesudah impor
- [x] Impor berjalan dalam satu transaksi, stok tersedia barang baru diset sama dengan stok total
- [x] Ringkasan hasil: jumlah masuk, jumlah dilewati, jumlah gagal beserta nomor baris dan alasannya
- [ ] `TODO(csv-format)`: contoh file CSV dari mentor belum ada. Setelah tiba, cek kolom apa saja yang tersedia dan apakah ada kolom yang belum tertampung, misalnya jumlah rusak
- [ ] `TODO(csv-merge)`: mode "perbarui yang sudah ada" belum dibuat, saat ini hanya "lewati duplikat"

## 7. Skenario pengujian PRD §11

- [x] T1 tambah barang stok 5, tersedia 5/5
- [x] T2 pinjam 2 unit, tersedia 3/5, status `dipinjam`
- [x] T3 pinjam 4 unit saat tersedia 3, ditolak
- [x] T4 tandai dikembalikan, status `selesai`, tersedia 5/5
- [x] T5 hapus peminjaman `dipinjam`, stok bertambah 2
- [x] T6 hapus peminjaman `selesai`, stok tidak berubah
- [x] T7 hapus barang yang masih dipinjam, ditolak
- [x] T8 ubah stok total 5 ke 8 saat 2 dipinjam, tersedia 6/8
- [x] T9 ubah stok total ke 1 saat 2 dipinjam, ditolak
- [x] T10 tanggal kembali sebelum tanggal pinjam, ditolak
- [x] T11 jumlah pinjam 0 atau negatif, ditolak
- [x] T12 input kosong pada field wajib, ditolak dengan pesan
- [x] T13 urutan daftar sesuai aturan

T1 sampai T13 lulus di lapisan repository dan database, 32 tes. Yang belum: pengujian yang sama lewat layar, setelah UI jadi.

## 8. UI

- [ ] Tema Material 3 mode terang dan gelap mengikuti pengaturan HP
- [ ] `HomeShell` dengan navigasi bawah dua tab: Barang dan Peminjaman
- [ ] Layar daftar barang: pencarian, daftar, indikator stok, tombol tambah, empty state
- [ ] Layar form barang: mode tambah dan ubah, validasi, tombol hapus
- [ ] Layar impor barang dari CSV: pilih file, pemetaan kolom, pratinjau, ringkasan
- [ ] Layar daftar peminjaman: filter status, chip status dan Terlambat, tombol tambah
- [ ] Layar form peminjaman: pilih barang beserta stok tersedia, jumlah, dua date picker, catatan
- [ ] Layar detail peminjaman: seluruh data, tandai dikembalikan, ubah, hapus
- [ ] Tiga keadaan pada setiap daftar: kosong, memuat, dan gagal
- [ ] SnackBar untuk hasil sukses dan gagal
- [ ] Dialog konfirmasi untuk semua aksi hapus
- [ ] Label aplikasi di Android masih `peminjaman_barang`, ubah menjadi "Peminjaman Barang"

## 9. Di luar MVP, dicatat supaya tidak hilang

- [ ] `TODO(export)`: ekspor dan cadangan CSV
- [ ] `TODO(multi-item)`: satu peminjaman untuk banyak barang sekaligus
- [ ] `TODO(statistics)`: dashboard ringkasan dan laporan
- [ ] `TODO(overdue-notif)`: notifikasi pengingat keterlambatan
- [ ] `TODO(qr)`: scan QR atau barcode barang
- [ ] `TODO(photo)`: foto barang
- [ ] `TODO(fine)`: denda keterlambatan
- [ ] `TODO(damage)`: barang rusak atau hilang mengurangi stok total
