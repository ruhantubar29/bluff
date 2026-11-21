import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';
import '../../../core/language/language_settings.dart';
import '../widgets/glow_background.dart';

/// The five beats of a round, in both languages.
class _Step {
  const _Step(this.titleEn, this.bodyEn, this.titleBn, this.bodyBn);

  final String titleEn;
  final String bodyEn;
  final String titleBn;
  final String bodyBn;
}

const List<_Step> _steps = [
  _Step(
    'Pick your categories',
    'Choose one mood or several. They all get shuffled into one deck, so a '
    'sitting can swing from silly to serious without stopping.',
    'ক্যাটাগরি বেছে নাও',
    'একটা বা একাধিক মুড বেছে নাও। সবগুলো একসাথে একটি ডেকে মেশানো হয়, '
    'তাই মজা থেকে গভীর — থামা ছাড়াই বদলায়।',
  ),
  _Step(
    'Read both sides',
    'Two cards, one impossible choice. Read them out loud and talk it through '
    'before anyone commits.',
    'দুই পাশটা পড়ো',
    'দুটো কার্ড, একটা অসম্ভব পছন্দ। কেউ সিদ্ধান্ত নেওয়ার আগে সবাই মিলে '
    'উচ্চ কণ্ঠে পড়ো আর যুক্তি দাও।',
  ),
  _Step(
    'Tap your answer',
    'Your side lights up, the other fades, and both show how many players '
    'picked the same side.',
    'তোমার উত্তরে ট্যাপ করো',
    'তোমার পাশটা জ্বলে ওঠে, অন্যটা ম্লান হয়, আর দুটোতেই দেখা যায় কতজন '
    'একই পক্ষে গেছে।',
  ),
  _Step(
    'Hit Next',
    'The cards flip away and a new dilemma slides in. Nothing repeats until '
    'the whole deck has been dealt.',
    'Next চাপো',
    'কার্ডগুলো সরে যায় আর নতুন প্রশ্ন এসে বসে। পুরো ডেক শেষ না হওয়া '
    'পর্যন্ত কিছুই আবার আসে না।',
  ),
  _Step(
    'Play together',
    'Take turns choosing, then make everyone defend the side they picked.',
    'সবাই মিলে খেলো',
    'পালা করে করে উত্তর দাও, তারপর যার যে পাশ পড়েছে তাকে তার যুক্তি '
    'দিতে বাধ্য করো।',
  ),
];

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isBangla = LanguageSettings.instance.language.code == 'bn';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D14),
      body: Stack(
        children: [
          const GlowBackground(
            warm: Color(0xFFFF3B30),
            cool: Color(0xFF0A7AFF),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        isBangla ? 'কীভাবে খেলবে' : 'How to play',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    itemCount: _steps.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      final title =
                          isBangla ? step.titleBn : step.titleEn;
                      final body = isBangla ? step.bodyBn : step.bodyEn;

                      return _StepTile(
                        index: index,
                        title: title,
                        body: body,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.title,
    required this.body,
  });

  final int index;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 18 * (1 - value)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFF3B30), Color(0xFFFF9500)],
                ),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
