import 'package:bluff/games/chess/core/models/game_record.dart';
import 'package:bluff/games/chess/core/models/game_result.dart';
import 'package:bluff/games/chess/core/models/player_profile.dart';
import 'package:bluff/games/chess/core/models/time_control.dart';
import 'package:bluff/games/chess/services/chess_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  PlayerProfile profile(String id) => PlayerProfile(
        id: id,
        username: 'user_$id',
        displayName: 'User $id',
        ratings: {
          RatingCategory.rapid: PlayerRating(rating: 1200),
        },
      );

  ChessGameRecord record(String id) => ChessGameRecord(
        id: id,
        startedAt: DateTime(2026, 1, 2, 12),
        endedAt: DateTime(2026, 1, 2, 12, 5),
        startFen:
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        moves: const [],
        result: const GameResult(
          reason: GameEndReason.resignation,
          winnerIsWhite: true,
        ),
        timeControlLabel: '5 + 0',
        timeCategory: TimeCategory.blitz,
        source: GameSource.computer,
        whiteName: 'White',
        blackName: 'Black',
        whiteRatingBefore: 1200,
        blackRatingBefore: 1187,
        rated: true,
        whiteRatingAfter: 1215,
        blackRatingAfter: 1172,
      );

  test('upsertProfile works on a first launch (empty store)', () async {
    await ChessStorage.instance.upsertProfile(profile('p1'));
    await ChessStorage.instance.upsertProfile(profile('p2'));

    final loaded = await ChessStorage.instance.loadProfiles();
    expect(loaded.map((p) => p.id), ['p1', 'p2']);

    // Upsert replaces instead of duplicating.
    await ChessStorage.instance.upsertProfile(profile('p1'));
    final after = await ChessStorage.instance.loadProfiles();
    expect(after.map((p) => p.id), ['p1', 'p2']);
  });

  test('addGame works on a first launch and round-trips', () async {
    await ChessStorage.instance.addGame(record('g1'));
    await ChessStorage.instance.addGame(record('g2'));

    final games = await ChessStorage.instance.loadGames();
    expect(
      games.map((g) => g.id),
      ['g2', 'g1'],
      reason: 'games are stored newest-first',
    );

    final first = games.first;
    expect(first.result.winnerIsWhite, isTrue);
    expect(first.timeControlLabel, '5 + 0');
    expect(first.whiteRatingAfter, 1215);
    expect(first.blackRatingAfter, 1172);
    expect(first.rated, isTrue);
  });

  test('current profile id round-trips and clears', () async {
    await ChessStorage.instance.saveCurrentProfileId('p9');
    expect(await ChessStorage.instance.loadCurrentProfileId(), 'p9');

    await ChessStorage.instance.saveCurrentProfileId('');
    expect(await ChessStorage.instance.loadCurrentProfileId(), '');
    expect(await ChessStorage.instance.loadCurrentProfile(), isNull);
  });

  test('loadCurrentProfile resolves a stored profile by id', () async {
    await ChessStorage.instance.upsertProfile(profile('hero'));
    await ChessStorage.instance.saveCurrentProfileId('hero');

    final loaded = await ChessStorage.instance.loadCurrentProfile();
    expect(loaded, isNotNull);
    expect(loaded!.id, 'hero');
    expect(loaded.displayName, 'User hero');
  });

  test('loadGames survives corrupt json', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chess_games_v1', '{not json');
    expect(await ChessStorage.instance.loadGames(), isEmpty);

    await prefs.setString('chess_games_v1', '{"weird": true}');
    expect(await ChessStorage.instance.loadGames(), isEmpty);
  });
}
