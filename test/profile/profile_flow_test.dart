import 'dart:convert';

import 'package:bluff/core/profile/profile.dart';
import 'package:bluff/core/profile/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers Splash's account model on the local side: the start-state machine
/// (onboarding → main — language is onboarding's first step), local-first
/// persistence, and the fact that nothing here requires Firebase to be
/// reachable. Cloud calls are expected to fail silently in tests and the
/// profile must survive anyway.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfileRepository.instance.resetForTesting();
  });

  test(
    'fresh install starts at onboarding (language is its first step)',
    () async {
      await ProfileRepository.instance.bootstrap();

      expect(ProfileRepository.instance.startState, AppStartState.onboarding);
      expect(ProfileRepository.instance.onboardingDone, isFalse);
    },
  );

  test('walks onboarding → main like Splash', () async {
    await ProfileRepository.instance.bootstrap();
    expect(ProfileRepository.instance.startState, AppStartState.onboarding);

    await ProfileRepository.instance.completeOnboarding(
      const Profile(name: 'Rakib', avatarIndex: 3),
    );
    expect(ProfileRepository.instance.startState, AppStartState.main);
    expect(ProfileRepository.instance.profile?.name, 'Rakib');
    expect(ProfileRepository.instance.profile?.avatarIndex, 3);
  });

  test('profile is local-first: survives a restart with no network', () async {
    await ProfileRepository.instance.bootstrap();
    await ProfileRepository.instance.completeOnboarding(
      const Profile(
        name: 'Nusrat',
        gender: PlayerGender.female,
        ageBand: AgeBand.age21plus,
        group: PlayGroup.family,
        source: HearSource.friends,
      ),
    );

    // Capture what was written, then boot a brand-new instance over it.
    final prefs = await SharedPreferences.getInstance();
    final storedProfile = prefs.getString(ProfileRepository.profileKey);

    expect(storedProfile, isNotNull);
    expect(storedProfile, contains('Nusrat'));

    ProfileRepository.instance.resetForTesting();
    SharedPreferences.setMockInitialValues({
      ProfileRepository.profileKey: storedProfile!,
      ProfileRepository.onboardingDoneKey: true,
    });

    await ProfileRepository.instance.bootstrap();

    expect(ProfileRepository.instance.startState, AppStartState.main);
    expect(ProfileRepository.instance.profile?.name, 'Nusrat');
    expect(ProfileRepository.instance.profile?.gender, PlayerGender.female);
    expect(ProfileRepository.instance.profile?.group, PlayGroup.family);
    expect(ProfileRepository.instance.profile?.source, HearSource.friends);
  });

  test('a stored profile with a name implies onboarding already ran', () async {
    // Install data without the onboarding flag — e.g. a restore that set the
    // profile but crashed before writing the flag.
    final stored = jsonEncode(const Profile(name: 'Tanvir').toJson());

    SharedPreferences.setMockInitialValues({
      ProfileRepository.profileKey: stored,
    });

    await ProfileRepository.instance.bootstrap();

    expect(ProfileRepository.instance.onboardingDone, isTrue);
    expect(ProfileRepository.instance.startState, AppStartState.main);
  });

  test('corrupt profile blob is discarded instead of crashing', () async {
    SharedPreferences.setMockInitialValues({
      ProfileRepository.profileKey: '%%%',
    });

    await ProfileRepository.instance.bootstrap();

    expect(ProfileRepository.instance.profile, isNull);
    expect(ProfileRepository.instance.startState, AppStartState.onboarding);
  });

  test('unknown enum ids from the cloud fall back to defaults', () {
    final profile = Profile.fromJson(const {
      'name': 'Ghost',
      'gender': 'not_a_gender',
      'ageBand': 'not_a_band',
      'group': 'not_a_group',
      'source': 'not_a_source',
    });

    expect(profile.gender, PlayerGender.ratherNotSay);
    expect(profile.ageBand, AgeBand.unknown);
    expect(profile.group, PlayGroup.friends);
    expect(profile.source, HearSource.other);
    expect(profile.hasName, isTrue);
  });

  test('deleteAccount wipes profile and onboarding flag', () async {
    await ProfileRepository.instance.bootstrap();
    await ProfileRepository.instance.completeOnboarding(
      const Profile(name: 'Mehjabin'),
    );

    await ProfileRepository.instance.deleteAccount();

    expect(ProfileRepository.instance.profile, isNull);
    expect(ProfileRepository.instance.onboardingDone, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ProfileRepository.profileKey), isNull);
    expect(prefs.getBool(ProfileRepository.onboardingDoneKey), isNull);
    expect(prefs.getString(ProfileRepository.onboardingDraftKey), isNull);
  });

  test('an interrupted onboarding run resumes from its draft', () async {
    await ProfileRepository.instance.bootstrap();

    // Player answers three steps, then the process dies.
    await ProfileRepository.instance.saveOnboardingDraft(
      const Profile(name: 'Rakib', avatarIndex: 5, gender: PlayerGender.male),
      3,
    );

    // Fresh boot over the same prefs.
    ProfileRepository.instance.resetForTesting();
    await ProfileRepository.instance.bootstrap();

    expect(ProfileRepository.instance.startState, AppStartState.onboarding);

    final draft = await ProfileRepository.instance.loadOnboardingDraft();
    expect(draft, isNotNull);
    expect(draft!.step, 3);
    expect(draft.profile.name, 'Rakib');
    expect(draft.profile.avatarIndex, 5);
    expect(draft.profile.gender, PlayerGender.male);
  });

  test('finishing onboarding retires the draft', () async {
    await ProfileRepository.instance.bootstrap();
    await ProfileRepository.instance.saveOnboardingDraft(
      const Profile(name: 'Rakib'),
      8,
    );

    await ProfileRepository.instance.completeOnboarding(
      const Profile(name: 'Rakib'),
    );

    expect(await ProfileRepository.instance.loadOnboardingDraft(), isNull);
  });

  test('a corrupt draft restarts onboarding instead of crashing', () async {
    SharedPreferences.setMockInitialValues({
      ProfileRepository.onboardingDraftKey: '{{{',
    });

    await ProfileRepository.instance.bootstrap();

    expect(ProfileRepository.instance.startState, AppStartState.onboarding);
    expect(await ProfileRepository.instance.loadOnboardingDraft(), isNull);
  });

  test('a leftover draft is dropped once onboarding is done', () async {
    SharedPreferences.setMockInitialValues({
      ProfileRepository.onboardingDoneKey: true,
      ProfileRepository.onboardingDraftKey: 'stale',
    });

    await ProfileRepository.instance.bootstrap();

    expect(await ProfileRepository.instance.loadOnboardingDraft(), isNull);
  });
}
