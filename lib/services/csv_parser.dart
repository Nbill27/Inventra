import '../core/exceptions.dart';

/// A parsed CSV file: one header row plus the data rows after it.
class CsvTable {
  const CsvTable({required this.header, required this.rows});

  final List<String> header;
  final List<List<String>> rows;

  int get columnCount => header.length;
}

/// Reads CSV text into rows.
///
/// The delimiter is detected from the first line, because a file exported from
/// Indonesian Excel usually uses `;` while most other tools use `,`. Quoted
/// cells, doubled quotes, embedded line breaks, a leading BOM, and CRLF line
/// endings are all handled, since those are the things that quietly corrupt an
/// import instead of failing loudly.
CsvTable parseCsv(String source, {bool firstRowIsHeader = true}) {
  final text = source.startsWith('\uFEFF') ? source.substring(1) : source;
  if (text.trim().isEmpty) {
    throw const CsvException('File CSV kosong.');
  }

  final delimiter = _detectDelimiter(_firstLogicalLine(text));
  final rows = _tokenize(text, delimiter)
      .where((row) => row.any((cell) => cell.trim().isNotEmpty))
      .toList();
  if (rows.isEmpty) {
    throw const CsvException('File CSV tidak berisi baris data.');
  }

  if (!firstRowIsHeader) {
    final width = rows.fold<int>(0, (widest, row) {
      return row.length > widest ? row.length : widest;
    });
    return CsvTable(
      header: [for (var i = 0; i < width; i++) 'Kolom ${i + 1}'],
      rows: rows,
    );
  }

  final header = <String>[
    for (var i = 0; i < rows.first.length; i++)
      rows.first[i].trim().isEmpty ? 'Kolom ${i + 1}' : rows.first[i].trim(),
  ];
  return CsvTable(header: header, rows: rows.sublist(1));
}

/// `""` inside a quoted cell is a literal quote, so the escape has to be read
/// before the closing quote, not after it.
List<List<String>> _tokenize(String source, String delimiter) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;

  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < source.length; i++) {
    final char = source[i];

    if (inQuotes) {
      if (char != '"') {
        cell.write(char);
        continue;
      }
      if (i + 1 < source.length && source[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        inQuotes = false;
      }
      continue;
    }

    if (char == '"') {
      inQuotes = true;
    } else if (char == delimiter) {
      endCell();
    } else if (char == '\r') {
      if (i + 1 < source.length && source[i + 1] == '\n') {
        i++;
      }
      endRow();
    } else if (char == '\n') {
      endRow();
    } else {
      cell.write(char);
    }
  }

  // A trailing newline has already closed the last row, so only close the row
  // when the file did not end with one.
  if (cell.isNotEmpty || row.isNotEmpty) {
    endRow();
  }
  return rows;
}

/// The first line outside quotes, used so a delimiter inside a quoted value
/// cannot decide how the rest of the file is read.
String _firstLogicalLine(String source) {
  var inQuotes = false;
  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (!inQuotes && (char == '\n' || char == '\r')) {
      return source.substring(0, i);
    }
  }
  return source;
}

/// Picks whichever candidate delimiter appears most often outside quotes.
String _detectDelimiter(String line) {
  const candidates = [',', ';', '\t', '|'];
  final counts = {for (final candidate in candidates) candidate: 0};

  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (!inQuotes && counts.containsKey(char)) {
      counts[char] = counts[char]! + 1;
    }
  }

  var best = ',';
  var bestCount = 0;
  counts.forEach((candidate, count) {
    if (count > bestCount) {
      best = candidate;
      bestCount = count;
    }
  });
  return best;
}
