/// The seam between the local-first chess platform and a future backend.
///
/// Everything the app does *online* — matchmaking, live games, presence,
/// challenges, leaderboards — goes through [OnlineService]. The default
/// implementation is [StubOnlineService], which reports `isAvailable == false`
/// and throws on every operation rather than inventing opponents, presence or
/// rankings. Plugging in a backend means assigning [OnlineService.instance]
/// once at startup; no screen changes.
///
/// Design rules that keep the local-first promise honest:
///
///  * UI gates on [OnlineService.isAvailable] *before* calling anything.
///  * The stub never fabricates data — misuse fails loudly
///    ([OnlineUnavailableException]) instead of silently showing fakes.
///  * Local-only features (history, ratings, puzzles, friends *roster*) never
///    touch this interface; they live in `ChessStorage`.
library;

import '../core/models/challenge.dart';
import '../core/models/friendship.dart';
import '../core/models/game_result.dart';
import '../core/models/time_control.dart';

/// Where the online layer currently stands.
enum ConnectionPhase {
  disconnected,
  connecting,
  connected;

  String get label => switch (this) {
        ConnectionPhase.disconnected => 'Disconnected',
        ConnectionPhase.connecting => 'Connecting…',
        ConnectionPhase.connected => 'Connected',
      };
}

/// Thrown by any [OnlineService] operation when no backend is wired in.
///
/// Callers gate on [OnlineService.isAvailable] first; this exists so a
/// caller that forgets fails loudly instead of receiving invented data.
class OnlineUnavailableException implements Exception {
  const OnlineUnavailableException(this.operation);

  /// The operation that was attempted (e.g. `'enqueue'`).
  final String operation;

  @override
  String toString() =>
      'OnlineUnavailableException("$operation"): no backend connected.';
}

// --------------------------------------------------------------- matchmaking

/// Progress emitted while waiting for an opponent.
sealed class MatchmakingUpdate {
  const MatchmakingUpdate();
}

/// The player is in the queue.
class QueueJoined extends MatchmakingUpdate {
  const QueueJoined({required this.timeControl, this.position});

  final TimeControl timeControl;

  /// Estimated players ahead in the queue, when the server reports one.
  final int? position;
}

/// An opponent was found and a game should start.
class MatchFound extends MatchmakingUpdate {
  const MatchFound({
    required this.gameId,
    required this.opponentId,
    required this.opponentName,
    required this.opponentRating,
    required this.localIsWhite,
    required this.timeControl,
    this.rated = true,
  });

  final String gameId;
  final String opponentId;
  final String opponentName;
  final int opponentRating;
  final bool localIsWhite;
  final TimeControl timeControl;
  final bool rated;
}

// ----------------------------------------------------------------- live game

/// Events pushed by an open [LiveGame] channel. Server-authoritative: the
/// client applies what it receives and proposes what it sends.
sealed class LiveGameEvent {
  const LiveGameEvent();
}

/// The opponent's move arrived and should be applied.
class OpponentMoved extends LiveGameEvent {
  const OpponentMoved({required this.from, required this.to, this.promotion});

  final String from;
  final String to;
  final String? promotion;
}

/// Authoritative clock values (both sides), as maintained by the server.
class ClockSynced extends LiveGameEvent {
  const ClockSynced({required this.whiteMs, required this.blackMs});

  final int whiteMs;
  final int blackMs;
}

/// The server reset the client to its authoritative position (a rejected
/// move, or a reconnect) — apply the FEN and clocks as the source of truth.
class PositionResynced extends LiveGameEvent {
  const PositionResynced({
    required this.fen,
    required this.whiteMs,
    required this.blackMs,
  });

  final String fen;
  final int whiteMs;
  final int blackMs;
}

/// The opponent offered a draw.
class DrawOffered extends LiveGameEvent {
  const DrawOffered();
}

/// The game ended; carries the final result and any server-computed ratings.
class GameEnded extends LiveGameEvent {
  const GameEnded({
    required this.result,
    this.whiteRatingAfter,
    this.blackRatingAfter,
  });

  final GameResult result;
  final int? whiteRatingAfter;
  final int? blackRatingAfter;
}

/// The connection to an open game was lost (the server keeps the game alive
/// until its own timeout rules resolve it).
class ConnectionLost extends LiveGameEvent {
  const ConnectionLost();
}

/// An open connection to a single online game.
abstract class LiveGame {
  String get gameId;

  /// Server events for this game. Closes when the channel shuts down.
  Stream<LiveGameEvent> get events;

  /// Proposes a move; the server validates and echoes it back through
  /// [events] only once accepted.
  Future<void> playMove({
    required String from,
    required String to,
    String? promotion,
  });

  Future<void> resign();
  Future<void> offerDraw();

