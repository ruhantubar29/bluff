import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/room_service.dart';
import 'package:bluff/games/impostor/screens/game_screen.dart' show RevealScreen;
import 'online_result_screen.dart';
import 'online_vote_screen.dart';

const _paper = Color(0xFFFFF3DC);
const _ink = Color(0xFF1B1013);
const _marker = Color(0xFFFFD23F);
const _mint = Color(0xFF9BE28A);
const _sky = Color(0xFF7FD6FF);
const _pink = Color(0xFFFF8FB1);
const _lav = Color(0xFFC9A7FF);
const _orange = Color(0xFFFFA45C);
const _red = Color(0xFFD92F45);
const _white = Color(0xFFFFFCF5);
const _pop = [_sky, _pink, _mint, _lav, _orange];
const _turnMs = 25000;
const _turnSecs = 25;

typedef Json = Map<String, dynamic>;

TextStyle _t(double s, {Color c = _ink, FontWeight w = FontWeight.w700}) =>
    GoogleFonts.atma(fontSize: s, fontWeight: w, color: c, height: 1.15);

Color _dim(Color c, double a) => c.withValues(alpha: a);

Map _map(dynamic v) => v is Map ? v : const {};

/// Sticker box: thick outline, hard shadow, presses down when tapped.
class _Box extends StatefulWidget {
  const _Box({
    required this.child,
    this.color = _white,
    this.radius = 16,
    this.border = 2.5,
    this.shadow = 4,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
  });

  final Widget child;
  final Color color;
  final double radius, border, shadow;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  State<_Box> createState() => _BoxState();
}

class _BoxState extends State<_Box> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final s = _down ? 0.0 : w.shadow;
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      transform: Matrix4.translationValues(w.shadow - s, w.shadow - s, 0),
      padding: w.padding,
      decoration: BoxDecoration(
        color: w.color,
        borderRadius: BorderRadius.circular(w.radius),
        border: Border.all(color: _ink, width: w.border),
        boxShadow: s > 0 ? [BoxShadow(color: _ink, offset: Offset(s, s))] : null,
      ),
      child: w.child,
    );
    if (w.onTap == null) return box;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        w.onTap!();
      },
      onTapCancel: () => setState(() => _down = false),
      child: box,
    );
  }
}

class OnlineRoundScreen extends StatefulWidget {
  const OnlineRoundScreen({super.key, required this.roomCode});
  final String roomCode;

  @override
  State<OnlineRoundScreen> createState() => _OnlineRoundScreenState();
}

class _OnlineRoundScreenState extends State<OnlineRoundScreen> {
  final _svc = RoomService.instance;
  late final _roomS = _svc.roomStream(widget.roomCode);
  final _clue = TextEditingController();
  final _secs = ValueNotifier<int>(_turnSecs);
  final _mine = ValueNotifier<Json?>(null);
  final _busy = <String>{};

  StreamSubscription? _mineSub;
  Timer? _timer;
  Json _data = {};
  String _playerId = '', _turnKey = '';
  DateTime _turnSeen = DateTime.now();
  bool _expiring = false, _ready = false;

  @override
  void initState() {
    super.initState();
    _svc.getPlayerId().then((id) {
      if (mounted) setState(() => _playerId = id);
    }).catchError((_) {});
    _mineSub = _svc.privatePlayerStream(widget.roomCode).listen(
          (s) => _mine.value = s.data() ?? {},
          onError: (_) {},
        );
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mineSub?.cancel();
    _secs.dispose();
    _mine.dispose();
    _clue.dispose();
    super.dispose();
  }

  // ── Logic ──────────────────────────────────────────────────────────────

  String get _uid => _playerId;

  bool _isClue(Json d) =>
      d['status'] == 'clue_round_1' || d['status'] == 'clue_round_2';

  /// Milliseconds left, counted on THIS phone from when the turn appeared,
  /// so wrong device clocks can never expire someone else's turn.
  int _leftMs() =>
      _turnMs - DateTime.now().difference(_turnSeen).inMilliseconds;

