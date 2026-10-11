import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/room_service.dart';
import 'online_sketch_ui.dart';

class OnlineResultScreen extends StatefulWidget {
  const OnlineResultScreen({super.key, required this.roomCode});
  final String roomCode;

  @override
  State<OnlineResultScreen> createState() => _OnlineResultScreenState();
}

class _OnlineResultScreenState extends State<OnlineResultScreen> {
  final _svc = RoomService.instance;
  late final _me = _svc.getPlayerId();
  late final _roomS = _svc.roomStream(widget.roomCode);
  late final _votesS = _svc.voteStream(widget.roomCode).asBroadcastStream();

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _me,
        builder: (_, me) {
          if (me.data == null) return const SketchLoading();
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _roomS,
            builder: (_, snap) {
              if (snap.hasError) return SketchMessage('${snap.error}');
              final d = snap.data?.data();
              if (d == null) {
                return snap.connectionState == ConnectionState.waiting
                    ? const SketchLoading()
                    : const SketchMessage('Room not found.');
              }
              final res = asMap(d['result']);
              if (res.isEmpty) {
                return const SketchMessage('The result is not ready yet.');
              }
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _votesS,
                builder: (_, votes) =>
                    _body(d, res, votes.data?.docs ?? [], d['hostId'] == me.data),
              );
            },
          );
        },
      );

  Future<void> _back() async {
    try {
      await _svc.returnToLobby(roomCode: widget.roomCode);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
  }

  Widget _body(
    Map<String, dynamic> d,
    Map<String, dynamic> res,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> votes,
    bool host,
  ) {
    final players = asMap(d['players']);
    final ids = orderedIds(d);
    final draw = res['isDraw'] == true, won = res['playersWon'] == true;
    final accused = asList(res['accusedPlayerIds']);
    final imps = asList(res['actualImpostorIds']);
    final earned = asMap(res['roundScores']), total = asMap(res['totalScores']);
    final settings = asMap(d['settings']);
    final random = settings['randomImpostorCount'] == true;
    final need = (settings['impostorCount'] as num?)?.toInt() ?? 1;

    int n(Map m, String id) => (m[id] as num?)?.toInt() ?? 0;
    String name(String id) => '${asMap(players[id])['name'] ?? 'Player'}';
    Color col(String id) => kArt[ids.indexOf(id) % kArt.length];

    final counts = <String, int>{};
    var none = 0;
    for (final v in votes) {
      final a = asList(v.data()['accusedPlayerIds']);
      if (a.isEmpty) none++;
      for (final t in a) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }

    List<String> sorted(int Function(String) key) => [...ids]..sort((a, b) {
        final c = key(b).compareTo(key(a));
        return c != 0 ? c : ids.indexOf(a).compareTo(ids.indexOf(b));
      });

    Widget card(Color fill, int seed, String title, List<Widget> rows,
            {double ts = 25}) =>
        SketchBox(
          fill: fill,
          radius: 22,
          seed: seed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(children: [
              Text(title, style: atma(ts)),
              const SizedBox(height: 10),
              ...rows,
            ]),
          ),
        );

    Widget tally(String id, int i) {
      final hi = accused.contains(id);
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hi ? dim(col(id), .55) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(children: [
          SizedBox(
              width: 28,
              child: Text('${ids.indexOf(id) + 1}',
                  style: atma(17, c: dim(kInk, .55)))),
          Expanded(
            child: Text(name(id),
                overflow: TextOverflow.ellipsis,
                style: atma(21, w: hi ? FontWeight.w700 : FontWeight.w500)),
          ),
          Text('${counts[id] ?? 0}', style: atma(22)),
        ]),
      );
    }

    Widget score(String id) {
      final e = n(earned, id);
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: dim(Colors.white, .58),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(children: [
          DoodleCircle(
              size: 38,
              fill: col(id),
              child: Text('${ids.indexOf(id) + 1}', style: atma(20))),
          const SizedBox(width: 10),
          Expanded(
              child: Text(name(id),
                  overflow: TextOverflow.ellipsis, style: atma(20))),
          const SizedBox(width: 8),
          Text('${n(total, id) - e}', style: atma(19, c: dim(kInk, .48))),
          const SizedBox(width: 5),
          Text(e > 0 ? '+$e' : '$e',
              style: atma(21,
                  c: e > 0 ? kMint : e < 0 ? kRed : dim(kInk, .42),
                  w: FontWeight.w900)),
          const SizedBox(width: 5),
          Text('${n(total, id)}', style: atma(23, w: FontWeight.w900)),
        ]),
      );
    }

    final subtitle = draw
        ? 'Nobody reached a majority.'
        : random
            ? (accused.isEmpty
                ? 'The final accusation was NONE.'
                : 'The majority selected the players below.')
            : 'The top $need vote-getters were accused.';

    final header = Column(children: [
      DoodleCircle(
        size: 96,
        fill: draw ? kMarker : won ? kMint : kRed,
        child: draw
            ? Text('=?', style: atma(34, w: FontWeight.w900))
            : Icon(won ? Icons.check_rounded : Icons.close_rounded,
                color: kInk, size: 58),
      ),
      const SizedBox(height: 16),
      SketchText(
        draw ? 'DRAW!' : won ? 'PLAYERS WIN!' : 'IMPOSTORS WIN!',
        draw ? 42 : 38,
        draw || won ? -.022 : .018,
      ),
      const SizedBox(height: 4),
      Text(subtitle,
          textAlign: TextAlign.center, style: atma(20, c: dim(kInk, .68))),
    ]);

    return SketchPage(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 16),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      header,
                      const SizedBox(height: 24),
                      if (votes.isNotEmpty) ...[
                        card(Colors.white, 18, 'VOTE TALLY', [
                          for (final id in sorted((i) => counts[i] ?? 0))
                            tally(id, 0),
                          if (random) ...[
                            const Divider(color: kInk, thickness: 1.4),
                            Row(children: [
                              Expanded(child: Text('NONE', style: atma(19))),
                              Text('$none', style: atma(21)),
                            ]),
                            const SizedBox(height: 6),
                          ],
                        ]),
                        const SizedBox(height: 24),
                      ],
                      card(kMarker, 27, 'POINTS', [
                        Text('THIS ROUND',
                            style: atma(16, c: dim(kInk, .58))),
                        const SizedBox(height: 8),
                        for (final id in sorted((i) => n(earned, i))) score(id),
                      ]),
                      const SizedBox(height: 24),
                      imps.isEmpty
                          ? card(kMint, 33, 'THE TRUTH', [
                              Text('THERE WERE NO IMPOSTORS',
                                  textAlign: TextAlign.center,
                                  style: atma(26, h: .95)),
                              const SizedBox(height: 6),
                            ], ts: 23)
                          : card(kPink, 37, 'THE TRUTH', [
                              for (final id in imps)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Text(name(id),
                                      textAlign: TextAlign.center,
                                      style: atma(28)),
                                ),
                            ], ts: 23),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
            child: SketchButton(
              text: host ? 'BACK TO LOBBY' : 'WAITING FOR HOST...',
              fill: kMarker,
              enabled: host,
              onTap: _back,
            ),
          ),
        ],
      ),
    );
  }
}