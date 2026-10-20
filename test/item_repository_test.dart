import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:peminjaman_barang/core/exceptions.dart';
import 'package:peminjaman_barang/db/database_helper.dart';
import 'package:peminjaman_barang/models/item_filter.dart';
import 'package:peminjaman_barang/repositories/item_repository.dart';
import 'package:peminjaman_barang/repositories/loan_repository.dart';

import 'support/test_database.dart';

void main() {
  late DatabaseHelper helper;
  late ItemRepository items;
  late LoanRepository loans;

  setUp(() {
    helper = createTestDatabase();
    items = ItemRepository(helper: helper);
    loans = LoanRepository(helper: helper);
  });

  tearDown(() => helper.close());

  test('a fresh database is filled by the injected seed', () async {
    // createTestDatabase injects an empty seed; a non-empty one plays the role
    // of the bundled asset and must land in the items table on creation.
    final seededHelper = DatabaseHelper(
      factory: databaseFactoryFfi,
      path: ':memory:',
      seedLoader: () async => [
        {
          'no_urut': '1',
          'name': 'Digital Caliper',
          'code': 'RAB/01/01',
          'range_text': '300 mm',
          'brand': 'Mitutoyo',
          'pic': 'QC',
          'status': 'OK',
          'stock_total': 1,
          'stock_available': 1,
        },
      ],
    );
    addTearDown(seededHelper.close);

    final seededItems = ItemRepository(helper: seededHelper);
    final list = await seededItems.getAll();

    expect(list, hasLength(1));
    expect(list.single.name, 'Digital Caliper');
    expect(list.single.stockTotal, 1);
    expect(list.single.stockAvailable, 1);
  });

  test('T1: a new item starts fully available', () async {
    final id = await items.create(itemFixture());

    final item = await items.getById(id);
    expect(item.name, 'Proyektor');
    expect(item.stockTotal, 5);
    expect(item.stockAvailable, 5);
    expect(item.borrowed, 0);
  });

  test('FR-B4: detail of a missing item reports not found', () async {
    expect(() => items.getById(404), throwsA(isA<NotFoundException>()));
  });

  test('name is required and trimmed', () async {
    expect(
      () => items.create(itemFixture(name: '   ')),
      throwsA(isA<ValidationException>()),
    );

    final id = await items.create(itemFixture(name: '  Proyektor  '));
    expect((await items.getById(id)).name, 'Proyektor');
  });

  test('FR-B8 / T8: raising the total keeps borrowed units out', () async {
    final id = await items.create(itemFixture());
    await loans.create(loanFixture(itemId: id, quantity: 2));

    final current = await items.getById(id);
    await items.update(current.copyWith(stockTotal: 8));

    final updated = await items.getById(id);
    expect(updated.stockTotal, 8);
    expect(updated.stockAvailable, 6);
  });

  test('T9: lowering the total below borrowed units is rejected', () async {
    final id = await items.create(itemFixture());
    await loans.create(loanFixture(itemId: id, quantity: 2));

    final current = await items.getById(id);
    await expectLater(
      items.update(current.copyWith(stockTotal: 1)),
      throwsA(isA<StockException>()),
    );

    final unchanged = await items.getById(id);
    expect(unchanged.stockTotal, 5);
    expect(unchanged.stockAvailable, 3);
  });

  test('FR-B3: search matches name or code, case-insensitively', () async {
    await items.create(itemFixture(name: 'Proyektor', code: 'PJ-01'));
    await items.create(itemFixture(name: 'Kabel HDMI', code: 'KB-99'));

    expect((await items.getAll(query: 'proyek')).map((i) => i.name), ['Proyektor']);
    expect((await items.getAll(query: 'kb-99')).map((i) => i.name), ['Kabel HDMI']);
    expect((await items.getAll(query: '')).length, 2);
  });

  test('filter kategori: tersedia, habis, dan dipinjam', () async {
    await items.create(itemFixture(name: 'Proyektor', stockTotal: 5));
    final habis = await items.create(itemFixture(name: 'Kabel HDMI', stockTotal: 3));
    final sebagian = await items.create(itemFixture(name: 'Roll Meter', stockTotal: 4));

    // Kabel HDMI habis dipinjam; Roll Meter hanya sebagian.
    await loans.create(loanFixture(itemId: habis, quantity: 3));
    await loans.create(loanFixture(itemId: sebagian, quantity: 1));

    Future<List<String>> names(ItemFilter filter) async =>
        (await items.getAll(filter: filter)).map((i) => i.name).toList();

    expect(await names(ItemFilter.available), ['Proyektor', 'Roll Meter']);
    expect(await names(ItemFilter.outOfStock), ['Kabel HDMI']);
    expect(await names(ItemFilter.borrowed), ['Kabel HDMI', 'Roll Meter']);
    expect((await items.getAll()).length, 3);
  });

  test('filter kategori digabung dengan pencarian', () async {
    final proyektor = await items.create(itemFixture(name: 'Proyektor', stockTotal: 5));
    await items.create(itemFixture(name: 'Proyektor Mini', stockTotal: 5));
    await loans.create(loanFixture(itemId: proyektor, quantity: 5));

    final hasil = await items.getAll(
      query: 'proyektor',
      filter: ItemFilter.outOfStock,
    );
    expect(hasil.map((i) => i.name), ['Proyektor']);
  });

  test('FR-B6: updating replaces the editable fields', () async {
    final id = await items.create(itemFixture());

    final current = await items.getById(id);
    await items.update(
      current.copyWith(
        noUrut: '7',
        name: 'Jangka Sorong',
        code: 'JS-02',
        range: '150 mm',
        brand: 'Mitutoyo',
        pic: 'QC',
        status: 'OK',
        stockTotal: 6,
      ),
    );

    final updated = await items.getById(id);
    expect(updated.noUrut, '7');
    expect(updated.name, 'Jangka Sorong');
    expect(updated.code, 'JS-02');
    expect(updated.range, '150 mm');
    expect(updated.brand, 'Mitutoyo');
    expect(updated.pic, 'QC');
    expect(updated.status, 'OK');
    expect(updated.stockAvailable, 6);
  });

  test('T7: delete is blocked while a loan is active', () async {
    final id = await items.create(itemFixture());
    await loans.create(loanFixture(itemId: id));

    await expectLater(
      items.delete(id),
      throwsA(isA<DeleteBlockedException>()),
    );
    expect((await items.getAll()).length, 1);
  });

  test('delete is blocked while loan history remains', () async {
    final id = await items.create(itemFixture());
    final loanId = await loans.create(loanFixture(itemId: id));
    await loans.markReturned(loanId: loanId, returnDate: DateTime(2026, 10, 5));

    await expectLater(
      items.delete(id),
      throwsA(isA<DeleteBlockedException>()),
    );
  });

  test('delete succeeds once the loans are gone', () async {
    final id = await items.create(itemFixture());
    final loanId = await loans.create(loanFixture(itemId: id));
    await loans.delete(loanId);

    await items.delete(id);
    expect(await items.getAll(), isEmpty);
  });

  test('stock total cannot be negative', () async {
    expect(
      () => items.create(itemFixture(stockTotal: -1)),
      throwsA(isA<ValidationException>()),
    );
  });

  test('update of an unsaved item is rejected', () async {
    expect(
      () => items.update(itemFixture()),
      throwsA(isA<ValidationException>()),
    );
  });
}
