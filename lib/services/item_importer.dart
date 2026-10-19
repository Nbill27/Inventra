import '../core/exceptions.dart';
import '../core/validation.dart';
import '../models/item_import.dart';
import 'csv_parser.dart';

/// A column of the imported file that was recognised from its header, so the
/// screen can show the admin which columns the import will read.
class DetectedColumn {
  const DetectedColumn({required this.label, required this.header});

  /// Field name in Indonesian, e.g. "Nama alat ukur".
  final String label;

  /// The header cell as it appears in the file, e.g. "NAMA ALAT UKUR".
  final String header;
}

/// What the file will do, worked out before anything is written: which rows are
/// ready, and which ones the admin still has to fix.
class ImportPlan {
  const ImportPlan({
    required this.drafts,
    required this.issues,
    this.detected = const [],
  });

  final List<ItemDraft> drafts;
  final List<ImportIssue> issues;

  /// Columns recognised from the header, for the "kolom terdeteksi" summary.
  final List<DetectedColumn> detected;

  bool get canImport => drafts.isNotEmpty;
}

/// Turns a parsed table into validated drafts.
///
/// Columns are recognised from the header names, which follow the master
/// "Daftar Alat Ukur" file. Only the item name is required; the stock comes from
/// a stock column, or, when the file has no stock column at all, from [plan]'s
/// `stockPerRow`.
class ItemImporter {
  const ItemImporter();

  /// Accepted header spellings per field, lower-cased. The first spelling that
  /// matches a header wins, and a header is only claimed by one field.
  static const Map<String, List<String>> _aliases = {
    'name': ['nama alat ukur', 'nama barang', 'nama alat', 'nama'],
    'code': ['kode alat ukur', 'kode barang', 'kode'],
    'no': ['no', 'no urut', 'nomor'],
    'range': ['range', 'kapasitas'],
    'brand': ['brand', 'merk', 'merek'],
    'pic': ['pic', 'penanggung jawab'],
    'status': ['status', 'kondisi'],
    'stock': ['stok', 'stock', 'jumlah', 'qty', 'kuantitas'],
  };

  /// Headers that are recognised but deliberately not stored.
  static const Set<String> _ignored = {'foto', 'photo', 'gambar'};

  /// Human labels, in the order they are shown.
  static const Map<String, String> _labels = {
    'name': 'Nama alat ukur',
    'code': 'Kode alat ukur',
    'no': 'No',
    'range': 'Range',
    'brand': 'Brand',
    'pic': 'PIC',
    'status': 'Status',
    'stock': 'Stok total',
  };

  /// Kolom yang dikenali dari baris judul, tanpa menghitung rencana impor.
  /// Dipakai layar untuk memutuskan isian mana yang masih perlu ditampilkan.
  List<DetectedColumn> detectColumns(CsvTable table) =>
      _detected(table.header, _columns(table.header));

