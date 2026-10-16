import '../models/item.dart';

/// Fields a CSV column can be mapped to. Only [name] and [stockTotal] are
/// required, the rest may stay unmapped.
enum ItemField {
  name('Nama barang'),
  code('Kode'),
  category('Kategori'),
  stockTotal('Stok total'),
  note('Catatan');

  const ItemField(this.label);

  final String label;

  bool get isRequired => this == ItemField.name || this == ItemField.stockTotal;
}

/// One data row that passed validation and is ready to be written.
class ItemDraft {
  const ItemDraft({
    required this.rowNumber,
    required this.name,
    this.code,
    this.category,
    required this.stockTotal,
    this.note,
  });

  /// Position among the data rows, 1-based and counted after the header row, so
  /// a rejected row can be pointed at in the imported file.
  final int rowNumber;

  final String name;
  final String? code;
  final String? category;
  final int stockTotal;
  final String? note;

  /// A brand new item is fully available, so availability mirrors the total.
  Item toItem() => Item(
        name: name,
        code: code,
        category: category,
        stockTotal: stockTotal,
        stockAvailable: stockTotal,
        note: note,
      );
}

/// A data row that was rejected, with the reason shown to the admin.
class ImportIssue {
  const ImportIssue({required this.rowNumber, required this.message});

  final int rowNumber;
  final String message;
}

class ImportReport {
  const ImportReport({
    required this.added,
    required this.skipped,
    required this.issues,
  });

  /// Rows actually inserted.
  final int added;

  /// Names of rows left alone because their code already exists.
  final List<String> skipped;

  final List<ImportIssue> issues;

  int get total => added + skipped.length + issues.length;
}
