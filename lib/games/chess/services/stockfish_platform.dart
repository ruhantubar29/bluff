import '../core/engine/chess_engine.dart';

/// Contract implemented per platform: the real native engine on devices that
/// ship it, a stub everywhere else (web, desktop, tests).
abstract class StockfishPlatform {
  /// Whether a Stockfish binary exists on this platform.
  bool get isSupported;

  /// Searches [fen] with Stockfish limited to [elo] for [timeMs].
  ///
  /// Returns null whenever Stockfish is unavailable or fails, so callers can
  /// honestly fall back to the built-in Dart engine instead of guessing.
  Future<EngineResult?> search(
    String fen, {
    required int elo,
    required int timeMs,
  });
}
