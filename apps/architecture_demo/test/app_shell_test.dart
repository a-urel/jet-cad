// The app shell (spec B1): one controller, one editor, the file chords
// consumed above the Navigator.
import 'package:architecture_demo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

Future<ArchitectureDemoAppState> pumpApp(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const ArchitectureDemoApp());
  await tester.pump();
  return tester
      .state<ArchitectureDemoAppState>(find.byType(ArchitectureDemoApp));
}

void main() {
  testWidgets('AS1 the app pumps: one editor, the kit\'s Symbols tab, clean',
      (tester) async {
    final app = await pumpApp(tester);
    expect(find.byType(PlanEditor), findsOneWidget);
    expect(find.text('Symbols'), findsWidgets);
    expect(app.controller.dirty.value, isFalse);
  });

  for (final modifier in [
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.control
  ]) {
    testWidgets('CH-consume ${modifier.keyLabel}+S over a dialog is handled',
        (tester) async {
      final app = await pumpApp(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      showDialog<void>(
          context: navigator.context,
          builder: (_) =>
              const AlertDialog(content: TextField(key: Key('dialog-field'))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dialog-field')), findsOneWidget);
      await tester.tap(find.byKey(const Key('dialog-field')));
      await tester.pump();

      await tester.sendKeyDownEvent(modifier);
      final handled = await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();

      expect(handled, isTrue, reason: 'the chord is consumed above the route');
      expect(find.byKey(const Key('dialog-field')), findsOneWidget,
          reason: 'dialog stays');
      expect(app.controller.dirty.value, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('AS-dispose unmounting disposes cleanly', (tester) async {
    await pumpApp(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
