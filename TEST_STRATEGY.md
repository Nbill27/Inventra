# Strategi Tes — Inventra (Peminjaman Barang)

Dokumen ini menetapkan **strategi tes menyeluruh** untuk aplikasi Inventra:
apa yang diuji, di lapisan mana, seberapa dalam, dan dengan urutan prioritas
mana. Sifat strategi ini adalah *risk-based* — tenaga tes dialokasikan ke kode
yang paling mahal bila salah, bukan ke kode yang paling mudah diuji.

Terakhir diperbarui: setelah commit `99d4b43`.
Toolchain acuan: Flutter 3.44.2 stable, Dart 3.12.2.

---

## 1. Tujuan dan prinsip

| Tujuan | Ukuran keberhasilan |
| --- | --- |
| Cegah kehilangan/kerusakan data | Nol bug data-integrity di jalur tulis (impor, peminjaman) yang lolos ke `main` |
| Cegah hasil ekspor/impor yang salah | Semua cabang parser punya tes eksplisit |
| Cegah regresi diam-diam | `flutter analyze` bersih + seluruh suite hijau di CI |
| Jaga determinisme | Nol tes bergantung pada `DateTime.now()` atau data global |
| Jaga kecepatan umpan balik | Suite unit+widget selesai < 3 menit di mesin dev |

Prinsip:

1. **Risk-based, bukan coverage-based.** 100% coverage pada tema/warna tidak
   mencegah satu pun insiden nyata. Prioritas: `services` → `repositories` →
   `providers` → `models` → layar dengan alur tulis.
2. **Uji perilaku, bukan implementasi.** Tes menegaskan kontrak (masukan →
   keluaran), bukan struktur privat. Bila sebuah refactor internal menggagalkan
   tes tanpa mengubah perilaku, tes itu salah tulis.
3. **Determinisme.** Waktu, urutan, dan data eksternal harus disuntikkan
   (lihat §7).
4. **Satu bug = satu tes baru.** Setiap bug produksi menambah tes yang gagal
   sebelum perbaikan dan hijau sesudahnya.
5. **Tes yang menggantung lebih buruk daripada tes yang gagal.** Tes tanpa
   batas waktu memblokir CI dan menutupi kegagalan lain (§10).

---

## 2. Konteks arsitektur

Aplikasi offline, satu perangkat, tanpa backend. Data di SQLite lokal
(`sqflite`), UI Flutter. Karena tidak ada server, **satu-satunya sumber
kebenaran data adalah perangkat pengguna** — kesalahan tulis/parsing tidak bisa
dikoreksi dari sisi lain. Ini menaikkan bobot risiko lapisan data.

```
lib/
  core/         validation, dates, formatters, exceptions, theme, text
  models/       Item, Loan (+statusOn), LoanDetail, stats, filter, ItemImport
  db/           DatabaseHelper (skema, migrasi, factory injeksi)
  repositories/ ItemRepository, LoanRepository   <- jalur tulis DB
  providers/    ItemProvider, LoanProvider       <- state + jam
  services/     csv_parser, sheet_reader, sheet_table, item_importer,
                loan_export_service                <- parsing & impor
  screens/      home, item_list, item_form, item_import, loan_list,
                loan_detail, loan_form, home_shell
  widgets/      history_card, loan_card, loan_progress_card, status_chip,
                status_pill, filter pill, app_chrome, error/empty state
```

---

## 3. Peta risiko

Skala dampak: **D** = kehilangan/kerusakan data, **S** = keamanan,
**T** = kepercayaan angka, **U** = kegagalan pemakaian (UI).