  /// Accepts or declines the opponent's pending draw offer.
  Future<void> answerDraw({required bool accept});

  /// Closes the channel locally (also happens on [OnlineService.disconnect]).
  void close();
}

// ---------------------------------------------------------------- leaderboard

/// One row of a leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.displayName,
    required this.rating,
    this.isLocal = false,
  });

  final int rank;
  final String playerId;
  final String displayName;
  final int rating;

  /// True for this device's own profile, so the UI can highlight it.
  final bool isLocal;
}

// ------------------------------------------------------------------ interface

/// Online operations available to the app.
///
/// See the library doc for the contract: gate on [isAvailable], never fake.
abstract class OnlineService {
  /// The active implementation.
  ///
  /// Defaults to [StubOnlineService], which reports [isAvailable] == false.
  /// The app does not install a backend today, so every online surface
  /// honestly says so; wiring one back up means assigning a real
  /// implementation here once, at startup.
  static OnlineService instance = StubOnlineService();

  /// True when a backend is configured *and* reachable — i.e. it is honest
  /// for the UI to offer online play, presence and leaderboards.
  bool get isAvailable;

  ConnectionPhase get phase;

  /// Fires whenever [phase] changes. The stub's stream is permanently empty
  /// (its phase genuinely never changes).
  Stream<ConnectionPhase> get phaseChanges;

  /// Attempts to connect. Throws [OnlineUnavailableException] when no
  /// backend is configured.
  Future<void> connect();

  /// Closes the connection. Safe to call when already disconnected.
  void disconnect();

  /// Enters the matchmaking queue for [timeControl]; the stream emits
  /// [QueueJoined] then exactly one [MatchFound], then closes.
  Future<Stream<MatchmakingUpdate>> enqueue({
    required TimeControl timeControl,
  });

  /// Leaves the queue (the queued stream closes).
  void leaveQueue();

  /// Opens the live channel for a game that has already started (from
  /// [MatchFound] or an accepted challenge).
  Future<LiveGame> openGame(String gameId);

  /// Presence for a set of player ids (friends). Returns one entry per
  /// requested id; unknown ids map to [PresenceStatus.unknown].
  Future<Map<String, PresenceStatus>> presence(Set<String> playerIds);

  /// Sends a challenge to another player.
  Future<void> sendChallenge(ChessChallenge challenge);

  /// Accepts or declines an incoming challenge by id.
  Future<void> respondToChallenge(String challengeId, {required bool accept});

  /// Challenge status updates (accept/decline/expire) for challenges the
  /// local player is involved in.
  Future<Stream<ChessChallenge>> challengeUpdates();

  /// Top players for a rating category, as reported by the backend.
  Future<List<LeaderboardEntry>> leaderboard({
    required RatingCategory category,
    int limit = 50,
  });
}

// ---------------------------------------------------------------------- stub

/// The default [OnlineService]: no backend is configured.
///
/// Every operation throws [OnlineUnavailableException] rather than returning
/// invented data, so a caller that forgets to gate on [isAvailable] fails
/// loudly instead of showing fake opponents, fake presence or a fake
/// leaderboard. [phaseChanges] is genuinely empty: the stub never connects.
class StubOnlineService implements OnlineService {
  const StubOnlineService();

  @override
  bool get isAvailable => false;

  @override
  ConnectionPhase get phase => ConnectionPhase.disconnected;

  @override
  Stream<ConnectionPhase> get phaseChanges => const Stream.empty();

  @override
  Future<void> connect() async =>
      throw const OnlineUnavailableException('connect');

  @override
  void disconnect() {
    // Already disconnected — nothing to tear down.
  }

  @override
  Future<Stream<MatchmakingUpdate>> enqueue({
    required TimeControl timeControl,
  }) async =>
      throw const OnlineUnavailableException('enqueue');

  @override
  void leaveQueue() {
    // Nothing was queued.
  }

  @override
  Future<LiveGame> openGame(String gameId) async =>
      throw const OnlineUnavailableException('openGame');

  @override
  Future<Map<String, PresenceStatus>> presence(Set<String> playerIds) async =>
      throw const OnlineUnavailableException('presence');

  @override
  Future<void> sendChallenge(ChessChallenge challenge) async =>
      throw const OnlineUnavailableException('sendChallenge');

  @override
  Future<void> respondToChallenge(
    String challengeId, {
    required bool accept,
  }) async =>
      throw const OnlineUnavailableException('respondToChallenge');

  @override
  Future<Stream<ChessChallenge>> challengeUpdates() async =>
      throw const OnlineUnavailableException('challengeUpdates');

  @override
  Future<List<LeaderboardEntry>> leaderboard({
    required RatingCategory category,
    int limit = 50,
  }) async =>
      throw const OnlineUnavailableException('leaderboard');
}
