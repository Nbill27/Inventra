# PRD: Sistem Peminjaman Barang (Android, Flutter, Offline)

| | |
|---|---|
| **Versi** | 1.0 (MVP: CRUD) |
| **Tanggal** | 16 Oktober 2026 |
| **Platform** | Android (Flutter) |
| **Mode** | Offline penuh (database lokal) |
| **Status** | Perancangan |

---

## 1. Ringkasan

Aplikasi mobile Android untuk mencatat peminjaman barang secara manual oleh satu pengguna (admin/pengelola). Aplikasi berjalan sepenuhnya offline, menyimpan data di perangkat, dan mencakup dua modul inti: **Barang** dan **Peminjaman**. Desainnya generik sehingga jenis barang yang dipinjam bisa ditentukan belakangan.

## 2. Latar Belakang dan Masalah

Pencatatan peminjaman barang secara manual (buku, kertas, atau chat) rawan masalah:

- Stok barang tidak terpantau akurat.
- Sulit mengetahui siapa meminjam apa dan kapan harus kembali.
- Riwayat peminjaman mudah hilang atau tercecer.

Aplikasi ini menggantikan pencatatan manual tersebut dengan pencatatan digital yang sederhana, cepat, dan tidak membutuhkan internet.

## 3. Tujuan dan Non-Tujuan

### 3.1 Tujuan
1. Admin dapat mengelola data barang (tambah, lihat, ubah, hapus).
2. Admin dapat mencatat dan mengelola peminjaman (tambah, lihat, ubah, hapus, tandai dikembalikan).
3. Stok barang otomatis sinkron dengan transaksi peminjaman dan pengembalian.
4. Admin dapat melihat peminjaman yang melewati tenggat secara visual.
5. Aplikasi berjalan lancar tanpa koneksi internet.

### 3.2 Non-Tujuan (di luar scope MVP)
- Login, registrasi, atau multi-user
- Role peminjam dan alur approval
- Backend, API, atau sinkronisasi cloud
- Notifikasi (push maupun lokal)
- Dashboard ringkasan dan laporan
- Scan QR/barcode
- Upload foto barang
- Backup/ekspor data
- Denda atau sanksi keterlambatan

## 4. Pengguna

| Atribut | Deskripsi |
|---|---|
| **Persona** | Admin/pengelola barang (satu orang) |
| **Perangkat** | Smartphone Android milik admin |
| **Kemampuan teknis** | Dasar; butuh antarmuka sederhana dan cepat |
| **Konteks pakai** | Mencatat saat serah terima dan pengembalian barang, sering sambil berdiri atau bergerak |

**Catatan:** Peminjam **tidak** memakai aplikasi. Nama peminjam hanya diketik sebagai data oleh admin.

## 5. Alur Penggunaan

### 5.1 Alur utama

```
Tambah data barang
       │
       ▼
Peminjam datang ──► Admin catat peminjaman ──► Stok tersedia berkurang
                                                     │
                                                     ▼
                                   Status: DIPINJAM (pantau di daftar)
                                                     │
                                  Peminjam mengembalikan barang
                                                     │
                                                     ▼
                       Admin tandai "Dikembalikan" ──► Stok tersedia bertambah
                                                     │
                                                     ▼
                                              Status: SELESAI
```

### 5.2 Status peminjaman

| Status | Arti |
|---|---|
| `dipinjam` | Barang sedang di tangan peminjam |
| `selesai` | Barang sudah dikembalikan |
| *Terlambat* (tampilan saja) | Status `dipinjam` dan tanggal kembali rencana sudah lewat; tidak disimpan sebagai status di database |

## 6. Kebutuhan Fungsional

### 6.1 Modul Barang

