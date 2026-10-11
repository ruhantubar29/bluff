import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/language/app_language.dart';
import '../../../core/language/language_settings.dart';
import '../../../core/profile/avatars.dart';
import '../../../core/profile/avatar_photo.dart';
import '../../../core/profile/profile.dart';
import '../../../core/profile/profile_repository.dart';

const _dark = Color(0xff09090E);
const _highlight = Color(0xffFFD166);

/// Splash-style "edit profile" screen.
///
/// Splash lets players change name and picture any time from the profile
/// screen; onboarding is not a one-shot form. This mirrors that — name plus
/// a vertical, swipeable avatar carousel for now (demographics can come
/// back later).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late Profile _draft;
  late final TextEditingController _nameController;
  late final PageController _avatarPageController;

  int _avatarPage = 0;
  bool _saving = false;

  bool get _isBangla => LanguageSettings.instance.language.code == 'bn';

  String _t(String en, String bn) => _isBangla ? bn : en;

  @override
  void initState() {
    super.initState();

    _draft = ProfileRepository.instance.profile ?? const Profile();

    _nameController = TextEditingController(text: _draft.name);

    // Legacy profiles can carry an index from the old 35-avatar picker.
    _avatarPage = _draft.avatarIndex % kAvatarCount;
    _avatarPageController = PageController(initialPage: _avatarPage);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarPageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Name must be at least 2 characters.',
              'নাম কমপক্ষে ২ অক্ষরের হতে হবে।',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    setState(() => _saving = true);

    final updated = _draft.copyWith(name: name);

    await ProfileRepository.instance.save(updated);

    // Best-effort cloud sync — same path onboarding uses.
    await ProfileRepository.instance.pushToCloud();

    if (!mounted) return;
    Navigator.pop(context, updated);
  }

  Future<void> _pickOwnPhoto() async {
    final path = await AvatarPhoto.pickFromGallery();
    if (path == null || !mounted) return;
    setState(() => _draft = _draft.copyWith(avatarPhotoPath: path));
  }

  Future<void> _removeOwnPhoto() async {
    final path = _draft.avatarPhotoPath;
    if (!mounted) return;
    setState(() => _draft = _draft.copyWith(clearAvatarPhoto: true));
    await AvatarPhoto.delete(path);
  }

  void _goToAvatar(int page) {
    _avatarPageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  /// The picked character follows the carousel: swiping to a page commits
  /// it, same rule as the onboarding carousel and the old grid's tap.
  void _commitAvatarPage(int page) {
    final oldPhoto = _draft.avatarPhotoPath;

    setState(() {
      _avatarPage = page;
      _draft = _draft.copyWith(avatarIndex: page, clearAvatarPhoto: true);
    });

    if (oldPhoto != null) AvatarPhoto.delete(oldPhoto);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _dark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _dark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _t('Edit Profile', 'প্রোফাইল সম্পাদনা'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _sectionTitle(_t('Name', 'নাম')),
              TextField(
                controller: _nameController,
                maxLength: 18,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: _t('Your Name', 'আপনার নাম'),
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _highlight, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 22),
              _sectionTitle(_t('Avatar', 'অ্যাভাটার')),
              _avatarCarousel(),

              if (!kIsWeb) ...[
                const SizedBox(height: 12),
                if (_draft.avatarPhotoPath != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
              ],

              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _highlight,
                    foregroundColor: _dark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving
                        ? _t('Saving…', 'সেভ হচ্ছে…')
                        : _t('Save changes', 'পরিবর্তন সেভ করুন'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _t(
                  'Saved on this device instantly, and synced to your account if you are signed in.',
                  'এই ডিভাইসে সাথে সাথে সেভ হবে, সাইন ইন থাকলে অ্যাকাউন্টেও যাবে।',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vertical, swipeable character carousel: swipe up/down (or use the
  /// chevrons) to browse; the visible page becomes the picked avatar.
  Widget _avatarCarousel() {
    return Column(
      children: [
        Center(
          child: _carouselButton(
            Icons.keyboard_arrow_up_rounded,
            _avatarPage > 0 ? () => _goToAvatar(_avatarPage - 1) : null,
          ),
        ),
        SizedBox(
          height: 174,
          child: PageView.builder(
            controller: _avatarPageController,
            scrollDirection: Axis.vertical,
            itemCount: kAvatarCount,
            onPageChanged: _commitAvatarPage,
            itemBuilder: (context, index) {
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _highlight, width: 2.5),
                  ),
                  child: CircleAvatar(
                    radius: 66,
                    backgroundColor: _highlight.withValues(alpha: 0.14),
                    child: AvatarView(
                      index: index,
                      size: 132,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Center(
          child: _carouselButton(
            Icons.keyboard_arrow_down_rounded,
            _avatarPage < kAvatarCount - 1
                ? () => _goToAvatar(_avatarPage + 1)
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_avatarPage + 1} / $kAvatarCount',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _carouselButton(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;

    return Material(
      color: Colors.white.withValues(alpha: enabled ? 0.06 : 0.03),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 26,
            color: enabled ? Colors.white70 : Colors.white24,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
