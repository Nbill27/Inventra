import '../models/item.dart';

/// One data row that passed validation and is ready to be written.
///
/// The fields mirror the master "Daftar Alat Ukur" file, so the importer maps
/// its columns straight across without asking the admin to match them by hand.
class ItemDraft {
  const ItemDraft({
    required this.rowNumber,
    required this.name,
    this.noUrut,
    this.code,
    this.range,
    this.brand,
    this.pic,
    this.status,
    required this.stockTotal,
  });

  /// Position among the data rows, 1-based and counted after the header row, so
  /// a rejected row can be pointed at in the imported file.
  final int rowNumber;

  final String? noUrut;
  final String name;
  final String? code;
  final String? range;
  final String? brand;
  final String? pic;
  final String? status;
  final int stockTotal;

  /// A brand new item is fully available, so availability mirrors the total.
  Item toItem() => Item(
        noUrut: noUrut,
        name: name,
        code: code,
        range: range,
        brand: brand,
        pic: pic,
        status: status,
        stockTotal: stockTotal,
        stockAvailable: stockTotal,
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
