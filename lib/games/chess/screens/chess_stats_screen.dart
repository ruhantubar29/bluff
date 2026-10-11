import 'package:flutter/material.dart';

import '../core/models/game_record.dart';
import '../core/models/player_profile.dart';
import '../core/models/puzzle.dart';
import '../core/models/time_control.dart';
import '../services/chess_storage.dart';
import '../services/session_service.dart';
import '../widgets/chess_theme.dart';
import '../widgets/rating_graph.dart';
import 'profile_screen.dart' show categoryLabel;

/// The player's chess progress in one place: career record, Elo per
/// category, the rating graph, activity breakdown, recent form and puzzle
/// stats — all derived from what is actually stored on this device.
class ChessStatsScreen extends StatefulWidget {
  const ChessStatsScreen({super.key});

  @override
  State<ChessStatsScreen> createState() => _ChessStatsScreenState();
}

class _ChessStatsScreenState extends State<ChessStatsScreen> {
  static const _playCategories = [
    RatingCategory.bullet,
    RatingCategory.blitz,
    RatingCategory.rapid,
    RatingCategory.classical,
  ];

  PlayerProfile? _profile;
  List<ChessGameRecord> _games = const [];
  List<PuzzleAttempt> _puzzleAttempts = const [];
  RatingCategory _category = RatingCategory.rapid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await SessionService.instance.current;
    final games = await ChessStorage.instance.loadGames();
    final attempts = await ChessStorage.instance.loadPuzzleAttempts();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _games = [...games]..sort((a, b) => b.endedAt.compareTo(a.endedAt));
      _puzzleAttempts = attempts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return const Scaffold(
        backgroundColor: ChessPalette.background,
        body: Center(
          child: CircularProgressIndicator(color: ChessPalette.accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ChessPalette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
                const Text('Chess Stats', style: ChessText.display),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Your progress on this device',
              style: ChessText.caption
                  .copyWith(color: ChessPalette.textFaint),
            ),
            const SizedBox(height: 16),
            const SectionTitle(title: 'Overview'),
            _overviewCard(profile),
            const SizedBox(height: 20),
            const SectionTitle(
              title: 'Rating by category',
              subtitle: 'Elo and record for every rating pool',
            ),
            _categoryGrid(profile),
            const SizedBox(height: 20),
            const SectionTitle(
              title: 'Rating progress',
              subtitle: 'How your Elo has moved over time',
            ),
            _progressCard(profile),
            const SizedBox(height: 20),
            const SectionTitle(title: 'Activity'),
            _activityCard(),
            const SizedBox(height: 20),
            _recentFormCard(profile),
            const SizedBox(height: 20),
            const SectionTitle(title: 'Puzzles'),
            _puzzlesCard(profile),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- overview --

  Widget _overviewCard(PlayerProfile profile) {
    var games = 0;
    var wins = 0;
    var draws = 0;
    var losses = 0;
    for (final category in _playCategories) {
      final r = profile.ratingFor(category);
      games += r.gamesPlayed;
      wins += r.wins;
      draws += r.draws;
      losses += r.losses;
    }

    // Longest win streak across identifiable games (oldest → newest).
    var bestStreak = 0;
    var streak = 0;
    final ordered = [..._games]
      ..sort((a, b) => a.endedAt.compareTo(b.endedAt));
    for (final g in ordered) {
      final side = _localSide(g, profile);
      if (side == null) {
        streak = 0;
        continue;
      }
      final winner = g.result.winnerIsWhite;
      if (winner != null && winner == side) {
        streak++;
        if (streak > bestStreak) bestStreak = streak;
      } else {
        streak = 0;
      }
    }

    final decided = wins + draws + losses;
    final winRate = decided == 0 ? 0 : (wins / decided * 100).round();

    return ChessCard(
      child: Column(
        children: [
          Row(
            children: [
              _statCell('$games', 'Games'),
              _statCell('$winRate%', 'Win rate'),
              _statCell('${profile.peakRating}', 'Peak Elo'),
              _statCell('$bestStreak', 'Best streak'),
            ],
          ),
          const SizedBox(height: 14),
          InfoChip(label: '${wins}W · ${draws}D · ${losses}L'),
        ],
      ),
    );
  }

  Widget _statCell(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: ChessPalette.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ChessText.caption
                  .copyWith(color: ChessPalette.textFaint),
            ),
          ],
        ),
      );

  // -------------------------------------------------- rating by category --

  Widget _categoryGrid(PlayerProfile profile) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final category in [
          ..._playCategories,
          RatingCategory.puzzle,
        ])
          SizedBox(
            width: 158,
            child: ChessCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryLabel(category).toUpperCase(),
                    style: ChessText.caption
                        .copyWith(color: ChessPalette.textFaint),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile.ratingFor(category).rating}',
                    style: const TextStyle(
                      color: ChessPalette.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile.ratingFor(category).gamesPlayed} games · '
                    '${(profile.ratingFor(category).winRate * 100).round()}% win',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ChessText.caption,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------- rating progress --

  Widget _progressCard(PlayerProfile profile) {
    final rating = profile.ratingFor(_category);
    final points = rating.history;
    final hasHistory = points.length >= 2;
    final delta = hasHistory
        ? points.last.rating - points.first.rating
        : 0;

    return ChessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in const [
                RatingCategory.bullet,
                RatingCategory.blitz,
                RatingCategory.rapid,
                RatingCategory.classical,
                RatingCategory.puzzle,
              ])
                InfoChip(
                  label: categoryLabel(category),
                  color: category == _category
                      ? ChessPalette.accentSoft
                      : ChessPalette.surfaceHigh,
                  textColor: category == _category
                      ? ChessPalette.text
                      : ChessPalette.textDim,
                  onTap: () => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 132,
            child: hasHistory
                ? RatingGraph(points: points)
                : Center(
                    child: Text(
                      'No rating history yet — play rated games to '
                      'build your graph.',
                      textAlign: TextAlign.center,
                      style: ChessText.caption,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${rating.gamesPlayed} games',
                style: ChessText.caption,
              ),
              if (hasHistory)
                Text(
                  '${delta >= 0 ? '+' : ''}$delta overall',
                  style: ChessText.mono.copyWith(
                    color: delta >= 0
                        ? ChessPalette.success
                        : ChessPalette.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- activity --

  Widget _activityCard() {
    final counts = <GameSource, int>{};
    var moves = 0;
    for (final g in _games) {
      counts.update(g.source, (n) => n + 1, ifAbsent: () => 1);
      moves += g.moves.length;
    }
    final avgMoves = _games.isEmpty ? 0 : (moves / _games.length).round();
    final last = _games.isEmpty ? null : _games.first.endedAt;

    return ChessCard(
      child: Column(
        children: [
          _activityRow(
            'vs Computer',
            '${counts[GameSource.computer] ?? 0}',
            Icons.smart_toy_outlined,
          ),
          _activityRow(
            'Pass & play',
            '${counts[GameSource.passAndPlay] ?? 0}',
            Icons.swap_horiz_rounded,
          ),
          _activityRow(
            'Online',
            '${counts[GameSource.online] ?? 0}',
            Icons.public_rounded,
          ),
          const Divider(height: 18, color: ChessPalette.border),
          _activityRow(
            'Avg. game length',
            _games.isEmpty ? '—' : '$avgMoves moves',
            Icons.alt_route_rounded,
          ),
          _activityRow(
            'Last game',
            last == null ? 'Never' : _timeAgo(last),
            Icons.history_rounded,
          ),
        ],
      ),
    );
  }

  Widget _activityRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ChessPalette.textFaint),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: ChessText.body)),
          Text(
            value,
            style: ChessText.mono.copyWith(
              color: ChessPalette.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- recent form --

  Widget _recentFormCard(PlayerProfile profile) {
    final identified = <ChessGameRecord>[];
    for (final g in _games) {
      if (_localSide(g, profile) != null) identified.add(g);
      if (identified.length == 10) break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          title: 'Recent form',
          subtitle: 'Last 10 games where your side is known',
        ),
        if (identified.isEmpty)
          ChessCard(
            child: Text(
              'No finished games yet — play a game against the computer '
              'or online and your form shows up here.',
              style: ChessText.caption.copyWith(height: 1.5),
            ),
          )
        else
          ChessCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in identified) _formPill(g, profile),
              ],
            ),
          ),
      ],
    );
  }

  Widget _formPill(ChessGameRecord record, PlayerProfile profile) {
    final side = _localSide(record, profile);
    final winner = record.result.winnerIsWhite;
    final String letter;
    final Color color;
    if (winner == null) {
      letter = side == null ? '·' : 'D';
      color = ChessPalette.textDim;
    } else if (side == null) {
      letter = '·';
      color = ChessPalette.textFaint;
    } else if (winner == side) {
      letter = 'W';
      color = ChessPalette.success;
    } else {
      letter = 'L';
      color = ChessPalette.danger;
    }
    return Tooltip(
      message: '${record.result.winnerLabel} · ${_timeAgo(record.endedAt)}',
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.16),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          letter,
          style: ChessText.mono.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  /// Which side the local player took, or null when it can't be attributed
  /// (pass & play shares one account for both sides).
  bool? _localSide(ChessGameRecord record, PlayerProfile profile) {
    if (record.source == GameSource.passAndPlay) return null;
    if (record.whiteId == 'engine') return false;
    if (record.blackId == 'engine') return true;
    if (record.whiteId != null && record.whiteId == record.blackId) {
      return null;
    }
    if (record.whiteId == profile.id) return true;
    if (record.blackId == profile.id) return false;
    if (record.whiteName == profile.displayName) return true;
    if (record.blackName == profile.displayName) return false;
    return null;
  }

  // ------------------------------------------------------------ puzzles --

  Widget _puzzlesCard(PlayerProfile profile) {
    final solved = _puzzleAttempts.where((a) => a.solved).length;
    final total = _puzzleAttempts.length;
    final accuracy = total == 0 ? 0 : (solved / total * 100).round();
    final puzzleRating = profile.ratingFor(RatingCategory.puzzle).rating;

    return ChessCard(
      child: total == 0
          ? Text(
              'No puzzles attempted yet — the Puzzle Adventure lives in '
              'the singleplayer folder.',
              style: ChessText.caption.copyWith(height: 1.5),
            )
          : Row(
              children: [
                Text(
                  '$puzzleRating',
                  style: const TextStyle(
                    color: ChessPalette.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Puzzle rating', style: ChessText.caption),
                      const SizedBox(height: 3),
                      Text(
                        '$solved solved · $total played · $accuracy% accuracy',
                        style: ChessText.body,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ------------------------------------------------------------- helpers --

  static String _timeAgo(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${when.month}/${when.year}';
  }
}
