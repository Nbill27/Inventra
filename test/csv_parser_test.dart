import 'package:flutter_test/flutter_test.dart';
import 'package:peminjaman_barang/core/exceptions.dart';
import 'package:peminjaman_barang/services/csv_parser.dart';

void main() {
  group('parseCsv', () {
    test('reads a comma separated file and treats the first row as header', () {
      final table = parseCsv('nama,kode,stok\nProyektor,PRJ-1,5\nKabel,KLB-2,2\n');

      expect(table.header, ['nama', 'kode', 'stok']);
      expect(table.rows, [
        ['Proyektor', 'PRJ-1', '5'],
        ['Kabel', 'KLB-2', '2'],
      ]);
    });

    test('reads a semicolon separated file, the usual Excel export here', () {
      final table = parseCsv('nama;kategori;stok\nProyektor;Elektronik;5\n');

      expect(table.header, ['nama', 'kategori', 'stok']);
      expect(table.rows.single, ['Proyektor', 'Elektronik', '5']);
    });

    test('keeps a delimiter inside a quoted cell', () {
      final table = parseCsv('nama,catatan\n"Proyektor, HDMI",aman\n');

      expect(table.rows.single.first, 'Proyektor, HDMI');
    });

    test('keeps a line break inside a quoted cell', () {
      final table = parseCsv('nama,catatan\n"Proyektor\nunit A",aman\n');

      expect(table.rows.length, 1);
      expect(table.rows.single.first, 'Proyektor\nunit A');
    });

    test('reads a doubled quote as one literal quote', () {
      final table = parseCsv('nama\n"Proyektor ""A"""\n');

      expect(table.rows.single.single, 'Proyektor "A"');
    });

    test('strips a leading BOM so the first column name is clean', () {
      final table = parseCsv('\uFEFFnama,stok\nProyektor,5\n');

      expect(table.header.first, 'nama');
    });

    test('handles CRLF line endings', () {
      final table = parseCsv('nama,stok\r\nProyektor,5\r\nKabel,2\r\n');

      expect(table.rows.length, 2);
      expect(table.rows.last.first, 'Kabel');
    });

    test('names columns when the first row is data instead of a header', () {
      final table = parseCsv('Proyektor,PRJ-1,5\n', firstRowIsHeader: false);

      expect(table.header, ['Kolom 1', 'Kolom 2', 'Kolom 3']);
      expect(table.rows.single.first, 'Proyektor');
    });

    test('fills a blank header cell with its position', () {
      final table = parseCsv('nama,,stok\nProyektor,PRJ-1,5\n');

      expect(table.header, ['nama', 'Kolom 2', 'stok']);
    });

    test('drops blank lines anywhere in the file', () {
      final table = parseCsv('nama,stok\nProyektor,5\n\n\nKabel,2\n\n');

      expect(table.rows.length, 2);
    });

    test('leaves cell whitespace for the importer to trim', () {
      final table = parseCsv('nama,stok\n  Proyektor  , 5 \n');

      expect(table.rows.single, ['  Proyektor  ', ' 5 ']);
    });

    test('rejects an empty file', () {
      expect(() => parseCsv('   \n'), throwsA(isA<CsvException>()));
    });

    test('rejects a file with no data rows at all', () {
      expect(() => parseCsv(''), throwsA(isA<CsvException>()));
    });
  });
}
