import 'package:bluff/games/chess/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.signOut();
  });

  test('bootstraps a local guest profile', () async {
    final first = await SessionService.instance.current;
    expect(first.isGuest, isTrue);
    expect(first.displayName, 'Guest');
    expect(SessionService.instance.isGuest, isTrue);
    expect(SessionService.instance.isSignedIn, isTrue);

    final second = await SessionService.instance.current;
    expect(second.id, first.id, reason: 'the guest session is stable');
  });

  test('signUp validates username and password', () async {
    final shortName = await SessionService.instance.signUp(
      username: 'ab',
      password: 'longenough',
    );
    expect(shortName.ok, isFalse);
    expect(shortName.error, contains('Username must be'));

    final badChars = await SessionService.instance.signUp(
      username: 'Not Valid!',
      password: 'longenough',
    );
    expect(badChars.ok, isFalse);
    expect(badChars.error, contains('lowercase letters'));

    final shortPassword = await SessionService.instance.signUp(
      username: 'tester',
      password: 'short',
    );
    expect(shortPassword.ok, isFalse);
    expect(shortPassword.error, contains('at least 8'));
  });

  test('signUp creates an account with a one-time recovery code', () async {
    final result = await SessionService.instance.signUp(
      username: 'maggie',
      password: 'castle42',
      displayName: 'Maggie',
    );

    expect(result.ok, isTrue);
    expect(result.profile!.username, 'maggie');
    expect(result.profile!.displayName, 'Maggie');
    expect(result.profile!.isGuest, isFalse);
    expect(
      result.recoveryCode,
      matches(RegExp(r'^BLUFF-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$')),
    );
    expect(SessionService.instance.isGuest, isFalse);

    final duplicate = await SessionService.instance.signUp(
      username: 'maggie',
      password: 'another1',
    );
    expect(duplicate.ok, isFalse);
    expect(duplicate.error, contains('taken'));
  });

  test('signIn authenticates and rejects bad credentials', () async {
    await SessionService.instance.signUp(
      username: 'rowan',
      password: 'rook1234',
    );
    await SessionService.instance.signOut();

    final unknown = await SessionService.instance.signIn(
      identifier: 'nobody',
      password: 'whatever1',
    );
    expect(unknown.ok, isFalse);
    expect(unknown.error, contains('No account'));

    final wrongPassword = await SessionService.instance.signIn(
      identifier: 'rowan',
      password: 'wrongpass',
    );
    expect(wrongPassword.ok, isFalse);
    expect(wrongPassword.error, contains('Incorrect password'));

    final ok = await SessionService.instance.signIn(
      identifier: 'ROWAN', // identifiers are case-insensitive
      password: 'rook1234',
    );
    expect(ok.ok, isTrue);
    expect(ok.profile!.username, 'rowan');
    expect(SessionService.instance.isGuest, isFalse);
  });

  test('recovery code resets a forgotten password', () async {
    final signup = await SessionService.instance.signUp(
      username: 'simon',
      password: 'initial1',
    );
    final code = signup.recoveryCode!;

    final reset = await SessionService.instance.resetPassword(
      username: 'simon',
      // Typed sloppily: lowercase, spaces instead of dashes.
      recoveryCode: code.toLowerCase().replaceAll('-', ' '),
      newPassword: 'brandnew1',
    );
    expect(reset.ok, isTrue);

    final withNew = await SessionService.instance.signIn(
      identifier: 'simon',
      password: 'brandnew1',
    );
    expect(withNew.ok, isTrue);

    final badCode = await SessionService.instance.resetPassword(
      username: 'simon',
      recoveryCode: 'BLUFF-ZZZZ-ZZZZ-ZZZZ',
      newPassword: 'another1',
    );
    expect(badCode.ok, isFalse);
    expect(badCode.error, contains('recovery code'));
  });

  test('changePassword requires the current password', () async {
    await SessionService.instance.signUp(
      username: 'dana',
      password: 'firstpwd1',
    );

    final wrong = await SessionService.instance.changePassword(
      currentPassword: 'notit1234',
      newPassword: 'secondpwd',
    );
    expect(wrong.ok, isFalse);
    expect(wrong.error, contains('Incorrect password'));

    final changed = await SessionService.instance.changePassword(
      currentPassword: 'firstpwd1',
      newPassword: 'secondpwd',
    );
    expect(changed.ok, isTrue);

    await SessionService.instance.signOut();
    final signIn = await SessionService.instance.signIn(
      identifier: 'dana',
      password: 'secondpwd',
    );
    expect(signIn.ok, isTrue);
  });

  test('signOut clears the session back to guest', () async {
    final signup = await SessionService.instance.signUp(
      username: 'kai',
      password: 'quietmoon',
    );
    final accountId = signup.profile!.id;

    await SessionService.instance.signOut();
    expect(SessionService.instance.isSignedIn, isFalse);
    expect(SessionService.instance.currentOrNull, isNull);

    final guest = await SessionService.instance.current;
    expect(guest.isGuest, isTrue);
    expect(guest.id, isNot(accountId));

    // The account itself survives the sign-out.
    final back = await SessionService.instance.signIn(
      identifier: 'kai',
      password: 'quietmoon',
    );
    expect(back.ok, isTrue);
    expect(back.profile!.id, accountId);
  });

  test('switchTo restores another stored profile', () async {
    final signup = await SessionService.instance.signUp(
      username: 'lee',
      password: 'sunnyday1',
    );
    await SessionService.instance.ensureGuest();

    final switched =
        await SessionService.instance.switchTo(signup.profile!.id);
    expect(switched, isTrue);
    expect(SessionService.instance.currentOrNull!.id, signup.profile!.id);

    final missing = await SessionService.instance.switchTo('nope');
    expect(missing, isFalse);
  });
}
