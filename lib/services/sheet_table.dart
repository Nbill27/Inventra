import '../core/exceptions.dart';
import 'csv_parser.dart';

/// Turns a worksheet grid into the same shape [parseCsv] produces, so the
/// importer only ever sees one kind of table.
///
/// [headerRow] is 0-based, or null when the sheet has no header row and the
/// columns are numbered instead. [stopAtBlank] ends a table at its first fully
/// blank row, which is how the mentor's file separates its table from the
/// signature rows underneath it.
CsvTable tableFromGrid(
  List<List<String>> grid, {
  int? headerRow,
  bool stopAtBlank = true,
}) {
  final rows = _rectangle(grid);
  if (rows.isEmpty) {
    throw const StorageException('Lembar ini tidak berisi data.');
  }

  if (headerRow == null) {
    return CsvTable(
      header: [for (var i = 0; i < rows.first.length; i++) 'Kolom ${i + 1}'],
      rows: _body(rows, rows.first.length, stopAtBlank),
    );
  }
  if (headerRow < 0 || headerRow >= rows.length) {
    throw const ValidationException('Baris judul berada di luar isi lembar.');
  }

  final runs = _labelRuns(rows[headerRow]);
  if (runs.length >= 2 && _sameLabels(rows[headerRow], runs)) {
    return _fromBlocks(rows, headerRow, runs, stopAtBlank);
  }

  final header = _labels(rows[headerRow]);
  final width = _widest(rows.sublist(headerRow + 1), header.length);
  return CsvTable(
    header: _pad(header, width),
    rows: _body(rows.sublist(headerRow + 1), width, stopAtBlank),
  );
}

/// Guesses which row holds the column names.
///
/// A header row is the first row that is nearly as wide as the widest row of
/// the sheet and is made of labels rather than numbers. The mentor's file puts
/// a merged title block above the table, so the answer there is row 5.
///
/// The guess is only a starting point: the caller shows it in a dropdown, so a
/// wrong answer costs one tap instead of a broken import.
int? suggestHeaderRow(List<List<String>> grid) {
  final limit = grid.length < 30 ? grid.length : 30;
  var widest = 0;
  for (var r = 0; r < limit; r++) {
    final filled = _filled(grid[r]).length;
    if (filled > widest) {
      widest = filled;
    }
  }
  if (widest < 3) {
    return null;
  }

  final threshold = (widest * 0.6).ceil();
  for (var r = 0; r < limit && r < grid.length - 1; r++) {
    final filled = _filled(grid[r]);
    if (filled.length < threshold) {
      continue;
    }
    final numbers = filled.where((cell) => double.tryParse(cell) != null).length;
    if (numbers * 3 > filled.length) {
      continue;
    }
    if (filled.any((cell) => cell.length > 60)) {
      continue;
    }
    return r;
  }
  return null;
}

/// A table laid out as two identical blocks side by side is read as one list:
/// the mentor's file keeps items 1-22 on the left and 23-40 on the right, which
/// is one table with one mapping.
CsvTable _fromBlocks(
  List<List<String>> rows,
  int headerRow,
  List<List<int>> runs,
  bool stopAtBlank,
) {
  final labels = [for (final column in runs.first) rows[headerRow][column]];
  final body = <List<String>>[];

  for (final run in runs) {
    var stopped = false;
    for (var r = headerRow + 1; r < rows.length && !stopped; r++) {
      final row = [for (final column in run) rows[r][column]];
      if (row.every((cell) => cell.isEmpty)) {
        stopped = stopAtBlank;
        continue;
      }
      if (_repeats(labels, row)) {
        continue;
      }
      body.add(row);
    }
  }

  if (body.isEmpty) {
    throw const CsvException('Tidak ada baris data di bawah baris judul.');
  }
  return CsvTable(header: _labels(labels), rows: body);
}

/// Drops blank rows, and cuts the table at the first blank row when asked.
List<List<String>> _body(
  List<List<String>> rows,
  int width,
  bool stopAtBlank,
) {
  final body = <List<String>>[];
  for (final row in rows) {
    if (row.every((cell) => cell.isEmpty)) {
      if (stopAtBlank) {
        break;
      }
      continue;
    }
    body.add(_pad(row, width));
  }
  if (body.isEmpty) {
    throw const CsvException('Tidak ada baris data di bawah baris judul.');
  }
  return body;
}

/// Trims the grid to the cells that carry something, and squares it off so
/// every row has the same width.
List<List<String>> _rectangle(List<List<String>> grid) {
  var lastRow = -1;
  var lastColumn = -1;
  final trimmed = <List<String>>[];

  for (var r = 0; r < grid.length; r++) {
    final row = [for (final cell in grid[r]) cell.trim()];
    trimmed.add(row);
    for (var c = 0; c < row.length; c++) {
      if (row[c].isEmpty) {
        continue;
      }
      if (r > lastRow) {
        lastRow = r;
      }
      if (c > lastColumn) {
        lastColumn = c;
      }
    }
  }

  if (lastRow < 0 || lastColumn < 0) {
    return const [];
  }
  return [
    for (var r = 0; r <= lastRow; r++)
      [for (var c = 0; c <= lastColumn; c++) c < trimmed[r].length ? trimmed[r][c] : ''],
  ];
}

/// Turns a header row into labels, numbering the columns that have no name.
List<String> _labels(List<String> header) {
  final used = <String, int>{};
  return [
    for (var i = 0; i < header.length; i++)
      _unique(header[i].isEmpty ? 'Kolom ${i + 1}' : header[i], used),
  ];
}

/// Two columns may legitimately share a name in the file, but the mapping
/// dropdown has to tell them apart.
String _unique(String label, Map<String, int> used) {
  final seen = used[label] ?? 0;
  used[label] = seen + 1;
  return seen == 0 ? label : '$label (${seen + 1})';
}

/// The column ranges of a header row: consecutive named columns, split wherever
/// the header has a gap. Two blocks side by side produce two ranges.
List<List<int>> _labelRuns(List<String> header) {
  final runs = <List<int>>[];
  var current = <int>[];
  for (var i = 0; i < header.length; i++) {
    if (header[i].isEmpty) {
      if (current.isNotEmpty) {
        runs.add(current);
        current = <int>[];
      }
      continue;
    }
    current.add(i);
  }
  if (current.isNotEmpty) {
    runs.add(current);
  }
  return runs;
}

/// Only blocks with the exact same column names are merged; anything else stays
/// one table, because guessing which block is which would silently mislabel
/// columns.
bool _sameLabels(List<String> header, List<List<int>> runs) {
  final first = [for (final column in runs.first) header[column]];
  for (final run in runs.skip(1)) {
    if (run.length != first.length) {
      return false;
    }
    for (var i = 0; i < run.length; i++) {
      if (header[run[i]] != first[i]) {
        return false;
      }
    }
  }
  return true;
}

bool _repeats(List<String> labels, List<String> row) {
  if (row.length != labels.length) {
    return false;
  }
  for (var i = 0; i < row.length; i++) {
    if (row[i].toLowerCase() != labels[i].trim().toLowerCase()) {
      return false;
    }
  }
  return true;
}

int _widest(List<List<String>> rows, int minimum) {
  var width = minimum;
  for (final row in rows) {
    if (row.length > width) {
      width = row.length;
    }
  }
  return width;
}

List<String> _pad(List<String> row, int width) => [
      for (var i = 0; i < width; i++) i < row.length ? row[i] : '',
    ];

List<String> _filled(List<String> row) =>
    [for (final cell in row) if (cell.trim().isNotEmpty) cell.trim()];