| Modul | Risiko utama bila salah | Level | Kelas |
| --- | --- | --- | --- |
| `services/item_importer.dart` | Barang salah terbaca/terlewat; stok salah; data duplikat masuk | P0 | D, T |
| `services/sheet_table.dart` | Deteksi judul kolom dan pemetaan blok berdampingan salah; baris tanda tangan ikut terimpor | P0 | D |
| `services/sheet_reader.dart` | Indeks baris meleset; lembar kosong; berkas rusak tidak ditolak | P0 | D |
| `services/csv_parser.dart` | Kutipan/pemisah salah; ribuan vs desimal tertukar; baris bocor | P0 | D |
| `repositories/loan_repository.dart` | Peminjaman tanpa barang valid; tanggal kembali mustahil; stok tersisa tidak turun | P0 | D, T |
| `repositories/item_repository.dart` | Kode barang duplikat; pembaruan stok menimpa nilai baru | P0 | D |
| `db/database_helper.dart` | Migrasi merusak skema; FK tidak aktif | P0 | D |
| `services/loan_export_service.dart` | Formula injection di CSV; status/tanggal salah hari | P1 | S, T |
| `providers/loan_provider.dart` | Data basi lintas hari; muat ulang menimpa hasil muat terbaru | P1 | T |
| `models/loan.dart` (`statusOn`) | Label "terlambat/selesai" salah pada batas hari | P1 | T |
| `core/validation.dart` | Kontak valid ditolak / kontak berbahaya diterima | P1 | S, U |
| `screens/loan_form_screen.dart` | Grafik tulis lewat UI tanpa umpan balik hasil | P1 | D, U |
| `screens/item_import_screen.dart` | Pratinjau menyesatkan; tombol aktif saat impor tak mungkin | P1 | U |
| `widgets/*`, tema, teks | Kontras, target sentuh, semantik pembaca layar | P2 | U |

Konsekuensi alokasi: **±70% tes baru menyasar `services` + `repositories` +
`providers`.**

---

## 4. Inventaris tes saat ini

Total **109 tes** di 11 berkas (per `99d4b43`).

| Berkas | Jumlah | Lapisan | Status | Catatan |
| --- | --- | --- | --- | --- |
| `test/csv_parser_test.dart` | 13 | unit | hijau | kutipan, BOM, CRLF, pemisah |
| `test/sheet_reader_test.dart` | 8 | unit | hijau | xlsx → grid |
| `test/sheet_table_test.dart` | 15 | unit | hijau | deteksi judul, blok berdampingan |
| `test/item_importer_test.dart` | 13 | unit | hijau | rencana impor |
| `test/item_repository_test.dart` | 14 | repositori | hijau | CRUD, stok, kode duplikat |
| `test/loan_repository_test.dart` | 20 | repositori | hijau | tanggal, agregat, laporan |
| `test/loan_provider_test.dart` | 4 | provider | hijau | **baru** — injeksi jam |
| `test/validation_test.dart` | 7 | unit | hijau | **baru** — kontak |
| `test/screen_render_test.dart` | 1 | smoke | hijau | pola `runAsync` |
| `test/item_import_test.dart` | 7 | unit integrasi | **1 gagal** | pesan validasi usang |
| `test/item_import_screen_test.dart` | 7 | widget | **7 gagal** | lihat §10 |
| `test/support/test_database.dart` | — | harness | — | DB `:memory:` + fixture |

Harness bersama sudah bagus: `createTestDatabase()` memakai `databaseFactoryFfi`
dengan `:memory:`, `itemFixture()`, `loanFixture()`. Semua tes DB memakai DB
bersih per kasus — pertahankan pola ini.

---

## 5. Matriks cakupan: risiko → lapisan → status

| Area | Unit | Repositori | Provider | Widget | Integrasi | Status |
| --- | :-: | :-: | :-: | :-: | :-: | --- |
| Parser CSV | ✅ | — | — | — | ⬜ | Baik |
| Reader/Tabel xlsx | ✅ | — | — | — | ⬜ | Baik |
| Rencana impor | ✅ | ⬜ | — | ⬜ | ❌ | Kurang |
| Impor lewat UI (end-to-end) | — | — | — | ❌ | ❌ | **Gap** |
| CRUD barang & stok | ✅ | ✅ | ⬜ | ⬜ | ❌ | Cukup |
| CRUD peminjaman | ✅ | ✅ | ⬜ | ⬜ | ❌ | Cukup |
| Statistik | ⬜ | ✅ | ⬜ | — | — | Kurang |
| Ekspor (CSV & xlsx) | ❌ | — | — | ❌ | ❌ | **Gap** |
| Injeksi jam / basi | ⬜ | — | ✅ | ❌ | — | Kurang |
| Validasi kontak | ✅ | — | — | ❌ | — | Cukup |
| Aksesibilitas & semantik | — | — | — | ⬜ | — | **Gap** |
| Migrasi skema | ❌ | ⬜ | — | — | — | **Gap** |

