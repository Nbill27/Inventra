import 'package:flutter_test/flutter_test.dart';
import 'package:peminjaman_barang/core/exceptions.dart';
import 'package:peminjaman_barang/services/csv_parser.dart';
import 'package:peminjaman_barang/services/item_importer.dart';

void main() {
  const importer = ItemImporter();

  /// The header of the mentor's "Daftar Alat Ukur" file.
  const table = CsvTable(
    header: [
      'NO',
      'FOTO',
      'NAMA ALAT UKUR',
      'KODE ALAT UKUR',
      'RANGE',
      'BRAND',
      'PIC',
      'STATUS',
    ],
    rows: [
      ['1', '', 'Digital Caliper', 'RAB/01/01', '300 mm', 'Mitutoyo', 'QC', 'OK'],
      [
        '2',
        '',
        'Bevel Protector\n(121432)',
        'RAB/02/001',
        '180O',
        'Mitutoyo',
        'QC',
        'Not Good / Rusak',
      ],
    ],
  );

  test('maps the master file columns automatically', () {
    final plan = importer.plan(table: table, stockPerRow: 1);

    expect(plan.issues, isEmpty);
    expect(plan.drafts.length, 2);

    final first = plan.drafts.first;
    expect(first.rowNumber, 1);
    expect(first.noUrut, '1');
    expect(first.name, 'Digital Caliper');
    expect(first.code, 'RAB/01/01');
    expect(first.range, '300 mm');
    expect(first.brand, 'Mitutoyo');
    expect(first.pic, 'QC');
    expect(first.status, 'OK');
    expect(first.stockTotal, 1);
  });

  test('reports the recognised columns and skips FOTO', () {
    final plan = importer.plan(table: table, stockPerRow: 1);

    final labels = plan.detected.map((column) => column.label).toList();
    expect(
      labels,
      containsAll([
        'No',
        'Nama alat ukur',
        'Kode alat ukur',
        'Range',
        'Brand',
        'PIC',
        'Status',
      ]),
    );
    expect(plan.detected.any((column) => column.label == 'Stok total'), isFalse);
    expect(
      plan.detected.any((column) => column.header.toUpperCase() == 'FOTO'),
      isFalse,
    );
  });

  test('collapses a name split across two lines', () {
    final plan = importer.plan(table: table, stockPerRow: 1);
    expect(plan.drafts.last.name, 'Bevel Protector (121432)');
  });

  test('uses one stock value for every row when there is no stock column', () {
    final plan = importer.plan(table: table, stockPerRow: 3);

    expect(plan.issues, isEmpty);
    expect(plan.drafts.map((draft) => draft.stockTotal), [3, 3]);
  });

  test('reads stock from a stock column when the file has one', () {
    const withStock = CsvTable(
      header: ['NAMA ALAT UKUR', 'STOK'],
      rows: [
        ['Kursi', '1.000'],
        ['Meja', '1,000'],
      ],
    );

    final plan = importer.plan(table: withStock);

    expect(plan.drafts.map((draft) => draft.stockTotal), [1000, 1000]);
  });

  test('leaves columns the file does not have as null', () {
    const minimal = CsvTable(
      header: ['NAMA', 'STOK'],
      rows: [
        ['Kursi', '5'],
      ],
    );

    final plan = importer.plan(table: minimal);

    expect(plan.drafts.single.noUrut, isNull);
    expect(plan.drafts.single.code, isNull);
    expect(plan.drafts.single.brand, isNull);
    expect(plan.drafts.single.status, isNull);
  });

  test('reports a row without a name instead of importing it', () {
    const missingName = CsvTable(
      header: ['NAMA ALAT UKUR', 'STOK'],
      rows: [
        ['', '5'],
        ['Kursi', '5'],
      ],
    );

    final plan = importer.plan(table: missingName);

    expect(plan.drafts.length, 1);
    expect(plan.drafts.single.name, 'Kursi');
    expect(plan.issues.single.rowNumber, 1);
    expect(plan.issues.single.message, contains('Nama alat ukur'));
  });

  test('reports a stock value that is not a whole number', () {
    const badStock = CsvTable(
      header: ['NAMA ALAT UKUR', 'STOK'],
      rows: [
        ['Kursi', 'lima'],
        ['Meja', '-2'],
      ],
    );

    final plan = importer.plan(table: badStock);

    expect(plan.drafts, isEmpty);
    expect(plan.issues.length, 2);
    expect(plan.issues.first.rowNumber, 1);
    expect(plan.issues.last.rowNumber, 2);
  });

  test('treats a short row as empty trailing columns', () {
    const shortRow = CsvTable(
      header: ['NAMA ALAT UKUR', 'KODE ALAT UKUR', 'STOK'],
      rows: [
        ['Kursi', 'K-1'],
      ],
    );

    final plan = importer.plan(table: shortRow);

    expect(plan.issues.single.message, contains('Stok total'));
  });

  test('skips a row whose cells all read blank', () {
    const withGap = CsvTable(
      header: ['NAMA ALAT UKUR', 'STOK'],
      rows: [
        ['Kursi', '5'],
        ['', ''],
        ['Meja', '2'],
      ],
    );

    final plan = importer.plan(table: withGap);

    expect(plan.drafts.map((draft) => draft.name), ['Kursi', 'Meja']);
    expect(plan.issues, isEmpty);
  });

  test('refuses a table without the name column', () {
    const noName = CsvTable(
      header: ['KODE ALAT UKUR', 'BRAND'],
      rows: [
        ['RAB/01', 'Mitutoyo'],
      ],
    );

    expect(
      () => importer.plan(table: noName, stockPerRow: 1),
      throwsA(isA<ValidationException>()),
    );
  });

  test('refuses when there is no stock column and no stock per row', () {
    expect(
      () => importer.plan(table: table),
      throwsA(
        isA<ValidationException>().having(
          (error) => error.message,
          'message',
          contains('Stok tiap baris'),
        ),
      ),
    );
  });

  test('a draft becomes an item whose availability equals its total', () {
    final item = importer.plan(table: table, stockPerRow: 3).drafts.first.toItem();

    expect(item.stockTotal, 3);
    expect(item.stockAvailable, 3);
    expect(item.borrowed, 0);
    expect(item.code, 'RAB/01/01');
    expect(item.brand, 'Mitutoyo');
  });
}
