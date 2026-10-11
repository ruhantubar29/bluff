import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/session_service.dart';
import '../widgets/chess_theme.dart';

/// Which local auth flow the screen is showing.
enum AuthMode { signIn, signUp, reset }

/// Local account flows: sign in, create account, and recovery-code reset.
///
/// Everything runs on-device through [SessionService] — usernames, salted
/// PBKDF2 password hashes and one-time recovery codes never leave the phone.
/// There is no server round-trip and nothing here pretends to be remote.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialMode = AuthMode.signIn});

  final AuthMode initialMode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late AuthMode _mode = widget.initialMode;

  final _identifier = TextEditingController(); // sign-in handle
  final _username = TextEditingController(); // sign-up / reset handle
  final _displayName = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController(); // recovery code
  final _newPassword = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _username.dispose();
    _displayName.dispose();
    _password.dispose();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final session = SessionService.instance;
    final AuthResult result;
    switch (_mode) {
      case AuthMode.signIn:
        result = await session.signIn(
          identifier: _identifier.text,
          password: _password.text,
        );
      case AuthMode.signUp:
        result = await session.signUp(
          username: _username.text,
          password: _password.text,
          displayName: _displayName.text,
        );
      case AuthMode.reset:
        result = await session.resetPassword(
          username: _username.text,
          recoveryCode: _code.text,
          newPassword: _newPassword.text,
        );
    }

    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _error = result.error;
      });
      return;
    }

    if (result.recoveryCode != null) {
      await _showRecoveryCode(result.recoveryCode!);
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Shown exactly once, right after sign-up: the recovery code is the only
  /// way back into an account whose password is forgotten.
  Future<void> _showRecoveryCode(String code) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ChessPalette.surface,
        title: const Text('Save your recovery code', style: ChessText.display),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This one-time code resets your password if you ever forget '
              'it. It is shown now and never again.',
              style: ChessText.caption.copyWith(height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ChessPalette.surfaceHigh,
                borderRadius: ChessPalette.chipRadius,
                border: Border.all(color: ChessPalette.borderStrong),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      code,
                      textAlign: TextAlign.center,
                      style: ChessText.mono.copyWith(
                        fontSize: 16,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded,
                        color: ChessPalette.textDim, size: 18),
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: code),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Store it somewhere safe — without it, this password cannot '
              'be recovered.',
              style: ChessText.caption.copyWith(
                color: ChessPalette.warning,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          PrimaryButton(
            label: 'I saved it',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _switchMode(AuthMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _error = null;
    });
  }

  InputDecoration _decoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: ChessPalette.textFaint),
      prefixIcon:
          icon == null ? null : Icon(icon, color: ChessPalette.textFaint, size: 20),
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

  Widget _field(
    TextEditingController controller, {
    required String label,
    IconData? icon,
    bool obscure = false,
    TextInputAction? action,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        enableSuggestions: !obscure,
        autocorrect: !obscure,
        textCapitalization: capitalization,
        textInputAction: action,
        onSubmitted: (_) => _submit(),
        style: ChessText.body,
        decoration: _decoration(label, icon: icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChessPalette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: ChessPalette.text),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  const Text('Account', style: ChessText.display),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Local accounts keep everything on this device — no server, '
                'no upload, no tracking.',
                style: ChessText.caption.copyWith(height: 1.5),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      label: 'Sign in',
                      expanded: true,
                      selected: _mode == AuthMode.signIn,
                      onPressed: () => _switchMode(AuthMode.signIn),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GhostButton(
                      label: 'Create',
                      expanded: true,
                      selected: _mode == AuthMode.signUp,
                      onPressed: () => _switchMode(AuthMode.signUp),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GhostButton(
                      label: 'Reset',
                      expanded: true,
                      selected: _mode == AuthMode.reset,
                      onPressed: () => _switchMode(AuthMode.reset),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ..._fields(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: ChessText.caption
                        .copyWith(color: ChessPalette.danger, height: 1.4),
                  ),
                ),
              PrimaryButton(
                label: switch (_mode) {
                  AuthMode.signIn => 'Sign in',
                  AuthMode.signUp => 'Create account',
                  AuthMode.reset => 'Reset password',
                },
                expanded: true,
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(height: 12),
              Text(
                _mode == AuthMode.reset
                    ? 'Enter your username, the recovery code from sign-up, '
                        'and a new password.'
                    : 'Passwords are stored only as salted PBKDF2 hashes '
                        '(120,000 iterations) on this device.',
                textAlign: TextAlign.center,
                style: ChessText.caption.copyWith(height: 1.55),
              ),
              if (_mode == AuthMode.signIn) ...[
                const SizedBox(height: 16),
                GhostButton(
                  label: 'Continue as guest',
                  icon: Icons.person_outline_rounded,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _fields() {
    switch (_mode) {
      case AuthMode.signIn:
        return [
          _field(
            _identifier,
            label: 'Username',
            icon: Icons.person_outline_rounded,
            action: TextInputAction.next,
          ),
          _field(
            _password,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: true,
          ),
        ];
      case AuthMode.signUp:
        return [
          _field(
            _username,
            label: 'Username (lowercase, numbers, _)',
            icon: Icons.person_outline_rounded,
            action: TextInputAction.next,
          ),
          _field(
            _displayName,
            label: 'Display name (optional)',
            icon: Icons.badge_outlined,
            action: TextInputAction.next,
          ),
          _field(
            _password,
            label: 'Password (8+ characters)',
            icon: Icons.lock_outline_rounded,
            obscure: true,
          ),
        ];
      case AuthMode.reset:
        return [
          _field(
            _username,
            label: 'Username',
            icon: Icons.person_outline_rounded,
            action: TextInputAction.next,
          ),
          _field(
            _code,
            label: 'Recovery code (BLUFF-XXXX-XXXX-XXXX)',
            icon: Icons.key_rounded,
            capitalization: TextCapitalization.characters,
            action: TextInputAction.next,
          ),
          _field(
            _newPassword,
            label: 'New password (8+ characters)',
            icon: Icons.lock_outline_rounded,
            obscure: true,
          ),
        ];
    }
  }
}