Keterangan: ✅ memadai · ⬜ sebagian · ❌ belum ada.

---

## 6. Celah prioritas

| ID | Celah | Risiko | Prioritas |
| --- | --- | --- | --- |
| G-01 | `loan_export_service` tanpa tes sama sekali — padahal ini jalur keamanan (formula injection) | S, T | **P0** |
| G-02 | `item_import_screen_test.dart` rusak total → perjalanan impor lewat UI tidak tervalidasi | D, U | **P0** |
| G-03 | Tidak ada tes migrasi skema (`DatabaseHelper.onUpgrade`) | D | **P0** |
| G-04 | Tidak ada tes bahwa `stopAtBlank` benar-benar berhenti di baris kosong **pada berkas nyata** (fixture lama tidak menulis baris kosong) | D | **P0** |
| G-05 | `ItemProvider` tanpa tes (muat ulang, kegagalan, tombol coba lagi) | U | P1 |
| G-06 | Tidak ada tes widget untuk aksesibilitas: semantik chip filter, tooltip hapus, target sentuh ≥48 dp | U | P1 |
| G-07 | `LoanProvider` hanya 4 tes; belum menguji `isStale` lintas hari & balapan muat ulang | T | P1 |
| G-08 | Statistik (`ItemStats`, `LoanStats`) hanya diuji lewat repositori, bukan batas (nol, negatif, semua terlambat) | T | P1 |
| G-09 | `currency`/`formatDate`/`dateOnly` (batas hari, zona waktu) tanpa tes | T | P1 |
| G-10 | Tidak ada `integration_test/` — alur nyata (buat barang → pinjam → kembali → ekspor) belum pernah diuji end-to-end | D, U | P2 |
| G-11 | Tidak ada CI sehingga semua gerbang hanya berjalan manual | proses | P1 |

---

## 7. Disiplin determinisme (aturan keras)

Bug "hari yang salah" berasal dari jam global. Aturan:

1. `lib/` **dilarang** memanggil `DateTime.now()` di luar titik masuk yang
   disetujui. Sumber "hari ini" adalah `LoanProvider.today` (disuntik).
2. Widget yang menampilkan tanggal/status harian **wajib** menerima `today`
   sebagai parameter opsional, dengan `DateTime.now()` hanya sebagai fallback
   produksi. Saat ini masih ada celah konsistensi: `HistoryCard`,
   `StatusChip`, dan `LoanProgressCard` tidak selalu menerima `today` dari
   pemanggil, sehingga di tes tidak bisa dikunci. **Perbaiki threading ini
   sebelum menambah tes widget tanggal.**
3. Tes **wajib** mengunci waktu: `LoanProvider(clock: () => DateTime(2026, 10, 12))`.
4. Larang `sleep`/`pumpAndSettle` tanpa batas untuk menunggu pekerjaan DB.

Tambahkan penjaga otomatis: satu tes/grep sederhana yang gagal bila
`DateTime.now()` muncul di `lib/` selain daftar putih yang disepakati.

---

## 8. Rencana tes per lapisan

### 8.1 Unit — parsing & impor (P0)

Sasaran: setiap cabang `csv_parser`, `sheet_reader`, `sheet_table`,
`item_importer` punya tes dengan nama yang menyebut perilaku.

Kasus wajib tambahan (belum ada / perlu diperkuat):

