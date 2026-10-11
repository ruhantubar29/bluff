import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/language/app_language.dart';
import '../../../../core/language/language_settings.dart';
import '../services/room_service.dart';
import 'online_impostor_screen.dart' show BluffColors;
import 'online_round_screen.dart';

const _chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

const _playingStates = {
  'reveal',
  'clue_round_1',
  'clue_round_2',
  'discussion',
  'voting',
  'result',
};

TextStyle _display(
  double s, {
  Color c = BluffColors.cream,
  FontWeight w = FontWeight.w800,
}) =>
    GoogleFonts.balooDa2(
      fontSize: s,
      fontWeight: w,
      color: c,
      height: 1.1,
    );

TextStyle _body(
  double s, {
  Color c = BluffColors.cream,
  FontWeight w = FontWeight.w400,
}) =>
    GoogleFonts.hindSiliguri(
      fontSize: s,
      fontWeight: w,
      color: c,
    );

BoxDecoration _cardDeco() => BoxDecoration(
      color: BluffColors.panel,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: BluffColors.line,
        width: 2,
      ),
      boxShadow: const [
        BoxShadow(
          color: BluffColors.ink,
          offset: Offset(0, 5),
        ),
        BoxShadow(
          color: BluffColors.line,
          offset: Offset(0, 6),
        ),
      ],
    );

// ── Room settings helpers ────────────────────────────────────────────────

dynamic _cfg(
  Map<String, dynamic> d,
  List<String> keys,
) {
  final s =
      d['settings'] is Map
          ? d['settings'] as Map
          : const {};

  for (final k in keys) {
    if (d[k] != null) {
      return d[k];
    }

    if (s[k] != null) {
      return s[k];
    }
  }

  return null;
}

bool _isRandom(
  Map<String, dynamic> d,
) =>
    _cfg(
      d,
      [
        'randomImpostorCount',
        'randomImpostors',
        'random',
      ],
    ) ==
    true;

bool _isAuto(
  Map<String, dynamic> d,
) =>
    _cfg(
      d,
      [
        'autoImpostorCount',
        'autoImpostors',
        'auto',
      ],
    ) ==
    true;

int _impostorCount(
  Map<String, dynamic> d,
) =>
    (_cfg(
          d,
          [
            'impostorCount',
            'impostors',
            'impostor_count',
          ],
        ) as num?)
        ?.toInt() ??
    1;

/// Players needed to start, by impostor count.
const _requiredByImpostors = {
  1: 3,
  2: 5,
  3: 7,
  4: 10,
  5: 13,
  6: 16,
};

/// AUTO impostor count based on the current number of players.
///
/// 1-4  players -> 1 impostor
/// 5-6  players -> 2 impostors
/// 7-9  players -> 3 impostors
/// 10-12 players -> 4 impostors
/// 13-15 players -> 5 impostors
/// 16+   players -> 6 impostors
int _autoImpostorCount(
  int playerCount,
) {
  if (playerCount <= 4) {
    return 1;
  }

  if (playerCount <= 6) {
    return 2;
  }

  if (playerCount <= 9) {
    return 3;
  }

  if (playerCount <= 12) {
    return 4;
  }

  if (playerCount <= 15) {
    return 5;
  }

  return 6;
}

/// Players needed to start.
///
/// Random always needs at least 3.
///
/// AUTO calculates its current impostor count from the
/// current number of players, then uses the normal minimum
/// for that impostor count.
///
/// Fixed 1-6 uses the normal minimum for that count.
int _requiredPlayers(
  Map<String, dynamic> d,
  int playerCount,
) {
  if (_isRandom(d)) {
    return 3;
  }

  if (_isAuto(d)) {
    final count =
        _autoImpostorCount(
      playerCount,
    );

    return _requiredByImpostors[count] ??
        3;
  }

  return _requiredByImpostors[
          _impostorCount(d)] ??
      3;
}

