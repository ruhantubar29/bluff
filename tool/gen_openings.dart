// Generates lib/games/chess/core/openings/opening_book_data.dart from the
// lichess-org/chess-openings dataset (CC0 1.0, public domain).
//
// Usage:
//   dart run tool/gen_openings.dart <path-to-tsv-dir> [maxPly]
//
// Every line is replayed through the rules library during generation, so the
// emitted book can only ever contain legal sequences.

import 'dart:io';

import 'package:chess/chess.dart';

const _outPath = 'lib/games/chess/core/openings/opening_book_data.dart';

void main(List<String> args) {
  final dir = args.isNotEmpty ? args[0] : '';
  final maxPly = args.length > 1 ? int.parse(args[1]) : 16;
  if (dir.isEmpty || !Directory(dir).existsSync()) {
    stderr.writeln('usage: dart run tool/gen_openings.dart <tsv-dir> [maxPly]');
    exit(64);
  }

  final entries = <_Entry>[];
  final rejected = <String>[];
  final seenLines = <String>{};

  for (final letter in ['a', 'b', 'c', 'd', 'e']) {
    final file = File('$dir/$letter.tsv');
    if (!file.existsSync()) {
      stderr.writeln('missing ${file.path}');
      exit(66);
    }
    final lines = file.readAsLinesSync();
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      final parts = line.split('\t');
      if (parts.length < 3) continue;
      final eco = parts[0].trim();
      final name = parts[1].trim();
      final pgn = parts[2].trim();
      if (eco.isEmpty || name.isEmpty || pgn.isEmpty) continue;
      if (pgn.contains('...')) {
        rejected.add('black-to-move pgn: $name');
        continue;
      }

      final sans = _pgnToSan(pgn);
      if (sans.isEmpty) {
        rejected.add('no moves: $name');
        continue;
      }
      if (sans.length > maxPly) continue;

      final key = sans.join(' ');
      if (!seenLines.add(key)) {
        rejected.add('duplicate line: $name');
        continue;
      }

      final replayed = _replay(sans);
      if (replayed == null) {
        rejected.add('illegal: $name ($key)');
        continue;
      }

      entries.add(_Entry(eco: eco, name: name, sans: replayed));
    }
  }

  entries.sort((a, b) {
    final byEco = a.eco.compareTo(b.eco);
    if (byEco != 0) return byEco;
    return a.sans.length.compareTo(b.sans.length);
  });

  final buf = StringBuffer();
  buf.writeln('// GENERATED FILE — do not edit by hand.');
  buf.writeln('//');
  buf.writeln('// Source: lichess-org/chess-openings (CC0 1.0 Universal, public');
  buf.writeln('// domain). Regenerate with:');
  buf.writeln('//   dart run tool/gen_openings.dart <tsv-dir> $maxPly');
  buf.writeln('//');
  buf.writeln('// Every line below was replayed through the rules library during');
  buf.writeln('// generation, so all sequences are legal. SAN suffixes (+, #) are');
  buf.writeln('// stripped; matching normalises both sides the same way.');
  buf.writeln();
  buf.writeln('/// One book line: ECO code, opening name and its SAN moves.');
  buf.writeln('class OpeningLineData {');
  buf.writeln('  const OpeningLineData(this.eco, this.name, this.moves);');
  buf.writeln();
  buf.writeln('  final String eco;');
  buf.writeln('  final String name;');
  buf.writeln('  final List<String> moves;');
  buf.writeln('}');
  buf.writeln();
  buf.writeln('/// The ECO opening book. `OpeningBook.identify` picks the longest');
  buf.writeln('/// line that is a prefix of the moves played.');
  buf.writeln('const List<OpeningLineData> kOpeningLines = [');
  for (final e in entries) {
    final sans = e.sans.map(_quote).join(', ');
    buf.writeln('  OpeningLineData(${_quote(e.eco)}, ${_quote(e.name)}, '
        '[$sans]),');
  }
  buf.writeln('];');

  final out = File(_outPath);
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(buf.toString());

  stdout.writeln('wrote ${out.path}: ${entries.length} lines '
      '(maxPly=$maxPly), ${rejected.length} rejected');
  final illegal = rejected.where((r) => r.startsWith('illegal')).toList();
  stdout.writeln('  illegal: ${illegal.length}');
  for (final r in illegal.take(15)) {
    stdout.writeln('    $r');
  }
  stdout.writeln(
      '  duplicates: ${rejected.where((r) => r.startsWith('duplicate')).length}');
  stdout.writeln('  other: ${rejected.where((r) => !r.startsWith('illegal') && !r.startsWith('duplicate')).length}');
}

class _Entry {
  _Entry({required this.eco, required this.name, required this.sans});
  final String eco;
  final String name;
  final List<String> sans;
}

List<String> _pgnToSan(String pgn) {
  final out = <String>[];
  for (final token in pgn.split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    if (RegExp(r'^\d+\.+$').hasMatch(token)) continue; // "1." / "12..."
    if (token == '*' || RegExp(r'^\d+-\d+$').hasMatch(token)) continue;
    out.add(token);
  }
  return out;
}

String _normalize(String san) => san
    .replaceAll('0-0-0', 'O-O-O')
    .replaceAll('0-0', 'O-O')
    .replaceAll(RegExp(r'[+#!?]+$'), '')
    .replaceAll('e.p.', '')
    .trim();

/// Replays [sans] and returns the SAN tokens as the engine spells them, or
/// null when a token is not a legal move in sequence.
List<String>? _replay(List<String> sans) {
  try {
    final game = Chess();
    final canonical = <String>[];
    for (final token in sans) {
      final wanted = _normalize(token);
      String? chosen;
      for (final raw in game.moves({'verbose': true})) {
        final m = raw as Map;
        final san = (m['san'] as String?) ?? '';
        if (_normalize(san) == wanted) {
          chosen = san;
          break;
        }
      }
      if (chosen == null) return null;
      if (!game.move(chosen)) return null;
      canonical.add(_normalize(chosen));
    }
    return canonical;
  } catch (_) {
    return null;
  }
}

String _quote(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');
  return "'$escaped'";
}