- Baris kosong **interior** di `.xlsx` mensintesis baris kosong sehingga
  `stopAtBlank` benar-benar berhenti (G-04). Fixture harus menulis sel kosong
  eksplisit, bukan baris kosong (`appendRow([])` hilang saat disimpan).
- Baris tanda tangan di bawah blok (mis. "Disetujui oleh") **tidak** menjadi
  barang.
- Angka: `1.500`, `1.500,5`, `1,500.5`, `1.234.567`, spasi sebagai pemisah
  ribuan, tanda minus, sel berisi hanya tanda baca.
- CSV: kutipan ganda (`""`), kutipan tidak ditutup (ditolak), pemisah `;`
  vs `,`, BOM, CRLF, sel multi-baris, baris terakhir tanpa newline.
- Judul kolom duplikat (`NAMA` dua kali), judul tak dikenal, jumlah kolom tidak
  seragam antar baris.
- Workbook multi-lembar: hasil digabung, bukan saling menimpa.
- Berkas bukan xlsx / rusak → `StorageException` dengan pesan Indonesia.

### 8.2 Unit — model & utilitas (P1)

- `Loan.statusOn` pada batas hari: besok, hari ini, kemarin, `returnDate` tepat
  di `dueDate`, tepat sehari setelah `dueDate`.
- `dateOnly`, `formatDate`, `currency` pada nilai nol, besar, dan lokal.
- `validation.dart` untuk kontak: nomor dengan `+62`/`08`/spasi/dash, email,
  tautan WA (`wa.me`, `api.whatsapp.com`), input kosong, dan penolakan bentuk
  yang jelas salah. Termasuk aturan longgar (menerima `@`, `_`, `.`) yang
  disengaja — kunci perilakunya, jangan longgarkan tesnya.

### 8.3 Repositori (P0)

Sudah 34 tes; lengkapi batas berikut:

- **FK**: menghapus barang yang masih dipinjam **gagal** (tanpa cascade) —
  kunci perilaku ini secara eksplisit.
- Menandai kembali: tanggal `> hari ini` **ditolak**; stok tersedia naik tepat
  sekali (tidak dobel bila dipanggil dua kali).
- Impor massal: N barang dengan 1 kode duplikat → sisanya tetap masuk, laporan
  menyebut kode yang dilewati.
- Statistik pada dataset kosong (tidak `NaN`, tidak bagi nol).
- Pemulihan setelah gagal: transaksi yang gagal tidak menyisakan baris separuh.

### 8.4 Provider (P1)

- `LoanProvider`: muat ulang saat `isStale`; hasil muat **terbaru menang**
  (balapan dua `load()` yang selesai terbalik — kunci request-id);
- kegagalan muat → state error, bukan daftar kosong; tombol coba lagi memuat
  ulang;
- pergantian hari (`clock` dimajukan) → `isStale` benar; filter "hari ini"
  mengikuti `today` baru.
- `ItemProvider`: muat, kegagalan, muat ulang setelah impor.

### 8.5 Service ekspor (P0 — celah G-01)

- **Netralisasi formula**: untuk setiap masukan berawalan `=`, `+`, `-`, `@`,
  tab, CR: keluaran CSV **tidak** dimulai karakter berbahaya; nilai lain tidak
  berubah. Uji juga bahwa netralisasi tidak merusak nilai sah (mis. `RAB/01/01`,
  `-` di tengah teks).
- Header kolom ekspor tidak berubah (kontrak berkas untuk pengguna).
- `statusLabel(loan, today)` memakai `today` yang diberikan, bukan hari nyata.
- xlsx: tipe sel adalah teks, sehingga tidak ada sel yang dievaluasi sebagai
  rumus.
- `build()` mengembalikan byte non-kosong untuk daftar kosong (header saja).

### 8.6 Widget & aksesibilitas (P1–P2)

Untuk layar dengan alur tulis (`item_import`, `loan_form`, `item_list`,
`loan_list`, `loan_detail`):

