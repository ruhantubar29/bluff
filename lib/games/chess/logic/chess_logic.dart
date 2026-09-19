class CastlingRights {
  bool whiteKingSide;
  bool whiteQueenSide;
  bool blackKingSide;
  bool blackQueenSide;

  CastlingRights({
    this.whiteKingSide = true,
    this.whiteQueenSide = true,
    this.blackKingSide = true,
    this.blackQueenSide = true,
  });

  CastlingRights.initial()
      : whiteKingSide = true,
        whiteQueenSide = true,
        blackKingSide = true,
        blackQueenSide = true;

  CastlingRights copy() {
    return CastlingRights(
      whiteKingSide: whiteKingSide,
      whiteQueenSide: whiteQueenSide,
      blackKingSide: blackKingSide,
      blackQueenSide: blackQueenSide,
    );
  }
}

class ChessLogic {
  // ============================================================
  // INITIAL BOARD
  // ============================================================

  static List<List<String>> createInitialBoard() {
    return [
      ['br', 'bn', 'bb', 'bq', 'bk', 'bb', 'bn', 'br'],
      ['bp', 'bp', 'bp', 'bp', 'bp', 'bp', 'bp', 'bp'],
      ['', '', '', '', '', '', '', ''],
      ['', '', '', '', '', '', '', ''],
      ['', '', '', '', '', '', '', ''],
      ['', '', '', '', '', '', '', ''],
      ['wp', 'wp', 'wp', 'wp', 'wp', 'wp', 'wp', 'wp'],
      ['wr', 'wn', 'wb', 'wq', 'wk', 'wb', 'wn', 'wr'],
    ];
  }

  // ============================================================
  // PIECE HELPERS
  // ============================================================

  static bool isWhitePiece(String piece) {
    return piece.startsWith('w');
  }

  static bool isBlackPiece(String piece) {
    return piece.startsWith('b');
  }

  static bool isEnemyPiece(
    String piece,
    bool white,
  ) {
    if (piece.isEmpty) {
      return false;
    }

    return white
        ? isBlackPiece(piece)
        : isWhitePiece(piece);
  }

  static bool isInsideBoard(
    int row,
    int col,
  ) {
    return row >= 0 &&
        row < 8 &&
        col >= 0 &&
        col < 8;
  }

  // ============================================================
  // INSUFFICIENT MATERIAL
  // ============================================================

