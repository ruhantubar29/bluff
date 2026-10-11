import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/language/app_language.dart';
import '../../../../core/language/language_settings.dart';
import '../../logic/word_deck.dart';
import '../services/room_service.dart';
import 'impostor_lobby_screen.dart';

// NOTE: identical palette/type-scale to ImpostorScreen (local game setup).
// If that file is importable from here, delete this block and import
// BluffColors / the _display/_body helpers from there instead.
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
}

const Map<String, String> _categoryEmojis = {
  'Animals': '🐾',
  'Food': '🍔',
  'Superheroes': '🦸',
  'Sports': '⚽',
  'Countries': '🌍',
  'Jobs': '💼',
  'Fruits': '🍎',
  'Cartoons': '📺',
  'Brands': '🏷️',
  'Anime': '🍥',
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

const _nameKey = 'bluff_player_name';

/// Each entry button (CREATE ROOM / JOIN ROOM) lives in its own slot.
/// Tapping a button grows that exact slot into a card in place — like a
/// cell dividing — via AnimatedSize; the OTHER slot's button is untouched
/// and never moves. Every deeper step (impostor count, categories, name)
/// happens *inside* the same growing slot too, so it's always the same
/// grow/shrink motion — never a full-screen swap or a separate popup.
class OnlineImpostorScreen extends StatefulWidget {
  const OnlineImpostorScreen({super.key});

  @override
  State<OnlineImpostorScreen> createState() => _OnlineImpostorScreenState();
}

class _OnlineImpostorScreenState extends State<OnlineImpostorScreen> {
  final _code = TextEditingController();

  // Which slot (if any) is expanded. Only one at a time — activating one
  // collapses the other back down to its plain button automatically,
  // since each slot only shows its card while it is the active one.
  String? _active; // null | 'create' | 'join'

  // Stage *within* the active slot — this is what animates inside the box.
  String _createStage = 'settings'; // settings -> impostors/categories -> name
  String _joinStage = 'code'; // code -> name

  bool _busy = false;
  int _impostorCount = 1;
  bool _random = false;
  bool _auto = true;
  bool _hints = true;

  late List<String> _categories;
  late Set<String> _selected;

  AppLanguage get _lang => LanguageSettings.instance.language;
  bool get _bn => _lang == AppLanguage.bangla;

  String _tr(String en, String bn) => _bn ? bn : en;

  @override
  void initState() {
    super.initState();
    _categories = ImpostorWordDeck.instance.categories(_lang);
    _selected = {..._categories};
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
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
        backgroundColor: BluffColors.panel2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );

  int get _maxImpostors => 6;

  String get _impostorBadge {
    if (_random) return '🎲';
    if (_auto) return 'AUTO';
    return '$_impostorCount';
  }

  String get _impostorSubtitle {
    if (_random) {
      return _tr(
        'Random from 0 to maximum',
        '০ থেকে সর্বোচ্চ পর্যন্ত র‍্যান্ডম',
      );
    }

    if (_auto) {
      return _tr(
        'Automatically based on players',
        'খেলোয়াড়ের সংখ্যার উপর ভিত্তি করে',
      );
    }

    return _tr(
      '$_impostorCount impostor${_impostorCount == 1 ? '' : 's'} selected',
      '$_impostorCount জন ইমপোস্টর নির্বাচিত',
    );
  }

  bool get _allCategories =>
      _selected.length == _categories.length;

  String get _categoryTitle => _allCategories
      ? _tr(
          'All Categories',
          'সব ক্যাটাগরি',
        )
      : _tr(
          '${_selected.length} Categories',
          '${_selected.length}টি ক্যাটাগরি',
        );

  String get _categorySubtitle {
    if (_selected.isEmpty) {
      return _tr(
        'Pick at least one',
        'কমপক্ষে একটি বেছে নিন',
      );
    }

    final list = _selected.toList();
    final shown = list.take(3).join(', ');
    final extra = list.length - 3;

    return extra > 0 ? '$shown  +$extra more' : shown;
  }

  // ── Slot toggles ──────────────────────────────────────────────────────
  void _toggleCreate() => setState(() {
        _active = _active == 'create' ? null : 'create';
        _createStage = 'settings';
      });

  void _toggleJoin() => setState(() {
        _active = _active == 'join' ? null : 'join';
        _joinStage = 'code';
      });

  void _startJoin() {
    if (_code.text.trim().length != 6) {
      _snack(
        _tr(
          'Enter a valid 6-character room code.',
          '৬ অক্ষরের সঠিক রুম কোড দিন।',
        ),
      );
      return;
    }

    setState(() => _joinStage = 'name');
  }

  void _startCreate() {
    if (_selected.isEmpty) {
      _snack(
        _tr(
          'Select at least one category.',
          'কমপক্ষে একটি ক্যাটাগরি নির্বাচন করুন।',
        ),
      );
      return;
    }

    setState(() => _createStage = 'name');
  }

  Future<void> _finish(String name) async {
    final joining = _active == 'join';

    setState(() => _busy = true);

    try {
      if (joining) {
        final code = _code.text.trim().toUpperCase();

        await RoomService.instance.joinRoom(
          roomCode: code,
          playerName: name,
        );

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImpostorLobbyScreen(
              roomCode: code,
            ),
          ),
        );
      } else {
        final code = await RoomService.instance.createRoom(
          playerName: name,
          impostorCount: _impostorCount,
          randomImpostorCount: _random,
          autoImpostorCount: _auto,
          hintsEnabled: _hints,
          categories: _selected.toList(),
          roomType: 'private',
        );

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImpostorLobbyScreen(
              roomCode: code,
            ),
          ),
        );
      }
    } catch (e) {
      _snack(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );

      if (mounted) {
        setState(() => _busy = false);
      }

      return;
    }

    if (mounted) {
      setState(() {
        _busy = false;
        _active = null;
        _createStage = 'settings';
        _joinStage = 'code';
        _code.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              14,
              18,
              20,
            ),
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 420,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '?',
                              style: _display(
                                64,
                                c: BluffColors.gold,
                              ).copyWith(
                                shadows: const [
                                  Shadow(
                                    color: BluffColors.redDeep,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _tr(
                                'Create a room or join with a code.',
                                'একটি রুম তৈরি করুন অথবা কোড দিয়ে যোগ দিন।',
                              ),
                              textAlign: TextAlign.center,
                              style: _body(
                                14.5,
                                c: BluffColors.muted,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _createSlot(),
                            const SizedBox(height: 14),
                            _joinSlot(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
        children: [
          _iconBtn(
            Icons.arrow_back_rounded,
            BluffColors.line,
            () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 12),
          Transform.rotate(
            angle: -0.03,
            child: Text(
              _tr(
                'IMPOSTOR',
                'ইমপোস্টর',
              ),
              style: _display(28).copyWith(
                shadows: const [
                  Shadow(
                    color: BluffColors.redDeep,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          const Text(
            '🕵️',
            style: TextStyle(fontSize: 40),
          ),
        ],
      );

  Widget _iconBtn(
    IconData icon,
    Color border,
    VoidCallback onTap,
  ) =>
      Material(
        color: BluffColors.panel2,
        shape: CircleBorder(
          side: BorderSide(
            color: border,
            width: 2,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              color: BluffColors.cream,
              size: 21,
            ),
          ),
        ),
      );

  // Wraps a slot's current content (button OR growing card) so the box
  // resize is always animated, and content changes inside it crossfade
  // rather than pop.
  Widget _slot({
    required bool open,
    required Widget Function() button,
    required Widget Function() box,
  }) =>
      AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: open ? box() : button(),
      );

  Widget _grownBox({
    required String stageKey,
    required Widget child,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          16,
          18,
          16,
          12,
        ),
        decoration: _cardDeco(),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: child,
          ),
          child: KeyedSubtree(
            key: ValueKey(stageKey),
            child: child,
          ),
        ),
      );

  // ── CREATE slot ──────────────────────────────────────────────────────
  Widget _createSlot() => _slot(
        open: _active == 'create',
        button: () => _Chunky(
          label: _tr(
            'CREATE ROOM',
            'রুম তৈরি করুন',
          ),
          onTap: _toggleCreate,
        ),
        box: () => _grownBox(
          stageKey: _createStage,
          child: _createStageContent(),
        ),
      );

  Widget _createStageContent() {
    switch (_createStage) {
      case 'impostors':
        return _impostorStage();

      case 'categories':
        return _categoryStage();

      case 'name':
        return _NamePanel(
          isJoin: false,
          bangla: _bn,
          busy: _busy,
          onCancel: () => setState(
            () => _createStage = 'settings',
          ),
          onDone: _finish,
        );

      case 'settings':
      default:
        return Column(
          key: const ValueKey('createSettings'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _tr(
                'ROOM SETTINGS',
                'রুম সেটিংস',
              ),
              textAlign: TextAlign.center,
              style: _display(21),
            ),
            const SizedBox(height: 14),
            _setupTile(
              leading: _badge(
                Text(
                  _impostorBadge,
                  style: _auto
                      ? _display(
                          15,
                          w: FontWeight.w800,
                        )
                      : _display(28),
                ),
              ),
              title: _tr(
                'Impostor Count',
                'ইমপোস্টর সংখ্যা',
              ),
              subtitle: _impostorSubtitle,
              onTap: () => setState(
                () => _createStage = 'impostors',
              ),
            ),
            const SizedBox(height: 12),
            _hintRow(),
            const SizedBox(height: 12),
            _setupTile(
              leading: _badge(
                const Text(
                  '🗂️',
                  style: TextStyle(fontSize: 26),
                ),
              ),
              title: _categoryTitle,
              subtitle: _categorySubtitle,
              onTap: () => setState(
                () => _createStage = 'categories',
              ),
            ),
            const SizedBox(height: 18),
            _Chunky(
              label: _tr(
                'CREATE ROOM',
                'রুম তৈরি করুন',
              ),
              onTap: _startCreate,
              height: 54,
            ),
            Center(
              child: TextButton(
                onPressed: _toggleCreate,
                child: Text(
                  _tr(
                    'CANCEL',
                    'বাতিল',
                  ),
                  style: _body(
                    12,
                    c: BluffColors.muted,
                    w: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }

  // ── Impostor grid stage ──────────────────────────────────────────────
  // Mirrors the offline ImpostorCountScreen:
  // Random toggle + Auto + 1–6 count cards + DONE.
  Widget _impostorStage() => Column(
        key: const ValueKey('impostorGrid'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _iconBtn(
                Icons.arrow_back_rounded,
                BluffColors.line,
                () => setState(
                  () => _createStage = 'settings',
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _tr(
                  'IMPOSTORS',
                  'ইমপোস্টর',
                ),
                style: _display(22),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _randomToggle(),
          const SizedBox(height: 18),
          Text(
            _random
                ? _tr(
                    'Random impostor count',
                    'র‍্যান্ডম ইমপোস্টর সংখ্যা',
                  )
                : _auto
                    ? _tr(
                        'Auto impostor count',
                        'অটো ইমপোস্টর সংখ্যা',
                      )
                    : _tr(
                        'Number of impostors',
                        'ইমপোস্টরের সংখ্যা',
                      ),
            style: _display(
              16,
              w: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _random ? 0.35 : 1,
            child: IgnorePointer(
              ignoring: _random,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.95,
                ),
                itemCount: _maxImpostors + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _autoCard();
                  }

                  return _countCard(i);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Chunky(
            label: '✓  ${_tr('DONE', 'সম্পন্ন')}',
            onTap: () => setState(
              () => _createStage = 'settings',
            ),
            height: 52,
          ),
        ],
      );

  Widget _randomToggle() => Container(
        decoration: BoxDecoration(
          color: BluffColors.panel2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: BluffColors.line,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() {
              _random = !_random;

              if (_random) {
                _auto = false;
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _random
                          ? BluffColors.goldTint
                          : BluffColors.panel,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.casino_rounded,
                      color: BluffColors.cream,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tr(
                            'Random impostor count',
                            'র‍্যান্ডম ইমপোস্টর সংখ্যা',
                          ),
                          style: _body(
                            15,
                            w: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _tr(
                            'There could be no impostor — or everyone could be one',
                            'কোনো ইমপোস্টর নাও থাকতে পারে — অথবা সবাই হতে পারে',
                          ),
                          style: _body(
                            12.5,
                            c: BluffColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _random,
                    onChanged: (v) => setState(() {
                      _random = v;

                      if (_random) {
                        _auto = false;
                      }
                    }),
                    activeThumbColor: BluffColors.cream,
                    activeTrackColor: BluffColors.red,
                    inactiveThumbColor: BluffColors.muted,
                    inactiveTrackColor: BluffColors.panel,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _countCard(int count) {
    final selected =
        !_random && !_auto && _impostorCount == count;

    final label = count == 1
        ? _tr(
            'impostor',
            'ইমপোস্টর',
          )
        : _tr(
            'impostors',
            'ইমপোস্টর',
          );

    final subtitle = _tr(
      'exactly $count',
      'ঠিক $count',
    );

    return GestureDetector(
      onTap: () => setState(() {
        _impostorCount = count;
        _auto = false;
        _random = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateZ(
            selected ? -0.035 : 0,
          )
          ..scale(
            selected ? 1.045 : 1.0,
            selected ? 1.045 : 1.0,
            1.0,
          ),
        decoration: BoxDecoration(
          color: selected
              ? BluffColors.red
              : BluffColors.panel2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? BluffColors.redLight
                : BluffColors.line,
            width: 2,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: BluffColors.redDeep,
                    offset: Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: _display(30),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: _body(
                  11,
                  c: selected
                      ? BluffColors.cream
                      : BluffColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: _body(
                  10,
                  c: selected
                      ? BluffColors.cream
                      : BluffColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── AUTO impostor card ───────────────────────────────────────────────
  // Same visual treatment as the 1–6 cards.
  Widget _autoCard() {
    final selected = !_random && _auto;

    return GestureDetector(
      onTap: () => setState(() {
        _auto = true;
        _random = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateZ(
            selected ? -0.035 : 0,
          )
          ..scale(
            selected ? 1.045 : 1.0,
            selected ? 1.045 : 1.0,
            1.0,
          ),
        decoration: BoxDecoration(
          color: selected
              ? BluffColors.red
              : BluffColors.panel2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? BluffColors.redLight
                : BluffColors.line,
            width: 2,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: BluffColors.redDeep,
                    offset: Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AUTO',
                style: _display(24),
              ),
              const SizedBox(height: 2),
              Text(
                _tr(
                  'impostors',
                  'ইমপোস্টর',
                ),
                style: _body(
                  11,
                  c: selected
                      ? BluffColors.cream
                      : BluffColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _tr(
                  'based on players',
                  'খেলোয়াড় অনুযায়ী',
                ),
                textAlign: TextAlign.center,
                style: _body(
                  10,
                  c: selected
                      ? BluffColors.cream
                      : BluffColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── JOIN slot ────────────────────────────────────────────────────────
  Widget _joinSlot() => _slot(
        open: _active == 'join',
        button: () => _Chunky(
          label: _tr(
            'JOIN ROOM',
            'রুমে যোগ দিন',
          ),
          height: 58,
          outline: true,
          onTap: _toggleJoin,
        ),
        box: () => _grownBox(
          stageKey: _joinStage,
          child: _joinStageContent(),
        ),
      );

  Widget _joinStageContent() {
    if (_joinStage == 'name') {
      return _NamePanel(
        isJoin: true,
        bangla: _bn,
        busy: _busy,
        onCancel: () => setState(
          () => _joinStage = 'code',
        ),
        onDone: _finish,
      );
    }

    return Column(
      key: const ValueKey('joinCode'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _tr(
            'JOIN ROOM',
            'রুমে যোগ দিন',
          ),
          style: _display(21),
        ),
        const SizedBox(height: 4),
        Text(
          _tr(
            'Enter the code from your friend.',
            'বন্ধুর কাছ থেকে পাওয়া কোডটি দিন।',
          ),
          textAlign: TextAlign.center,
          style: _body(
            13,
            c: BluffColors.muted,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: BluffColors.panel2,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _code,
            textCapitalization:
                TextCapitalization.characters,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: _display(
              19,
              c: BluffColors.cream,
            ).copyWith(
              letterSpacing: 3,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'ABC123',
              hintStyle: _display(
                18,
                c: BluffColors.muted,
              ).copyWith(
                letterSpacing: 3,
              ),
              border: InputBorder.none,
            ),
            onSubmitted: (_) => _startJoin(),
          ),
        ),
        const SizedBox(height: 14),
        _Chunky(
          label: _tr(
            'JOIN',
            'যোগ দিন',
          ),
          onTap: _startJoin,
          height: 54,
        ),
        Center(
          child: TextButton(
            onPressed: () {
              _code.clear();
              _toggleJoin();
            },
            child: Text(
              _tr(
                'CANCEL',
                'বাতিল',
              ),
              style: _body(
                12,
                c: BluffColors.muted,
                w: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Matches ImpostorScreen's _Badge exactly: 56×56 rounded panel chip.
  Widget _badge(Widget child) => Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BluffColors.panel2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: BluffColors.line,
            width: 2,
          ),
        ),
        child: child,
      );

  // Matches ImpostorScreen's _SetupTile exactly: card + badge + title/subtitle + chevron.
  Widget _setupTile({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: BluffColors.panel2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: BluffColors.line,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: _display(
                            17.5,
                            w: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: _body(
                            13,
                            c: BluffColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: BluffColors.gold,
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  // Matches ImpostorScreen's _HintRow.
  Widget _hintRow() => Container(
        decoration: BoxDecoration(
          color: BluffColors.panel2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: BluffColors.line,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(
              () => _hints = !_hints,
            ),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _hints
                          ? BluffColors.goldTint
                          : BluffColors.panel,
                      borderRadius:
                          BorderRadius.circular(13),
                    ),
                    child: const Text(
                      '💡',
                      style: TextStyle(fontSize: 21),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tr(
                            'Give hint to impostors',
                            'ইমপোস্টরদের হিন্ট দিন',
                          ),
                          style: _body(
                            15,
                            w: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _tr(
                            'Only impostors will receive the hint',
                            'শুধু ইমপোস্টররাই হিন্ট পাবে',
                          ),
                          style: _body(
                            12.5,
                            c: BluffColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _hints,
                    onChanged: (v) => setState(
                      () => _hints = v,
                    ),
                    activeThumbColor:
                        BluffColors.cream,
                    activeTrackColor:
                        BluffColors.red,
                    inactiveThumbColor:
                        BluffColors.muted,
                    inactiveTrackColor:
                        BluffColors.panel,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  // ── Category grid stage ──────────────────────────────────────────────
  // mirrors the offline CategoryScreen: header +
  // count/Select-all/Clear row + emoji tile grid (ALL categories) + DONE.
  Widget _categoryStage() {
    final total = _categories.length;
    final count = _selected.length;

    return StatefulBuilder(
      key: const ValueKey('categoryGrid'),
      builder: (context, setLocal) {
        void toggle(String name) {
          setLocal(
            () => _selected.contains(name)
                ? _selected.remove(name)
                : _selected.add(name),
          );
          setState(() {});
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _iconBtn(
                  Icons.arrow_back_rounded,
                  BluffColors.line,
                  () => setState(
                    () => _createStage = 'settings',
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _tr(
                    'CATEGORIES',
                    'ক্যাটাগরি',
                  ),
                  style: _display(22),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  '$count/$total ${_tr('selected', 'নির্বাচিত')}',
                  style: _display(
                    16,
                    w: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _linkButton(
                  _tr(
                    'Select all',
                    'সব নির্বাচন',
                  ),
                  () {
                    setLocal(
                      () => _selected = {
                        ..._categories
                      },
                    );
                    setState(() {});
                  },
                ),
                const SizedBox(width: 16),
                _linkButton(
                  _tr(
                    'Clear',
                    'পরিষ্কার',
                  ),
                  () {
                    setLocal(
                      () => _selected.clear(),
                    );
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 360,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1 / 0.95,
                ),
                itemCount: total,
                itemBuilder: (_, i) {
                  final name = _categories[i];

                  return _categoryTile(
                    name: name,
                    emoji:
                        _categoryEmojis[name] ?? '🔸',
                    selected:
                        _selected.contains(name),
                    onTap: () => toggle(name),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            if (count == 0)
              Padding(
                padding:
                    const EdgeInsets.only(bottom: 8),
                child: Text(
                  _tr(
                    'Select at least one category',
                    'কমপক্ষে একটি ক্যাটাগরি বেছে নিন',
                  ),
                  textAlign: TextAlign.center,
                  style: _body(
                    13,
                    c: BluffColors.muted,
                  ),
                ),
              ),
            _Chunky(
              label: _tr(
                'DONE',
                'সম্পন্ন',
              ),
              enabled: count > 0,
              height: 52,
              onTap: () => setState(
                () => _createStage = 'settings',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _linkButton(
    String label,
    VoidCallback onTap,
  ) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 4,
          ),
          child: Text(
            label,
            style: _body(
              13,
              c: BluffColors.gold,
              w: FontWeight.w600,
            ).copyWith(
              decoration:
                  TextDecoration.underline,
              decorationColor:
                  BluffColors.gold,
            ),
          ),
        ),
      );

  Widget _categoryTile({
    required String name,
    required String emoji,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      AnimatedOpacity(
        duration:
            const Duration(milliseconds: 150),
        opacity: selected ? 1 : 0.5,
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(
              selected ? -0.035 : 0,
            )
            ..scale(
              selected ? 1.045 : 1.0,
              selected ? 1.045 : 1.0,
              1.0,
            ),
          decoration: BoxDecoration(
            color: selected
                ? BluffColors.red
                : BluffColors.panel2,
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? BluffColors.redLight
                  : BluffColors.line,
              width: 2,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: BluffColors.redDeep,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius:
                BorderRadius.circular(18),
            child: InkWell(
              borderRadius:
                  BorderRadius.circular(18),
              onTap: onTap,
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 5,
                      ),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Text(
                            emoji,
                            style:
                                const TextStyle(
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              name,
                              textAlign:
                                  TextAlign.center,
                              style: _display(
                                13,
                                w: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration:
                            const BoxDecoration(
                          shape: BoxShape.circle,
                          color: BluffColors.cream,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color:
                              BluffColors.redDeep,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ── Shared chunky button (same press-down style across the app) ──────────
class _Chunky extends StatefulWidget {
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
  State<_Chunky> createState() => _ChunkyState();
}

class _ChunkyState extends State<_Chunky> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;

    final fill = !enabled
        ? BluffColors.panel2
        : (widget.outline
            ? BluffColors.panel2
            : BluffColors.red);

    final border = !enabled
        ? BluffColors.line
        : (widget.outline
            ? BluffColors.line
            : BluffColors.redLight);

    final shadow = !enabled
        ? BluffColors.line
        : (widget.outline
            ? BluffColors.line
            : BluffColors.redDeep);

    final textColor =
        enabled ? BluffColors.cream : BluffColors.muted;

    return GestureDetector(
      onTapDown: enabled
          ? (_) => setState(() => _down = true)
          : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              widget.onTap();
            }
          : null,
      onTapCancel: enabled
          ? () => setState(() => _down = false)
          : null,
      child: SizedBox(
        width: double.infinity,
        height: widget.height + 7,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration:
                  const Duration(milliseconds: 80),
              top: _down ? 5 : 0,
              left: 0,
              right: 0,
              child: Container(
                height: widget.height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius:
                      BorderRadius.circular(18),
                  border: Border.all(
                    color: border,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: shadow,
                      offset: Offset(
                        0,
                        _down ? 2 : 7,
                      ),
                    ),
                  ],
                ),
                child: Text(
                  widget.label,
                  style: _display(
                    widget.height > 50
                        ? 20
                        : 16,
                    c: textColor,
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

// ── Shared "your name" step content — no card of its own; it grows inside
//     whichever slot's box is already open (Create's or Join's). ─────────
class _NamePanel extends StatefulWidget {
  const _NamePanel({
    required this.isJoin,
    required this.bangla,
    required this.busy,
    required this.onCancel,
    required this.onDone,
  });

  final bool isJoin;
  final bool bangla;
  final bool busy;
  final VoidCallback onCancel;
  final ValueChanged<String> onDone;

  @override
  State<_NamePanel> createState() => _NamePanelState();
}

class _NamePanelState extends State<_NamePanel> {
  final _c = TextEditingController();
  bool _loading = true;

  String _tr(String en, String bn) =>
      widget.bangla ? bn : en;

  @override
  void initState() {
    super.initState();

    SharedPreferences.getInstance().then((p) {
      final saved =
          p.getString(_nameKey)?.trim();

      if (saved != null && saved.isNotEmpty) {
        _c.text = saved;
      }

      if (mounted) {
        setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _c.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              BluffColors.panel2,
          content: Text(
            _tr(
              'Please enter your name.',
              'আপনার নাম লিখুন।',
            ),
            style: _body(14),
          ),
        ),
      );
      return;
    }

    (await SharedPreferences.getInstance())
        .setString(
      _nameKey,
      name,
    );

    widget.onDone(name);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('nameStage'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _tr(
            'YOUR NAME',
            'আপনার নাম',
          ),
          style: _display(21),
        ),
        const SizedBox(height: 6),
        Text(
          widget.isJoin
              ? _tr(
                  'Shown to the other players in the room.',
                  'এটি রুমের অন্য খেলোয়াড়রা দেখতে পাবে।',
                )
              : _tr(
                  'Shown to players who join your room.',
                  'যারা আপনার রুমে যোগ দেবে তারা এটি দেখবে।',
                ),
          textAlign: TextAlign.center,
          style: _body(
            13,
            c: BluffColors.muted,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: BluffColors.panel2,
            borderRadius:
                BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration:
                    const BoxDecoration(
                  color: BluffColors.goldTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: BluffColors.gold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _c,
                  autofocus: true,
                  enabled:
                      !_loading && !widget.busy,
                  textCapitalization:
                      TextCapitalization.words,
                  maxLength: 20,
                  style: _body(
                    16,
                    w: FontWeight.w700,
                  ),
                  decoration:
                      InputDecoration(
                    counterText: '',
                    hintText: _tr(
                      'Your name',
                      'আপনার নাম',
                    ),
                    hintStyle: _body(
                      15,
                      c: BluffColors.muted,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
        const SizedBox(height: 16),
        widget.busy
            ? const Padding(
                padding:
                    EdgeInsets.symmetric(
                  vertical: 16,
                ),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: BluffColors.gold,
                  ),
                ),
              )
            : _Chunky(
                label: _tr(
                  'CONTINUE',
                  'চালিয়ে যান',
                ),
                onTap: _submit,
                height: 52,
              ),
        if (!widget.busy)
          Center(
            child: TextButton(
              onPressed: widget.onCancel,
              child: Text(
                _tr(
                  'CANCEL',
                  'বাতিল',
                ),
                style: _body(
                  12,
                  c: BluffColors.muted,
                  w: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}