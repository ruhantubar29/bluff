import 'package:flutter/material.dart';

import '../../core/features.dart';
import '../../games/chess/multiplayer/online_lobby_screen.dart';
import '../../games/chess/services/online_service.dart';
import '../../games/impostor/multiplayer/screens/online_impostor_screen.dart';

const _dark = Color(0xff09090E);
const _red = Color(0xffC62828);
const _highlight = Color(0xffFFD166);

class MultiplayerScreen extends StatelessWidget {
  const MultiplayerScreen({
    super.key,
  });

  void _openImpostor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OnlineImpostorScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        18,
        8,
        18,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(
            title: 'PLAY ONLINE',
            subtitle: 'Have fun with friends beyond your reach.',
          ),

          const SizedBox(height: 14),

          _ImpostorGameCard(
            onTap: () => _openImpostor(context),
          ),

          // Live chess goes straight under PLAY ONLINE; otherwise it drops
          // below as a locked COMING SOON entry.
          if (kChessEnabled) ...[
            const SizedBox(height: 14),

            _ChessOnlineCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnlineLobbyScreen()),
              ),
            ),
          ],

          const SizedBox(height: 30),

          const _SectionHeader(
            title: 'COMING SOON',
            subtitle:
                'More multiplayer games will be introduced in future updates.',
          ),

          if (!kChessEnabled) ...[
            const SizedBox(height: 14),

            // Chess sits under COMING SOON, locked, until kChessEnabled is
            // flipped back on (see lib/core/features.dart).
            _ChessOnlineCard(
              locked: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnlineLobbyScreen()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChessOnlineCard extends StatelessWidget {
  const _ChessOnlineCard({
    required this.onTap,
    this.locked = false,
  });

  final VoidCallback onTap;

  /// When true the card is shown as coming-soon: taps are dead and the
  /// arrow becomes a padlock.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    // Derived from the service (not hardcoded) so the card flips honestly
    // the moment a backend is wired in.
    final online = OnlineService.instance.isAvailable;

    final status = locked
        ? 'COMING SOON'
        : online
            ? 'ONLINE'
            : 'SERVER REQUIRED';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: _highlight.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.035),
        child: Ink(
          height: 150,
          decoration: BoxDecoration(
            color: const Color(0xff151116),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/game_cards/chess_card.jpeg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.4, -0.2),
                    errorBuilder: (_, _, _) {
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xff241512), Color(0xff0D0D12)],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.90),
                          Colors.black.withValues(alpha: 0.62),
                          Colors.black.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                  ),
                ),

                // Locked (coming soon): flatten the art so the card reads as
                // unavailable rather than as a live game.
                if (locked)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                  ),

                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 17,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CHESS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Rated games against players around the world.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              status,
                              style: TextStyle(
                                color: locked
                                    ? Colors.white38
                                    : online
                                        ? const Color(0xff43A047)
                                        : const Color(0xffF9A825),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: locked
                              ? Colors.white.withValues(alpha: 0.10)
                              : _highlight,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          locked
                              ? Icons.lock_rounded
                              : Icons.arrow_forward_rounded,
                          color: locked ? Colors.white70 : _dark,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            color: _red,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImpostorGameCard extends StatelessWidget {
  const _ImpostorGameCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: _highlight.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.035),
        child: Ink(
          height: 190,
          decoration: BoxDecoration(
            color: const Color(0xff151116),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/game_cards/impostor_card.jpeg',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, _, _) {
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xff321014),
                              Color(0xff0D0D12),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.88),
                          Colors.black.withValues(alpha: 0.62),
                          Colors.black.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.60),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 17,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'IMPOSTOR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Find the impostor before they fool everyone.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _highlight,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: _dark,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}