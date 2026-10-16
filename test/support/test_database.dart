import 'package:peminjaman_barang/db/database_helper.dart';
import 'package:peminjaman_barang/models/item.dart';
import 'package:peminjaman_barang/models/loan.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fresh in-memory database per test. The FFI factory lets the suite run on the
/// host without a device.
DatabaseHelper createTestDatabase() {
  sqfliteFfiInit();
  return DatabaseHelper(factory: databaseFactoryFfi, path: ':memory:');
}

Item itemFixture({
  String name = 'Proyektor',
  String? noUrut,
  String? code,
  String? range,
  String? brand,
  String? pic,
  String? status,
  int stockTotal = 5,
}) =>
    Item(
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

Loan loanFixture({
  required int itemId,
  String borrowerName = 'Budi',
  String? contact,
  int quantity = 2,
  DateTime? loanDate,
  DateTime? dueDate,
  String? note,
}) =>
    Loan(
      itemId: itemId,
      borrowerName: borrowerName,
      contact: contact,
      quantity: quantity,
      loanDate: loanDate ?? DateTime(2026, 10, 1),
      dueDate: dueDate ?? DateTime(2026, 10, 8),
      note: note,
    );
