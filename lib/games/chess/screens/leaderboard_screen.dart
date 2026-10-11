import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models/player_profile.dart';
import '../core/models/time_control.dart';
import '../services/chess_storage.dart';
import '../services/online_service.dart';
import '../services/session_service.dart';
import '../widgets/chess_theme.dart';
import 'profile_screen.dart' show categoryLabel;

/// Ranks players for a chosen rating category.
///
/// With the backend connected this shows the server's real standings; with
/// no backend it falls back to ranking the profiles on this device — always
/// labeled LOCAL, never fabricating remote players.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const _categories = [
    RatingCategory.bullet,
    RatingCategory.blitz,
    RatingCategory.rapid,
    RatingCategory.classical,
  ];

  List<PlayerProfile> _profiles = const [];
  String? _localId;
  RatingCategory _category = RatingCategory.rapid;

  /// Server standings for the selected category; null → local board.
  List<LeaderboardEntry>? _serverEntries;
  int _fetchSeq = 0;
  StreamSubscription<ConnectionPhase>? _phaseSub;

  @override
  void initState() {
    super.initState();
    _load();
    _fetchServer();
    _phaseSub = OnlineService.instance.phaseChanges.listen((_) {
      if (!mounted) return;
      setState(() {});
      _fetchServer();
    });
  }

  @override
  void dispose() {
    _phaseSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    // Ensures a local profile exists even on a fresh install.
    final current = await SessionService.instance.current;
    final profiles = await ChessStorage.instance.loadProfiles();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _localId = current.id;
    });
  }

  /// Fetches real standings when a backend is connected; otherwise the
  /// screen stays on the labeled local board.
  Future<void> _fetchServer() async {
    final service = OnlineService.instance;
    final seq = ++_fetchSeq;
    if (!service.isAvailable) {
      if (mounted && _serverEntries != null) {
        setState(() => _serverEntries = null);
      }
      return;
    }
    try {
      final entries = await service.leaderboard(category: _category, limit: 50);
      if (!mounted || seq != _fetchSeq) return;
      setState(() => _serverEntries = entries);
    } catch (_) {
      // Fetch failed — fall back to the honest local board (labeled LOCAL).
      if (!mounted || seq != _fetchSeq) return;
      setState(() => _serverEntries = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverMode = _serverEntries != null;
    final ranked = [..._profiles]
      ..sort((a, b) => b.rating(_category).compareTo(a.rating(_category)));

    return Scaffold(
      backgroundColor: ChessPalette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: ChessPalette.text),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 4),
                const Text('Leaderboard', style: ChessText.display),
              ],
            ),
            const SizedBox(height: 8),
            ChessCard(
              color: ChessPalette.surfaceAlt,
              border: Border.all(
                color: (serverMode
                        ? ChessPalette.success
                        : ChessPalette.warning)
                    .withValues(alpha: 0.4),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    serverMode
                        ? Icons.public_rounded
                        : Icons.info_outline_rounded,
                    color: serverMode
                        ? ChessPalette.success
                        : ChessPalette.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      serverMode
                          ? 'Rankings come from the connected BLUFF server — '
                              'these are the real standings for every player '
                              'who has played there.'
                          : 'Global rankings come from the BLUFF server, which is '
                              'not connected in this build. This board ranks the '
                              'profiles on this device so it works offline.',
                      style: ChessText.caption.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final category in _categories) ...[
                  if (category != _categories.first) const SizedBox(width: 8),
                  Expanded(
                    child: GhostButton(
                      label: categoryLabel(category),
                      expanded: true,
                      selected: category == _category,
                      onPressed: () {
                        setState(() => _category = category);
                        _fetchServer();
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            SectionTitle(
              title: 'Rankings',
              trailing: InfoChip(
                label: serverMode ? 'SERVER' : 'LOCAL',
                color: serverMode
                    ? ChessPalette.accentSoft
                    : ChessPalette.surfaceHigh,
                textColor:
                    serverMode ? ChessPalette.success : ChessPalette.textDim,
              ),
            ),
            if (serverMode && _serverEntries!.isEmpty)
              ChessCard(
                child: Text(
                  'The server has no rated players yet — win a rated game '
                  'there and the standings fill in.',
                  style: ChessText.caption.copyWith(height: 1.5),
                ),
              )
            else if (serverMode)
              for (final entry in _serverEntries!) _serverTile(entry)
            else if (ranked.isEmpty)
              ChessCard(
                child: Text(
                  'No local profiles yet — play a game or create an '
                  'account and your ranking appears here.',
                  style: ChessText.caption.copyWith(height: 1.5),
                ),
              )
            else
              for (var i = 0; i < ranked.length; i++)
                _tile(rank: i + 1, profile: ranked[i]),
          ],
        ),
      ),
    );
  }

  Widget _serverTile(LeaderboardEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ChessCard(
        border: entry.isLocal
            ? Border.all(color: ChessPalette.accent, width: 1.4)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#${entry.rank}',
                style: ChessText.mono.copyWith(
                  color: entry.rank <= 3
                      ? ChessPalette.accent
                      : ChessPalette.textFaint,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: ChessPalette.surfaceHigh,
              ),
              child: Text(
                _initials(entry.displayName),
                style:
                    ChessText.body.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ChessText.body,
                  ),
                  Text(
                    '@${entry.playerId}',
                    style: ChessText.caption.copyWith(
                      color: ChessPalette.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            if (entry.isLocal) ...[
              const InfoChip(label: 'You'),
              const SizedBox(width: 8),
            ],
            Text(
              '${entry.rating}',
              style: ChessText.display.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return (parts.first[0] + parts.last[0]).toUpperCase();
    }
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  Widget _tile({required int rank, required PlayerProfile profile}) {
    final isYou = profile.id == _localId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ChessCard(
        border: isYou
            ? Border.all(color: ChessPalette.accent, width: 1.4)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#$rank',
                style: ChessText.mono.copyWith(
                  color: rank <= 3
                      ? ChessPalette.accent
                      : ChessPalette.textFaint,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _avatar(profile),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ChessText.body,
                  ),
                  Text(
                    '@${profile.username}',
                    style: ChessText.caption.copyWith(
                      color: ChessPalette.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            if (isYou) ...[
              const InfoChip(label: 'You'),
              const SizedBox(width: 8),
            ],
            Text(
              '${profile.rating(_category)}',
              style: ChessText.display.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(PlayerProfile profile) {
    final color = Color(profile.avatarColor);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        profile.avatarEmoji ?? profile.initials,
        style: ChessText.body.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
