import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../logic/impostor_round_generator.dart';
import '../../logic/word_deck.dart';
import '../../models/impostor_player.dart';
import '../../models/impostor_settings.dart';
import '../../../../core/language/app_language.dart';
import '../../../../core/language/language_settings.dart';

typedef _J = Map<String, dynamic>;

const _characterCount = 35;

_J _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
String _code(String c) => c.trim().toUpperCase();
List<String> _clean(List<String> l) =>
    l.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
int _int(dynamic v, int d) => (v as num?)?.toInt() ?? d;

class RoomService {
  RoomService._();
  static final RoomService instance = RoomService._();

  static const _playerIdKey = 'bluff_multiplayer_player_id';

  final _firestore = FirebaseFirestore.instance;
  String? _cachedPlayerId;

  CollectionReference<_J> get _rooms => _firestore.collection('rooms');
  DocumentReference<_J> _ref(String c) => _rooms.doc(_code(c));
  CollectionReference<_J> _chat(String c) => _ref(c).collection('chat');
  CollectionReference<_J> _votes(String c) => _ref(c).collection('votes');

  // ── Player id ─────────────────────────────────────────────────────────

  Future<String> _getPlayerId() async {
    if (_cachedPlayerId != null) return _cachedPlayerId!;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_playerIdKey)?.trim();
    if (saved != null && saved.isNotEmpty) return _cachedPlayerId = saved;

    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random();
    final part = List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
    final id = 'player_${DateTime.now().microsecondsSinceEpoch}_$part';
    await prefs.setString(_playerIdKey, id);
    return _cachedPlayerId = id;
  }

  Future<String> getPlayerId() => _getPlayerId();

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ── Shared helpers ────────────────────────────────────────────────────

  void _validate(int count, bool random, bool auto, String type) {
    if (count < 1 || count > 6) {
      throw Exception('Impostor count must be between 1 and 6.');
    }
    if (random && auto) {
      throw Exception('Random and Auto impostor modes cannot be enabled together.');
    }
    if (type != 'private' && type != 'public') {
      throw Exception('Invalid room type.');
    }
  }

  _J _cfg(String type, int count, bool random, bool auto, bool hints,
          List<String> cats, String lang) =>
      {
        'roomType': type,
        'impostorCount': count,
        'randomImpostorCount': random,
        'autoImpostorCount': auto,
        'hintsEnabled': hints,
        'categories': _clean(cats),
        'language': lang,
      };

  _J _player(String id, String name, bool host) => {
        'id': id,
        'name': name,
        'isHost': host,
        'ready': false,
        'revealReady': false,
        'score': 0,
        'joinedAt': FieldValue.serverTimestamp(),
      };

  /// Loads the room and checks the caller is the host.
  Future<(DocumentReference<_J>, _J)> _hostRoom(
      String roomCode, String denied) async {
    final me = await _getPlayerId();
    final ref = _ref(roomCode);
    final d = (await ref.get()).data();
    if (d == null) throw Exception('Room not found.');
    if (d['hostId'] != me) throw Exception(denied);
    return (ref, d);
  }

  // ── Create / join ─────────────────────────────────────────────────────

  Future<String> createRoom({
    required String playerName,
    int impostorCount = 1,
    bool randomImpostorCount = false,
    bool autoImpostorCount = false,
    bool hintsEnabled = true,
    List<String> categories = const [],
    String roomType = 'private',
  }) async {
    final me = await _getPlayerId();
    _validate(impostorCount, randomImpostorCount, autoImpostorCount, roomType);

    String code;
    do {
      code = _generateRoomCode();
    } while ((await _rooms.doc(code).get()).exists);

    final name = playerName.trim().isEmpty ? 'Player' : playerName.trim();

    await _rooms.doc(code).set({
      'roomCode': code,
      'hostId': me,
      'status': 'waiting',
      'roundNumber': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'settings': _cfg(roomType, impostorCount, randomImpostorCount,
          autoImpostorCount, hintsEnabled, categories,
          LanguageSettings.instance.language.code),
      'players': {me: _player(me, name, true)},
      'votesSubmitted': 0,
      'result': null,
      'playerOrder': <String>[],
      'startingPlayerId': null,
      'clueRound': 0,
      'currentCluePlayerId': null,
      'currentClueIndex': null,
      'clueTurnStartedAt': null,
      'clues': <String, dynamic>{},
      'matchId': null,
      'charBag': <int>[],
    });
    return code;
  }

  Future<void> joinRoom({
    required String roomCode,
    required String playerName,
  }) async {
    final me = await _getPlayerId();
    final code = _code(roomCode);
    final ref = _rooms.doc(code);
    final d = (await ref.get()).data();

    if (d == null) throw Exception('Room not found.');
    if ((d['status'] ?? 'waiting') != 'waiting') {
      throw Exception('This game has already started.');
    }
    final players = _m(d['players']);
    if (players.containsKey(me)) return;
    if (players.length >= 20) throw Exception('This room is full.');

    final name = playerName.trim().isEmpty
        ? 'Player ${players.length + 1}'
        : playerName.trim();

    final batch = _firestore.batch();
    batch.update(ref, {'players.$me': _player(me, name, false)});
    batch.set(_chat(code).doc(), {
      'type': 'join',
      'senderId': me,
      'senderName': name,
      'text': '$name joined',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Stream<DocumentSnapshot<_J>> roomStream(String roomCode) =>
      _ref(roomCode).snapshots();

  // ── Settings ──────────────────────────────────────────────────────────

  Future<void> updateSettings({
    required String roomCode,
    required int impostorCount,
    required bool randomImpostorCount,
    required bool hintsEnabled,
    required List<String> categories,
    required AppLanguage language,
    bool autoImpostorCount = false,
    String roomType = 'private',
  }) async {
    _validate(impostorCount, randomImpostorCount, autoImpostorCount, roomType);
    final (ref, _) =
        await _hostRoom(roomCode, 'Only the host can change settings.');
    await ref.update({
      'settings': _cfg(roomType, impostorCount, randomImpostorCount,
          autoImpostorCount, hintsEnabled, categories, language.code),
    });
  }

  int _autoCount(int n) =>
      n >= 16 ? 6 : n >= 13 ? 5 : n >= 10 ? 4 : n >= 7 ? 3 : n >= 5 ? 2 : 1;

  int _required(int count, bool random) =>
      random ? 3 : const {1: 3, 2: 5, 3: 7, 4: 10, 5: 13, 6: 16}[count] ?? 3;

  // ── Start game ────────────────────────────────────────────────────────

  Future<void> startGame({required String roomCode}) async {
    final (ref, d) = await _hostRoom(roomCode, 'Only the host can start the game.');

    if ((d['status'] ?? 'waiting') != 'waiting') {
      throw Exception('The game has already started.');
    }
    final pm = _m(d['players']);
    if (pm.length > ImpostorSettings.maxPlayers) {
      throw Exception('Too many players.');
    }

    final s = _m(d['settings']);
    final random = s['randomImpostorCount'] as bool? ?? false;
    final auto = s['autoImpostorCount'] as bool? ?? false;
    final count = (auto ? _autoCount(pm.length) : _int(s['impostorCount'], 1))
        .clamp(1, 6)
        .toInt();

    final need = _required(count, random);
    if (pm.length < need) throw Exception('At least $need players are required.');

    final language =
        (s['language'] as String?) == 'en' ? AppLanguage.english : AppLanguage.bangla;
    final stored = List<String>.from(s['categories'] ?? []);
    final categories =
        stored.isEmpty ? ImpostorWordDeck.instance.categories(language) : stored;
    if (categories.isEmpty) throw Exception('No categories are available.');
    final hints = s['hintsEnabled'] as bool? ?? true;

    final ids = pm.keys.toList();
    final round = await ImpostorRoundGenerator.instance.generate(
      settings: ImpostorSettings(
        playerCount: ids.length,
        impostorCount: count,
        categories: categories,
        hintsEnabled: hints,
        randomImpostorCount: random,
        language: language,
      ),
      players: [
        for (final id in ids)
          ImpostorPlayer(name: _m(pm[id])['name'] as String? ?? 'Player'),
      ],
    );

    // Character bag: everyone gets a different character, and a character
    // cannot return until all 35 have been used. The bag lives in the room,
    // so the cycle continues across rematches.
    final bag = List<int>.from(d['charBag'] ?? []);
    final chars = <int>[];
    for (var i = 0; i < ids.length; i++) {
      if (bag.isEmpty) {
        bag.addAll(List<int>.generate(_characterCount, (k) => k)
            .where((k) => !chars.contains(k))
            .toList()
          ..shuffle());
      }
      chars.add(bag.removeLast());
    }

    final startIdx = round.startingPlayerIndex;
    final batch = _firestore.batch();

    batch.update(ref, {
      'status': 'reveal',
      'roundNumber': 1,
      'matchId': DateTime.now().microsecondsSinceEpoch.toString(),
      'charBag': bag,
      'startingPlayerId': startIdx == null ? null : ids[startIdx],
      'playerOrder': ids,
      'clueRound': 0,
      'currentCluePlayerId': null,
      'currentClueIndex': null,
      'clueTurnStartedAt': null,
      'clues': <String, dynamic>{},
      'votesSubmitted': 0,
      'result': null,
      'players': pm.map((k, v) => MapEntry(k, {
            ..._m(v),
            'score': _int(_m(v)['score'], 0),
            'revealReady': false,
          })),
      'settings': _cfg(s['roomType'] as String? ?? 'private', count, random,
          auto, hints, categories, language.code),
    });

    for (var i = 0; i < ids.length; i++) {
      final imp = round.isImpostor(i);
      batch.set(ref.collection('private').doc(ids[i]), {
        'role': imp ? 'impostor' : 'civilian',
        'secretWord': imp ? null : round.secretWord,
        'hint': imp ? round.hint : null,
        'category': round.category,
        'character': chars[i],
        'revealed': false,
      });
    }
    await batch.commit();
  }

  // ── Reveal ready ──────────────────────────────────────────────────────

  Future<void> markRevealReady({required String roomCode}) async {
    final me = await _getPlayerId();
    final ref = _ref(roomCode);

    // Only this player's own flag: shows up in everyone's count immediately.
    await ref.update({'players.$me.revealReady': true});
    await ref.collection('private').doc(me).update({'revealed': true});

    // Start the clue round only if everyone is ready.
    await _firestore.runTransaction((tx) async {
      final d = (await tx.get(ref)).data();
      if (d == null || d['status'] != 'reveal') return;

      final players = _m(d['players']);
      if (players.isEmpty ||
          !players.values.every((p) => _m(p)['revealReady'] == true)) {
        return;
      }

      final order = List<String>.from(d['playerOrder'] ?? []);
      if (order.isEmpty) throw Exception('Player order is missing.');
      final i = max(0, order.indexOf(d['startingPlayerId'] as String? ?? ''));

      tx.update(ref, {
        'status': 'clue_round_1',
        'clueRound': 1,
        'currentClueIndex': i,
        'currentCluePlayerId': order[i],
        'clueTurnStartedAt': FieldValue.serverTimestamp(),
        'clues': <String, dynamic>{},
      });
    });
  }

  // ── Clues (submit / skip / timeout share one transaction) ─────────────

  /// Fields that move the game to the next clue turn / round / discussion.
  _J _next(_J d) {
    final order = List<String>.from(d['playerOrder'] ?? []);
    final i = _int(d['currentClueIndex'], 0) + 1;
    final ts = FieldValue.serverTimestamp();
    if (i < order.length) {
      return {
        'currentClueIndex': i,
        'currentCluePlayerId': order[i],
        'clueTurnStartedAt': ts,
      };
    }
    if (_int(d['clueRound'], 0) == 1) {
      return {
        'status': 'clue_round_2',
        'clueRound': 2,
        'currentClueIndex': 0,
        'currentCluePlayerId': order[0],
        'clueTurnStartedAt': ts,
      };
    }
    return {
      'status': 'discussion',
      'clueRound': 2,
      'currentClueIndex': null,
      'currentCluePlayerId': null,
      'clueTurnStartedAt': null,
    };
  }

  /// [type]: 'clue' | 'skip' | 'timeout'. For 'timeout' [asId]/[round] must
  /// still match the live turn, otherwise it silently does nothing.
  Future<void> _turn(
    String roomCode,
    String type, {
    String? clue,
    String? asId,
    int? round,
  }) async {
    final me = await _getPlayerId();
    final code = _code(roomCode);
    final ref = _rooms.doc(code);
    final strict = type != 'timeout';

    await _firestore.runTransaction((tx) async {
      void fail(String m) {
        if (strict) throw Exception(m);
      }

      final d = (await tx.get(ref)).data();
      if (d == null) return fail('Room not found.');

      final status = d['status'];
      if (status != 'clue_round_1' && status != 'clue_round_2') {
        return fail('It is not clue time.');
      }

      final who = asId ?? me;
      final cr = _int(d['clueRound'], 0);
      if (d['currentCluePlayerId'] != who || (round != null && round != cr)) {
        return fail(type == 'clue'
            ? 'It is not your turn to give a clue.'
            : 'It is not your turn.');
      }
      if (List.from(d['playerOrder'] ?? []).isEmpty) {
        return fail('Player order is missing.');
      }

      final clues = _m(d['clues']);
      final mine = _m(clues[who]);
      if (type == 'clue') {
        if (mine['clue$cr'] != null) throw Exception('You already gave this clue.');
        mine['clue$cr'] = clue;
      } else {
        mine[type == 'skip' ? 'skip$cr' : 'out$cr'] = true;
      }
      clues[who] = mine;

      final name = _m(_m(d['players'])[who])['name'] as String? ?? 'Player';
      tx.update(ref, {..._next(d), 'clues': clues});
      tx.set(_chat(code).doc(), {
        'type': type,
        'senderId': who,
        'senderName': name,
        'text': type == 'clue'
            ? clue
            : type == 'skip'
                ? '$name skipped'
                : '$name ran out of time',
        'clueRound': cr,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> submitClue({required String roomCode, required String text}) {
    final t = text.trim();
    if (t.isEmpty) throw Exception('Clue cannot be empty.');
    if (t.length > 300) throw Exception('Clue is too long.');
    return _turn(roomCode, 'clue', clue: t);
  }

  Future<void> skipClue({required String roomCode}) => _turn(roomCode, 'skip');

  /// Timing is decided by the client (local timer); this only applies if the
  /// expected player and round are still the live turn.
  Future<void> expireClueTurn({
    required String roomCode,
    String? playerId,
    int? round,
  }) =>
      _turn(roomCode, 'timeout', asId: playerId, round: round);

  // ── Voting ────────────────────────────────────────────────────────────

  Future<void> startVoting({required String roomCode}) async {
    final (ref, d) = await _hostRoom(roomCode, 'Only the host can start voting.');
    if (d['status'] != 'discussion') {
      throw Exception('The discussion has not finished.');
    }
    final players = _m(d['players']);
    if (players.isEmpty) throw Exception('No players found.');

    final code = _code(roomCode);
    final batch = _firestore.batch();
    for (final id in players.keys) {
      batch.delete(_votes(code).doc(id));
    }
    batch.update(ref, {
      'status': 'voting',
      'votesSubmitted': 0,
      'votingStartedAt': FieldValue.serverTimestamp(),
      'result': null,
    });
    batch.set(_chat(code).doc(), {
      'type': 'system',
      'senderId': d['hostId'],
      'senderName': 'System',
      'text': 'Voting started',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> submitVote({
    required String roomCode,
    required List<String> accusedPlayerIds,
  }) async {
    final me = await _getPlayerId();
    final code = _code(roomCode);
    final ref = _rooms.doc(code);
    final voteRef = _votes(code).doc(me);
    final votes = accusedPlayerIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final d = (await ref.get()).data();
    if (d == null) throw Exception('Room not found.');
    if (d['status'] != 'voting') throw Exception('It is not voting time.');

    final players = _m(d['players']);
    if (!players.containsKey(me)) throw Exception('You are not in this room.');
    if (votes.contains(me)) throw Exception('You cannot vote for yourself.');
    if (votes.any((t) => !players.containsKey(t))) {
      throw Exception('Invalid player vote.');
    }

    final s = _m(d['settings']);
    final random = s['randomImpostorCount'] as bool? ?? false;
    final count = _int(s['impostorCount'], 1);

    if (!random && votes.length != count) {
      throw Exception('You must select exactly $count '
          'player${count == 1 ? '' : 's'}.');
    }
    if (random && votes.length > count) {
      throw Exception('You selected too many players.');
    }
    if ((await voteRef.get()).exists) throw Exception('You have already voted.');

    await voteRef.set({
      'voterId': me,
      'accusedPlayerIds': votes,
      'submittedAt': FieldValue.serverTimestamp(),
    });
    await ref.update({'votesSubmitted': FieldValue.increment(1)});
  }

  Stream<QuerySnapshot<_J>> voteStream(String roomCode) =>
      _votes(roomCode).snapshots();

  Stream<DocumentSnapshot<_J>> currentPlayerVoteStream(String roomCode) =>
      Stream.fromFuture(_getPlayerId())
          .asyncExpand((id) => _votes(roomCode).doc(id).snapshots());

  Future<void> finalizeVoting({required String roomCode}) async {
    final (ref, d) =
        await _hostRoom(roomCode, 'Only the host can finalize voting.');
    if (d['status'] != 'voting') return;

    final players = _m(d['players']);
    final ids = players.keys.toList();
    if (ids.isEmpty) throw Exception('No players found.');

    final docs = (await _votes(roomCode).get()).docs;
    if (docs.length < ids.length) throw Exception('Not everyone has voted yet.');

    final s = _m(d['settings']);
    final random = s['randomImpostorCount'] as bool? ?? false;
    final need = _int(s['impostorCount'], 1);

    // Votes: voter -> accused list
    final accusedOf = {
      for (final v in docs)
        v.id: List<String>.from(v.data()['accusedPlayerIds'] ?? []),
    };
    final counts = <String, int>{};
    var none = 0;
    accusedOf.forEach((_, a) {
      if (random && a.isEmpty) none++;
      for (final t in a) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    });

    final order = List<String>.from(d['playerOrder'] ?? ids);
    final pos = {for (var i = 0; i < order.length; i++) order[i]: i};
    final ranked = counts.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0
            ? c
            : (pos[a.key] ?? 999999).compareTo(pos[b.key] ?? 999999);
      });

    // Final accusation
    final accused = <String>{};
    var draw = false;
    if (!random) {
      accused.addAll(ranked.take(need).map((e) => e.key));
    } else {
      final maj = ids.length ~/ 2 + 1;
      final cand =
          counts.entries.where((e) => e.value >= maj).map((e) => e.key).toList();
      final noneMaj = none >= maj;
      draw = cand.isEmpty ? !noneMaj : noneMaj;
      if (!draw) accused.addAll(cand);
    }

    // Actual impostors
    final snaps = await Future.wait(
        ids.map((id) => ref.collection('private').doc(id).get()));
    final imps = <String>{};
    for (var i = 0; i < ids.length; i++) {
      if (!snaps[i].exists) throw Exception('Private player data is missing.');
      if (snaps[i].data()!['role'] == 'impostor') imps.add(ids[i]);
    }

    final playersWon =
        !draw && accused.length == imps.length && accused.containsAll(imps);

    // Impostors who were only caught because of a tie at the cutoff
    final tie = <String>{};
    if (!random && need > 0 && ranked.length >= need) {
      final cutoff = ranked[need - 1].value;
      for (final e in ranked) {
        if (e.value == cutoff &&
            imps.contains(e.key) &&
            accused.contains(e.key)) {
          tie.add(e.key);
        }
      }
    }

    // Scores
    final earned = {for (final id in ids) id: 0};
    void add(String id, int n) => earned[id] = (earned[id] ?? 0) + n;

    if (imps.isEmpty) {
      accusedOf.forEach((v, a) => add(v, a.isEmpty ? 5 : -a.length));
    } else {
      accusedOf.forEach((v, a) {
        if (imps.contains(v)) return;
        add(v, a.fold<int>(0, (sum, t) => sum + (imps.contains(t) ? 5 : -1)));
      });
      for (final i in imps) {
        if (!accused.contains(i)) {
          add(i, 10);
        } else if (tie.contains(i)) {
          add(i, 5);
        }
      }
    }

    final totals = <String, int>{};
    final updated = <String, dynamic>{};
    for (final id in ids) {
      final p = _m(players[id]);
      totals[id] = _int(p['score'], 0) + (earned[id] ?? 0);
      updated[id] = {...p, 'score': totals[id]};
    }

    await ref.update({
      'players': updated,
      'status': 'result',
      'result': {
        'isDraw': draw,
        'playersWon': playersWon,
        'accusedPlayerIds': accused.toList(),
        'actualImpostorIds': imps.toList(),
        'roundScores': earned,
        'totalScores': totals,
        'tieCaughtImpostorIds': tie.toList(),
      },
      'votesSubmitted': docs.length,
    });
  }

  // ── Return to lobby ───────────────────────────────────────────────────

  Future<void> returnToLobby({required String roomCode}) async {
    final me = await _getPlayerId();
    final ref = _ref(roomCode);

    await _firestore.runTransaction((tx) async {
      final d = (await tx.get(ref)).data();
      if (d == null) throw Exception('Room not found.');
      if (d['hostId'] != me) {
        throw Exception('Only the host can return to the lobby.');
      }
      if (d['status'] != 'result') {
        throw Exception('The current round has not finished.');
      }
      tx.update(ref, {
        'status': 'waiting',
        'players': _m(d['players']).map((k, v) =>
            MapEntry(k, {..._m(v), 'ready': false, 'revealReady': false})),
        'votesSubmitted': 0,
        'result': null,
        'startingPlayerId': null,
        'clueRound': 0,
        'currentCluePlayerId': null,
        'currentClueIndex': null,
        'clueTurnStartedAt': null,
        'clues': <String, dynamic>{},
      });
    });
  }

  // ── Chat ──────────────────────────────────────────────────────────────

  Stream<QuerySnapshot<_J>> chatStream(String roomCode) => _chat(roomCode)
      .orderBy('createdAt', descending: false)
      .limitToLast(100)
      .snapshots();

  Future<void> sendChatMessage({
    required String roomCode,
    required String text,
  }) async {
    final me = await _getPlayerId();
    final t = text.trim();
    if (t.isEmpty) return;
    if (t.length > 500) throw Exception('Message is too long.');

    final d = (await _ref(roomCode).get()).data();
    if (d == null) throw Exception('Room not found.');
    final players = _m(d['players']);
    if (!players.containsKey(me)) throw Exception('You are not in this room.');

    await _chat(roomCode).add({
      'type': 'message',
      'senderId': me,
      'senderName': _m(players[me])['name'] as String? ?? 'Player',
      'text': t,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot<_J>> privatePlayerStream(String roomCode) =>
      Stream.fromFuture(_getPlayerId()).asyncExpand(
          (id) => _ref(roomCode).collection('private').doc(id).snapshots());

  // ── Leave room ────────────────────────────────────────────────────────

  Future<void> leaveRoom({required String roomCode}) async {
    final me = await _getPlayerId();
    final code = _code(roomCode);
    final ref = _rooms.doc(code);

    await _firestore.runTransaction((tx) async {
      final d = (await tx.get(ref)).data();
      if (d == null) return;
      final players = _m(d['players']);
      if (!players.containsKey(me)) return;

      final name = _m(players[me])['name']?.toString() ?? 'Player';
      final wasHost = d['hostId']?.toString() == me;
      players.remove(me);

      if (players.isEmpty) {
        tx.delete(ref);
        return;
      }

      var text = '$name left';
      final up = <String, dynamic>{'players': players};

      if (wasHost) {
        // Earliest joiner becomes host (old rooms without joinedAt: first).
        String? host;
        Timestamp? oldest;
        players.forEach((k, v) {
          final j = _m(v)['joinedAt'];
          if (j is Timestamp && (oldest == null || j.compareTo(oldest!) < 0)) {
            oldest = j;
            host = k;
          }
        });
        host ??= players.keys.first;

        players.updateAll((k, v) => {..._m(v), 'isHost': k == host});
        up['hostId'] = host;
        text += '. ${_m(players[host])['name'] ?? 'Player'} is now the host.';
      }

      tx.update(ref, up);
      tx.set(_chat(code).doc(), {
        'type': 'leave',
        'senderId': me,
        'senderName': name,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}