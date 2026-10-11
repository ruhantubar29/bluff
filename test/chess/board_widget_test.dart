import 'package:bluff/games/chess/core/board.dart';
import 'package:bluff/games/chess/widgets/board/chess_board_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const side = 400.0;
  const cell = side / 8;

  Widget wrap(ChessBoardView board) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: side,
              child: board,
            ),
          ),
        ),
      );

  List<BoardPiece> startingPieces() => piecesFromFen(
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      );

  /// Board-relative centre of [square] in global test coordinates.
  Offset squareCenter(
    WidgetTester tester,
    String square, {
    bool orientationWhite = true,
  }) {
    final origin = tester.getTopLeft(find.byType(ChessBoardView));
    final col = Squares.colOf(square);
    final row = Squares.rowOf(square);
    final dc = orientationWhite ? col : 7 - col;
    final dr = orientationWhite ? row : 7 - row;
    return origin + Offset((dc + 0.5) * cell, (dr + 0.5) * cell);
  }

  Finder boardColoredBoxes() => find.descendant(
        of: find.byType(ChessBoardView),
        matching: find.byType(ColoredBox),
      );

  group('ChessBoardView rendering', () {
    testWidgets('renders every piece of the starting position', (tester) async {
      await tester.pumpWidget(wrap(
        ChessBoardView(
          pieces: startingPieces(),
          pieceThemeId: 'glyph',
          boardThemeId: 'slate',
        ),
      ));

      expect(find.byType(Image), findsNothing); // glyph theme uses no assets
      expect(find.text('a'), findsOneWidget); // file label
      expect(find.text('8'), findsOneWidget); // rank label
      expect(find.text('♞'), findsNWidgets(4)); // both colours of knights
      expect(find.text('♚'), findsNWidgets(2)); // both kings share the glyph
    });

    testWidgets('hides coordinates when disabled', (tester) async {
      await tester.pumpWidget(wrap(
        ChessBoardView(
          pieces: startingPieces(),
          pieceThemeId: 'glyph',
          showCoordinates: false,
        ),
      ));
      expect(find.text('a'), findsNothing);
      expect(find.text('8'), findsNothing);
    });

    testWidgets('shows the selected square', (tester) async {
      await tester.pumpWidget(wrap(
        ChessBoardView(
          pieces: startingPieces(),
          pieceThemeId: 'glyph',
          selectedSquare: 'e2',
          legalTargets: const ['e3', 'e4'],
        ),
      ));
      // 64 squares + 1 selected-square tint (dots are not ColoredBox).
      expect(boardColoredBoxes(), findsNWidgets(65));
    });

    testWidgets('marks the king in check', (tester) async {
      await tester.pumpWidget(wrap(
        ChessBoardView(
          pieces: piecesFromFen('4k3/8/8/8/8/8/8/4K2r w - - 0 1'),
          pieceThemeId: 'glyph',
          checkSquare: 'e1',
        ),
      ));
      expect(boardColoredBoxes(), findsNWidgets(65));
    });
  });

  group('ChessBoardView interaction', () {
    testWidgets('tap reports the correct square (White at bottom)',
        (tester) async {
      String? tapped;
      await tester.pumpWidget(wrap(
        ChessBoardView(
          pieces: startingPieces(),
          pieceThemeId: 'glyph',
          onTapSquare: (sq) => tapped = sq,
        ),
      ));

      await tester.tapAt(squareCenter(tester, 'e4'));
      expect(tapped, 'e4');

      await tester.tapAt(squareCenter(tester, 'a1'));
      expect(tapped, 'a1');

      await tester.tapAt(squareCenter(tester, 'h8'));
      expect(tapped, 'h8');
    });

    testWidgets('tap reports the correct square (Black at bottom)',
        (tester) async {
      String? tapped;
      await tester.pumpWidget(wrap(
        ChessBoardView(
          pieces: startingPieces(),
          pieceThemeId: 'glyph',
          orientationWhite: false,
          onTapSquare: (sq) => tapped = sq,
        ),
      ));

      await tester.tapAt(
          squareCenter(tester, 'e4', orientationWhite: false));
      expect(tapped, 'e4');

      // With the board flipped, a1 sits in the top-right corner.
      await tester.tapAt(
          squareCenter(tester, 'a1', orientationWhite: false));
      expect(tapped, 'a1');
    });

    testWidgets('dragging a movable piece reports from → to', (tester) async {
      (String, String)? move;
      await tester.pumpWidget(wrap(
        ChessBoardView(
          pieces: startingPieces(),
          pieceThemeId: 'glyph',
          movableSquares: const {'e2'},
          onMoveAttempt: (from, to) => move = (from, to),
        ),
      ));

      final gesture = await tester.startGesture(squareCenter(tester, 'e2'));
      await gesture.moveBy(const Offset(0, 40)); // exceed touch slop
      await tester.pump();
      await gesture.moveTo(squareCenter(tester, 'e4'));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(move, ('e2', 'e4'));
    });

    testWidgets('dragging a non-movable square does nothing', (tester) async {
      (String, String)? move;
      String? tapped;
      await tester.pumpWidget(wrap(
        ChessBoardView(
          pieces: startingPieces(),
          pieceThemeId: 'glyph',
          movableSquares: const {'e2'},
          onMoveAttempt: (from, to) => move = (from, to),
          onTapSquare: (sq) => tapped = sq,
        ),
      ));

      final gesture = await tester.startGesture(squareCenter(tester, 'a7'));
      await gesture.moveBy(const Offset(0, 60));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(move, isNull);
      expect(tapped, 'a7');
    });

    testWidgets('dropping back on the origin acts like a tap', (tester) async {
      String? tapped;
      (String, String)? move;
      await tester.pumpWidget(wrap(
        ChessBoardView(
          pieces: startingPieces(),
          pieceThemeId: 'glyph',
          movableSquares: const {'g1'},
          onMoveAttempt: (from, to) => move = (from, to),
          onTapSquare: (sq) => tapped = sq,
        ),
      ));

      final origin = squareCenter(tester, 'g1');
      final gesture = await tester.startGesture(origin);
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesture.moveTo(origin + const Offset(4, 4));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(move, isNull);
      expect(tapped, 'g1');
    });

    testWidgets('drag is ignored when interaction is disabled',
        (tester) async {
      (String, String)? move;
      await tester.pumpWidget(wrap(
        ChessBoardView(
          pieces: startingPieces(),
          pieceThemeId: 'glyph',
          movableSquares: const {'e2'},
          interactive: false,
          onMoveAttempt: (from, to) => move = (from, to),
        ),
      ));

      final gesture = await tester.startGesture(squareCenter(tester, 'e2'));
      await gesture.moveTo(squareCenter(tester, 'e4'));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(move, isNull);
    });
  });

  group('ChessBoardView promotion', () {
    testWidgets('shows four pieces and reports the choice', (tester) async {
      String? chosen;
      await tester.pumpWidget(wrap(
        ChessBoardView(
          pieces: piecesFromFen('8/P6k/8/8/8/8/8/K7 w - - 0 1'),
          pieceThemeId: 'glyph',
          pendingPromotion: ('a7', 'a8'),
          onPromotionSelected: (p) => chosen = p,
        ),
      ));

      expect(find.byKey(const ValueKey('promotion_q')), findsOneWidget);
      expect(find.byKey(const ValueKey('promotion_r')), findsOneWidget);
      expect(find.byKey(const ValueKey('promotion_b')), findsOneWidget);
      expect(find.byKey(const ValueKey('promotion_n')), findsOneWidget);
      expect(find.text('Choose promotion'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('promotion_n')));
      expect(chosen, 'n');
    });

    testWidgets('cancel reports nothing', (tester) async {
      String? chosen;
      var cancelled = false;
      await tester.pumpWidget(wrap(
        ChessBoardView(
          pieces: piecesFromFen('8/P6k/8/8/8/8/8/K7 w - - 0 1'),
          pieceThemeId: 'glyph',
          pendingPromotion: ('a7', 'a8'),
          onPromotionSelected: (p) => chosen = p,
          onPromotionCancelled: () => cancelled = true,
        ),
      ));

      await tester.tap(find.byKey(const ValueKey('promotion_cancel')));
      expect(cancelled, isTrue);
      expect(chosen, isNull);
    });
  });

  group('ChessBoardView theming', () {
    testWidgets('square colours follow the selected board theme',
        (tester) async {
      await tester.pumpWidget(wrap(
        ChessBoardView(
          pieces: const [],
          pieceThemeId: 'glyph',
          boardThemeId: 'slate',
        ),
      ));
      final boxes = tester.widgetList<ColoredBox>(boardColoredBoxes());
      expect(boxes.length, 64);
      // a8 is a light square in the standard orientation.
      expect(boxes.first.color, const Color(0xFFDCE3EA));
    });

    testWidgets('flipping the board mirrors square positions', (tester) async {
      Widget build(bool whiteAtBottom) => wrap(
            ChessBoardView(
              pieces: const [],
              pieceThemeId: 'glyph',
              boardThemeId: 'slate',
              orientationWhite: whiteAtBottom,
            ),
          );

      Positioned firstSquare() {
        final squares = tester
            .widgetList<Positioned>(find.descendant(
              of: find.byType(ChessBoardView),
              matching: find.byType(Positioned),
            ))
            .where((p) => p.child is ColoredBox)
            .toList();
        return squares.first; // a8
      }

      await tester.pumpWidget(build(true));
      var square = firstSquare();
      expect(square.left, 0);
      expect(square.top, 0);

      await tester.pumpWidget(build(false));
      square = firstSquare();
      // Flipped: a8 sits in the bottom-right corner.
      expect(square.left, cell * 7);
      expect(square.top, cell * 7);
    });

    testWidgets('changing themes repaints the squares', (tester) async {
      await tester.pumpWidget(wrap(
        ChessBoardView(
          pieces: const [],
          pieceThemeId: 'glyph',
          boardThemeId: 'midnight',
        ),
      ));
      final boxes = tester.widgetList<ColoredBox>(boardColoredBoxes());
      expect(boxes.first.color, const Color(0xFF9AA7B8));
    });
  });
}
