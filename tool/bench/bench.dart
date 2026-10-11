// ignore_for_file: avoid_print
import 'package:chess/chess.dart';

void main() {
  final sw = Stopwatch()..start();
  int nodes = 0;
  void descend(Chess game, int depth) {
    if (depth == 0) {
      nodes++;
      return;
    }
    final moves = game.generate_moves();
    for (final m in moves) {
      game.make_move(m);
      descend(game, depth - 1);
      game.undo_move();
    }
  }

  descend(Chess(), 4);
  sw.stop();
  print('depth4 nodes=$nodes in ${sw.elapsedMilliseconds}ms '
      '(${(nodes / sw.elapsedMilliseconds * 1000).round()} nps)');

  // Kiwipete perft sanity (famous test position)
  final k = Chess.fromFEN(
      'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1');
  print('kiwipete perft(3)=${k.perft(3)} (expect 97862)');

  final sw2 = Stopwatch()..start();
  descend(Chess(), 5);
  sw2.stop();
  print('depth5 nodes=$nodes total in ${sw2.elapsedMilliseconds}ms');
}
