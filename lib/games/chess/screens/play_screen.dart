import 'dart:math';

import 'package:flutter/material.dart';

import '../core/engine/chess_engine.dart';
import '../core/models/time_control.dart';
import '../services/online_service.dart';
import '../services/settings_service.dart';
import '../state/game_controller.dart';
import '../widgets/chess_theme.dart';
import 'game_replay_screen.dart';
import 'game_screen.dart';

/// New game setup: mode, time control, opponent strength, colour and rating.
///
/// Online mode is honest about the local-first build: it explains that a
/// backend is required instead of pretending to matchmake.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, this.initialMode});

  /// Mode preselected by the caller (e.g. the Bluff multiplayer entry).
  final ChessGameMode? initialMode;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  late ChessGameMode _mode;
  late TimeControl _timeControl;
  late EngineLevel _level;

  /// 0 = White, 1 = Black, 2 = Random (computer mode only).
  int _colorChoice = 0;
  bool _rated = true;

  /// Whether the online layer is actually reachable. Read from
  /// [OnlineService] rather than hardcoded, so wiring a backend flips this
  /// screen without editing it.
  bool get _onlineReady => OnlineService.instance.isAvailable;

  static const _colorLabels = ['White', 'Black', 'Random'];

  @override
  void initState() {
    super.initState();
    _applyMode(widget.initialMode);
    final settings = ChessSettingsService.instance.settings;
    _timeControl = TimeControl.byLabel(settings.defaultTimeControlLabel) ??
        TimeControl.byLabel('10 + 0')!;
    final levelIndex = (settings.defaultComputerLevel - 1).clamp(0, 5);
    _level = EngineLevel.values[levelIndex];
    if (settings.preferBlack) _colorChoice = 1;
    _rated = _timeControl.category != TimeCategory.unlimited;
  }

  @override
  void didUpdateWidget(covariant PlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMode != null &&
        widget.initialMode != oldWidget.initialMode) {
      _applyMode(widget.initialMode);
    }
  }

  void _applyMode(ChessGameMode? mode) {
    _mode = mode ?? ChessGameMode.computer;
  }

  void _selectTimeControl(TimeControl tc) {
    setState(() {
      _timeControl = tc;
      if (tc.category == TimeCategory.unlimited) _rated = false;
    });
  }

  Future<void> _start() async {
    final mode = _mode;
    var computerIsWhite = _colorChoice == 0;
    if (_colorChoice == 2) computerIsWhite = Random().nextBool();

    final game = GameScreen(
      mode: mode,
      timeControl: _timeControl,
      computerLevel: mode == ChessGameMode.computer ? _level : null,
      computerIsWhite: computerIsWhite,
      rated: mode == ChessGameMode.computer
          ? (_rated && _timeControl.category != TimeCategory.unlimited)
          : false,
      onReview: (record) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GameReplayScreen(record: record),
          ),
        );
      },
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => game),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const SectionTitle(
          title: 'Game mode',
          subtitle: 'Everything here runs on this device.',
        ),
        _modeCard(
          ChessGameMode.computer,
          Icons.computer_rounded,
          'vs Computer',
          'Six strengths from Beginner to Master',
        ),
        _modeCard(
          ChessGameMode.passAndPlay,
          Icons.groups_rounded,
          'Pass & Play',
          'Two players, one device · unrated',
        ),
        _modeCard(
          ChessGameMode.online,
          Icons.wifi_rounded,
          'Online',
          'Play people over the network',
        ),
        if (_mode == ChessGameMode.online) ...[
          const SizedBox(height: 4),
          _onlineBanner(),
        ],
        const SizedBox(height: 20),
        const SectionTitle(
          title: 'Time control',
          subtitle: 'Base time plus increment per move.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tc in [...TimeControl.presets, TimeControl.unlimited])
              InfoChip(
                label: tc.displayLabel,
                color: tc.label == _timeControl.label
                    ? ChessPalette.accentSoft
                    : ChessPalette.surface,
                textColor: tc.label == _timeControl.label
                    ? ChessPalette.text
                    : ChessPalette.textDim,
                onTap: () => _selectTimeControl(tc),
              ),
          ],
        ),
        if (_mode == ChessGameMode.computer) ...[
          const SizedBox(height: 20),
          const SectionTitle(
            title: 'Opponent',
            subtitle: 'Engine strength in Elo points.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final level in EngineLevel.values)
                InfoChip(
                  label: '${level.displayName} · ${level.rating}',
                  color: level == _level
                      ? ChessPalette.accentSoft
                      : ChessPalette.surface,
                  textColor: level == _level
                      ? ChessPalette.text
                      : ChessPalette.textDim,
                  onTap: () => setState(() => _level = level),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionTitle(title: 'Your colour'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _colorLabels.length; i++)
                InfoChip(
                  label: _colorLabels[i],
                  color: i == _colorChoice
                      ? ChessPalette.accentSoft
                      : ChessPalette.surface,
                  textColor: i == _colorChoice
                      ? ChessPalette.text
                      : ChessPalette.textDim,
                  onTap: () => setState(() => _colorChoice = i),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ChessCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rated game', style: ChessText.body),
                      SizedBox(height: 2),
                      Text(
                        'Affects your rating for this time category',
                        style: ChessText.caption,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _rated &&
                      _timeControl.category != TimeCategory.unlimited,
                  activeThumbColor: ChessPalette.accent,
                  onChanged: _timeControl.category == TimeCategory.unlimited
                      ? null
                      : (v) => setState(() => _rated = v),
                ),
              ],
            ),
          ),
        ],
        if (_mode == ChessGameMode.passAndPlay) ...[
          const SizedBox(height: 8),
          ChessCard(
            child: Text(
              'Pass the device after each move. Games on a shared account '
              'are always unrated, so neither player\'s rating moves.',
              style: ChessText.caption.copyWith(height: 1.5),
            ),
          ),
        ],
        const SizedBox(height: 24),
        PrimaryButton(
          label: _mode == ChessGameMode.online && !_onlineReady
              ? 'Server required'
              : 'Start game',
          icon: Icons.play_arrow_rounded,
          expanded: true,
          onPressed: _mode == ChessGameMode.online
              ? (_onlineReady ? null : _serverNeeded)
              : _start,
        ),
        if (_mode == ChessGameMode.online && !_onlineReady)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Matchmaking, friends and leaderboards talk to the BLUFF '
              'backend, which is not connected in this build. Try vs '
              'Computer or Pass & Play — both are fully playable offline.',
              textAlign: TextAlign.center,
              style: ChessText.caption.copyWith(height: 1.5),
            ),
          ),
      ],
    );
  }

  Widget _modeCard(
    ChessGameMode mode,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final selected = mode == _mode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ChessCard(
        onTap: () => setState(() => _mode = mode),
        padding: const EdgeInsets.all(14),
        border: Border.all(
          color: selected ? ChessPalette.accent : ChessPalette.border,
          width: selected ? 2 : 1,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? ChessPalette.accentSoft
                    : ChessPalette.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected ? ChessPalette.text : ChessPalette.textDim,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ChessText.body.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: ChessText.caption),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? ChessPalette.accent : ChessPalette.textFaint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// The honest server-required message, shown when no backend is reachable.
  void _serverNeeded() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Online play needs the BLUFF server — not connected '
          'in this build.',
        ),
      ),
    );
  }

  Widget _onlineBanner() {
    final ready = _onlineReady;
    return ChessCard(
      color: ChessPalette.surfaceAlt,
      border: Border.all(
        color: (ready ? ChessPalette.success : ChessPalette.warning)
            .withValues(alpha: 0.4),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ready ? Icons.cloud_done_outlined : Icons.info_outline_rounded,
            color: ready ? ChessPalette.success : ChessPalette.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ready
                  ? 'The backend is reachable, but this build ships without '
                      'the matchmaking client — online games open here once '
                      'it lands. Nothing is faked until then.'
                  : 'Online play is gated behind a server connection. This build '
                      'is local-first: nothing is faked, so the Online mode only '
                      'activates once a backend is plugged in.',
              style: ChessText.caption.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
