import 'package:bluff/games/chess/core/game_clock.dart';
import 'package:bluff/games/chess/core/models/time_control.dart';
import 'package:bluff/games/chess/core/rating/elo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameClock', () {
    late DateTime now;

    GameClock makeClock({TimeControl? tc}) {
      now = DateTime(2026, 10, 3, 12);
      return GameClock(
        timeControl: tc ?? TimeControl.presets[4], // 3 + 2
        now: () => now,
      );
    }

    test('starts with the full initial time for both sides', () {
      final c = makeClock();
      expect(c.whiteRemaining, const Duration(minutes: 3));
      expect(c.blackRemaining, const Duration(minutes: 3));
      expect(c.isRunning, isFalse);
      expect(c.activeSide, ClockSide.white);
    });

    test('does not tick while stopped', () {
      final c = makeClock();
      now = now.add(const Duration(minutes: 5));
      expect(c.whiteRemaining, const Duration(minutes: 3));
    });

    test('counts down the active side only', () {
      final c = makeClock();
      c.start();
      now = now.add(const Duration(seconds: 30));
      expect(c.whiteRemaining, const Duration(minutes: 2, seconds: 30));
      expect(c.blackRemaining, const Duration(minutes: 3));
      expect(c.isRunning, isTrue);
    });

    test('stop banks the elapsed time', () {
      final c = makeClock();
      c.start();
      now = now.add(const Duration(seconds: 45));
      c.stop();
      expect(c.whiteRemaining, const Duration(minutes: 2, seconds: 15));
      // Stopped: further time passing does not drain the clock.
      now = now.add(const Duration(minutes: 10));
      expect(c.whiteRemaining, const Duration(minutes: 2, seconds: 15));
      expect(c.isRunning, isFalse);
    });

    test('move applies increment to the mover and hands over', () {
      final c = makeClock(); // 3 + 2
      c.start();
      now = now.add(const Duration(seconds: 40));
      c.movePlayed(ClockSide.white);

      // White: 3:00 - 0:40 + 0:02 = 2:22
      expect(c.whiteRemaining, const Duration(minutes: 2, seconds: 22));
      expect(c.blackRemaining, const Duration(minutes: 3));
      expect(c.activeSide, ClockSide.black);
      expect(c.isRunning, isTrue);

      now = now.add(const Duration(seconds: 10));
      expect(c.blackRemaining, const Duration(minutes: 2, seconds: 50));
      expect(c.whiteRemaining, const Duration(minutes: 2, seconds: 22));
    });

    test('no increment for increment-less controls', () {
      final c = makeClock(tc: TimeControl.presets[0]); // 1 + 0
      c.start();
      now = now.add(const Duration(seconds: 50));
      c.movePlayed(ClockSide.white);
      expect(c.whiteRemaining, const Duration(seconds: 10));
      expect(c.activeSide, ClockSide.black);
    });

    test('timeout flags the side whose clock reached zero', () {
      final c = makeClock(tc: TimeControl.presets[0]); // 1 + 0
      c.start();
      now = now.add(const Duration(minutes: 2));
      expect(c.checkTimeout(), ClockSide.white);
      expect(c.isExpired, isTrue);
      expect(c.whiteRemaining, Duration.zero);
      // Once expired the clock stays halted.
      c.start();
      now = now.add(const Duration(minutes: 1));
      expect(c.whiteRemaining, Duration.zero);
      expect(c.checkTimeout(), isNull);
    });

    test('halt ends the clock permanently', () {
      final c = makeClock();
      c.start();
      now = now.add(const Duration(seconds: 5));
      c.halt();
      expect(c.isRunning, isFalse);
      expect(c.whiteRemaining, const Duration(minutes: 2, seconds: 55));
      c.start();
      now = now.add(const Duration(minutes: 10));
      expect(c.whiteRemaining, const Duration(minutes: 2, seconds: 55));
    });

    test('reset restores the initial time control', () {
      final c = makeClock();
      c.start();
      now = now.add(const Duration(minutes: 2));
      c.reset();
      expect(c.whiteRemaining, const Duration(minutes: 3));
      expect(c.blackRemaining, const Duration(minutes: 3));
      expect(c.isRunning, isFalse);
      expect(c.isExpired, isFalse);
    });

    test('low-time warnings', () {
      final c = makeClock(tc: TimeControl.presets[0]); // 1 + 0
      expect(c.isLowTime(ClockSide.white), isFalse);
      c.start();
      now = now.add(const Duration(seconds: 45));
      expect(c.isLowTime(ClockSide.white), isTrue); // 15s left
      expect(c.isCriticalTime(ClockSide.white), isFalse);
      now = now.add(const Duration(seconds: 6));
      expect(c.isCriticalTime(ClockSide.white), isTrue); // 9s left
    });

    test('unlimited controls never run or expire', () {
      final c = makeClock(tc: TimeControl.unlimited);
      expect(c.hasClock, isFalse);
      c.start();
      expect(c.isRunning, isFalse);
      now = now.add(const Duration(days: 5));
      expect(c.checkTimeout(), isNull);
      expect(c.isExpired, isFalse);
    });

    test('server sync clamps at zero and marks expiry', () {
      final c = makeClock();
      c.start();
      c.setRemaining(ClockSide.black, const Duration(seconds: 3));
      expect(c.blackRemaining, const Duration(seconds: 3));
      c.setRemaining(ClockSide.black, Duration.zero);
      expect(c.isExpired, isTrue);
    });

    test('JSON snapshot round-trips', () {
      final c = makeClock();
      c.start();
      now = now.add(const Duration(seconds: 12));
      c.movePlayed(ClockSide.white);
      final json = c.toJson();

      final restored = makeClock();
      restored.restoreFromJson(json);
      expect(restored.whiteRemaining, const Duration(minutes: 2, seconds: 50));
      expect(restored.blackRemaining, const Duration(minutes: 3));
      expect(restored.activeSide, ClockSide.black);
    });

    test('formats durations like a real chess clock', () {
      expect(GameClock.format(const Duration(minutes: 3)), '3:00');
      expect(GameClock.format(const Duration(seconds: 65)), '1:05');
      expect(GameClock.format(const Duration(hours: 1, minutes: 5)), '1:05:00');
      expect(
        GameClock.format(const Duration(milliseconds: 15500), verbose: true),
        '0:15.5',
      );
      expect(GameClock.format(const Duration(minutes: 10)), '10:00');
      expect(GameClock.format(Duration.zero), '0:00');
    });
  });

  group('Elo', () {
    test('expected score is symmetric and sensible', () {
      expect(Elo.expectedScore(1500, 1500), closeTo(0.5, 1e-9));
      expect(Elo.expectedScore(1600, 1500), greaterThan(0.5));
      expect(Elo.expectedScore(1500, 1600), closeTo(
        1 - Elo.expectedScore(1600, 1500),
        1e-9,
      ));
      // ~76% expected for a 200-point favorite.
      expect(Elo.expectedScore(1700, 1500), closeTo(0.76, 0.01));
    });

    test('equal players gain/lose symmetric amounts', () {
      final win = Elo.newRating(
        rating: 1500,
        opponentRating: 1500,
        score: 1,
        gamesPlayed: 50,
      );
      final loss = Elo.newRating(
        rating: 1500,
        opponentRating: 1500,
        score: 0,
        gamesPlayed: 50,
      );
      expect(win - 1500, equals(1500 - loss));
      expect(win, 1510); // K20 * (1 - 0.5)
      expect(loss, 1490);
    });

    test('draws against a stronger opponent gain rating', () {
      final after = Elo.newRating(
        rating: 1400,
        opponentRating: 1600,
        score: 0.5,
        gamesPlayed: 50,
      );
      expect(after, greaterThan(1400));
    });

    test('upset wins gain more than routine wins', () {
      final upset = Elo.newRating(
        rating: 1400,
        opponentRating: 1800,
        score: 1,
        gamesPlayed: 50,
      );
      final routine = Elo.newRating(
        rating: 1800,
        opponentRating: 1400,
        score: 1,
        gamesPlayed: 50,
      );
      expect(upset - 1400, greaterThan(routine - 1800));
    });

    test('K-factor schedule follows games played and rating', () {
      expect(Elo.kFactor(1200, 5), Elo.defaultKProvisional);
      expect(Elo.kFactor(1200, 100), Elo.defaultKEstablished);
      expect(Elo.kFactor(2500, 100), Elo.defaultKElite);
      // Provisional K applies regardless of rating.
      expect(Elo.kFactor(2500, 10), Elo.defaultKProvisional);
    });

    test('provisional status covers the first games', () {
      expect(Elo.isProvisional(0), isTrue);
      expect(Elo.isProvisional(Elo.provisionalGames - 1), isTrue);
      expect(Elo.isProvisional(Elo.provisionalGames), isFalse);
    });

    test('ratings stay within sane bounds', () {
      final crushed = Elo.newRating(
        rating: 100,
        opponentRating: 4000,
        score: 0,
        gamesPlayed: 100,
      );
      expect(crushed, greaterThanOrEqualTo(100));

      final boosted = Elo.newRating(
        rating: 3990,
        opponentRating: 100,
        score: 1,
        gamesPlayed: 100,
      );
      expect(boosted, lessThanOrEqualTo(4000));
    });

    test('calculate reports the full change details', () {
      final change = Elo.calculate(
        category: RatingCategory.blitz,
        rating: 1500,
        opponentRating: 1500,
        score: 1,
        gamesPlayed: 50,
      );
      expect(change.ratingBefore, 1500);
      expect(change.ratingAfter, 1510);
      expect(change.delta, 10);
      expect(change.kFactor, Elo.defaultKEstablished);
      expect(change.expectedScore, closeTo(0.5, 1e-9));
      expect(change.provisionalAfter, isFalse);
      expect(change.category, RatingCategory.blitz);
    });

    test('provisional flag is reported for new players', () {
      final change = Elo.calculate(
        category: RatingCategory.rapid,
        rating: 1200,
        opponentRating: 1200,
        score: 0.5,
        gamesPlayed: 3,
      );
      expect(change.provisionalAfter, isTrue);
    });
  });

  group('RatingPoint', () {
    test('JSON round-trip', () {
      final p = RatingPoint(
        rating: 1432,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1759500000000),
        delta: 14,
      );
      final back = RatingPoint.fromJson(p.toJson());
      expect(back.rating, 1432);
      expect(back.timestamp, p.timestamp);
      expect(back.delta, 14);
    });
  });
}
