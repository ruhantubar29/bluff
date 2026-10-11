import 'dart:math';

import 'package:flutter/material.dart';

import '../core/engine/chess_engine.dart';
import '../core/models/time_control.dart';
import '../screens/game_screen.dart';
import '../services/stockfish_runner.dart';
import '../state/game_controller.dart';
import '../widgets/chess_theme.dart';
import '../widgets/time_control_picker.dart';

/// A named bot: plain-language label, shown rating, and the built-in engine
/// level it maps to (used for names/rating bookkeeping and as the fallback
/// strength when Stockfish isn't available on this device).
class _BotDef {
  const _BotDef(this.name, this.elo, this.level);

  final String name;
  final int elo;
  final EngineLevel level;
}

const List<_BotDef> _bots = [
  _BotDef('Beginner', 400, EngineLevel.beginner),
  _BotDef('Easy', 800, EngineLevel.easy),
  _BotDef('Medium', 1200, EngineLevel.medium),
  _BotDef('Hard', 1600, EngineLevel.hard),
  _BotDef('Expert', 1900, EngineLevel.expert),
  _BotDef('Master', 2200, EngineLevel.master),
  _BotDef('Grandmaster', 2800, EngineLevel.master),
];

enum _Side { white, black, random }

/// Bot selection flow for the singleplayer folder.
///
/// Three choices, in order: who you face (named bots or a custom 250–3200
/// Elo slider on Stockfish/built-in engine), which side you take, and the
/// clock — the clock lives in the "Options" end drawer exactly like the
/// spec's side panel. START GAME opens the board directly.
class BotSetupScreen extends StatefulWidget {
  const BotSetupScreen({super.key});

  @override
  State<BotSetupScreen> createState() => _BotSetupScreenState();
}

