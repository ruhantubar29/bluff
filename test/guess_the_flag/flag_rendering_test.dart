import 'package:bluff/core/theme/bluff_theme.dart';
import 'package:bluff/games/guess_the_flag/screens/guess_the_flag_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the flag is drawn with an emoji-capable fallback font',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BluffTheme.light,
        home: const GuessTheFlagScreen(),
      ),
    );
    await tester.pump();

    // The flag is the only Text on screen made of two regional indicators.
    Text? flag;
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final runes = text.data?.runes.toList() ?? const <int>[];
      final isFlag = runes.length == 2 &&
          runes.every((r) => r >= 0x1F1E6 && r <= 0x1F1FF);
      if (isFlag) {
        flag = text;
        break;
      }
    }

    expect(flag, isNotNull, reason: 'no flag emoji rendered on screen');
    expect(
      flag!.style?.fontFamilyFallback,
      contains('Noto Color Emoji Flags'),
      reason:
          'Without the flags font ahead of the theme\'s NotoSans, Android '
          'resolves the regional indicators to bare letters (IN, ID) instead '
          'of a flag. On Android 15 flags live in NotoColorEmojiFlags.ttf, '
          'not NotoColorEmoji.ttf.',
    );
  });
}
