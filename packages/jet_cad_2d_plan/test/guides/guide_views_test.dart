// The views' alignment-guide options (alignment guides spec, "Turning them
// off"; plan Task 9): the allowance has one owner per mounted view, a swap
// hands the old controller's back, a dispose does not, and the theme's
// guide width reaches the controller in both modes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/editor_host.dart';

void main() {
  testWidgets(
      'PlanEditor(alignmentGuides: false) turns guides off in design and in '
      'service, and the user\'s choice survives the switch (M-GV-1)',
      (tester) async {
    final c = editorController();
    await pumpEditor(tester, PlanEditor(controller: c, alignmentGuides: false));
    expect(c.alignmentGuides.allowed, isFalse);
    expect(c.alignmentGuides.on, isFalse);
    expect(c.alignmentGuides.userOn, isTrue, reason: 'premise');
    c.alignmentGuides.toggle();
    expect(c.alignmentGuides.userOn, isFalse);

    c.setMode(PlanMode.service);
    await tester.pump();
    await tester.pump();
    expect(find.byType(PlanServiceView), findsOneWidget);
    expect(c.alignmentGuides.allowed, isFalse,
        reason: 'the replaced canvas\'s dispose must not reset (P-1)');
    expect(c.alignmentGuides.on, isFalse);
    expect(c.alignmentGuides.userOn, isFalse);

    c.setMode(PlanMode.design);
    await tester.pump();
    await tester.pump();
    expect(c.alignmentGuides.allowed, isFalse);
  });

  testWidgets(
      'PlanEditor hands a changed alignmentGuides to the service view it '
      'rebuilt (M-GV-2)', (tester) async {
    final c = editorController();
    await pumpEditor(tester, PlanEditor(controller: c));
    c.setMode(PlanMode.service);
    await tester.pump();
    await tester.pump();
    expect(c.alignmentGuides.allowed, isTrue);
    await pumpEditor(tester, PlanEditor(controller: c, alignmentGuides: false));
    expect(c.alignmentGuides.allowed, isFalse);
    expect(
        tester
            .widget<PlanServiceView>(find.byType(PlanServiceView))
            .alignmentGuides,
        isFalse);
    await pumpEditor(tester, PlanEditor(controller: c));
    expect(c.alignmentGuides.allowed, isTrue);
  });

  testWidgets(
      'a PlanCanvas(alignmentGuides: false) swapped to another controller '
      'gives the old one its allowance back; a dispose leaves it (M-GV-3)',
      (tester) async {
    final a = editorController();
    final b = editorController();
    Widget host(Widget? child) =>
        MaterialApp(home: Scaffold(body: child ?? const SizedBox()));
    await tester.pumpWidget(host(
        PlanCanvas(controller: a, alignmentGuides: false, autofocus: false)));
    await tester.pump();
    expect(a.alignmentGuides.allowed, isFalse);
    await tester.pumpWidget(host(
        PlanCanvas(controller: b, alignmentGuides: false, autofocus: false)));
    await tester.pump();
    expect(b.alignmentGuides.allowed, isFalse);
    expect(a.alignmentGuides.allowed, isTrue, reason: 'no view speaks for a');
    await tester.pumpWidget(host(null));
    await tester.pump();
    expect(b.alignmentGuides.allowed, isFalse,
        reason: 'a dispose does not reset (P-1)');
  });

  testWidgets(
      'a PlanServiceView swapped to another controller gives the old one its '
      'allowance back (M-GV-4)', (tester) async {
    final a = editorController()..setMode(PlanMode.service);
    final b = editorController()..setMode(PlanMode.service);
    Widget host(PlanController c) => MaterialApp(
        home: Scaffold(
            body: PlanServiceView(controller: c, alignmentGuides: false)));
    await tester.pumpWidget(host(a));
    await tester.pump();
    expect(a.alignmentGuides.allowed, isFalse);
    await tester.pumpWidget(host(b));
    await tester.pump();
    expect(b.alignmentGuides.allowed, isFalse);
    expect(a.alignmentGuides.allowed, isTrue);
  });

  testWidgets(
      'PlanTheme(guideWidth: 3) sets guideStrokePixels in design and in '
      'service; no theme sets 1 (M-GV-5)', (tester) async {
    final c = editorController();
    await pumpEditor(tester, PlanEditor(controller: c));
    expect(c.guideStrokePixels, 1.0);
    await pumpEditor(tester,
        PlanEditor(controller: c, theme: const PlanTheme(guideWidth: 3)));
    expect(c.guideStrokePixels, 3.0);
    c.setMode(PlanMode.service);
    await tester.pump();
    await tester.pump();
    expect(c.guideStrokePixels, 3.0);
    await pumpEditor(tester,
        PlanEditor(controller: c, theme: const PlanTheme(guideWidth: 5)));
    expect(c.guideStrokePixels, 5.0);
    await pumpEditor(tester, PlanEditor(controller: c));
    expect(c.guideStrokePixels, 1.0);
  });
}
