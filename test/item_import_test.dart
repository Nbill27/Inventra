import 'package:flutter_test/flutter_test.dart';
import 'package:peminjaman_barang/db/database_helper.dart';
import 'package:peminjaman_barang/models/item_import.dart';
import 'package:peminjaman_barang/repositories/item_repository.dart';

import 'support/test_database.dart';

void main() {
  late DatabaseHelper helper;
  late ItemRepository items;

  setUp(() {
    helper = createTestDatabase();
    items = ItemRepository(helper: helper);
  });

  tearDown(() => helper.close());

  ItemDraft draft(
    int rowNumber,
    String name, {
    String? code,
    int stockTotal = 5,
  }) =>
      ItemDraft(
        rowNumber: rowNumber,
        name: name,
        code: code,
        stockTotal: stockTotal,
      );

  test('a fresh file is inserted in full, fully available', () async {
    final report = await items.importItems([
      draft(1, 'Proyektor', code: 'PRJ-1', stockTotal: 5),
      draft(2, 'Kabel HDMI', code: 'KLB-2', stockTotal: 2),
    ]);

    expect(report.added, 2);
    expect(report.skipped, isEmpty);
    expect(report.issues, isEmpty);

    final stored = await items.getAll();
    expect(stored.length, 2);
    expect(stored.every((item) => item.stockAvailable == item.stockTotal), isTrue);
  });

  test('a code that already exists is skipped, not duplicated', () async {
    await items.importItems([draft(1, 'Proyektor', code: 'PRJ-1')]);

    final report = await items.importItems([
      draft(1, 'Proyektor lain', code: 'prj-1 '),
      draft(2, 'Kabel', code: 'KLB-2'),
    ]);

    expect(report.added, 1);
    expect(report.skipped, ['Proyektor lain']);
    expect((await items.getAll()).length, 2);
  });

  test('a code repeated inside the same file is skipped the second time', () async {
    final report = await items.importItems([
      draft(1, 'Proyektor', code: 'PRJ-1'),
      draft(2, 'Proyektor salinan', code: 'PRJ-1'),
    ]);

    expect(report.added, 1);
    expect(report.skipped, ['Proyektor salinan']);
  });

  test('rows without a code are always inserted, there is no key to match', () async {
    final report = await items.importItems([
      draft(1, 'Proyektor', stockTotal: 3),
      draft(2, 'Proyektor', stockTotal: 3),
    ]);

    expect(report.added, 2);
    expect(report.skipped, isEmpty);
  });

  test('a row rejected by validation is reported and the rest still import', () async {
    final report = await items.importItems([
      draft(1, '   ', code: 'X-1'),
      draft(2, 'Proyektor', code: 'PRJ-1'),
    ]);

    expect(report.added, 1);
    expect(report.issues.single.rowNumber, 1);
    expect(report.issues.single.message, contains('Nama barang'));
    expect((await items.getAll()).length, 1);
  });

  test('an empty file changes nothing', () async {
    final report = await items.importItems([]);

    expect(report.added, 0);
    expect(report.skipped, isEmpty);
    expect(report.issues, isEmpty);
    expect(report.total, 0);
  });

  test('imported items take part in the normal stock rules', () async {
    await items.importItems([draft(1, 'Proyektor', code: 'PRJ-1', stockTotal: 4)]);

    final stored = (await items.getAll()).single;
    await items.update(stored.copyWith(stockTotal: 1, stockAvailable: 1));

    expect((await items.getById(stored.id!)).stockTotal, 1);
  });
}
