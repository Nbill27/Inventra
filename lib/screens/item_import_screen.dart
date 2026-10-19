import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';
import '../core/exceptions.dart';
import '../models/item_import.dart';
import '../providers/item_provider.dart';
import '../services/csv_parser.dart';
import '../services/item_importer.dart';
import '../services/sheet_reader.dart';
import '../services/sheet_table.dart';
import '../widgets/app_background.dart';
import '../widgets/content_width.dart';
import '../widgets/panel.dart';
import '../widgets/section_header.dart';

/// Satu berkas yang sudah dibaca ke memori, sehingga tidak ada lagi bagian di
/// bawah baris ini yang menyentuh dialog berkas platform.
class PickedFile {
  const PickedFile({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

/// Bisa disuntik supaya layar dapat dijalankan di test tanpa pemilih sistem.
typedef ImportFilePicker = Future<PickedFile?> Function();

/// Pembaca mana yang dipakai sebuah berkas. Tidak semua format kantor bisa
/// dibaca, jadi isi berkas yang menentukan, bukan namanya.
enum PickedFileFormat { csv, spreadsheet }

/// Pemilih asli: Android membuka pemilih dokumennya, yang sudah memberi hak
/// baca pada satu berkas terpilih, jadi tidak ada izin penyimpanan yang diminta.
Future<PickedFile?> pickImportFileFromDevice() async {
  final file = await FilePicker.pickFile(
    dialogTitle: 'Pilih file data alat ukur',
    type: FileType.custom,
    allowedExtensions: ['xlsx', 'csv', 'txt', 'xls'],
  );
  if (file == null) {
    return null;
  }
  return PickedFile(fileName: file.name, bytes: await file.readAsBytes());
}

/// Excel menulis CSV memakai code page mesin, bukan UTF-8, jadi teks yang bukan
/// UTF-8 valid dibaca sebagai latin1 alih-alih menolak seluruh berkas.
String decodeText(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return latin1.decode(bytes);
  }
}

/// Mengimpor berkas induk "Daftar Alat Ukur", CSV atau Excel.
///
/// Layarnya sengaja pendek: pilih berkas, lalu kolomnya dibaca otomatis.
/// Semua hal teknis (lembar, baris judul, pratinjau) bersembunyi di balik
/// "Pengaturan lanjutan" supaya impor normal cukup dua ketukan.
class ItemImportScreen extends StatefulWidget {
  const ItemImportScreen({super.key, this.picker});

  /// Default ke dialog berkas perangkat.
  final ImportFilePicker? picker;

  @override
  State<ItemImportScreen> createState() => _ItemImportScreenState();
}

class _ItemImportScreenState extends State<ItemImportScreen> {
  static const _importer = ItemImporter();

  /// Berapa baris judul yang ditawarkan dropdown, supaya lembar yang lebar
  /// tidak menghasilkan menu dengan ratusan entri.
  static const _headerOptions = 60;

  final _stockPerRow = TextEditingController(text: '1');

  PickedFile? _file;
  PickedFileFormat _format = PickedFileFormat.csv;
  List<RawSheet> _sheets = const [];
  int _sheetIndex = 0;
  int? _headerRow;
  bool _stopAtBlankRows = true;
  bool _firstRowIsHeader = true;
  bool _showAdvanced = false;
  CsvTable? _table;

  /// Rencana dihitung saat tabel berubah, bukan di setiap build, supaya file
  /// besar tidak diparse ulang hanya karena layar digambar ulang.
  ImportPlan? _plan;
  String? _planError;

  /// Pemetaan manual untuk file tanpa judul kolom.
  int? _nameColumn;
  int? _stockColumn;

  bool _busy = false;
  String? _error;
  ImportReport? _report;

  @override
  void dispose() {
    _stockPerRow.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final picked = await (widget.picker ?? pickImportFileFromDevice)();
      if (!mounted) {
        return;
      }
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _busy = false;
        _load(picked);
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _fail(error.message);
      });
    } catch (error, stackTrace) {
      debugPrint('Gagal membaca berkas impor: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _fail('Gagal membaca berkas. Coba file lain.');
      });
    }
  }

  void _load(PickedFile picked) {
    _file = picked;
    _report = null;
    _sheets = const [];
    _sheetIndex = 0;
    _headerRow = null;
    _nameColumn = null;
    _stockColumn = null;
    _showAdvanced = false;

    if (looksLikeXlsx(picked.bytes)) {
      _format = PickedFileFormat.spreadsheet;
      _sheets = readWorkbook(picked.bytes);
      _headerRow = suggestHeaderRow(_sheets.first.grid);
    } else if (looksLikeOldExcel(picked.bytes)) {
      throw const StorageException(
        'Berkas .xls lama belum didukung. Simpan ulang sebagai .xlsx, lalu pilih lagi.',
      );
    } else {
      _format = PickedFileFormat.csv;
    }
    _readTable();
  }

  void _fail(String message) {
    _file = null;
    _sheets = const [];
    _table = null;
    _report = null;
    _error = message;
  }

  /// Membangun ulang tabel. Kolom dikenali lagi dari baris judul, jadi berkas,
  /// baris judul, atau lembar yang berbeda ikut terbaca otomatis.
  void _readTable() {
    _report = null;
    _plan = null;
    _planError = null;
    try {
      _table = _format == PickedFileFormat.spreadsheet ? _readSheet() : _readCsv();
      _error = null;
    } on AppException catch (error) {
      _table = null;
      _error = error.message;
    }
    _replan();
    // Saat belum ada yang bisa dibaca, buka pengaturan supaya baris judul bisa
    // diperbaiki tanpa mencari tombolnya.
    if (_table == null || _plan == null) {
      _showAdvanced = true;
    }
  }

  /// Menghitung ulang rencana tanpa membaca berkas lagi. Dipanggil saat stok
  /// atau pemetaan kolom berubah.
  void _replan() {
    final table = _table;
    if (table == null) {
      _plan = null;
      _planError = null;
      return;
    }
    try {
      _plan = _importer.plan(
        table: table,
        stockPerRow: _stockPerRowValue,
        nameColumn: _nameColumn,
        stockColumn: _stockColumn,
      );
      _planError = null;
    } on AppException catch (error) {
      _plan = null;
      _planError = error.message;
    }
  }

  CsvTable _readSheet() => tableFromGrid(
        _sheets[_sheetIndex].grid,
        headerRow: _headerRow,
        stopAtBlank: _stopAtBlankRows,
      );

  CsvTable _readCsv() =>
      parseCsv(decodeText(_file!.bytes), firstRowIsHeader: _firstRowIsHeader);

  /// Jumlah negatif bukan stok, jadi dibaca sebagai "belum diisi".
  int? get _stockPerRowValue {
    final value = int.tryParse(_stockPerRow.text.trim());
    return value == null || value < 0 ? null : value;
  }

  Future<void> _import(ImportPlan plan) async {
    final provider = context.read<ItemProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final report = await provider.importItems(plan.drafts);
      if (!mounted) {
        return;
      }
      // Rows rejected at preview time never reach the repository, so the final
      // report has to carry them too. Otherwise a mixed file says "0 gagal"
      // even though the preview listed skipped rows.
      final merged = ImportReport(
        added: report.added,
        skipped: report.skipped,
        issues: [...plan.issues, ...report.issues],
      );
      setState(() {
        _busy = false;
        _report = merged;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('${merged.added} barang ditambahkan.')),
      );
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impor Barang'),
        flexibleSpace: appBarScrim(),
      ),
      body: ContentWidth(
        child: report == null ? _setupView() : _reportView(report),
      ),
    );
  }

  Widget _setupView() {
    final table = _table;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceMd,
        AppTheme.spaceSm,
        AppTheme.spaceMd,
        AppTheme.spaceLg,
      ),
      children: [
        if (_error != null) ...[
          _errorPanel(_error!),
          const SizedBox(height: AppTheme.spaceMd),
        ],
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pilih berkas data alat ukur',
                style: AppText.headlineSm.copyWith(color: AppTheme.ink),
              ),
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                'Format Excel (.xlsx) atau CSV. Kolom dibaca otomatis, jadi '
                'tidak perlu atur apa-apa.',
                style: AppText.bodySm.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              FilledButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.folder_open),
                label: Text(_file == null ? 'Pilih file' : 'Ganti file'),
              ),
              if (_busy) ...[
                const SizedBox(height: AppTheme.spaceLg),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
        if (_file != null && !_busy) ...[
          const SizedBox(height: AppTheme.spaceMd),
          _filePanel(table),
          if (table != null) ...[
            const SizedBox(height: AppTheme.spaceMd),
            _summaryPanel(table),
            const SizedBox(height: AppTheme.spaceSm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _showAdvanced = !_showAdvanced),
                icon: Icon(
                  _showAdvanced ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(
                  _showAdvanced
                      ? 'Sembunyikan pengaturan'
                      : 'Pengaturan lanjutan',
                ),
              ),
            ),
            if (_showAdvanced) ...[
              const SizedBox(height: AppTheme.spaceSm),
              ..._advancedControls(table),
            ],
          ],
        ],
      ],
    );
  }

  /// Satu panel yang paling penting: berapa barang siap, dan tombol impor.
  ///
  /// Saat rencana belum bisa dibuat, panel tetap menampilkan isian yang
  /// dibutuhkan (pemetaan kolom dan stok), bukan hanya pesan error yang
  /// menghilangkan jalan keluarnya.
  Widget _summaryPanel(CsvTable table) {
    final plan = _plan;
    final detected = _importer.detectColumns(table);
    final hasStockColumn = _stockColumn != null ||
        detected.any((column) => column.label == 'Stok total');
    final hasNameColumn = _nameColumn != null ||
        detected.any((column) => column.label == 'Nama alat ukur');

    if (plan == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _errorPanel(
            _planError ??
                'Belum bisa diimpor dengan pengaturan berkas saat ini.',
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!hasNameColumn) ...[
                  _mappingControls(table),
                  const SizedBox(height: AppTheme.spaceMd),
                ],
                if (!hasStockColumn) ...[
                  _stockPerRowField(showError: true),
                  const SizedBox(height: AppTheme.spaceMd),
                ],
                Text(
                  'Isian di atas langsung memperbarui pratinjau.',
                  style: AppText.bodySm.copyWith(color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Siap diimpor',
            style: AppText.labelMd.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${plan.drafts.length}',
                style: AppText.headlineLg.copyWith(color: AppTheme.ink),
              ),
              const SizedBox(width: AppTheme.space6),
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space6),
                child: Text(
                  'barang',
                  style: AppText.style(
                    size: 14,
                    weight: 600,
                    color: AppTheme.ink2,
                  ),
                ),
              ),
            ],
          ),
          if (plan.issues.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              '${plan.issues.length} baris dilewati:',
              style: AppText.bodySm.copyWith(color: AppTheme.muted),
            ),
            for (final issue in plan.issues.take(5))
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.space2),
                child: Text(
                  'Baris ${issue.rowNumber}: ${issue.message}',
                  style: AppText.bodySm.copyWith(color: AppTheme.muted),
                ),
              ),
            if (plan.issues.length > 5)
              Text(
                '... dan ${plan.issues.length - 5} baris lagi.',
                style: AppText.bodySm.copyWith(color: AppTheme.muted),
              ),
          ],
          if (!hasStockColumn) ...[
            const SizedBox(height: AppTheme.spaceMd),
            _stockPerRowField(),
          ],
          if (_nameColumn != null) ...[
            const SizedBox(height: AppTheme.spaceMd),
            _mappingControls(table),
          ],
          const SizedBox(height: AppTheme.spaceMd),
          FilledButton.icon(
            onPressed: _busy || !plan.canImport ? null : () => _import(plan),
            icon: const Icon(Icons.download_done),
            label: Text(
              _busy ? 'Mengimpor…' : 'Impor ${plan.drafts.length} barang',
            ),
          ),
        ],
      ),
    );
  }

  /// Pemetaan manual dipakai saat baris judul tidak bisa dibaca, misalnya
  /// tabel tanpa judul yang kolomnya hanya bernama "Kolom 1", "Kolom 2".
  Widget _mappingControls(CsvTable table) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pemetaan kolom',
          style: AppText.style(size: 13.5, weight: 600, color: AppTheme.ink),
        ),
        const SizedBox(height: AppTheme.spaceXs),
        Text(
          'Pilih kolom yang berisi nama barang. Kolom stok boleh dikosongkan '
          'kalau jumlahnya diisi manual.',
          style: AppText.bodySm.copyWith(color: AppTheme.muted),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        _dropdown<int?>(
          label: 'Kolom nama barang *',
          value: _nameColumn,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Pilih kolom'),
            ),
            for (var i = 0; i < table.header.length; i++)
              DropdownMenuItem<int?>(
                value: i,
                child: Text(
                  _columnHint(table, i),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() {
            _nameColumn = value;
            _replan();
          }),
        ),
        _dropdown<int?>(
          label: 'Kolom stok (opsional)',
          value: _stockColumn,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Otomatis dari judul'),
            ),
            for (var i = 0; i < table.header.length; i++)
              DropdownMenuItem<int?>(
                value: i,
                child: Text(
                  _columnHint(table, i),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() {
            _stockColumn = value;
            _replan();
          }),
        ),
      ],
    );
  }

  /// Label kolom beserta contoh isinya, supaya "Kolom 3" bisa dikenali.
  String _columnHint(CsvTable table, int index) {
    final header = table.header[index];
    if (table.rows.isEmpty || index >= table.rows.first.length) {
      return header;
    }
    final sample = table.rows.first[index].trim();
    if (sample.isEmpty) {
      return header;
    }
    final shown = sample.length > 24 ? '${sample.substring(0, 24)}…' : sample;
    return '$header — $shown';
  }

  /// Semua hal teknis ada di sini, jauh dari jalur impor normal.
  List<Widget> _advancedControls(CsvTable table) => [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GroupLabel(
                icon: Icons.tune,
                label: 'Cara membaca berkas',
              ),
              const SizedBox(height: AppTheme.spaceSm),
              if (_format == PickedFileFormat.spreadsheet)
                ..._sheetControls(),
              if (_format == PickedFileFormat.csv)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _firstRowIsHeader,
                  title: const Text('Baris pertama adalah judul kolom'),
                  subtitle: const Text('Matikan kalau file langsung berisi data.'),
                  onChanged: (value) => setState(() {
                    _firstRowIsHeader = value;
                    _readTable();
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _detectedSection(table),
              const Divider(height: AppTheme.spaceLg),
              _preview(table),
            ],
          ),
        ),
      ];

  /// Lembar, baris judul, dan di mana tabel berakhir.
  List<Widget> _sheetControls() {
    final sheet = _sheets[_sheetIndex];
    return [
      if (_sheets.length > 1)
        _dropdown<int>(
          label: 'Lembar',
          value: _sheetIndex,
          items: [
            for (var i = 0; i < _sheets.length; i++)
              DropdownMenuItem<int>(value: i, child: Text(_sheets[i].name)),
          ],
          onChanged: (value) => setState(() {
            _sheetIndex = value ?? 0;
            _headerRow = suggestHeaderRow(_sheets[_sheetIndex].grid);
            _readTable();
          }),
        ),
      _dropdown<int?>(
        label: 'Baris judul kolom',
        value: _headerRow,
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('Tanpa judul')),
          for (var i = 0; i < sheet.grid.length && i < _headerOptions; i++)
            DropdownMenuItem<int?>(
              value: i,
              child: Text(
                'Baris ${i + 1} - ${_rowHint(sheet.grid[i])}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) => setState(() {
          _headerRow = value;
          _readTable();
        }),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _stopAtBlankRows,
        title: const Text('Berhenti di baris kosong'),
        subtitle: const Text(
          'Baris setelah baris kosong diabaikan, misalnya baris tanda tangan '
          'di bawah tabel.',
        ),
        onChanged: (value) => setState(() {
          _stopAtBlankRows = value;
          _readTable();
        }),
      ),
      Text(
        _headerRow == null
            ? 'Kolom diberi nama Kolom 1, Kolom 2, dan seterusnya.'
            : 'Judul kolom dibaca dari baris ${_headerRow! + 1}.',
        style: AppText.bodySm.copyWith(color: AppTheme.muted),
      ),
      const SizedBox(height: AppTheme.spaceSm),
    ];
  }

  String _rowHint(List<String> row) {
    final filled = [
      for (final cell in row)
        if (cell.trim().isNotEmpty) cell.trim(),
    ];
    return filled.isEmpty ? 'kosong' : filled.join(' | ');
  }

  Widget _errorPanel(String message) {
    return Panel(
      fill: AppTheme.errorContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.onErrorContainer),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(
              message,
              style: AppText.bodySm.copyWith(
                color: AppTheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filePanel(CsvTable? table) {
    return Panel(
      padding: const EdgeInsets.all(AppTheme.space12),
      child: Row(
        children: [
          Container(
            width: AppTheme.touch,
            height: AppTheme.touch,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.chip,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(
              _format == PickedFileFormat.spreadsheet
                  ? Icons.grid_on
                  : Icons.description_outlined,
              size: 20,
              color: AppTheme.link,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _file?.fileName ?? 'Berkas',
                  style: AppText.style(
                    size: 13.5,
                    weight: 600,
                    color: AppTheme.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.space2),
                Text(
                  table == null
                      ? 'Belum ada baris data yang bisa dibaca dengan '
                          'pengaturan ini.'
                      : '${table.rows.length} baris data, '
                          '${table.columnCount} kolom',
                  style: AppText.bodySm.copyWith(color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.space12),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, isDense: true),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              onChanged: onChanged,
              items: items,
            ),
          ),
        ),
      );

  /// Menampilkan kolom berkas mana yang dikenali, supaya admin bisa memastikan
  /// baris judulnya sudah benar.
  Widget _detectedSection(CsvTable table) {
    final plan = _plan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kolom terdeteksi',
          style: AppText.style(size: 13.5, weight: 600, color: AppTheme.ink),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        if (plan == null)
          Text(
            'Kolom "NAMA ALAT UKUR" belum terbaca. Periksa baris judul di atas.',
            style: AppText.bodySm.copyWith(color: AppTheme.muted),
          )
        else ...[
          for (final column in plan.detected)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space2),
              child: Text(
                '${column.label}  <-  ${column.header}',
                style: AppText.bodySm.copyWith(color: AppTheme.ink2),
              ),
            ),
          if (!plan.detected.any((column) => column.label == 'Stok total'))
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spaceXs),
              child: Text(
                'File tidak punya kolom stok, jadi stok diambil dari "Stok tiap '
                'barang" di atas.',
                style: AppText.bodySm.copyWith(color: AppTheme.muted),
              ),
            ),
        ],
      ],
    );
  }

  Widget _stockPerRowField({bool showError = false}) => TextField(
        controller: _stockPerRow,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Stok tiap barang',
          helperText:
              'File tidak punya kolom stok. Isi 1 kalau tiap barang satu unit.',
          errorText: showError && _stockPerRowValue == null
              ? 'Isi jumlah stok, misalnya 1.'
              : null,
        ),
        onChanged: (_) => setState(() => _replan()),
      );

  Widget _preview(CsvTable table) {
    final head = table.rows.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contoh isi file',
          style: AppText.style(size: 13.5, weight: 600, color: AppTheme.ink),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        for (var i = 0; i < head.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceXs),
            child: Text(
              '${i + 1}. ${head[i].join(' | ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySm.copyWith(color: AppTheme.muted),
            ),
          ),
        if (table.rows.length > head.length)
          Text(
            '... dan ${table.rows.length - head.length} baris lain.',
            style: AppText.bodySm.copyWith(color: AppTheme.muted),
          ),
      ],
    );
  }

  Widget _reportView(ImportReport report) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceMd,
        AppTheme.spaceSm,
        AppTheme.spaceMd,
        AppTheme.spaceLg,
      ),
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Hasil impor',
                style: AppText.headlineSm.copyWith(color: AppTheme.ink),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${report.added}',
                    style: AppText.headlineLg.copyWith(color: AppTheme.ink),
                  ),
                  const SizedBox(width: AppTheme.space6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space6),
                    child: Text(
                      'barang ditambahkan',
                      style: AppText.style(
                        size: 14,
                        weight: 600,
                        color: AppTheme.ink2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceMd),
              const Divider(),
              _statRow('Dilewati karena kode sudah ada', report.skipped.length),
              _statRow('Gagal karena data tidak valid', report.issues.length),
            ],
          ),
        ),
        if (report.skipped.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spaceMd),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Dilewati'),
                for (final name in report.skipped.take(20))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space2),
                    child: Text(
                      '- $name',
                      style: AppText.bodySm.copyWith(color: AppTheme.ink2),
                    ),
                  ),
                if (report.skipped.length > 20)
                  Text(
                    '... dan ${report.skipped.length - 20} nama lain.',
                    style: AppText.bodySm.copyWith(color: AppTheme.muted),
                  ),
              ],
            ),
          ),
        ],
        if (report.issues.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spaceMd),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Gagal'),
                for (final issue in report.issues.take(20))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space2),
                    child: Text(
                      'Baris ${issue.rowNumber}: ${issue.message}',
                      style: AppText.bodySm.copyWith(color: AppTheme.ink2),
                    ),
                  ),
                if (report.issues.length > 20)
                  Text(
                    '... dan ${report.issues.length - 20} masalah lain.',
                    style: AppText.bodySm.copyWith(color: AppTheme.muted),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppTheme.spaceLg),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Selesai'),
        ),
      ],
    );
  }

  Widget _statRow(String label, int value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppText.bodySm.copyWith(color: AppTheme.muted),
              ),
            ),
            Text(
              '$value',
              style: AppText.style(size: 13, weight: 600, color: AppTheme.ink),
            ),
          ],
        ),
      );
}
