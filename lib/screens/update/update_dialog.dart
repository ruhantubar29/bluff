import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/update/force_update.dart';
import '../../widgets/bluff_button.dart';

const _dark = Color(0xff09090E);
const _accent = Color(0xffFFD166);

/// Blocking prompt shown when this install is older than the latest release.
///
/// It cannot be put off by accident: the barrier ignores taps and PopScope
/// swallows Android's back button, so the only two ways out are the update
/// itself or an explicit LATER. Neither is remembered — the next launch asks
/// again, because nothing about the dismissal is stored.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key, required this.onDismiss});

  /// Closes the prompt for the rest of this session. Used by both buttons:
  /// LATER because the player chose to keep playing, UPDATE NOW because they
  /// are leaving for the browser.
  final VoidCallback onDismiss;

  Future<void> _openDownload(BuildContext context) async {
    var opened = false;
    try {
      // One tap, straight into the browser; GitHub starts the APK download.
      opened = await launchUrl(
        Uri.parse(kDownloadUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the download page.'),
          backgroundColor: Color(0xffEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Android's back button must not slip past the two buttons.
      canPop: false,
      child: Dialog(
        backgroundColor: _dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _accent.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.system_update_alt_rounded,
                  size: 40,
                  color: _accent,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'A new update is available',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'BLUFF has been updated.\nUpdate to keep playing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.66),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  'You have v$kAppVersion',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              BluffButton(
                text: 'UPDATE NOW',
                fontSize: 16,
                onPressed: () async {
                  await _openDownload(context);
                  if (context.mounted) onDismiss();
                },
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: onDismiss,
                child: Text(
                  'LATER',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
