// Spec 2b S3 ("the design is not edited in service ... dirty never moves in
// service"), final review I-1: the design's tools write through their own
// dispatcher, so a host that keeps a PlanCanvas mounted while the plan is
// in service must find the design read-only there. The design document's
// engine permissions are DraftPermissions.readOnly exactly while a service
// copy exists, and the profile's again on leaving it.
//
// The fixture is canvas_draw_test's: a line on a 1:20 page under a zoomed,
// rotated, non-reflecting camera, dragged by the mouse on the canvas.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/canvas_fixture.dart';

void main() {
  testWidgets(
      'SM-design-readonly: a PlanCanvas mounted in service does not edit the '
      'design (a drag leaves the bytes and dirty alone, a profile change in '
      'service does not re-open it); back in design the same drag edits '
      '(M-SM-ro-enter, M-SM-ro-setter)', (tester) async {
    final f = drawController();
    final c = f.c;
    await pumpDraw(tester, c);
    // The line's middle, and a drop 120 mm right and 60 mm up of it.
    const mid = (x: 7219.1, y: 3175.9);
    Future<void> drag() async {
      c.selection.replace([SelectionKey.root(f.line)]);
      await tester.pump();
      final at = globalOf(tester, c, mid.x, mid.y);
      final to = globalOf(tester, c, mid.x + 120, mid.y + 60);
      final gesture =
          await tester.startGesture(at, kind: PointerDeviceKind.mouse);
      await tester.pump();
      for (var i = 1; i <= 4; i++) {
        await gesture.moveTo(Offset.lerp(at, to, i / 4)!);
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
    }

    final designed = bytes(c);
    c.setMode(PlanMode.service);
    await tester.pump();
    expect(find.byType(PlanCanvas), findsOneWidget,
        reason: 'premise: the canvas stays mounted in service');
    expect(c.document.commands.permissions, same(DraftPermissions.readOnly));

    await drag();
    expect(tester.takeException(), isNull);
    expect(bytes(c), designed, reason: 'the drag did not move the line');
    expect(c.dirty.value, isFalse);
    expect(c.document.commands.canUndo, isFalse);

    // The profile changes in service: still read-only until leaving.
    c.permissions = PlanPermissions.full.copyWith(rotate: false);
    expect(c.permissions.draft, same(DraftPermissions.all),
        reason: 'premise: the new profile edits');
    expect(c.document.commands.permissions, same(DraftPermissions.readOnly));
    await drag();
    expect(bytes(c), designed, reason: 'the setter did not re-open it');
    expect(c.dirty.value, isFalse);

    c.setMode(PlanMode.design);
    await tester.pump();
    expect(c.document.commands.permissions, same(DraftPermissions.all));
    await drag();
    expect(bytes(c), isNot(designed),
        reason: 'positive control: the same drag edits in design');
    expect(c.dirty.value, isTrue);
  });

  testWidgets(
      'SM-design-readonly-load: a load and a new plan in service keep the '
      'new design read-only while the copy exists, and give it the profile '
      'on leaving', (tester) async {
    final c = drawController().c;
    c.setMode(PlanMode.service);
    c.load(bytes(c));
    expect(c.mode.value, PlanMode.service);
    expect(c.document.commands.permissions, same(DraftPermissions.readOnly));
    c.newPlan();
    expect(c.document.commands.permissions, same(DraftPermissions.readOnly));
    c.resetService();
    expect(c.document.commands.permissions, same(DraftPermissions.readOnly));
    c.setMode(PlanMode.design);
    expect(c.document.commands.permissions, same(DraftPermissions.all));
    c.permissions = PlanPermissions.readOnly;
    expect(c.document.commands.permissions, same(DraftPermissions.readOnly));
    c.setMode(PlanMode.service);
    c.setMode(PlanMode.design);
    expect(c.document.commands.permissions, same(DraftPermissions.readOnly),
        reason: "leaving restores the profile's, not DraftPermissions.all");
    await tester.pump();
  });
}
