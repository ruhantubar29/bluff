import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/language/app_language.dart';
import '../../core/language/language_settings.dart';
import '../../core/profile/avatars.dart';
import '../../core/profile/avatar_photo.dart';
import '../../core/profile/profile.dart';
import '../../core/profile/profile_repository.dart';
import '../home/home_screen.dart';

const _dark = Color(0xff09090E);
const _red = Color(0xffC62828);
const _highlight = Color(0xffFFD166);

/// Splash-style first-run flow. Runs once, right after bootstrap, and
/// produces the local profile that the hidden anonymous account syncs.
///
/// Seven steps: language → name → avatar → gender → age → group → source.
/// The choice steps (language, gender, age, group, source) commit on tap
/// and advance themselves; only the name and avatar steps carry a
/// CONTINUE bar.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _lastStep = 6;

  int _step = 0;
  bool _saving = false;

  /// Choice steps (language, gender, age, group, source) start empty: the
  /// player has to tap an option, which highlights it and auto-advances.
  /// This set remembers which of those steps have actually been answered.
  final Set<int> _pickedSteps = {};

  final TextEditingController _nameController = TextEditingController();
  Timer? _nameDebounce;

  late final PageController _avatarPageController;

  Profile _draft = const Profile();

  bool get _isBangla => LanguageSettings.instance.language.code == 'bn';

  String _t(String en, String bn) => _isBangla ? bn : en;

  /// Steps that commit on tap (no CONTINUE bar): language, then the four
  /// survey questions. Name and avatar are the exceptions.
  bool _isChoiceStep(int step) => step == 0 || step >= 3;

  @override
  void initState() {
    super.initState();

    _avatarPageController = PageController(viewportFraction: 0.62);

    _resumeDraft();
  }

  /// Picks the flow back up where a crash or force-stop left it, instead of
  /// dropping the player at 1/7 after they answered six steps.
  Future<void> _resumeDraft() async {
    final saved = await ProfileRepository.instance.loadOnboardingDraft();
    if (!mounted || saved == null) return;

    setState(() {
      _draft = saved.profile;
      _step = saved.step > _lastStep ? _lastStep : saved.step;
      // Everything behind us was answered to get here, so those choice
      // steps show as picked again after a resume.
      for (var i = 0; i < _step; i++) {
        if (_isChoiceStep(i)) _pickedSteps.add(i);
      }
      if (_draft.name.trim().isNotEmpty) {
        _nameController.text = _draft.name.trim();
      }
    });

    // A resume can land mid-avatar with a saved pick; realign the carousel.
    if (_step == 2 && _draft.avatarIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _avatarPageController.hasClients) {
          _avatarPageController.jumpToPage(_draft.avatarIndex % kAvatarCount);
        }
      });
    }
  }

  /// Cheap durability: one prefs write per step so progress never rewinds.
  void _persistDraft() {
    // The name lives in the controller until finish; mirror it into the
    // draft so a resume on a later step still shows who the player is.
    final typed = _nameController.text.trim();
    if (typed.isNotEmpty) {
      _draft = _draft.copyWith(name: typed);
    }
    ProfileRepository.instance.saveOnboardingDraft(_draft, _step);
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _nameController.dispose();
    _avatarPageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == _lastStep) {
      _finish();
      return;
    }

    setState(() => _step++);
    _persistDraft();
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _persistDraft();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);

    final name = _nameController.text.trim();
    final profile = _draft.copyWith(
      name: name.isEmpty ? 'Player' : name,
      languageCode: LanguageSettings.instance.language.code,
    );

    try {
      await ProfileRepository.instance.completeOnboarding(profile);
    } catch (_) {
      // Local write failed — let the player tap again rather than
      // strand them on a dead spinner.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Could not save. Tap the option again.',
              'সেভ হয়নি। আবার অপশনে চাপুন।',
            ),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    // The seven steps land on home. The Bluff ID window is not part of
    // the flow — home shows first, and about a second later the prompt
    // pops over it (BluffIdPrompt, triggered by HomeScreen).
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  bool get _canContinue {
    if (_step == 1) {
      final name = _nameController.text.trim();
      return name.length >= 2;
    }
    // Choice steps have no CONTINUE bar at all — they finish on tap — but
    // the auto-advance still checks this before moving on.
    if (_isChoiceStep(_step)) {
      return _pickedSteps.contains(_step);
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final progress = (_step + 1) / (_lastStep + 1);

    return Scaffold(
      backgroundColor: _dark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Opacity(
                    opacity: _step == 0 ? 0 : 1,
                    child: IconButton(
                      onPressed: _step == 0 ? null : _back,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(_highlight),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_step + 1}/${_lastStep + 1}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildStep(),
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    // The choice steps (language, gender → source) commit on tap and
    // finish the flow themselves — Splash shows no CONTINUE bar on them.
    if (_isChoiceStep(_step)) return const SizedBox(height: 0);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: _red,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _red.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: _canContinue ? _next : null,
        child: Text(
          _t('CONTINUE', 'চালিয়ে যান'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEPS
  // ---------------------------------------------------------------------------

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _languageStep();
      case 1:
        return _nameStep();
      case 2:
        return _avatarStep();
      case 3:
        return _genderStep();
      case 4:
        return _ageStep();
      case 5:
        return _groupStep();
      default:
        return _sourceStep();
    }
  }

  Widget _shell({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      key: ValueKey(_step),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 26),
        Expanded(child: child),
      ],
    );
  }

  /// Splash's language picker, folded in as the first step. Tapping an
  /// option commits it and the whole flow re-renders in the new language
  /// before advancing.
  Widget _languageStep() {
    final options = [('bn', 'বাংলা'), ('en', 'English')];

    return _shell(
      title: _t('Choose your language', 'আপনার ভাষা বেছে নিন'),
      subtitle: _t(
        'Select the language you want to play in.',
        'আপনি যে ভাষায় খেলতে চান সেটি নির্বাচন করুন।',
      ),
      child: Column(
        children: [
          Expanded(
            child: _options([
              for (final (code, label) in options)
                (
                  code,
                  label,
                  _pickedSteps.contains(_step) &&
                      LanguageSettings.instance.language.code == code,
                ),
            ]),
          ),
          const SizedBox(height: 14),
          Text(
            _t(
              'This language is used for the game words, hints and phrases. '
                  'You can change it later from Settings.',
              'গেমের শব্দ, হিন্ট ও বাক্যে এই ভাষাটিই ব্যবহার হবে। '
                  'পরে সেটিংস থেকে পরিবর্তন করা যাবে।',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameStep() {
    return _shell(
      title: _t("What's your name?", 'আপনার নাম কী?'),
      subtitle: _t(
        'This is the name other players will see.',
        'অন্য খেলোয়াড়রা এই নামটিই দেখবে।',
      ),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            maxLength: 18,
            onChanged: (_) {
              setState(() {});
              _nameDebounce?.cancel();
              _nameDebounce = Timer(const Duration(milliseconds: 400), () {
                if (mounted) _persistDraft();
              });
            },
            textInputAction: TextInputAction.done,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: _t('Your Name', 'আপনার নাম'),
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _highlight, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Splash-style picture picker: a swipeable carousel of the bundled
  /// character art (landing on one selects it) plus a "your own photo"
  /// section underneath.
  Widget _avatarStep() {
    final photo = AvatarPhoto.fileFor(_draft.avatarPhotoPath);

    return _shell(
      title: _t('Select an avatar', 'একটি অ্যাভাটার বেছে নিন'),
      subtitle: _t(
        'Swipe or use the arrows to pick one — or use your own photo.',
        'সোয়াইপ বা তীর চেপে বেছে নিন — অথবা নিজের ছবি ব্যবহার করুন।',
      ),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _avatarPageController,
              onPageChanged: (index) {
                // Landing on a different character replaces an own photo —
                // otherwise the photo would override and the swipe would
                // look dead. Swipes to the same page (resume re-align) skip.
                final oldPhoto = _draft.avatarPhotoPath;
                if (index != _draft.avatarIndex) {
                  setState(
                    () => _draft = _draft.copyWith(
                      avatarIndex: index,
                      clearAvatarPhoto: true,
                    ),
                  );
                  if (oldPhoto != null) AvatarPhoto.delete(oldPhoto);
                } else {
                  setState(() => _draft = _draft.copyWith(avatarIndex: index));
                }
                _persistDraft();
              },
              itemCount: kAvatarCount,
              itemBuilder: (context, index) {
                final selected = _draft.avatarIndex == index;
                return Center(
                  child: GestureDetector(
                    onTap: () => _avatarPageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut,
                    ),
                    child: AnimatedScale(
                      scale: selected ? 1 : 0.78,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut,
                      child: Container(
                        width: 172,
                        height: 172,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _highlight.withValues(
                            alpha: selected ? 0.16 : 0.05,
                          ),
                          border: Border.all(
                            color: selected
                                ? _highlight
                                : Colors.white.withValues(alpha: 0.18),
                            width: selected ? 3 : 1.5,
                          ),
                        ),
                        child: AvatarView(
                          index: index,
                          size: 156,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          // Swipe works too, but the arrows make browsing discoverable.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _carouselButton(
                icon: Icons.chevron_left_rounded,
                enabled: _draft.avatarIndex > 0,
                onTap: () => _stepAvatar(-1),
              ),
              const SizedBox(width: 14),
              Text(
                '${_draft.avatarIndex + 1} / $kAvatarCount',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(width: 14),
              _carouselButton(
                icon: Icons.chevron_right_rounded,
                enabled: _draft.avatarIndex < kAvatarCount - 1,
                onTap: () => _stepAvatar(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!kIsWeb) ...[
            if (photo != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AvatarView(
                    index: _draft.avatarIndex,
                    size: 36,
                    photoPath: _draft.avatarPhotoPath,
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _pickOwnPhoto,
                    icon: const Icon(Icons.photo_camera_rounded, size: 17),
                    label: Text(
                      _t('Change photo', 'ছবি বদলান'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _removeOwnPhoto,
                    child: Text(
                      _t('Remove', 'সরান'),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _pickOwnPhoto,
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: Text(
                    _t('Use your own photo', 'নিজের ছবি ব্যবহার করুন'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Future<void> _pickOwnPhoto() async {
    final path = await AvatarPhoto.pickFromGallery();
    if (path == null || !mounted) return;
    setState(() => _draft = _draft.copyWith(avatarPhotoPath: path));
    _persistDraft();
  }

  Future<void> _removeOwnPhoto() async {
    final path = _draft.avatarPhotoPath;
    if (!mounted) return;
    setState(() => _draft = _draft.copyWith(clearAvatarPhoto: true));
    _persistDraft();
    await AvatarPhoto.delete(path);
  }

  /// Round chevron flanking the counter: taps walk the carousel one
  /// character at a time. Uses the live scroll position, so hammering it
  /// mid-animation keeps stepping instead of stalling on a stale index.
  Widget _carouselButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.03),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 28,
            color: enabled ? Colors.white70 : Colors.white24,
          ),
        ),
      ),
    );
  }

  void _stepAvatar(int delta) {
    final controller = _avatarPageController;
    final current = controller.hasClients && controller.page != null
        ? controller.page!.round()
        : _draft.avatarIndex;

    var target = current + delta;
    if (target < 0) target = 0;
    if (target > kAvatarCount - 1) target = kAvatarCount - 1;
    if (target == current) return;

    controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Widget _genderStep() {
    final options = [
      (PlayerGender.male, _t('Male', 'পুরুষ')),
      (PlayerGender.female, _t('Female', 'নারী')),
    ];

    return _shell(
      title: _t("What's your gender?", 'আপনার লিঙ্গ কী?'),
      subtitle: _t(
        'This helps us personalize your experience.',
        'এটি আপনার অভিজ্ঞতা ব্যক্তিগত করতে সাহায্য করবে।',
      ),
      child: _options(
        options.map((entry) {
          return (
            entry.$1.id,
            entry.$2,
            _pickedSteps.contains(_step) && _draft.gender == entry.$1,
          );
        }).toList(),
      ),
    );
  }

  Widget _ageStep() {
    final options = [
      (AgeBand.under13, _t('Under 13', '১৩-এর কম')),
      (AgeBand.age13_17, '13–17'),
      (AgeBand.age18_20, '18–20'),
      (AgeBand.age21plus, _t('21+', '২১+')),
    ];

    return _shell(
      title: _t('How old are you?', 'আপনার বয়স কত?'),
      subtitle: _t(
        'This is to personalize your experience.',
        'এটি আপনার অভিজ্ঞতা ব্যক্তিগতকরণে সাহায্য করবে।',
      ),
      child: _options(
        options.map((entry) {
          return (
            entry.$1.id,
            entry.$2,
            _pickedSteps.contains(_step) && _draft.ageBand == entry.$1,
          );
        }).toList(),
      ),
    );
  }

  Widget _groupStep() {
    final options = [
      (PlayGroup.friends, _t('Friends', 'বন্ধু')),
      (PlayGroup.family, _t('Family', 'পরিবার')),
      (PlayGroup.partner, _t('Partner', 'সঙ্গী')),
      (PlayGroup.colleagues, _t('Colleagues', 'সহকর্মী')),
    ];

    return _shell(
      title: _t(
        'Who do you most like to play with?',
        'আপনি সাধারণত কাদের সাথে খেলতে পছন্দ করেন?',
      ),
      subtitle: _t(
        'For the best game experience, tailored to your group.',
        'আপনার দল অনুযায়ী সেরা গেম অভিজ্ঞতার জন্য।',
      ),
      child: _options(
        options.map((entry) {
          return (
            entry.$1.id,
            entry.$2,
            _pickedSteps.contains(_step) && _draft.group == entry.$1,
          );
        }).toList(),
      ),
    );
  }

  Widget _sourceStep() {
    final options = [
      (
        HearSource.store,
        _t('App Store / Play Store', 'অ্যাপ স্টোর / প্লে স্টোর'),
      ),
      (HearSource.friends, _t('Friends & Family', 'বন্ধু ও পরিবার')),
      (HearSource.socialMedia, _t('Social Media', 'সোশ্যাল মিডিয়া')),
      (HearSource.other, _t('Somewhere else', 'অন্য কোথাও')),
    ];

    return _shell(
      title: _t(
        'How did you hear about us?',
        'আপনি আমাদের সম্পর্কে কোথায় জানলেন?',
      ),
      subtitle: _t(
        'This helps us personalize your experience.',
        'এটি আপনার অভিজ্ঞতা ব্যক্তিগত করতে সাহায্য করবে।',
      ),
      child: _options(
        options.map((entry) {
          return (
            entry.$1.id,
            entry.$2,
            _pickedSteps.contains(_step) && _draft.source == entry.$1,
          );
        }).toList(),
      ),
    );
  }

  /// Generic radio-style option list used by most steps.
  Widget _options(List<(String, String, bool)> options) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: options.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final (value, label, selected) = options[index];
        return Material(
          color: selected
              ? _red.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _selectOption(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? _red : Colors.white.withValues(alpha: 0.10),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? _highlight : Colors.white38,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectOption(String value) {
    setState(() {
      switch (_step) {
        case 0:
          // Language lives outside the draft profile: setLanguage swaps the
          // in-memory language synchronously, so this rebuild (and every
          // step after it) comes back in the picked language.
          unawaited(
            LanguageSettings.instance.setLanguage(
              value == 'bn' ? AppLanguage.bangla : AppLanguage.english,
            ),
          );
        case 3:
          _draft = _draft.copyWith(gender: PlayerGender.fromId(value));
        case 4:
          _draft = _draft.copyWith(ageBand: AgeBand.fromId(value));
        case 5:
          _draft = _draft.copyWith(group: PlayGroup.fromId(value));
        case 6:
          _draft = _draft.copyWith(source: HearSource.fromId(value));
      }
      _pickedSteps.add(_step);
    });
    _persistDraft();

    // Feels snappier: committing a single-choice answer advances.
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted && _canContinue) _next();
    });
  }
}
