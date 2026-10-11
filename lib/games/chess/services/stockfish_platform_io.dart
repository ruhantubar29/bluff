import 'dart:async';
import 'dart:io';

import 'package:stockfish/stockfish.dart';

import '../core/engine/chess_engine.dart';
import 'stockfish_platform.dart';

StockfishPlatform createPlatform() => IoStockfishPlatform();

/// Native Stockfish via `package:stockfish` (FFI).
///
/// The package bundles binaries for Android and iOS only, so [isSupported]
/// gates every call and one failed start disables further attempts — a broken
/// engine must never stall a game; the built-in Dart engine takes over.
class IoStockfishPlatform implements StockfishPlatform {
  Stockfish? _sf;
  StreamSubscription<String>? _sub;
  bool _failed = false;

  // Per-search stdout bookkeeping.
  final List<_Waiter> _waiters = [];
  int _scoreCp = 0;
  bool _scoreMate = false;
  int _depth = 0;

  @override
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<EngineResult?> search(
    String fen, {
    required int elo,
    required int timeMs,
  }) async {
    final sf = await _ensure();
    if (sf == null) return null;
    try {
      // Stockfish's limit-strength band (1350–3190); weaker slider values
      // clamp to the floor and still play below named-bot strength.
      final sfElo = elo.clamp(1350, 3190);
      sf.stdin = 'setoption name UCI_LimitStrength value true';
      sf.stdin = 'setoption name UCI_Elo value $sfElo';
      sf.stdin = 'ucinewgame';
      sf.stdin = 'position fen $fen';

      _scoreCp = 0;
      _scoreMate = false;
      _depth = 0;
      // Register the waiter before sending `go` so an instant reply can't
      // arrive before we start listening.
      final bestmove = _expect(
        (line) => line.startsWith('bestmove'),
        const Duration(seconds: 15),
      );
      sf.stdin = 'go movetime $timeMs';
      final line = await bestmove;
      if (line == null) return null;
      return _toResult(line, fen, timeMs);
    } catch (_) {
      _failed = true; // engine died mid-game: fail over for good
      return null;
    }
  }

  // ---------------------------------------------------------------- engine --

  Future<Stockfish?> _ensure() async {
    if (_failed || !isSupported) return null;
    final current = _sf;
    if (current != null && current.state.value == StockfishState.ready) {
      return current;
    }
    try {
      final sf = await stockfishAsync().timeout(const Duration(seconds: 4));
      _sf = sf;
      await _sub?.cancel();
      _sub = sf.stdout.listen(_onLine);

      final uciOk = _expect((l) => l.trim() == 'uciok', const Duration(seconds: 3));
      sf.stdin = 'uci';
      if (await uciOk == null) throw StateError('stockfish: no uciok');

      final readyOk = _expect((l) => l.trim() == 'readyok', const Duration(seconds: 3));
      sf.stdin = 'isready';
      if (await readyOk == null) throw StateError('stockfish: no readyok');
      return sf;
    } catch (_) {
      _failed = true;
      _sf = null;
      return null;
    }
  }

  void _onLine(String line) {
    if (line.startsWith('info')) {
      final depth = RegExp(r'\bdepth (\d+)').firstMatch(line);
      if (depth != null) _depth = int.tryParse(depth.group(1)!) ?? _depth;
      final score = RegExp(r'score (cp|mate) (-?\d+)').firstMatch(line);
      if (score != null) {
        _scoreMate = score.group(1) == 'mate';
        _scoreCp = int.tryParse(score.group(2) ?? '') ?? _scoreCp;
      }
    }
    for (final waiter in List<_Waiter>.of(_waiters)) {
      if (waiter.test(line)) {
        _waiters.remove(waiter);
        if (!waiter.completer.isCompleted) waiter.completer.complete(line);
      }
    }
  }

  Future<String?> _expect(bool Function(String line) test, Duration timeout) {
    final completer = Completer<String?>();
    final waiter = _Waiter(test, completer);
    _waiters.add(waiter);
    Timer(timeout, () {
      _waiters.remove(waiter);
      if (!completer.isCompleted) completer.complete(null);
    });
    return completer.future;
  }

  EngineResult? _toResult(String bestmoveLine, String fen, int timeMs) {
    final parts = bestmoveLine.trim().split(RegExp(r'\s+'));
    if (parts.length < 2 || parts.first != 'bestmove') return null;
    final uci = parts[1];
    if (uci == '(none)') return EngineResult.empty;
    if (uci.length < 4) return null;

    // Scores arrive from the side to move's point of view (UCI convention).
    final scoreCp = _scoreMate ? (_scoreCp > 0 ? 30000 : -30000) : _scoreCp;
    final whiteToMove = fen.split(' ').length > 1 && fen.split(' ')[1] == 'w';
    return EngineResult(
      from: uci.substring(0, 2),
      to: uci.substring(2, 4),
      promotion: uci.length > 4 ? uci.substring(4, 5) : null,
      scoreCp: scoreCp,
      whiteScoreCp: whiteToMove ? scoreCp : -scoreCp,
      depth: _depth,
      pv: const [],
      nodes: 0,
      moveTimeMs: timeMs,
      bestSan: null,
      isMate: false,
      mateInPly: 0,
    );
  }
}

class _Waiter {
  _Waiter(this.test, this.completer);

  final bool Function(String line) test;
  final Completer<String?> completer;
}
