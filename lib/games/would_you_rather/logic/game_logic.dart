import '../../../core/language/app_language.dart';
import '../data/categories.dart';
import '../data/questions.dart';

/// Builds and deals the deck for one sitting.
///
/// The deck spans every selected category at once, shuffled together, so
/// picking three moods gives one interleaved run rather than three blocks
/// played back to back.
class WouldYouRatherGameLogic {
  WouldYouRatherGameLogic({
    required this.selectedCategoryIds,
    required this.language,
  }) {
    _prepareDeck();
  }

  final List<String> selectedCategoryIds;
  final AppLanguage language;

  late List<WouldYouRatherQuestion> _deck;
  int _index = 0;

  void _prepareDeck() {
    _deck = wouldYouRatherQuestions
        .where((question) => selectedCategoryIds.contains(question.category))
        .toList(growable: false);
    _deck.shuffle();
  }

  WouldYouRatherQuestion? get currentQuestion =>
      _index < _deck.length ? _deck[_index] : null;

  /// The two sides of the current choice, split and in the active language.
  List<String> get currentOptions {
    final question = currentQuestion;
    if (question == null) return const ['', ''];
    final source = language == AppLanguage.bangla ? question.bn : question.en;
    return source.split('|');
  }

  WouldYouRatherCategory? get currentCategory =>
      categoryById(currentQuestion?.category ?? '');

  /// 1-based position, shown as "3 / 14" in the top bar.
  int get position => _deck.isEmpty ? 0 : _index + 1;

  int get deckLength => _deck.length;

  bool get hasQuestions => _deck.isNotEmpty;

  /// Advances the deck and, like the original, reshuffles and keeps going
  /// rather than running a party into a dead end.
  void nextQuestion() {
    if (_deck.isEmpty) return;
    _index++;
    if (_index >= _deck.length) {
      _index = 0;
      _deck.shuffle();
    }
  }

  /// The share revealed after a pick.
  ///
  /// Deterministic in the English text, so the same dilemma always claims
  /// the same number and — unlike hashing the translation — the figure does
  /// not change when the app is switched to Bangla.
  static int percentageFor(String englishOptions) {
    var hash = 0;
    for (final unit in englishOptions.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return 26 + hash % 49;
  }
}
