import 'package:sqflite/sqflite.dart';

import '../core/exceptions.dart';
import '../core/validation.dart';
import '../db/database_helper.dart';
import '../models/item.dart';
import '../models/item_filter.dart';
import '../models/item_import.dart';
import '../models/item_stats.dart';
import '../models/loan.dart';

class ItemRepository {
  ItemRepository({DatabaseHelper? helper})
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  static const _table = 'items';

  /// [filter] menyaring daftar ke satu kategori stok; `null` berarti semua
  /// barang. Syarat kategori digabung dengan pencarian memakai AND.
  Future<List<Item>> getAll({String? query, ItemFilter? filter}) async {
    final db = await _helper.database;
    final keyword = query?.trim() ?? '';
    final conditions = <String>[];
    final args = <Object?>[];

    if (keyword.isNotEmpty) {
      conditions.add('(name LIKE ? OR code LIKE ?)');
      args.addAll(['%$keyword%', '%$keyword%']);
    }
    if (filter != null) {
      conditions.add(_filterCondition(filter));
    }

    final rows = await db.query(
      _table,
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Item.fromMap).toList();
  }

  /// `borrowed` bersifat turunan, jadi syaratnya membandingkan dua kolom stok.
  String _filterCondition(ItemFilter filter) => switch (filter) {
        ItemFilter.available => 'stock_available > 0',
        ItemFilter.outOfStock => 'stock_available = 0',
        ItemFilter.borrowed => 'stock_total > stock_available',
      };

  Future<Item> getById(int id) async {
    final db = await _helper.database;
    final item = await _findById(db, id);
    if (item == null) {
      throw const NotFoundException('Barang tidak ditemukan.');
    }
    return item;
  }

  /// Satu baris berdasarkan id, atau `null` kalau tidak ada. Dipakai `getById`
  /// dan `update` supaya bentuk query-nya cuma ditulis sekali.
  Future<Item?> _findById(DatabaseExecutor db, int id) async {
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Item.fromMap(rows.first);
  }

  /// Ringkasan untuk beranda, dihitung database dalam satu query agregat.
  Future<ItemStats> stats() async {
    final db = await _helper.database;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS total_items,
             COALESCE(SUM(stock_total), 0) AS total_units,
             COALESCE(SUM(stock_available), 0) AS available_units,
             COALESCE(SUM(CASE WHEN stock_available = 0 THEN 1 ELSE 0 END), 0)
               AS out_of_stock
      FROM $_table
    ''');
    final row = rows.first;
    return ItemStats(
      totalItems: (row['total_items'] as int?) ?? 0,
      totalUnits: (row['total_units'] as int?) ?? 0,
      availableUnits: (row['available_units'] as int?) ?? 0,
      outOfStock: (row['out_of_stock'] as int?) ?? 0,
    );
  }

  /// A new item starts fully available, so `stock_available` mirrors `stock_total`.
  ///
  /// Kode dipakai mencocokkan duplikat saat impor, jadi kode yang sudah dipakai
  /// barang lain ditolak lebih dulu.
  Future<int> create(Item item) async {
    final db = await _helper.database;
    return db.transaction((txn) async {
      await _requireCodeFree(txn, optionalText(item.code));
      return txn.insert(_table, _validatedValues(item));
    });
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

  /// Kode kosong selalu boleh. Selain itu kode harus belum dipakai barang lain,
  /// dibandingkan tanpa membedakan huruf besar/kecil dan spasi tepi.
  Future<void> _requireCodeFree(
    DatabaseExecutor db,
    String? code, {
    int? exceptId,
  }) async {
    if (code == null) {
      return;
    }
    final rows = await db.query(
      _table,
      columns: ['id'],
      where: 'code IS NOT NULL AND LOWER(TRIM(code)) = ?'
          '${exceptId == null ? '' : ' AND id <> ?'}',
      whereArgs: [
        code.toLowerCase(),
        ?exceptId,
      ],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      throw ValidationException('Kode "$code" sudah dipakai barang lain.');
    }
  }

  Map<String, Object?> _validatedValues(Item item) {
    final stockTotal = requireNonNegativeInt(item.stockTotal, field: 'Stok total');
    return {
      ..._identityColumns(item),
      'stock_total': stockTotal,
      // Barang baru sepenuhnya tersedia, jadi ketersediaan menyalin total.
      'stock_available': stockTotal,
    };
  }

  /// Kolom teks yang sama untuk penambahan maupun perubahan.
  Map<String, Object?> _identityColumns(Item item) => {
        'no_urut': optionalText(item.noUrut),
        'name': requireText(item.name, field: 'Nama alat ukur'),
        'code': optionalText(item.code),
        'range_text': optionalText(item.range),
        'brand': optionalText(item.brand),
        'pic': optionalText(item.pic),
        'status': optionalText(item.status),
      };

  /// FR-B8: changing the total shifts availability by the same delta, so units
  /// that are out on loan stay out. Rejected when the new total is below them.
  Future<void> update(Item item) async {
    final id = item.id;
    if (id == null) {
      throw const ValidationException('Barang belum tersimpan.');
    }
    final stockTotal = requireNonNegativeInt(item.stockTotal, field: 'Stok total');

    final db = await _helper.database;
    await db.transaction((txn) async {
      final current = await _findById(txn, id);
      if (current == null) {
        throw const NotFoundException('Barang tidak ditemukan.');
      }
      final borrowed = current.borrowed;
      final available = stockTotal - borrowed;
      if (available < 0) {
        throw StockException(
          'Stok total tidak boleh kurang dari $borrowed unit yang sedang dipinjam.',
        );
      }
      final values = {
        ..._identityColumns(item),
        'stock_total': stockTotal,
        'stock_available': available,
      };
      // Kode milik barang ini sendiri tidak dihitung sebagai bentrok.
      await _requireCodeFree(txn, optionalText(item.code), exceptId: id);
      await txn.update(_table, values, where: 'id = ?', whereArgs: [id]);
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
