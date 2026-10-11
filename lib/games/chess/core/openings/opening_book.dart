import 'opening_book_data.dart';

/// Splits a raw book entry into family/variation parts.
extension OpeningLineDataMatch on OpeningLineData {
  OpeningMatch toMatch() {
    final i = name.indexOf(': ');
    return OpeningMatch(
      name: name,
      eco: eco,
      family: i < 0 ? name : name.substring(0, i),
      variation: i < 0 ? null : name.substring(i + 2),
    );
  }
}

/// An identified opening: its ECO code plus the published name, split into
/// family and variation for display/grouping.
class OpeningMatch {
  const OpeningMatch({
    required this.name,
    required this.eco,
    required this.family,
    this.variation,
  });

  /// Full published name, e.g. "Sicilian Defense: Najdorf Variation".
  final String name;

  /// ECO code, e.g. "B90".
  final String eco;

  /// Opening family, e.g. "Sicilian Defense".
  final String family;

  /// Everything after the colon, e.g. "Najdorf Variation, English Attack".
  final String? variation;

  /// Human-readable label used in the UI (same as [name]).
  String get displayName => name;

  bool get hasVariation => variation != null && variation!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is OpeningMatch && other.eco == eco && other.name == name;

  @override
  int get hashCode => Object.hash(eco, name);

  @override
  String toString() => '$name ($eco)';
}

/// A raw book line, exposed for tests and the opening explorer.
class OpeningLine {
  const OpeningLine({
    required this.moves,
    required this.name,
    required this.eco,
    this.family,
    this.variation,
  });

  final List<String> moves;
  final String name;
  final String eco;
  final String? family;
  final String? variation;
}

/// Static ECO book: identifies the opening being played by matching the SAN
/// move sequence against published lines (longest prefix wins).
class OpeningBook {
  OpeningBook._();

  /// Number of lines loaded.
  static int get entryCount => kOpeningLines.length;

  /// Longest line in the book (ply count) — bounds the search.
  static int get maxLineLength => _maxLength;

  static final int _maxLength = () {
    var best = 0;
    for (final line in kOpeningLines) {
      if (line.moves.length > best) best = line.moves.length;
    }
    return best;
  }();

  /// Index of every line keyed by its normalised SAN sequence.
  static final Map<String, OpeningMatch> _index = () {
    final map = <String, OpeningMatch>{};
    for (final line in kOpeningLines) {
      map.putIfAbsent(line.moves.join(' '), () => line.toMatch());
    }
    return map;
  }();

  static final List<OpeningLine> _lines = List.unmodifiable([
    for (final line in kOpeningLines)
      OpeningLine(
        moves: List.unmodifiable(line.moves),
        name: line.name,
        eco: line.eco,
        family: _split(line.name).$1,
        variation: _split(line.name).$2,
      ),
  ]);

  /// All book lines (unmodifiable, built once).
  static List<OpeningLine> get lines => _lines;

  static (String, String?) _split(String name) {
    final i = name.indexOf(': ');
    if (i < 0) return (name, null);
    return (name.substring(0, i), name.substring(i + 2));
  }

  /// Identifies the opening for [sanMoves] (the SAN moves played so far, in
  /// order from the start of the game).
  ///
  /// Returns the longest book line that is a prefix of the played moves, or
  /// `null` when the game has left the book or nothing has been played.
  static OpeningMatch? identify(List<String>? sanMoves) {
    if (sanMoves == null || sanMoves.isEmpty) return null;
    final limit =
        sanMoves.length < maxLineLength ? sanMoves.length : maxLineLength;
    if (limit == 0) return null;

    // Look up each prefix, longest first.
    final normalized = <String>[];
    for (var i = 0; i < limit; i++) {
      normalized.add(_normalizeSan(sanMoves[i]));
    }
    for (var len = limit; len >= 1; len--) {
      final match = _index[normalized.sublist(0, len).join(' ')];
      if (match != null) return match;
    }
    return null;
  }

  static String _normalizeSan(String san) => san
      .replaceAll('0-0-0', 'O-O-O')
      .replaceAll('0-0', 'O-O')
      .replaceAll(RegExp(r'[+#!?]+$'), '')
      .replaceAll('e.p.', '')
      .trim();
}
