import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peminjaman_barang/db/database_helper.dart';
import 'package:peminjaman_barang/models/item.dart';
import 'package:peminjaman_barang/providers/item_provider.dart';
import 'package:peminjaman_barang/repositories/item_repository.dart';
import 'package:peminjaman_barang/screens/item_import_screen.dart';
import 'package:provider/provider.dart';

import 'support/test_database.dart';

/// Builds real `.xlsx` bytes, so the screen is driven through the same reader
/// the phone uses.
Uint8List workbookBytes(List<List<CellValue?>> rows) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  for (final row in rows) {
    sheet.appendRow(row);
  }
  return Uint8List.fromList(excel.encode()!);
}

/// A workbook shaped like the mentor's: a title block, the header on row 5, two
/// blocks side by side, and a signature row under a blank row.
Uint8List mentorWorkbook() => workbookBytes([
      [TextCellValue('DAFTAR ALAT UKUR QC')],
      [],
      [
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('Periode'),
      ],
      [],
      [
        TextCellValue('NO'),
        TextCellValue('FOTO'),
        TextCellValue('NAMA ALAT UKUR'),
        TextCellValue('KODE ALAT UKUR'),
        TextCellValue('RANGE'),
        TextCellValue('BRAND'),
        TextCellValue('PIC'),
        TextCellValue('STATUS'),
        TextCellValue(''),
        TextCellValue('NO'),
        TextCellValue('FOTO'),
        TextCellValue('NAMA ALAT UKUR'),
        TextCellValue('KODE ALAT UKUR'),
        TextCellValue('RANGE'),
        TextCellValue('BRAND'),
        TextCellValue('PIC'),
        TextCellValue('STATUS'),
      ],
      [
        TextCellValue('1'),
        TextCellValue(''),
        TextCellValue('Digital Caliper'),
        TextCellValue('RAB/01/01'),
        TextCellValue('300 mm'),
        TextCellValue('Mitutoyo'),
        TextCellValue('QC'),
        TextCellValue('OK'),
        TextCellValue(''),
        TextCellValue('1'),
        TextCellValue(''),
        TextCellValue('Bevel Protector'),
        TextCellValue('RAB/02/001'),
        TextCellValue('180O'),
        TextCellValue('Mitutoyo'),
        TextCellValue('QC'),
        TextCellValue('OK'),
      ],
      [
        TextCellValue('2'),
        TextCellValue(''),
        TextCellValue('Jangka Sorong'),
        TextCellValue('RAB/01/02'),
        TextCellValue('150 mm'),
        TextCellValue('Insize'),
        TextCellValue('QC'),
        TextCellValue('OK'),
        TextCellValue(''),
        TextCellValue('2'),
        TextCellValue(''),
        TextCellValue('Height Gauge'),
        TextCellValue('RAB/03/001'),
        TextCellValue('600 mm'),
        TextCellValue('Mitutoyo'),
        TextCellValue('QC'),
        TextCellValue('Not Good / Rusak'),
      ],
      [],
      [TextCellValue('Disetujui oleh')],
    ]);

