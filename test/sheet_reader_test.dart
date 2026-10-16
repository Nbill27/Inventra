import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peminjaman_barang/core/exceptions.dart';
import 'package:peminjaman_barang/services/sheet_reader.dart';

/// Builds a real `.xlsx` in memory, so the reader is tested against the same
/// bytes the phone would hand it.
Uint8List workbookBytes(
  Map<String, List<List<CellValue?>>> sheets,
) {
  final excel = Excel.createExcel();
  for (final entry in sheets.entries) {
    final sheet = excel[entry.key];
    for (final row in entry.value) {
      sheet.appendRow(row);
    }
  }
  return Uint8List.fromList(excel.encode()!);
}

void main() {
  group('readWorkbook', () {
    test('reads cell text and turns whole numbers into plain digits', () {
      final bytes = workbookBytes({
        'Sheet1': [
          [TextCellValue('NAMA'), TextCellValue('STOK')],
          [TextCellValue('  Mikrometer  '), DoubleCellValue(12)],
          [TextCellValue('Jangka Sorong'), IntCellValue(5)],
        ],
      });

      final sheets = readWorkbook(bytes);

      expect(sheets.length, 1);
      expect(sheets.single.name, 'Sheet1');
      expect(sheets.single.grid[0], ['NAMA', 'STOK']);
      expect(sheets.single.grid[1], ['Mikrometer', '12']);
      expect(sheets.single.grid[2], ['Jangka Sorong', '5']);
    });

    test('keeps a blank cell beside filled ones as an empty string', () {
      final bytes = workbookBytes({
        'Sheet1': [
          [TextCellValue('NAMA'), null, TextCellValue('KODE')],
          [TextCellValue('Mikrometer'), null, TextCellValue('MIC-1')],
        ],
      });

      final sheets = readWorkbook(bytes);

      expect(sheets.single.grid[0], ['NAMA', '', 'KODE']);
      expect(sheets.single.grid[1], ['Mikrometer', '', 'MIC-1']);
    });

    test('reads every sheet of a multi sheet workbook', () {
      final bytes = workbookBytes({
        'Sheet1': [
          [TextCellValue('NAMA')],
          [TextCellValue('Mikrometer')],
        ],
        'Cadangan': [
          [TextCellValue('NAMA')],
          [TextCellValue('Jangka Sorong')],
        ],
      });

      final sheets = readWorkbook(bytes);

      expect(sheets.map((sheet) => sheet.name), containsAll(['Sheet1', 'Cadangan']));
    });

    test('rejects a workbook without any data', () {
      expect(
        () => readWorkbook(workbookBytes(const {'Sheet1': []})),
        throwsA(isA<StorageException>()),
      );
    });

    test('rejects bytes that are not a workbook at all', () {
      final garbage = Uint8List.fromList(List<int>.filled(64, 0x7A));

      expect(() => readWorkbook(garbage), throwsA(isA<StorageException>()));
    });
  });

  group('format sniffing', () {
    test('recognises the zip container a spreadsheet is stored in', () {
      final bytes = workbookBytes({
        'Sheet1': [
          [TextCellValue('NAMA')],
        ],
      });

      expect(looksLikeXlsx(bytes), isTrue);
      expect(looksLikeOldExcel(bytes), isFalse);
    });

    test('does not mistake plain CSV text for a spreadsheet', () {
      final bytes = Uint8List.fromList('NAMA;STOK\nMikrometer;5\n'.codeUnits);

      expect(looksLikeXlsx(bytes), isFalse);
      expect(looksLikeOldExcel(bytes), isFalse);
    });

    test('recognises the pre-2007 Excel container', () {
      final bytes = Uint8List.fromList([0xD0, 0xCF, 0x11, 0xE0, 0, 0]);

      expect(looksLikeOldExcel(bytes), isTrue);
      expect(looksLikeXlsx(bytes), isFalse);
    });
  });
}
