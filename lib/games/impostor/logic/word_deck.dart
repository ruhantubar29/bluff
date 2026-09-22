import 'dart:math';

import '../../../core/language/app_language.dart';
import '../../../core/storage/app_storage.dart';
import '../data/bn/word_bank.dart' as bangla;
import '../data/en/word_bank.dart' as english;

class ImpostorWord {
  final String word;
  final String hint;

  const ImpostorWord({
    required this.word,
    required this.hint,
  });
}

class ImpostorWordDeck {
  ImpostorWordDeck._();

  static final ImpostorWordDeck instance =
      ImpostorWordDeck._();

  final Random _random = Random();

  final Map<String, List<int>> _wordQueues = {};

  final Map<String, Set<int>> _usedHintIndexes = {};

  bool _loaded = false;

  Future<void> initialize() async {
    if (_loaded) {
      return;
    }

    final state =
        await AppStorage.instance.loadWordDeckState();

    if (state != null) {
      _loadState(state);
    }

    _loaded = true;
  }

  void _loadState(Map<String, dynamic> state) {
    _wordQueues.clear();
    _usedHintIndexes.clear();

    final rawQueues = state['wordQueues'];

    if (rawQueues is Map) {
      for (final entry in rawQueues.entries) {
        final key = entry.key.toString();
        final value = entry.value;

        if (value is List) {
          _wordQueues[key] = value
              .whereType<num>()
              .map((number) => number.toInt())
              .toList();
        }
      }
    }

    final rawHints = state['usedHintIndexes'];

    if (rawHints is Map) {
      for (final entry in rawHints.entries) {
        final key = entry.key.toString();
        final value = entry.value;

        if (value is List) {
          _usedHintIndexes[key] = value
              .whereType<num>()
              .map((number) => number.toInt())
              .toSet();
        }
      }
    }
  }

  List<dynamic> _rawEntriesFor(
    AppLanguage language,
    String category,
  ) {
    if (language == AppLanguage.bangla) {
      return bangla.WordBank.entriesFor(category);
    }

    return english.WordBank.entriesFor(category);
  }

  String _queueKey(
    AppLanguage language,
    String category,
  ) {
    return '${language.code}:$category';
  }

  String _hintKey(
    AppLanguage language,
    String category,
    int wordIndex,
  ) {
    return '${language.code}:$category:$wordIndex';
  }

  Future<ImpostorWord> next({
    required AppLanguage language,
    required String category,
  }) async {
    await initialize();

    final entries =
        _rawEntriesFor(language, category);

    if (entries.isEmpty) {
      throw Exception(
        'No words available for category: $category',
      );
    }

    final queueKey =
        _queueKey(language, category);

    var queue = _wordQueues[queueKey];

    if (queue == null || queue.isEmpty) {
      queue = List<int>.generate(
        entries.length,
        (index) => index,
      )..shuffle(_random);

      _wordQueues[queueKey] = queue;
    }

    // Remove the word immediately from the current
    // cycle. This is important: once selected, the word
    // is considered played.
    final wordIndex = queue.removeAt(0);

    final entry = entries[wordIndex];

    final hints = entry.hints;

    if (hints.isEmpty) {
      final result = ImpostorWord(
        word: entry.word,
        hint: '',
      );

      // Persist BEFORE returning the generated word.
      await _saveState();

      return result;
    }

    final hintKey =
        _hintKey(
          language,
          category,
          wordIndex,
        );

    var usedHints =
        _usedHintIndexes[hintKey];

    if (usedHints == null) {
      usedHints = <int>{};
      _usedHintIndexes[hintKey] =
          usedHints;
    }

    if (usedHints.length >= hints.length) {
      usedHints.clear();
    }

    final availableHintIndexes =
        <int>[];

    for (var i = 0; i < hints.length; i++) {
      if (!usedHints.contains(i)) {
        availableHintIndexes.add(i);
      }
    }

    final selectedHintIndex =
        availableHintIndexes[
          _random.nextInt(
            availableHintIndexes.length,
          )
        ];

    usedHints.add(selectedHintIndex);

    final result = ImpostorWord(
      word: entry.word,
      hint: hints[selectedHintIndex],
    );

    // ----------------------------------------------------------
    // CRITICAL:
    //
    // The word has already been removed from the queue and the
    // hint has already been marked used.
    //
    // Save NOW, before returning the result.
    //
    // If Android kills the app immediately after this point,
    // this word + hint are still considered played.
    // ----------------------------------------------------------
    await _saveState();

    return result;
  }

  Future<void> _saveState() async {
    await AppStorage.instance.saveWordDeckState(
      wordQueues: _wordQueues,
      usedHintIndexes: _usedHintIndexes,
    );
  }

  List<String> categories(
    AppLanguage language,
  ) {
    if (language == AppLanguage.bangla) {
      return bangla.WordBank.bank.keys.toList();
    }

    return english.WordBank.bank.keys.toList();
  }

  Future<void> reset() async {
    _wordQueues.clear();
    _usedHintIndexes.clear();
    _loaded = true;

    await AppStorage.instance
        .clearWordDeckState();
  }
}