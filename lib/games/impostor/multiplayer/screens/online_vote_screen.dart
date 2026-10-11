import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/room_service.dart';
import 'online_result_screen.dart';
import 'online_sketch_ui.dart';

class OnlineVoteScreen extends StatefulWidget {
  const OnlineVoteScreen({super.key, required this.roomCode});
  final String roomCode;

  @override
  State<OnlineVoteScreen> createState() => _OnlineVoteScreenState();
}

class _OnlineVoteScreenState extends State<OnlineVoteScreen> {
  final _svc = RoomService.instance;
  late final _me = _svc.getPlayerId();
  late final _roomS = _svc.roomStream(widget.roomCode);
  late final _voteS =
      _svc.currentPlayerVoteStream(widget.roomCode).asBroadcastStream();

  final _sel = <String>{};
  bool _busy = false, _voted = false, _finalizing = false, _left = false;

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _me,
        builder: (_, me) {
          final id = me.data;
          if (id == null) return const SketchLoading();

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

              if (d['status'] == 'result') {
                if (!_left) {
                  _left = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) =>
                          OnlineResultScreen(roomCode: widget.roomCode),
                    ));
                  });
                }
                return const SketchLoading();
              }

              final settings = asMap(d['settings']);
              final random = settings['randomImpostorCount'] == true;
              final need = (settings['impostorCount'] as num?)?.toInt() ?? 1;
              final submitted = (d['votesSubmitted'] as num?)?.toInt() ?? 0;
              final ids = orderedIds(d);
              final total = ids.length;

              // Only the host finalizes; everyone else follows the status.
              if (d['status'] == 'voting' &&
                  d['hostId'] == id &&
                  total > 0 &&
                  submitted >= total &&
                  !_finalizing) {
                _finalize();
              }

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _voteS,
                builder: (_, v) {
                  final done = _voted || (v.data?.exists ?? false);
                  return SketchPage(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                          child: Row(
                            children: [
                              const Expanded(
                                  child: SketchText('VOTE', 34, -.018)),
                              ProgressBadge(submitted, total),
                            ],
                          ),
                        ),
                        Expanded(
                          child: done
                              ? _waiting(submitted, total)
                              : _ballot(d, ids, id, random, need),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      );

  void _finalize() {
    _finalizing = true; // no setState: we're inside a builder
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await _svc.finalizeVoting(roomCode: widget.roomCode);
      } catch (_) {
        _finalizing = false;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await _svc.submitVote(
          roomCode: widget.roomCode, accusedPlayerIds: _sel.toList());
      if (mounted) setState(() => _voted = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
  }

  // ── Ballot ─────────────────────────────────────────────────────────────

  Widget _ballot(Map<String, dynamic> d, List<String> all, String me,
      bool random, int need) {
    final players = asMap(d['players']);
    final ids = all.where((k) => k != me).toList();
    final none = random && _sel.isEmpty;

    void toggle(String id) => setState(() {
          if (!_sel.remove(id) && _sel.length < need) _sel.add(id);
        });

    Widget sub(String t) => Text(t,
        textAlign: TextAlign.center, style: atma(17, c: dim(kInk, .62)));

    return Column(
      children: [
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: random
              ? Column(children: [
                  Text('WHO DO YOU THINK ARE THE IMPOSTORS?',
                      textAlign: TextAlign.center, style: atma(23, h: .95)),
                  const SizedBox(height: 4),
                  sub(none
                      ? 'NONE selected — tap a player to choose players.'
                      : '${_sel.length} selected • you may choose 1 to $need'),
                ])
              : Column(children: [
                  Text('SELECT EXACTLY $need', style: atma(27)),
                  const SizedBox(height: 2),
                  sub('${_sel.length} / $need selected'),
                ]),
        ),
        const SizedBox(height: 10),
        if (random)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: SketchBox(
              fill: none ? kLav : Colors.white,
              radius: 20,
              stroke: none ? 3.5 : 2.5,
              seed: 81,
              shadow: none ? const Offset(4, 4) : const Offset(2, 3),
              onTap: () => setState(_sel.clear),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    DoodleCircle(
                        size: 46, fill: kMarker, child: Text('0', style: atma(26))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NONE', style: atma(26)),
                          Text('I think there are no impostors.',
                              style: atma(16,
                                  c: dim(kInk, .62), w: FontWeight.w400)),
                        ],
                      ),
                    ),
                    DoodleCheck(checked: none),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
            itemCount: ids.length,
            itemBuilder: (_, i) {
              final id = ids[i];
              final on = _sel.contains(id);
              final accent = kArt[i % kArt.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SketchBox(
                  fill: on ? accent : Colors.white,
                  radius: 19,
                  stroke: on ? 3.5 : 2.5,
                  seed: i + 51,
                  shadow: const Offset(3, 4),
                  onTap: () => toggle(id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        DoodleCircle(
                            size: 46,
                            fill: accent,
                            child: Text('${i + 1}', style: atma(24))),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            '${asMap(players[id])['name'] ?? 'Player'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: atma(25),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DoodleCheck(checked: on),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: SketchButton(
            text: _busy
                ? 'SUBMITTING...'
                : random
                    ? (none ? 'VOTE NONE' : 'SUBMIT VOTE')
                    : 'SUBMIT ${_sel.length}/$need',
            fill: none ? kLav : kMint,
            enabled: !_busy && (random || _sel.length == need),
            onTap: _submit,
          ),
        ),
      ],
    );
  }

  // ── Waiting ────────────────────────────────────────────────────────────

  Widget _waiting(int submitted, int total) {
    final all = total > 0 && submitted >= total;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DoodleCircle(
              size: 96,
              fill: all ? kMarker : kMint,
              child: Icon(all ? Icons.auto_awesome : Icons.how_to_vote_rounded,
                  color: kInk, size: 52),
            ),
            const SizedBox(height: 18),
            SketchText(all ? 'VOTES LOCKED!' : 'VOTE LOCKED!', 36, -.02),
            const SizedBox(height: 8),
            Text(
              all ? 'Calculating the result...' : 'Waiting for the other players...',
              textAlign: TextAlign.center,
              style: atma(21, c: dim(kInk, .68)),
            ),
            const SizedBox(height: 18),
            Text('$submitted / $total voted',
                style: atma(25, c: dim(kInk, .55))),
          ],
        ),
      ),
    );
  }
}