class _BotSetupScreenState extends State<BotSetupScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  _BotDef? _selectedBot = _bots[2]; // Medium
  int _elo = 1200;
  _Side _side = _Side.white;
  TimeControl _tc = TimeControl.unlimited;

  /// Stockfish is only a real choice where the natives ship; elsewhere the
  /// toggle stays off and says why.
  final bool _stockfishAvailable = StockfishRunner.instance.isSupported;
  bool _useStockfish = StockfishRunner.instance.isSupported;

  EngineLevel get _nearestLevel {
    var best = EngineLevel.beginner;
    var bestDiff = (best.rating - _elo).abs();
    for (final level in EngineLevel.values) {
      final diff = (level.rating - _elo).abs();
      if (diff < bestDiff) {
        best = level;
        bestDiff = diff;
      }
    }
    return best;
  }

  bool get _clockRated => _tc.hasClock;

  String get _tcLabel => timeControlLabel(_tc);

  void _openOptions() => _scaffoldKey.currentState?.openEndDrawer();

  void _start() {
    final computerIsWhite = switch (_side) {
      _Side.white => false,
      _Side.black => true,
      _Side.random => Random().nextBool(),
    };
    final bot = _selectedBot;
    final engineName =
        '${_useStockfish ? 'Stockfish' : 'Computer'} · ${bot?.name ?? '$_elo'}';

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          mode: ChessGameMode.computer,
          timeControl: _tc,
          computerLevel: _nearestLevel,
          computerIsWhite: computerIsWhite,
          computerElo: _elo,
          useStockfish: _useStockfish,
          // No clock → unrated (same policy as the hub's play screen).
          rated: _tc.hasClock,
          whiteName: computerIsWhite ? engineName : null,
          blackName: computerIsWhite ? null : engineName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: ChessPalette.background,
      endDrawer: TimeControlDrawer(
        selected: _tc,
        onSelected: (tc) => setState(() => _tc = tc),
      ),
      appBar: AppBar(
        backgroundColor: ChessPalette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ChessPalette.text,
        elevation: 0,
        title: const Text('Play with Bot', style: ChessText.title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // ---------------------------------------------------- opponent --
            const SectionTitle(
              title: 'Opponent',
              subtitle: 'Named bots, or dial in your own strength below',
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final bot in _bots) _buildBotChip(bot),
              ],
            ),
            const SizedBox(height: 28),

            // ------------------------------------------------------- side --
            const SectionTitle(
              title: 'Your side',
              subtitle: 'Random mixes it up each game',
            ),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'White',
                    expanded: true,
                    selected: _side == _Side.white,
                    onPressed: () => setState(() => _side = _Side.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GhostButton(
                    label: 'Black',
                    expanded: true,
                    selected: _side == _Side.black,
                    onPressed: () => setState(() => _side = _Side.black),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GhostButton(
                    label: 'Random',
                    icon: Icons.shuffle_rounded,
                    expanded: true,
                    selected: _side == _Side.random,
                    onPressed: () => setState(() => _side = _Side.random),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ----------------------------------------------------- engine --
            SectionTitle(
              title: 'Engine',
              subtitle: 'Opponent strength on a 250–3200 Elo slider',
              trailing: InfoChip(
                label: _stockfishAvailable ? 'STOCKFISH READY' : 'BUILT-IN',
                icon: Icons.memory_rounded,
                color: _stockfishAvailable
                    ? ChessPalette.accentSoft
                    : ChessPalette.surfaceHigh,
                textColor: _stockfishAvailable
                    ? ChessPalette.accent
                    : ChessPalette.textDim,
              ),
            ),
            ChessCard(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GhostButton(
                          label: 'Stockfish',
                          icon: Icons.cached_rounded,
                          expanded: true,
                          selected: _useStockfish,
                          onPressed: _stockfishAvailable
                              ? () => setState(() => _useStockfish = true)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GhostButton(
                          label: 'Built-in',
                          expanded: true,
                          selected: !_useStockfish,
                          onPressed: () =>
                              setState(() => _useStockfish = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedBot?.name ?? 'Custom',
                          style: ChessText.body.copyWith(
                            color: ChessPalette.textDim,
                          ),
                        ),
                      ),
                      Text(
                        '$_elo',
                        style: ChessText.display.copyWith(
                          color: ChessPalette.gold,
                          fontSize: 30,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 4),
                        child: Text('Elo', style: ChessText.caption),
                      ),
                    ],
                  ),
                  Slider(
                    value: _elo.toDouble(),
                    min: 250,
                    max: 3200,
                    divisions: 59, // steps of 50
                    activeColor: ChessPalette.accent,
                    inactiveColor: ChessPalette.surfaceHigh,
                    label: '$_elo',
                    onChanged: (value) => setState(() {
                      _elo = value.round();
                      _selectedBot = null;
                    }),
                  ),
                  Text(
                    _stockfishAvailable
                        ? 'Stockfish plays to its supported 1350–3190 band; '
                            'the built-in engine covers the full slider.'
                        : 'Stockfish ships on Android and iOS — this device '
                            'plays with the built-in engine.',
                    style: ChessText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ------------------------------------------------ time control --
            SectionTitle(
              title: 'Time control',
              subtitle: _clockRated
                  ? '${_tc.categoryName} · rated vs engine'
                  : 'No clock · unrated',
              trailing: GhostButton(
                label: 'OPTIONS',
                icon: Icons.tune_rounded,
                dense: true,
                onPressed: _openOptions,
              ),
            ),
            ChessCard(
              onTap: _openOptions,
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: ChessPalette.textDim,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_tcLabel, style: ChessText.title),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to open the full clock menu',
                          style: ChessText.caption,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: ChessPalette.textFaint,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'START GAME',
              icon: Icons.play_arrow_rounded,
              expanded: true,
              onPressed: _start,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- widgets --

  Widget _buildBotChip(_BotDef bot) {
    final selected = _selectedBot?.name == bot.name;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        _selectedBot = bot;
        _elo = bot.elo;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? ChessPalette.accentSoft : ChessPalette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? ChessPalette.accent
                : ChessPalette.borderStrong,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              bot.name,
              style: TextStyle(
                color: selected ? ChessPalette.text : ChessPalette.textDim,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text('${bot.elo}', style: ChessText.caption),
          ],
        ),
      ),
    );
  }
}
