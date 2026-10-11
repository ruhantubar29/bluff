import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/language/app_language.dart';
import '../../../core/language/language_settings.dart';
import '../../../core/profile/avatars.dart';
import '../../../core/profile/player_roster.dart';

const _dark = Color(0xff09090E);
const _highlight = Color(0xffFFD166);

/// Your recurring pass-and-play crew — Splash's player roster, where regular
/// players are remembered so games never ask for the same names twice.
class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final TextEditingController _nameController = TextEditingController();

  List<RosterPlayer> _players = const [];
  bool _ready = false;

  bool get _isBangla => LanguageSettings.instance.language.code == 'bn';

  String _t(String en, String bn) => _isBangla ? bn : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await PlayerRoster.instance.load();
    // On a fresh install the account roster is pulled back, like the profile.
    await PlayerRoster.instance.restoreIfEmpty();

    if (!mounted) return;

    setState(() {
      _players = PlayerRoster.instance.players;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) return;

    final ok = await PlayerRoster.instance.add(
      name: name,
      avatarIndex: name.hashCode.abs() % kAvatarCount,
    );

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Roster is full — remove someone first.',
              'তালিকা পূর্ণ — আগে কাউকে সরান।',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _nameController.clear();
    setState(() => _players = PlayerRoster.instance.players);
  }

  Future<void> _remove(RosterPlayer player) async {
    await PlayerRoster.instance.remove(player.name);

    if (!mounted) return;
    setState(() => _players = PlayerRoster.instance.players);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _dark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _dark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _t('Your Players', 'আপনার খেলোয়াড়রা'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        maxLength: 18,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _add(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: _t('Add a player…', 'খেলোয়াড় যোগ করুন…'),
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: _highlight,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _highlight,
                          foregroundColor: _dark,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _add,
                        child: const Icon(Icons.add_rounded, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: !_ready
                    ? const Center(child: CircularProgressIndicator())
                    : _players.isEmpty
                    ? _emptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: _players.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final player = _players[index];

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: _highlight.withValues(
                                    alpha: 0.16,
                                  ),
                                  child: AvatarView(
                                    index: player.avatarIndex,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        player.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        player.timesPlayed == 0
                                            ? _t('New player', 'নতুন খেলোয়াড়')
                                            : _t(
                                                'Played ${player.timesPlayed} times',
                                                '${player.timesPlayed} বার খেলেছে',
                                              ),
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: _t('Remove', 'সরান'),
                                  onPressed: () => _remove(player),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white30,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👥', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 14),
            Text(
              _t(
                'Your regular crew shows up here',
                'আপনার নিয়মিত দল এখানে থাকবে',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                'Add the people you play with often — next time every game starts with their names already filled in.',
                'যাদের সাথে প্রায়ই খেলেন তাদের যোগ করুন — পরেরবার সব গেমে নামগুলো আগে থেকেই থাকবে।',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