/// Stored host is used if that player is still present.
///
/// If the stored host is gone, the player with the earliest
/// joinedAt becomes the resolved host.
String? _resolveHost(
  Map<String, dynamic> d,
  Map<String, dynamic> players,
) {
  final stored =
      (d['hostId'] ??
              d['hostUid'] ??
              d['host'] ??
              d['ownerId'] ??
              d['createdBy'])
          ?.toString();

  if (stored != null &&
      players.containsKey(stored)) {
    return stored;
  }

  num timeOf(dynamic p) {
    if (p is! Map) {
      return double.infinity;
    }

    final t =
        p['joinedAt'] ??
        p['createdAt'] ??
        p['joined_at'] ??
        p['joinOrder'];

    if (t is Timestamp) {
      return t.millisecondsSinceEpoch;
    }

    if (t is num) {
      return t;
    }

    return double.infinity;
  }

  final keys =
      players.keys.toList();

  keys.sort(
    (a, b) {
      final c =
          timeOf(players[a]).compareTo(
        timeOf(players[b]),
      );

      if (c != 0) {
        return c;
      }

      return a.compareTo(b);
    },
  );

  final resolved =
      keys.isEmpty
          ? null
          : keys.first;

  debugPrint(
    'LOBBY: stored host "$stored" not in players '
    '${players.keys.toList()} -> using $resolved',
  );

  return resolved;
}

class ImpostorLobbyScreen
    extends StatefulWidget {
  const ImpostorLobbyScreen({
    super.key,
    required this.roomCode,
  });

  final String roomCode;

  @override
  State<ImpostorLobbyScreen>
      createState() =>
          _ImpostorLobbyScreenState();
}

