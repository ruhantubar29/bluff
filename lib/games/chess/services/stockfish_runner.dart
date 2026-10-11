import '../core/engine/chess_engine.dart';
import 'stockfish_platform.dart';
import 'stockfish_platform_stub.dart'
    if (dart.library.io) 'stockfish_platform_io.dart' as platform;

/// Native Stockfish behind a small, honest interface.
///
/// The bundled `stockfish` package ships binaries for Android and iOS only.
/// On any other platform (Windows/macOS/Linux desktop, web, widget tests)
/// [search] answers null immediately and the game falls back to the built-in
/// Dart engine — no pretending Stockfish ran when it didn't.
class StockfishRunner {
  StockfishRunner._();

  static final StockfishRunner instance = StockfishRunner._();

  late final StockfishPlatform _impl = platform.createPlatform();

  /// True when this device actually bundles a Stockfish binary.
  bool get isSupported => _impl.isSupported;

  /// Searches [fen] with Stockfish limited to [elo] for [timeMs].
  /// Null means "no Stockfish here" — fall back to the built-in engine.
  Future<EngineResult?> search(
    String fen, {
    required int elo,
    required int timeMs,
  }) =>
      _impl.search(fen, elo: elo, timeMs: timeMs);
}
