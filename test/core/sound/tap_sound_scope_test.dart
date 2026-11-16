import 'package:bluff/core/sound/ui_sounds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [TapSoundScope.hitsControl] is what decides whether a tap ticks: a press
/// on a real control must register, a tap on empty screen space must not.
Future<BuildContext> _pumpApp(
  WidgetTester tester, {
  bool withScope = false,
}) async {
  const control = Key('control');
  late BuildContext ctx;

  Widget body() => Builder(
        builder: (context) {
          ctx = context;
          return Stack(
            children: <Widget>[
              const SizedBox.expand(),
              Positioned(
                left: 40,
                top: 40,
                child: ElevatedButton(
                  key: control,
                  onPressed: () {},
                  child: const Text('Press'),
                ),
              ),
            ],
          );
        },
      );

  await tester.pumpWidget(
    MaterialApp(
      home: Material(child: body()),
      builder: withScope
          ? (context, child) => TapSoundScope(child: child ?? const SizedBox())
          : null,
    ),
  );

  return ctx;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tells a button apart from blank space', (tester) async {
    final ctx = await _pumpApp(tester);

    expect(
      TapSoundScope.hitsControl(ctx, tester.getCenter(find.byKey(const Key('control')))),
      isTrue,
      reason: 'a button is a control, so pressing it must tick',
    );
    expect(
      TapSoundScope.hitsControl(ctx, const Offset(520, 420)),
      isFalse,
      reason: 'blank space is not a control, so it must stay silent',
    );
  });

  testWidgets('stays out of its own hit test once mounted', (tester) async {
    final ctx = await _pumpApp(tester, withScope: true);

    expect(
      TapSoundScope.hitsControl(ctx, tester.getCenter(find.byKey(const Key('control')))),
      isTrue,
      reason: 'a button must still read as a control with the scope mounted',
    );
    expect(
      TapSoundScope.hitsControl(ctx, const Offset(520, 420)),
      isFalse,
      reason: 'the scope listens app-wide, so it must not count as a control',
    );
  });
}
