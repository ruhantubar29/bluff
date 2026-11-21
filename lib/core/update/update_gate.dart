import 'dart:async';

import 'package:flutter/material.dart';

import '../../screens/update/update_dialog.dart';
import 'force_update.dart';

/// Global navigator handle for the app.
///
/// [UpdateGate] sits above the Navigator in `MaterialApp.builder` so it
/// survives every screen change, which means it has no route context of its
/// own to raise a dialog from. This key supplies one.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Watches for a newer release for as long as the app stays open.
///
/// Started once from `MaterialApp.builder`. It asks once at launch and keeps
/// re-asking while the server cannot be reached, so a player who opened
/// offline is prompted the moment they reconnect rather than only on their
/// next cold start. LATER lasts until the app is closed — nothing about the
/// dismissal is stored, so every fresh launch asks again until they update.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child, this.fetch});

  final Widget child;

  /// Test seam: the version feed to read. Null means the real one, so the
  /// gate never opens a socket of its own in a widget test.
  final Future<String?> Function()? fetch;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  /// Re-asks until the server answers, so coming back online is enough.
  Timer? _retry;

  /// True while the dialog is on screen, so two checks cannot stack.
  bool _prompting = false;

  /// True once the player has put it off, for this session only.
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    // One frame in, so the Navigator definitely exists to host the dialog.
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  Future<void> _begin() async {
    // A previous session already proved us stale: prompt straight away rather
    // than wait on a network that may never answer.
    if (stillOutdated(await knownStaleVersion())) _prompt();

    await _refresh();
  }

  Future<void> _refresh() async {
    final outdated = await checkForUpdate(fetch: widget.fetch);
    if (!mounted) return;

    if (outdated == null) {
      // No answer yet. Never read as "up to date" — that would drop a wall
      // we already know is justified. Ask again shortly instead.
      _retry ??= Timer.periodic(kUpdateRetryInterval, (_) => _refresh());
      return;
    }

    _retry?.cancel();
    _retry = null;
    if (outdated) _prompt();
  }

  void _prompt() {
    if (_prompting || _dismissed || !mounted) return;

    final navigator = appNavigatorKey.currentState;
    // Not reachable past the first frame; a later launch tries again anyway.
    if (navigator == null) return;

    _prompting = true;
    showDialog<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (dialogContext) => UpdateDialog(
        onDismiss: () {
          // Not stored anywhere: the next launch asks again.
          _dismissed = true;
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        },
      ),
    ).whenComplete(() => _prompting = false);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
