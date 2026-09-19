import 'package:flutter/material.dart';

class ChessBoard extends StatelessWidget {
  final List<List<String>> board;

  final int? selectedRow;
  final int? selectedCol;

  final List<List<int>> validMoves;

  final bool Function(int row, int col) isValidMoveSquare;

  final bool Function(bool white) isKingInCheck;

  final void Function(int row, int col) onSquareTap;

  const ChessBoard({
    super.key,
    required this.board,
    required this.selectedRow,
    required this.selectedCol,
    required this.validMoves,
    required this.isValidMoveSquare,
    required this.isKingInCheck,
    required this.onSquareTap,
  });

  static const List<String> files = [
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
  ];

  static const List<String> ranks = [
    '8',
    '7',
    '6',
    '5',
    '4',
    '3',
    '2',
    '1',
  ];

  static const double coordinateSize = 20.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;

        // The actual chessboard is 8x8.
        // Coordinates need 20px on the left and 20px at the bottom.
        final boardSize = (maxWidth - coordinateSize)
            .clamp(
              0.0,
              maxHeight - coordinateSize,
            );

        final squareSize = boardSize / 8;

        final totalWidth =
            coordinateSize + boardSize;

        final totalHeight =
            boardSize + coordinateSize;

        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: totalWidth,
            height: totalHeight,
            child: Column(
              children: [
                // ==================================================
                // CHESS BOARD
                // ==================================================

                SizedBox(
                  width: totalWidth,
                  height: boardSize,
                  child: Row(
                    children: [
                      // --------------------------------------------
                      // RANK NUMBERS
                      // --------------------------------------------

                      SizedBox(
                        width: coordinateSize,
                        height: boardSize,
                        child: Column(
                          children: List.generate(
                            8,
                            (row) {
                              return SizedBox(
                                width: coordinateSize,
                                height: squareSize,
                                child: Center(
                                  child: Text(
                                    ranks[row],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.bold,
                                      color:
                                          _coordinateColor(
                                        row,
                                        0,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // --------------------------------------------
                      // 8x8 BOARD
                      // --------------------------------------------

                      SizedBox(
                        width: boardSize,
                        height: boardSize,
                        child: Column(
                          children: List.generate(
                            8,
                            (row) {
                              return Row(
                                children:
                                    List.generate(
                                  8,
                                  (col) {
                                    return _buildSquare(
                                      row,
                                      col,
                                      squareSize,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ==================================================
                // FILE LETTERS
                // ==================================================

                SizedBox(
                  width: totalWidth,
                  height: coordinateSize,
                  child: Row(
                    children: [
                      const SizedBox(
                        width: coordinateSize,
                      ),

                      ...List.generate(
                        8,
                        (col) {
                          return SizedBox(
                            width: squareSize,
                            height: coordinateSize,
                            child: Center(
                              child: Text(
                                files[col],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.bold,
                                  color:
                                      _coordinateColor(
                                    7,
                                    col,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==============================================================
  // COORDINATE COLOR
  // ==============================================================

  Color _coordinateColor(
    int row,
    int col,
  ) {
    final isLight =
        (row + col).isEven;

    return isLight
        ? const Color(0xffF0D9B5)
        : const Color(0xffB58863);
  }

  // ==============================================================
  // SQUARE
  // ==============================================================

  Widget _buildSquare(
    int row,
    int col,
    double squareSize,
  ) {
    final piece =
        board[row][col];

    final isLightSquare =
        (row + col).isEven;

    final isSelected =
        selectedRow == row &&
        selectedCol == col;

    final isLegalMove =
        isValidMoveSquare(
      row,
      col,
    );

    final isCapture =
        isLegalMove &&
        piece.isNotEmpty;

    final isCheckedKing =
        (piece == 'wk' &&
                isKingInCheck(true)) ||
            (piece == 'bk' &&
                isKingInCheck(false));

    return GestureDetector(
      onTap: () {
        onSquareTap(
          row,
          col,
        );
      },
      child: SizedBox(
        width: squareSize,
        height: squareSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ====================================================
            // SQUARE
            // ====================================================

            Container(
              width: squareSize,
              height: squareSize,
              decoration: BoxDecoration(
                color: isCheckedKing
                    ? Colors.red.withOpacity(0.75)
                    : isSelected
                        ? const Color(0xffFFD166)
                        : isLightSquare
                            ? const Color(0xffF0D9B5)
                            : const Color(0xffB58863),
              ),
            ),

            // ====================================================
            // CHECKED KING
            // ====================================================

            if (isCheckedKing)
              Container(
                width: squareSize - 3,
                height: squareSize - 3,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.red.shade900,
                    width: 4,
                  ),
                ),
              ),

            // ====================================================
            // LEGAL MOVE DOT
            // ====================================================

            if (isLegalMove && !isCapture)
              Container(
                width: squareSize * 0.22,
                height: squareSize * 0.22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      Colors.black.withOpacity(0.35),
                ),
              ),

            // ====================================================
            // CAPTURE RING
            // ====================================================

            if (isCapture)
              Container(
                width: squareSize * 0.82,
                height: squareSize * 0.82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        Colors.black.withOpacity(0.45),
                    width: squareSize * 0.08,
                  ),
                ),
              ),

            // ====================================================
            // PIECE
            // ====================================================

            if (piece.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.all(2),
                child: Image.asset(
                  'assets/images/chess/pieces/$piece.png',
                  width: squareSize * 0.88,
                  height: squareSize * 0.88,
                  fit: BoxFit.contain,
                ),
              ),
          ],
        ),
      ),
    );
  }
}