// The alignment-guide switch (alignment guides spec, "The setting"): `on` is
// the user's choice and the canvas's allowance together. The allowance is
// written inside a build, so it changes `allowed` at once and notifies after
// the frame (as `snappingAllowed`); a user toggle notifies at once.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/mark_kit.dart';

PlanController _controller() {
  final c = PlanController(kits: [markKit()]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('on at start; toggle flips the user choice, one notification',
      (tester) async {
    final g = _controller().alignmentGuides;
    var n = 0;
    g.addListener(() => n++);
    expect(g.on, isTrue);
    expect(g.userOn, isTrue);
    expect(g.allowed, isTrue);
    g.toggle();
    expect(g.userOn, isFalse);
    expect(g.on, isFalse);
    expect(n, 1);
    g.toggle();
    expect(g.on, isTrue);
    expect(n, 2);
  });

  testWidgets('the allowance changes at once and notifies after the frame',
      (tester) async {
    final c = _controller();
    final g = c.alignmentGuides;
    var n = 0;
    g.addListener(() => n++);
    c.alignmentGuidesAllowed = false;
    expect(g.allowed, isFalse);
    expect(g.on, isFalse);
    expect(g.userOn, isTrue);
    expect(n, 0);
    await tester.pump();
    expect(n, 1);
  });

  testWidgets('the same allowance twice notifies once', (tester) async {
    final c = _controller();
    var n = 0;
    c.alignmentGuides.addListener(() => n++);
    c.alignmentGuidesAllowed = false;
    c.alignmentGuidesAllowed = false;
    await tester.pump();
    expect(n, 1);
    c.alignmentGuidesAllowed = true;
    c.alignmentGuidesAllowed = true;
    await tester.pump();
    expect(n, 2);
    expect(c.alignmentGuides.on, isTrue);
  });

  testWidgets('a notice owed when the controller is disposed is dropped',
      (tester) async {
    final c = PlanController(kits: [markKit()]);
    c.alignmentGuidesAllowed = false;
    c.dispose();
    await tester.pump();
  });

  testWidgets('the user choice survives a mode switch and back',
      (tester) async {
    final c = _controller();
    c.alignmentGuides.toggle();
    c.setMode(PlanMode.service);
    expect(c.alignmentGuides.userOn, isFalse);
    c.setMode(PlanMode.design);
    expect(c.alignmentGuides.userOn, isFalse);
    expect(c.alignmentGuides.on, isFalse);
  });

  testWidgets('guideStrokePixels starts at 1', (tester) async {
    expect(_controller().guideStrokePixels, 1.0);
  });
}
