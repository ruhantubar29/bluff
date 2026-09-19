import 'package:flutter/material.dart';

class ImpostorCountScreen extends StatefulWidget {
  const ImpostorCountScreen({
    super.key,
    required this.playerCount,
    required this.selectedCount,
    this.randomEnabled = false,
  });

  final int playerCount;
  final int selectedCount;
  final bool randomEnabled;

  @override
  State<ImpostorCountScreen> createState() =>
      _ImpostorCountScreenState();
}

class _ImpostorCountScreenState
    extends State<ImpostorCountScreen> {
  late bool _randomEnabled;
  late int _selectedCount;

  @override
  void initState() {
    super.initState();

    _randomEnabled = widget.randomEnabled;
    _selectedCount = widget.selectedCount;

    final maximum = _maximumImpostors(
      widget.playerCount,
    );

    if (_selectedCount < 1 ||
        _selectedCount > maximum) {
      _selectedCount = 1;
    }
  }

  int _maximumImpostors(int players) {
    if (players >= 16) {
      return 6;
    }

    if (players >= 13) {
      return 5;
    }

    if (players >= 10) {
      return 4;
    }

    if (players >= 7) {
      return 3;
    }

    if (players >= 5) {
      return 2;
    }

    return 1;
  }

  int _minimumPlayersFor(int impostors) {
    switch (impostors) {
      case 1:
        return 3;
      case 2:
        return 5;
      case 3:
        return 7;
      case 4:
        return 10;
      case 5:
        return 13;
      case 6:
        return 16;
      default:
        return 3;
    }
  }

  bool _isAvailable(int count) {
    return count <= _maximumImpostors(
      widget.playerCount,
    );
  }

  void _selectCount(int count) {
    if (!_isAvailable(count)) {
      return;
    }

    setState(() {
      _selectedCount = count;
    });
  }

  void _toggleRandom(bool value) {
    setState(() {
      _randomEnabled = value;

      final maximum = _maximumImpostors(
        widget.playerCount,
      );

      if (_selectedCount > maximum) {
        _selectedCount = maximum;
      }
    });
  }

  void _done() {
    Navigator.pop(
      context,
      ImpostorCountSelection(
        count: _selectedCount,
        randomEnabled: _randomEnabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _BluffColors.ink,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.9, -1.1),
            radius: 1.15,
            colors: [
              _BluffColors.glow,
              Color(0x00F0364F),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
            ),
            child: Column(
              children: [
                // HEADER
                Padding(
                  padding: const EdgeInsets.only(
                    top: 14,
                  ),
                  child: Row(
                    children: [
                      Material(
                        color: _BluffColors.panel2,
                        shape: const CircleBorder(
                          side: BorderSide(
                            color: _BluffColors.line,
                            width: 2,
                          ),
                        ),
                        child: InkWell(
                          customBorder:
                              const CircleBorder(),
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: const SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: _BluffColors.cream,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Transform.rotate(
                        angle: -0.035,
                        child: Text(
                          'Impostors',
                          style:
                              _bluffDisplay(30).copyWith(
                            shadows: const [
                              Shadow(
                                color:
                                    _BluffColors.redDeep,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // RANDOM CARD
                _RandomCard(
                  value: _randomEnabled,
                  onChanged: _toggleRandom,
                ),

                const SizedBox(height: 22),

                // SECTION TITLE
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _randomEnabled
                        ? 'Random impostor count'
                        : 'Number of impostors',
                    style: _bluffDisplay(20).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // GRID
                Expanded(
                  child: AnimatedOpacity(
                    duration:
                        const Duration(milliseconds: 200),
                    opacity:
                        _randomEnabled ? 0.35 : 1,
                    child: IgnorePointer(
                      ignoring: _randomEnabled,
                      child: GridView.builder(
                        padding:
                            const EdgeInsets.only(
                          bottom: 14,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                        itemCount: 6,
                        itemBuilder:
                            (context, index) {
                          final count = index + 1;

                          return _CountCard(
                            count: count,
                            selected:
                                _selectedCount ==
                                    count,
                            available:
                                _isAvailable(count),
                            randomEnabled:
                                _randomEnabled,
                            minimumPlayers:
                                _minimumPlayersFor(
                              count,
                            ),
                            onTap: () {
                              _selectCount(count);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // DONE
                _DoneButton(
                  onTap: _done,
                ),

                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RandomCard extends StatelessWidget {
  const _RandomCard({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _bluffCard(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            onChanged(!value);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value
                        ? _BluffColors.goldTint
                        : _BluffColors.panel2,
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.casino_rounded,
                    color: _BluffColors.cream,
                    size: 23,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Random impostor count',
                        style: _bluffBody(
                          16,
                          weight:
                              FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'There could be no impostor — or everyone could be one',
                        style: _bluffBody(
                          13.5,
                          color:
                              _BluffColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),

                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor:
                      _BluffColors.cream,
                  activeTrackColor:
                      _BluffColors.red,
                  inactiveThumbColor:
                      _BluffColors.muted,
                  inactiveTrackColor:
                      _BluffColors.panel2,
                  trackOutlineColor:
                      WidgetStateProperty
                          .resolveWith(
                    (states) {
                      if (states.contains(
                        WidgetState.selected,
                      )) {
                        return _BluffColors
                            .redLight;
                      }

                      return _BluffColors.line;
                    },
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

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.count,
    required this.selected,
    required this.available,
    required this.randomEnabled,
    required this.minimumPlayers,
    required this.onTap,
  });

  final int count;
  final bool selected;
  final bool available;
  final bool randomEnabled;
  final int minimumPlayers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label =
        count == 1 ? 'impostor' : 'impostors';

    final subtitle = available
        ? randomEnabled
            ? 'possible'
            : 'exactly $count'
        : 'needs $minimumPlayers players';

    return AnimatedContainer(
      duration:
          const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      transformAlignment: Alignment.center,
      transform: Matrix4.identity()
        ..rotateZ(
          selected ? -0.035 : 0,
        )
        ..scale(
          selected ? 1.045 : 1,
          selected ? 1.045 : 1,
          1.0,
        ),
      decoration: BoxDecoration(
        color: selected
            ? _BluffColors.red
            : _BluffColors.panel2,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? _BluffColors.redLight
              : _BluffColors.line,
          width: 2,
        ),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color:
                      _BluffColors.redDeep,
                  offset: Offset(0, 5),
                ),
              ]
            : const [],
      ),
      child: Opacity(
        opacity: available ? 1 : 0.42,
        child: Material(
          color: Colors.transparent,
          borderRadius:
              BorderRadius.circular(20),
          child: InkWell(
            borderRadius:
                BorderRadius.circular(20),
            onTap:
                available ? onTap : null,
            child: Center(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  if (!available)
                    const Icon(
                      Icons.lock_rounded,
                      color:
                          _BluffColors.muted,
                      size: 27,
                    )
                  else
                    Text(
                      '$count',
                      style:
                          _bluffDisplay(38),
                    ),

                  const SizedBox(height: 2),

                  Text(
                    label,
                    style: _bluffBody(
                      12,
                      color: selected
                          ? _BluffColors.cream
                          : _BluffColors.muted,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitle,
                    textAlign:
                        TextAlign.center,
                    style: _bluffBody(
                      11,
                      color: selected
                          ? _BluffColors.cream
                          : _BluffColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: Material(
        color: _BluffColors.red,
        borderRadius:
            BorderRadius.circular(18),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(18),
              border: Border.all(
                color:
                    _BluffColors.redLight,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color:
                      _BluffColors.redDeep,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: const Center(
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_rounded,
                    color:
                        _BluffColors.cream,
                    size: 22,
                  ),
                  SizedBox(width: 9),
                  Text(
                    'DONE',
                    style: TextStyle(
                      color:
                          _BluffColors.cream,
                      fontSize: 19,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BluffColors {
  static const ink =
      Color(0xFF090708);

  static const panel2 =
      Color(0xFF171013);

  static const line =
      Color(0xFF392328);

  static const red =
      Color(0xFFD9273F);

  static const redLight =
      Color(0xFFF05A6D);

  static const redDeep =
      Color(0xFF7A1425);

  static const cream =
      Color(0xFFFFF3E1);

  static const muted =
      Color(0xFFB8A5A8);

  static const glow =
      Color(0x33F0364F);

  static const goldTint =
      Color(0x332C2110);
}

TextStyle _bluffDisplay(
  double size, {
  FontWeight weight =
      FontWeight.w800,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: _BluffColors.cream,
    letterSpacing: -0.4,
  );
}

TextStyle _bluffBody(
  double size, {
  Color color =
      _BluffColors.cream,
  FontWeight weight =
      FontWeight.w400,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
  );
}

BoxDecoration _bluffCard() {
  return BoxDecoration(
    color: _BluffColors.panel2,
    borderRadius:
        BorderRadius.circular(22),
    border: Border.all(
      color: _BluffColors.line,
      width: 2,
    ),
  );
}

class ImpostorCountSelection {
  const ImpostorCountSelection({
    required this.count,
    required this.randomEnabled,
  });

  final int count;
  final bool randomEnabled;
}