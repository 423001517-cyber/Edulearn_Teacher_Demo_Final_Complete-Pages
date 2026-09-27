/// Parses a class roster CSV for "Import CSV".
///
/// Accepted shapes (header row optional, any order when a header is given):
///   name,studentNumber
///   Maria Santos,0001
///   "Dela Cruz, Juan",0002
/// or just one name per line. Missing numbers are filled in from
/// [firstNumber] upward, skipping numbers already used.
class RosterParse {
  const RosterParse(this.rows, this.errors);

  final List<({String name, String number})> rows;
  final List<String> errors;
}

RosterParse parseRosterCsv(String text, {int firstNumber = 1, Set<String> takenNumbers = const {}}) {
  final lines = text
      .replaceAll('\uFEFF', '')
      .split(RegExp(r'\r\n|\n|\r'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final rows = <({String name, String number})>[];
  final errors = <String>[];
  if (lines.isEmpty) return RosterParse(rows, ['The file is empty.']);

  var nameCol = 0;
  var numberCol = 1;
  var start = 0;
  final header = splitCsvLine(lines.first).map((h) => h.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')).toList();
  if (header.any((h) => h.contains('name'))) {
    nameCol = header.indexWhere((h) => h.contains('name'));
    numberCol = header.indexWhere((h) => h.contains('number') || h == 'no' || h == 'lrn' || h == 'id');
    start = 1;
  }

  final used = {...takenNumbers};
  var next = firstNumber;
  String nextFree() {
    while (used.contains(_pad(next))) {
      next++;
    }
    return _pad(next++);
  }

  for (var i = start; i < lines.length; i++) {
    final cells = splitCsvLine(lines[i]);
    final name = nameCol < cells.length ? cells[nameCol].trim() : '';
    if (name.isEmpty) {
      errors.add('Line ${i + 1}: missing name — skipped.');
      continue;
    }
    if (name.length > 100) {
      errors.add('Line ${i + 1}: name is too long — skipped.');
      continue;
    }
    var number = numberCol >= 0 && numberCol < cells.length ? cells[numberCol].trim() : '';
    if (number.isNotEmpty && RegExp(r'^\d+$').hasMatch(number)) number = _pad(int.parse(number));
    if (number.isEmpty || used.contains(number)) {
      if (number.isNotEmpty) errors.add('Line ${i + 1}: number $number is already used — assigned a new one.');
      number = nextFree();
    }
    used.add(number);
    rows.add((name: name, number: number));
  }
  return RosterParse(rows, errors);
}

String _pad(int n) => '$n'.padLeft(4, '0');

/// Splits one CSV line, honoring "quoted, values" and "" escapes.
List<String> splitCsvLine(String line) {
  final out = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',' || ch == ';' || ch == '\t') {
      out.add(cell.toString());
      cell.clear();
    } else {
      cell.write(ch);
    }
  }
  out.add(cell.toString());
  return out;
}
