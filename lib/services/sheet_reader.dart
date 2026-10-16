import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../core/exceptions.dart';

/// One worksheet read into plain text, so nothing above this layer has to know
/// about workbooks, cell types, or styles.
///
/// Row and column indexes are kept exactly as Excel reports them, so a header
/// found on row 5 stays on row 5.
class RawSheet {
  const RawSheet({required this.name, required this.grid});

  final String name;
  final List<List<String>> grid;

  bool get isEmpty => grid.every((row) => row.every((cell) => cell.isEmpty));
}

/// Reads every worksheet of an `.xlsx` file.
///
/// Only cell text survives: the mentor's file carries images, a merged title
/// block, and formatting, none of which an import can use.
List<RawSheet> readWorkbook(Uint8List bytes) {
  final Excel workbook;
  try {
    workbook = Excel.decodeBytes(bytes);
  } catch (error) {
    throw const StorageException(
      'Berkas Excel tidak bisa dibaca. Pastikan filenya .xlsx dan tidak rusak.',
    );
  }

  final List<RawSheet> sheets;
  try {
    sheets = [
      for (final sheet in workbook.tables.values)
        RawSheet(
          name: sheet.sheetName,
          grid: [
            for (final row in sheet.rows)
              [for (final cell in row) _text(cell?.value)],
          ],
        ),
    ];
  } catch (error) {
    throw const StorageException('Isi berkas Excel tidak bisa dibaca.');
  }

  if (sheets.isEmpty || sheets.every((sheet) => sheet.isEmpty)) {
    throw const StorageException('Berkas Excel tidak berisi data.');
  }
  return sheets;
}

/// Spreadsheets are zip archives, and the old `.xls` format is not one, so the
/// bytes decide which reader a file needs. A renamed file still opens.
bool looksLikeXlsx(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x50 &&
    bytes[1] == 0x4B &&
    bytes[2] == 0x03 &&
    bytes[3] == 0x04;

/// The pre-2007 `.xls` format is an OLE2 container, which is refused with its
/// own message rather than read as text and reported as a broken table.
bool looksLikeOldExcel(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0xD0 &&
    bytes[1] == 0xCF &&
    bytes[2] == 0x11 &&
    bytes[3] == 0xE0;

/// Excel keeps a whole number as a double, so a stock of 12 would otherwise
/// read as `12.0` and be rejected by the integer stock check.
String _text(CellValue? value) {
  switch (value) {
    case null:
      return '';
    case TextCellValue():
      return value.value.toString().trim();
    case IntCellValue():
      return value.value.toString();
    case DoubleCellValue():
      final number = value.value;
      if (!number.isFinite) {
        return '';
      }
      if (number == number.roundToDouble() && number.abs() < 1e15) {
        return number.toInt().toString();
      }
      return number.toString();
    default:
      return value.toString().trim();
  }
}
