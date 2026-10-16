import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../core/dates.dart';
import '../models/loan.dart';
import '../models/loan_detail.dart';

/// Formats a loan history can be exported to.
enum LoanExportFormat {
  excel('xlsx', 'Excel (.xlsx)'),
  csv('csv', 'CSV');

  const LoanExportFormat(this.extension, this.label);

  final String extension;
  final String label;
}

/// Turns the loan history into a file the admin can keep or send on.
///
/// The rows mirror what the list shows, so an export is a faithful copy of the
/// screen — including the "Terlambat" label, which is derived at export time.
class LoanExportService {
  const LoanExportService();

  static const List<String> _header = [
    'No',
    'Nama peminjam',
    'Kontak',
    'Barang',
    'Kode barang',
    'Jumlah',
    'Tanggal pinjam',
    'Rencana kembali',
    'Dikembalikan',
    'Status',
    'Catatan',
  ];

  /// Header plus one row per loan, in the order they are shown on screen.
  List<List<String>> rows(List<LoanDetail> loans, {DateTime? today}) {
    final now = today ?? DateTime.now();
    return [
      _header,
      for (var i = 0; i < loans.length; i++) _row(loans[i], i + 1, now),
    ];
  }

  List<String> _row(LoanDetail detail, int number, DateTime today) {
    final loan = detail.loan;
    return [
      '$number',
      loan.borrowerName,
      loan.contact ?? '',
      detail.item.name,
      detail.item.code ?? '',
      '${loan.quantity}',
      formatDate(loan.loanDate),
      formatDate(loan.dueDate),
      loan.returnDate == null ? '' : formatDate(loan.returnDate!),
      statusLabel(loan, today),
      loan.note ?? '',
    ];
  }

  /// The same labels the list chip shows, so the file reads like the screen.
  static String statusLabel(Loan loan, DateTime today) => switch (loan.status) {
        LoanStatus.returned => 'Selesai',
        LoanStatus.borrowed => loan.isLateOn(today) ? 'Terlambat' : 'Dipinjam',
      };

  /// Encodes the history in the background, since building a workbook or a long
  /// CSV is pure CPU work that would otherwise stall the UI.
  Future<Uint8List> build({
    required List<LoanDetail> loans,
    required LoanExportFormat format,
    DateTime? today,
  }) {
    final data = rows(loans, today: today);
    return Isolate.run(
      () => format == LoanExportFormat.excel ? _excel(data) : _csv(data),
    );
  }

  /// Opens the system save dialog and writes [bytes] where the admin chooses.
  /// Returns false when the dialog was dismissed.
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required LoanExportFormat format,
  }) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      dialogTitle: 'Simpan riwayat peminjaman',
      mimeType: switch (format) {
        LoanExportFormat.excel =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        LoanExportFormat.csv => 'text/csv',
      },
    );
    return uri != null;
  }

  static Uint8List _excel(List<List<String>> rows) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Riwayat Peminjaman');
    final sheet = excel['Riwayat Peminjaman'];
    for (final row in rows) {
      sheet.appendRow([for (final cell in row) TextCellValue(cell)]);
    }
    return Uint8List.fromList(excel.encode() ?? const []);
  }

  /// `;` as the separator, because that is what Indonesian Excel expects. The
  /// UTF-8 BOM makes Excel read accented characters correctly.
  static Uint8List _csv(List<List<String>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer
        ..write(row.map(_csvCell).join(';'))
        ..write('\r\n');
    }
    return Uint8List.fromList(utf8.encode('\uFEFF$buffer'));
  }

  /// Quotes a cell only when it would otherwise break the row apart.
  static String _csvCell(String value) {
    if (!value.contains(RegExp(r'[;"\r\n]'))) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }
}