| ID | Kebutuhan | Prioritas |
|---|---|---|
| FR-B1 | Admin dapat menambah barang: nama (wajib), kode, kategori, stok total (wajib), catatan | Must |
| FR-B2 | Admin dapat melihat daftar barang beserta stok tersedia dan stok total | Must |
| FR-B3 | Admin dapat mencari barang berdasarkan nama atau kode | Must |
| FR-B4 | Admin dapat melihat detail barang | Must |
| FR-B5 | Admin dapat mengubah data barang | Must |
| FR-B6 | Admin dapat menghapus barang dengan dialog konfirmasi | Must |
| FR-B7 | Penghapusan diblokir jika barang masih memiliki peminjaman berstatus `dipinjam` | Must |
| FR-B8 | Saat stok total diubah, stok tersedia disesuaikan sebesar selisihnya; hasil tidak boleh negatif | Must |

### 6.2 Modul Peminjaman

| ID | Kebutuhan | Prioritas |
|---|---|---|
| FR-L1 | Admin dapat mencatat peminjaman: barang (wajib), nama peminjam (wajib), kontak, jumlah (wajib), tanggal pinjam (wajib), tanggal kembali rencana (wajib), catatan | Must |
| FR-L2 | Jumlah pinjam tidak boleh melebihi stok tersedia barang | Must |
| FR-L3 | Tanggal kembali rencana tidak boleh sebelum tanggal pinjam | Must |
| FR-L4 | Saat peminjaman dibuat, stok tersedia berkurang sebesar jumlah pinjam | Must |
| FR-L5 | Admin dapat melihat daftar peminjaman, diurutkan dari yang terbaru | Must |
| FR-L6 | Admin dapat memfilter daftar berdasarkan status (semua, dipinjam, selesai) | Should |
| FR-L7 | Admin dapat melihat detail peminjaman | Must |
| FR-L8 | Admin dapat mengubah data peminjaman | Must |
| FR-L9 | Admin dapat menandai peminjaman "Dikembalikan" (mengisi tanggal kembali aktual, status menjadi `selesai`, stok tersedia bertambah) | Must |
| FR-L10 | Admin dapat menghapus catatan peminjaman dengan konfirmasi | Must |
| FR-L11 | Hapus peminjaman berstatus `dipinjam` mengembalikan stok; hapus yang berstatus `selesai` tidak mengubah stok | Must |
| FR-L12 | Peminjaman `dipinjam` yang lewat tanggal kembali rencana ditandai "Terlambat" di daftar dan detail | Should |

### 6.3 Aturan Bisnis Stok

1. `stock_available` tidak boleh kurang dari 0 dan tidak boleh melebihi `stock_total`.
2. Pembuatan peminjaman, pengembalian, penghapusan peminjaman, dan perubahan stok harus dijalankan dalam **satu transaksi database** (atomik). Jika salah satu langkah gagal, seluruhnya dibatalkan.
3. Mengubah jumlah atau barang pada peminjaman `dipinjam` harus menghitung ulang stok kedua barang yang terdampak (lama dan baru) secara konsisten.

## 7. Kebutuhan Non-Fungsional

| ID | Kategori | Kebutuhan |
|---|---|---|
| NFR-1 | Offline | Seluruh fitur berfungsi tanpa internet |
| NFR-2 | Performa | Daftar hingga ±5.000 data tetap lancar; operasi CRUD terasa instan (< 300 ms) |
| NFR-3 | Integritas data | Tidak ada inkonsistensi stok akibat aplikasi tertutup mendadak (gunakan transaksi) |
| NFR-4 | Kegunaan | Antarmuka Bahasa Indonesia, Material 3, maksimal 3 ketuk untuk mencatat peminjaman dari layar utama |
| NFR-5 | Kompatibilitas | Android 7.0 (API 24) ke atas |
| NFR-6 | Privasi | Data hanya tersimpan lokal di perangkat; tidak ada pengiriman data keluar |
| NFR-7 | Keandalan | Error operasi DB ditangani dan ditampilkan lewat SnackBar tanpa membuat aplikasi crash |
| NFR-8 | Maintainability | Kode dipisah: UI, state, repository, database |

