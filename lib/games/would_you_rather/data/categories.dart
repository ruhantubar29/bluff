import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';

/// One of the five moods the game ships with.
///
/// Every label carries both languages side by side, so adding a language or
/// rewording one means editing a single line rather than chasing two files.
class WouldYouRatherCategory {
  const WouldYouRatherCategory({
    required this.id,
    required this.icon,
    required this.nameEn,
    required this.nameBn,
    required this.descEn,
    required this.descBn,
    required this.warm,
    required this.cool,
  });

  /// Stable key questions use to say which category they belong to.
  final String id;

  /// Emoji shown on the category tile and in the game's top bar.
  final String icon;

  final String nameEn;
  final String nameBn;
  final String descEn;
  final String descBn;

  /// Four colours each, taken from the original design.
  ///
  /// Option A draws its gradient from [warm], option B from [cool], and both
  /// — along with the screen glow — step through the list as the deck
  /// advances, so consecutive questions never look quite the same.
  final List<Color> warm;
  final List<Color> cool;

  String name(AppLanguage language) =>
      language == AppLanguage.bangla ? nameBn : nameEn;

  String description(AppLanguage language) =>
      language == AppLanguage.bangla ? descBn : descEn;

  Color warmAt(int step) => warm[step % warm.length];

  Color coolAt(int step) => cool[step % cool.length];
}

const List<WouldYouRatherCategory> wouldYouRatherCategories = [
  WouldYouRatherCategory(
    id: 'classic',
    icon: '😄',
    nameEn: 'Classic',
    nameBn: 'ক্লাসিক',
    descEn: 'Lighthearted questions that are always playable and perfect '
        'for any group.',
    descBn: 'হালকা মজার প্রশ্ন — যেকোনো দলের সাথে যেকোনো সময় খেলা যায়।',
    warm: [
      Color(0xFFFF3B30),
      Color(0xFFFF6A2B),
      Color(0xFFFF9500),
      Color(0xFFFF453A),
    ],
    cool: [
      Color(0xFF0A7AFF),
      Color(0xFF4FB4FF),
      Color(0xFF1F5FFF),
      Color(0xFF00A2FF),
    ],
  ),
  WouldYouRatherCategory(
    id: 'party',
    icon: '🎉',
    nameEn: 'Party',
    nameBn: 'পার্টি',
    descEn: 'Fun and chaotic questions made for wild nights and loud laughs.',
    descBn: 'পাগল রাত আর জোরে হাসির জন্য মজার ও হাস্যকর প্রশ্ন।',
    warm: [
      Color(0xFFFF2D92),
      Color(0xFFFF6B35),
      Color(0xFFFFB300),
      Color(0xFFFF4D6D),
    ],
    cool: [
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
      Color(0xFF6366F1),
      Color(0xFF22D3EE),
    ],
  ),
  WouldYouRatherCategory(
    id: 'spicy',
    icon: '🔥',
    nameEn: 'Spicy',
    nameBn: 'ঝাঁঝালো',
    descEn: 'Flirty, bold and a little out of bounds. Not for the shy.',
    descBn: 'ফ্লার্টি, সাহসী একটু সীমা ছাড়াই। লাজুকদের জন্য নয়।',
    warm: [
      Color(0xFFFF2E63),
      Color(0xFFFF5E7E),
      Color(0xFFD90429),
      Color(0xFFFF4081),
    ],
    cool: [
      Color(0xFFB5179E),
      Color(0xFFF72585),
      Color(0xFF7209B7),
      Color(0xFFE0409A),
    ],
  ),
  WouldYouRatherCategory(
    id: 'taboo',
    icon: '🙈',
    nameEn: 'Taboo & Cringe',
    nameBn: 'ট্যাবু ও ক্রিঞ্জ',
    descEn: 'Embarrassing truths and forbidden thoughts no one wants to '
        'admit.',
    descBn: 'লজ্জাজনক সত্য আর নিষিদ্ধ চিন্তা — যা কেউ মানতে চায় না।',
    warm: [
      Color(0xFF84CC16),
      Color(0xFFFACC15),
      Color(0xFF22C55E),
      Color(0xFFA3E635),
    ],
    cool: [
      Color(0xFFF97316),
      Color(0xFFEF4444),
      Color(0xFFFB923C),
      Color(0xFFF43F5E),
    ],
  ),
  WouldYouRatherCategory(
    id: 'deep',
    icon: '🌑',
    nameEn: 'Deep & Dark',
    nameBn: 'গভীর ও অন্ধকার',
    descEn: 'Unfiltered honesty, emotional depth and things we rarely say '
        'out loud.',
    descBn: 'বাধাহীন সততা, গভীর আবেগ আর যা আমরা কখনো বলি না।',
    warm: [
      Color(0xFF1E293B),
      Color(0xFF334155),
      Color(0xFF0F172A),
      Color(0xFF3B3B5C),
    ],
    cool: [
      Color(0xFF312E81),
      Color(0xFF4C1D95),
      Color(0xFF1E1B4B),
      Color(0xFF581C87),
    ],
  ),
];

/// Looks a category up by the id its questions carry.
WouldYouRatherCategory? categoryById(String id) {
  for (final category in wouldYouRatherCategories) {
    if (category.id == id) return category;
  }
  return null;
}
