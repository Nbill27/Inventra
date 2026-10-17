import 'package:sqflite/sqflite.dart';

import '../core/dates.dart';
import '../core/exceptions.dart';
import '../core/validation.dart';
import '../db/database_helper.dart';
import '../models/item.dart';
import '../models/loan.dart';
import '../models/loan_detail.dart';
import '../models/loan_filter.dart';
import '../models/loan_stats.dart';

class LoanRepository {
  LoanRepository({DatabaseHelper? helper})
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  static const _table = 'loans';
  static const _itemTable = 'items';

  /// FR-L5: newest first. Items are fetched in one extra query instead of per row.
  ///
  /// [filter] narrows the list to one category; `null` means everything.
  /// [today] dipakai kategori "Terlambat" dan bisa dipatok oleh test.
  Future<List<LoanDetail>> getAllDetailed({
    LoanFilter? filter,
    DateTime? today,
  }) async {
    final db = await _helper.database;
    final conditions = <String>[];
    final args = <Object?>[];

    switch (filter) {
      case null:
        break;
      case LoanFilter.borrowed:
        conditions.add('status = ?');
        args.add(LoanStatus.borrowed.dbValue);
      case LoanFilter.returned:
        conditions.add('status = ?');
        args.add(LoanStatus.returned.dbValue);
      case LoanFilter.late:
        conditions.add('status = ?');
        conditions.add('due_date < ?');
        args.add(LoanStatus.borrowed.dbValue);
        args.add(formatDate(dateOnly(today ?? DateTime.now())));
    }

    final rows = await db.query(
      _table,
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'loan_date DESC, id DESC',
    );
    final loans = rows.map(Loan.fromMap).toList();
    if (loans.isEmpty) {
      return const [];
    }

    final itemIds = loans.map((loan) => loan.itemId).toSet().toList();
    final itemRows = await db.query(
      _itemTable,
      where: 'id IN (${List.filled(itemIds.length, '?').join(',')})',
      whereArgs: itemIds,
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

  /// Ringkasan untuk beranda, dihitung database dalam satu query agregat.
  ///
  /// Tanggal disimpan sebagai teks `YYYY-MM-DD`, jadi perbandingan teks sudah
  /// sama dengan perbandingan tanggal.
  Future<LoanStats> stats({required DateTime today}) async {
    final db = await _helper.database;
    final borrowed = LoanStatus.borrowed.dbValue;
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN status = ? THEN 1 ELSE 0 END), 0) AS active,
        COALESCE(SUM(CASE WHEN status = ? THEN quantity ELSE 0 END), 0)
          AS active_units,
        COALESCE(SUM(CASE WHEN status = ? AND due_date < ? THEN 1 ELSE 0 END), 0)
          AS late,
        COALESCE(SUM(CASE WHEN status = ? THEN 1 ELSE 0 END), 0) AS returned,
        COALESCE(SUM(CASE WHEN status = ? AND return_date <= due_date
          THEN 1 ELSE 0 END), 0) AS on_time,
        AVG(CASE WHEN status = ? THEN julianday(return_date) - julianday(loan_date)
          END) AS avg_days
      FROM $_table
    ''', [
      borrowed,
      borrowed,
      borrowed,
      formatDate(today),
      LoanStatus.returned.dbValue,
      LoanStatus.returned.dbValue,
      LoanStatus.returned.dbValue,
    ]);
    final row = rows.first;
    return LoanStats(
      active: (row['active'] as int?) ?? 0,
      activeUnits: (row['active_units'] as int?) ?? 0,
      late: (row['late'] as int?) ?? 0,
      returned: (row['returned'] as int?) ?? 0,
      onTime: (row['on_time'] as int?) ?? 0,
      averageLoanDays: (row['avg_days'] as num?)?.toDouble() ?? 0,
    );
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
        ..['contact'] = optionalContact(loan.contact)
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
        'contact': optionalContact(loan.contact),
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
      // Unit pinjaman ini bebas lagi sebelum jumlah yang baru diambil. Kalau
      // barangnya sama, stok yang tersedia bertambah sebanyak jumlah lama.
      final freedStock = sameItem
          ? oldItem.stockAvailable + existing.quantity
          : newItem.stockAvailable;
      if (quantity > freedStock) {
        throw StockException('Stok ${newItem.name} tersedia hanya $freedStock.');
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
        {'stock_available': freedStock - quantity},
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
