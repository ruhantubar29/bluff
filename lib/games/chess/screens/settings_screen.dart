import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/models/time_control.dart';
import '../services/settings_service.dart';
import '../widgets/board/board_themes.dart';
import '../widgets/board/piece_theme.dart';
import '../widgets/chess_theme.dart';

/// Preferences: Board, Gameplay, Account and Notifications.
///
/// Every toggle writes through [ChessSettingsService] immediately, so the
/// board behind this screen (and the next game) picks changes up live.
class ChessSettingsScreen extends StatefulWidget {
  const ChessSettingsScreen({super.key});

  @override
  State<ChessSettingsScreen> createState() => _ChessSettingsScreenState();
}

class _ChessSettingsScreenState extends State<ChessSettingsScreen> {
  ChessSettings get _s => ChessSettingsService.instance.settings;

  Future<void> _save() async {
    await ChessSettingsService.instance.save();
    if (mounted) setState(() {});
  }

  void _toggle(void Function(ChessSettings) apply) {
    apply(_s);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChessPalette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: ChessPalette.text),
                ),
                Text('SETTINGS', style: ChessText.label.copyWith(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            _boardSection(),
            const SizedBox(height: 24),
            _gameplaySection(),
            const SizedBox(height: 24),
            _accountSection(),
            const SizedBox(height: 24),
            _notificationsSection(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ board

  Widget _boardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(title: 'Board'),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: BoardTheme.all.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final theme = BoardTheme.all[index];
              final selected = theme.id == _s.boardThemeId;
              return GestureDetector(
                onTap: () => _toggle((s) => s.boardThemeId = theme.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? ChessPalette.accent
                          : ChessPalette.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            for (var i = 0; i < 4; i++)
                              Expanded(
                                child: Column(
                                  children: [
                                    for (var j = 0; j < 4; j++)
                                      Expanded(
                                        child: ColoredBox(
                                          color: (i + j).isEven
                                              ? theme.lightSquare
                                              : theme.darkSquare,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text(
                          theme.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ChessText.caption.copyWith(
                            color: selected
                                ? ChessPalette.text
                                : ChessPalette.textDim,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: PieceTheme.all.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final theme = PieceTheme.all[index];
              final selected = theme.id == _s.pieceThemeId;
              return GestureDetector(
                onTap: () =>
                    _toggle((s) => s.pieceThemeId = theme.id),
                child: Container(
                  width: 132,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: ChessPalette.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? ChessPalette.accent
                          : ChessPalette.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      theme.build(
                        context,
                        const BoardPiece(
                          type: PieceType.knight,
                          isWhite: false,
                          square: 'g8',
                        ),
                        34,
                      ),
                      const SizedBox(width: 8),
                      Text(theme.name, style: ChessText.body),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        ChessCard(
          child: Column(
            children: [
              _switchRow(
                'Coordinates',
                'Show file/rank labels on the board',
                _s.showCoordinates,
                (v) => _toggle((s) => s.showCoordinates = v),
              ),
              _switchRow(
                'Legal move dots',
                'Dots and rings for legal destinations',
                _s.showLegalDots,
                (v) => _toggle((s) => s.showLegalDots = v),
              ),
              _switchRow(
                'Last move highlight',
                'Tint the from/to squares of the last move',
                _s.showLastMove,
                (v) => _toggle((s) => s.showLastMove = v),
              ),
              _switchRow(
                'Check highlight',
                'Glow the king that is in check',
                _s.showCheckHighlight,
                (v) => _toggle((s) => s.showCheckHighlight = v),
              ),
              _switchRow(
                'Animate moves',
                'Slide pieces instead of jumping',
                _s.animateMoves,
                (v) => _toggle((s) => s.animateMoves = v),
              ),
              if (_s.animateMoves)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Animation speed', style: ChessText.dim),
                      ),
                      SizedBox(
                        width: 190,
                        child: Slider(
                          value: _s.moveAnimationMs.clamp(60, 400).toDouble(),
                          min: 60,
                          max: 400,
                          divisions: 7,
                          label: '${_s.moveAnimationMs} ms',
                          onChanged: (v) => setState(() {
                            _s.moveAnimationMs = v.round();
                          }),
                          onChangeEnd: (_) => _save(),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- gameplay

  Widget _gameplaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(title: 'Gameplay'),
        ChessCard(
          child: Column(
            children: [
              _switchRow(
                'Sounds',
                'Move, capture, check and end-of-game cues',
                _s.playSounds,
                (v) => _toggle((s) => s.playSounds = v),
              ),
              if (_s.playSounds)
                Row(
                  children: [
                    const Icon(Icons.volume_up_rounded,
                        size: 18, color: ChessPalette.textDim),
                    Expanded(
                      child: Slider(
                        value: _s.soundVolume.clamp(0.0, 1.0),
                        onChanged: (v) => setState(() => _s.soundVolume = v),
                        onChangeEnd: (_) => _save(),
                      ),
                    ),
                  ],
                ),
              _switchRow(
                'Auto-queen',
                'Promote to a queen without asking',
                _s.autoQueen,
                (v) => _toggle((s) => s.autoQueen = v),
              ),
              _switchRow(
                'Confirm moves',
                'Tap a second time to commit a move',
                _s.confirmMoves,
                (v) => _toggle((s) => s.confirmMoves = v),
              ),
              _switchRow(
                'Confirm before resigning',
                'Ask for confirmation on the flag button',
                _s.confirmResign,
                (v) => _toggle((s) => s.confirmResign = v),
              ),
              _switchRow(
                'Allow takebacks',
                'Offer takebacks during a game',
                _s.allowTakebacks,
                (v) => _toggle((s) => s.allowTakebacks = v),
              ),
              _switchRow(
                'Evaluation bar',
                'Engine judgement beside the board',
                _s.showEvalBar,
                (v) => _toggle((s) => s.showEvalBar = v),
              ),
              _switchRow(
                'Move list',
                'Show notation next to the board',
                _s.showMoveList,
                (v) => _toggle((s) => s.showMoveList = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ChessCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('Default time control', style: ChessText.dim),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tc in TimeControl.presets)
                    InfoChip(
                      label: tc.label ?? tc.displayLabel,
                      color: _s.defaultTimeControlLabel ==
                              (tc.label ?? tc.displayLabel)
                          ? ChessPalette.accentSoft
                          : ChessPalette.surfaceHigh,
                      textColor: _s.defaultTimeControlLabel ==
                              (tc.label ?? tc.displayLabel)
                          ? ChessPalette.text
                          : ChessPalette.textDim,
                      onTap: () => _toggle(
                        (s) => s.defaultTimeControlLabel =
                            tc.label ?? tc.displayLabel,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('Default computer level', style: ChessText.dim),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < 6; i++)
                    InfoChip(
                      label: _levelName(i),
                      color: _s.defaultComputerLevel == i + 1
                          ? ChessPalette.accentSoft
                          : ChessPalette.surfaceHigh,
                      textColor: _s.defaultComputerLevel == i + 1
                          ? ChessPalette.text
                          : ChessPalette.textDim,
                      onTap: () => _toggle((s) => s.defaultComputerLevel = i + 1),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              _switchRow(
                'Prefer Black',
                'Start new games with the black pieces',
                _s.preferBlack,
                (v) => _toggle((s) => s.preferBlack = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _levelName(int index) => const [
        'Beginner',
        'Easy',
        'Medium',
        'Hard',
        'Expert',
        'Master',
      ][index];

  // ---------------------------------------------------------------- account

  Widget _accountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(title: 'Account'),
        ChessCard(
          child: Column(
            children: [
              _switchRow(
                'Show rating changes',
                'Display the +/- after rated games',
                _s.showRatingChanges,
                (v) => _toggle((s) => s.showRatingChanges = v),
              ),
              _switchRow(
                'Rich presence',
                'Let friends see when you are playing',
                _s.richPresence,
                (v) => _toggle((s) => s.richPresence = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------- notifications

  Widget _notificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(title: 'Notifications'),
        ChessCard(
          child: Column(
            children: [
              _switchRow(
                'Challenges',
                'When a friend challenges you',
                _s.notifyChallenges,
                (v) => _toggle((s) => s.notifyChallenges = v),
              ),
              _switchRow(
                'Friend requests',
                'When someone adds you as a friend',
                _s.notifyFriendRequests,
                (v) => _toggle((s) => s.notifyFriendRequests = v),
              ),
              _switchRow(
                'Game start',
                'When a paired game begins',
                _s.notifyGameStart,
                (v) => _toggle((s) => s.notifyGameStart = v),
              ),
              _switchRow(
                'Daily puzzle',
                'A nudge when the new puzzle drops',
                _s.notifyDailyPuzzle,
                (v) => _toggle((s) => s.notifyDailyPuzzle = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _switchRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ChessText.body),
              const SizedBox(height: 2),
              Text(subtitle, style: ChessText.caption.copyWith(height: 1.3)),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: ChessPalette.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
