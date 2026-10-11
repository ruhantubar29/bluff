import 'package:flutter/material.dart';

import '../../core/features.dart';
import '../../widgets/game_card.dart';

import '../../games/impostor/screens/impostor_screen.dart';
import '../../games/would_you_rather/screens/would_you_rather_screen.dart';
import '../../games/truth_or_dare/screens/truth_or_dare_screen.dart';
import '../../games/wrong_answer_only/screens/wrong_answer_only_screen.dart';
import '../../games/who_am_i/screens/who_am_i_screen.dart';
import '../../games/perfect_circle/screens/perfect_circle_screen.dart';
import '../../games/chess/pass_and_play/pass_and_play_setup_screen.dart';
import '../../games/never_have_i_ever/screens/never_have_i_ever_screen.dart';
import '../../games/charades/screens/charades_screen.dart';
import '../../games/mafia/screens/mafia_screen.dart';

const _red = Color(0xffC62828);

class PassAndPlayScreen extends StatelessWidget {
  const PassAndPlayScreen({
    super.key,
    required this.favoriteGames,
    required this.onFavoriteToggle,
    required this.onGameOpened,
  });

  final Set<String> favoriteGames;
  final Future<void> Function(String gameTitle) onFavoriteToggle;
  final Future<void> Function(String gameTitle) onGameOpened;

  @override
  Widget build(BuildContext context) {
    final games = <_PassAndPlayGame>[
      _PassAndPlayGame(
        title: 'IMPOSTOR',
        screen: const ImpostorScreen(),
        imagePath:
            'assets/images/game_cards/impostor_card.jpeg',
        description:
            'Pass the phone and find the impostor.',
        isAvailable: true,
      ),
      _PassAndPlayGame(
        title: 'WOULD YOU RATHER',
        screen: const WouldYouRatherScreen(),
        imagePath:
            'assets/images/game_cards/would_you_rather_card.jpeg',
        description:
            'Take turns choosing with your friends.',
        isAvailable: false,
      ),
      _PassAndPlayGame(
        title: 'TRUTH OR DARE',
        screen: const TruthOrDareScreen(),
        imagePath:
            'assets/images/game_cards/truth_or_dare_card.jpeg',
        description:
            'Pass the phone and challenge your friends.',
        isAvailable: false,
      ),
      _PassAndPlayGame(
        title: 'WRONG ANSWER ONLY',
        screen: const WrongAnswerOnlyScreen(),
        imagePath:
            'assets/images/game_cards/wrong_answer_only_card.jpeg',
        description:
            'Take turns giving ridiculous answers.',
        isAvailable: false,
      ),
      _PassAndPlayGame(
        title: 'WHO AM I?',
        screen: const WhoAmIScreen(),
        imagePath:
            'assets/images/game_cards/who_am_i_card.jpeg',
        description:
            'Guess together on one device.',
        isAvailable: false,
      ),
      _PassAndPlayGame(
        title: 'PERFECT CIRCLE',
        screen: const PerfectCircleScreen(),
        imagePath:
            'assets/images/game_cards/perfect_circle_card.jpeg',
        description:
            'Take turns drawing the perfect circle.',
        isAvailable: false,
      ),
      // Chess ships as a locked tile under COMING SOON until kChessEnabled
      // is flipped back on (see lib/core/features.dart).
      _PassAndPlayGame(
        title: 'CHESS',
        screen: const PassAndPlaySetupScreen(),
        imagePath:
            'assets/images/game_cards/chess_card.jpeg',
        description:
            'Play chess together on one device.',
        isAvailable: kChessEnabled,
      ),
      _PassAndPlayGame(
        title: 'NEVER HAVE I EVER',
        screen: const NeverHaveIEverScreen(),
        imagePath:
            'assets/images/game_cards/never_have_i_ever_card.jpeg',
        description:
            'Reveal secrets with your friends.',
        isAvailable: false,
      ),
      _PassAndPlayGame(
        title: 'CHARADES',
        screen: const CharadesScreen(),
        imagePath:
            'assets/images/game_cards/charades_card.jpeg',
        description:
            'Act it out for the people beside you.',
        isAvailable: false,
      ),
      _PassAndPlayGame(
        title: 'MAFIA',
        screen: const MafiaScreen(),
        imagePath:
            'assets/images/game_cards/mafia_card.jpeg',
        description:
            'Pass the phone and find the Mafia.',
        isAvailable: false,
      ),
    ];

    final available =
        games.where((game) => game.isAvailable).toList();

    final comingSoon =
        games.where((game) => !game.isAvailable).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (available.isNotEmpty)
          const SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'AVAILABLE NOW',
              subtitle: 'Ready to play.',
            ),
          ),

        if (available.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              20,
              0,
              20,
              30,
            ),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final game = available[index];

                  return _GameTile(
                    game: game,
                    isFavorite:
                        favoriteGames.contains(game.title),
                    onFavoriteToggle: onFavoriteToggle,
                    onGameOpened: onGameOpened,
                  );
                },
                childCount: available.length,
              ),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 5 / 7,
              ),
            ),
          ),

        if (comingSoon.isNotEmpty)
          const SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'COMING SOON',
              subtitle:
                  'More games will be introduced in future updates.',
            ),
          ),

        if (comingSoon.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              20,
              0,
              20,
              28,
            ),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final game = comingSoon[index];

                  return _GameTile(
                    game: game,
                    isFavorite:
                        favoriteGames.contains(game.title),
                    onFavoriteToggle: onFavoriteToggle,
                    onGameOpened: onGameOpened,
                  );
                },
                childCount: comingSoon.length,
              ),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 5 / 7,
              ),
            ),
          ),
      ],
    );
  }
}

