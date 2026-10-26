// A chrome tooltip on a touch screen (fix in 1.0.2): a tap on an icon
// button does what it says and leaves no tooltip over what it opened; a long
// press shows the tooltip, as a Material tooltip does; a mouse shows it on
// hover. Fixture: the editor on a phone, its right button (Properties).
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

Future<void> mount(WidgetTester tester) async {
  final c = PlanController(kits: const []);
  addTearDown(c.dispose);
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      supportedLocales: planSupportedLocales,
      localizationsDelegates: planLocalizationsDelegates,
      home: Scaffold(body: PlanEditor(controller: c))));
  await tester.pump();
}

Finder get button => find.byKey(const Key('chrome-right-button'));
Finder get tip => find.text('Properties');

void main() {
  testWidgets(
      'TT1 a tap on the right button opens the drawer and shows no tooltip '
      'over it', (tester) async {
    await mount(tester);
    expect(tip, findsNothing, reason: 'premise: no tooltip before');
    await tester.tap(button, kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chrome-right-drawer')), findsOneWidget);
    expect(tip, findsNothing);
  });

  testWidgets(
      'TT4 a finger held briefly, short of a long press, shows no tooltip '
      '(shadcn\'s default shows it on the tap\'s down)', (tester) async {
    await mount(tester);
    final g = await tester.startGesture(tester.getCenter(button),
        kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tip, findsNothing);
    await g.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('TT2 a long press on it shows its tooltip, and lifting hides it',
      (tester) async {
    await mount(tester);
    final g = await tester.startGesture(tester.getCenter(button),
        kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget);
    await g.up();
    await tester.pumpAndSettle();
    expect(tip, findsNothing);
  });

  testWidgets('TT3 a mouse over it shows its tooltip', (tester) async {
    await mount(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(button));
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget);
  });
}
