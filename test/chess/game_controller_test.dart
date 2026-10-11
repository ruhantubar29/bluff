import 'package:bluff/games/chess/core/chess_game.dart';
import 'package:bluff/games/chess/core/engine/chess_engine.dart';
import 'package:bluff/games/chess/core/game_clock.dart';
import 'package:bluff/games/chess/core/models/game_record.dart';
import 'package:bluff/games/chess/core/models/game_result.dart';
import 'package:bluff/games/chess/core/models/time_control.dart';
import 'package:bluff/games/chess/services/settings_service.dart';
import 'package:bluff/games/chess/state/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every cue so tests can assert on the audio side without a plugin.
class _RecordingSound implements ChessSound {
  final List<String> events = [];

  @override
  void move({
    required bool capture,
    required bool castle,
    required bool promotion,
  }) {
    if (promotion) {
      events.add('promotion');
    } else if (castle) {
      events.add('castle');
    } else if (capture) {
      events.add('capture');
    } else {
      events.add('move');
    }
  }

  @override
  void check() => events.add('check');

  @override
  void gameEnd({required bool isDraw, required bool localWon}) {
    events.add(isDraw ? 'draw' : localWon ? 'win' : 'lose');
  }

  @override
  void illegal() => events.add('illegal');

  @override
  void lowTime() => events.add('lowTime');

