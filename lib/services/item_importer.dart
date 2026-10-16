import '../core/exceptions.dart';
import '../core/validation.dart';
import '../models/item_import.dart';
import 'csv_parser.dart';

/// What the file will do, worked out before anything is written: which rows are
/// ready, and which ones the admin still has to fix.
class ImportPlan {
  const ImportPlan({required this.drafts, required this.issues});

  final List<ItemDraft> drafts;
  final List<ImportIssue> issues;

  bool get canImport => drafts.isNotEmpty;
}

/// Turns a parsed table plus a column mapping into validated drafts.
///
/// Column names are never guessed: the mentor's file may name its columns
/// anything, so the mapping is supplied by the admin and only its result is
/// trusted here.
class ItemImporter {
  const ItemImporter();

  ImportPlan plan({
    required CsvTable table,
    required Map<ItemField, int?> mapping,
  }) {
    final nameColumn = mapping[ItemField.name];
    final stockColumn = mapping[ItemField.stockTotal];
    if (nameColumn == null) {
      throw const ValidationException('Kolom Nama barang belum dipilih.');
    }
    if (stockColumn == null) {
      throw const ValidationException('Kolom Stok total belum dipilih.');
    }

    final codeColumn = mapping[ItemField.code];
    final categoryColumn = mapping[ItemField.category];
    final noteColumn = mapping[ItemField.note];

    final drafts = <ItemDraft>[];
    final issues = <ImportIssue>[];

    for (var i = 0; i < table.rows.length; i++) {
      final row = table.rows[i];
      final rowNumber = i + 1;
      try {
        final name = requireText(_cell(row, nameColumn), field: 'Nama barang');
        final stockTotal = _parseStock(_cell(row, stockColumn));
        if (stockTotal == null) {
          throw const ValidationException(
            'Stok total harus bilangan bulat 0 atau lebih.',
          );
        }
        drafts.add(
          ItemDraft(
            rowNumber: rowNumber,
            name: name,
            code: optionalText(_cell(row, codeColumn)),
            category: optionalText(_cell(row, categoryColumn)),
            stockTotal: stockTotal,
            note: optionalText(_cell(row, noteColumn)),
          ),
        );
      } on ValidationException catch (error) {
        issues.add(ImportIssue(rowNumber: rowNumber, message: error.message));
      }
    }

    return ImportPlan(drafts: drafts, issues: issues);
  }

  /// A short row is normal when trailing optional columns are empty, so a
  /// missing cell reads as blank instead of throwing.
  String _cell(List<String> row, int? column) {
    if (column == null || column >= row.length) {
      return '';
    }
    return row[column].trim();
  }

  /// Stock is a whole unit count, so `1.000` and `1,000` are read as one
  /// thousand rather than as decimals.
  int? _parseStock(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s.,]'), '');
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return null;
    }
    return int.tryParse(cleaned);
  }
}
