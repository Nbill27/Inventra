import 'package:flutter_test/flutter_test.dart';
import 'package:peminjaman_barang/db/database_helper.dart';
import 'package:peminjaman_barang/providers/loan_provider.dart';
import 'package:peminjaman_barang/repositories/item_repository.dart';
import 'package:peminjaman_barang/repositories/loan_repository.dart';

import 'support/test_database.dart';

void main() {
  late DatabaseHelper helper;
  late ItemRepository items;
  late LoanRepository loans;
  late DateTime now;

  setUp(() {
    helper = createTestDatabase();
    items = ItemRepository(helper: helper);
    loans = LoanRepository(helper: helper);
    now = DateTime(2026, 10, 1, 8);
  });

  tearDown(() => helper.close());

  LoanProvider build() =>
      LoanProvider(repository: loans, clock: () => now);

  test('today mengikuti jam yang disuntikkan, tanpa bagian waktu', () {
    final provider = build();

    expect(provider.today, DateTime(2026, 10, 1));
  });

  test('data dianggap segar pada hari yang sama', () async {
    final itemId = await items.create(itemFixture());
    await loans.create(loanFixture(itemId: itemId));

    final provider = build();
    expect(provider.isStale, isTrue, reason: 'belum pernah dimuat');

    await provider.load();
    expect(provider.isStale, isFalse);

    // Jam bergerak tapi harinya masih sama: belum basi.
    now = DateTime(2026, 10, 1, 23, 59);
    expect(provider.isStale, isFalse);
  });

  test('lewat tengah malam membuat data basi sampai dimuat ulang', () async {
    final itemId = await items.create(itemFixture());
    await loans.create(loanFixture(itemId: itemId));

    final provider = build();
    await provider.load();
    expect(provider.stats.active, 1);

    now = DateTime(2026, 10, 2, 0, 5);
    expect(provider.isStale, isTrue, reason: 'ringkasan dihitung kemarin');

    await provider.load();
    expect(provider.isStale, isFalse);
  });

  test('ringkasan memakai hari saat pemuatan, bukan tanggal pinjam', () async {
    // Rencana kembali hari ini: belum terlambat hari ini, terlambat besok.
    final itemId = await items.create(itemFixture());
    await loans.create(
      loanFixture(itemId: itemId, dueDate: DateTime(2026, 10, 1)),
    );

    final provider = build();
    await provider.load();
    expect(provider.stats.late, 0);

    now = DateTime(2026, 10, 2, 9);
    await provider.load();
    expect(provider.stats.late, 1);
  });
}