- Keadaan: memuat, kosong, galat + tombol coba lagi, sukses.
- Tidak ada tombol aktif saat aksi mustahil (mis. impor tanpa baris; kembali
  untuk peminjaman yang belum mulai).
- Aksesibilitas: target sentuh ≥48 dp; chip filter punya label semantik;
  tombol ikon punya tooltip; urutan fokus wajar; kontras AA.
- Uji semantik dengan `tester.getSemantics` / `matchesSemantics`, bukan sekadar
  mencari `Text`.

Perbaiki celah threading `today` (§7) lebih dulu agar tes tanggal bisa dikunci.

### 8.7 Integrasi / end-to-end (P2)

`integration_test/` dengan satu alur emas dan satu alur gagal:

1. Buat 2 barang → pinjam 1 → tandai kembali → ekspor riwayat → cek berkas
   berisi 1 baris dengan status selesai.
2. Impor xlsx mirip berkas mentor (dengan blok berdampingan, baris kosong,
   baris tanda tangan) → pastikan jumlah barang **4** dan "Disetujui oleh"
   **tidak** ada.
3. Kegagalan: impor CSV rusak → pesan jelas, data lama tidak berubah.

Jalankan di runner Android (emulator) di CI, bukan hanya di mesin dev.

---

## 9. Harness & data uji

Perluas `test/support/`:

| Berkas | Isi |
| --- | --- |
| `test_database.dart` | (sudah ada) DB `:memory:` + fixture |
| `clock.dart` | `fixedClock(DateTime)`, helper maju mundur hari |
| `workbooks.dart` | Pembuat xlsx: **baris kosong eksplisit**, blok berdampingan, judul di bawah blok judul |
| `pump.dart` | `settle(tester)` dengan tenggat pendek; `runDb(tester, fn)` pembungkus `runAsync` |
| `goldens/` (opsional) | Tangkapan layar untuk layar kunci |

Aturan fixture: **fixture harus menyerupai berkas nyata.** Kesalahan yang
ditemukan pada `99d4b43` muncul justru karena fixture menulis baris kosong
sebagai daftar kosong yang hilang saat disimpan — sehingga yang diuji bukan
bentuk berkas sebenarnya.

---

## 10. Memperbaiki dua suite impor yang gagal

Ini prasyarat sebelum menambah tes impor apa pun.

### 10.1 `test/item_import_test.dart` — 1 gagal

**Gejala:** mengharapkan teks `Nama barang`, menerima
`Nama alat ukur wajib diisi.`
**Akar masalah:** ekspektasi usang setelah pesan validasi diganti.
**Perbaikan:** perbarui ekspektasi ke pesan baru, atau (lebih baik) jadikan
pesan sebagai konstanta bersama agar tes dan kode tidak bisa menyimpang.

### 10.2 `test/item_import_screen_test.dart` — 7 gagal

**Gejala:**

- Kasus 1 (`imports an xlsx whose header sits under a title block`) gagal cepat
  di `expect(find.textContaining('4 baris data'), findsOneWidget)`, baris 147.
- Kasus 2–7 gagal setelah kasus pertama menggantung, dengan jejak menunjuk
  `pumpWidget` (`baris 116`) — tanda *cascade*: satu tes yang menggantung
  mengotori sisanya, sehingga kegagalan terlihat seragam.

**Akar masalah (terverifikasi lewat probe langsung pipeline):**

1. **Fixture tidak realistis.** `workbookBytes(...)` menulis baris kosong
   sebagai `appendRow([])`; baris seperti itu **hilang saat workbook disimpan
   dan dibaca ulang**. Akibatnya grid kehilangan baris kosong, `stopAtBlank`
   tidak pernah berhenti, baris tanda tangan "Disetujui oleh" **ikut masuk**,
   dan jumlah baris menjadi **5**, bukan 4.
2. **Bukti kode produksi benar.** Ketika baris kosong ditulis sebagai sel
   kosong eksplisit (bentuk berkas Excel nyata), `suggestHeaderRow` → 4
   (baris Excel 5), `tableFromGrid` → **4 baris** dengan nomor baris
   `[6, 7, 6, 7]`, dan baris tanda tangan **berhasil dibuang**. Jadi ini bug
   fixture/ekspektasi, **bukan regresi `99d4b43`.**
