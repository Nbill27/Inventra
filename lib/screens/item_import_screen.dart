import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/exceptions.dart';
import '../models/item_import.dart';
import '../providers/item_provider.dart';
import '../services/csv_parser.dart';
import '../services/item_importer.dart';

/// One CSV file already read into memory, so nothing below this line has to
/// touch the platform file dialog.
class PickedCsv {
  const PickedCsv({required this.fileName, required this.content});

  final String fileName;
  final String content;
}

/// Injectable so the screen can be driven in a test without the system picker.
typedef CsvFilePicker = Future<PickedCsv?> Function();

/// The real picker: Android opens its document picker, which already grants
/// read access to the one file that was chosen, so no storage permission is
/// requested.
Future<PickedCsv?> pickCsvFromDevice() async {
  final file = await FilePicker.pickFile(
    dialogTitle: 'Pilih file CSV',
    type: FileType.custom,
    allowedExtensions: ['csv', 'txt'],
  );
  if (file == null) {
    return null;
  }
  final bytes = await file.readAsBytes();
  return PickedCsv(fileName: file.name, content: _decodeBytes(bytes));
}

/// Excel writes CSV in the machine code page rather than UTF-8, so text that is
/// not valid UTF-8 is read as latin1 instead of rejecting the whole file.
String _decodeBytes(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

/// Imports the mentor's item file. Column names are never guessed: the admin
/// maps each required field to a column, sees what will happen, and only then
/// presses import.
class ItemImportScreen extends StatefulWidget {
  const ItemImportScreen({super.key, this.picker});

  /// Defaults to the device file dialog.
  final CsvFilePicker? picker;

  @override
  State<ItemImportScreen> createState() => _ItemImportScreenState();
}

class _ItemImportScreenState extends State<ItemImportScreen> {
  static const _importer = ItemImporter();

  final _mapping = <ItemField, int?>{};

  PickedCsv? _file;
  CsvTable? _table;
  bool _firstRowIsHeader = true;
  bool _busy = false;
  String? _error;
  ImportReport? _report;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final picked = await (widget.picker ?? pickCsvFromDevice)();
      if (!mounted) {
        return;
      }
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _busy = false;
        _file = picked;
        _readFile();
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _table = null;
        _error = error.message;
      });
    } catch (error, stackTrace) {
      debugPrint('Gagal membaca berkas CSV: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _table = null;
        _error = 'Gagal membaca berkas CSV.';
      });
    }
  }

  /// Re-reads the current file. Called again when the header switch is flipped,
  /// because that changes how every row is understood.
  void _readFile() {
    final content = _file?.content;
    if (content == null) {
      return;
    }
    _mapping.clear();
    _report = null;
    try {
      _table = parseCsv(content, firstRowIsHeader: _firstRowIsHeader);
      _error = null;
    } on AppException catch (error) {
      _table = null;
      _error = error.message;
    }
  }

  /// Null while the required columns are still unmapped, which keeps the
  /// summary and the import button hidden until the file can actually be read.
  ImportPlan? _planFor(CsvTable table) {
    try {
      return _importer.plan(table: table, mapping: _mapping);
    } on AppException {
      return null;
    }
  }

  void _onMappingChanged(ItemField field, int? column) {
    if (column != null) {
      final clash = _mapping.entries.where(
        (entry) => entry.key != field && entry.value == column,
      );
      if (clash.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kolom itu sudah dipakai untuk ${clash.first.key.label}.',
            ),
          ),
        );
        return;
      }
    }
    setState(() => _mapping[field] = column);
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
      appBar: AppBar(title: const Text('Impor Barang dari CSV')),
      body: report == null ? _setupView() : _reportView(report),
    );
  }

  Widget _setupView() {
    final table = _table;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Barang dengan kode yang sudah ada akan dilewati, jadi file yang sama '
          'boleh diimpor dua kali. Nama kolom di file kamu tidak harus seragam, '
          'karena kolomnya dipetakan manual di bawah.',
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[_errorCard(_error!), const SizedBox(height: 16)],
        FilledButton.icon(
          onPressed: _busy ? null : _pick,
          icon: const Icon(Icons.folder_open),
          label: Text(table == null ? 'Pilih file CSV' : 'Ganti file CSV'),
        ),
        if (table != null) ...[
          const SizedBox(height: 24),
          _fileCard(table),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _firstRowIsHeader,
            title: const Text('Baris pertama adalah judul kolom'),
            subtitle: const Text('Matikan kalau file langsung berisi data.'),
            onChanged: (value) => setState(() {
              _firstRowIsHeader = value;
              _readFile();
            }),
          ),
          const Divider(),
          const SizedBox(height: 8),
          Text('Pemetaan kolom', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Tanda bintang wajib dipilih.'),
          const SizedBox(height: 12),
          for (final field in ItemField.values) _mappingField(field, table),
          const SizedBox(height: 8),
          _preview(table),
          const Divider(),
          const SizedBox(height: 8),
          _planSection(table),
        ],
      ],
    );
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

  Widget _fileCard(CsvTable table) => Card(
        child: ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(_file?.fileName ?? 'Berkas CSV'),
          subtitle: Text(
            '${table.rows.length} baris data, ${table.columnCount} kolom',
          ),
        ),
      );

  Widget _mappingField(ItemField field, CsvTable table) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: field.isRequired ? '${field.label} *' : field.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _mapping[field],
              isExpanded: true,
              isDense: true,
              onChanged: (value) => _onMappingChanged(field, value),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Tidak dipakai'),
                ),
                for (var i = 0; i < table.columnCount; i++)
                  DropdownMenuItem<int?>(value: i, child: Text(table.header[i])),
              ],
            ),
          ),
        ),
      );

  Widget _preview(CsvTable table) {
    final sample = table.rows.take(3).toList();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pratinjau', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (var i = 0; i < sample.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${i + 1}. ${sample[i].join(' | ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (table.rows.length > sample.length)
          Text(
            '... dan ${table.rows.length - sample.length} baris lain.',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _planSection(CsvTable table) {
    final plan = _planFor(table);
    if (plan == null) {
      return const Text('Pilih kolom Nama barang dan Stok total untuk melihat ringkasan.');
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ringkasan sebelum impor', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Siap ditambahkan: ${plan.drafts.length} baris'),
        Text('Perlu diperbaiki: ${plan.issues.length} baris'),
        const SizedBox(height: 4),
        const Text('Baris yang perlu diperbaiki dilewati, sisanya tetap masuk.'),
        if (plan.issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final issue in plan.issues.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('Baris ${issue.rowNumber}: ${issue.message}'),
            ),
          if (plan.issues.length > 10)
            Text('... dan ${plan.issues.length - 10} masalah lain.'),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy || !plan.canImport ? null : () => _import(plan),
          icon: const Icon(Icons.download_done),
          label: Text(
            _busy ? 'Mengimpor...' : 'Impor ${plan.drafts.length} barang',
          ),
        ),
      ],
    );
  }

  Widget _reportView(ImportReport report) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
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