void main() {
  late DatabaseHelper helper;
  late ItemRepository repository;
  late ItemProvider provider;

  setUp(() {
    helper = createTestDatabase();
    repository = ItemRepository(helper: helper);
    provider = ItemProvider(repository: repository);
  });

  tearDown(() => helper.close());

  Future<void> pumpScreen(
    WidgetTester tester,
    ImportFilePicker picker,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ItemProvider>.value(
        value: provider,
        child: MaterialApp(home: ItemImportScreen(picker: picker)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickFile(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> pressImport(WidgetTester tester, int rows) async {
    final button = find.text('Impor $rows barang');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('imports an xlsx whose header sits under a title block',
      (tester) async {
    await pumpScreen(
      tester,
      () async => PickedFile(fileName: 'alat.xlsx', bytes: mentorWorkbook()),
    );

    await pickFile(tester, 'Pilih file');

    expect(find.text('alat.xlsx'), findsOneWidget);
    expect(find.textContaining('4 baris data'), findsOneWidget);
    // Columns are recognised automatically, so the summary is all that shows.
    expect(find.text('Siap diimpor'), findsOneWidget);
    expect(find.text('Pengaturan lanjutan'), findsOneWidget);
    expect(find.text('Berhenti di baris kosong'), findsNothing);

    await pressImport(tester, 4);

    expect(find.text('Hasil impor'), findsOneWidget);
    expect(find.text('barang ditambahkan'), findsOneWidget);
    expect(find.text('Dilewati karena kode sudah ada'), findsOneWidget);

    final items = await repository.getAll();
    expect(
      items.map((item) => item.code),
      containsAll(['RAB/01/01', 'RAB/01/02', 'RAB/02/001', 'RAB/03/001']),
    );
    expect(items.map((item) => item.name), contains('Bevel Protector'));
    expect(items.map((item) => item.brand), contains('Mitutoyo'));
    // No stock column, so every row takes the typed stock (default 1).
    expect(items.every((item) => item.stockTotal == 1), isTrue);
    expect(items.every((item) => item.stockAvailable == 1), isTrue);
    // The signature row under the blank row never became an item.
    expect(items.map((item) => item.name), isNot(contains('Disetujui oleh')));
  });

  testWidgets('skips items whose code is already in the database',
      (tester) async {
    await repository.create(
      const Item(
        name: 'Digital Caliper',
        code: 'RAB/01/01',
        stockTotal: 3,
        stockAvailable: 3,
      ),
    );

    await pumpScreen(
      tester,
      () async => PickedFile(fileName: 'alat.xlsx', bytes: mentorWorkbook()),
    );
    await pickFile(tester, 'Pilih file');
    await pressImport(tester, 4);

    expect(find.text('Dilewati karena kode sudah ada'), findsOneWidget);
    expect(find.text('- Digital Caliper'), findsOneWidget);
  });

  testWidgets('reads stock from a stock column in a CSV file', (tester) async {
    final bytes = Uint8List.fromList(
      'NAMA ALAT UKUR;STOK\nProyektor;5\nKabel HDMI;2\n'.codeUnits,
    );

    await pumpScreen(
      tester,
      () async => PickedFile(fileName: 'barang.csv', bytes: bytes),
    );

    await pickFile(tester, 'Pilih file');

    expect(find.text('Siap diimpor'), findsOneWidget);
    // The stock column is present, so the "stok tiap barang" field stays hidden.
    expect(find.text('Stok tiap barang'), findsNothing);

    await pressImport(tester, 2);

    final items = await repository.getAll();
    expect(items.singleWhere((item) => item.name == 'Proyektor').stockTotal, 5);
    expect(
      items.singleWhere((item) => item.name == 'Kabel HDMI').stockTotal,
      2,
    );
  });

  testWidgets('takes the typed stock when the file has no stock column',
      (tester) async {
    await pumpScreen(
      tester,
      () async => PickedFile(fileName: 'alat.xlsx', bytes: mentorWorkbook()),
    );
    await pickFile(tester, 'Pilih file');

    // The mentor file has no stock column, so the field is offered.
    await tester.enterText(find.byType(TextField), '4');
    await tester.pumpAndSettle();

    expect(find.text('Siap diimpor'), findsOneWidget);
    await pressImport(tester, 4);

    final items = await repository.getAll();
    expect(items.every((item) => item.stockTotal == 4), isTrue);
  });

  testWidgets('opens the settings when the name column is missing',
      (tester) async {
    final bytes = Uint8List.fromList('KODE;BRAND\nRAB/01;Mitutoyo\n'.codeUnits);

    await pumpScreen(
      tester,
      () async => PickedFile(fileName: 'lain.csv', bytes: bytes),
    );
    await pickFile(tester, 'Pilih file');

    expect(find.textContaining('Belum bisa diimpor'), findsOneWidget);
    // Nothing to import, so no summary panel.
    expect(find.text('Siap diimpor'), findsNothing);
    // The settings open themselves so the header row can be fixed.
    expect(find.text('Kolom terdeteksi'), findsOneWidget);
  });

  testWidgets('explains that an old .xls file has to be saved as .xlsx',
      (tester) async {
    final bytes = Uint8List.fromList([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1]);

    await pumpScreen(
      tester,
      () async => PickedFile(fileName: 'alat.xls', bytes: bytes),
    );
    await pickFile(tester, 'Pilih file');

    expect(find.textContaining('Simpan ulang sebagai .xlsx'), findsOneWidget);
    // A failed pick leaves nothing half loaded.
    expect(find.text('alat.xls'), findsNothing);
    expect(find.text('Pilih file'), findsOneWidget);
  });

  testWidgets('stays put when the picker is dismissed', (tester) async {
    await pumpScreen(tester, () async => null);

    await pickFile(tester, 'Pilih file');

    expect(find.text('Pilih file'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });
}
