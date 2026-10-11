import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models/time_control.dart';
import '../screens/friends_screen.dart';
import '../screens/game_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../services/online_service.dart';
import '../state/game_controller.dart';
import '../widgets/chess_theme.dart';

/// Online lobby for the multiplayer folder.
///
/// Honest local-first design: everything that works offline (friends, local
/// leaderboard, the queue UI itself) is live, while quick match is only
/// enabled when a real backend reports `isAvailable`. Until a backend is
/// wired in, [OnlineService.instance] stays on the bundled stub, so this
/// screen says so plainly instead of faking a connection.
class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  /// Popular pairings offered for matchmaking.
  static final List<TimeControl> _matchControls = [
    for (final label in const [
      '1 + 0',
      '2 + 1',
      '3 + 2',
      '5 + 0',
      '10 + 0',
      '15 + 10',
    ])
      TimeControl.byLabel(label) ?? TimeControl.presets.first,
  ];

  TimeControl _tc = _matchControls[2]; // 3 + 2
  bool _queueing = false;
  String? _queueStatus;
  StreamSubscription<ConnectionPhase>? _phaseSub;

  bool get _onlineReady => OnlineService.instance.isAvailable;

  @override
  void initState() {
    super.initState();
    _phaseSub = OnlineService.instance.phaseChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _phaseSub?.cancel();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _quickMatch() async {
    final service = OnlineService.instance;
    if (!service.isAvailable || _queueing) return;
    setState(() {
      _queueing = true;
      _queueStatus = 'Connecting…';
    });
    try {
      await service.connect();
      final updates = await service.enqueue(timeControl: _tc);
      if (!mounted) return;
      setState(() => _queueStatus = 'Looking for an opponent…');

      await for (final update in updates) {
        if (!mounted) return;
        switch (update) {
          case QueueJoined(:final position):
            setState(() => _queueStatus = position != null
                ? 'In queue — $position players ahead'
                : 'In queue…');
          case MatchFound(
              :final gameId,
              :final timeControl,
              :final opponentId,
              :final opponentName,
              :final opponentRating,
              :final localIsWhite,
              :final rated,
            ):
            // The server made the pairing; open the live channel before
            // the board so no early event is missed.
            final live = await service.openGame(gameId);
            if (!mounted) return;
            setState(() {
              _queueing = false;
              _queueStatus = null;
            });
            _snack('Opponent found: $opponentName ($opponentRating)');
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => GameScreen(
                  mode: ChessGameMode.online,
                  timeControl: timeControl,
                  rated: rated,
                  liveGame: live,
                  localIsWhite: localIsWhite,
                  opponentId: opponentId,
                  opponentRating: opponentRating,
                  whiteName: localIsWhite ? null : opponentName,
                  blackName: localIsWhite ? opponentName : null,
                ),
              ),
            );
            return;
        }
      }
      // Stream closed without a match: leave the queue state cleanly.
      if (mounted) {
        setState(() {
          _queueing = false;
          _queueStatus = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _queueing = false;
        _queueStatus = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Matchmaking unavailable: $error')),
      );
    }
  }

  void _leaveQueue() {
    OnlineService.instance.leaveQueue();
    setState(() {
      _queueing = false;
      _queueStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChessPalette.background,
      appBar: AppBar(
        backgroundColor: ChessPalette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ChessPalette.text,
        elevation: 0,
        title: const Text('Multiplayer', style: ChessText.title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _buildStatusCard(),
            const SizedBox(height: 24),

            // ------------------------------------------------- quick match --
            SectionTitle(
              title: 'Quick match',
              subtitle: 'Pair you with a similar-rated player',
              trailing: InfoChip(
                label: _onlineReady ? 'READY' : 'OFFLINE',
                color: _onlineReady
                    ? ChessPalette.accentSoft
                    : ChessPalette.surfaceHigh,
                textColor: _onlineReady
                    ? ChessPalette.success
                    : ChessPalette.textDim,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final control in _matchControls)
                  InfoChip(
                    label: control.displayLabel,
                    color: control == _tc
                        ? ChessPalette.accentSoft
                        : ChessPalette.surfaceHigh,
                    textColor: control == _tc
                        ? ChessPalette.text
                        : ChessPalette.textDim,
                    onTap: _queueing
                        ? null
                        : () => setState(() => _tc = control),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (_queueing) ...[
              ChessCard(
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: ChessPalette.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _queueStatus ?? 'Looking for an opponent…',
                        style: ChessText.body,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              GhostButton(
                label: 'LEAVE QUEUE',
                expanded: true,
                danger: true,
                onPressed: _leaveQueue,
              ),
            ] else ...[
              PrimaryButton(
                label: 'QUICK MATCH',
                icon: Icons.bolt_rounded,
                expanded: true,
                onPressed: _onlineReady ? _quickMatch : null,
              ),
              if (!_onlineReady) ...[
                const SizedBox(height: 10),
                Text(
                  'Online matchmaking needs the live backend, which this '
                  'build does not ship. Everything else — friends, '
                  'challenges and the local leaderboard — stays fully '
                  'local.',
                  style: ChessText.caption,
                ),
              ],
            ],
            const SizedBox(height: 28),

            // -------------------------------------------------- challenge --
            SectionTitle(
              title: 'Challenge a friend',
              subtitle: _onlineReady
                  ? 'Send challenges — friends answer live through the '
                      'server'
                  : 'Send challenges and watch friends online — stored '
                      'locally until the server arrives',
            ),
            GhostButton(
              label: 'FRIENDS & CHALLENGES',
              icon: Icons.group_rounded,
              expanded: true,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FriendsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ------------------------------------------------- leaderboard --
            const SectionTitle(
              title: 'Leaderboard',
              subtitle: 'Local standings by rating category',
            ),
            GhostButton(
              label: 'VIEW LEADERBOARD',
              icon: Icons.leaderboard_rounded,
              expanded: true,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LeaderboardScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final ready = _onlineReady;
    final service = OnlineService.instance;
    return ChessCard(
      color: ready ? ChessPalette.surface : ChessPalette.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: ready
                      ? ChessPalette.success.withValues(alpha: 0.16)
                      : ChessPalette.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  ready ? Icons.wifi_rounded : Icons.cloud_off_rounded,
                  color: ready ? ChessPalette.success : ChessPalette.textDim,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready ? 'CONNECTED' : 'SERVER REQUIRED',
                      style: ChessText.label.copyWith(
                        color: ready
                            ? ChessPalette.success
                            : ChessPalette.warning,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ready
                          ? 'Backend online — matchmaking, presence, '
                              'challenges and global ratings are live.'
                          : 'Online play needs a live backend, which this '
                              'build does not ship. Friends, the local '
                              'leaderboard and pass & play all work '
                              'offline.',
                      style: ChessText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InfoChip(
            label: 'Phase: ${service.phase.label}',
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }
}
