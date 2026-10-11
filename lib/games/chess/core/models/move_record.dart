/// A single move as recorded in game history.
class MoveRecord {
  const MoveRecord({
    required this.san,
    required this.from,
    required this.to,
    required this.fenAfter,
    required this.colorWasWhite,
    this.promotion,
    this.capturedPiece,
    this.isCapture = false,
    this.isCastle = false,
    this.isEnPassant = false,
    this.isCheck = false,
    this.isCheckmate = false,
    this.whiteMsLeft,
    this.blackMsLeft,
    this.sanBeforeSuffix,
  });

  /// Standard algebraic notation including +/# suffix, e.g. "Nf3", "Qxe5+".
  final String san;

  final String from;
  final String to;

  /// FEN of the position right after this move.
  final String fenAfter;

  /// Side that played the move.
  final bool colorWasWhite;

  /// Promotion piece letter ("q", "r", "b", "n") when applicable.
  final String? promotion;

  /// Piece type captured, if any (used for captured-piece display).
  final String? capturedPiece;

  final bool isCapture;
  final bool isCastle;
  final bool isEnPassant;
  final bool isCheck;
  final bool isCheckmate;

  /// Clock snapshot after the move (milliseconds), when clocks are in use.
  final int? whiteMsLeft;
  final int? blackMsLeft;

  /// SAN without check/mate suffix (used for repetition display fallback).
  final String? sanBeforeSuffix;

  /// UCI-style coordinate representation, e.g. "e2e4" / "e7e8q".
  String get uci => '$from$to${promotion ?? ''}';

  @override
  String toString() => san;
}
