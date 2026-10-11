import 'package:bluff/games/chess/core/models/player_profile.dart';
import 'package:bluff/games/chess/core/models/time_control.dart';
import 'package:bluff/games/chess/screens/leaderboard_screen.dart';
import 'package:bluff/games/chess/services/chess_storage.dart';
import 'package:bluff/games/chess/services/session_service.dart';
import 'package:bluff/games/chess/widgets/chess_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.signOut();
  });

  PlayerProfile profile({
    required String id,
    required String username,
    required String displayName,
    Map<RatingCategory, PlayerRating> ratings = const {},
    bool isGuest = false,
  }) =>
      PlayerProfile(
        id: id,
        username: username,
        displayName: displayName,
        isGuest: isGuest,
        ratings: ratings,
      );

  Future<void> pumpBoard(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LeaderboardScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('ranks local profiles by rapid rating and highlights you',
      (tester) async {
    await ChessStorage.instance.saveProfiles([
      profile(
        id: 'p1',
        username: 'ada',
        displayName: 'Ada',
        ratings: {
          RatingCategory.rapid: PlayerRating(rating: 1500),
        },
      ),
      profile(
        id: 'p2',
        username: 'ben',
        displayName: 'Ben',
        ratings: {
          RatingCategory.rapid: PlayerRating(rating: 1200),
        },
      ),
      profile(
        id: 'local-you',
        username: 'local',
        displayName: 'Local',
        isGuest: true,
        ratings: {
          RatingCategory.rapid: PlayerRating(rating: 1350),
        },
      ),
    ]);
    await ChessStorage.instance.saveCurrentProfileId('local-you');

    await pumpBoard(tester);

    expect(find.text('RANKINGS'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('1500'), findsOneWidget);

    // Descending order: Ada (1500) > Local (1350) > Ben (1200).
    expect(
      tester.getTopLeft(find.text('Ada')).dy <
          tester.getTopLeft(find.text('Ben')).dy,
      isTrue,
    );
    expect(
      tester.getTopLeft(find.text('Local')).dy <
          tester.getTopLeft(find.text('Ben')).dy,
      isTrue,
    );
    // The signed-in profile carries the You chip.
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('switching category re-ranks the board', (tester) async {
    await ChessStorage.instance.saveProfiles([
      profile(
        id: 'p1',
        username: 'ada',
        displayName: 'Ada',
        ratings: {
          RatingCategory.rapid: PlayerRating(rating: 1500),
          RatingCategory.blitz: PlayerRating(rating: 1100),
        },
      ),
      profile(
        id: 'p2',
        username: 'ben',
        displayName: 'Ben',
        ratings: {
          RatingCategory.rapid: PlayerRating(rating: 1200),
          RatingCategory.blitz: PlayerRating(rating: 1400),
        },
      ),
    ]);
    await ChessStorage.instance.saveCurrentProfileId('p1');
    await pumpBoard(tester);

    // Rapid default: Ada above Ben.
    expect(
      tester.getTopLeft(find.text('Ada')).dy <
          tester.getTopLeft(find.text('Ben')).dy,
      isTrue,
    );

    await tester.tap(find.widgetWithText(GhostButton, 'Blitz'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Blitz: Ben (1400) takes the top spot.
    expect(
      tester.getTopLeft(find.text('Ben')).dy <
          tester.getTopLeft(find.text('Ada')).dy,
      isTrue,
    );
    expect(find.text('1400'), findsOneWidget);
    expect(find.text('1500'), findsNothing);
  });

  testWidgets('says rankings are local while the server is offline',
      (tester) async {
    await pumpBoard(tester);

    expect(
      find.textContaining('not connected in this build'),
      findsOneWidget,
    );
    expect(find.textContaining('on this device'), findsWidgets);
  });
}
