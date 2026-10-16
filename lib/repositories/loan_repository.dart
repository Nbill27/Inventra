import 'package:sqflite/sqflite.dart';

import '../core/dates.dart';
import '../core/exceptions.dart';
import '../core/validation.dart';
import '../db/database_helper.dart';
import '../models/item.dart';
import '../models/loan.dart';
import '../models/loan_detail.dart';

class LoanRepository {
  LoanRepository({DatabaseHelper? helper})
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  static const _table = 'loans';
  static const _itemTable = 'items';

  /// FR-L5: newest first. Items are fetched in one extra query instead of per row.
  ///
  /// [statuses] narrows the list; an empty set (or null) means every status.
  Future<List<LoanDetail>> getAllDetailed({Set<LoanStatus>? statuses}) async {
    final db = await _helper.database;
    final wanted = statuses == null || statuses.isEmpty ? null : statuses.toList();
    final rows = await db.query(
      _table,
      where: wanted == null
          ? null
          : 'status IN (${List.filled(wanted.length, '?').join(', ')})',
      whereArgs: wanted?.map((status) => status.dbValue).toList(),
      orderBy: 'loan_date DESC, id DESC',
    );
    final loans = rows.map(Loan.fromMap).toList();
    if (loans.isEmpty) {
      return const [];
    }

    final itemRows = await db.query(
      _itemTable,
      where: 'id IN (${List.filled(loans.map((l) => l.itemId).toSet().length, '?').join(',')})',
      whereArgs: loans.map((l) => l.itemId).toSet().toList(),
    );
    final items = {for (final row in itemRows) row['id'] as int: Item.fromMap(row)};

    return loans
        .map((loan) => LoanDetail(loan: loan, item: items[loan.itemId]!))
        .toList();
  }

  Future<LoanDetail> getDetailById(int id) async {
    final db = await _helper.database;
    final loan = await _loadLoan(db, id);
    final item = await _loadItem(db, loan.itemId);
    return LoanDetail(loan: loan, item: item);
  }

  /// FR-L2..FR-L4: quantity must fit available stock, and one transaction
  /// inserts the loan and takes the units out of stock together.
  Future<int> create(Loan loan) async {
    final borrower = requireText(loan.borrowerName, field: 'Nama peminjam');
    final quantity = requirePositiveInt(loan.quantity, field: 'Jumlah pinjam');
    _requireDueNotBeforeLoan(loan.loanDate, loan.dueDate);

    final db = await _helper.database;
    return db.transaction((txn) async {
      final item = await _loadItem(txn, loan.itemId);
      if (quantity > item.stockAvailable) {
        throw StockException(
          'Stok ${item.name} tersedia hanya ${item.stockAvailable}.',
        );
      }
      final values = loan.toMap()
        ..remove('id')
        ..['borrower_name'] = borrower
        ..['contact'] = optionalText(loan.contact)
        ..['quantity'] = quantity
        ..['status'] = LoanStatus.borrowed.dbValue
        ..['return_date'] = null
        ..['note'] = optionalText(loan.note);
      final id = await txn.insert(_table, values);
      await txn.rawUpdate(
        'UPDATE $_itemTable SET stock_available = stock_available - ? WHERE id = ?',
        [quantity, item.id],
      );
      return id;
    });
  }

  /// Recalculates stock for both sides when the item or quantity changes.
  /// A `selesai` loan keeps its item and quantity frozen so history stays valid.
  Future<void> update(Loan loan) async {
    final id = loan.id;
    if (id == null) {
      throw const ValidationException('Peminjaman belum tersimpan.');
    }
    final borrower = requireText(loan.borrowerName, field: 'Nama peminjam');
    final quantity = requirePositiveInt(loan.quantity, field: 'Jumlah pinjam');
    _requireDueNotBeforeLoan(loan.loanDate, loan.dueDate);

    final db = await _helper.database;
    await db.transaction((txn) async {
      final existing = await _loadLoan(txn, id);
      final shared = <String, Object?>{
        'borrower_name': borrower,
        'contact': optionalText(loan.contact),
        'loan_date': formatDate(loan.loanDate),
        'due_date': formatDate(loan.dueDate),
        'note': optionalText(loan.note),
      };

      if (existing.status == LoanStatus.returned) {
        if (loan.itemId != existing.itemId || quantity != existing.quantity) {
          throw const ValidationException(
            'Peminjaman selesai tidak bisa diganti barang atau jumlahnya.',
          );
        }
        await txn.update(_table, shared, where: 'id = ?', whereArgs: [id]);
        return;
      }

      final oldItem = await _loadItem(txn, existing.itemId);
      final sameItem = existing.itemId == loan.itemId;
      final newItem = sameItem ? oldItem : await _loadItem(txn, loan.itemId);
      // Units on this loan are free again before the new quantity is taken.
      final available = (sameItem ? oldItem.stockAvailable : newItem.stockAvailable) +
          (sameItem ? existing.quantity : 0);
      if (quantity > available) {
        throw StockException('Stok ${newItem.name} tersedia hanya $available.');
      }

      await txn.update(
        _table,
        shared
          ..['item_id'] = loan.itemId
          ..['quantity'] = quantity,
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        _itemTable,
        {'stock_available': available - quantity},
        where: 'id = ?',
        whereArgs: [newItem.id],
      );
      if (!sameItem) {
        await txn.update(
          _itemTable,
          {'stock_available': oldItem.stockAvailable + existing.quantity},
          where: 'id = ?',
          whereArgs: [oldItem.id],
        );
      }
    });
  }

  /// FR-L9: marks the loan done and returns its units to the item.
  Future<void> markReturned({required int loanId, required DateTime returnDate}) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      final loan = await _loadLoan(txn, loanId);
      if (loan.status == LoanStatus.returned) {
        throw const ValidationException('Peminjaman ini sudah selesai.');
      }
      if (isBeforeDay(returnDate, loan.loanDate)) {
        throw const ValidationException(
          'Tanggal kembali tidak boleh sebelum tanggal pinjam.',
        );
      }
      await txn.update(
        _table,
        {
          'status': LoanStatus.returned.dbValue,
          'return_date': formatDate(returnDate),
        },
        where: 'id = ?',
        whereArgs: [loanId],
      );
      await txn.rawUpdate(
        'UPDATE $_itemTable SET stock_available = stock_available + ? WHERE id = ?',
        [loan.quantity, loan.itemId],
      );
    });
  }

  /// FR-L11: deleting an active loan puts its units back before the row goes.
  Future<void> delete(int id) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      final loan = await _loadLoan(txn, id);
      if (loan.status == LoanStatus.borrowed) {
        await txn.rawUpdate(
          'UPDATE $_itemTable SET stock_available = stock_available + ? WHERE id = ?',
          [loan.quantity, loan.itemId],
        );
      }
      await txn.delete(_table, where: 'id = ?', whereArgs: [id]);
    });
  }

  void _requireDueNotBeforeLoan(DateTime loanDate, DateTime dueDate) {
    if (isBeforeDay(dueDate, loanDate)) {
      throw const ValidationException(
        'Tanggal kembali rencana tidak boleh sebelum tanggal pinjam.',
      );
    }
  }

  Future<Loan> _loadLoan(DatabaseExecutor db, int id) async {
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) {
      throw const NotFoundException('Peminjaman tidak ditemukan.');
    }
    return Loan.fromMap(rows.first);
  }

  Future<Item> _loadItem(DatabaseExecutor db, int id) async {
    final rows = await db.query(_itemTable, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) {
      throw const NotFoundException('Barang tidak ditemukan.');
    }
    return Item.fromMap(rows.first);
  }
}
