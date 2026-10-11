import '../core/engine/chess_engine.dart';
import 'stockfish_platform.dart';

StockfishPlatform createPlatform() => const StubStockfishPlatform();

/// No Stockfish here (web build / missing natives): always unsupported.
class StubStockfishPlatform implements StockfishPlatform {
  const StubStockfishPlatform();

  @override
  bool get isSupported => false;

  @override
  Future<EngineResult?> search(
    String fen, {
    required int elo,
    required int timeMs,
  }) async =>
      null;
}
