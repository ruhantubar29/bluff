import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/impostor_player.dart';
import '../models/impostor_settings.dart';

class BluffColors {
  static const ink = Color(0xFF12080B);
  static const panel = Color(0xFF241118);
  static const panel2 = Color(0xFF33171F);
  static const line = Color(0xFF4A222D);

  static const red = Color(0xFFF0364F);
  static const redDeep = Color(0xFFA8162D);
  static const redLight = Color(0xFFFF7A8C);

  static const cream = Color(0xFFFFEFE3);
  static const muted = Color(0xFFC39AA3);

  static const gold = Color(0xFFFFC94A);
  static const goldTint = Color(0x33FFC94A);

  static const glow = Color(0x47F0364F);

  static const avatars = [
    Color(0xFFFFC94A),
    Color(0xFF7FD6FF),
    Color(0xFFFF8FB1),
    Color(0xFF9BE28A),
    Color(0xFFC9A7FF),
  ];
}

TextStyle bluffDisplay(
  double size, {
  Color color = BluffColors.cream,
  FontWeight weight = FontWeight.w800,
  double letterSpacing = 0,
}) {
  return GoogleFonts.balooDa2(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.1,
    letterSpacing: letterSpacing,
  );
}

TextStyle bluffBody(
  double size, {
  Color color = BluffColors.cream,
  FontWeight w = FontWeight.w400,
}) {
  return GoogleFonts.hindSiliguri(
    fontSize: size,
    fontWeight: w,
    color: color,
  );
}