## 8. Desain Layar

| # | Layar | Isi utama |
|---|---|---|
| 1 | **Daftar Barang** | Search bar, list barang (nama, kategori, stok tersedia/total), FAB tambah, empty state |
| 2 | **Form Barang** | Field nama, kode, kategori, stok total, catatan; mode tambah/edit; validasi |
| 3 | **Daftar Peminjaman** | Filter status, list (nama peminjam, barang, jumlah, tgl kembali, chip status/Terlambat), FAB tambah |
| 4 | **Form Peminjaman** | Dropdown barang (menampilkan stok tersedia), nama, kontak, jumlah, date picker pinjam dan kembali, catatan |
| 5 | **Detail Peminjaman** | Seluruh data, tombol "Tandai Dikembalikan", Edit, Hapus |

**Navigasi:** `BottomNavigationBar` dengan 2 tab: **Barang** dan **Peminjaman**.

**Komponen UI penting**
- Dialog konfirmasi untuk semua aksi hapus
- SnackBar untuk umpan balik sukses/gagal
- Chip status: `Dipinjam`, `Selesai`, `Terlambat` (warna berbeda)
- Empty state yang jelas pada tiap daftar

## 9. Model Data

### 9.1 ERD

```
┌──────────────┐ 1          N ┌──────────────────┐
│    items     │──────────────│      loans       │
├──────────────┤              ├──────────────────┤
│ id (PK)      │              │ id (PK)          │
│ name         │              │ item_id (FK)     │
│ code         │              │ borrower_name    │
│ category     │              │ contact          │
│ stock_total  │              │ quantity         │
│ stock_avail. │              │ loan_date        │
│ note         │              │ due_date         │
└──────────────┘              │ return_date      │
                              │ status           │
                              │ note             │
                              └──────────────────┘
```

### 9.2 Skema SQLite

```sql
CREATE TABLE items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  code TEXT,
  category TEXT,
  stock_total INTEGER NOT NULL,
  stock_available INTEGER NOT NULL,
  note TEXT
);

CREATE TABLE loans (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  item_id INTEGER NOT NULL,
  borrower_name TEXT NOT NULL,
  contact TEXT,
  quantity INTEGER NOT NULL,
  loan_date TEXT NOT NULL,        -- format ISO 8601 (YYYY-MM-DD)
  due_date TEXT NOT NULL,
  return_date TEXT,
  status TEXT NOT NULL,           -- 'dipinjam' | 'selesai'
  note TEXT,
  FOREIGN KEY (item_id) REFERENCES items(id)
);
```

### 9.3 Validasi field

| Field | Aturan |
|---|---|
| `items.name` | Wajib, maks. 100 karakter |
| `items.stock_total` | Wajib, bilangan bulat ≥ 0 |
| `loans.borrower_name` | Wajib, maks. 100 karakter |
| `loans.quantity` | Wajib, bilangan bulat ≥ 1, ≤ stok tersedia |
| `loans.due_date` | Wajib, ≥ `loan_date` |

## 10. Arsitektur Teknis

| Aspek | Pilihan |
|---|---|
| Framework | Flutter (Dart), null safety |
| Database | `sqflite` + `path` + `path_provider` |
| State management | `provider` |
| Tanggal | `intl` |
| Desain | Material 3 |

### Struktur folder

```
lib/
├── main.dart
├── db/
│   └── database_helper.dart
├── models/
│   ├── item.dart
│   └── loan.dart
├── repositories/
│   ├── item_repository.dart
│   └── loan_repository.dart
├── providers/
│   ├── item_provider.dart
│   └── loan_provider.dart
└── screens/
    ├── item_list_screen.dart
    ├── item_form_screen.dart
    ├── loan_list_screen.dart
    ├── loan_form_screen.dart
    └── loan_detail_screen.dart
```