3. **Tes yang menggantung.** Kasus 2–7 memakai `pumpAndSettle()` sementara alur
   menyentuh DB FFI nyata atau indikator memuat; ketika tidak bisa "settle",
   bawaan `pumpAndSettle` menunggu hingga **10 menit**, lalu mengotori kasus
   berikutnya. Pola yang benar sudah ada di `test/screen_render_test.dart`:
   `tester.pump()` + `tester.runAsync()`.

**Perbaikan yang diminta (urut):**

1. Ganti pembuat fixture agar menulis baris kosong eksplisit:

   ```dart
   List<CellValue?> blankRow(int width) =>
       List.generate(width, (_) => TextCellValue(''));
   ```

2. Ganti pekerjaan DB di dalam widget test ke `runAsync`, dan ganti
   `pumpAndSettle()` dengan `pump()` bertenggat pendek:

   ```dart
   await tester.runAsync(() => repository.create(itemFixture()));
   await tester.pump(); // bukan pumpAndSettle()
   ```

3. Tambahkan helper `settle(tester)` dengan tenggat ≤ 10 detik agar tes yang
   menggantung gagal cepat, bukan menahan CI 10 menit.

**Verifikasi saat ini (before):** `flutter analyze --no-pub` bersih; suite inti
75 hijau; dua berkas di atas gagal dengan sebab di atas. Sasaran (after): 109 +
tes baru, semua hijau, suite < 3 menit.

---

## 11. CI — belum ada, usulan

Repo belum punya `.github/`. Tanpa CI, semua gerbang bergantung pada disiplin
manual. Usulan minimal (`.github/workflows/ci.yml`):

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 3.44.2
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter analyze --no-pub
      - run: flutter test --no-pub --coverage --reporter compact
      - name: Ambang cakupan
        run: |
          pip install --quiet lcov_cobertura >/dev/null 2>&1 || true
          # ganti dengan pemeriksa ambang favorit; gagal bila turun
      - uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/lcov.info
```

Plus satu job emulator (Android) untuk `integration_test/`, dijalankan pada
`pull_request` saja agar hemat waktu:

```yaml
  e2e:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: flutter pub get
      - uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 34
          arch: x86_64
          script: flutter test integration_test
