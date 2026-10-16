import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/exceptions.dart';
import '../models/item_import.dart';
import '../providers/item_provider.dart';
import '../services/csv_parser.dart';
import '../services/item_importer.dart';
import '../services/sheet_reader.dart';
import '../services/sheet_table.dart';

/// One file already read into memory, so nothing below this line has to touch
/// the platform file dialog.
class PickedFile {
  const PickedFile({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

/// Injectable so the screen can be driven in a test without the system picker.
typedef ImportFilePicker = Future<PickedFile?> Function();

/// Which reader a picked file goes through. Not every other office format is
/// readable, so the bytes decide this rather than the file name.
enum PickedFileFormat { csv, spreadsheet }

/// The real picker: Android opens its document picker, which already grants
/// read access to the one file that was chosen, so no storage permission is
/// requested.
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

/// Excel writes CSV in the machine code page rather than UTF-8, so text that is
/// not valid UTF-8 is read as latin1 instead of rejecting the whole file.
String decodeText(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return latin1.decode(bytes);
  }
}

/// Imports the master "Daftar Alat Ukur" file, CSV or Excel.
///
/// The screen is deliberately short: pick a file, and the columns are read
/// automatically. Everything technical (sheet, header row, preview) hides under
/// "Pengaturan lanjutan" so a normal import is just two taps.
class ItemImportScreen extends StatefulWidget {
  const ItemImportScreen({super.key, this.picker});

  /// Defaults to the device file dialog.
  final ImportFilePicker? picker;

  @override
  State<ItemImportScreen> createState() => _ItemImportScreenState();
}

class _ItemImportScreenState extends State<ItemImportScreen> {
  static const _importer = ItemImporter();

  /// How many header rows the dropdown offers, so a stray wide sheet cannot
  /// produce a menu with hundreds of entries.
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

  /// Rebuilds the table. Columns are recognised from the header again, so a
  /// different sheet, header row, or file is picked up automatically.
  void _readTable() {
    _report = null;
    try {
      _table = _format == PickedFileFormat.spreadsheet ? _readSheet() : _readCsv();
      _error = null;
    } on AppException catch (error) {
      _table = null;
      _error = error.message;
    }
    // When nothing can be read yet, open the settings so the header row can be
    // corrected without hunting for the toggle.
    if (_table == null || _planFor(_table!) == null) {
      _showAdvanced = true;
    }
  }

  CsvTable _readSheet() => tableFromGrid(
        _sheets[_sheetIndex].grid,
        headerRow: _headerRow,
        stopAtBlank: _stopAtBlankRows,
      );

  CsvTable _readCsv() =>
      parseCsv(decodeText(_file!.bytes), firstRowIsHeader: _firstRowIsHeader);

  /// Null while the file still cannot be read as items, which keeps the summary
  /// and the import button hidden until there is something to import.
  ImportPlan? _planFor(CsvTable table) {
    try {
      return _importer.plan(table: table, stockPerRow: _stockPerRowValue);
    } on AppException {
      return null;
    }
  }

  /// A negative count is not a stock, so it reads as "not filled in".
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
      setState(() {
        _busy = false;
        _report = report;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('${report.added} barang ditambahkan.')),
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
      appBar: AppBar(title: const Text('Impor Barang')),
      body: report == null ? _setupView() : _reportView(report),
    );
  }

  Widget _setupView() {
    final table = _table;
    return ListView(
      padding: const EdgeInsets.all(AppTheme.gap),
      children: [
        const Text(
          'Pilih file Excel (.xlsx) atau CSV. Kolom dibaca otomatis, jadi tidak '
          'perlu atur apa-apa.',
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          _errorCard(_error!),
          const SizedBox(height: 16),
        ],
        FilledButton.icon(
          onPressed: _busy ? null : _pick,
          icon: const Icon(Icons.folder_open),
          label: Text(_file == null ? 'Pilih file' : 'Ganti file'),
        ),
        if (_busy) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_file != null && !_busy) ...[
          const SizedBox(height: 16),
          _fileCard(table),
          if (table != null) ...[
            const SizedBox(height: 12),
            _summaryCard(table),
            const SizedBox(height: 12),
            _advancedToggle(),
            if (_showAdvanced) ...[
              const SizedBox(height: 8),
              ..._advancedControls(table),
            ],
          ],
        ],
      ],
    );
  }

