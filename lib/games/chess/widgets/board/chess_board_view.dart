import 'package:flutter/material.dart';

import '../../core/board.dart';
import '../../services/settings_service.dart';
import 'board_themes.dart';
import 'piece_theme.dart';

/// Interactive chess board: click-to-move and drag-and-drop, highlights,
/// piece animation, promotion picker, flip, and coordinates.
///
/// The board is deliberately "dumb": it renders state it is given and reports
/// intents (taps, drops, promotion choices) upward. The live game controller,
/// the analysis board and puzzle trainer all reuse this one widget.
class ChessBoardView extends StatefulWidget {
  const ChessBoardView({
    super.key,
    required this.pieces,
    this.orientationWhite = true,
    this.selectedSquare,
    this.legalTargets = const [],
    this.lastMoveFrom,
    this.lastMoveTo,
    this.checkSquare,
    this.extraHighlights = const {},
    this.movableSquares = const {},
    this.interactive = true,
    this.showCoordinates = true,
    this.showLegalDots = true,
    this.showLastMove = true,
    this.boardThemeId,
    this.pieceThemeId,
    this.animationDuration = const Duration(milliseconds: 170),
    this.pendingPromotion,
    this.onPromotionSelected,
    this.onPromotionCancelled,
    this.onTapSquare,
    this.onMoveAttempt,
    this.borderRadius = 6,
  });

  /// Pieces to render (row 0 = rank 8 in list order is irrelevant; each piece
  /// carries its own square).
  final List<BoardPiece> pieces;

  /// True when White is at the bottom.
  final bool orientationWhite;

  final String? selectedSquare;

  /// Destination squares legal for the selected piece (may repeat for
  /// promotions — the board dedupes for indicators).
  final List<String> legalTargets;

  final String? lastMoveFrom;
  final String? lastMoveTo;
  final String? checkSquare;

  /// Extra tinted squares (analysis best-move, puzzle hints, blunder marks).
  final Map<String, Color> extraHighlights;

  /// Squares whose pieces may be picked up (empty = drag disabled).
  final Set<String> movableSquares;

  final bool interactive;
  final bool showCoordinates;
  final bool showLegalDots;
  final bool showLastMove;
  final String? boardThemeId;
  final String? pieceThemeId;
  final Duration animationDuration;

  /// Set while waiting for the player to choose a promotion piece.
  final (String, String)? pendingPromotion;
  final ValueChanged<String>? onPromotionSelected;
  final VoidCallback? onPromotionCancelled;

  final ValueChanged<String>? onTapSquare;

  /// Called when a piece is dropped on another square (drag path).
  final void Function(String from, String to)? onMoveAttempt;

  final double borderRadius;

  @override
  State<ChessBoardView> createState() => _ChessBoardViewState();
}

