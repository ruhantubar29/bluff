import 'dart:async';

import 'package:bluff/games/chess/core/models/challenge.dart';
import 'package:bluff/games/chess/core/models/friendship.dart';
import 'package:bluff/games/chess/core/models/game_result.dart';
import 'package:bluff/games/chess/core/models/time_control.dart';
import 'package:bluff/games/chess/services/online_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// An in-memory backend double: proves a future backend plugs in by
/// assigning [OnlineService.instance] — no app code changes required.
class FakeOnlineService implements OnlineService {
  @override
  bool get isAvailable => true;

  @override
  ConnectionPhase get phase => ConnectionPhase.connected;

  @override
  Stream<ConnectionPhase> get phaseChanges => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  void disconnect() {}

  @override
  Future<Stream<MatchmakingUpdate>> enqueue({
    required TimeControl timeControl,
  }) async {
    return Stream.fromIterable([
      QueueJoined(timeControl: timeControl),
      MatchFound(
        gameId: 'g1',
        opponentId: 'o1',
        opponentName: 'Nora',
        opponentRating: 1214,
        localIsWhite: true,
        timeControl: timeControl,
      ),
    ]);
  }

  @override
  void leaveQueue() {}

  @override
  Future<LiveGame> openGame(String gameId) async => FakeLiveGame(gameId);

  @override
  Future<Map<String, PresenceStatus>> presence(Set<String> playerIds) async {
    return {
      for (final id in playerIds) id: PresenceStatus.offline,
    };
  }

  @override
  Future<void> sendChallenge(ChessChallenge challenge) async {}

  @override
  Future<void> respondToChallenge(
    String challengeId, {
    required bool accept,
  }) async {}

  @override
  Future<Stream<ChessChallenge>> challengeUpdates() async =>
      const Stream<ChessChallenge>.empty();

  @override
  Future<List<LeaderboardEntry>> leaderboard({
    required RatingCategory category,
    int limit = 50,
  }) async {
    return [
      const LeaderboardEntry(
        rank: 1,
        playerId: 'local-1',
        displayName: 'You',
        rating: 1350,
        isLocal: true,
      ),
    ];
  }
}

class FakeLiveGame implements LiveGame {
  FakeLiveGame(this.gameId);

  @override
  final String gameId;

  final _events = StreamController<LiveGameEvent>();
  final moves = <String>[];

  @override
  Stream<LiveGameEvent> get events => _events.stream;

  @override
  Future<void> playMove({
    required String from,
    required String to,
    String? promotion,
  }) async {
    moves.add('$from$to${promotion ?? ''}');
    // The "server" validates and echoes an opponent reply.
    _events.add(const OpponentMoved(from: 'd7', to: 'd5'));
  }

  @override
  Future<void> resign() async {
    _events.add(const GameEnded(
      result: GameResult(
        reason: GameEndReason.resignation,
        winnerIsWhite: false,
      ),
    ));
  }

  @override
  Future<void> offerDraw() async {}

  @override
  Future<void> answerDraw({required bool accept}) async {}

  @override
  void close() => _events.close();
}

void main() {
  tearDown(() {
    OnlineService.instance = const StubOnlineService();
  });

  test('the default implementation is the offline stub', () {
    expect(OnlineService.instance, isA<StubOnlineService>());
    expect(OnlineService.instance.isAvailable, isFalse);
    expect(OnlineService.instance.phase, ConnectionPhase.disconnected);
  });

  test('stub phase stream is genuinely empty (never pretends to connect)',
      () async {
    expect(await OnlineService.instance.phaseChanges.isEmpty, isTrue);
    expect(OnlineService.instance.phase.label, 'Disconnected');
  });

  test('stub throws instead of inventing backend data', () async {
    final service = OnlineService.instance;

    await expectLater(
      service.connect(),
      throwsA(isA<OnlineUnavailableException>()),
    );
    await expectLater(
      service.enqueue(timeControl: TimeControl.presets.first),
      throwsA(isA<OnlineUnavailableException>()),
    );
    await expectLater(
      service.openGame('g1'),
      throwsA(isA<OnlineUnavailableException>()),
    );
    await expectLater(
      service.presence(const {'friend-1'}),
      throwsA(isA<OnlineUnavailableException>()),
    );
    await expectLater(
      service.sendChallenge(_challenge()),
      throwsA(isA<OnlineUnavailableException>()),
    );
    await expectLater(
      service.respondToChallenge('c1', accept: true),
      throwsA(isA<OnlineUnavailableException>()),
    );
    await expectLater(
      service.challengeUpdates(),
      throwsA(isA<OnlineUnavailableException>()),
    );
    await expectLater(
      service.leaderboard(category: RatingCategory.rapid),
      throwsA(isA<OnlineUnavailableException>()),
    );

    // Idempotent operations stay safe.
    service.disconnect();
    service.leaveQueue();
  });

  test('a backend plugs in by assigning the instance', () async {
    OnlineService.instance = FakeOnlineService();
    final service = OnlineService.instance;
    expect(service.isAvailable, isTrue);
    expect(service.phase, ConnectionPhase.connected);

    // Matchmaking emits queue progress then exactly one match.
    final updates =
        await (await service.enqueue(timeControl: TimeControl.presets.first))
            .toList();
    expect(updates.whereType<QueueJoined>(), hasLength(1));
    final match = updates.whereType<MatchFound>().single;
    expect(match.gameId, 'g1');
    expect(match.localIsWhite, isTrue);
    expect(match.opponentRating, 1214);

    // An open game round-trips moves through events.
    final game = await service.openGame(match.gameId);
    expect(game.gameId, 'g1');
    final reply = game.events.first;
    await game.playMove(from: 'e2', to: 'e4');
    final event = await reply;
    expect(event, isA<OpponentMoved>());
    expect((event as OpponentMoved).from, 'd7');
    game.close();

    // Presence and leaderboard return real data, marked for the local player.
    final presence =
        await service.presence(const {'friend-1', 'friend-2'});
    expect(presence.keys, containsAll(const {'friend-1', 'friend-2'}));
    final board = await service.leaderboard(category: RatingCategory.blitz);
    expect(board.single.isLocal, isTrue);
    expect(board.single.rank, 1);
  });

  test('live game resign ends with a server result', () async {
    OnlineService.instance = FakeOnlineService();
    final game = await OnlineService.instance.openGame('g2');
    final ended = game.events.first;
    await game.resign();
    final event = await ended;
    expect(event, isA<GameEnded>());
    expect((event as GameEnded).result.winnerIsWhite, isFalse);
    game.close();
  });
}

ChessChallenge _challenge() => ChessChallenge(
      id: 'c1',
      fromId: 'local-1',
      fromName: 'You',
      toId: 'friend-1',
      toName: 'Friend',
      timeControlLabel: '10 + 0',
      timeCategory: TimeCategory.rapid,
      createdAt: DateTime(2026, 1, 1),
    );
