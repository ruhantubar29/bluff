/// Board primitives: squares, pieces, FEN parsing helpers.
///
/// Squares are expressed in algebraic notation ("a1".."h8") everywhere in
/// the app. The board is rendered as an 8x8 grid where row 0 is rank 8 and
/// column 0 is file a, so index = row * 8 + col.
library;

enum PieceType { pawn, knight, bishop, rook, queen, king }

extension PieceTypeLetter on PieceType {
  /// Lowercase FEN letter.
  String get fenLetter {
    switch (this) {
      case PieceType.pawn:
        return 'p';
      case PieceType.knight:
        return 'n';
      case PieceType.bishop:
        return 'b';
      case PieceType.rook:
        return 'r';
      case PieceType.queen:
        return 'q';
      case PieceType.king:
        return 'k';
    }
  }

  /// Display glyph for the "Glyph" piece theme (filled chess symbols).
  String get glyph {
    switch (this) {
      case PieceType.pawn:
        return '\u265F';
      case PieceType.knight:
        return '\u265E';
      case PieceType.bishop:
        return '\u265D';
      case PieceType.rook:
        return '\u265C';
      case PieceType.queen:
        return '\u265B';
      case PieceType.king:
        return '\u265A';
    }
  }

  /// Centipawn value used by the engine and captured-piece display.
  int get value {
    switch (this) {
      case PieceType.pawn:
        return 100;
      case PieceType.knight:
        return 320;
      case PieceType.bishop:
        return 330;
      case PieceType.rook:
        return 500;
      case PieceType.queen:
        return 900;
      case PieceType.king:
        return 0;
    }
  }
}

/// A piece sitting on a square.
class BoardPiece {
  const BoardPiece({
    required this.type,
    required this.isWhite,
    required this.square,
  });

  final PieceType type;
  final bool isWhite;

  /// Algebraic square, e.g. "e4".
  final String square;

  /// FEN letter with case encoding color ("P" for white pawn).
  String get fenChar => isWhite ? type.fenLetter.toUpperCase() : type.fenLetter;

  BoardPiece copyWith({PieceType? type, bool? isWhite, String? square}) {
    return BoardPiece(
      type: type ?? this.type,
      isWhite: isWhite ?? this.isWhite,
      square: square ?? this.square,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BoardPiece &&
      other.type == type &&
      other.isWhite == isWhite &&
      other.square == square;

  @override
  int get hashCode => Object.hash(type, isWhite, square);

  @override
  String toString() => '$fenChar@$square';
}

/// Helpers for converting between algebraic squares and grid indices.
class Squares {
  Squares._();

  static const List<String> files = [
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h',
  ];

  static bool isValid(String square) {
    if (square.length != 2) return false;
    final file = files.indexOf(square[0]);
    final rank = int.tryParse(square.substring(1));
    if (file < 0 || rank == null) return false;
    return rank >= 1 && rank <= 8;
  }

  /// Grid row (0 = rank 8) for an algebraic square.
  static int rowOf(String square) => 8 - int.parse(square[1]);

  /// Grid column (0 = file a) for an algebraic square.
  static int colOf(String square) => files.indexOf(square[0]);

  /// Grid index in 0..63 (row-major from a8).
  static int indexOf(String square) => rowOf(square) * 8 + colOf(square);

  /// Algebraic square for a grid index in 0..63.
  static String squareAt(int index) {
    final row = index ~/ 8;
    final col = index % 8;
    return '${files[col]}${8 - row}';
  }

  static String at(int row, int col) => '${files[col]}${8 - row}';

  /// "light" / "dark" square color, matching standard board orientation.
  static bool isLight(String square) =>
      (rowOf(square) + colOf(square)) % 2 == 0;

  static int distance(String a, String b) {
    final dr = (rowOf(a) - rowOf(b)).abs();
    final dc = (colOf(a) - colOf(b)).abs();
    return dr > dc ? dr : dc;
  }
}

/// Parses the piece-placement part of a FEN into [BoardPiece]s.
List<BoardPiece> piecesFromFen(String fen) {
  final placement = fen.split(' ').first;
  final pieces = <BoardPiece>[];
  var row = 0;
  var col = 0;
  for (final ch in placement.split('')) {
    if (ch == '/') {
      row++;
      col = 0;
      continue;
    }
    final skip = int.tryParse(ch);
    if (skip != null) {
      col += skip;
      continue;
    }
    final isWhite = ch == ch.toUpperCase();
    final letter = ch.toLowerCase();
    final type = pieceTypeFromLetter(letter);
    if (type != null) {
      pieces.add(
        BoardPiece(
          type: type,
          isWhite: isWhite,
          square: Squares.at(row, col),
        ),
      );
    }
    col++;
  }
  return pieces;
}

PieceType? pieceTypeFromLetter(String letter) {
  switch (letter) {
    case 'p':
      return PieceType.pawn;
    case 'n':
      return PieceType.knight;
    case 'b':
      return PieceType.bishop;
    case 'r':
      return PieceType.rook;
    case 'q':
      return PieceType.queen;
    case 'k':
      return PieceType.king;
    default:
      return null;
  }
}
