import 'package:flutter/material.dart';

import '../../core/board.dart';

/// How pieces are drawn on the board.
class PieceTheme {
  const PieceTheme._(this.id, this.name, this._builder);

  final String id;
  final String name;
  final Widget Function(BuildContext context, BoardPiece piece, double size)
      _builder;

  Widget build(BuildContext context, BoardPiece piece, double size) =>
      _builder(context, piece, size);

  /// The bundled PNG set (12 images) — crisp at every density.
  static const PieceTheme classic = PieceTheme._(
    'classic',
    'Classic',
    _buildAsset,
  );

  /// Unicode chess glyphs — no assets, works anywhere the system font ships
  /// the chess block.
  static const PieceTheme glyph = PieceTheme._(
    'glyph',
    'Glyph',
    _buildGlyph,
  );

  static const List<PieceTheme> all = [classic, glyph];

  static PieceTheme byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return classic;
  }

  static Widget _buildAsset(
    BuildContext context,
    BoardPiece piece,
    double size,
  ) {
    final color = piece.isWhite ? 'w' : 'b';
    final letter = piece.type.fenLetter;
    return Image.asset(
      'assets/images/chess/pieces/$color$letter.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
  }

  static Widget _buildGlyph(
    BuildContext context,
    BoardPiece piece,
    double size,
  ) {
    // Filled chess symbols for both colours; colour comes from the text paint
    // so both remain legible on any square palette.
    final glyph = piece.type.glyph;
    // White pieces are drawn as outlines in a warm ivory; black pieces are
    // near-black. A soft shadow keeps both readable on any square colour.
    final color = piece.isWhite ? const Color(0xFFFFFBF0) : const Color(0xFF1D1D22);
    return Text(
      glyph,
      style: TextStyle(
        fontSize: size * 0.86,
        height: 1.0,
        color: color,
        shadows: const [
          Shadow(
            blurRadius: 2,
            offset: Offset(0.6, 1.0),
            color: Color(0x66000000),
          ),
        ],
      ),
      textScaler: TextScaler.noScaling,
    );
  }
}