class _ImpostorLobbyScreenState
    extends State<ImpostorLobbyScreen>
    with TickerProviderStateMixin {
  bool get _bn =>
      LanguageSettings
          .instance
          .language ==
      AppLanguage.bangla;

  String _tr(
    String en,
    String bn,
  ) =>
      _bn ? bn : en;

  // IMPORTANT:
  // This is the persistent RoomService player ID.
  // It is NOT the Firebase Auth UID.
  String _myUid = '';

  bool _starting = false;
  bool _leaving = false;
  bool _claiming = false;

  DocumentReference<Map<String, dynamic>>?
      _roomRef;

  late final AnimationController _intro =
      AnimationController(
    vsync: this,
    duration:
        const Duration(
      milliseconds: 5000,
    ),
  );

  late final AnimationController _wave =
      AnimationController(
    vsync: this,
    duration:
        const Duration(
      milliseconds: 1200,
    ),
  );

  @override
  void initState() {
    super.initState();

    _loadPlayerId();

    _intro.addStatusListener(
      (s) {
        if (s ==
            AnimationStatus.completed) {
          _idleLoop();
        }
      },
    );

    _intro.forward();
  }

  Future<void> _loadPlayerId() async {
    try {
      final id =
          await RoomService
              .instance
              .getPlayerId();

      if (!mounted) {
        return;
      }

      setState(() {
        _myUid = id;
      });
    } catch (e) {
      debugPrint(
        'LOAD PLAYER ID ERROR: $e',
      );
    }
  }

  /// wait 1s → wave once → wait 1s → wave once → ...
  Future<void> _idleLoop() async {
    try {
      while (mounted) {
        await Future.delayed(
          const Duration(
            seconds: 1,
          ),
        );

        if (!mounted) {
          return;
        }

        await _wave
            .forward(
              from: 0,
            )
            .orCancel;
      }
    } on TickerCanceled {
      // screen closed
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _wave.dispose();
    super.dispose();
  }

  void _snack(
    String m,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            m,
            style: _body(
              15,
              w: FontWeight.w600,
            ),
          ),
          backgroundColor:
              BluffColors.panel2,
          behavior:
              SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),
        ),
      );
  }

  /// Fallback for old/inconsistent rooms.
  ///
  /// Normal host transfer is handled directly inside
  /// RoomService.leaveRoom() transactionally.
  void _claimHost(
    String? stored,
    String? resolved,
  ) {
    if (_claiming ||
        resolved == null ||
        resolved != _myUid ||
        stored == _myUid) {
      return;
    }

    _claiming = true;

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) async {
        try {
          await _roomRef?.update({
            'hostId': _myUid,
          });
        } catch (e) {
          debugPrint(
            'CLAIM HOST ERROR: $e',
          );
        } finally {
          _claiming = false;
        }
      },
    );
  }

  Future<void> _startGame() async {
    if (_starting) {
      return;
    }

    setState(() {
      _starting = true;
    });

    try {
      await RoomService
          .instance
          .startGame(
        roomCode:
            widget.roomCode,
      );
    } catch (e) {
      debugPrint(
        'startGame ERROR: $e',
      );

      if (mounted) {
        setState(() {
          _starting = false;
        });
      }

      _snack(
        '${_tr(
          'Could not start the game.',
          'গেম শুরু করা যায়নি।',
        )}\n$e',
      );
    }
  }

  Future<void> _copy(
    String code,
  ) async {
    await Clipboard.setData(
      ClipboardData(
        text: code,
      ),
    );

    _snack(
      _tr(
        'Room code copied!',
        'Room code কপি হয়েছে!',
      ),
    );
  }

  Future<void> _leave() async {
    if (_leaving) {
      return;
    }

    setState(() {
      _leaving = true;
    });

    try {
      await RoomService
          .instance
          .leaveRoom(
        roomCode:
            widget.roomCode,
      );
    } catch (e) {
      debugPrint(
        'LEAVE ERROR: $e',
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult:
          (didPop, _) {
        if (!didPop) {
          _leave();
        }
      },
      child: Scaffold(
        backgroundColor:
            BluffColors.ink,
        body: Container(
          decoration:
              const BoxDecoration(
            gradient:
                RadialGradient(
              center:
                  Alignment(
                0.9,
                -1.1,
              ),
              radius: 1.1,
              colors: [
                BluffColors.glow,
                Color(
                  0x00F0364F,
                ),
              ],
            ),
          ),
          child: SafeArea(
            child: StreamBuilder<
                DocumentSnapshot<
                    Map<String,
                        dynamic>>>(
              stream:
                  RoomService
                      .instance
                      .roomStream(
                widget.roomCode,
              ),
              builder:
                  (context, snap) {
                if (snap.hasError) {
                  return _message(
                    Icons
                        .error_outline_rounded,
                    _tr(
                      'Could not load the room.',
                      'রুম লোড করা যায়নি।',
                    ),
                  );
                }

                final data =
                    snap.data?.data();

                if (data == null) {
                  return _roomGone();
                }

                _roomRef =
                    snap.data!.reference;

                final code =
                    (data['roomCode']
                                ?.toString()
                                .trim()
                                .toUpperCase()) ??
                        widget.roomCode
                            .trim()
                            .toUpperCase();

                final status =
    data['status']
            ?.toString() ??
        'waiting';

// A completed round can return this same lobby
// screen instance back to "waiting". The previous
// START GAME action may have left _starting == true,
// so reset it once the room is safely back in the lobby.
if (status == 'waiting' && _starting) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;

    if (_starting) {
      setState(() {
        _starting = false;
      });
    }
  });
}

if (_playingStates.contains(status)) {
  return OnlineRoundScreen(
    roomCode: code,
  );
}

                final raw =
                    Map<String,
                        dynamic>.from(
                  data['players'] ??
                      {},
                );

                final hostId =
                    _resolveHost(
                  data,
                  raw,
                );

                _claimHost(
                  data['hostId']
                      ?.toString(),
                  hostId,
                );

                final players =
                    _ordered(
                  raw,
                  hostId,
                );

                final isHost =
                    hostId ==
                    _myUid;

                final random =
                    _isRandom(
                  data,
                );

                final auto =
                    _isAuto(
                  data,
                );

                final autoCount =
                    auto
                        ? _autoImpostorCount(
                            players.length,
                          )
                        : null;

                final required =
                    _requiredPlayers(
                  data,
                  players.length,
                );

                final enough =
                    players.length >=
                        required;

                final canStart =
                    isHost &&
                    enough &&
                    status ==
                        'waiting' &&
                    !_starting;

                String? hint;

                if (isHost &&
                    status ==
                        'waiting' &&
                    !enough) {
                  final n =
                      required -
                          players.length;

                  hint = _tr(
                    'Need $n more player${n == 1 ? '' : 's'}',
                    'আরও $n জন খেলোয়াড় দরকার',
                  );
                }

                final playerCountLabel =
                    random
                        ? '${players.length}'
                        : players.length >=
                                required
                            ? '${players.length}/${players.length}'
                            : '${players.length}/$required';

                return Column(
                  children: [
                    Expanded(
                      child:
                          SingleChildScrollView(
                        physics:
                            const BouncingScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(
                          20,
                          20,
                          20,
                          12,
                        ),
                        child:
                            Column(
                          children: [
                            Text(
                              status !=
                                      'waiting'
                                  ? _tr(
                                      'STARTING GAME',
                                      'গেম শুরু হচ্ছে',
                                    )
                                  : _tr(
                                      'WAITING FOR PLAYERS',
                                      'খেলোয়াড়ের অপেক্ষায়',
                                    ),
                              textAlign:
                                  TextAlign
                                      .center,
                              style:
                                  _display(
                                30,
                              ),
                            ),
                            const SizedBox(
                              height: 16,
                            ),
                            _roomCodeCard(
                              code,
                            ),
                            const SizedBox(
                              height: 24,
                            ),
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .end,
                              children: [
                                Text(
                                  _tr(
                                    'PLAYERS',
                                    'খেলোয়াড়',
                                  ),
                                  style:
                                      _display(
                                    24,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  playerCountLabel,
                                  style:
                                      _display(
                                    22,
                                    c: BluffColors
                                        .gold,
                                  ),
                                ),
                              ],
                            ),
                            if (random)
                              Padding(
                                padding:
                                    const EdgeInsets
                                        .only(
                                  top: 4,
                                ),
                                child:
                                    Align(
                                  alignment:
                                      Alignment
                                          .centerLeft,
                                  child:
                                      Text(
                                    _tr(
                                      '🎲 Random — none to all may be impostors',
                                      '🎲 র‍্যান্ডম — কেউ না থেকে সবাই ইমপোস্টর হতে পারে',
                                    ),
                                    style:
                                        _body(
                                      13,
                                      c: BluffColors
                                          .muted,
                                    ),
                                  ),
                                ),
                              ),
                            if (auto)
                              Padding(
                                padding:
                                    const EdgeInsets
                                        .only(
                                  top: 4,
                                ),
                                child:
                                    Align(
                                  alignment:
                                      Alignment
                                          .centerLeft,
                                  child:
                                      Text(
                                    _tr(
                                      'AUTO • $autoCount impostor${autoCount == 1 ? '' : 's'} based on player count',
                                      'অটো • খেলোয়াড়ের সংখ্যার ভিত্তিতে $autoCount জন ইমপোস্টর',
                                    ),
                                    style:
                                        _body(
                                      13,
                                      c: BluffColors
                                          .muted,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(
                              height: 10,
                            ),
                            Container(
                              width:
                                  double.infinity,
                              decoration:
                                  _cardDeco(),
                              child:
                                  Column(
                                children: [
                                  for (int i =
                                          0;
                                      i <
                                          players.length;
                                      i++)
                                    _playerTile(
                                      players[i]
                                          .key,
                                      players[i]
                                          .value,
                                      hostId,
                                      i ==
                                          players.length -
                                              1,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _bottom(
                      isHost,
                      canStart,
                      hint,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Every device uses the same player order.
  ///
  /// The order is based on the server-side `joinedAt`
  /// timestamp stored by RoomService:
  ///
  ///   1st person to join  -> row 1
  ///   2nd person to join  -> row 2
  ///   3rd person to join  -> row 3
  ///   ...
  ///
  /// The local player (`YOU`) and host status NEVER affect
  /// the player's position in this list.
  ///
  /// If a very old room does not have joinedAt values yet,
  /// player IDs are used as a deterministic fallback so
  /// different devices still produce the same ordering.
  List<MapEntry<String, Map<String, dynamic>>>
      _ordered(
    Map<String, dynamic> raw,
    String? hostId,
  ) {
    final list =
        raw.entries
            .map(
              (e) => MapEntry(
                e.key,
                Map<String,
                    dynamic>.from(
                  e.value ?? {},
                ),
              ),
            )
            .toList();

    num joinedTime(
      Map<String, dynamic> player,
    ) {
      final value =
          player['joinedAt'] ??
          player['createdAt'] ??
          player['joined_at'] ??
          player['joinOrder'];

      if (value is Timestamp) {
        return value.millisecondsSinceEpoch;
      }

      if (value is num) {
        return value;
      }

      return double.infinity;
    }

    list.sort(
      (a, b) {
        final aTime =
            joinedTime(a.value);

        final bTime =
            joinedTime(b.value);

        final timeCompare =
            aTime.compareTo(bTime);

        if (timeCompare != 0) {
          return timeCompare;
        }

        // If both players have no usable joinedAt yet,
        // use the persistent player ID as a deterministic
        // fallback. This does NOT depend on the local device.
        return a.key.compareTo(
          b.key,
        );
      },
    );

    return list;
  }

  Widget _roomCodeCard(
    String code,
  ) =>
      Container(
        width:
            double.infinity,
        padding:
            const EdgeInsets.fromLTRB(
          18,
          16,
          18,
          18,
        ),
        decoration:
            _cardDeco(),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color:
                      BluffColors.gold,
                  size: 22,
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  'ROOM CODE',
                  style:
                      _display(
                    19,
                  ).copyWith(
                    letterSpacing:
                        1.2,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap:
                      () => _copy(
                    code,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  child:
                      const Padding(
                    padding:
                        EdgeInsets.all(
                      8,
                    ),
                    child:
                        Icon(
                      Icons
                          .copy_rounded,
                      color:
                          BluffColors
                              .muted,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                _tr(
                  'Share this code with your friends',
                  'বন্ধুদের সাথে এই কোডটি শেয়ার করুন',
                ),
                style:
                    _body(
                  14,
                  c: BluffColors
                      .muted,
                ),
              ),
            ),
            const SizedBox(
              height: 14,
            ),
            SizedBox(
              height: 74,
              child:
                  FittedBox(
                fit: BoxFit.scaleDown,
                child:
                    Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    for (int i =
                            0;
                        i < 6;
                        i++)
                      Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 3,
                        ),
                        child:
                            _Reel(
                          char:
                              i <
                                      code.length
                                  ? code[i]
                                  : '',
                          index:
                              i,
                          intro:
                              _intro,
                          wave:
                              _wave,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _playerTile(
    String uid,
    Map<String, dynamic> p,
    String? hostId,
    bool last,
  ) {
    final raw =
        p['name']
                ?.toString()
                .trim() ??
            '';

    final name =
        raw.isEmpty
            ? _tr(
                'Player',
                'খেলোয়াড়',
              )
            : raw;

    final host =
        uid == hostId;

    final me =
        uid == _myUid;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 13,
      ),
      decoration:
          BoxDecoration(
        border:
            last
                ? null
                : const Border(
                    bottom:
                        BorderSide(
                      color:
                          BluffColors
                              .line,
                    ),
                  ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment:
                Alignment.center,
            decoration:
                BoxDecoration(
              color:
                  host
                      ? BluffColors
                          .gold
                      : BluffColors
                          .panel2,
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
              border:
                  Border.all(
                color:
                    host
                        ? BluffColors
                            .gold
                        : BluffColors
                            .line,
                width: 2,
              ),
            ),
            child: Text(
              name.characters
                  .first
                  .toUpperCase(),
              style:
                  _display(
                23,
                c:
                    host
                        ? BluffColors
                            .ink
                        : BluffColors
                            .cream,
              ),
            ),
          ),
          const SizedBox(
            width: 13,
          ),
          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  name,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      _display(
                    20,
                    w: FontWeight
                        .w700,
                  ),
                ),
                if (host ||
                    me) ...[
                  const SizedBox(
                    height: 5,
                  ),
                  Row(
                    children: [
                      if (host)
                        _badge(
                          'HOST',
                          BluffColors
                              .gold,
                        ),
                      if (host &&
                          me)
                        const SizedBox(
                          width: 5,
                        ),
                      if (me)
                        _badge(
                          'YOU',
                          Color(
                            0xFF69D17D,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(
    String t,
    Color bg,
  ) =>
      Container(
        padding:
            const EdgeInsets
                .symmetric(
          horizontal: 7,
          vertical: 2,
        ),
        decoration:
            BoxDecoration(
          color: bg,
          borderRadius:
              BorderRadius.circular(
            6,
          ),
        ),
        child: Text(
          t,
          style:
              _display(
            12,
            c:
                BluffColors.ink,
          ).copyWith(
            letterSpacing:
                0.5,
          ),
        ),
      );

  Widget _bottom(
    bool host,
    bool canStart,
    String? hint,
  ) =>
      Container(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12,
        ),
        decoration:
            const BoxDecoration(
          color:
              BluffColors.ink,
          boxShadow: [
            BoxShadow(
              color:
                  Color(0x59000000),
              blurRadius: 20,
              offset:
                  Offset(0, -8),
            ),
          ],
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            if (hint != null)
              Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 8,
                ),
                child: Text(
                  hint,
                  style:
                      _body(
                    13,
                    c: BluffColors
                        .muted,
                  ),
                ),
              ),
            if (host)
              _Chunky(
                label:
                    _starting
                        ? '...'
                        : _tr(
                            'START GAME',
                            'গেম শুরু করুন',
                          ),
                enabled:
                    canStart,
                onTap:
                    _startGame,
                height: 56,
              )
            else
              _Chunky(
                label:
                    _tr(
                  'WAITING FOR HOST',
                  'হোস্টের অপেক্ষায়',
                ),
                enabled:
                    false,
                onTap: () {},
                height: 56,
              ),
            const SizedBox(
              height: 2,
            ),
            TextButton(
              onPressed:
                  _leaving
                      ? null
                      : _leave,
              child: Text(
                _leaving
                    ? _tr(
                        'LEAVING...',
                        'বের হচ্ছি...',
                      )
                    : _tr(
                        'LEAVE ROOM',
                        'রুম থেকে বের হন',
                      ),
                style:
                    _body(
                  14,
                  c: BluffColors
                      .muted,
                  w: FontWeight
                      .w700,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _message(
    IconData icon,
    String text,
  ) =>
      Center(
        child:
            Padding(
          padding:
              const EdgeInsets.all(
            30,
          ),
          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                icon,
                color:
                    BluffColors
                        .cream,
                size: 52,
              ),
              const SizedBox(
                height: 16,
              ),
              Text(
                text,
                textAlign:
                    TextAlign.center,
                style:
                    _display(
                  24,
                  w: FontWeight
                      .w700,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _roomGone() =>
      Center(
        child:
            Padding(
          padding:
              const EdgeInsets.all(
            30,
          ),
          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .no_meeting_room_outlined,
                color:
                    BluffColors
                        .cream,
                size: 52,
              ),
              const SizedBox(
                height: 16,
              ),
              Text(
                _tr(
                  'This room no longer exists.',
                  'রুমটি আর নেই।',
                ),
                textAlign:
                    TextAlign.center,
                style:
                    _display(
                  24,
                  w: FontWeight
                      .w700,
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              _Chunky(
                label:
                    _tr(
                  'GO BACK',
                  'ফিরে যান',
                ),
                onTap:
                    () =>
                        Navigator.of(
                          context,
                        ).pop(),
                height: 52,
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────
//                              JACKPOT REEL
// ─────────────────────────────────────────────────────────────────────────

class _Reel
    extends StatelessWidget {
  const _Reel({
    required this.char,
    required this.index,
    required this.intro,
    required this.wave,
  });

  final String char;
  final int index;
  final AnimationController intro;
  final AnimationController wave;

  static const double _w = 45;
  static const double _h = 64;

  static final _glyphs =
      List<Widget>.generate(
    _chars.length,
    (i) => SizedBox(
      width: _w,
      height: _h,
      child: Center(
        child: Text(
          _chars[i],
          style:
              _display(
            38,
            c: BluffColors
                .cream,
          ),
        ),
      ),
    ),
    growable: false,
  );

  @override
  Widget build(
    BuildContext context,
  ) {
    final target =
        math.max(
      0,
      _chars.indexOf(char),
    );

    final delay =
        index * 0.065;

    final duration =
        0.40 +
            (target /
                    (_chars.length -
                        1)) *
                0.58;

    return RepaintBoundary(
      child:
          AnimatedBuilder(
        animation:
            Listenable.merge([
          intro,
          wave,
        ]),
        builder:
            (_, __) {
          final done =
              intro.isCompleted;

          final t =
              done
                  ? 1.0
                  : Curves
                      .easeOutCubic
                      .transform(
                      ((intro.value -
                                  delay) /
                              duration)
                          .clamp(
                        0.0,
                        1.0,
                      ),
                    );

          final pos =
              target * t;

          final base =
              pos.floor();

          final frac =
              pos - base;

          var scale =
              1.0;

          if (done &&
              wave.isAnimating) {
            final local =
                ((wave.value -
                            index *
                                0.1) /
                        0.5)
                    .clamp(
              0.0,
              1.0,
            );

            scale =
                1 +
                    0.12 *
                        math.sin(
                          math.pi *
                              local,
                        );
          }

          return Transform.scale(
            scale: scale,
            child:
                Container(
              width: _w,
              height: _h,
              clipBehavior:
                  Clip.antiAlias,
              decoration:
                  BoxDecoration(
                color:
                    BluffColors
                        .ink,
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
              ),
              foregroundDecoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
                border:
                    Border.all(
                  color:
                      BluffColors
                          .line,
                  width: 2,
                ),
                gradient:
                    const LinearGradient(
                  begin:
                      Alignment
                          .topCenter,
                  end:
                      Alignment
                          .bottomCenter,
                  colors: [
                    Color(
                      0x9912080B,
                    ),
                    Colors
                        .transparent,
                    Colors
                        .transparent,
                    Color(
                      0x9912080B,
                    ),
                  ],
                  stops: [
                    0,
                    0.17,
                    0.83,
                    1,
                  ],
                ),
              ),
              child:
                  OverflowBox(
                minHeight: 0,
                maxHeight:
                    _h * 2,
                alignment:
                    Alignment
                        .topCenter,
                child:
                    Transform.translate(
                  offset:
                      Offset(
                    0,
                    -frac * _h,
                  ),
                  child:
                      Column(
                    mainAxisSize:
                        MainAxisSize
                            .min,
                    children: [
                      _glyphs[
                        base
                      ],
                      _glyphs[
                        math.min(
                          base + 1,
                          _chars.length - 1,
                        )
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Same chunky press-down button used on the online impostor screen ─────

class _Chunky
    extends StatefulWidget {
  const _Chunky({
    required this.label,
    required this.onTap,
    this.height = 64,
    this.outline = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final double height;
  final bool outline;
  final bool enabled;

  @override
  State<_Chunky> createState() =>
      _ChunkyState();
}

class _ChunkyState
    extends State<_Chunky> {
  bool _down = false;

  @override
  Widget build(
    BuildContext context,
  ) {
    final e =
        widget.enabled;

    final o =
        widget.outline;

    final fill =
        !e || o
            ? BluffColors
                .panel2
            : BluffColors
                .red;

    final border =
        !e || o
            ? BluffColors
                .line
            : BluffColors
                .redLight;

    final shadow =
        !e || o
            ? BluffColors
                .line
            : BluffColors
                .redDeep;

    return GestureDetector(
      behavior:
          HitTestBehavior
              .opaque,
      onTapDown:
          e
              ? (_) =>
                  setState(
                    () =>
                        _down =
                            true,
                  )
              : null,
      onTapUp:
          e
              ? (_) =>
                  setState(
                    () =>
                        _down =
                            false,
                  )
              : null,
      onTapCancel:
          e
              ? () =>
                  setState(
                    () =>
                        _down =
                            false,
                  )
              : null,
      onTap:
          e
              ? widget.onTap
              : null,
      child:
          SizedBox(
        width:
            double.infinity,
        height:
            widget.height +
                7,
        child:
            Stack(
          children: [
            AnimatedPositioned(
              duration:
                  const Duration(
                milliseconds:
                    80,
              ),
              top:
                  _down
                      ? 5
                      : 0,
              left: 0,
              right: 0,
              child:
                  Container(
                height:
                    widget.height,
                alignment:
                    Alignment
                        .center,
                decoration:
                    BoxDecoration(
                  color:
                      fill,
                  borderRadius:
                      BorderRadius
                          .circular(
                    18,
                  ),
                  border:
                      Border.all(
                    color:
                        border,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          shadow,
                      offset:
                          Offset(
                        0,
                        _down
                            ? 2
                            : 7,
                      ),
                    ),
                  ],
                ),
                child:
                    Text(
                  widget.label,
                  style:
                      _display(
                    widget.height >
                            50
                        ? 20
                        : 16,
                    c:
                        e
                            ? BluffColors
                                .cream
                            : BluffColors
                                .muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}