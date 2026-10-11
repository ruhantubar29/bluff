import 'package:flutter/material.dart';

import '../core/models/game_record.dart';
import '../services/chess_storage.dart';
import '../widgets/chess_theme.dart';
import 'game_replay_screen.dart';

/// Finished games, newest first, with result and source filters.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.localId, this.isActive = true});

  /// The id of the signed-in profile, used to decide which side the local
  /// player was on when judging "won / lost".
  final String? localId;

  /// When this flips to true the list reloads (the hub refires it each time
  /// the tab becomes visible).
  final bool isActive;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ChessGameRecord>? _games;
  _ResultFilter _resultFilter = _ResultFilter.all;
  _SourceFilter _sourceFilter = _SourceFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load();
  }

  Future<void> _load() async {
    final games = await ChessStorage.instance.loadGames();
    if (!mounted) return;
    setState(() => _games = games);
  }

  /// Which side the local player took, falling back to White's perspective
  /// when no id was recorded (pass & play and older games).
  bool _wasWhite(ChessGameRecord record) {
    final me = widget.localId;
    if (me != null && record.whiteId == me) return true;
    if (me != null && record.blackId == me) return false;
    return true;
  }

  bool _matchesResult(ChessGameRecord record) {
    switch (_resultFilter) {
      case _ResultFilter.all:
        return true;
      case _ResultFilter.drawn:
        return record.result.isDraw;
      case _ResultFilter.won:
        return record.result.winnerIsWhite == _wasWhite(record);
      case _ResultFilter.lost:
        return !record.result.isDraw &&
            record.result.winnerIsWhite != _wasWhite(record);
    }
  }

  bool _matchesSource(ChessGameRecord record) {
    switch (_sourceFilter) {
      case _SourceFilter.all:
        return true;
      case _SourceFilter.computer:
        return record.source == GameSource.computer;
      case _SourceFilter.passAndPlay:
        return record.source == GameSource.passAndPlay;
      case _SourceFilter.online:
        return record.source == GameSource.online;
    }
  }

  @override
  Widget build(BuildContext context) {
    final games = _games;
    if (games == null) {
      return const Center(
        child: CircularProgressIndicator(color: ChessPalette.accent),
      );
    }

    final filtered =
        games.where((g) => _matchesResult(g) && _matchesSource(g)).toList();

    if (games.isEmpty) {
      return _emptyState(
        icon: Icons.history_rounded,
        title: 'No games yet',
        message: 'Play your first game and it will show up here with the '
            'full move list.',
      );
    }

    if (filtered.isEmpty) {
      return _emptyState(
        icon: Icons.filter_alt_off_rounded,
        title: 'Nothing matches',
        message: 'No games fit the current filters.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _filterChips(),
        const SizedBox(height: 6),
        for (final record in filtered) GameRecordTile(record: record),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: ChessPalette.textFaint),
            const SizedBox(height: 14),
            Text(title, style: ChessText.title),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: ChessText.dim.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChips() {
    Widget row<T extends Enum>(
      List<(T, String)> options,
      T selected,
      void Function(T) onSelect,
    ) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (value, label) in options)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InfoChip(
                    label: label,
                    color: value == selected
                        ? ChessPalette.accentSoft
                        : ChessPalette.surface,
                    textColor: value == selected
                        ? ChessPalette.text
                        : ChessPalette.textDim,
                    onTap: () => setState(() => onSelect(value)),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        row<_ResultFilter>(
          const [
            (_ResultFilter.all, 'All'),
            (_ResultFilter.won, 'Won'),
            (_ResultFilter.lost, 'Lost'),
            (_ResultFilter.drawn, 'Drawn'),
          ],
          _resultFilter,
          (v) => _resultFilter = v,
        ),
        row<_SourceFilter>(
          const [
            (_SourceFilter.all, 'All modes'),
            (_SourceFilter.computer, 'Computer'),
            (_SourceFilter.passAndPlay, 'Pass & Play'),
            (_SourceFilter.online, 'Online'),
          ],
          _sourceFilter,
          (v) => _sourceFilter = v,
        ),
      ],
    );
  }
}

enum _ResultFilter { all, won, lost, drawn }

enum _SourceFilter { all, computer, passAndPlay, online }

/// One finished game as a tappable row (shared by History and Home).
class GameRecordTile extends StatelessWidget {
  const GameRecordTile({super.key, required this.record});

  final ChessGameRecord record;

  @override
  Widget build(BuildContext context) {
    final result = record.result;
    final String score;
    final Color scoreColor;
    if (result.isDraw) {
      score = '½–½';
      scoreColor = ChessPalette.textDim;
    } else if (result.winnerIsWhite == true) {
      score = '1–0';
      scoreColor = ChessPalette.gold;
    } else {
      score = '0–1';
      scoreColor = ChessPalette.gold;
    }

    final delta = record.rated &&
            record.whiteRatingAfter != null &&
            record.whiteRatingBefore != record.whiteRatingAfter
        ? record.whiteRatingAfter! - record.whiteRatingBefore
        : record.rated &&
                record.blackRatingAfter != null &&
                record.blackRatingBefore != record.blackRatingAfter
            ? record.blackRatingAfter! - record.blackRatingBefore
            : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ChessCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GameReplayScreen(record: record),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ChessPalette.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ChessPalette.border),
              ),
              child: Text(
                score,
                style: TextStyle(
                  color: scoreColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${record.whiteName} vs ${record.blackName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ChessText.body.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (record.openingName != null) record.openingName!,
                      if (record.openingEco != null) record.openingEco!,
                      '${record.moves.length} moves',
                      if (delta != null)
                        '${delta >= 0 ? '+' : ''}$delta',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ChessText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _relativeDate(record.endedAt),
                  style: ChessText.caption,
                ),
                const SizedBox(height: 3),
                Text(
                  record.timeControlLabel,
                  style: ChessText.caption.copyWith(
                    color: ChessPalette.textDim,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeDate(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(when.year, when.month, when.day);
    final diff = today.difference(day).inDays;
    final time =
        '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'Today $time';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    return '${when.day.toString().padLeft(2, '0')}.'
        '${when.month.toString().padLeft(2, '0')}.'
        '${when.year % 100}';
  }
}
