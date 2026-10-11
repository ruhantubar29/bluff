import 'package:flutter/material.dart';

import '../core/models/time_control.dart';
import '../screens/game_screen.dart';
import '../state/game_controller.dart';
import '../widgets/chess_theme.dart';
import '../widgets/time_control_picker.dart';

/// Options screen for the pass & play folder: name the two players and pick
/// a clock, then START GAME drops both straight onto the board. Sides are
/// not fixed here — the device gets passed around (and can be rotated or
/// flipped) between moves, so each player simply takes the side in front of
/// them.
class PassAndPlaySetupScreen extends StatefulWidget {
  const PassAndPlaySetupScreen({super.key});

  @override
  State<PassAndPlaySetupScreen> createState() =>
      _PassAndPlaySetupScreenState();
}

class _PassAndPlaySetupScreenState extends State<PassAndPlaySetupScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _player1 = TextEditingController(text: 'Player 1');
  final TextEditingController _player2 = TextEditingController(text: 'Player 2');

  TimeControl _tc = TimeControl.unlimited;

  @override
  void dispose() {
    _player1.dispose();
    _player2.dispose();
    super.dispose();
  }

  String get _tcLabel => timeControlLabel(_tc);

  String _nameOf(TextEditingController controller, String fallback) {
    final text = controller.text.trim();
    return text.isEmpty ? fallback : text;
  }

  void _start() {
    final white = _nameOf(_player1, 'Player 1');
    final black = _nameOf(_player2, 'Player 2');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          mode: ChessGameMode.passAndPlay,
          timeControl: _tc,
          whiteName: white,
          blackName: black,
          rated: false, // shared device — unrated by policy
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
        title: const Text('Pass & Play', style: ChessText.title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // ---------------------------------------------------- players --
            const SectionTitle(
              title: 'Players',
              subtitle: 'Name yourselves — the names show on the clock bars',
            ),
            ChessCard(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Column(
                children: [
                  _playerRow(
                    badge: '1',
                    hint: 'Player 1',
                    controller: _player1,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Divider(color: ChessPalette.border),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('VS', style: ChessText.label),
                        ),
                        const Expanded(
                          child: Divider(color: ChessPalette.border),
                        ),
                      ],
                    ),
                  ),
                  _playerRow(
                    badge: '2',
                    hint: 'Player 2',
                    controller: _player2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pass the device after each move — rotate or flip the board '
              'whichever way suits you.',
              style: ChessText.caption,
            ),
            const SizedBox(height: 28),

            // ------------------------------------------------ time control --
            SectionTitle(
              title: 'Time control',
              subtitle: _tc.hasClock
                  ? '${_tc.categoryName} · both players share the clock'
                  : 'No clock · take all the time you like',
              trailing: GhostButton(
                label: 'OPTIONS',
                icon: Icons.tune_rounded,
                dense: true,
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ),
            ChessCard(
              onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
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

  Widget _playerRow({
    required String badge,
    required String hint,
    required TextEditingController controller,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ChessPalette.surfaceHigh,
            shape: BoxShape.circle,
            border: Border.all(color: ChessPalette.borderStrong),
          ),
          child: Text(
            badge,
            style: ChessText.title.copyWith(fontSize: 16),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: TextField(
            controller: controller,
            maxLength: 16,
            style: ChessText.body.copyWith(color: ChessPalette.text),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              counterText: '',
              hintText: hint,
              hintStyle: ChessText.caption,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ChessPalette.borderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ChessPalette.accent),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