  void _tick() {
    if (!mounted || !_isClue(_data)) return;
    final ms = _leftMs();
    final s = (ms / 1000).ceil().clamp(0, _turnSecs).toInt();
    if (_secs.value != s) _secs.value = s;

    if (_expiring) return;
    // Only the player on turn expires it; the host is a fallback after 3s.
    final mine = _data['currentCluePlayerId'] == _uid;
    final host = _data['hostId'] == _uid;
    if (!((mine && ms <= 0) || (host && ms <= -3000))) return;

    _expiring = true;
    _svc
        .expireClueTurn(
          roomCode: widget.roomCode,
          playerId: '${_data['currentCluePlayerId']}',
          round: (_data['clueRound'] as num?)?.toInt(),
        )
        .catchError((_) {})
        .whenComplete(() => Future.delayed(
              const Duration(seconds: 2),
              () => _expiring = false,
            ));
  }

  Future<void> _run(String key, Future<void> Function() job) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await job();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  void _submitClue() {
    final t = _clue.text.trim();
    if (t.isEmpty) return;
    _run('clue', () async {
      await _svc.submitClue(roomCode: widget.roomCode, text: t);
      _clue.clear();
    });
  }

  void _skip() => _run('skip', () async {
        await _svc.skipClue(roomCode: widget.roomCode);
        _clue.clear();
      });

  void _vote() =>
      _run('vote', () => _svc.startVoting(roomCode: widget.roomCode));

  // Reveal sync only (not the removed lobby READY system).
  void _markReady() => _run('ready', () async {
        await _svc.markRevealReady(roomCode: widget.roomCode);
        if (mounted) setState(() => _ready = true);
      });

  // ── Build ──────────────────────────────────────────────────────────────

  static const _loader = Center(child: CircularProgressIndicator());

  @override
  Widget build(BuildContext context) {
    if (_playerId.isEmpty) {
      return const Scaffold(backgroundColor: _paper, body: _loader);
    }
    return StreamBuilder<DocumentSnapshot<Json>>(
      stream: _roomS,
      builder: (context, snap) {
        Widget page(Widget w) =>
            Scaffold(backgroundColor: _paper, body: SafeArea(child: w));

        if (snap.hasError) return page(_msg('${snap.error}'));
        final d = snap.data?.data();
        if (d == null) {
          return page(snap.connectionState == ConnectionState.waiting
              ? _loader
              : _msg('The room could not be found.'));
        }

        _data = d;
        final key = '${d['matchId']}_${d['currentCluePlayerId']}_${d['clueRound']}';
        if (key != _turnKey) {
          _turnKey = key;
          _turnSeen = DateTime.now();
          _expiring = false;
          _secs.value = _turnSecs;
        }

        final status = d['status'] as String? ?? 'waiting';
        if (status == 'voting') return OnlineVoteScreen(roomCode: widget.roomCode);
        if (status == 'result') return OnlineResultScreen(roomCode: widget.roomCode);

        if (_isClue(d) || status == 'discussion') {
          _ready = false;
          return page(_round(d));
        }

        return ValueListenableBuilder<Json?>(
          valueListenable: _mine,
          builder: (_, pd, __) {
            if (pd == null || pd.isEmpty) {
              return const Scaffold(backgroundColor: _red, body: _loader);
            }
            return _reveal(d, pd);
          },
        );
      },
    );
  }

  /// The exact local reveal screen (same card, curve, hop button, doodles).
  Widget _reveal(Json d, Json pd) {
    final pl = _map(d['players']);
    final order = List<String>.from(d['playerOrder'] ?? []);
    final n = pl.values.where((p) => p is Map && p['revealReady'] == true).length;
    final done = _ready || pd['revealed'] == true;

    final imp = pd['role'] == 'impostor';
    final hint = (pd['hint'] as String?)?.trim() ?? '';
    final raw = _map(pl[_uid])['name'];
    final name = raw is String && raw.trim().isNotEmpty ? raw.trim() : 'YOUR CARD';
    final ch = ((pd['character'] as num?)?.toInt() ?? _uid.hashCode.abs()) % 35;

    return RevealScreen(
      key: ValueKey('reveal_${d['matchId']}'),
      playerName: name,
      playerIndex: math.max(0, order.indexOf(_uid)),
      total: order.length,
      isImpostor: imp,
      secretTitle: imp ? 'Impostor' : '${pd['secretWord'] ?? 'Unknown'}',
      secretHint: imp && hint.isNotEmpty ? hint : null,
      secretCategory: imp ? null : pd['category'] as String?,
      characterAsset: 'assets/images/characters/character_${ch + 1}.png',
      onNext: done || _busy.contains('ready') ? () {} : _markReady,
      onClose: () => Navigator.of(context).maybePop(),
      nextLabel: done ? 'READY ✓  $n/${pl.length}' : 'I AM READY ✓',
      passHint: 'Waiting for everyone to be ready',
    );
  }

