import 'item.dart';
import 'loan.dart';

/// A loan together with the item it points at, for the list and detail screens.
class LoanDetail {
  const LoanDetail({required this.loan, required this.item});

  final Loan loan;
  final Item item;

  /// Cocok dengan nama peminjam, nama barang, atau kode barang.
  ///
  /// Pencarian dilakukan di memori supaya tiap layar bisa menyaring daftarnya
  /// sendiri tanpa mengubah data bersama di provider.
  bool matchesQuery(String query) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) {
      return true;
    }
    return loan.borrowerName.toLowerCase().contains(keyword) ||
        item.name.toLowerCase().contains(keyword) ||
        (item.code ?? '').toLowerCase().contains(keyword);
  }
}