  /// The one card that matters: how many items are ready, and the import button.
  Widget _summaryCard(CsvTable table) {
    final theme = Theme.of(context);
    final plan = _planFor(table);
    final hasStockColumn =
        plan?.detected.any((column) => column.label == 'Stok total') ?? false;

    if (plan == null) {
      return Card(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Belum bisa diimpor. Pastikan baris judul berisi kolom '
                  '"NAMA ALAT UKUR", dan isi "Stok tiap barang" kalau file tidak '
                  'punya kolom stok.',
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${plan.drafts.length} barang siap diimpor',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (plan.issues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${plan.issues.length} baris dilewati:'),
              for (final issue in plan.issues.take(5))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Baris ${issue.rowNumber}: ${issue.message}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (plan.issues.length > 5)
                Text(
                  '... dan ${plan.issues.length - 5} baris lagi.',
                  style: theme.textTheme.bodySmall,
                ),
            ],
            if (!hasStockColumn) ...[
              const SizedBox(height: 12),
              _stockPerRowField(),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy || !plan.canImport ? null : () => _import(plan),
                icon: const Icon(Icons.download_done),
                label: Text(
                  _busy ? 'Mengimpor...' : 'Impor ${plan.drafts.length} barang',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _advancedToggle() => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
          icon: Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
          label: Text(
            _showAdvanced ? 'Sembunyikan pengaturan' : 'Pengaturan lanjutan',
          ),
        ),
      );

  /// Everything technical lives here, out of the way of a normal import.
  List<Widget> _advancedControls(CsvTable table) => [
        if (_format == PickedFileFormat.spreadsheet) ..._sheetControls(),
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
        const SizedBox(height: 8),
        _detectedSection(table),
        const SizedBox(height: 8),
        _preview(table),
      ];

  /// Sheet, header row, and where the table ends.
  List<Widget> _sheetControls() {
    final sheet = _sheets[_sheetIndex];
    final theme = Theme.of(context);
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
                'Baris ${i + 1} — ${_rowHint(sheet.grid[i])}',
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
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
    ];
  }

  String _rowHint(List<String> row) {
    final filled = [
      for (final cell in row)
        if (cell.trim().isNotEmpty) cell.trim(),
    ];
    return filled.isEmpty ? 'kosong' : filled.join(' | ');
  }

  Widget _errorCard(String message) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileCard(CsvTable? table) => Card(
        child: ListTile(
          leading: Icon(
            _format == PickedFileFormat.spreadsheet
                ? Icons.table_chart_outlined
                : Icons.description_outlined,
          ),
          title: Text(_file?.fileName ?? 'Berkas'),
          subtitle: Text(
            table == null
                ? 'Belum ada baris data yang bisa dibaca dengan pengaturan ini.'
                : '${table.rows.length} baris data, ${table.columnCount} kolom',
          ),
        ),
      );

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
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

  /// Shows which file columns were recognised, so the admin can confirm the
  /// header row is right.
  Widget _detectedSection(CsvTable table) {
    final theme = Theme.of(context);
    final plan = _planFor(table);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kolom terdeteksi', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        if (plan == null)
          Text(
            'Kolom "NAMA ALAT UKUR" belum terbaca. Periksa baris judul di atas.',
            style: theme.textTheme.bodyMedium,
          )
        else ...[
          for (final column in plan.detected)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${column.label}  ←  ${column.header}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (!plan.detected.any((column) => column.label == 'Stok total'))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'File tidak punya kolom stok, jadi stok diambil dari "Stok tiap '
                'barang" di atas.',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }

  Widget _stockPerRowField() => TextField(
        controller: _stockPerRow,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Stok tiap barang',
          helperText:
              'File tidak punya kolom stok. Isi 1 kalau tiap barang satu unit.',
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      );

  Widget _preview(CsvTable table) {
    final theme = Theme.of(context);
    final head = table.rows.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contoh isi file', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        for (var i = 0; i < head.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${i + 1}. ${head[i].join(' | ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (table.rows.length > head.length)
          Text(
            '... dan ${table.rows.length - head.length} baris lain.',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _reportView(ImportReport report) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppTheme.gap),
      children: [
        Text('Hasil impor', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        _stat('Ditambahkan', report.added),
        _stat('Dilewati karena kode sudah ada', report.skipped.length),
        _stat('Gagal karena data tidak valid', report.issues.length),
        if (report.skipped.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Dilewati', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final name in report.skipped.take(20)) Text('- $name'),
          if (report.skipped.length > 20)
            Text('... dan ${report.skipped.length - 20} nama lain.'),
        ],
        if (report.issues.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Gagal', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final issue in report.issues.take(20))
            Text('Baris ${issue.rowNumber}: ${issue.message}'),
          if (report.issues.length > 20)
            Text('... dan ${report.issues.length - 20} masalah lain.'),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Selesai'),
        ),
      ],
    );
  }

  Widget _stat(String label, int value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text('$label: $value'),
      );
}
