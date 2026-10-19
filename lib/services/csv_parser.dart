import '../core/exceptions.dart';

/// A parsed CSV file: one header row plus the data rows after it.
class CsvTable {
  const CsvTable({
    required this.header,
    required this.rows,
    this.rowNumbers = const [],
  });

  final List<String> header;
  final List<List<String>> rows;

  /// 1-based line in the source file for each entry in [rows].
  ///
  /// A quoted cell may span several lines, so this is the line where the
  /// record starts. Empty when the caller built the table itself; [rowNumberAt]
  /// then falls back to the position among the data rows.
  final List<int> rowNumbers;

  int get columnCount => header.length;

  int rowNumberAt(int index) =>
      index < rowNumbers.length ? rowNumbers[index] : index + 1;
}

/// Reads CSV text into rows.
///
/// The delimiter is detected from the first line, because a file exported from
/// Indonesian Excel usually uses `;` while most other tools use `,`. Quoted
/// cells, doubled quotes, embedded line breaks, a leading BOM, and CRLF line
/// endings are all handled, since those are the things that quietly corrupt an
/// import instead of failing loudly.
///
/// A quote that is never closed, or text after a closing quote, is refused:
/// both mean the file does not say what it appears to say.
CsvTable parseCsv(String source, {bool firstRowIsHeader = true}) {
  final text = source.startsWith('\uFEFF') ? source.substring(1) : source;
  if (text.trim().isEmpty) {
    throw const CsvException('File CSV kosong.');
  }

  final delimiter = _detectDelimiter(_firstLogicalLine(text));
  final parsed = _tokenize(text, delimiter);
  final rows = <List<String>>[];
  final rowNumbers = <int>[];
  for (var i = 0; i < parsed.rows.length; i++) {
    if (parsed.rows[i].any((cell) => cell.trim().isNotEmpty)) {
      rows.add(parsed.rows[i]);
      rowNumbers.add(parsed.lines[i]);
    }
  }
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
      rowNumbers: rowNumbers,
    );
  }

  final header = <String>[
    for (var i = 0; i < rows.first.length; i++)
      rows.first[i].trim().isEmpty ? 'Kolom ${i + 1}' : rows.first[i].trim(),
  ];
  return CsvTable(
    header: header,
    rows: rows.sublist(1),
    rowNumbers: rowNumbers.sublist(1),
  );
}

/// `""` inside a quoted cell is a literal quote, so the escape has to be read
/// before the closing quote, not after it.
///
/// The parser remembers the physical line each record starts on, so an error
/// can point at the line the admin sees in Excel rather than at the position
/// among the surviving data rows.
({List<List<String>> rows, List<int> lines}) _tokenize(
  String source,
  String delimiter,
) {
  final rows = <List<String>>[];
  final lines = <int>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  var closedQuote = false;
  var rowStarted = false;
  var line = 1;
  var rowStartLine = 1;
  var quoteStartLine = 1;

  void endCell() {
    row.add(cell.toString());
    cell.clear();
    closedQuote = false;
  }

  void endRow() {
    endCell();
    rows.add(row);
    lines.add(rowStartLine);
    row = <String>[];
    rowStarted = false;
  }

  for (var i = 0; i < source.length; i++) {
    final char = source[i];

    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < source.length && source[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
          closedQuote = true;
        }
        continue;
      }
      if (char == '\n') {
        line++;
      }
      cell.write(char);
      continue;
    }

    if (char == '"') {
      if (closedQuote) {
        throw CsvException(
          'Ada teks setelah kutipan penutup di baris $line. '
          'Periksa kembali tanda kutip pada file.',
        );
      }
      if (!rowStarted || cell.toString().trim().isEmpty) {
        // A quote only opens a quoted cell at the start of that cell. A quote
        // in the middle of unquoted text stays a literal character.
        inQuotes = true;
        quoteStartLine = line;
        rowStarted = true;
        continue;
      }
    }

    if (char == delimiter) {
      endCell();
      rowStarted = true;
    } else if (char == '\r') {
      if (i + 1 < source.length && source[i + 1] == '\n') {
        i++;
      }
      endRow();
      line++;
      rowStartLine = line;
    } else if (char == '\n') {
      endRow();
      line++;
      rowStartLine = line;
    } else {
      if (closedQuote && char.trim().isNotEmpty) {
        throw CsvException(
          'Ada teks setelah kutipan penutup di baris $line. '
          'Periksa kembali tanda kutip pada file.',
        );
      }
      cell.write(char);
      rowStarted = true;
    }
  }

  if (inQuotes) {
    throw CsvException(
      'Kutipan yang dimulai di baris $quoteStartLine tidak ditutup. '
      'Periksa kembali tanda kutip pada file.',
    );
  }

  // A trailing newline has already closed the last row, so only close the row
  // when the file did not end with one.
  if (rowStarted || cell.isNotEmpty || row.isNotEmpty) {
    endRow();
  }
  return (rows: rows, lines: lines);
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
