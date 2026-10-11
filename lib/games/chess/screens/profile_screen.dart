import 'package:flutter/material.dart';

import '../core/models/player_profile.dart';
import '../core/models/time_control.dart';
import '../services/session_service.dart';
import '../widgets/chess_theme.dart';
import '../widgets/rating_graph.dart';
import 'auth_screen.dart';
import 'chess_stats_screen.dart';
import 'settings_screen.dart';

/// The local player: identity, per-category ratings with a performance graph,
/// record, and links into settings.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.isActive = true});

  /// When this flips to true the profile reloads (ratings may have moved).
  final bool isActive;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  PlayerProfile? _profile;
  RatingCategory _category = RatingCategory.rapid;

  static const _categories = [
    RatingCategory.bullet,
    RatingCategory.blitz,
    RatingCategory.rapid,
    RatingCategory.classical,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load();
  }

  Future<void> _load() async {
    final profile = await SessionService.instance.current;
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  /// Opens an auth flow and refreshes the account card when it returns
  /// (signed in, signed out or guest may have changed).
  Future<void> _openAuth(AuthMode mode) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AuthScreen(initialMode: mode)),
    );
    if (mounted) _load();
  }

  Future<void> _signOut() async {
    await SessionService.instance.signOut();
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return const Center(
        child: CircularProgressIndicator(color: ChessPalette.accent),
      );
    }

    final rating = profile.ratingFor(_category);
    final points = rating.history;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _header(profile),
        const SizedBox(height: 20),
        const SectionTitle(title: 'Ratings'),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final category = _categories[index];
              final r = profile.ratingFor(category);
              final selected = category == _category;
              return GestureDetector(
                onTap: () => setState(() => _category = category),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 118,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected
                        ? ChessPalette.accentSoft
                        : ChessPalette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? ChessPalette.accent
                          : ChessPalette.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        categoryLabel(category).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ChessText.caption,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${r.rating}',
                        style: const TextStyle(
                          color: ChessPalette.text,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
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
        ChessCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(categoryLabel(_category), style: ChessText.body),
                  const Spacer(),
                  if (rating.isProvisional)
                    const InfoChip(
                      label: 'Provisional',
                      icon: Icons.star_rounded,
                    ),
                  const SizedBox(width: 8),
                  InfoChip(
                    label:
                        '${rating.wins}W · ${rating.draws}D · ${rating.losses}L',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 132,
                child: points.length < 2
                    ? Center(
                        child: Text(
                          'Play rated games here to build your graph.',
                          style: ChessText.caption,
                        ),
                      )
                    : RatingGraph(points: points),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${rating.gamesPlayed} games',
                    style: ChessText.caption,
                  ),
                  Text(
                    '${(rating.winRate * 100).round()}% win rate',
                    style: ChessText.caption,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle(title: 'Progress'),
        ChessCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => const ChessStatsScreen()),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: const Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: ChessPalette.textDim),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chess Stats', style: ChessText.body),
                    SizedBox(height: 2),
                    Text(
                      'History, Elo, form and puzzle progress',
                      style: ChessText.caption,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ChessPalette.textFaint),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle(title: 'Account'),
        ChessCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => const ChessSettingsScreen()),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: const Row(
            children: [
              Icon(Icons.settings_rounded, color: ChessPalette.textDim),
              SizedBox(width: 12),
              Expanded(child: Text('Settings', style: ChessText.body)),
              Icon(Icons.chevron_right_rounded, color: ChessPalette.textFaint),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ChessCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.isGuest
                    ? 'Playing as a local guest'
                    : 'Signed in as ${profile.username}',
                style: ChessText.body,
              ),
              const SizedBox(height: 6),
              Text(
                profile.isGuest
                    ? 'Everything — ratings, history and settings — is stored '
                        'on this device only. Local accounts keep your data '
                        'portable without a server.'
                    : 'Your account and all progress live on this device.',
                style: ChessText.caption.copyWith(height: 1.5),
              ),
              const SizedBox(height: 12),
              if (profile.isGuest)
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Create account',
                        icon: Icons.person_add_alt_1_rounded,
                        expanded: true,
                        onPressed: () => _openAuth(AuthMode.signUp),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GhostButton(
                        label: 'Sign in',
                        icon: Icons.login_rounded,
                        expanded: true,
                        onPressed: () => _openAuth(AuthMode.signIn),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: GhostButton(
                        label: 'Reset password',
                        icon: Icons.key_rounded,
                        expanded: true,
                        onPressed: () => _openAuth(AuthMode.reset),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GhostButton(
                        label: 'Sign out',
                        icon: Icons.logout_rounded,
                        expanded: true,
                        danger: true,
                        onPressed: _signOut,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(PlayerProfile profile) {
    final letter = profile.displayName.trim().isEmpty
        ? '?'
        : profile.displayName.trim()[0].toUpperCase();

    return Row(
      children: [
        Container(
          width: 62,
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFC62828), Color(0xFF7B1E1E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: ChessPalette.borderStrong),
          ),
          child: profile.avatarEmoji != null
              ? Text(profile.avatarEmoji!, style: const TextStyle(fontSize: 28))
              : Text(
                  letter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.displayName, style: ChessText.display),
              const SizedBox(height: 3),
              Text(
                profile.isGuest
                    ? '@guest · local profile'
                    : '@${profile.username}',
                style: ChessText.caption,
              ),
              if (profile.statusMessage.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(profile.statusMessage, style: ChessText.dim),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String categoryLabel(RatingCategory category) => switch (category) {
      RatingCategory.bullet => 'Bullet',
      RatingCategory.blitz => 'Blitz',
      RatingCategory.rapid => 'Rapid',
      RatingCategory.classical => 'Classical',
      RatingCategory.puzzle => 'Puzzle',
    };