BoxDecoration bluffCard() {
  return BoxDecoration(
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
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.players,
  });

  final List<ImpostorPlayer> players;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerEntry {
  _PlayerEntry(ImpostorPlayer player)
      : id = _nextId++,
        player = player.copyWith(),
        controller = TextEditingController(
          text: player.name,
        );

  static int _nextId = 0;

  final int id;
  final ImpostorPlayer player;
  final TextEditingController controller;
  final FocusNode focus = FocusNode();

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class _PlayerScreenState extends State<PlayerScreen> {
  final ScrollController _scroll = ScrollController();

  late final List<_PlayerEntry> _entries;

  @override
  void initState() {
    super.initState();

    _entries = widget.players
        .map(_PlayerEntry.new)
        .toList();

    while (_entries.length <
        ImpostorSettings.minPlayers) {
      _entries.add(
        _PlayerEntry(
          ImpostorPlayer(
            name: 'Player ${_entries.length + 1}',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();

    for (final entry in _entries) {
      entry.dispose();
    }

    super.dispose();
  }

  bool get _canAdd =>
      _entries.length <
      ImpostorSettings.maxPlayers;

  bool get _canRemove =>
      _entries.length >
      ImpostorSettings.minPlayers;

  void _add() {
    if (!_canAdd) {
      return;
    }

    final entry = _PlayerEntry(
      ImpostorPlayer(
        name: 'Player ${_entries.length + 1}',
        score: 0,
      ),
    );

    setState(() {
      _entries.add(entry);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration:
              const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }

      entry.focus.requestFocus();
    });
  }

  void _remove(_PlayerEntry entry) {
    if (!_canRemove) {
      return;
    }

    setState(() {
      _entries.remove(entry);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      entry.dispose();
    });
  }

  Future<void> _resetPoints() async {
    FocusScope.of(context).unfocus();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: BluffColors.panel,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(22),
            side: const BorderSide(
              color: BluffColors.line,
              width: 2,
            ),
          ),
          title: Text(
            'Reset Points?',
            style: bluffDisplay(24),
          ),
          content: Text(
            'All players will be set back to 0 points.',
            style: bluffBody(
              16,
              color: BluffColors.muted,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(
                'CANCEL',
                style: bluffDisplay(
                  15,
                  color: BluffColors.muted,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(
                'RESET',
                style: bluffDisplay(
                  15,
                  color: BluffColors.redLight,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      for (final entry in _entries) {
        entry.player.score = 0;
      }
    });
  }

  void _done() {
    final players = <ImpostorPlayer>[];

    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];

      final name = entry.controller.text.trim();

      players.add(
        entry.player.copyWith(
          name: name.isEmpty
              ? 'Player ${i + 1}'
              : name,
        ),
      );
    }

    Navigator.of(context).pop(players);
  }

  @override
  Widget build(BuildContext context) {
    final count = _entries.length;

    return Scaffold(
      backgroundColor: BluffColors.ink,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.9, -1.1),
            radius: 1.1,
            colors: [
              BluffColors.glow,
              Color(0x00F0364F),
            ],
          ),
        ),
        child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    14,
                    18,
                    0,
                  ),
                  child: Row(
                    children: [
                      Material(
                        color: BluffColors.panel2,
                        shape: const CircleBorder(
                          side: BorderSide(
                            color: BluffColors.line,
                            width: 2,
                          ),
                        ),
                        child: InkWell(
                          customBorder:
                              const CircleBorder(),
                          onTap: () {
                            Navigator.of(context)
                                .maybePop();
                          },
                          child: const SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(
                              Icons
                                  .arrow_back_rounded,
                              color:
                                  BluffColors.cream,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Transform.rotate(
                        angle: -0.035,
                        child: Text(
                          'Players',
                          style: bluffDisplay(
                            30,
                          ).copyWith(
                            shadows: const [
                              Shadow(
                                color:
                                    BluffColors
                                        .redDeep,
                                offset:
                                    Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    10,
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: [
                      Text(
                        '$count Players',
                        style: bluffDisplay(
                          20,
                          weight:
                              FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${ImpostorSettings.minPlayers}'
                        '–'
                        '${ImpostorSettings.maxPlayers}',
                        style: bluffBody(
                          14,
                          color:
                              BluffColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.separated(
                    controller: _scroll,
                    padding:
                        const EdgeInsets.fromLTRB(
                      18,
                      4,
                      18,
                      16,
                    ),
                    itemCount: count,
                    separatorBuilder:
                        (_, __) =>
                            const SizedBox(
                      height: 14,
                    ),
                    itemBuilder: (_, index) {
                      return _PlayerRow(
                        key: ValueKey(
                          _entries[index].id,
                        ),
                        index: index,
                        entry: _entries[index],
                        canRemove:
                            _canRemove,
                        onRemove: () {
                          _remove(
                            _entries[index],
                          );
                        },
                      );
                    },
                  ),
                ),

                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    18,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _resetPoints,
                          icon: const Icon(
                            Icons
                                .restart_alt_rounded,
                            size: 21,
                          ),
                          label: Text(
                            'Reset Points',
                            style: bluffDisplay(
                              18,
                              weight:
                                  FontWeight.w700,
                            ),
                          ),
                          style:
                              OutlinedButton
                                  .styleFrom(
                            foregroundColor:
                                BluffColors.redLight,
                            side:
                                const BorderSide(
                              color:
                                  BluffColors.line,
                              width: 2,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                18,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child:
                            OutlinedButton.icon(
                          onPressed:
                              _canAdd
                                  ? _add
                                  : null,
                          icon: const Icon(
                            Icons
                                .add_circle_outline_rounded,
                            size: 22,
                          ),
                          label: Text(
                            'Add Player',
                            style: bluffDisplay(
                              19,
                              weight:
                                  FontWeight.w700,
                            ),
                          ),
                          style:
                              OutlinedButton
                                  .styleFrom(
                            foregroundColor:
                                BluffColors
                                    .gold,
                            disabledForegroundColor:
                                BluffColors
                                    .line,
                            side: BorderSide(
                              color: _canAdd
                                  ? BluffColors
                                      .gold
                                  : BluffColors
                                      .line,
                              width: 2,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                20,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      _ChunkyButton(
                        label: 'DONE',
                        onTap: _done,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    super.key,
    required this.index,
    required this.entry,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final _PlayerEntry entry;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final avatarColor =
        BluffColors.avatars[
            index %
                BluffColors.avatars.length];

    final score = entry.player.score;

    return Container(
      decoration: bluffCard(),
      padding: const EdgeInsets.fromLTRB(
        12,
        10,
        6,
        10,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor,
            ),
            child: Text(
              '${index + 1}',
              style: bluffDisplay(
                18,
                color: BluffColors.ink,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: TextField(
              controller: entry.controller,
              focusNode: entry.focus,
              maxLength: 16,
              textInputAction:
                  TextInputAction.done,
              textCapitalization:
                  TextCapitalization.words,
              cursorColor: BluffColors.gold,
              style: bluffBody(
                18,
                w: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                counterText: '',
                hintText:
                    'Player ${index + 1}',
                hintStyle: bluffBody(
                  18,
                  color: BluffColors.muted,
                ),
              ),
              onSubmitted: (_) {
                FocusScope.of(context)
                    .unfocus();
              },
            ),
          ),

          // SCORE
          Container(
            constraints:
                const BoxConstraints(
              minWidth: 42,
            ),
            padding:
                const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: score == 0
                  ? BluffColors.panel2
                  : BluffColors.goldTint,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Text(
              '$score',
              textAlign: TextAlign.center,
              style: bluffDisplay(
                18,
                color: score < 0
                    ? BluffColors.redLight
                    : BluffColors.gold,
                weight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(width: 2),

          IconButton(
            onPressed:
                canRemove ? onRemove : null,
            tooltip: 'Remove player',
            icon: const Icon(
              Icons
                  .delete_outline_rounded,
            ),
            color: BluffColors.redLight,
            disabledColor:
                BluffColors.line,
          ),
        ],
      ),
    );
  }
}

class _ChunkyButton extends StatefulWidget {
  const _ChunkyButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<_ChunkyButton> createState() =>
      _ChunkyButtonState();
}

class _ChunkyButtonState
    extends State<_ChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _down = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _down = false;
        });
      },
      onTapCancel: () {
        setState(() {
          _down = false;
        });
      },
      onTap: widget.onTap,
      child: SizedBox(
        width: double.infinity,
        height: 71,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration:
                  const Duration(
                milliseconds: 80,
              ),
              top: _down ? 5 : 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 80,
                ),
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BluffColors.red,
                  borderRadius:
                      BorderRadius.circular(22),
                  border: Border.all(
                    color:
                        BluffColors.redLight,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          BluffColors.redDeep,
                      offset: Offset(
                        0,
                        _down ? 2 : 7,
                      ),
                    ),
                  ],
                ),
                child: Text(
                  widget.label,
                  style: bluffDisplay(
                    24,
                    letterSpacing: 1,
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