class _ChessBoardViewState extends State<ChessBoardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flightController;

  /// Slide animation for the piece that just moved.
  ({BoardPiece piece, String from, String to})? _flight;

  // Active drag.
  String? _dragFrom;
  Offset? _dragPosition;
  BoardPiece? _dragPiece;

  @override
  void initState() {
    super.initState();
    _flightController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _flight = null);
        }
      });
  }

  @override
  void didUpdateWidget(covariant ChessBoardView old) {
    super.didUpdateWidget(old);
    final newTo = widget.lastMoveTo;
    final changed = newTo != null &&
        (newTo != old.lastMoveTo || widget.lastMoveFrom != old.lastMoveFrom);
    if (changed && widget.animationDuration > Duration.zero) {
      BoardPiece? moved;
      for (final p in widget.pieces) {
        if (p.square == newTo) {
          moved = p;
          break;
        }
      }
      if (moved != null) {
        setState(() {
          _flight = (
            piece: moved!,
            from: widget.lastMoveFrom ?? newTo,
            to: newTo,
          );
        });
        _flightController
          ..duration = widget.animationDuration
          ..forward(from: 0);
        return;
      }
    }
    if (_flight != null && !_flightController.isAnimating) {
      _flight = null;
    }
  }

  @override
  void dispose() {
    _flightController.dispose();
    super.dispose();
  }

  BoardTheme get _boardTheme =>
      BoardTheme.byId(widget.boardThemeId ?? ChessSettingsService.instance.settings.boardThemeId);

  PieceTheme get _pieceTheme =>
      PieceTheme.byId(widget.pieceThemeId ?? ChessSettingsService.instance.settings.pieceThemeId);

  // ------------------------------------------------------------ coordinates --

  int _displayCol(int gridCol) =>
      widget.orientationWhite ? gridCol : 7 - gridCol;

  int _displayRow(int gridRow) =>
      widget.orientationWhite ? gridRow : 7 - gridRow;

  int _gridCol(int displayCol) =>
      widget.orientationWhite ? displayCol : 7 - displayCol;

  int _gridRow(int displayRow) =>
      widget.orientationWhite ? displayRow : 7 - displayRow;

  String? _squareAt(Offset local, double cell) {
    final dc = (local.dx / cell).floor();
    final dr = (local.dy / cell).floor();
    if (dc < 0 || dc > 7 || dr < 0 || dr > 7) return null;
    return Squares.at(_gridRow(dr), _gridCol(dc));
  }

  // ------------------------------------------------------------------ drag --

  /// Pointer-down position: pan callbacks only fire after the pointer has
  /// travelled past the touch slop, so the origin square has to be captured
  /// on the way down.
  Offset? _downPosition;

  bool _dragMovable = false;

  void _handlePanDown(DragDownDetails details) {
    _downPosition = details.localPosition;
    _dragPosition = details.localPosition;
  }

  void _handlePanStart(DragStartDetails details, Size boardSize) {
    if (!widget.interactive) {
      _resetDrag();
      return;
    }
    final cell = boardSize.width / 8;
    final origin = _downPosition ?? details.localPosition;
    final square = _squareAt(origin, cell);
    if (square == null) {
      _resetDrag();
      return;
    }
    BoardPiece? piece;
    for (final p in widget.pieces) {
      if (p.square == square) {
        piece = p;
        break;
      }
    }
    if (piece == null) {
      _resetDrag();
      return;
    }
    setState(() {
      _dragFrom = square;
      _dragPiece = piece;
      _dragPosition = details.localPosition;
      _dragMovable = widget.movableSquares.contains(square);
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_dragFrom == null) return;
    setState(() => _dragPosition = details.localPosition);
  }

  void _handlePanEnd(DragEndDetails details, Size boardSize) {
    final from = _dragFrom;
    final local = _dragPosition;
    final movable = _dragMovable;
    _resetDrag();
    if (from == null || local == null) return;

    if (!movable) {
      // Dragging a piece that may not move behaves like a tap (select/clear).
      widget.onTapSquare?.call(from);
      return;
    }

    final cell = boardSize.width / 8;
    final to = _squareAt(local, cell);
    if (to == null || to == from) {
      // Released in place: behave like a tap (select).
      widget.onTapSquare?.call(from);
      return;
    }
    widget.onMoveAttempt?.call(from, to);
  }

  void _resetDrag() {
    _downPosition = null;
    _dragMovable = false;
    if (_dragFrom == null && _dragPosition == null && _dragPiece == null) {
      return;
    }
    setState(() {
      _dragFrom = null;
      _dragPiece = null;
      _dragPosition = null;
      _dragMovable = false;
    });
  }

  // ----------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    final theme = _boardTheme;
    final pieceTheme = _pieceTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide.isFinite
            ? constraints.biggest.shortestSide
            : constraints.maxWidth;
        if (side <= 0) {
          return const SizedBox.shrink();
        }
        final cell = side / 8;

        return SizedBox.square(
          dimension: side,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.interactive
                  ? (details) {
                      final sq = _squareAt(details.localPosition, cell);
                      if (sq != null) widget.onTapSquare?.call(sq);
                    }
                  : null,
              onPanDown: widget.interactive ? _handlePanDown : null,
              onPanStart: widget.interactive
                  ? (d) => _handlePanStart(d, Size.square(side))
                  : null,
              onPanUpdate: widget.interactive ? _handlePanUpdate : null,
              onPanEnd: widget.interactive
                  ? (d) => _handlePanEnd(d, Size.square(side))
                  : null,
              child: AnimatedBuilder(
                animation: _flightController,
                builder: (context, _) => _buildBoard(context, theme, pieceTheme, side, cell),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoard(
    BuildContext context,
    BoardTheme theme,
    PieceTheme pieceTheme,
    double side,
    double cell,
  ) {
    final pieceBySquare = <String, BoardPiece>{};
    for (final p in widget.pieces) {
      pieceBySquare[p.square] = p;
    }

    final children = <Widget>[];

    // 1. Squares.
    for (var gridRow = 0; gridRow < 8; gridRow++) {
      for (var gridCol = 0; gridCol < 8; gridCol++) {
        final square = Squares.at(gridRow, gridCol);
        final isLight = Squares.isLight(square);
        final dx = _displayCol(gridCol) * cell;
        final dy = _displayRow(gridRow) * cell;
        children.add(Positioned(
          left: dx,
          top: dy,
          width: cell,
          height: cell,
          child: ColoredBox(color: theme.squareColor(isLight)),
        ));
      }
    }

    // 2. Highlight layer (below pieces).
    void tint(String square, Color color) {
      final piece = _squarePos(square, cell);
      if (piece == null) return;
      children.add(Positioned(
        left: piece.$1,
        top: piece.$2,
        width: cell,
        height: cell,
        child: ColoredBox(color: color),
      ));
    }

    if (widget.showLastMove) {
      if (widget.lastMoveFrom != null) tint(widget.lastMoveFrom!, theme.lastMoveColor);
      if (widget.lastMoveTo != null) tint(widget.lastMoveTo!, theme.lastMoveColor);
    }
    for (final entry in widget.extraHighlights.entries) {
      tint(entry.key, entry.value);
    }
    if (widget.selectedSquare != null) {
      tint(widget.selectedSquare!, theme.selectedColor);
    }
    if (widget.checkSquare != null) {
      tint(widget.checkSquare!, theme.checkColor);
    }

    // 3. Legal-move indicators.
    if (widget.showLegalDots && widget.interactive) {
      final seen = <String>{};
      for (final target in widget.legalTargets) {
        if (!seen.add(target)) continue;
        final pos = _squarePos(target, cell);
        if (pos == null) continue;
        final occupant = pieceBySquare[target];
        final isCapture = occupant != null;
        children.add(Positioned(
          left: pos.$1,
          top: pos.$2,
          width: cell,
          height: cell,
          child: Center(
            child: isCapture
                ? Container(
                    width: cell * 0.86,
                    height: cell * 0.86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.legalMoveColor,
                        width: cell * 0.07,
                      ),
                    ),
                  )
                : Container(
                    width: cell * 0.26,
                    height: cell * 0.26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.legalMoveColor,
                    ),
                  ),
          ),
        ));
      }
    }

    // 4. Pieces.
    final flightTo = _flight?.to;
    for (final entry in pieceBySquare.entries) {
      if (entry.key == flightTo) continue; // rendered as the flying piece
      if (_dragMovable && entry.key == _dragFrom) {
        continue; // rendered under the pointer
      }
      final pos = _squarePos(entry.key, cell);
      if (pos == null) continue;
      children.add(_pieceAt(pieceTheme, entry.value, pos.$1, pos.$2, cell));
    }

    // 5. Flying piece (smooth slide from origin to destination).
    final flight = _flight;
    if (flight != null) {
      final from = _squarePos(flight.from, cell);
      final to = _squarePos(flight.to, cell);
      if (from != null && to != null) {
        final t = Curves.easeOutCubic.transform(
          _flightController.isAnimating ? _flightController.value : 1.0,
        );
        final x = from.$1 + (to.$1 - from.$1) * t;
        final y = from.$2 + (to.$2 - from.$2) * t;
        children.add(_pieceAt(pieceTheme, flight.piece, x, y, cell,
            lifted: _flightController.isAnimating));
      }
    }

    // 6. Dragged piece following the pointer.
    final dragPiece = _dragPiece;
    final dragPos = _dragPosition;
    if (_dragMovable && dragPiece != null && dragPos != null) {
      children.add(Positioned(
        left: dragPos.dx - cell / 2,
        top: dragPos.dy - cell / 2,
        width: cell,
        height: cell,
        child: IgnorePointer(
          child: Transform.scale(
            scale: 1.08,
            child: Opacity(
              opacity: 0.95,
              child: pieceTheme.build(context, dragPiece, cell * 0.92),
            ),
          ),
        ),
      ));
    }

    // 7. Coordinates.
    if (widget.showCoordinates) {
      children.addAll(_coordinateLabels(cell));
    }

    // 8. Promotion picker overlay.
    final promotion = widget.pendingPromotion;
    if (promotion != null) {
      children.add(_buildPromotionOverlay(context, promotion, cell, pieceTheme));
    }

    return Stack(children: children);
  }

  (double, double)? _squarePos(String square, double cell) {
    if (!Squares.isValid(square)) return null;
    final gridRow = Squares.rowOf(square);
    final gridCol = Squares.colOf(square);
    return (_displayCol(gridCol) * cell, _displayRow(gridRow) * cell);
  }

  Widget _pieceAt(
    PieceTheme theme,
    BoardPiece piece,
    double x,
    double y,
    double cell, {
    bool lifted = false,
  }) {
    return Positioned(
      left: x,
      top: y,
      width: cell,
      height: cell,
      child: IgnorePointer(
        child: lifted
            ? Transform.scale(scale: 1.05, child: _centered(theme, piece, cell))
            : _centered(theme, piece, cell),
      ),
    );
  }

  Widget _centered(PieceTheme theme, BoardPiece piece, double cell) {
    return Center(
      child: SizedBox(
        width: cell * 0.92,
        height: cell * 0.92,
        child: FittedBox(
          fit: BoxFit.contain,
          child: theme.build(context, piece, cell * 0.92),
        ),
      ),
    );
  }

  List<Widget> _coordinateLabels(double cell) {
    final theme = _boardTheme;
    final labels = <Widget>[];
    final style = TextStyle(
      fontSize: (cell * 0.24).clamp(7.0, 15.0),
      fontWeight: FontWeight.w700,
      color: theme.coordinateColor,
      height: 1.0,
    );

    for (var displayCol = 0; displayCol < 8; displayCol++) {
      final file = Squares.files[_gridCol(displayCol)];
      labels.add(Positioned(
        left: displayCol * cell,
        top: 7 * cell + cell * 0.74,
        width: cell,
        child: Center(child: Text(file, style: style)),
      ));
    }
    for (var displayRow = 0; displayRow < 8; displayRow++) {
      final rank = 8 - _gridRow(displayRow);
      labels.add(Positioned(
        left: cell * 0.10,
        top: displayRow * cell + cell * 0.04,
        width: cell * 0.5,
        child: Text('$rank', style: style),
      ));
    }
    return labels;
  }

  Widget _buildPromotionOverlay(
    BuildContext context,
    (String, String) promotion,
    double cell,
    PieceTheme pieceTheme,
  ) {
    final (from, to) = promotion;
    BoardPiece? mover;
    for (final p in widget.pieces) {
      if (p.square == from) {
        mover = p;
        break;
      }
    }
    final isWhite = mover?.isWhite ?? true;
    final choices = ['q', 'r', 'b', 'n'];

    // Place the picker over the promotion rank so it reads naturally.
    final targetRow = Squares.rowOf(to);
    final displayRow = _displayRow(targetRow);
    final top = displayRow <= 3 ? displayRow * cell : (displayRow - 3) * cell;

    return Positioned(
      left: 0,
      right: 0,
      top: top.clamp(0.0, cell * 4),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xF014161C),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 18),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose promotion',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 0.6,
                      ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final letter in choices)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          key: ValueKey('promotion_$letter'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => widget.onPromotionSelected?.call(letter),
                          child: SizedBox(
                            width: cell * 0.92,
                            height: cell * 0.92,
                            child: Center(
                              child: SizedBox(
                                width: cell * 0.8,
                                height: cell * 0.8,
                                child: FittedBox(
                                  child: pieceTheme.build(
                                    context,
                                    BoardPiece(
                                      type: _typeFor(letter),
                                      isWhite: isWhite,
                                      square: to,
                                    ),
                                    cell * 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                TextButton(
                  key: const ValueKey('promotion_cancel'),
                  onPressed: widget.onPromotionCancelled,
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PieceType _typeFor(String letter) {
    switch (letter) {
      case 'q':
        return PieceType.queen;
      case 'r':
        return PieceType.rook;
      case 'b':
        return PieceType.bishop;
      default:
        return PieceType.knight;
    }
  }
}