  static bool isInsufficientMaterial(
    List<List<String>> board,
  ) {
    final nonKingPieces = <_PiecePosition>[];

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = board[row][col];

        if (piece.isEmpty ||
            piece == 'wk' ||
            piece == 'bk') {
          continue;
        }

        nonKingPieces.add(
          _PiecePosition(
            piece: piece,
            row: row,
            col: col,
          ),
        );
      }
    }

    // ----------------------------------------------------------
    // KING VS KING
    // ----------------------------------------------------------

    if (nonKingPieces.isEmpty) {
      return true;
    }

    // ----------------------------------------------------------
    // KING + BISHOP VS KING
    // KING + KNIGHT VS KING
    // ----------------------------------------------------------

    if (nonKingPieces.length == 1) {
      final piece =
          nonKingPieces.first.piece;

      return piece == 'wb' ||
          piece == 'bb' ||
          piece == 'wn' ||
          piece == 'bn';
    }

    // ----------------------------------------------------------
    // KING + BISHOP VS KING + BISHOP
    //
    // Only same-colored bishops are insufficient material.
    // ----------------------------------------------------------

    if (nonKingPieces.length == 2) {
      final first =
          nonKingPieces[0];

      final second =
          nonKingPieces[1];

      final bothBishops =
          (first.piece == 'wb' ||
              first.piece == 'bb') &&
          (second.piece == 'wb' ||
              second.piece == 'bb');

      if (bothBishops) {
        final firstSquareColor =
            (first.row + first.col) % 2;

        final secondSquareColor =
            (second.row + second.col) % 2;

        return firstSquareColor ==
            secondSquareColor;
      }
    }

    return false;
  }

  // ============================================================
  // POSITION KEY
  //
  // Used for threefold repetition.
  //
  // The position includes:
  // - Piece placement
  // - Side to move
  // - Castling rights
  // - En passant availability
  // ============================================================

  static String createPositionKey(
    List<List<String>> board, {
    required bool whiteTurn,
    CastlingRights? castlingRights,
    int? enPassantTargetRow,
    int? enPassantTargetCol,
  }) {
    final rights =
        castlingRights ??
            CastlingRights.initial();

    final buffer =
        StringBuffer();

    // ----------------------------------------------------------
    // BOARD
    // ----------------------------------------------------------

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece =
            board[row][col];

        buffer.write(
          piece.isEmpty
              ? '--'
              : piece,
        );
      }
    }

    // ----------------------------------------------------------
    // SIDE TO MOVE
    // ----------------------------------------------------------

    buffer.write(
      whiteTurn ? '|w|' : '|b|',
    );

    // ----------------------------------------------------------
    // CASTLING RIGHTS
    // ----------------------------------------------------------

    buffer.write(
      rights.whiteKingSide
          ? 'K'
          : '-',
    );

    buffer.write(
      rights.whiteQueenSide
          ? 'Q'
          : '-',
    );

    buffer.write(
      rights.blackKingSide
          ? 'k'
          : '-',
    );

    buffer.write(
      rights.blackQueenSide
          ? 'q'
          : '-',
    );

    // ----------------------------------------------------------
    // EN PASSANT
    //
    // Only include the target square if an actual legal
    // en passant capture exists for the side to move.
    // ----------------------------------------------------------

    final hasLegalEnPassant =
        _hasLegalEnPassantCapture(
      board,
      whiteTurn,
      enPassantTargetRow,
      enPassantTargetCol,
    );

    if (hasLegalEnPassant) {
      buffer.write(
        '|ep:$enPassantTargetRow,$enPassantTargetCol',
      );
    } else {
      buffer.write('|ep:-');
    }

    return buffer.toString();
  }

  // ============================================================
  // LEGAL EN PASSANT AVAILABILITY
  // ============================================================

  static bool _hasLegalEnPassantCapture(
    List<List<String>> board,
    bool white,
    int? enPassantTargetRow,
    int? enPassantTargetCol,
  ) {
    if (enPassantTargetRow == null ||
        enPassantTargetCol == null) {
      return false;
    }

    final targetRow =
        enPassantTargetRow;

    final targetCol =
        enPassantTargetCol;

    final pawn =
        white ? 'wp' : 'bp';

    final pawnRow =
        white
            ? targetRow + 1
            : targetRow - 1;

    if (!isInsideBoard(
      pawnRow,
      targetCol,
    )) {
      return false;
    }

    for (final colOffset in [-1, 1]) {
      final pawnCol =
          targetCol + colOffset;

      if (!isInsideBoard(
        pawnRow,
        pawnCol,
      )) {
        continue;
      }

      if (board[pawnRow][pawnCol] != pawn) {
        continue;
      }

      if (!isValidMove(
        board,
        pawnRow,
        pawnCol,
        targetRow,
        targetCol,
        enPassantTargetRow:
            enPassantTargetRow,
        enPassantTargetCol:
            enPassantTargetCol,
      )) {
        continue;
      }

      final testBoard =
          _copyBoard(board);

      _makeMoveUnchecked(
        testBoard,
        pawnRow,
        pawnCol,
        targetRow,
        targetCol,
        enPassantTargetRow:
            enPassantTargetRow,
        enPassantTargetCol:
            enPassantTargetCol,
      );

      if (!isInCheck(
        testBoard,
        white,
      )) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // NORMAL MOVE VALIDATION
  // ============================================================

  static bool isValidMove(
    List<List<String>> board,
    int fromRow,
    int fromCol,
    int toRow,
    int toCol, {
    int? enPassantTargetRow,
    int? enPassantTargetCol,
  }) {
    if (!isInsideBoard(fromRow, fromCol) ||
        !isInsideBoard(toRow, toCol)) {
      return false;
    }

    final piece =
        board[fromRow][fromCol];

    if (piece.isEmpty) {
      return false;
    }

    final target =
        board[toRow][toCol];

    // Cannot capture your own piece.
    if (target.isNotEmpty) {
      final sameColor =
          isWhitePiece(piece) ==
              isWhitePiece(target);

      if (sameColor) {
        return false;
      }

      // Kings can never be captured.
      if (target == 'wk' ||
          target == 'bk') {
        return false;
      }
    }

    final white =
        isWhitePiece(piece);

    final type =
        piece[1];

    switch (type) {
      case 'p':
        return _isValidPawnMove(
          board,
          fromRow,
          fromCol,
          toRow,
          toCol,
          white,
          enPassantTargetRow,
          enPassantTargetCol,
        );

      case 'n':
        return _isValidKnightMove(
          fromRow,
          fromCol,
          toRow,
          toCol,
        );

      case 'b':
        return _isValidBishopMove(
          board,
          fromRow,
          fromCol,
          toRow,
          toCol,
        );

      case 'r':
        return _isValidRookMove(
          board,
          fromRow,
          fromCol,
          toRow,
          toCol,
        );

      case 'q':
        return _isValidQueenMove(
          board,
          fromRow,
          fromCol,
          toRow,
          toCol,
        );

      case 'k':
        return _isValidKingMove(
          fromRow,
          fromCol,
          toRow,
          toCol,
        );

      default:
        return false;
    }
  }

  // ============================================================
  // PAWN
  // ============================================================

  static bool _isValidPawnMove(
    List<List<String>> board,
    int fromRow,
    int fromCol,
    int toRow,
    int toCol,
    bool white,
    int? enPassantTargetRow,
    int? enPassantTargetCol,
  ) {
    final direction =
        white ? -1 : 1;

    final startRow =
        white ? 6 : 1;

    final rowDifference =
        toRow - fromRow;

    final colDifference =
        toCol - fromCol;

    final target =
        board[toRow][toCol];

    // One square forward.
    if (colDifference == 0 &&
        rowDifference == direction &&
        target.isEmpty) {
      return true;
    }

    // Two squares forward from starting position.
    if (colDifference == 0 &&
        fromRow == startRow &&
        rowDifference == direction * 2 &&
        target.isEmpty &&
        board[fromRow + direction][fromCol]
            .isEmpty) {
      return true;
    }

    // Normal diagonal capture.
    if (rowDifference == direction &&
        colDifference.abs() == 1 &&
        target.isNotEmpty &&
        isEnemyPiece(
          target,
          white,
        )) {
      return true;
    }

    // En passant.
    if (rowDifference == direction &&
        colDifference.abs() == 1 &&
        target.isEmpty &&
        enPassantTargetRow == toRow &&
        enPassantTargetCol == toCol) {
      return true;
    }

    return false;
  }

  // ============================================================
  // KNIGHT
  // ============================================================

  static bool _isValidKnightMove(
    int fromRow,
    int fromCol,
    int toRow,
    int toCol,
  ) {
    final rowDifference =
        (toRow - fromRow).abs();

    final colDifference =
        (toCol - fromCol).abs();

    return (rowDifference == 2 &&
            colDifference == 1) ||
        (rowDifference == 1 &&
            colDifference == 2);
  }

  // ============================================================
  // BISHOP
  // ============================================================

  static bool _isValidBishopMove(
    List<List<String>> board,
    int fromRow,
    int fromCol,
    int toRow,
    int toCol,
  ) {
    final rowDifference =
        (toRow - fromRow).abs();

    final colDifference =
        (toCol - fromCol).abs();

    if (rowDifference != colDifference) {
      return false;
    }

    return _isPathClear(
      board,
      fromRow,
      fromCol,
      toRow,
      toCol,
    );
  }

  // ============================================================
  // ROOK
  // ============================================================

  static bool _isValidRookMove(
    List<List<String>> board,
    int fromRow,
    int fromCol,
    int toRow,
    int toCol,
  ) {
    if (fromRow != toRow &&
        fromCol != toCol) {
      return false;
    }

    return _isPathClear(
      board,
      fromRow,
      fromCol,
      toRow,
      toCol,
    );
  }

  // ============================================================
  // QUEEN
  // ============================================================

  static bool _isValidQueenMove(
    List<List<String>> board,
    int fromRow,
    int fromCol,
    int toRow,
    int toCol,
  ) {
    final rowDifference =
        (toRow - fromRow).abs();

    final colDifference =
        (toCol - fromCol).abs();

    final straight =
        fromRow == toRow ||
            fromCol == toCol;

    final diagonal =
        rowDifference == colDifference;

    if (!straight && !diagonal) {
      return false;
    }

    return _isPathClear(
      board,
      fromRow,
      fromCol,
      toRow,
      toCol,
    );
  }

  // ============================================================
  // KING
  // ============================================================

  static bool _isValidKingMove(
    int fromRow,
    int fromCol,
    int toRow,
    int toCol,
  ) {
    final rowDifference =
        (toRow - fromRow).abs();

    final colDifference =
        (toCol - fromCol).abs();

    return rowDifference <= 1 &&
        colDifference <= 1 &&
        rowDifference +
                colDifference >
            0;
  }

  // ============================================================
  // PATH
  // ============================================================

  static bool _isPathClear(
    List<List<String>> board,
    int fromRow,
    int fromCol,
    int toRow,
    int toCol,
  ) {
    final rowDirection =
        _direction(
      toRow - fromRow,
    );

    final colDirection =
        _direction(
      toCol - fromCol,
    );

    int row =
        fromRow + rowDirection;

    int col =
        fromCol + colDirection;

    while (row != toRow ||
        col != toCol) {
      if (board[row][col].isNotEmpty) {
        return false;
      }

      row += rowDirection;
      col += colDirection;
    }

    return true;
  }

  static int _direction(
    int value,
  ) {
    if (value > 0) {
      return 1;
    }

    if (value < 0) {
      return -1;
    }

    return 0;
  }

  // ============================================================
  // LEGAL MOVES
  // ============================================================

  static List<List<int>> getValidMoves(
    List<List<String>> board,
    int fromRow,
    int fromCol, {
    CastlingRights? castlingRights,
    int? enPassantTargetRow,
    int? enPassantTargetCol,
  }) {
    final moves =
        <List<int>>[];

    final piece =
        board[fromRow][fromCol];

    if (piece.isEmpty) {
      return moves;
    }

    final white =
        isWhitePiece(piece);

    final rights =
        castlingRights ??
            CastlingRights.initial();

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        // Normal / en passant move.
        if (isValidMove(
          board,
          fromRow,
          fromCol,
          row,
          col,
          enPassantTargetRow:
              enPassantTargetRow,
          enPassantTargetCol:
              enPassantTargetCol,
        )) {
          final testBoard =
              _copyBoard(board);

          _makeMoveUnchecked(
            testBoard,
            fromRow,
            fromCol,
            row,
            col,
            enPassantTargetRow:
                enPassantTargetRow,
            enPassantTargetCol:
                enPassantTargetCol,
          );

          if (!isInCheck(
            testBoard,
            white,
          )) {
            moves.add([
              row,
              col,
            ]);
          }
        }

        // Castling.
        if (piece[1] == 'k' &&
            _isValidCastle(
              board,
              fromRow,
              fromCol,
              row,
              col,
              rights,
            )) {
          moves.add([
            row,
            col,
          ]);
        }
      }
    }

    return moves;
  }

  // ============================================================
  // ALL LEGAL MOVES
  // ============================================================

  static List<List<List<int>>> getAllLegalMoves(
    List<List<String>> board,
    bool white, {
    CastlingRights? castlingRights,
    int? enPassantTargetRow,
    int? enPassantTargetCol,
  }) {
    final allMoves =
        <List<List<int>>>[];

    final rights =
        castlingRights ??
            CastlingRights.initial();

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece =
            board[row][col];

        if (piece.isEmpty) {
          continue;
        }

        if (isWhitePiece(piece) != white) {
          continue;
        }

        final validMoves =
            getValidMoves(
          board,
          row,
          col,
          castlingRights:
              rights,
          enPassantTargetRow:
              enPassantTargetRow,
          enPassantTargetCol:
              enPassantTargetCol,
        );

        for (final move
            in validMoves) {
          allMoves.add([
            [
              row,
              col,
            ],
            [
              move[0],
              move[1],
            ],
          ]);
        }
      }
    }

    return allMoves;
  }

  // ============================================================
  // STRICT CASTLING
  // ============================================================

  static bool _isValidCastle(
    List<List<String>> board,
    int fromRow,
    int fromCol,
    int toRow,
    int toCol,
    CastlingRights rights,
  ) {
    final king =
        board[fromRow][fromCol];

    if (king != 'wk' &&
        king != 'bk') {
      return false;
    }

    final isWhite =
        king == 'wk';

    final homeRow =
        isWhite ? 7 : 0;

    if (fromRow != homeRow ||
        fromCol != 4) {
      return false;
    }

    final kingSideAllowed =
        isWhite
            ? rights.whiteKingSide
            : rights.blackKingSide;

    final queenSideAllowed =
        isWhite
            ? rights.whiteQueenSide
            : rights.blackQueenSide;

    if (isInCheck(
      board,
      isWhite,
    )) {
      return false;
    }

    // King side.
    if (toRow == homeRow &&
        toCol == 6) {
      if (!kingSideAllowed) {
        return false;
      }

      final rook =
          isWhite ? 'wr' : 'br';

      if (board[homeRow][7] != rook) {
        return false;
      }

      if (board[homeRow][5].isNotEmpty ||
          board[homeRow][6].isNotEmpty) {
        return false;
      }

      if (isSquareAttacked(
        board,
        homeRow,
        5,
        !isWhite,
      )) {
        return false;
      }

      if (isSquareAttacked(
        board,
        homeRow,
        6,
        !isWhite,
      )) {
        return false;
      }

      return true;
    }

    // Queen side.
    if (toRow == homeRow &&
        toCol == 2) {
      if (!queenSideAllowed) {
        return false;
      }

      final rook =
          isWhite ? 'wr' : 'br';

      if (board[homeRow][0] != rook) {
        return false;
      }

      if (board[homeRow][1].isNotEmpty ||
          board[homeRow][2].isNotEmpty ||
          board[homeRow][3].isNotEmpty) {
        return false;
      }

      if (isSquareAttacked(
        board,
        homeRow,
        3,
        !isWhite,
      )) {
        return false;
      }

      if (isSquareAttacked(
        board,
        homeRow,
        2,
        !isWhite,
      )) {
        return false;
      }

      return true;
    }

    return false;
  }

  // ============================================================
  // CHECK
  // ============================================================

  static bool isInCheck(
    List<List<String>> board,
    bool white,
  ) {
    final king =
        white ? 'wk' : 'bk';

    int kingRow = -1;
    int kingCol = -1;

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        if (board[row][col] == king) {
          kingRow = row;
          kingCol = col;
          break;
        }
      }

      if (kingRow != -1) {
        break;
      }
    }

    if (kingRow == -1) {
      return true;
    }

    return isSquareAttacked(
      board,
      kingRow,
      kingCol,
      !white,
    );
  }

  // ============================================================
  // SQUARE ATTACKED
  // ============================================================

  static bool isSquareAttacked(
    List<List<String>> board,
    int row,
    int col,
    bool byWhite,
  ) {
    // Pawns.
    final pawnRow =
        byWhite
            ? row + 1
            : row - 1;

    if (isInsideBoard(
      pawnRow,
      col - 1,
    )) {
      if (board[pawnRow][col - 1] ==
          (byWhite ? 'wp' : 'bp')) {
        return true;
      }
    }

    if (isInsideBoard(
      pawnRow,
      col + 1,
    )) {
      if (board[pawnRow][col + 1] ==
          (byWhite ? 'wp' : 'bp')) {
        return true;
      }
    }

    // Knights.
    const knightOffsets = [
      [-2, -1],
      [-2, 1],
      [-1, -2],
      [-1, 2],
      [1, -2],
      [1, 2],
      [2, -1],
      [2, 1],
    ];

    final knight =
        byWhite ? 'wn' : 'bn';

    for (final offset
        in knightOffsets) {
      final r =
          row + offset[0];

      final c =
          col + offset[1];

      if (isInsideBoard(r, c) &&
          board[r][c] == knight) {
        return true;
      }
    }

    // King.
    final enemyKing =
        byWhite ? 'wk' : 'bk';

    for (int r = row - 1;
        r <= row + 1;
        r++) {
      for (int c = col - 1;
          c <= col + 1;
          c++) {
        if (r == row &&
            c == col) {
          continue;
        }

        if (isInsideBoard(r, c) &&
            board[r][c] == enemyKing) {
          return true;
        }
      }
    }

    // Rook / queen.
    const straightDirections = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];

    final rook =
        byWhite ? 'wr' : 'br';

    final queen =
        byWhite ? 'wq' : 'bq';

    for (final direction
        in straightDirections) {
      int r =
          row + direction[0];

      int c =
          col + direction[1];

      while (isInsideBoard(r, c)) {
        final piece =
            board[r][c];

        if (piece.isNotEmpty) {
          if (piece == rook ||
              piece == queen) {
            return true;
          }

          break;
        }

        r += direction[0];
        c += direction[1];
      }
    }

    // Bishop / queen.
    const diagonalDirections = [
      [-1, -1],
      [-1, 1],
      [1, -1],
      [1, 1],
    ];

    final bishop =
        byWhite ? 'wb' : 'bb';

    for (final direction
        in diagonalDirections) {
      int r =
          row + direction[0];

      int c =
          col + direction[1];

      while (isInsideBoard(r, c)) {
        final piece =
            board[r][c];

        if (piece.isNotEmpty) {
          if (piece == bishop ||
              piece == queen) {
            return true;
          }

          break;
        }

        r += direction[0];
        c += direction[1];
      }
    }

    return false;
  }

  // ============================================================
  // CHECKMATE
  // ============================================================

  static bool isCheckmate(
    List<List<String>> board,
    bool white, {
    CastlingRights? castlingRights,
    int? enPassantTargetRow,
    int? enPassantTargetCol,
  }) {
    if (!isInCheck(
      board,
      white,
    )) {
      return false;
    }

    final legalMoves =
        getAllLegalMoves(
      board,
      white,
      castlingRights:
          castlingRights,
      enPassantTargetRow:
          enPassantTargetRow,
      enPassantTargetCol:
          enPassantTargetCol,
    );

    return legalMoves.isEmpty;
  }

  // ============================================================
  // STALEMATE
  // ============================================================

  static bool isStalemate(
    List<List<String>> board,
    bool white, {
    CastlingRights? castlingRights,
    int? enPassantTargetRow,
    int? enPassantTargetCol,
  }) {
    if (isInCheck(
      board,
      white,
    )) {
      return false;
    }

    final legalMoves =
        getAllLegalMoves(
      board,
      white,
      castlingRights:
          castlingRights,
      enPassantTargetRow:
          enPassantTargetRow,
      enPassantTargetCol:
          enPassantTargetCol,
    );

    return legalMoves.isEmpty;
  }

  // ============================================================
  // MAKE MOVE
  // ============================================================

  static bool makeMove(
    List<List<String>> board,
    int fromRow,
    int fromCol,
    int toRow,
    int toCol, {
    CastlingRights? castlingRights,
    int? enPassantTargetRow,
    int? enPassantTargetCol,
  }) {
    final rights =
        castlingRights ??
            CastlingRights.initial();

    final validMoves =
        getValidMoves(
      board,
      fromRow,
      fromCol,
      castlingRights:
          rights,
      enPassantTargetRow:
          enPassantTargetRow,
      enPassantTargetCol:
          enPassantTargetCol,
    );

    final isLegal =
        validMoves.any(
      (move) =>
          move[0] == toRow &&
          move[1] == toCol,
    );

    if (!isLegal) {
      return false;
    }

    final piece =
        board[fromRow][fromCol];

    final capturedPiece =
        board[toRow][toCol];

    // Castling.
    if (piece[1] == 'k' &&
        fromRow == toRow &&
        (toCol - fromCol).abs() == 2) {
      _makeCastle(
        board,
        fromRow,
        fromCol,
        toRow,
        toCol,
      );

      _updateCastlingRightsAfterMove(
        movingPiece: piece,
        fromRow: fromRow,
        fromCol: fromCol,
        toRow: toRow,
        toCol: toCol,
        capturedPiece:
            capturedPiece,
        rights: rights,
      );

      return true;
    }

    // Normal / en passant move.
    _makeMoveUnchecked(
      board,
      fromRow,
      fromCol,
      toRow,
      toCol,
      enPassantTargetRow:
          enPassantTargetRow,
      enPassantTargetCol:
          enPassantTargetCol,
    );

    // Castling rights.
    _updateCastlingRightsAfterMove(
      movingPiece: piece,
      fromRow: fromRow,
      fromCol: fromCol,
      toRow: toRow,
      toCol: toCol,
      capturedPiece:
          capturedPiece,
      rights: rights,
    );

    return true;
  }

  // ============================================================
  // CASTLING RIGHTS UPDATE
  // ============================================================

  static void _updateCastlingRightsAfterMove({
    required String movingPiece,
    required int fromRow,
    required int fromCol,
    required int toRow,
    required int toCol,
    required String capturedPiece,
    required CastlingRights rights,
  }) {
    // White king moved.
    if (movingPiece == 'wk') {
      rights.whiteKingSide = false;
      rights.whiteQueenSide = false;
    }

    // Black king moved.
    if (movingPiece == 'bk') {
      rights.blackKingSide = false;
      rights.blackQueenSide = false;
    }

    // White rook moved from a1.
    if (movingPiece == 'wr' &&
        fromRow == 7 &&
        fromCol == 0) {
      rights.whiteQueenSide = false;
    }

    // White rook moved from h1.
    if (movingPiece == 'wr' &&
        fromRow == 7 &&
        fromCol == 7) {
      rights.whiteKingSide = false;
    }

    // Black rook moved from a8.
    if (movingPiece == 'br' &&
        fromRow == 0 &&
        fromCol == 0) {
      rights.blackQueenSide = false;
    }

    // Black rook moved from h8.
    if (movingPiece == 'br' &&
        fromRow == 0 &&
        fromCol == 7) {
      rights.blackKingSide = false;
    }

    // White rook captured on a1.
    if (capturedPiece == 'wr' &&
        toRow == 7 &&
        toCol == 0) {
      rights.whiteQueenSide = false;
    }

    // White rook captured on h1.
    if (capturedPiece == 'wr' &&
        toRow == 7 &&
        toCol == 7) {
      rights.whiteKingSide = false;
    }

    // Black rook captured on a8.
    if (capturedPiece == 'br' &&
        toRow == 0 &&
        toCol == 0) {
      rights.blackQueenSide = false;
    }

    // Black rook captured on h8.
    if (capturedPiece == 'br' &&
        toRow == 0 &&
        toCol == 7) {
      rights.blackKingSide = false;
    }
  }

  // ============================================================
  // CASTLE
  // ============================================================

  static void _makeCastle(
    List<List<String>> board,
    int fromRow,
    int fromCol,
    int toRow,
    int toCol,
  ) {
    final king =
        board[fromRow][fromCol];

    final isWhite =
        king == 'wk';

    final rook =
        isWhite ? 'wr' : 'br';

    // King side.
    if (toCol == 6) {
      board[toRow][6] = king;
      board[fromRow][fromCol] = '';

      board[toRow][5] = rook;
      board[toRow][7] = '';

      return;
    }

    // Queen side.
    if (toCol == 2) {
      board[toRow][2] = king;
      board[fromRow][fromCol] = '';

      board[toRow][3] = rook;
      board[toRow][0] = '';
    }
  }

  // ============================================================
  // UNCHECKED MOVE
  // ============================================================

  static void _makeMoveUnchecked(
    List<List<String>> board,
    int fromRow,
    int fromCol,
    int toRow,
    int toCol, {
    int? enPassantTargetRow,
    int? enPassantTargetCol,
  }) {
    final piece =
        board[fromRow][fromCol];

    // En passant capture.
    if (piece[1] == 'p' &&
        toRow == enPassantTargetRow &&
        toCol == enPassantTargetCol &&
        board[toRow][toCol].isEmpty &&
        fromCol != toCol) {
      final capturedPawnRow =
          isWhitePiece(piece)
              ? toRow + 1
              : toRow - 1;

      board[capturedPawnRow][toCol] =
          '';
    }

    // Normal move.
    board[toRow][toCol] =
        piece;

    board[fromRow][fromCol] =
        '';

    // Automatic queen promotion for simulations.
    if (piece == 'wp' &&
        toRow == 0) {
      board[toRow][toCol] = 'wq';
    }

    if (piece == 'bp' &&
        toRow == 7) {
      board[toRow][toCol] = 'bq';
    }
  }

  // ============================================================
  // COPY BOARD
  // ============================================================

  static List<List<String>> _copyBoard(
    List<List<String>> board,
  ) {
    return board
        .map(
          (row) =>
              List<String>.from(row),
        )
        .toList();
  }
}

// ================================================================
// PIECE POSITION
// ================================================================

class _PiecePosition {
  final String piece;
  final int row;
  final int col;

  _PiecePosition({
    required this.piece,
    required this.row,
    required this.col,
  });
}