  Widget _msg(String m) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(m, textAlign: TextAlign.center, style: _t(22)),
        ),
      );

  Widget _round(Json d) {
    final isClue = _isClue(d);
    final myTurn = isClue && d['currentCluePlayerId'] == _uid;
    return Column(
      children: [
        _header(d, isClue, myTurn),
        Expanded(child: _players(d, isClue)),
        if (myTurn) _clueBar(),
        if (!isClue) _voteBar(_uid == d['hostId']),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _header(Json d, bool isClue, bool myTurn) {
    final who =
        '${_map(_map(d['players'])[d['currentCluePlayerId']])['name'] ?? 'Player'}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: _white,
        border: Border(bottom: BorderSide(color: _ink, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<Json?>(
                  valueListenable: _mine,
                  builder: (_, pd, __) => _peek(pd ?? {}),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<int>(
                  valueListenable: _secs,
                  builder: (_, s, __) {
                    final out = isClue && s == 0;
                    final line = !isClue
                        ? 'DISCUSSION · bluff, accuse, defend'
                        : out
                            ? 'TIME OUT · $who'
                            : myTurn
                                ? 'YOUR TURN · give your clue!'
                                : '$who · clue ${d['clueRound'] ?? 1}';
                    return Text(line,
                        style: _t(18, c: out ? _red : _dim(_ink, .7)));
                  },
                ),
              ],
            ),
          ),
          if (isClue) ...[const SizedBox(width: 12), _ring()],
        ],
      ),
    );
  }

  Widget _peek(Json pd) {
    final imp = pd['role'] == 'impostor';
    final hint = (pd['hint'] as String?)?.trim() ?? '';

    Widget tag(String label, String value, Color bg, Color lc, Color vc,
            double vs, double hp) =>
        Flexible(
          child: _Box(
            color: bg,
            radius: 14,
            padding: EdgeInsets.symmetric(horizontal: hp, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _t(12, c: lc)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(vs, c: vc)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        tag(
          imp ? 'YOUR ROLE' : 'YOUR WORD',
          imp ? 'IMPOSTOR' : '${pd['secretWord'] ?? '?'}',
          imp ? _red : _mint,
          imp ? _dim(_white, .8) : _dim(_ink, .6),
          imp ? _white : _ink,
          26,
          14,
        ),
        if (imp && hint.isNotEmpty) ...[
          const SizedBox(width: 8),
          tag('HINT', hint, _marker, _dim(_ink, .6), _ink, 20, 12),
        ],
      ],
    );
  }

  Widget _ring() => ValueListenableBuilder<int>(
        valueListenable: _secs,
        builder: (_, s, __) {
          final urgent = s <= 5;
          return SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: s / _turnSecs,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    backgroundColor: _dim(_ink, .12),
                    color: urgent ? _red : _ink,
                  ),
                ),
                Text(
                  s == 0 ? 'TIME\nOUT' : '$s',
                  textAlign: TextAlign.center,
                  style: _t(s == 0 ? 13 : 24, c: urgent ? _red : _ink),
                ),
              ],
            ),
          );
        },
      );

  // ── Players + clues ────────────────────────────────────────────────────

  Widget _players(Json d, bool isClue) {
    final order = List<String>.from(d['playerOrder'] ?? []);
    if (order.isEmpty) return _loader;

    final players = _map(d['players']);
    final clues = _map(d['clues']);
    final cur = d['currentCluePlayerId'];
    final round = (d['clueRound'] as num?)?.toInt() ?? 1;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      itemCount: order.length,
      itemBuilder: (_, i) {
        final id = order[i];
        final c = _map(clues[id]);
        final name = '${_map(players[id])['name'] ?? 'Player'}';
        final now = isClue && cur == id;

        bool has(int j) =>
            c['clue$j'] is String && (c['clue$j'] as String).trim().isNotEmpty;
        bool skip(int j) => c['skip$j'] == true;
        bool out(int j) => c['out$j'] == true;
        final any = [1, 2].any((j) => has(j) || skip(j) || out(j));

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Box(
            color: now ? _marker : _white,
            shadow: now ? 5 : 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _avatar(name, _pop[i % _pop.length]),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(id == _uid ? '$name (YOU)' : name, style: _t(21)),
                      if (!any)
                        Text(now ? 'thinking…' : '—',
                            style: _t(16, c: _dim(_ink, .45), w: FontWeight.w500)),
                      for (var j = 1; j <= 2; j++)
                        if (has(j))
                          _clueChip(j, c['clue$j'] as String, j == round)
                        else if (skip(j))
                          _flagChip(j, 'SKIPPED')
                        else if (out(j))
                          _flagChip(j, 'TIME OUT'),
                    ],
                  ),
                ),
                if (now)
                  _Box(
                    color: _sky,
                    radius: 8,
                    border: 1.5,
                    shadow: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Text(id == _uid ? 'YOU' : 'NOW', style: _t(12)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _avatar(String name, Color color) => Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: _ink, width: 2.5),
        ),
        child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
            style: _t(20)),
      );

  Widget _chip(Color bg, Color border, double bw, double vp, Widget child) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: vp),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: bw),
        ),
        child: child,
      );

  Widget _clueChip(int n, String text, bool latest) => _chip(
        latest ? _mint : _dim(_ink, .05),
        latest ? _ink : _dim(_ink, .25),
        latest ? 2 : 1,
        6,
        Text.rich(TextSpan(children: [
          TextSpan(text: '#$n  ', style: _t(13, c: _dim(_ink, .5))),
          TextSpan(
            text: text,
            style: _t(latest ? 20 : 16,
                w: latest ? FontWeight.w700 : FontWeight.w500),
          ),
        ])),
      );

  Widget _flagChip(int n, String label) => _chip(
        _dim(_red, .14),
        _dim(_ink, .3),
        1,
        5,
        Text('#$n  $label', style: _t(15, c: _red)),
      );

  // ── Action bars ────────────────────────────────────────────────────────

  Widget _btn(String label, Color color, VoidCallback? onTap,
          {bool busy = false}) =>
      Opacity(
        opacity: onTap == null && !busy ? .5 : 1,
        child: _Box(
          color: color,
          onTap: busy ? null : onTap,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(label, style: _t(20)),
          ),
        ),
      );

  static const _barPad = EdgeInsets.fromLTRB(14, 6, 14, 10);

  Widget _clueBar() => Padding(
        padding: _barPad,
        child: Column(
          children: [
            _field(_clue, 'Write your clue…', lines: 2),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ListenableBuilder(
                    listenable: _clue,
                    builder: (_, __) => _btn(
                      'GIVE CLUE',
                      _marker,
                      _clue.text.trim().isEmpty || _busy.isNotEmpty
                          ? null
                          : _submitClue,
                      busy: _busy.contains('clue'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _btn('SKIP', _white, _busy.isEmpty ? _skip : null,
                    busy: _busy.contains('skip')),
              ],
            ),
          ],
        ),
      );

  Widget _voteBar(bool host) => Padding(
        padding: _barPad,
        child: host
            ? SizedBox(
                width: double.infinity,
                child: _btn('START VOTING 🗳️', _pink, _vote,
                    busy: _busy.contains('vote')),
              )
            : _Box(
                shadow: 0,
                child: SizedBox(
                  width: double.infinity,
                  child: Text('Waiting for host to start voting…',
                      textAlign: TextAlign.center, style: _t(17)),
                ),
              ),
      );

  Widget _field(TextEditingController c, String hint, {int lines = 1}) {
    OutlineInputBorder ob(double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _ink, width: w),
        );
    return TextField(
      controller: c,
      minLines: 1,
      maxLines: lines,
      maxLength: 300,
      textCapitalization: TextCapitalization.sentences,
      style: _t(18, w: FontWeight.w500),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: _t(18, c: _dim(_ink, .4), w: FontWeight.w500),
        filled: true,
        fillColor: _white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: ob(2),
        enabledBorder: ob(2),
        focusedBorder: ob(3),
      ),
    );
  }
}