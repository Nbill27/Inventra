import 'package:flutter_test/flutter_test.dart';
import 'package:peminjaman_barang/core/exceptions.dart';
import 'package:peminjaman_barang/services/sheet_table.dart';

void main() {
  group('tableFromGrid', () {
    test('reads the table under a title block', () {
      const grid = [
        ['DAFTAR ALAT UKUR', ''],
        ['', ''],
        ['NO', 'NAMA', 'KODE'],
        ['1', 'Mikrometer', 'MIC-1'],
        ['2', 'Jangka Sorong', 'JS-2'],
      ];

      final table = tableFromGrid(grid, headerRow: 2);

      expect(table.header, ['NO', 'NAMA', 'KODE']);
      expect(table.rows, [
        ['1', 'Mikrometer', 'MIC-1'],
        ['2', 'Jangka Sorong', 'JS-2'],
      ]);
    });

    test('numbers the columns when the sheet has no header row', () {
      const grid = [
        ['Mikrometer', '5'],
        ['Jangka Sorong', '2'],
      ];

      final table = tableFromGrid(grid);

      expect(table.header, ['Kolom 1', 'Kolom 2']);
      expect(table.rows, [
        ['Mikrometer', '5'],
        ['Jangka Sorong', '2'],
      ]);
    });

    test('merges two side by side blocks that share the same column names', () {
      const grid = [
        ['NO', 'NAMA', 'KODE', '', 'NO', 'NAMA', 'KODE'],
        ['1', 'A', 'A-1', '', '1', 'C', 'C-1'],
        ['2', 'B', 'B-2', '', '2', 'D', 'D-2'],
      ];

      final table = tableFromGrid(grid, headerRow: 0);

      expect(table.header, ['NO', 'NAMA', 'KODE']);
      expect(table.rows, [
        ['1', 'A', 'A-1'],
        ['2', 'B', 'B-2'],
        ['1', 'C', 'C-1'],
        ['2', 'D', 'D-2'],
      ]);
    });

    test('keeps blocks with different column names as one table', () {
      const grid = [
        ['NO', 'NAMA', '', 'NO', 'JENIS', 'KODE'],
        ['1', 'A', '', '1', 'C', 'C-1'],
      ];

      final table = tableFromGrid(grid, headerRow: 0);

      expect(table.columnCount, 6);
      expect(table.header[3], 'NO (2)');
      expect(table.rows.single[4], 'C');
    });

    test('stops the table at the first blank row', () {
      const grid = [
        ['NAMA', 'STOK'],
        ['A', '1'],
        ['', ''],
        ['B', '2'],
      ];

      expect(tableFromGrid(grid, headerRow: 0).rows, [
        ['A', '1'],
      ]);
      expect(
        tableFromGrid(grid, headerRow: 0, stopAtBlank: false).rows,
        [
          ['A', '1'],
          ['B', '2'],
        ],
      );
    });

    test('skips a repeated header row inside the block body', () {
      const grid = [
        ['NO', 'NAMA', 'KODE', '', 'NO', 'NAMA', 'KODE'],
        ['1', 'A', 'A-1', '', '1', 'C', 'C-1'],
        ['NO', 'NAMA', 'KODE', '', 'NO', 'NAMA', 'KODE'],
        ['2', 'B', 'B-2', '', '2', 'D', 'D-2'],
      ];

      final table = tableFromGrid(grid, headerRow: 0);

      expect(table.rows.length, 4);
      expect(table.rows[1], ['2', 'B', 'B-2']);
      expect(table.rows[3], ['2', 'D', 'D-2']);
    });

    test('tells two columns with the same name apart', () {
      const grid = [
        ['NAMA', 'NAMA'],
        ['A', 'B'],
      ];

      final table = tableFromGrid(grid, headerRow: 0);

      expect(table.header, ['NAMA', 'NAMA (2)']);
    });

    test('names a blank header cell by its position', () {
      const grid = [
        ['NAMA', '', 'STOK'],
        ['A', 'x', '1'],
      ];

      final table = tableFromGrid(grid, headerRow: 0);

      expect(table.header[1], 'Kolom 2');
    });

    test('pads short rows to the table width', () {
      const grid = [
        ['NAMA', 'STOK', 'KODE'],
        ['A', '1'],
      ];

      final table = tableFromGrid(grid, headerRow: 0);

      expect(table.rows.single, ['A', '1', '']);
    });

    test('rejects a header row outside the sheet', () {
      const grid = [
        ['NAMA', 'STOK'],
        ['A', '1'],
      ];

      expect(
        () => tableFromGrid(grid, headerRow: 5),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects a sheet with no rows at all', () {
      expect(
        () => tableFromGrid(const []),
        throwsA(isA<StorageException>()),
      );
    });

    test('rejects a sheet with a header but no data rows', () {
      expect(
        () => tableFromGrid(const [
          ['NAMA', 'STOK'],
        ], headerRow: 0),
        throwsA(isA<CsvException>()),
      );
    });
  });

  group('suggestHeaderRow', () {
    test('finds the header under a merged title block', () {
      final grid = <List<String>>[
        ['DAFTAR ALAT UKUR QC', ...List.filled(15, '')],
        ['', ...List.filled(15, '')],
        ['', '', '', '', 'Periode', '', '', '', '', '', '', '', '', '', '', ''],
        ['', ...List.filled(15, '')],
        [
          'NO', 'FOTO', 'NAMA', 'KODE', 'RANGE', 'BRAND', 'PIC', 'STATUS',
          '', 'NO', 'FOTO', 'NAMA', 'KODE', 'RANGE', 'BRAND', 'PIC', 'STATUS',
        ],
        ['1', '', 'Mikrometer', 'MIC-1', '0-25', 'Mitutoyo', 'QC', 'OK'],
        ['2', '', 'Jangka Sorong', 'JS-2', '0-150', 'Mitutoyo', 'QC', 'OK'],
      ];

      expect(suggestHeaderRow(grid), 4);
    });

    test('ignores a first row that is mostly numbers', () {
      final grid = <List<String>>[
        ['1', '2', '3', '4'],
        ['NAMA', 'KODE', 'STOK', 'KATEGORI'],
        ['A', 'A-1', '1', 'Alat'],
      ];

      expect(suggestHeaderRow(grid), 1);
    });

    test('gives up on a sheet that is too narrow to be a table', () {
      expect(suggestHeaderRow(const [['Judul'], ['A']]), isNull);
    });
  });
}
