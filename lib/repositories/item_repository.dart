import 'package:sqflite/sqflite.dart';

import '../core/exceptions.dart';
import '../core/validation.dart';
import '../db/database_helper.dart';
import '../models/item.dart';
import '../models/item_import.dart';
import '../models/loan.dart';

class ItemRepository {
  ItemRepository({DatabaseHelper? helper})
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  static const _table = 'items';

  Future<List<Item>> getAll({String? query}) async {
    final db = await _helper.database;
    final keyword = query?.trim() ?? '';
    final rows = keyword.isEmpty
        ? await db.query(_table, orderBy: 'name COLLATE NOCASE ASC')
        : await db.query(
            _table,
            where: 'name LIKE ? OR code LIKE ?',
            whereArgs: ['%$keyword%', '%$keyword%'],
            orderBy: 'name COLLATE NOCASE ASC',
          );
    return rows.map(Item.fromMap).toList();
  }

  Future<Item> getById(int id) async {
    final db = await _helper.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) {
      throw const NotFoundException('Barang tidak ditemukan.');
    }
    return Item.fromMap(rows.first);
  }

  /// A new item starts fully available, so `stock_available` mirrors `stock_total`.
  Future<int> create(Item item) async {
    final db = await _helper.database;
    return db.insert(_table, _validatedValues(item));
  }

  /// Imports many items inside one transaction, so a failure halfway cannot
  /// leave a partial import behind.
  ///
  /// A row whose code already exists is skipped rather than duplicated or
  /// overwritten. Rows without a code are always inserted, since there is
  /// nothing to match them against.
  Future<ImportReport> importItems(List<ItemDraft> drafts) async {
    if (drafts.isEmpty) {
      return const ImportReport(added: 0, skipped: [], issues: []);
    }

    final db = await _helper.database;
    final skipped = <String>[];
    final issues = <ImportIssue>[];
    var added = 0;

    await db.transaction((txn) async {
      final codeRows = await txn.query(
        _table,
        columns: ['code'],
        where: 'code IS NOT NULL',
      );
      final known = <String>{
        for (final row in codeRows)
          if ((row['code'] as String?)?.trim().isNotEmpty ?? false)
            (row['code'] as String).trim().toLowerCase(),
      };

      for (final draft in drafts) {
        final key = draft.code?.trim().toLowerCase();
        if (key != null && known.contains(key)) {
          skipped.add(draft.name);
          continue;
        }
        try {
          await txn.insert(_table, _validatedValues(draft.toItem()));
          added++;
          if (key != null) {
            known.add(key);
          }
        } on ValidationException catch (error) {
          issues.add(
            ImportIssue(rowNumber: draft.rowNumber, message: error.message),
          );
        }
      }
    });

    return ImportReport(added: added, skipped: skipped, issues: issues);
  }

  Map<String, Object?> _validatedValues(Item item) => {
        'no_urut': optionalText(item.noUrut),
        'name': requireText(item.name, field: 'Nama alat ukur'),
        'code': optionalText(item.code),
        'range_text': optionalText(item.range),
        'brand': optionalText(item.brand),
        'pic': optionalText(item.pic),
        'status': optionalText(item.status),
        'stock_total': requireNonNegativeInt(item.stockTotal, field: 'Stok total'),
        'stock_available': requireNonNegativeInt(item.stockTotal, field: 'Stok total'),
      };

  /// FR-B8: changing the total shifts availability by the same delta, so units
  /// that are out on loan stay out. Rejected when the new total is below them.
  Future<void> update(Item item) async {
    final id = item.id;
    if (id == null) {
      throw const ValidationException('Barang belum tersimpan.');
    }
    final name = requireText(item.name, field: 'Nama alat ukur');
    final stockTotal = requireNonNegativeInt(item.stockTotal, field: 'Stok total');

    final db = await _helper.database;
    await db.transaction((txn) async {
      final rows = await txn.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) {
        throw const NotFoundException('Barang tidak ditemukan.');
      }
      final current = Item.fromMap(rows.first);
      final borrowed = current.borrowed;
      final available = stockTotal - borrowed;
      if (available < 0) {
        throw StockException(
          'Stok total tidak boleh kurang dari $borrowed unit yang sedang dipinjam.',
        );
      }
      await txn.update(
        _table,
        {
          'no_urut': optionalText(item.noUrut),
          'name': name,
          'code': optionalText(item.code),
          'range_text': optionalText(item.range),
          'brand': optionalText(item.brand),
          'pic': optionalText(item.pic),
          'status': optionalText(item.status),
          'stock_total': stockTotal,
          'stock_available': available,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// FR-B7 blocks deletion while a loan is active. Loans that are already
  /// `selesai` also block it, because the `loans.item_id` foreign key keeps the
  /// history intact. That is stricter than FR-B7 and is reported as a deviation.
  Future<void> delete(int id) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      final history = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM loans WHERE item_id = ?',
            [id],
          )) ??
          0;
      if (history > 0) {
        final active = Sqflite.firstIntValue(await txn.rawQuery(
              'SELECT COUNT(*) FROM loans WHERE item_id = ? AND status = ?',
              [id, LoanStatus.borrowed.dbValue],
            )) ??
            0;
        throw DeleteBlockedException(
          active > 0
              ? 'Barang masih punya $active peminjaman aktif. Selesaikan atau hapus dulu.'
              : 'Barang punya $history riwayat peminjaman. Hapus riwayatnya dulu.',
        );
      }
      final deleted = await txn.delete(_table, where: 'id = ?', whereArgs: [id]);
      if (deleted == 0) {
        throw const NotFoundException('Barang tidak ditemukan.');
      }
    });
  }
}
