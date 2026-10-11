import 'package:bluff/core/profile/player_roster.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Splash keeps a roster of recurring pass-and-play players. These tests cover
/// the local-first store behind it: dedupe, play counts, persistence, limits.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PlayerRoster.instance.resetForTesting();
    await PlayerRoster.instance.load();
  });

  test('adds a player and bumps them to the top', () async {
    expect(await PlayerRoster.instance.add(name: 'Rakib'), isTrue);
    expect(await PlayerRoster.instance.add(name: 'Nusrat'), isTrue);

    final names = PlayerRoster.instance.players.map((p) => p.name).toList();
    expect(names, ['Nusrat', 'Rakib']);
  });

  test('is case-insensitively deduped', () async {
    await PlayerRoster.instance.add(name: 'Tanvir');
    await PlayerRoster.instance.add(name: 'TANVIR');

    expect(PlayerRoster.instance.count, 1);
    expect(PlayerRoster.instance.players.single.name, 'Tanvir');
  });

  test('rejects blank names', () async {
    expect(await PlayerRoster.instance.add(name: '   '), isFalse);
    expect(PlayerRoster.instance.count, 0);
  });

  test('re-adding an existing player increments their play count', () async {
    await PlayerRoster.instance.add(name: 'Farhana');
    await PlayerRoster.instance.add(name: 'Farhana');
    await PlayerRoster.instance.add(name: 'Farhana');

    final player = PlayerRoster.instance.players.single;
    expect(player.timesPlayed, 2);
  });

  test('recordGame remembers players who were never added manually', () async {
    await PlayerRoster.instance.recordGame(['Shanto', 'Mehjabin']);

    expect(PlayerRoster.instance.count, 2);
    expect(
      PlayerRoster.instance.players.map((p) => p.name),
      containsAll(['Shanto', 'Mehjabin']),
    );
  });

  test('recordGame bumps counts for known players', () async {
    await PlayerRoster.instance.add(name: 'Shanto');
    await PlayerRoster.instance.recordGame(['Shanto']);

    expect(PlayerRoster.instance.players.single.timesPlayed, 1);
  });

  test('removes players case-insensitively', () async {
    await PlayerRoster.instance.add(name: 'Rakib');
    await PlayerRoster.instance.remove('RAKIB');

    expect(PlayerRoster.instance.count, 0);
  });

  test('roster is capped so it cannot grow without bound', () async {
    for (var i = 0; i < PlayerRoster.maxPlayers + 5; i++) {
      await PlayerRoster.instance.add(name: 'Player $i');
    }

    expect(PlayerRoster.instance.count, PlayerRoster.maxPlayers);
  });

  test('persists across a cold start', () async {
    await PlayerRoster.instance.add(name: 'Rakib');
    await PlayerRoster.instance.add(name: 'Nusrat');

    // Simulate an app restart: memory cleared, then loaded from disk again.
    PlayerRoster.instance.resetForTesting();
    await PlayerRoster.instance.load();

    expect(
      PlayerRoster.instance.players.map((p) => p.name),
      ['Nusrat', 'Rakib'],
    );
  });

  test('corrupt roster blob is discarded instead of crashing', () async {
    await PlayerRoster.instance.add(name: 'Rakib');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bluff.roster', '{not a list');

    PlayerRoster.instance.resetForTesting();
    await PlayerRoster.instance.load();

    expect(PlayerRoster.instance.count, 0);
  });
}