### Pembagian tanggung jawab
- **Screens**: tampilan dan input pengguna
- **Providers**: state dan pemanggilan repository
- **Repositories**: logika CRUD dan aturan stok (termasuk transaksi)
- **database_helper**: membuka DB, membuat tabel, migrasi

## 11. Skenario Pengujian (Acceptance Criteria)

| # | Skenario | Hasil yang diharapkan |
|---|---|---|
| T1 | Tambah barang "Proyektor", stok 5 | Muncul di daftar, tersedia 5/5 |
| T2 | Pinjam 2 unit | Stok tersedia 3/5, status `dipinjam` |
| T3 | Pinjam 4 unit saat tersedia 3 | Ditolak dengan pesan error |
| T4 | Tandai dikembalikan | Status `selesai`, stok tersedia kembali 5/5 |
| T5 | Hapus peminjaman `dipinjam` (2 unit) | Stok tersedia bertambah 2 |
| T6 | Hapus peminjaman `selesai` | Stok tidak berubah |
| T7 | Hapus barang yang masih dipinjam | Ditolak dengan pesan penjelasan |
| T8 | Edit stok total 5 menjadi 8 saat 2 dipinjam | Stok tersedia 6/8 |
| T9 | Edit stok total menjadi 1 saat 2 dipinjam | Ditolak (hasil tersedia negatif) |
| T10 | Tanggal kembali sebelum tanggal pinjam | Validasi form menolak |
| T11 | Peminjaman `dipinjam` lewat tenggat | Muncul penanda "Terlambat" |
| T12 | Tutup paksa aplikasi saat menyimpan | Data tetap konsisten (transaksi atomik) |
| T13 | Mode pesawat | Semua fitur tetap berfungsi |

## 12. Risiko dan Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Data hilang jika HP rusak atau aplikasi di-uninstall (tidak ada backup) | Tinggi | Masukkan fitur backup/ekspor di fase berikutnya; informasikan risiko ke admin |
| Stok tidak sinkron karena bug logika | Tinggi | Semua perubahan stok lewat satu repository dalam transaksi; uji skenario T2 sampai T9 |
| Jenis barang belum jelas, skema bisa kurang pas | Sedang | Skema generik; tambah kolom lewat migrasi database |
| Nama peminjam diketik manual (typo, tidak konsisten) | Rendah | Tahap lanjut: autocomplete dari nama yang pernah dipakai |

## 13. Roadmap

| Fase | Cakupan |
|---|---|
| **Fase 1: MVP (saat ini)** | CRUD Barang, CRUD Peminjaman, logika stok, penanda terlambat, bottom nav |
| **Fase 2** | Backup/ekspor data (CSV atau file DB), dashboard ringkasan, riwayat dengan filter lanjutan |
| **Fase 3** | Notifikasi lokal jatuh tempo, foto barang, scan QR/barcode, autocomplete peminjam |
| **Fase 4 (opsional)** | Dukungan banyak barang per transaksi (`loan_items`), denda, sinkronisasi cloud |

### Urutan pengerjaan Fase 1
1. Setup project, dependencies, `database_helper`, model
2. CRUD Barang (repository, provider, 2 layar)
3. CRUD Peminjaman dengan logika stok dan transaksi
4. Navigasi bottom nav dan polishing UI
5. Pengujian manual (T1 sampai T13)

## 14. Pertanyaan Terbuka

1. Jenis barang apa yang akan dipinjam? (memengaruhi kategori dan kebutuhan field tambahan)
2. Apakah satu transaksi perlu mendukung banyak barang sekaligus? (saat ini: satu transaksi satu barang)
3. Apakah ada batas maksimal durasi atau jumlah pinjam per peminjam?
4. Apakah barang yang rusak atau hilang perlu dicatat dan mengurangi stok total?

## 15. Definisi Selesai (MVP)

- Semua kebutuhan berprioritas **Must** terimplementasi
- Skenario pengujian T1 sampai T13 lulus
- Aplikasi berjalan di perangkat Android nyata tanpa internet
- Tidak ada crash pada alur utama