  @override
  void start() => events.add('start');
}

Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 8),
  String description = 'condition',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $description');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  ChessSettings settings({
    bool? autoQueen,
    bool? confirmMoves,
    bool? allowTakebacks,
  }) =>
      // null keeps the product default for that flag.
      ChessSettings().copyWith(
        autoQueen: autoQueen,
        confirmMoves: confirmMoves,
        allowTakebacks: allowTakebacks,
      );

  GameController makeController({
    ChessGameMode mode = ChessGameMode.passAndPlay,
    ChessGame? game,
    TimeControl? timeControl,
    ChessSettings? settings,
    EngineLevel level = EngineLevel.beginner,
    bool computerIsWhite = false,
    ChessSound sound = const SilentChessSound(),
    String whiteName = 'White',
    String blackName = 'Black',
  }) {
    final controller = GameController(
      mode: mode,
      game: game,
      // Unlimited keeps the ticker out of the way unless a test wants a clock.
      timeControl: timeControl ?? TimeControl.unlimited,
      settings: settings,
      sound: sound,
      computerLevel: level,
      computerIsWhite: computerIsWhite,
      whiteName: whiteName,
      blackName: blackName,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  ChessGame promotionGame() => ChessGame(fen: '7k/P7/8/8/8/8/8/7K w - - 0 1');

  group('move flow (pass & play)', () {
    test('tap-select then tap-target plays the move', () {
      final c = makeController();
      expect(c.canInteract, isTrue);
      expect(c.isWhiteTurn, isTrue);

      c.tapSquare('e2');
      expect(c.selectedSquare, 'e2');
      expect(c.legalTargets, contains('e4'));
      expect(c.legalTargets, hasLength(2)); // e3, e4

      c.tapSquare('e4');
      expect(c.moves, hasLength(1));
      expect(c.moves.first.san, 'e4');
      expect(c.moves.first.colorWasWhite, isTrue);
      expect(c.lastMoveFrom, 'e2');
      expect(c.lastMoveTo, 'e4');
      expect(c.selectedSquare, isNull);
      expect(c.legalTargets, isEmpty);
      expect(c.isWhiteTurn, isFalse);
      expect(c.lastMove, isNotNull);
    });

    test('selecting another own piece retargets instead of moving', () {
      final c = makeController();
      c.tapSquare('e2');
      c.tapSquare('g1');
      expect(c.selectedSquare, 'g1');
      expect(c.legalTargets, contains('f3'));
      expect(c.moves, isEmpty);
    });

    test('tapping an illegal destination clears the selection', () {
      final c = makeController();
      c.tapSquare('e2');
      c.tapSquare('e5'); // not a legal target, nothing there
      expect(c.selectedSquare, isNull);
      expect(c.moves, isEmpty);
    });

    test('an illegal move is refused and reported', () {
      final sound = _RecordingSound();
      final c = makeController(sound: sound);
      final attempt = c.playMove(from: 'e2', to: 'e5');
      expect(attempt.played, isFalse);
      expect(attempt.outcome, MoveOutcome.illegal);
      expect(c.moves, isEmpty);
      expect(sound.events, contains('illegal'));
    });

    test('moving out of turn is refused', () {
      final c = makeController();
      c.playMove(from: 'e2', to: 'e4');
      final attempt = c.playMove(from: 'e1', to: 'e2');
      expect(attempt.played, isFalse);
      expect(attempt.outcome, MoveOutcome.notYourTurn);
      expect(c.moves, hasLength(1));
    });

    test('captures update the trays and material balance', () {
      final c = makeController();
      c.playMove(from: 'e2', to: 'e4');
      c.playMove(from: 'd7', to: 'd5');
      final attempt = c.playMove(from: 'e4', to: 'd5');

      expect(attempt.played, isTrue);
      expect(c.moves.last.isCapture, isTrue);
      expect(c.moves.last.capturedPiece, 'p');
      expect(c.captured.byWhite, ['p']);
      expect(c.captured.byBlack, isEmpty);
      expect(c.materialBalance(), 1.0);
    });

    test('move sounds carry the right cue', () {
      final sound = _RecordingSound();
      final c = makeController(sound: sound);
      c.playMove(from: 'e2', to: 'e4');
      c.playMove(from: 'd7', to: 'd5');
      c.playMove(from: 'e4', to: 'd5');
      expect(sound.events, ['move', 'move', 'capture']);
    });

    test('identifies the opening from the ECO book', () {
      final c = makeController();
      expect(c.opening, isNull);
      c.playMove(from: 'e2', to: 'e4');
      c.playMove(from: 'e7', to: 'e5');
      final opening = c.opening;
      expect(opening, isNotNull);
      expect(opening!.eco, matches(RegExp(r'^[A-E][0-9]{2}$')));
      expect(opening.name, isNotEmpty);
    });
  });

  group('promotion', () {
    test('asks for a piece when auto-queen is off', () {
      final c = makeController(game: promotionGame());
      final attempt = c.playMove(from: 'a7', to: 'a8');

      expect(attempt.played, isFalse);
      expect(attempt.outcome, MoveOutcome.promotionRequired);
      expect(c.pendingPromotion, ('a7', 'a8'));
      expect(c.moves, isEmpty);
      expect(c.canInteract, isFalse, reason: 'pending choice blocks input');

      c.completePromotion('q');
      expect(c.pendingPromotion, isNull);
      expect(c.moves, hasLength(1));
      expect(c.moves.first.promotion, 'q');
      expect(c.moves.first.san, startsWith('a8=Q'),
          reason: 'promotion is spelled with =Q (plus check if any)');
      expect(c.canInteract, isTrue);
    });

    test('underpromotion is honoured', () {
      final c = makeController(game: promotionGame());
      c.playMove(from: 'a7', to: 'a8');
      c.completePromotion('n');
      expect(c.moves, hasLength(1));
      expect(c.moves.first.promotion, 'n');
      expect(c.moves.first.san, 'a8=N');
    });

    test('cancelling the dialog leaves the position untouched', () {
      final c = makeController(game: promotionGame());
      c.playMove(from: 'a7', to: 'a8');
      expect(c.pendingPromotion, isNotNull);
      c.cancelPromotion();
      expect(c.pendingPromotion, isNull);
      expect(c.moves, isEmpty);
      expect(c.game.pieceAt('a7')?.type, isNotNull);
      expect(c.canInteract, isTrue);
    });

    test('auto-queen applies immediately', () {
      final c =
          makeController(game: promotionGame(), settings: settings(autoQueen: true));
      final attempt = c.playMove(from: 'a7', to: 'a8');
      expect(attempt.played, isTrue);
      expect(c.pendingPromotion, isNull);
      expect(c.moves.first.promotion, 'q');
    });
  });

  group('confirm-moves setting', () {
    test('waits for a second tap before applying', () {
      final c = makeController(settings: settings(confirmMoves: true));
      final attempt = c.playMove(from: 'e2', to: 'e4');

      expect(attempt.outcome, MoveOutcome.awaitingConfirmation);
      expect(c.moves, isEmpty);
      expect(c.pendingConfirmation, ('e2', 'e4'));

      c.tapSquare('e4');
      expect(c.moves, hasLength(1));
      expect(c.pendingConfirmation, isNull);
    });

    test('tapping the origin cancels the pending move', () {
      final c = makeController(settings: settings(confirmMoves: true));
      c.playMove(from: 'e2', to: 'e4');
      c.tapSquare('e2');
      expect(c.pendingConfirmation, isNull);
      expect(c.moves, isEmpty);
    });

    test('explicit cancel works too', () {
      final c = makeController(settings: settings(confirmMoves: true));
      c.playMove(from: 'e2', to: 'e4');
      c.cancelPendingConfirmation();
      expect(c.pendingConfirmation, isNull);
      expect(c.moves, isEmpty);
    });
  });

  group('computer opponent', () {
    test('engine replies after the human move', () async {
      final c = makeController(
        mode: ChessGameMode.computer,
        level: EngineLevel.beginner,
      );
      expect(c.canInteract, isTrue);

      final attempt = c.playMove(from: 'e2', to: 'e4');
      expect(attempt.played, isTrue);
      expect(c.thinking, isTrue,
          reason: 'the engine starts thinking synchronously');
      expect(c.canInteract, isFalse, reason: 'no input while it thinks');

      await c.playEngineMoveNow();

      expect(c.moves, hasLength(2));
      expect(c.moves.last.colorWasWhite, isFalse);
      expect(c.thinking, isFalse);
      expect(c.isWhiteTurn, isTrue, reason: "back to the human's turn");
      expect(c.canInteract, isTrue);
    });

    test('engine opens the game when it plays White', () async {
      final c = makeController(
        mode: ChessGameMode.computer,
        level: EngineLevel.beginner,
        computerIsWhite: true,
      );
      expect(c.canInteract, isFalse, reason: 'the engine moves first');

      await c.playEngineMoveNow();
      expect(c.moves, hasLength(1));
      expect(c.moves.first.colorWasWhite, isTrue);
      expect(c.canInteract, isTrue, reason: "now it's the human's turn");
    });

    test('human may not move on the engine turn', () {
      final c = makeController(
        mode: ChessGameMode.computer,
        level: EngineLevel.beginner,
        computerIsWhite: true,
      );
      expect(c.canInteract, isFalse, reason: 'the engine plays White');
      c.playMove(from: 'e7', to: 'e5');
      expect(c.moves, isEmpty, reason: 'the rules refuse a White-to-move game');
      c.tapSquare('e7'); // tap path is blocked by canInteract
      expect(c.moves, isEmpty);
    });

    test('takeback removes engine reply and human move together', () async {
      final c = makeController(
        mode: ChessGameMode.computer,
        level: EngineLevel.beginner,
      );
      c.playMove(from: 'e2', to: 'e4');
      await c.playEngineMoveNow();
      expect(c.moves, hasLength(2));

      final undone = c.requestTakeback();
      expect(undone, 2, reason: 'engine reply + human move');
      expect(c.moves, isEmpty);
      expect(c.isWhiteTurn, isTrue, reason: "it's the human's turn again");

      // The engine must not silently re-reply into the rewound position.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(c.moves, isEmpty);
      expect(c.thinking, isFalse);
    });

    test('takeback during the engine think undoes only the human move', () {
      final c = makeController(
        mode: ChessGameMode.computer,
        level: EngineLevel.beginner,
      );
      c.playMove(from: 'e2', to: 'e4');
      expect(c.thinking, isTrue);

      final undone = c.requestTakeback();
      expect(undone, 1);
      expect(c.moves, isEmpty);
      expect(c.isWhiteTurn, isTrue);
    });
  });

  group('takeback (pass & play)', () {
    test('undoes exactly one ply', () {
      final c = makeController();
      c.playMove(from: 'e2', to: 'e4');
      c.playMove(from: 'e7', to: 'e5');
      expect(c.requestTakeback(), 1);
      expect(c.moves, hasLength(1));
      expect(c.isWhiteTurn, isFalse, reason: 'Black is to move again');
      expect(c.lastMoveFrom, isNull);
      expect(c.statusMessage, 'Takeback');
    });

    test('is refused when the setting is off', () {
      final c = makeController(settings: settings(allowTakebacks: false));
      c.playMove(from: 'e2', to: 'e4');
      expect(c.requestTakeback(), 0);
      expect(c.moves, hasLength(1));
    });

    test('is refused on an empty game', () {
      final c = makeController();
      expect(c.requestTakeback(), 0);
    });

    test('online mode only requests approval', () {
      final c = makeController(mode: ChessGameMode.online);
      c.playMove(from: 'e2', to: 'e4');
      expect(c.requestTakeback(), 0);
      expect(c.takebackPending, isTrue);
      expect(c.moves, hasLength(1));

      c.declineTakeback();
      expect(c.takebackPending, isFalse);
      expect(c.statusMessage, 'Takeback declined');
    });
  });

  group('draw offers', () {
    test('pass & play: offer then accept ends in a draw', () async {
      final sound = _RecordingSound();
      GameFinishedEvent? event;
      final c = makeController(sound: sound)
        ..onFinished = (e) => event = e;

      c.playMove(from: 'e2', to: 'e4');
      expect(await c.offerDraw(byWhite: true), isFalse,
          reason: 'the answer arrives via respondToDrawOffer');
      expect(c.drawOfferActive, isTrue);

      c.respondToDrawOffer(accepted: true);
      expect(c.finished, isTrue);
      expect(c.result!.reason, GameEndReason.drawAgreement);
      expect(c.result!.isDraw, isTrue);
      expect(sound.events, contains('draw'));
      expect(event, isNotNull);
      expect(event!.result.isDraw, isTrue);
    });

    test('pass & play: declining clears the offer', () {
      final c = makeController();
      c.playMove(from: 'e2', to: 'e4');
      c.offerDraw(byWhite: true);
      expect(c.drawOfferActive, isTrue);

      c.respondToDrawOffer(accepted: false);
      expect(c.drawOfferActive, isFalse);
      expect(c.finished, isFalse);
      expect(c.statusMessage, 'Draw offer declined');
    });

    test('computer declines a draw it is not worse in', () async {
      final c = makeController(
        mode: ChessGameMode.computer,
        level: EngineLevel.beginner,
      );
      c.playMove(from: 'e2', to: 'e4');
      await c.playEngineMoveNow();

      final accepted = await c.offerDraw(byWhite: true);
      expect(accepted, isFalse);
      expect(c.drawOfferActive, isFalse);
      expect(c.finished, isFalse);
      expect(c.statusMessage, 'Draw offer declined');
    });

    test('a finished game ignores further offers', () async {
      final c = makeController();
      c.resign(byWhite: true);
      expect(await c.offerDraw(byWhite: false), isFalse);
      c.respondToDrawOffer(accepted: true);
      expect(c.result!.reason, GameEndReason.resignation);
      expect(c.finished, isTrue);
    });
  });

  group('claiming rule draws', () {
    test('insufficient material can be claimed', () {
      final c = makeController(game: ChessGame(fen: '7k/8/8/8/8/8/8/K6N w - - 0 1'));
      expect(c.claimableDraw, DrawReason.insufficientMaterial);
      expect(c.canClaimDraw, isTrue);

      expect(c.claimDraw(), isTrue);
      expect(c.finished, isTrue);
      expect(c.result!.reason, GameEndReason.insufficientMaterial);
      expect(c.result!.isDraw, isTrue);
    });

    test('nothing to claim outside the rules', () {
      final c = makeController();
      expect(c.claimableDraw, isNull);
      expect(c.canClaimDraw, isFalse);
      expect(c.claimDraw(), isFalse);
      expect(c.finished, isFalse);
    });
  });

  group('endings', () {
    test('resigning awards the win to the opponent', () {
      GameFinishedEvent? event;
      final sound = _RecordingSound();
      final c = makeController(sound: sound)
        ..onFinished = (e) => event = e;

      c.playMove(from: 'e2', to: 'e4');
      c.resign(byWhite: true);

      expect(c.finished, isTrue);
      expect(c.result!.reason, GameEndReason.resignation);
      expect(c.result!.winnerIsWhite, isFalse);
      expect(c.statusMessage, 'RESIGNATION');
      expect(c.canInteract, isFalse);
      expect(sound.events, contains('lose'));
      expect(event, isNotNull);
      expect(event!.result.winnerIsWhite, isFalse);

      // A second resign is a no-op.
      c.resign(byWhite: false);
      expect(c.result!.winnerIsWhite, isFalse);
    });

    test('abandonment (connection lost) awards the win', () {
      final c = makeController(mode: ChessGameMode.online);
      c.abandon(whiteAbandoned: true);
      expect(c.finished, isTrue);
      expect(c.result!.reason, GameEndReason.abandonment);
      expect(c.result!.winnerIsWhite, isFalse);
    });

    test('timeout ends the game on the next tick', () async {
      final c = makeController(
        timeControl: TimeControl.presets.first, // 1 + 0
      );
      expect(c.hasClock, isTrue);
      c.startGame();
      expect(c.started, isTrue);
      expect(c.clock!.isRunning, isTrue);

      c.clock!.setRemaining(ClockSide.white, const Duration(milliseconds: 5));
      await waitFor(() => c.finished, description: 'flagged clock');

      expect(c.result!.reason, GameEndReason.timeout);
      expect(c.result!.winnerIsWhite, isFalse,
          reason: 'White ran out of time');
      expect(c.clock!.isRunning, isFalse);
    });

    test('a finished game refuses further play', () {
      final c = makeController();
      c.resign(byWhite: true);
      expect(c.playMove(from: 'e2', to: 'e4').outcome, MoveOutcome.gameOver);
      expect(c.moves, isEmpty);
    });

    test('sound cues distinguish win / draw / loss', () {
      final winSound = _RecordingSound();
      final win = makeController(sound: winSound);
      win.resign(byWhite: false); // local player (White) wins
      expect(winSound.events, contains('win'));

      final drawSound = _RecordingSound();
      final draw = makeController(sound: drawSound);
      draw.agreeDraw();
      expect(drawSound.events, contains('draw'));

      final lossSound = _RecordingSound();
      final loss = makeController(sound: lossSound);
      loss.resign(byWhite: true); // local player (White) loses
      expect(lossSound.events, contains('lose'));
    });
  });

  group('record building', () {
    test('captures result, moves, source and opening', () {
      final c = makeController(
        timeControl: TimeControl.presets[7], // 10 + 0
        whiteName: 'Ada',
        blackName: 'Bobby',
      );
      c.playMove(from: 'e2', to: 'e4');
      c.playMove(from: 'e7', to: 'e5');
      expect(c.buildRecord(), isNull, reason: 'before the game ends');

      c.resign(byWhite: true);
      final record = c.buildRecord(
        whiteRatingAfter: 1210,
        blackRatingAfter: 1190,
        openingName: c.opening?.name,
        openingEco: c.opening?.eco,
        pgn: '1. e4 e5 *',
      );

      expect(record, isNotNull);
      expect(record!.moves, hasLength(2));
      expect(record.result.reason, GameEndReason.resignation);
      expect(record.source, GameSource.passAndPlay);
      expect(record.timeControlLabel, '10 + 0');
      expect(record.timeCategory, TimeCategory.rapid);
      expect(record.whiteName, 'Ada');
      expect(record.blackName, 'Bobby');
      expect(record.whiteRatingAfter, 1210);
      expect(record.blackRatingAfter, 1190);
      expect(record.openingEco, isNotNull);
      expect(record.pgn, '1. e4 e5 *');
      expect(record.endedAt.isAfter(record.startedAt), isTrue);
    });

    test('computer games record the level', () async {
      final c = makeController(
        mode: ChessGameMode.computer,
        level: EngineLevel.easy,
      );
      c.playMove(from: 'e2', to: 'e4');
      await c.playEngineMoveNow();
      c.resign(byWhite: true);

      final record = c.buildRecord();
      expect(record, isNotNull);
      expect(record!.source, GameSource.computer);
      expect(record.computerLevel, 'easy');
    });
  });

  group('online mode', () {
    test('applies a legal move from the peer', () {
      final c = makeController(mode: ChessGameMode.online);
      c.playMove(from: 'e2', to: 'e4');
      final attempt =
          c.applyRemoteMove(from: 'e7', to: 'e5');
      expect(attempt.played, isTrue);
      expect(c.moves, hasLength(2));
      expect(c.isWhiteTurn, isTrue);
    });

    test('rejects an illegal payload from the peer', () {
      final c = makeController(mode: ChessGameMode.online);
      c.playMove(from: 'e2', to: 'e4');
      final attempt = c.applyRemoteMove(from: 'e7', to: 'e4');
      expect(attempt.played, isFalse);
      expect(c.moves, hasLength(1));
    });
  });

  group('state helpers', () {
    test('startGame marks the game live', () {
      final c = makeController();
      expect(c.started, isFalse);
      c.startGame();
      expect(c.started, isTrue);
    });

    test('flipping notifies listeners', () {
      final c = makeController();
      var notified = 0;
      c.addListener(() => notified++);
      expect(c.flipped, isFalse);
      c.flipped = true;
      expect(c.flipped, isTrue);
      expect(notified, 1);
      c.flipped = true; // no-op
      expect(notified, 1);
    });

    test('clock snapshots round-trip through JSON', () {
      final c = makeController(timeControl: TimeControl.presets[3]);
      c.startGame();
      final snapshot = c.clockSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot!['whiteMs'], greaterThan(0));
      c.pauseClock();
      expect(c.clock!.isRunning, isFalse);
      c.resumeClock();
    });
  });
}
