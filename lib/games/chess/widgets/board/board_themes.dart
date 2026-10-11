import 'package:flutter/material.dart';

/// A board colour scheme: square colours plus all interaction highlights.
///
/// Palettes are original (drawn for BLUFF), not lifted from any other chess
/// product.
class BoardTheme {
  const BoardTheme({
    required this.id,
    required this.name,
    required this.lightSquare,
    required this.darkSquare,
    this.selected,
    this.lastMove,
    this.legalMove,
    this.check,
    this.hint,
    this.coordinate,
  });

  final String id;
  final String name;
  final Color lightSquare;
  final Color darkSquare;

  /// Tint for the selected square (defaults to a translucent accent).
  final Color? selected;

  /// Tint for the from/to squares of the previous move.
  final Color? lastMove;

  /// Colour of legal-move dots and capture rings.
  final Color? legalMove;

  /// Tint under a king in check.
  final Color? check;

  /// Analysis highlights (best move / blunder marks).
  final Color? hint;

  /// Coordinate label colour.
  final Color? coordinate;

  Color squareColor(bool isLight) => isLight ? lightSquare : darkSquare;

  Color get selectedColor => selected ?? const Color(0x66F2C94C);

  Color get lastMoveColor => lastMove ?? const Color(0x4DF2C94C);

  Color get legalMoveColor => legalMove ?? const Color(0xCC1B5E20);

  Color get checkColor => check ?? const Color(0x99E53935);

  Color get hintColor => hint ?? const Color(0x552196F3);

  Color get coordinateColor => coordinate ?? darkSquare.withValues(alpha: 0.75);

  /// All themes offered in Settings → Board.
  static const List<BoardTheme> all = [
    BoardTheme(
      id: 'slate',
      name: 'Slate',
      lightSquare: Color(0xFFDCE3EA),
      darkSquare: Color(0xFF6C8199),
      selected: Color(0x662E7D6E),
      lastMove: Color(0x4D2E7D6E),
      legalMove: Color(0xCC245B63),
      coordinate: Color(0xFF44576B),
    ),
    BoardTheme(
      id: 'forest',
      name: 'Forest',
      lightSquare: Color(0xFFE4E8D4),
      darkSquare: Color(0xFF5F7A52),
      selected: Color(0x66E0A800),
      lastMove: Color(0x4DE0A800),
      legalMove: Color(0xCC2E5B2A),
      coordinate: Color(0xFF3D4F35),
    ),
    BoardTheme(
      id: 'midnight',
      name: 'Midnight',
      lightSquare: Color(0xFF9AA7B8),
      darkSquare: Color(0xFF3B4657),
      selected: Color(0x66F0B429),
      lastMove: Color(0x4DF0B429),
      legalMove: Color(0xE6E0F0B4),
      check: Color(0x99EF5350),
      coordinate: Color(0xFFD7DEE8),
    ),
    BoardTheme(
      id: 'sand',
      name: 'Sand',
      lightSquare: Color(0xFFF0E3CC),
      darkSquare: Color(0xFFB98C5A),
      selected: Color(0x662A7B8C),
      lastMove: Color(0x4D2A7B8C),
      legalMove: Color(0xCC1F5F6B),
      coordinate: Color(0xFF6E4E2E),
    ),
    BoardTheme(
      id: 'rose',
      name: 'Rose',
      lightSquare: Color(0xFFF4E1E6),
      darkSquare: Color(0xFFB3677C),
      selected: Color(0x665B3C86),
      lastMove: Color(0x4D5B3C86),
      legalMove: Color(0xCC5B3C86),
      coordinate: Color(0xFF6E3A49),
    ),
    BoardTheme(
      id: 'ivory',
      name: 'Ivory',
      lightSquare: Color(0xFFF7F3E8),
      darkSquare: Color(0xFFC9A227),
      selected: Color(0x663D6B8C),
      lastMove: Color(0x4D3D6B8C),
      legalMove: Color(0xCC2C4F6B),
      coordinate: Color(0xFF6B5410),
    ),
    BoardTheme(
      id: 'berry',
      name: 'Berry',
      lightSquare: Color(0xFFEADFF2),
      darkSquare: Color(0xFF7C5295),
      selected: Color(0x662196F3),
      lastMove: Color(0x4D2196F3),
      legalMove: Color(0xCC3A1D5E),
      coordinate: Color(0xFF43285C),
    ),
    BoardTheme(
      id: 'graphite',
      name: 'Graphite',
      lightSquare: Color(0xFFB9BEC6),
      darkSquare: Color(0xFF4C525B),
      selected: Color(0x66FFD166),
      lastMove: Color(0x4DFFD166),
      legalMove: Color(0xE6FFD166),
      check: Color(0x99E53935),
      coordinate: Color(0xFFE4E7EB),
    ),
  ];

  static BoardTheme byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }
}
