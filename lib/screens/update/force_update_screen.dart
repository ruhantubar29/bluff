import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/update/force_update.dart';
import '../../widgets/bluff_button.dart';

const _dark = Color(0xff09090E);
const _accent = Color(0xffFFD166);

/// Full-screen wall shown when this install is older than the latest release.
///
/// There is deliberately no close button, no "later" and no back gesture:
/// PopScope refuses to pop, so the only way forward is the update itself.
/// Leaving the app and reopening lands here again.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  Future<void> _openDownload(BuildContext context) async {
    // One tap, straight into the browser; GitHub starts the APK download.
    final opened = await launchUrl(
      Uri.parse(kDownloadUrl),
      mode: LaunchMode.externalApplication,
    );
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
      // Android's back button must not escape the wall.
      canPop: false,
      child: Scaffold(
        backgroundColor: _dark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 108,
                  height: 108,
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
                    size: 54,
                    color: _accent,
                  ),
                ),
                const SizedBox(height: 36),
                const Text(
                  'A new update is available',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'BLUFF has been updated and this version can no longer '
                  'be used.\n\nUpdate to keep playing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const Spacer(),
                BluffButton(
                  text: 'UPDATE NOW',
                  onPressed: () => _openDownload(context),
                ),
                const SizedBox(height: 14),
                Text(
                  'You will be taken to the download page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
