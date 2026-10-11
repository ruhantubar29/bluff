/// Game-ending reasons and results.
library;

enum GameEndReason {
  checkmate,
  resignation,
  timeout,
  drawAgreement,
  stalemate,
  threefoldRepetition,
  fiftyMoveRule,
  insufficientMaterial,
  abandonment,
}

/// The outcome from White's point of view plus the reason it happened.
class GameResult {
  const GameResult({required this.reason, this.winnerIsWhite});

  /// Why the game ended.
  final GameEndReason reason;

  /// Winner: `true` = White, `false` = Black, `null` = draw.
  final bool? winnerIsWhite;

  bool get isDraw => winnerIsWhite == null;

  String get reasonLabel {
    switch (reason) {
      case GameEndReason.checkmate:
        return 'Checkmate';
      case GameEndReason.resignation:
        return 'Resignation';
      case GameEndReason.timeout:
        return 'Timeout';
      case GameEndReason.drawAgreement:
        return 'Draw by agreement';
      case GameEndReason.stalemate:
        return 'Stalemate';
      case GameEndReason.threefoldRepetition:
        return 'Threefold repetition';
      case GameEndReason.fiftyMoveRule:
        return 'Fifty-move rule';
      case GameEndReason.insufficientMaterial:
        return 'Insufficient material';
      case GameEndReason.abandonment:
        return 'Abandonment';
    }
  }

  /// Short headline shown in the result modal (e.g. "CHECKMATE").
  String get headline {
    switch (reason) {
      case GameEndReason.checkmate:
        return 'CHECKMATE';
      case GameEndReason.resignation:
        return 'RESIGNATION';
      case GameEndReason.timeout:
        return 'TIME OUT';
      case GameEndReason.drawAgreement:
        return 'DRAW';
      case GameEndReason.stalemate:
        return 'STALEMATE';
      case GameEndReason.threefoldRepetition:
      case GameEndReason.fiftyMoveRule:
      case GameEndReason.insufficientMaterial:
        return 'DRAW';
      case GameEndReason.abandonment:
        return 'GAME OVER';
    }
  }

  /// e.g. "White wins" / "Draw".
  String get winnerLabel {
    if (isDraw) return 'Draw';
    return winnerIsWhite == true ? 'White wins' : 'Black wins';
  }

  /// Score for White: 1 win, 0.5 draw, 0 loss.
  double get whiteScore {
    if (winnerIsWhite == null) return 0.5;
    return winnerIsWhite == true ? 1.0 : 0.0;
  }

  /// Result token stored in PGN (1-0, 0-1, 1/2-1/2).
  String get pgnToken {
    if (winnerIsWhite == null) return '1/2-1/2';
    return winnerIsWhite == true ? '1-0' : '0-1';
  }

  /// Result as seen from [perspectiveIsWhite]'s point of view.
  String outcomeFor(bool perspectiveIsWhite) {
    if (isDraw) return '½';
    final perspectiveWon = winnerIsWhite == perspectiveIsWhite;
    return perspectiveWon ? '1' : '0';
  }

  @override
  String toString() => 'GameResult(${reason.name}, $winnerLabel)';
}
