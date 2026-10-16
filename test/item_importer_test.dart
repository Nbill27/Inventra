import 'package:flutter_test/flutter_test.dart';
import 'package:peminjaman_barang/core/exceptions.dart';
import 'package:peminjaman_barang/models/item_import.dart';
import 'package:peminjaman_barang/services/csv_parser.dart';
import 'package:peminjaman_barang/services/item_importer.dart';

void main() {
  const importer = ItemImporter();

  const table = CsvTable(
    header: ['nama', 'kode', 'kategori', 'stok', 'catatan'],
    rows: [
      ['Proyektor', 'PRJ-1', 'Elektronik', '5', 'unit A'],
      ['Kabel HDMI', '', '  ', '2', ''],
    ],
  );

  const mapping = {
    ItemField.name: 0,
    ItemField.code: 1,
    ItemField.category: 2,
    ItemField.stockTotal: 3,
    ItemField.note: 4,
  };

  test('turns rows into drafts, trimming text and blanking empty fields', () {
    final plan = importer.plan(table: table, mapping: mapping);

    expect(plan.issues, isEmpty);
    expect(plan.drafts.length, 2);

    final first = plan.drafts.first;
    expect(first.rowNumber, 1);
    expect(first.name, 'Proyektor');
    expect(first.code, 'PRJ-1');
    expect(first.category, 'Elektronik');
    expect(first.stockTotal, 5);
    expect(first.note, 'unit A');

    final second = plan.drafts.last;
    expect(second.code, isNull);
    expect(second.category, isNull);
    expect(second.note, isNull);
  });

  test('leaves unmapped optional columns null', () {
    final plan = importer.plan(
      table: table,
      mapping: const {ItemField.name: 0, ItemField.stockTotal: 3},
    );

    expect(plan.drafts.first.code, isNull);
    expect(plan.drafts.first.category, isNull);
    expect(plan.drafts.first.note, isNull);
  });

  test('reads a thousand separator in the stock column', () {
    const withSeparator = CsvTable(
      header: ['nama', 'stok'],
      rows: [
        ['Kursi', '1.000'],
        ['Meja', '1,000'],
      ],
    );

    final plan = importer.plan(
      table: withSeparator,
      mapping: const {ItemField.name: 0, ItemField.stockTotal: 1},
    );

    expect(plan.drafts.map((draft) => draft.stockTotal), [1000, 1000]);
  });

  test('reports a row without a name instead of importing it', () {
    const missingName = CsvTable(
      header: ['nama', 'stok'],
      rows: [
        ['', '5'],
        ['Proyektor', '5'],
      ],
    );

    final plan = importer.plan(
      table: missingName,
      mapping: const {ItemField.name: 0, ItemField.stockTotal: 1},
    );

    expect(plan.drafts.length, 1);
    expect(plan.drafts.single.name, 'Proyektor');
    expect(plan.issues.single.rowNumber, 1);
    expect(plan.issues.single.message, contains('Nama barang'));
  });

  test('reports a stock value that is not a whole number', () {
    const badStock = CsvTable(
      header: ['nama', 'stok'],
      rows: [
        ['Proyektor', 'lima'],
        ['Kabel', '-2'],
      ],
    );

    final plan = importer.plan(
      table: badStock,
      mapping: const {ItemField.name: 0, ItemField.stockTotal: 1},
    );

    expect(plan.drafts, isEmpty);
    expect(plan.issues.length, 2);
    expect(plan.issues.first.rowNumber, 1);
    expect(plan.issues.last.rowNumber, 2);
  });

  test('treats a short row as empty trailing columns', () {
    const shortRow = CsvTable(
      header: ['nama', 'kode', 'stok'],
      rows: [
        ['Proyektor', 'PRJ-1'],
      ],
    );

    final plan = importer.plan(
      table: shortRow,
      mapping: const {
        ItemField.name: 0,
        ItemField.code: 1,
        ItemField.stockTotal: 2,
      },
    );

    expect(plan.issues.single.message, contains('Stok total'));
  });

  test('refuses to plan without the two required columns', () {
    expect(
      () => importer.plan(
        table: table,
        mapping: const {ItemField.stockTotal: 3},
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => importer.plan(
        table: table,
        mapping: const {ItemField.name: 0},
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('a draft becomes an item whose availability equals its total', () {
    final item = table.rows.isEmpty
        ? null
        : importer
            .plan(table: table, mapping: mapping)
            .drafts
            .first
            .toItem();

    expect(item, isNotNull);
    expect(item!.stockTotal, 5);
    expect(item.stockAvailable, 5);
    expect(item.borrowed, 0);
  });
}
