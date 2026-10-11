import 'package:bluff/core/features.dart';
import 'package:bluff/games/chess/multiplayer/online_lobby_screen.dart';
import 'package:bluff/games/chess/services/settings_service.dart';
import 'package:bluff/games/chess/singleplayer/singleplayer_home.dart';
import 'package:bluff/games/chess/pass_and_play/pass_and_play_setup_screen.dart';
import 'package:bluff/games/chess/widgets/chess_theme.dart';
import 'package:bluff/screens/multiplayer/multiplayer_screen.dart';
import 'package:bluff/screens/pass_and_play/pass_and_play_screen.dart';
import 'package:bluff/screens/singleplayer/singleplayer_screen.dart';
import 'package:bluff/widgets/game_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The three Bluff entry screens gate chess on [kChessEnabled].
///
/// When chess ships, each screen opens its dedicated flow (singleplayer →
/// mode chooser, pass & play → setup, multiplayer → lobby). When it is off,
/// chess still appears in every list but locked under COMING SOON — padlocked,
/// unresponsive, and never routing into the chess flow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final settings = ChessSettingsService.instance.settings;
    settings
      ..showEvalBar = false
      ..playSounds = false;
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  /// Drags the list upward until at least one COMING SOON padlock is built.
  ///
  /// The game grids are lazy slivers, so the locked tiles do not exist in the
  /// tree until they scroll into the viewport (plus cache extent).
  Future<void> dragToLocks(WidgetTester tester) async {
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 8; i++) {
      if (find.byIcon(Icons.lock_rounded).evaluate().isNotEmpty) return;
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('singleplayer offers the shipped games', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleplayerScreen(
          favoriteGames: const {},
          onFavoriteToggle: (_) async {},
          onGameOpened: (_) async {},
        ),
      ),
    );
    await settle(tester);

    // GameCard tiles are image-only; only *available* tiles carry a star
    // badge, which makes them a reliable count of what actually ships.
    expect(find.byType(GameCard), findsWidgets);

    if (kChessEnabled) {
      expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(2));

      // CHESS is the second available tile.
      await tester.tap(find.byType(GameCard).at(1));
      await settle(tester);

      expect(find.byType(SingleplayerHome), findsOneWidget);
      expect(find.text('CHOOSE YOUR GAME'), findsOneWidget);
      expect(find.text('Play with Bot'), findsOneWidget);
      expect(find.text('Solve Puzzles'), findsOneWidget);
    } else {
      // Chess is present but locked in COMING SOON: Perfect Circle is the
      // only playable tile, padlocks mark the rest, and the chess flow
      // stays unreachable even when a locked tile is tapped.
      expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(1));

      // The locked tiles live in the COMING SOON grid, below the fold.
      // Drag down until they materialise — the grid builds lazily, and every
      // lock icon is identical so it can't be used as a scroll target.
      await dragToLocks(tester);
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);

      await tester.tap(
        find.byIcon(Icons.lock_rounded).first,
        warnIfMissed: false,
      );
      await settle(tester);
      expect(find.byType(SingleplayerHome), findsNothing);
    }

    await unmount(tester);
  });

  testWidgets('pass & play offers the shipped games', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PassAndPlayScreen(
          favoriteGames: const {},
          onFavoriteToggle: (_) async {},
          onGameOpened: (_) async {},
        ),
      ),
    );
    await settle(tester);

    if (kChessEnabled) {
      expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(2));

      // CHESS is the second available tile here as well (after IMPOSTOR).
      await tester.tap(find.byType(GameCard).at(1));
      await settle(tester);

      expect(find.byType(PassAndPlaySetupScreen), findsOneWidget);
      expect(find.text('PLAYERS'), findsOneWidget); // SectionTitle uppercases
      expect(find.text('START GAME'), findsOneWidget);
    } else {
      // Chess sits locked under COMING SOON; Impostor is the only playable
      // tile and the setup screen stays unreachable.
      expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(1));

      // The locked tiles live in the COMING SOON grid, below the fold.
      await dragToLocks(tester);
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);

      await tester.tap(
        find.byIcon(Icons.lock_rounded).first,
        warnIfMissed: false,
      );
      await settle(tester);
      expect(find.byType(PassAndPlaySetupScreen), findsNothing);
    }

    await unmount(tester);
  });

  testWidgets('multiplayer offers the shipped games', (tester) async {
    // No online service is installed (lib/main.dart leaves the stub in
    // place), so the chess card must present itself as server-required.
    await tester.pumpWidget(const MaterialApp(home: MultiplayerScreen()));
    await settle(tester);

    if (kChessEnabled) {
      // The chess card carries its own availability banner.
      expect(find.text('SERVER REQUIRED'), findsOneWidget);

      await tester.tap(find.text('CHESS'));
      await settle(tester);

      expect(find.byType(OnlineLobbyScreen), findsOneWidget);
      // Honest about the missing backend: the queue stays off until a server
      // address is CONNECTed, and the copy says exactly how to do that.
      expect(find.text('QUICK MATCH'), findsWidgets); // heading + button
      expect(
        find.textContaining('Set the server address above and press CONNECT'),
        findsOneWidget,
      );
      expect(find.widgetWithText(PrimaryButton, 'CONNECT'), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, 'QUICK MATCH'), findsOneWidget);
    } else {
      // The chess card is still shown, but under COMING SOON and locked:
      // padlock instead of arrow, dead tap, and no route to the lobby.
      // NB: 'COMING SOON' matches both the section header and the card's
      // status line, so it is asserted as a group.
      expect(find.text('CHESS'), findsOneWidget);
      expect(find.text('COMING SOON'), findsWidgets);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      await tester.tap(find.text('CHESS'), warnIfMissed: false);
      await settle(tester);
      expect(find.byType(OnlineLobbyScreen), findsNothing);

      // Impostor online remains the playable offering.
      expect(find.text('IMPOSTOR'), findsOneWidget);
    }

    await unmount(tester);
  });
}
