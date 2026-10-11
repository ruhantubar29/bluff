import 'dart:async';
import 'dart:isolate';

import '../core/engine/chess_engine.dart';

/// Which kind of search is running. Gameplay and analysis keep separate
/// sequences so a background eval can never cancel the computer's reply.
enum EngineLane { gameplay, analysis }

/// Runs engine searches off the UI thread.
///
/// Every search executes in its own isolate so the board stays at 60fps while
/// the computer "thinks". Stale requests within the same [EngineLane] can be
/// dropped, which is what lets the UI ask for a new line without waiting for
/// the old one.
class EngineRunner {
  EngineRunner._();

  static final EngineRunner instance = EngineRunner._();

  final Map<EngineLane, int> _seq = {
    EngineLane.gameplay: 0,
    EngineLane.analysis: 0,
  };

  final Map<EngineLane, Future<EngineResult>?> _inFlight = {};

  /// Searches [fen] at [level] (difficulty presets) and returns the move the
  /// engine would play plus its evaluation.
  Future<EngineResult> searchAtLevel(
    String fen,
    EngineLevel level, {
    List<String> rootMoves = const [],
    int? seed,
  }) {
    return _run(
      EngineSearchRequest.fromLevel(
        fen: fen,
        level: level,
        seed: seed,
      ),
      lane: EngineLane.gameplay,
      rootMoves: rootMoves,
    );
  }

  /// Custom-strength search for the Elo slider (250–3200). Same lane and
  /// staleness rules as [searchAtLevel].
  Future<EngineResult> searchAtElo(
    String fen,
    int elo, {
    List<String> rootMoves = const [],
    int? seed,
  }) {
    return _run(
      EngineSearchRequest.fromElo(fen: fen, elo: elo, seed: seed),
      lane: EngineLane.gameplay,
      rootMoves: rootMoves,
    );
  }

  /// Analysis-mode search: quiet (no injected error), a bit deeper, used by
  /// the analysis board and game review to show eval + best line.
  ///
  /// Runs on its own lane, so it never cancels a gameplay search.
  Future<EngineResult> analyze(
    String fen, {
    int maxDepth = 7,
    int timeMs = 1500,
    List<String> rootMoves = const [],
  }) {
    return _run(
      EngineSearchRequest(
        fen: fen,
        maxDepth: maxDepth,
        timeMs: timeMs,
        randomSeed: 1,
        noise: 0,
        blunderChance: 0,
        rootMoves: rootMoves,
      ),
      lane: EngineLane.analysis,
      rootMoves: rootMoves,
    );
  }

  /// Drops any queued work on [lane] and searches again. Returns the latest
  /// result for that lane.
  Future<EngineResult> _run(
    EngineSearchRequest request, {
    required EngineLane lane,
    List<String> rootMoves = const [],
  }) async {
    final seq = _seq[lane] = _seq[lane]! + 1;

    final effective = rootMoves.isEmpty && request.rootMoves.isEmpty
        ? request
        : EngineSearchRequest(
            fen: request.fen,
            maxDepth: request.maxDepth,
            timeMs: request.timeMs,
            randomSeed: request.randomSeed,
            noise: request.noise,
            blunderChance: request.blunderChance,
            rootMoves: rootMoves.isEmpty ? request.rootMoves : rootMoves,
          );

    final future = Isolate.run(() => ChessEngine.search(effective));
    _inFlight[lane] = future;
    try {
      final result = await future;
      if (seq != _seq[lane]) {
        // A newer request in this lane superseded this one: return empty so
        // callers that still hold this future don't apply an outdated move.
        return EngineResult.empty;
      }
      return result;
    } finally {
      if (identical(_inFlight[lane], future)) _inFlight.remove(lane);
    }
  }

  /// True while any search is running (drives the "thinking…" indicator).
  bool get isBusy => _inFlight.isNotEmpty;

  /// True while a gameplay search (computer move) is running.
  bool get isGameplayBusy =>
      _inFlight[EngineLane.gameplay] != null;
}
