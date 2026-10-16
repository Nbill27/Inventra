import 'package:flutter_test/flutter_test.dart';
import 'package:peminjaman_barang/core/exceptions.dart';
import 'package:peminjaman_barang/db/database_helper.dart';
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

  test('FR-B6: updating replaces the editable fields', () async {
    final id = await items.create(itemFixture());

    final current = await items.getById(id);
    await items.update(
      current.copyWith(
        name: 'Proyektor Epson',
        code: 'PJ-02',
        category: 'Elektronik',
        note: 'Rak A',
        stockTotal: 6,
      ),
    );

    final updated = await items.getById(id);
    expect(updated.name, 'Proyektor Epson');
    expect(updated.code, 'PJ-02');
    expect(updated.category, 'Elektronik');
    expect(updated.note, 'Rak A');
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
