import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models/challenge.dart';
import '../core/models/friendship.dart';
import '../core/models/time_control.dart';
import '../screens/game_screen.dart';
import '../services/chess_storage.dart';
import '../services/online_service.dart';
import '../services/session_service.dart';
import '../state/game_controller.dart';
import '../widgets/chess_theme.dart';

/// Local friends roster: add, remove and challenge other players.
///
/// The roster itself is fully local ([ChessStorage]), so it works offline.
/// Presence and challenge delivery run through [OnlineService] — with no
/// backend connected the screen says so instead of simulating online friends.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<ChessFriend> _friends = const [];
  String? _myProfileId;
  ChessChallenge? _incoming;
  ChessChallenge? _outgoing;
  bool _openingGame = false;
  StreamSubscription<ChessChallenge>? _challengeSub;
  StreamSubscription<ConnectionPhase>? _phaseSub;

  bool get _online => OnlineService.instance.isAvailable;

  @override
  void initState() {
    super.initState();
    _load();
    _initOnline();
    _phaseSub = OnlineService.instance.phaseChanges.listen((_) {
      if (!mounted) return;
      setState(() {}); // the banner follows the connection state
      if (OnlineService.instance.isAvailable) _initOnline();
    });
  }

  @override
  void dispose() {
    _challengeSub?.cancel();
    _phaseSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final friends = await ChessStorage.instance.loadFriends();
    if (!mounted) return;
    setState(() => _friends = friends);
    await _refreshPresence();
  }

  /// Applies the local identity, refreshes presence and starts listening
  /// for challenge pushes. Safe to call again after a (re)connect.
  Future<void> _initOnline() async {
    try {
      final profile = await SessionService.instance.current;
      if (!mounted) return;
      _myProfileId = profile.id;
      await _refreshPresence();
      await _watchChallenges();
    } catch (_) {
      // No session — the screen stays local-only.
    }
  }

  /// Real presence from the server; unknown stays unknown on any failure.
  Future<void> _refreshPresence() async {
    final service = OnlineService.instance;
    if (!service.isAvailable || _friends.isEmpty) return;
    try {
      final states = await service.presence(_friends.map((f) => f.id).toSet());
      if (!mounted) return;
      setState(() {
        _friends = [
          for (final f in _friends)
            f.copyWith(
              presence: states[f.id] ?? PresenceStatus.unknown,
              presenceNote: f.presenceNote,
            ),
        ];
      });
    } catch (_) {
      // Presence is never invented offline.
    }
  }

  Future<void> _watchChallenges() async {
    final service = OnlineService.instance;
    if (!service.isAvailable) return;
    try {
      final updates = await service.challengeUpdates();
      await _challengeSub?.cancel();
      _challengeSub = updates.listen(_onChallengeUpdate);
    } catch (_) {
      // Challenge stream unavailable — local-only behavior remains.
    }
  }

  Future<void> _persist(List<ChessFriend> friends) async {
    // Newest first so the friend just added is visible immediately.
    final sorted = [...friends]
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    await ChessStorage.instance.saveFriends(sorted);
    if (!mounted) return;
    setState(() => _friends = sorted);
  }

  Future<void> _addFriend() async {
    final friend = await showDialog<ChessFriend>(
      context: context,
      builder: (_) => _AddFriendDialog(existing: _friends),
    );
    if (friend == null || !mounted) return;
    await _persist([..._friends, friend]);
  }

  void _remove(ChessFriend friend) {
    _persist(_friends.where((f) => f.id != friend.id).toList());
  }

  /// Sends a real challenge through the backend when one is connected;
  /// otherwise says so honestly instead of staging a fake invite.
  Future<void> _challenge(ChessFriend friend) async {
    final service = OnlineService.instance;
    if (!service.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Challenges go through the BLUFF server — press CONNECT in '
            'the multiplayer lobby first.',
          ),
        ),
      );
      return;
    }
    final pick = await showDialog<(TimeControl, SidePreference)>(
      context: context,
      builder: (_) => _SendChallengeDialog(friend: friend),
    );
    if (pick == null || !mounted) return;
    final (timeControl, preference) = pick;
    final profile = await SessionService.instance.current;
    if (!mounted) return;
    final challenge = ChessChallenge(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      fromId: profile.id,
      fromName: profile.displayName,
      toId: friend.id,
      toName: friend.displayName,
      timeControlLabel: timeControl.displayLabel,
      timeCategory: timeControl.category,
      rated: timeControl.hasClock,
      sidePreference: preference,
      createdAt: DateTime.now(),
    );
    try {
      await service.sendChallenge(challenge);
      if (!mounted) return;
      setState(() => _outgoing = challenge);
      _snack('Challenge sent to ${friend.displayName}.');
    } catch (error) {
      if (!mounted) return;
      _snack('Could not send challenge: $error');
    }
  }

  void _onChallengeUpdate(ChessChallenge challenge) {
    if (!mounted) return;
    final iAmTarget = challenge.toId == _myProfileId;
    final iAmChallenger = challenge.fromId == _myProfileId;
    if (!iAmTarget && !iAmChallenger) return;
    switch (challenge.status) {
      case ChallengeStatus.waiting:
        if (iAmTarget) setState(() => _incoming = challenge);
      case ChallengeStatus.declined:
        if (iAmChallenger) {
          setState(() => _outgoing = null);
          _snack('${challenge.toName} declined the challenge.');
        }
      case ChallengeStatus.accepted:
        unawaited(_openChallengedGame(challenge));
      case ChallengeStatus.cancelled:
      case ChallengeStatus.expired:
        if (iAmTarget) setState(() => _incoming = null);
        if (iAmChallenger) setState(() => _outgoing = null);
    }
  }

  Future<void> _acceptIncoming() async {
    final challenge = _incoming;
    final service = OnlineService.instance;
    if (challenge == null || !service.isAvailable) return;
    try {
      await service.respondToChallenge(challenge.id, accept: true);
      // The board opens when the accepted update arrives from the server.
    } catch (error) {
      if (mounted) _snack('Could not accept: $error');
    }
  }

  Future<void> _declineIncoming() async {
    final challenge = _incoming;
    if (challenge == null) return;
    setState(() => _incoming = null);
    final service = OnlineService.instance;
    if (!service.isAvailable) return;
    try {
      await service.respondToChallenge(challenge.id, accept: false);
    } catch (_) {
      // Local banner already cleared; the server resolves the rest.
    }
  }

  /// Opens the server-created challenge game. Both clients compute the same
  /// deterministic side split the server used, so no extra round-trip is
  /// needed for colors.
  Future<void> _openChallengedGame(ChessChallenge challenge) async {
    if (_openingGame || !mounted) return;
    _openingGame = true;
    try {
      final service = OnlineService.instance;
      if (!service.isAvailable) return;
      final live = await service.openGame('ch_${challenge.id}');
      if (!mounted) return;

      final challengerIsWhite = switch (challenge.sidePreference) {
        SidePreference.white => true,
        SidePreference.black => false,
        SidePreference.random => (int.tryParse(challenge.id) ?? 0).isOdd,
      };
      final iAmChallenger = challenge.fromId == _myProfileId;
      final localIsWhite =
          iAmChallenger ? challengerIsWhite : !challengerIsWhite;
      final whiteName =
          challengerIsWhite ? challenge.fromName : challenge.toName;
      final blackName =
          challengerIsWhite ? challenge.toName : challenge.fromName;

      setState(() {
        _incoming = null;
        _outgoing = null;
      });
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => GameScreen(
            mode: ChessGameMode.online,
            timeControl: challenge.timeControl ?? TimeControl.presets.first,
            rated: challenge.rated,
            liveGame: live,
            localIsWhite: localIsWhite,
            opponentId: iAmChallenger ? challenge.toId : challenge.fromId,
            whiteName: localIsWhite ? null : whiteName,
            blackName: localIsWhite ? blackName : null,
          ),
        ),
      );
    } catch (error) {
      if (mounted) _snack('Could not open the game: $error');
    } finally {
      _openingGame = false;
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChessPalette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: ChessPalette.text),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 4),
                const Text('Friends', style: ChessText.display),
              ],
            ),
            const SizedBox(height: 8),
            ChessCard(
              color: ChessPalette.surfaceAlt,
              border: Border.all(
                color: ChessPalette.warning.withValues(alpha: 0.4),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: ChessPalette.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _online
                          ? 'Friends are stored on this device. Presence and '
                              'challenge invites now run through the '
                              'connected BLUFF server.'
                          : 'Friends are stored on this device. Live presence and '
                              'challenge invites run through the BLUFF server — not '
                              'connected in this build, so neither is simulated.',
                      style: ChessText.caption.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Add friend',
              icon: Icons.person_add_alt_1_rounded,
              expanded: true,
              onPressed: _addFriend,
            ),
            const SizedBox(height: 18),
            if (_incoming != null) _incomingCard(_incoming!),
            if (_outgoing != null) _outgoingCard(_outgoing!),
            SectionTitle(title: 'Friends'),
            if (_friends.isEmpty)
              ChessCard(
                child: Text(
                  'No friends yet. Add someone by username — the roster '
                  'lives on this device and works offline.',
                  style: ChessText.caption.copyWith(height: 1.5),
                ),
              )
            else
              for (final friend in _friends) _tile(friend),
          ],
        ),
      ),
    );
  }

  Widget _tile(ChessFriend friend) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ChessCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _avatar(friend),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ChessText.body,
                  ),
                  Text(
                    '@${friend.username}',
                    style: ChessText.caption.copyWith(
                      color: ChessPalette.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            _presenceChip(friend),
            const SizedBox(width: 2),
            IconButton(
              tooltip: 'Challenge',
              icon: const Icon(Icons.play_circle_outline_rounded,
                  color: ChessPalette.textDim),
              onPressed: () => _challenge(friend),
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline_rounded,
                  color: ChessPalette.textFaint),
              onPressed: () => _remove(friend),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(ChessFriend friend) {
    final color = Color(friend.avatarColor);
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        friend.avatarEmoji ?? friend.initials,
        style: ChessText.body.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  /// Never invents a status: unknown presence (no backend) is shown as such.
  Widget _presenceChip(ChessFriend friend) {
    final live = friend.presence.isLive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: ChessPalette.chipRadius,
        border: Border.all(color: ChessPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: live ? ChessPalette.success : ChessPalette.textFaint,
            ),
          ),
          const SizedBox(width: 5),
          Text(friend.presence.label, style: ChessText.caption),
        ],
      ),
    );
  }

  Widget _incomingCard(ChessChallenge challenge) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ChessCard(
        color: ChessPalette.surface,
        border: Border.all(color: ChessPalette.accent.withValues(alpha: 0.5)),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mail_outline_rounded,
                    color: ChessPalette.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Challenge from ${challenge.fromName}',
                    style: ChessText.body,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${challenge.timeControlLabel}${challenge.rated ? ' · rated' : ''}',
              style: ChessText.caption,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'Decline',
                    expanded: true,
                    danger: true,
                    onPressed: _declineIncoming,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: 'Accept',
                    expanded: true,
                    onPressed: _acceptIncoming,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _outgoingCard(ChessChallenge challenge) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ChessCard(
        color: ChessPalette.surfaceAlt,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ChessPalette.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Challenge to ${challenge.toName} '
                '(${challenge.timeControlLabel}) — waiting for an answer…',
                style: ChessText.caption.copyWith(height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add-friend dialog. Owns its text controllers so they outlive the pop
/// animation (disposed with the route, not before it).
class _AddFriendDialog extends StatefulWidget {
  const _AddFriendDialog({required this.existing});

  final List<ChessFriend> existing;

  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final _handle = TextEditingController();
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _handle.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final handle = _handle.text.trim().toLowerCase();
    if (handle.isEmpty) {
      setState(() => _error = 'Enter a username.');
      return;
    }
    if (widget.existing.any((f) => f.username.toLowerCase() == handle)) {
      setState(() => _error = 'That friend is already on your roster.');
      return;
    }
    final name = _name.text.trim();
    Navigator.of(context).pop(
      ChessFriend(
        id: 'friend_$handle',
        username: handle,
        displayName: name.isEmpty ? handle : name,
        addedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ChessPalette.surface,
      title: const Text('Add a friend', style: ChessText.display),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _handle,
            style: ChessText.body,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration('Username'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _name,
            style: ChessText.body,
            decoration: _inputDecoration('Display name (optional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: ChessText.caption
                  .copyWith(color: ChessPalette.danger, height: 1.4),
            ),
          ],
        ],
      ),
      actions: [
        GhostButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        PrimaryButton(label: 'Add', onPressed: _submit),
      ],
    );
  }
}

/// Time control + side picker for an outgoing challenge.
class _SendChallengeDialog extends StatefulWidget {
  const _SendChallengeDialog({required this.friend});

  final ChessFriend friend;

  @override
  State<_SendChallengeDialog> createState() => _SendChallengeDialogState();
}

class _SendChallengeDialogState extends State<_SendChallengeDialog> {
  static final _controls = <TimeControl>[
    for (final label in const ['3 + 2', '5 + 0', '10 + 0', '15 + 10'])
      TimeControl.byLabel(label) ?? TimeControl.presets.first,
  ];

  TimeControl _tc = _controls[0];
  SidePreference _side = SidePreference.random;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ChessPalette.surface,
      title: Text(
        'Challenge ${widget.friend.displayName}',
        style: ChessText.title,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Time control', style: ChessText.caption),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final control in _controls)
                InfoChip(
                  label: control.displayLabel,
                  color: control == _tc
                      ? ChessPalette.accentSoft
                      : ChessPalette.surfaceHigh,
                  textColor: control == _tc
                      ? ChessPalette.text
                      : ChessPalette.textDim,
                  onTap: () => setState(() => _tc = control),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Your side', style: ChessText.caption),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final side in SidePreference.values)
                InfoChip(
                  label: side.label,
                  color: side == _side
                      ? ChessPalette.accentSoft
                      : ChessPalette.surfaceHigh,
                  textColor: side == _side
                      ? ChessPalette.text
                      : ChessPalette.textDim,
                  onTap: () => setState(() => _side = side),
                ),
            ],
          ),
        ],
      ),
      actions: [
        GhostButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        PrimaryButton(
          label: 'Send',
          icon: Icons.send_rounded,
          onPressed: () => Navigator.of(context).pop((_tc, _side)),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: ChessPalette.textFaint),
    filled: true,
    fillColor: ChessPalette.surfaceAlt,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ChessPalette.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ChessPalette.accent, width: 1.6),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}
