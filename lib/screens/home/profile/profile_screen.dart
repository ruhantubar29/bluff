import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/language/app_language.dart';
import '../../../core/language/language_settings.dart';
import '../../../core/features.dart';
import '../../../core/profile/avatars.dart';
import '../../../core/profile/bluff_id_signin.dart';
import '../../../core/profile/profile.dart';
import '../../../core/profile/profile_repository.dart';
import '../../../core/theme/bluff_theme.dart';
import '../../../games/chess/screens/chess_stats_screen.dart';
import 'edit_profile_screen.dart';

bool get _isBangla => LanguageSettings.instance.language.code == 'bn';

String _t(String en, String bn) => _isBangla ? bn : en;

const _red = BluffTheme.red;
const _highlight = BluffTheme.gold;
const _green = Color(0xFF32D74B);

/// Profile / "Splash ID" equivalent: shows the local account, explains what
/// signing in unlocks, and upgrades the anonymous session in place.
///
/// Runs on the dark Bluff account theme (BluffTheme.dark) so it never
/// flashes a pale Material screen between home and the games.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;
  String? _message;

  Profile get _profile => ProfileRepository.instance.profile ?? const Profile();

  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });

    // All Google/Firebase mechanics (single initialize(), timeouts, honest
    // bilingual error mapping) live in the shared Bluff ID service so this
    // screen and the home popup behave identically.
    final error = await signInWithBluffId();

    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = error;
    });
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);

    await ProfileRepository.instance.signOut();

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google session cleanup is best-effort.
    }

    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      // The dialog rides the app-level (light) navigator, so bring the dark
      // account theme along explicitly.
      builder: (context) => Theme(
        data: BluffTheme.dark,
        child: AlertDialog(
          title: Text(_t('Delete account?', 'অ্যাকাউন্ট মুছে ফেলবেন?')),
          content: Text(
            _t(
              'Your account and all data will be permanently deleted. This cannot be undone.',
              'আপনার অ্যাকাউন্ট ও সব তথ্য স্থায়ীভাবে মুছে যাবে। এটি ফেরানো যাবে না।',
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              onPressed: () => Navigator.pop(context, false),
              child: Text(_t('Cancel', 'বাতিল')),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: Text(_t('Delete', 'মুছুন')),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await ProfileRepository.instance.deleteAccount();

    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = _t('Local data cleared.', 'লোকাল তথ্য মুছে ফেলা হয়েছে।');
    });
  }

  /// Tinted rounded-square icon, the account area's tile mark.
  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final signedIn = profile.isSignedIn;
    final ringColor = signedIn ? _green : _highlight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: BluffTheme.ink,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Theme(
        data: BluffTheme.dark,
        child: Scaffold(
          appBar: AppBar(title: Text(_t('Profile', 'প্রোফাইল'))),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Centred identity card: picture on top, name below it, both
              // locked to the horizontal middle (a full-width centred Text
              // auto-centres whatever the user types). Opens Edit Profile.
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _openEditProfile,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: ringColor, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor:
                                  ringColor.withValues(alpha: 0.16),
                              child: AvatarView(
                                index: profile.avatarIndex,
                                size: 54,
                                photoPath: profile.avatarPhotoPath,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            profile.name.isEmpty
                                ? _t('Player', 'খেলোয়াড়')
                                : profile.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            signedIn
                                ? _t(
                                    'Backed up to your account',
                                    'অ্যাকাউন্টে ব্যাকআপ হয়েছে',
                                  )
                                : _t(
                                    'Saved on this device',
                                    'এই ডিভাইসে সংরক্ষিত',
                                  ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: signedIn
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _iconBadge(Icons.edit_rounded, _highlight),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _iconBadge(
                            signedIn
                                ? Icons.cloud_done_rounded
                                : Icons.cloud_upload_rounded,
                            signedIn ? _green : _highlight,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              signedIn
                                  ? _t('Your Bluff ID', 'আপনার ব্লাফ আইডি')
                                  : _t('Get started', 'শুরু করুন'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        signedIn
                            ? _t(
                                'Your progress, stats and rewards are saved to your account and follow you to any device.',
                                'আপনার অগ্রগতি, স্ট্যাটস ও পুরস্কার অ্যাকাউন্টে সংরক্ষিত থাকে এবং যেকোনো ডিভাইসে সাথে যাবে।',
                              )
                            : _t(
                                'Your personal key to saving progress, playing online and tracking your stats. You can keep playing without it — progress just stays on this device.',
                                'অগ্রগতি সংরক্ষণ, অনলাইনে খেলা ও স্ট্যাটস ট্র্যাক করার জন্য আপনার ব্যক্তিগত চাবি। ছাড়াও খেলতে পারবেন — তখন অগ্রগতি এই ডিভাইসেই থাকবে।',
                              ),
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!signedIn)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _red,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _red.withValues(
                                alpha: 0.35,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _busy ? null : _signInWithGoogle,
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.g_mobiledata_rounded,
                                    size: 28,
                                  ),
                            label: Text(
                              _t(
                                'Continue with Google',
                                'Google দিয়ে চালিয়ে যান',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _busy ? null : _signOut,
                            child: Text(_t('Log out', 'লগ আউট')),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],

              // Chess progress (history, Elo, form, puzzles). Shown in every
              // build, but locked exactly like chess itself under COMING SOON
              // until kChessEnabled flips on — visible, tappable-dead, and
              // never reaching the stats screen.
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  enabled: kChessEnabled,
                  leading: _iconBadge(
                    kChessEnabled
                        ? Icons.bar_chart_rounded
                        : Icons.lock_rounded,
                    _highlight,
                  ),
                  title: Text(_t('Chess Stats', 'দাবা স্ট্যাটস')),
                  subtitle: Text(
                    kChessEnabled
                        ? _t(
                            'History, Elo, form and puzzle progress',
                            'ইতিহাস, ইলো, ফর্ম ও ধাঁধার অগ্রগতি',
                          )
                        : _t('Coming soon', 'শীঘ্রই আসছে'),
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  onTap: kChessEnabled
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChessStatsScreen(),
                            ),
                          )
                      : null,
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: ListTile(
                  leading: _iconBadge(
                    Icons.delete_outline_rounded,
                    Colors.redAccent,
                  ),
                  title: Text(_t('Delete account', 'অ্যাকাউন্ট মুছুন')),
                  subtitle: Text(
                    _t(
                      'Removes local data and the cloud copy',
                      'লোকাল ও ক্লাউড তথ্য মুছে ফেলবে',
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  onTap: _busy ? null : _deleteAccount,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _t(
                  'Sign in is optional. Games always work without an account.',
                  'সাইন ইন ঐচ্ছিক। অ্যাকাউন্ট ছাড়াও সব গেম চলবে।',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