  /// [nameColumn] and [stockColumn] are manual overrides for a file whose
  /// header cannot be read, such as a table without a title row.
  ImportPlan plan({
    required CsvTable table,
    int? stockPerRow,
    int? nameColumn,
    int? stockColumn,
  }) {
    final columns = _columns(table.header);
    final resolvedName = nameColumn ?? columns['name'];
    if (resolvedName == null) {
      throw const ValidationException(
        'Kolom "NAMA ALAT UKUR" tidak ditemukan di baris judul. '
        'Pilih kolom nama barang secara manual.',
      );
    }

    final resolvedStock = stockColumn ?? columns['stock'];
    if (resolvedStock == null && stockPerRow == null) {
      throw const ValidationException(
        'File tidak punya kolom stok. Isi "Stok tiap baris" dulu.',
      );
    }

    final drafts = <ItemDraft>[];
    final issues = <ImportIssue>[];
    // A manually mapped column has to count when deciding whether a row is
    // blank, otherwise every row of a headerless table would be skipped.
    final mapped = {
      ...columns,
      'name': resolvedName,
      'stock': ?resolvedStock,
    };

    for (var i = 0; i < table.rows.length; i++) {
      final row = table.rows[i];
      final rowNumber = table.rowNumberAt(i);
      if (_isBlank(row, mapped)) {
        continue;
      }
      try {
        final name = requireText(_cell(row, resolvedName), field: 'Nama alat ukur');
        final stockTotal = resolvedStock == null
            ? stockPerRow
            : _parseStock(_cell(row, resolvedStock));
        if (stockTotal == null) {
          throw const ValidationException(
            'Stok total harus bilangan bulat 0 atau lebih.',
          );
        }
        drafts.add(
          ItemDraft(
            rowNumber: rowNumber,
            name: name,
            noUrut: optionalText(_cell(row, columns['no'])),
            code: optionalText(_cell(row, columns['code'])),
            range: optionalText(_cell(row, columns['range'])),
            brand: optionalText(_cell(row, columns['brand'])),
            pic: optionalText(_cell(row, columns['pic'])),
            status: optionalText(_cell(row, columns['status'])),
            stockTotal: stockTotal,
          ),
        );
      } on ValidationException catch (error) {
        issues.add(ImportIssue(rowNumber: rowNumber, message: error.message));
      }
    }

    return ImportPlan(
      drafts: drafts,
      issues: issues,
      detected: _detected(
        table.header,
        {
          ...columns,
          'name': ?nameColumn,
          'stock': ?stockColumn,
        },
      ),
    );
  }

  /// Field -> column index, from the header row.
  static Map<String, int> _columns(List<String> header) {
    final columns = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      final cell = _norm(header[i]);
      if (cell.isEmpty || _ignored.contains(cell)) {
        continue;
      }
      for (final entry in _aliases.entries) {
        if (columns.containsKey(entry.key)) {
          continue;
        }
        if (entry.value.contains(cell)) {
          columns[entry.key] = i;
          break;
        }
      }
    }
    return columns;
  }

  static List<DetectedColumn> _detected(
    List<String> header,
    Map<String, int> columns,
  ) =>
      [
        for (final entry in _labels.entries)
          if (columns.containsKey(entry.key) &&
              columns[entry.key]! < header.length)
            DetectedColumn(
              label: entry.value,
              header: header[columns[entry.key]!].trim(),
            ),
      ];

  /// A row whose recognised cells all read blank carries nothing to import, so
  /// it is skipped instead of reported as a broken row. This keeps the signature
  /// lines under a spreadsheet's table out of the import.
  bool _isBlank(List<String> row, Map<String, int> columns) {
    for (final column in columns.values) {
      if (_cell(row, column).isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  /// A short row is normal when trailing optional columns are empty, so a
  /// missing cell reads as blank instead of throwing. Runs of whitespace are
  /// collapsed so a name split across two lines reads as one line.
  static String _cell(List<String> row, int? column) {
    if (column == null || column >= row.length) {
      return '';
    }
    return row[column].trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _norm(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Stock is a whole unit count. Plain digits are taken as they are; a
  /// thousand separator is accepted only in a consistent, valid grouping
  /// (`1.000`, `1,000`, `1.000.000`). A decimal such as `1.5` is refused
  /// instead of being flattened into `15`, because that would silently change
  /// the amount the file asked for.
  int? _parseStock(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return null;
    }
    if (RegExp(r'^\d+$').hasMatch(text)) {
      return int.tryParse(text);
    }

    // Groups must be three digits, and the same separator has to be used
    // throughout: `1.000,5` and `1,000.00` are mixed, so they fall through.
    if (!RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(text)) {
      return null;
    }
    final separators = text.replaceAll(RegExp(r'\d'), '').split('').toSet();
    if (separators.length != 1) {
      return null;
    }
    return int.tryParse(text.replaceAll(RegExp(r'[.,]'), ''));
  }
}
