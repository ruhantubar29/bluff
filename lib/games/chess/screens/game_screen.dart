import 'package:flutter/material.dart';

import '../logic/chess_logic.dart';
import '../widgets/chess_board.dart';

class ChessGameScreen extends StatefulWidget {
  const ChessGameScreen({
    super.key,
  });

  @override
  State<ChessGameScreen> createState() =>
      _ChessGameScreenState();
}

class _ChessGameScreenState
    extends State<ChessGameScreen> {
  // ============================================================
  // BOARD
  // ============================================================

  late List<List<String>> board;

  // ============================================================
  // CHESS STATE
  // ============================================================

  late CastlingRights castlingRights;

  int? enPassantTargetRow;
  int? enPassantTargetCol;

  // Number of half-moves since the last pawn move or capture.
  int halfmoveClock = 0;

  // ============================================================
  // UI STATE
  // ============================================================

  int? selectedRow;
  int? selectedCol;

  List<List<int>> validMoves = [];

  bool whiteTurn = true;

  bool gameOver = false;

  String winnerMessage = '';

  // ============================================================
  // HISTORY
  // ============================================================

  final List<String> moveHistory = [];

  final List<_ChessState> _undoHistory = [];

  // ============================================================
  // REPETITION
  // ============================================================

  final Map<String, int> _positionOccurrences =
      <String, int>{};

  // ============================================================
  // CAPTURED PIECES
  // ============================================================

  final List<String> capturedWhitePieces = [];

  final List<String> capturedBlackPieces = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    board =
        ChessLogic.createInitialBoard();

    castlingRights =
        CastlingRights.initial();

    _resetPositionHistory();
  }

  // ============================================================
  // RESET POSITION HISTORY
  // ============================================================

  void _resetPositionHistory() {
    _positionOccurrences.clear();

    final startingPosition =
        _createPositionKey();

    _positionOccurrences[
        startingPosition] = 1;
  }

  // ============================================================
  // CURRENT POSITION KEY
  // ============================================================

  String _createPositionKey() {
    return ChessLogic.createPositionKey(
      board,
      whiteTurn: whiteTurn,
      castlingRights:
          castlingRights,
      enPassantTargetRow:
          enPassantTargetRow,
      enPassantTargetCol:
          enPassantTargetCol,
    );
  }

  // ============================================================
  // RECORD POSITION
  // ============================================================

  void _recordCurrentPosition() {
    final key =
        _createPositionKey();

    _positionOccurrences[key] =
        (_positionOccurrences[key] ?? 0) + 1;
  }

  // ============================================================
  // THREEFOLD REPETITION
  // ============================================================

  bool _isThreefoldRepetition() {
    final key =
        _createPositionKey();

    return (_positionOccurrences[key] ?? 0) >= 3;
  }

  // ============================================================
  // FIVEFOLD REPETITION
  // ============================================================

  bool _isFivefoldRepetition() {
    final key =
        _createPositionKey();

    return (_positionOccurrences[key] ?? 0) >= 5;
  }

  // ============================================================
  // 50-MOVE RULE
  // ============================================================

  bool _isFiftyMoveDraw() {
    return halfmoveClock >= 100;
  }

  // ============================================================
  // 75-MOVE RULE
  // ============================================================

  bool _isSeventyFiveMoveDraw() {
    return halfmoveClock >= 150;
  }

  // ============================================================
  // SQUARE TAP
  // ============================================================

  Future<void> onSquareTap(
    int row,
    int col,
  ) async {
    if (gameOver) {
      return;
    }

    final piece =
        board[row][col];

    // ----------------------------------------------------------
    // NOTHING SELECTED
    // ----------------------------------------------------------

    if (selectedRow == null ||
        selectedCol == null) {
      if (_isCorrectTurn(piece)) {
        _selectPiece(
          row,
          col,
        );
      }

      return;
    }

    // ----------------------------------------------------------
    // SELECT ANOTHER OWN PIECE
    // ----------------------------------------------------------

    if (_isCorrectTurn(piece)) {
      _selectPiece(
        row,
        col,
      );

      return;
    }

    // ----------------------------------------------------------
    // INVALID DESTINATION
    // ----------------------------------------------------------

    if (!_isValidMoveSquare(
      row,
      col,
    )) {
      _clearSelection();
      return;
    }

    final fromRow =
        selectedRow!;

    final fromCol =
        selectedCol!;

    final movingPiece =
        board[fromRow][fromCol];

    final capturedPiece =
        board[row][col];

    // ----------------------------------------------------------
    // EN PASSANT
    // ----------------------------------------------------------

    final isEnPassant =
        movingPiece[1] == 'p' &&
            capturedPiece.isEmpty &&
            fromCol != col &&
            row == enPassantTargetRow &&
            col == enPassantTargetCol;

    // ----------------------------------------------------------
    // GET EN PASSANT CAPTURED PIECE
    // ----------------------------------------------------------

    String actualCapturedPiece =
        capturedPiece;

    if (isEnPassant) {
      final capturedPawnRow =
          ChessLogic.isWhitePiece(
            movingPiece,
          )
              ? row + 1
              : row - 1;

      actualCapturedPiece =
          board[capturedPawnRow][col];
    }

    // ----------------------------------------------------------
    // SAVE STATE
    // ----------------------------------------------------------

    final previousState =
        _createCurrentState();

    // ----------------------------------------------------------
    // SAVE DATA NEEDED FOR SAN
    // ----------------------------------------------------------

    final legalMovesForPiece =
        ChessLogic.getValidMoves(
      board,
      fromRow,
      fromCol,
      castlingRights:
          castlingRights,
      enPassantTargetRow:
          enPassantTargetRow,
      enPassantTargetCol:
          enPassantTargetCol,
    );

    // ----------------------------------------------------------
    // PROMOTION
    // ----------------------------------------------------------

    String? promotionPiece;

    final reachesPromotionRank =
        (movingPiece == 'wp' &&
                row == 0) ||
            (movingPiece == 'bp' &&
                row == 7);

    if (reachesPromotionRank) {
      promotionPiece =
          await _showPromotionDialog(
        white:
            ChessLogic.isWhitePiece(
          movingPiece,
        ),
      );

      if (!mounted) {
        return;
      }

      if (promotionPiece == null) {
        return;
      }
    }

    // ----------------------------------------------------------
    // MAKE MOVE
    // ----------------------------------------------------------

    final moved =
        ChessLogic.makeMove(
      board,
      fromRow,
      fromCol,
      row,
      col,
      castlingRights:
          castlingRights,
      enPassantTargetRow:
          enPassantTargetRow,
      enPassantTargetCol:
          enPassantTargetCol,
    );

    if (!moved) {
      _clearSelection();
      return;
    }

    // ----------------------------------------------------------
    // SAVE UNDO
    // ----------------------------------------------------------

    _undoHistory.add(
      previousState,
    );

    // ----------------------------------------------------------
    // PROMOTION
    // ----------------------------------------------------------

    if (promotionPiece != null) {
      board[row][col] =
          promotionPiece;
    }

    // ----------------------------------------------------------
    // CAPTURE
    // ----------------------------------------------------------

    if (actualCapturedPiece.isNotEmpty) {
      if (ChessLogic.isWhitePiece(
        actualCapturedPiece,
      )) {
        capturedWhitePieces.add(
          actualCapturedPiece,
        );
      } else {
        capturedBlackPieces.add(
          actualCapturedPiece,
        );
      }
    }

    // ----------------------------------------------------------
    // UPDATE 50/75 MOVE COUNTER
    // ----------------------------------------------------------

    final isPawnMove =
        movingPiece[1] == 'p';

    final isCapture =
        actualCapturedPiece.isNotEmpty;

    if (isPawnMove || isCapture) {
      halfmoveClock = 0;
    } else {
      halfmoveClock++;
    }

    // ----------------------------------------------------------
    // UPDATE EN PASSANT
    // ----------------------------------------------------------

    int? newEnPassantRow;
    int? newEnPassantCol;

    if (movingPiece[1] == 'p' &&
        (row - fromRow).abs() == 2) {
      newEnPassantRow =
          (fromRow + row) ~/ 2;

      newEnPassantCol =
          fromCol;
    }

    enPassantTargetRow =
        newEnPassantRow;

    enPassantTargetCol =
        newEnPassantCol;

    // ----------------------------------------------------------
    // CHANGE TURN
    // ----------------------------------------------------------

    final nextSideToMove =
        !whiteTurn;

    whiteTurn =
        nextSideToMove;

    // ----------------------------------------------------------
    // CREATE SAN MOVE TEXT
    // ----------------------------------------------------------

    final moveText =
        _createSanMoveText(
      piece: movingPiece,
      fromRow: fromRow,
      fromCol: fromCol,
      toRow: row,
      toCol: col,
      capturedPiece:
          actualCapturedPiece,
      isEnPassant:
          isEnPassant,
      promotionPiece:
          promotionPiece,
      legalMovesForPiece:
          legalMovesForPiece,
    );

    moveHistory.add(
      moveText,
    );

    // ----------------------------------------------------------
    // RECORD NEW POSITION
    // ----------------------------------------------------------

    _recordCurrentPosition();

    // ----------------------------------------------------------
    // UPDATE UI
    // ----------------------------------------------------------

    setState(() {
      selectedRow = null;
      selectedCol = null;

      validMoves = [];
    });

    // ----------------------------------------------------------
    // CHECK RESULT
    // ----------------------------------------------------------

    _checkGameResult(
      whiteTurn,
    );
  }

  // ============================================================
  // SELECT PIECE
  // ============================================================

  void _selectPiece(
    int row,
    int col,
  ) {
    final moves =
        ChessLogic.getValidMoves(
      board,
      row,
      col,
      castlingRights:
          castlingRights,
      enPassantTargetRow:
          enPassantTargetRow,
      enPassantTargetCol:
          enPassantTargetCol,
    );

    setState(() {
      selectedRow = row;
      selectedCol = col;
      validMoves = moves;
    });
  }

  // ============================================================
  // CLEAR SELECTION
  // ============================================================

  void _clearSelection() {
    setState(() {
      selectedRow = null;
      selectedCol = null;
      validMoves = [];
    });
  }

  // ============================================================
  // TURN
  // ============================================================

  bool _isCorrectTurn(
    String piece,
  ) {
    if (piece.isEmpty) {
      return false;
    }

    return ChessLogic.isWhitePiece(
          piece,
        ) ==
        whiteTurn;
  }

  // ============================================================
  // VALID MOVE
  // ============================================================

  bool _isValidMoveSquare(
    int row,
    int col,
  ) {
    return validMoves.any(
      (move) =>
          move[0] == row &&
          move[1] == col,
    );
  }

  // ============================================================
  // PROMOTION DIALOG
  // ============================================================

  Future<String?> _showPromotionDialog({
    required bool white,
  }) {
    final pieces = [
      'q',
      'r',
      'b',
      'n',
    ];

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Promote Pawn',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Text(
                'Choose a piece:',
              ),
              const SizedBox(
                height: 16,
              ),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceEvenly,
                children:
                    pieces.map(
                  (type) {
                    final piece =
                        '${white ? 'w' : 'b'}$type';

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(
                          context,
                          piece,
                        );
                      },
                      child: Container(
                        width: 55,
                        height: 65,
                        padding:
                            const EdgeInsets
                                .all(5),
                        decoration:
                            BoxDecoration(
                          border:
                              Border.all(
                            color:
                                Theme.of(
                              context,
                            ).dividerColor,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                        ),
                        child:
                            Image.asset(
                          'assets/images/chess/pieces/$piece.png',
                          fit: BoxFit
                              .contain,
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // SAN MOVE TEXT
  // ============================================================

  String _createSanMoveText({
    required String piece,
    required int fromRow,
    required int fromCol,
    required int toRow,
    required int toCol,
    required String capturedPiece,
    required bool isEnPassant,
    required String? promotionPiece,
    required List<List<int>> legalMovesForPiece,
  }) {
    // ----------------------------------------------------------
    // CASTLING
    // ----------------------------------------------------------

    if (piece[1] == 'k' &&
        (toCol - fromCol).abs() == 2) {
      final isKingSide =
          toCol > fromCol;

      final notation =
          isKingSide
              ? 'O-O'
              : 'O-O-O';

      return _addCheckSuffix(
        notation,
      );
    }

    final type =
        piece[1];

    final isPawn =
        type == 'p';

    final isCapture =
        capturedPiece.isNotEmpty ||
            isEnPassant;

    // ----------------------------------------------------------
    // PAWN
    // ----------------------------------------------------------

    if (isPawn) {
      String result = '';

      if (isCapture) {
        result +=
            _fileName(fromCol);
        result += 'x';
      }

      result +=
          _squareName(
        toRow,
        toCol,
      );

      if (promotionPiece != null) {
        result +=
            '=${promotionPiece[1].toUpperCase()}';
      }

      return _addCheckSuffix(
        result,
      );
    }

    // ----------------------------------------------------------
    // PIECE
    // ----------------------------------------------------------

    const pieceNames = {
      'n': 'N',
      'b': 'B',
      'r': 'R',
      'q': 'Q',
      'k': 'K',
    };

    final symbol =
        pieceNames[type] ?? '';

    String disambiguation =
        '';

    if (type != 'k') {
      disambiguation =
          _getDisambiguation(
        piece,
        fromRow,
        fromCol,
        toRow,
        toCol,
      );
    }

    String result =
        '$symbol'
        '$disambiguation'
        '${isCapture ? 'x' : ''}'
        '${_squareName(toRow, toCol)}';

    return _addCheckSuffix(
      result,
    );
  }

  // ============================================================
  // SAN DISAMBIGUATION
  // ============================================================

  String _getDisambiguation(
    String movingPiece,
    int fromRow,
    int fromCol,
    int toRow,
    int toCol,
  ) {
    final candidates =
        <List<int>>[];

    final movingWhite =
        ChessLogic.isWhitePiece(
      movingPiece,
    );

    for (int row = 0;
        row < 8;
        row++) {
      for (int col = 0;
          col < 8;
          col++) {
        if (row == fromRow &&
            col == fromCol) {
          continue;
        }

        final candidate =
            board[row][col];

        if (candidate !=
            movingPiece) {
          continue;
        }

        if (ChessLogic.isWhitePiece(
              candidate,
            ) !=
            movingWhite) {
          continue;
        }

        final moves =
            ChessLogic.getValidMoves(
          board,
          row,
          col,
          castlingRights:
              castlingRights,
          enPassantTargetRow:
              enPassantTargetRow,
          enPassantTargetCol:
              enPassantTargetCol,
        );

        final canReach =
            moves.any(
          (move) =>
              move[0] == toRow &&
              move[1] == toCol,
        );

        if (canReach) {
          candidates.add([
            row,
            col,
          ]);
        }
      }
    }

    if (candidates.isEmpty) {
      return '';
    }

    final sameFile =
        candidates.any(
      (square) =>
          square[1] == fromCol,
    );

    final sameRank =
        candidates.any(
      (square) =>
          square[0] == fromRow,
    );

    if (!sameFile) {
      return _fileName(
        fromCol,
      );
    }

    if (!sameRank) {
      return _rankName(
        fromRow,
      );
    }

    return _squareName(
      fromRow,
      fromCol,
    );
  }

  // ============================================================
  // CHECK / CHECKMATE SUFFIX
  // ============================================================

  String _addCheckSuffix(
    String notation,
  ) {
    final sideThatMoved =
        !whiteTurn;

    final opponent =
        whiteTurn;

    if (ChessLogic.isCheckmate(
      board,
      opponent,
      castlingRights:
          castlingRights,
      enPassantTargetRow:
          enPassantTargetRow,
      enPassantTargetCol:
          enPassantTargetCol,
    )) {
      return '$notation#';
    }

    if (ChessLogic.isInCheck(
      board,
      opponent,
    )) {
      return '$notation+';
    }

    return notation;
  }

  // ============================================================
  // FILE NAME
  // ============================================================

  String _fileName(
    int col,
  ) {
    const files = [
      'a',
      'b',
      'c',
      'd',
      'e',
      'f',
      'g',
      'h',
    ];

    return files[col];
  }

  // ============================================================
  // RANK NAME
  // ============================================================

  String _rankName(
    int row,
  ) {
    const ranks = [
      '8',
      '7',
      '6',
      '5',
      '4',
      '3',
      '2',
      '1',
    ];

    return ranks[row];
  }

  // ============================================================
  // SQUARE NAME
  // ============================================================

  String _squareName(
    int row,
    int col,
  ) {
    return '${_fileName(col)}${_rankName(row)}';
  }

  // ============================================================
  // GAME RESULT
  // ============================================================

  void _checkGameResult(
    bool sideToMove,
  ) {
    if (!mounted) {
      return;
    }

    // ----------------------------------------------------------
    // DRAW — INSUFFICIENT MATERIAL
    // ----------------------------------------------------------

    if (ChessLogic.isInsufficientMaterial(
      board,
    )) {
      setState(() {
        gameOver = true;

        winnerMessage =
            'Draw by insufficient material.';
      });

      _showGameOverDialog(
        'Draw',
        'The game ended because there is insufficient material to checkmate.',
      );

      return;
    }

    // ----------------------------------------------------------
    // DRAW — FIVEFOLD REPETITION
    // ----------------------------------------------------------

    if (_isFivefoldRepetition()) {
      setState(() {
        gameOver = true;

        winnerMessage =
            'Draw by fivefold repetition.';
      });

      _showGameOverDialog(
        'Draw',
        'The same position occurred five times.',
      );

      return;
    }

    // ----------------------------------------------------------
    // DRAW — THREEFOLD REPETITION
    // ----------------------------------------------------------

    if (_isThreefoldRepetition()) {
      setState(() {
        gameOver = true;

        winnerMessage =
            'Draw by threefold repetition.';
      });

      _showGameOverDialog(
        'Draw',
        'The same position occurred three times.',
      );

      return;
    }

    // ----------------------------------------------------------
    // DRAW — 75-MOVE RULE
    // ----------------------------------------------------------

    if (_isSeventyFiveMoveDraw()) {
      setState(() {
        gameOver = true;

        winnerMessage =
            'Draw by the 75-move rule.';
      });

      _showGameOverDialog(
        'Draw',
        '75 moves by each side were completed without a pawn move or capture.',
      );

      return;
    }

    // ----------------------------------------------------------
    // DRAW — 50-MOVE RULE
    // ----------------------------------------------------------

    if (_isFiftyMoveDraw()) {
      setState(() {
        gameOver = true;

        winnerMessage =
            'Draw by the 50-move rule.';
      });

      _showGameOverDialog(
        'Draw',
        '50 moves by each side were completed without a pawn move or capture.',
      );

      return;
    }

    // ----------------------------------------------------------
    // CHECKMATE
    // ----------------------------------------------------------

    if (ChessLogic.isCheckmate(
      board,
      sideToMove,
      castlingRights:
          castlingRights,
      enPassantTargetRow:
          enPassantTargetRow,
      enPassantTargetCol:
          enPassantTargetCol,
    )) {
      final winner =
          sideToMove
              ? 'Black'
              : 'White';

      setState(() {
        gameOver = true;

        winnerMessage =
            '$winner wins by checkmate!';
      });

      _showGameOverDialog(
        '$winner Wins!',
        '$winner wins by checkmate.',
      );

      return;
    }

    // ----------------------------------------------------------
    // STALEMATE
    // ----------------------------------------------------------

    if (ChessLogic.isStalemate(
      board,
      sideToMove,
      castlingRights:
          castlingRights,
      enPassantTargetRow:
          enPassantTargetRow,
      enPassantTargetCol:
          enPassantTargetCol,
    )) {
      setState(() {
        gameOver = true;

        winnerMessage =
            'Draw by stalemate.';
      });

      _showGameOverDialog(
        'Draw',
        'The game ended in stalemate.',
      );

      return;
    }

    setState(() {});
  }

  // ============================================================
  // GAME OVER DIALOG
  // ============================================================

  void _showGameOverDialog(
    String title,
    String message,
  ) {
    Future.delayed(
      const Duration(
        milliseconds: 250,
      ),
      () {
        if (!mounted) {
          return;
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              content: Text(
                message,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );

                    restartGame();
                  },
                  child: const Text(
                    'RESTART',
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );

                    Navigator.pop(
                      context,
                    );
                  },
                  child: const Text(
                    'EXIT',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // UNDO
  // ============================================================

  void undoMove() {
    if (_undoHistory.isEmpty) {
      return;
    }

    final previousState =
        _undoHistory.removeLast();

    setState(() {
      board =
          previousState.board
              .map(
                (row) =>
                    List<String>.from(row),
              )
              .toList();

      castlingRights =
          previousState.castlingRights
              .copy();

      enPassantTargetRow =
          previousState.enPassantTargetRow;

      enPassantTargetCol =
          previousState.enPassantTargetCol;

      halfmoveClock =
          previousState.halfmoveClock;

      whiteTurn =
          previousState.whiteTurn;

      moveHistory
        ..clear()
        ..addAll(
          previousState.moveHistory,
        );

      capturedWhitePieces
        ..clear()
        ..addAll(
          previousState.capturedWhitePieces,
        );

      capturedBlackPieces
        ..clear()
        ..addAll(
          previousState.capturedBlackPieces,
        );

      _positionOccurrences
        ..clear()
        ..addAll(
          previousState.positionOccurrences,
        );

      selectedRow = null;
      selectedCol = null;

      validMoves = [];

      gameOver = false;

      winnerMessage = '';
    });
  }

  // ============================================================
  // SAVE STATE
  // ============================================================

  _ChessState _createCurrentState() {
    return _ChessState(
      board: board
          .map(
            (row) =>
                List<String>.from(row),
          )
          .toList(),
      castlingRights:
          castlingRights.copy(),
      enPassantTargetRow:
          enPassantTargetRow,
      enPassantTargetCol:
          enPassantTargetCol,
      halfmoveClock:
          halfmoveClock,
      whiteTurn:
          whiteTurn,
      moveHistory:
          List<String>.from(
        moveHistory,
      ),
      capturedWhitePieces:
          List<String>.from(
        capturedWhitePieces,
      ),
      capturedBlackPieces:
          List<String>.from(
        capturedBlackPieces,
      ),
      positionOccurrences:
          Map<String, int>.from(
        _positionOccurrences,
      ),
    );
  }

  // ============================================================
  // RESIGN
  // ============================================================

  void resignGame() {
    if (gameOver) {
      return;
    }

    final resigningPlayer =
        whiteTurn
            ? 'White'
            : 'Black';

    final winner =
        whiteTurn
            ? 'Black'
            : 'White';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Resign Game?',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          content: Text(
            '$resigningPlayer will lose the game if they resign.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child: const Text(
                'CANCEL',
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );

                setState(() {
                  gameOver = true;

                  winnerMessage =
                      '$winner wins by resignation!';
                });

                _showGameOverDialog(
                  '$winner Wins!',
                  '$winner wins by resignation.',
                );
              },
              child: const Text(
                'RESIGN',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // RESTART
  // ============================================================

  void restartGame() {
    setState(() {
      board =
          ChessLogic.createInitialBoard();

      castlingRights =
          CastlingRights.initial();

      enPassantTargetRow = null;
      enPassantTargetCol = null;

      halfmoveClock = 0;

      selectedRow = null;
      selectedCol = null;

      validMoves = [];

      whiteTurn = true;

      gameOver = false;

      winnerMessage = '';

      moveHistory.clear();

      _undoHistory.clear();

      capturedWhitePieces.clear();

      capturedBlackPieces.clear();

      _resetPositionHistory();
    });
  }

  // ============================================================
  // KING CHECK
  // ============================================================

  bool _isKingInCheck(
    bool white,
  ) {
    return ChessLogic.isInCheck(
      board,
      white,
    );
  }

  // ============================================================
  // MOVE HISTORY
  // ============================================================

  void _showMoveHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Theme.of(context)
              .scaffoldBackgroundColor,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 360,
            child: Column(
              children: [
                const SizedBox(
                  height: 14,
                ),

                const Text(
                  'MOVE HISTORY',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                const Divider(
                  height: 1,
                ),

                Expanded(
                  child:
                      moveHistory.isEmpty
                          ? const Center(
                              child: Text(
                                'No moves yet.',
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                vertical: 8,
                                horizontal: 20,
                              ),
                              itemCount:
                                  (moveHistory.length +
                                          1) ~/
                                      2,
                              itemBuilder:
                                  (context,
                                      index) {
                                final whiteIndex =
                                    index * 2;

                                final blackIndex =
                                    whiteIndex + 1;

                                final whiteMove =
                                    moveHistory[
                                        whiteIndex];

                                final blackMove =
                                    blackIndex <
                                            moveHistory
                                                .length
                                        ? moveHistory[
                                            blackIndex]
                                        : '';

                                return Padding(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    vertical: 5,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 32,
                                        child:
                                            Text(
                                          '${index + 1}.',
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),

                                      Expanded(
                                        child:
                                            Text(
                                          whiteMove,
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                        ),
                                      ),

                                      Expanded(
                                        child:
                                            Text(
                                          blackMove,
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final currentPlayer =
        whiteTurn
            ? 'White'
            : 'Black';

    final currentPlayerInCheck =
        _isKingInCheck(
      whiteTurn,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chess',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip:
                'Move history',
            onPressed:
                _showMoveHistory,
            icon: const Icon(
              Icons.history,
            ),
          ),

          IconButton(
            tooltip:
                'Undo move',
            onPressed:
                _undoHistory.isEmpty
                    ? null
                    : undoMove,
            icon: const Icon(
              Icons.undo,
            ),
          ),

          PopupMenuButton<String>(
            onSelected:
                (value) {
              if (value ==
                  'resign') {
                resignGame();
              }

              if (value ==
                  'restart') {
                restartGame();
              }
            },
            itemBuilder:
                (context) {
              return const [
                PopupMenuItem(
                  value:
                      'resign',
                  child: Text(
                    'Resign',
                  ),
                ),
                PopupMenuItem(
                  value:
                      'restart',
                  child: Text(
                    'Restart Game',
                  ),
                ),
              ];
            },
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(
              height: 10,
            ),

            Text(
              gameOver
                  ? winnerMessage
                  : "$currentPlayer's turn",
              style:
                  const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(
              height: 6,
            ),

            if (!gameOver &&
                currentPlayerInCheck)
              const Text(
                'CHECK!',
                style:
                    TextStyle(
                  color: Colors.red,
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),

            const SizedBox(
              height: 8,
            ),

            SizedBox(
              height: 28,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                children: [
                  if (capturedBlackPieces
                      .isNotEmpty)
                    ...capturedBlackPieces
                        .map(
                      (piece) {
                        return _capturedPiece(
                          piece,
                        );
                      },
                    ),

                  if (capturedBlackPieces
                          .isNotEmpty &&
                      capturedWhitePieces
                          .isNotEmpty)
                    const SizedBox(
                      width: 14,
                    ),

                  if (capturedWhitePieces
                      .isNotEmpty)
                    ...capturedWhitePieces
                        .map(
                      (piece) {
                        return _capturedPiece(
                          piece,
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            Expanded(
              child: Center(
                child: ChessBoard(
                  board: board,
                  selectedRow:
                      selectedRow,
                  selectedCol:
                      selectedCol,
                  validMoves:
                      validMoves,
                  isKingInCheck:
                      _isKingInCheck,
                  isValidMoveSquare:
                      _isValidMoveSquare,
                  onSquareTap:
                      onSquareTap,
                ),
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: Row(
                children: [
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          _undoHistory.isEmpty
                              ? null
                              : undoMove,
                      icon:
                          const Icon(
                        Icons.undo,
                      ),
                      label:
                          const Text(
                        'UNDO',
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          restartGame,
                      icon:
                          const Icon(
                        Icons.refresh,
                      ),
                      label:
                          const Text(
                        'RESTART',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 12,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CAPTURED PIECE
  // ============================================================

  Widget _capturedPiece(
    String piece,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 1,
      ),
      child: Image.asset(
        'assets/images/chess/pieces/$piece.png',
        width: 22,
        height: 22,
        fit: BoxFit.contain,
      ),
    );
  }
}

// ================================================================
// UNDO STATE
// ================================================================

class _ChessState {
  final List<List<String>> board;

  final CastlingRights castlingRights;

  final int? enPassantTargetRow;

  final int? enPassantTargetCol;

  final int halfmoveClock;

  final bool whiteTurn;

  final List<String> moveHistory;

  final List<String> capturedWhitePieces;

  final List<String> capturedBlackPieces;

  final Map<String, int> positionOccurrences;

  _ChessState({
    required this.board,
    required this.castlingRights,
    required this.enPassantTargetRow,
    required this.enPassantTargetCol,
    required this.halfmoveClock,
    required this.whiteTurn,
    required this.moveHistory,
    required this.capturedWhitePieces,
    required this.capturedBlackPieces,
    required this.positionOccurrences,
  });
}