```

Gerbang wajib di `main`:

- `flutter analyze` → nol isu.
- `flutter test` → nol gagal, nol tes menggantung.
- Ambang cakupan per direktori (§12) tidak turun.
- `gradlew help` / `flutter build apk --debug` sukses (jaga konfigurasi rilis
  `key.properties` tetap valid).

---

## 12. Metrik dan target

| Metrik | Sekarang | Target |
| --- | --- | --- |
| `flutter analyze` | bersih | tetap bersih |
| Tes total | 109 (10 gagal) | 150+, 0 gagal |
| Cakupan `lib/services` | belum diukur | ≥ 90% baris, semua cabang parser |
| Cakupan `lib/repositories` | belum diukur | ≥ 85% |
| Cakupan `lib/providers` | belum diukur | ≥ 85% |
| Cakupan `lib/core` + `lib/models` | belum diukur | ≥ 90% |
| Cakupan `lib/screens` + `lib/widgets` | — | tanpa target baris; checklist perilaku + a11y per layar kunci |
| Waktu suite unit+widget | belum diukur | < 3 menit |
| Tes menggantung | ada | 0 |
| E2E alur emas | tidak ada | 3 skenario |

Cakupan diukur dengan `flutter test --coverage` lalu `coverage/lcov.info`.

---

## 13. Backlog tes terurut

| ID | Prioritas | Berkas yang dibuat/disentuh | Isi |
| --- | --- | --- | --- |
| T-01 | P0 | `test/item_import_screen_test.dart`, `test/support/workbooks.dart` | Perbaiki fixture baris kosong + ganti `pumpAndSettle` (menutup G-02, G-04) |
| T-02 | P0 | `test/item_import_test.dart` | Perbarui pesan validasi (konstanta bersama) |
| T-03 | P0 | `test/loan_export_service_test.dart` **(baru)** | Netralisasi formula, hari `today`, tipe sel xlsx (G-01) |
| T-04 | P0 | `test/sheet_table_test.dart`, `test/item_importer_test.dart` | Baris kosong nyata, baris tanda tangan tidak terimpor, angka ribuan/desimal |
| T-05 | P0 | `test/database_helper_test.dart` **(baru)** | Migrasi skema, FK aktif, indeks, buka-tutup berulang (G-03) |
| T-06 | P0 | `test/loan_repository_test.dart` | FK hapus barang, tanggal kembali mustahil, stok naik tepat sekali |
| T-07 | P1 | `test/loan_provider_test.dart` | `isStale` lintas hari, balapan `load()` (request-id), state galat |
| T-08 | P1 | `test/item_provider_test.dart` **(baru)** | Muat, galat, muat ulang setelah impor (G-05) |
| T-09 | P1 | `test/core_utils_test.dart` **(baru)** | `dateOnly`, `formatDate`, `currency`, batas hari (G-09) |
| T-10 | P1 | `test/models_loan_test.dart` **(baru)** | `statusOn` pada batas hari (G-08) |
| T-11 | P1 | `test/a11y_test.dart` **(baru)** | Semantik chip filter, tooltip hapus, target sentuh ≥48 dp (G-06) |
| T-12 | P1 | `.github/workflows/ci.yml` **(baru)** | Gerbang analyze + test + cakupan (G-11) |
| T-13 | P2 | `integration_test/golden_flow_test.dart` **(baru)** | Alur emas barang → pinjam → kembali → ekspor, plus jalur gagal (G-10) |
| T-14 | P2 | `test/support/pump.dart` | Helper `settle` bertenggat pendek |
| T-15 | P2 | `test/import_goldens/` | Berkas xlsx/csv contoh untuk regresi bentuk berkas |

Definisi selesai (DoD) untuk tiap butir: `flutter analyze` tetap bersih, tes
baru hijau, tidak ada tes yang menggantung, dan bila butir memperbaiki bug —
ada commit tes yang gagal sebelum perbaikan.

---

## 14. Cara menjalankan

```sh
# seluruh suite
flutter test

# satu berkas (disarankan saat mendiagnosis)
flutter test test/item_import_screen_test.dart --reporter expanded

# satu kasus saja (untuk membedakan kegagalan nyata vs cascade)
flutter test test/item_import_screen_test.dart --plain-name "menjelaskan bahwa"

# statis
flutter analyze --no-pub

# cakupan
flutter test --coverage
```

Diagnosis dua suite impor: jalankan **satu kasus per perintah** dengan
`--plain-name`. Bila satu kasus lulus sendiri tetapi gagal saat dijalankan
bersama, penyebabnya adalah kebocoran async dari kasus sebelumnya
(§10.2 butir 3), bukan logika kasus tersebut.

---

## 15. Risiko strategi dan mitigasi

| Risiko | Mitigasi |
| --- | --- |
| Tes widget rapuh terhadap perubahan teks | Cari berdasarkan peran/semantik atau konstanta bersama, bukan string bebas |
| Fixture menyimpang dari berkas nyata | Simpan contoh berkas asli di `test/support/` dan uji dari berkas itu |
| Tes DB lambat | Pertahankan DB `:memory:`; hindari membuat helper berulang per kasus |
| Cakupan tinggi tapi bug lolos | Prioritaskan cabang (branch) di parser; cakupan baris saja tidak cukup |
| Jam global muncul kembali | Penjaga grep + threading `today` yang konsisten (§7) |
| Tes menggantung memblokir CI | Tenggat `pumpAndSettle` ≤ 10 detik + tenggat job CI |
