import 'package:bluff/games/chess/screens/chess_hub.dart';
import 'package:bluff/games/chess/screens/friends_screen.dart';
import 'package:bluff/games/chess/screens/game_screen.dart';
import 'package:bluff/games/chess/screens/leaderboard_screen.dart';
import 'package:bluff/games/chess/screens/puzzle_screen.dart';
import 'package:bluff/games/chess/services/settings_service.dart';
import 'package:bluff/games/chess/widgets/board/chess_board_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final settings = ChessSettingsService.instance.settings;
    settings
      ..showEvalBar = false
      ..playSounds = false;
  });

  Future<void> pumpHub(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChessHub()));
    // Settings gate + session/profile boot.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  testWidgets('phone layout uses a bottom navigation bar', (tester) async {
    await pumpHub(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    // Home content (SectionTitle renders uppercase).
    expect(find.textContaining('CHESS'), findsWidgets);
    expect(find.text('vs Computer'), findsWidgets);
    expect(find.text('RECENT GAMES'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('tabs switch between play, history and profile',
      (tester) async {
    await pumpHub(tester);

    await tester.tap(find.byIcon(Icons.play_circle_outline_rounded));
    await tester.pump();
    expect(find.text('GAME MODE'), findsOneWidget);
    expect(find.text('vs Computer'), findsOneWidget);
    expect(find.text('TIME CONTROL'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pump();
    expect(find.text('No games yet'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('RATINGS'), findsOneWidget);
    // Guest profiles expose the local auth flows (below the fold); the
    // Progress/Account sections sit below them too.
    await tester.scrollUntilVisible(
      find.text('Create account'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Chess Stats'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('home links to friends and leaderboard', (tester) async {
    await pumpHub(tester);

    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);

    await tester.tap(find.text('Friends'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(FriendsScreen), findsOneWidget);
    expect(find.textContaining('No friends yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(FriendsScreen), findsNothing);

    await tester.tap(find.text('Leaderboard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LeaderboardScreen), findsOneWidget);
    expect(find.textContaining('not connected in this build'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('puzzles tab opens the trainer', (tester) async {
    await pumpHub(tester);

    await tester.tap(find.byIcon(Icons.extension_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(find.textContaining('Find the best move for'), findsOneWidget);
    expect(find.text('Show solution'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('desktop width switches to a navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpHub(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('History'), findsOneWidget); // extended rail labels
    expect(find.text('Puzzles'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('play tab starts a computer game', (tester) async {
    await pumpHub(tester);

    await tester.tap(find.byIcon(Icons.play_circle_outline_rounded));
    await tester.pump();

    // The start button sits below the fold on a phone-sized surface.
    final start = find.text('Start game');
    await tester.scrollUntilVisible(
      start,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    await tester.tap(start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byType(ChessBoardView), findsOneWidget);
    expect(find.textContaining('Computer ·'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
