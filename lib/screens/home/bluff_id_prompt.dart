import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/language/app_language.dart';
import '../../core/language/language_settings.dart';
import '../../core/profile/bluff_id_signin.dart';
import '../../core/profile/profile_repository.dart';

const _sheet = Color(0xff14141C);
const _red = Color(0xffC62828);
const _highlight = Color(0xffFFD166);
const _green = Color(0xFF32D74B);

const String _dismissedKey = 'bluff.bluffid.prompt_dismissed';

bool get _isBangla => LanguageSettings.instance.language.code == 'bn';

String _t(String en, String bn) => _isBangla ? bn : en;

/// The "Login with Bluff ID" subscription window.
///
/// It is deliberately **not** part of the seven first-run steps: onboarding
/// lands on home, and about a second later this sheet slides up over it —
/// a one-time offer ("login so your progress won't get lost").
///
/// Every way out — the cross, back, an outside tap, dragging it away or
/// "Continue as guest" — remembers the dismissal, so it never nags again.
/// Players who want it later can still sign in from Profile.
class BluffIdPrompt {
  BluffIdPrompt._();

  static Future<bool> isDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dismissedKey) ?? false;
  }

  static Future<void> markDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  /// Called by HomeScreen a second after it first appears. Skips players
  /// who are already signed in or who dismissed the window before.
  static Future<void> maybeShow(BuildContext context) async {
    try {
      final profile = ProfileRepository.instance.profile;
      if (profile == null || profile.isSignedIn) return;
      if (await isDismissed()) return;
    } catch (_) {
      return;
    }

    if (!context.mounted) return;
    await show(context);
  }

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BluffIdWindow(),
    );
  }
}

class _BluffIdWindow extends StatefulWidget {
  const _BluffIdWindow();

  @override
  State<_BluffIdWindow> createState() => _BluffIdWindowState();
}

class _BluffIdWindowState extends State<_BluffIdWindow> {
  bool _busy = false;
  bool _done = false;
  String? _message;

  @override
  void initState() {
    super.initState();

    // Defensive: a signed-in profile (cloud restore) sees the success
    // variant straight away.
    _done = ProfileRepository.instance.profile?.isSignedIn ?? false;
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });

    final error = await signInWithBluffId();

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error == null) {
        _done = true;
      } else {
        _message = error;
      }
    });
  }

  void _dismiss() {
    BluffIdPrompt.markDismissed();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back, an outside tap and a drag all close the window — and all
      // count as "dismissed", so it won't come back next launch.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) BluffIdPrompt.markDismissed();
      },
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: _sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
              spreadRadius: 6,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              10,
              24,
              20 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cross at the top right.
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: _busy ? null : _dismiss,
                    icon: const Icon(Icons.close_rounded, size: 21),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      foregroundColor: Colors.white70,
                      fixedSize: const Size(38, 38),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Center(child: _badge()),
                const SizedBox(height: 16),
                Text(
                  _done
                      ? _t("You're all set!", 'সব ঠিক আছে!')
                      : _t('Login with Bluff ID', 'Bluff ID-তে লগইন করুন'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _done
                      ? _t(
                          'Your progress is backed up to your account.',
                          'আপনার অগ্রগতি অ্যাকাউন্টে ব্যাকআপ হয়েছে।',
                        )
                      : _t(
                          "So your progress won't get lost.",
                          'লগইন করলে আপনার অগ্রগতি হারাবে না।',
                        ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                if (!_done) ...[
                  _benefitsCard(),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
                _primaryButton(),
                if (!_done) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _busy ? null : _dismiss,
                      child: Text(
                        _t('Continue as guest', 'গেস্ট হিসেবে চালিয়ে যান'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  _t(
                    'You can sign in anytime later from Profile.',
                    'পরে যেকোনো সময় প্রোফাইল থেকে সাইন ইন করা যাবে।',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge() {
    final color = _done ? _green : _highlight;

    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color, width: 2.5),
      ),
      child: Icon(
        _done ? Icons.check_rounded : Icons.cloud_upload_rounded,
        size: 40,
        color: color,
      ),
    );
  }

  Widget _benefitsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          _benefit(
            Icons.phonelink_lock_rounded,
            _t(
              'Progress backed up — restores on any device',
              'অগ্রগতি ব্যাকআপ থাকে — যেকোনো ডিভাইসে ফেরানো যায়',
            ),
          ),
          const SizedBox(height: 12),
          _benefit(
            Icons.devices_rounded,
            _t(
              'Your profile follows you everywhere',
              'প্রোফাইল সব ডিভাইসে সাথে যাবে',
            ),
          ),
          const SizedBox(height: 12),
          _benefit(
            Icons.emoji_events_rounded,
            _t(
              'Online play, stats and rewards stay safe',
              'অনলাইন খেলা, স্ট্যাটস ও পুরস্কার নিরাপদ থাকবে',
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefit(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _highlight),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton() {
    if (_done) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _dismiss,
          child: Text(
            _t('Start playing', 'খেলা শুরু করুন'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _red,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _red.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _busy ? null : _signIn,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.g_mobiledata_rounded, size: 30),
        label: Text(
          _t('Sign in with Google', 'Google দিয়ে সাইন ইন'),
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
