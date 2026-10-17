import 'package:flutter_test/flutter_test.dart';
import 'package:peminjaman_barang/core/exceptions.dart';
import 'package:peminjaman_barang/db/database_helper.dart';
import 'package:peminjaman_barang/models/loan.dart';
import 'package:peminjaman_barang/models/loan_filter.dart';
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

  test('T2: creating a loan takes the units out of stock', () async {
    final itemId = await items.create(itemFixture());
    await loans.create(loanFixture(itemId: itemId, quantity: 2));

    final item = await items.getById(itemId);
    expect(item.stockAvailable, 3);

    final [detail] = await loans.getAllDetailed();
    expect(detail.loan.status, LoanStatus.borrowed);
    expect(detail.loan.returnDate, isNull);
    expect(detail.item.name, 'Proyektor');
  });

  test('T3: a loan larger than available stock is rejected', () async {
    final itemId = await items.create(itemFixture());
    await loans.create(loanFixture(itemId: itemId, quantity: 2));

    await expectLater(
      loans.create(loanFixture(itemId: itemId, quantity: 4)),
      throwsA(isA<StockException>()),
    );

    expect((await items.getById(itemId)).stockAvailable, 3);
    expect((await loans.getAllDetailed()).length, 1);
  });

  test('T4: marking returned restores stock and finishes the loan', () async {
    final itemId = await items.create(itemFixture());
    final loanId = await loans.create(loanFixture(itemId: itemId, quantity: 2));

    await loans.markReturned(loanId: loanId, returnDate: DateTime(2026, 10, 6));

    final detail = await loans.getDetailById(loanId);
    expect(detail.loan.status, LoanStatus.returned);
    expect(detail.loan.returnDate, DateTime(2026, 10, 6));
    expect((await items.getById(itemId)).stockAvailable, 5);
  });

  test('T5: deleting an active loan gives the units back', () async {
    final itemId = await items.create(itemFixture());
    final loanId = await loans.create(loanFixture(itemId: itemId, quantity: 2));

    await loans.delete(loanId);

    expect((await items.getById(itemId)).stockAvailable, 5);
    expect(await loans.getAllDetailed(), isEmpty);
  });

  test('T6: deleting a finished loan leaves stock alone', () async {
    final itemId = await items.create(itemFixture());
    final loanId = await loans.create(loanFixture(itemId: itemId, quantity: 2));
    await loans.markReturned(loanId: loanId, returnDate: DateTime(2026, 10, 6));

    await loans.delete(loanId);

    expect((await items.getById(itemId)).stockAvailable, 5);
  });

  test('T10: a due date before the loan date is rejected', () async {
    final itemId = await items.create(itemFixture());

    await expectLater(
      loans.create(
        loanFixture(
          itemId: itemId,
          loanDate: DateTime(2026, 10, 8),
          dueDate: DateTime(2026, 10, 7),
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
    expect((await items.getById(itemId)).stockAvailable, 5);
  });

  test('a return date before the loan date is rejected', () async {
    final itemId = await items.create(itemFixture());
    final loanId = await loans.create(loanFixture(itemId: itemId));

    await expectLater(
      loans.markReturned(loanId: loanId, returnDate: DateTime(2026, 9, 30)),
      throwsA(isA<ValidationException>()),
    );
    expect((await loans.getDetailById(loanId)).loan.status, LoanStatus.borrowed);
  });

  test('T11: overdue is derived from the due date, not stored', () async {
    final itemId = await items.create(itemFixture());
    await loans.create(
      loanFixture(
        itemId: itemId,
        loanDate: DateTime(2026, 10, 1),
        dueDate: DateTime(2026, 10, 8),
      ),
    );

    final [detail] = await loans.getAllDetailed();
    expect(detail.loan.status, LoanStatus.borrowed);
    expect(detail.loan.isLateOn(DateTime(2026, 10, 8)), isFalse);
    expect(detail.loan.isLateOn(DateTime(2026, 10, 9)), isTrue);
  });

  test('a finished loan is never late', () async {
    final itemId = await items.create(itemFixture());
    final loanId = await loans.create(loanFixture(itemId: itemId));
    await loans.markReturned(loanId: loanId, returnDate: DateTime(2026, 10, 30));

    final detail = await loans.getDetailById(loanId);
    expect(detail.loan.isLateOn(DateTime(2026, 11, 30)), isFalse);
  });

  test('borrower name is required and quantity must be positive', () async {
    final itemId = await items.create(itemFixture());

    await expectLater(
      loans.create(loanFixture(itemId: itemId, borrowerName: '  ')),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      loans.create(loanFixture(itemId: itemId, quantity: 0)),
      throwsA(isA<ValidationException>()),
    );
  });

  test('a loan for a missing item is rejected', () async {
    await expectLater(
      loans.create(loanFixture(itemId: 404)),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('FR-L5: the list runs newest first', () async {
    final itemId = await items.create(itemFixture(stockTotal: 10));
    await loans.create(
      loanFixture(itemId: itemId, loanDate: DateTime(2026, 10, 1)),
    );
    await loans.create(
      loanFixture(
        itemId: itemId,
        loanDate: DateTime(2026, 10, 9),
        dueDate: DateTime(2026, 10, 16),
      ),
    );

    final list = await loans.getAllDetailed();
    expect(list.first.loan.loanDate, DateTime(2026, 10, 9));
  });

  test('FR-L6: the list can be filtered by category', () async {
    final itemId = await items.create(itemFixture(stockTotal: 10));
    final activeId = await loans.create(
      loanFixture(itemId: itemId, quantity: 1, dueDate: DateTime(2026, 10, 20)),
    );
    final lateId = await loans.create(
      loanFixture(itemId: itemId, quantity: 1, dueDate: DateTime(2026, 10, 5)),
    );
    final doneId = await loans.create(loanFixture(itemId: itemId, quantity: 2));
    await loans.markReturned(loanId: doneId, returnDate: DateTime(2026, 10, 6));

    final today = DateTime(2026, 10, 10);

    expect((await loans.getAllDetailed()).length, 3);

    // "Dipinjam" mencakup yang sudah lewat tenggat.
    final borrowed = await loans.getAllDetailed(filter: LoanFilter.borrowed);
    expect(borrowed.length, 2);
    expect(borrowed.map((d) => d.loan.id), containsAll([activeId, lateId]));

    final late = await loans.getAllDetailed(
      filter: LoanFilter.late,
      today: today,
    );
    expect(late.single.loan.id, lateId);

    final done = await loans.getAllDetailed(filter: LoanFilter.returned);
    expect(done.single.loan.id, doneId);
  });

  test('6.3.3: changing the quantity recalculates stock', () async {
    final itemId = await items.create(itemFixture());
    final loanId = await loans.create(loanFixture(itemId: itemId, quantity: 2));

    final detail = await loans.getDetailById(loanId);
    await loans.update(detail.loan.copyWith(quantity: 4));

    expect((await items.getById(itemId)).stockAvailable, 1);
  });

  test('6.3.3: changing the quantity above stock is rejected', () async {
    final itemId = await items.create(itemFixture());
    final loanId = await loans.create(loanFixture(itemId: itemId, quantity: 2));

    final detail = await loans.getDetailById(loanId);
    await expectLater(
      loans.update(detail.loan.copyWith(quantity: 6)),
      throwsA(isA<StockException>()),
    );

    expect((await items.getById(itemId)).stockAvailable, 3);
  });

  test('6.3.3: switching item recalculates both items', () async {
    final projector = await items.create(itemFixture(name: 'Proyektor', stockTotal: 5));
    final speaker = await items.create(itemFixture(name: 'Speaker', stockTotal: 5));
    final loanId = await loans.create(loanFixture(itemId: projector, quantity: 2));

    final detail = await loans.getDetailById(loanId);
    await loans.update(detail.loan.copyWith(itemId: speaker, quantity: 3));

    expect((await items.getById(projector)).stockAvailable, 5);
    expect((await items.getById(speaker)).stockAvailable, 2);
  });

  test('switching item without enough stock is rejected, both untouched', () async {
    final projector = await items.create(itemFixture(name: 'Proyektor', stockTotal: 5));
    final speaker = await items.create(itemFixture(name: 'Speaker', stockTotal: 2));
    final loanId = await loans.create(loanFixture(itemId: projector, quantity: 2));

    final detail = await loans.getDetailById(loanId);
    await expectLater(
      loans.update(detail.loan.copyWith(itemId: speaker, quantity: 3)),
      throwsA(isA<StockException>()),
    );

    expect((await items.getById(projector)).stockAvailable, 3);
    expect((await items.getById(speaker)).stockAvailable, 2);
  });

  test('a finished loan keeps its item and quantity frozen', () async {
    final projector = await items.create(itemFixture(name: 'Proyektor', stockTotal: 5));
    final speaker = await items.create(itemFixture(name: 'Speaker', stockTotal: 5));
    final loanId = await loans.create(loanFixture(itemId: projector, quantity: 2));
    await loans.markReturned(loanId: loanId, returnDate: DateTime(2026, 10, 6));

    final detail = await loans.getDetailById(loanId);
    await expectLater(
      loans.update(detail.loan.copyWith(quantity: 3)),
      throwsA(isA<ValidationException>()),
    );
    expect((await items.getById(projector)).stockAvailable, 5);

    await expectLater(
      loans.update(detail.loan.copyWith(itemId: speaker)),
      throwsA(isA<ValidationException>()),
    );
  });

  test('a loan cannot be returned twice', () async {
    final itemId = await items.create(itemFixture());
    final loanId = await loans.create(loanFixture(itemId: itemId, quantity: 2));
    await loans.markReturned(loanId: loanId, returnDate: DateTime(2026, 10, 6));

    await expectLater(
      loans.markReturned(loanId: loanId, returnDate: DateTime(2026, 10, 7)),
      throwsA(isA<ValidationException>()),
    );
    expect((await items.getById(itemId)).stockAvailable, 5);
  });

  test('NFR-3: a failed write leaves stock untouched', () async {
    final itemId = await items.create(itemFixture(stockTotal: 3));
    await loans.create(loanFixture(itemId: itemId, quantity: 3));
    expect((await items.getById(itemId)).stockAvailable, 0);

    await expectLater(
      loans.create(loanFixture(itemId: itemId, quantity: 1)),
      throwsA(isA<StockException>()),
    );

    expect((await items.getById(itemId)).stockAvailable, 0);
    expect((await loans.getAllDetailed()).length, 1);
  });
}