class _PassAndPlayGame {
  const _PassAndPlayGame({
    required this.title,
    required this.screen,
    required this.description,
    required this.isAvailable,
    this.imagePath,
  });

  final String title;
  final Widget screen;
  final String description;
  final String? imagePath;
  final bool isAvailable;
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        14,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: _red,
              borderRadius:
                  BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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
                    color: Colors.white.withValues(
                      alpha: 0.38,
                    ),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.game,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onGameOpened,
  });

  final _PassAndPlayGame game;
  final bool isFavorite;
  final Future<void> Function(String gameTitle)
      onFavoriteToggle;
  final Future<void> Function(String gameTitle)
      onGameOpened;

  Future<void> _openGame(BuildContext context) async {
    if (!game.isAvailable) {
      return;
    }

    await onGameOpened(game.title);

    if (!context.mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => game.screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = GameCard(
      title: game.title,
      description: game.description,
      imagePath: game.imagePath,
      onTap: () => _openGame(context),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          ignoring: !game.isAvailable,
          child: card,
        ),

        if (game.isAvailable)
          Positioned(
            top: 10,
            right: 10,
            child: _FavoriteButton(
              isFavorite: isFavorite,
              onPressed: () {
                onFavoriteToggle(game.title);
              },
            ),
          ),

        if (!game.isAvailable)
          const Positioned.fill(
            child: _ComingSoonOverlay(),
          ),
      ],
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.onPressed,
  });

  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.52),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(
            isFavorite
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            color: isFavorite
                ? const Color(0xffffd166)
                : Colors.white70,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _ComingSoonOverlay extends StatelessWidget {
  const _ComingSoonOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(
            alpha: 0.56,
          ),
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: 0.08,
            ),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(
                    alpha: 0.38,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: 0.16,
                    ),
                  ),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: Colors.white70,
                  size: 23,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(
                    alpha: 0.55,
                  ),
                  borderRadius:
                      BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: 0.12,
                    ),
                  ),
                ),
                child: const Text(
                  'COMING SOON',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}