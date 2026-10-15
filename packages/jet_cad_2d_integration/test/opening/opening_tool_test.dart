// Ported from jet_cad_floor_plan/test/opening_tool_test.dart (spec 3a C6, C7, R15-2..R15-5).
// ignore_for_file: invalid_use_of_internal_member
// Spec 08 D14: the Door (D), Window (N) and Gap (G) tools in PlanEditor:
// OT1 (shell) and OT1 (rv9-guardDNG). The cases that drive the tool
// directly, and OT1 (shell)'s preview line (R15-2), run in the kit. Every
// wall is at the far origin in its own rotated group, none is
// axis-aligned, the camera is rotated, and no click is central. Expected
// positions come from `support/opening_support.dart`'s oracles, which
// never call the kit's geometry.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/opening_support.dart';

const centre = Justification.centre;
const left = Justification.left;

void main() {
  testWidgets(
      'OT1 (M-08b, X9-raw, X9-unclamped) D, N and G each place one opening '
      'with one click and one undo step, centred at the resolved click '
      'projected onto the host, at the tool\'s width; a click near a mitre '
      'stores the clamped centre and nothing is diagnosed; a click in no '
      'band places nothing; the tool stays active, and Esc returns to '
      'Select', (tester) async {
    final c = openingController(openingPlanText(shellPage, (_) {}));
    await pumpEditor(tester, c, centre: plan(2500, 1500), scale: 0.15);
    final doc = c.document;
    // An L: A (200, centred) runs into B (115, left-justified) at a mitre.
    final a = addWallFromSeed(doc, plan(0, 0), plan(5000, 0), 200, centre);
    final b = addWallFromSeed(doc, plan(5000, 0), plan(5000, 3000), 115, left);
    doc.commands.clearHistory();
    await tester.pump();
    expect(diagnosticsOf(doc), isEmpty);
    final fa = oracleFrameOf(doc, a), fb = oracleFrameOf(doc, b);

    // The palette reaches every tool.
    for (final (key, name) in const [
      ('tool-architecture.door', 'Door'),
      ('tool-architecture.window', 'Window'),
      ('tool-architecture.gap', 'Gap'),
      ('tool-plan.select', 'Select'),
    ]) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      expect(status(tester), name, reason: key);
    }

    /// One click at [raw] with the tool [toolId] active places one opening:
    /// returns it and checks the undo depth, the resolved point and the
    /// tool, whose word is [word].
    Future<Handle> place(String toolId, String word, Vector2 raw) async {
      final before = openings(doc);
      final depth = doc.commands.undoDepth;
      await tapWorld(tester, c, raw);
      expect(xy(placementOf(c, toolId).hoverPoint), xy(gridOf(doc, raw)),
          reason: 'resolved to the grid point, not snapped to an entity');
      expect(openings(doc), hasLength(before.length + 1), reason: 'one more');
      expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
      expect(status(tester), word, reason: 'the tool stays active');
      return added(doc, before);
    }

    // D: a door at a non-default width, 1,300 along A and 37 off it.
    await press(tester, LogicalKeyboardKey.keyD);
    await enterAndSubmit(tester, settingWidth, '750');
    expect(status(tester), 'Door');
    final r1 = oracleAt(fa, 1300, 37);
    // A mouse hover first: the preview is built and painted (a leaf, an
    // arc and two jambs: asserted in the kit, R15-2), and nothing is
    // committed.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    final s1 = cameraOf(c).value.worldToScreen(r1);
    await mouse.moveTo(
        tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s1.x, s1.y));
    await tester.pump();
    expect(openings(doc), isEmpty);
    final d1 = await place(ArchitectureTools.door, 'Door', r1);
    final p1 = doc.components.get<OpeningParams>(d1)!;
    expect(p1.host, a);
    expect(p1.kind, OpeningKind.door);
    expect(p1.width, 750);
    expect(p1.position, closeTo(oracleU(fa, gridOf(doc, r1)), 1e-6),
        reason: 'the resolved click projected onto A');

    // N: a window. The raw click is 3 mm inside A's left face; its grid
    // point lies outside the band (so the host comes from the raw point),
    // and is what is projected.
    await press(tester, LogicalKeyboardKey.keyN);
    await enterAndSubmit(tester, settingWidth, '1000');
    expect(status(tester), 'Window');
    Vector2? r2;
    for (var u = 2400.0; u < 2800; u += 3) {
      final raw = oracleAt(fa, u, 97);
      final g = gridOf(doc, raw);
      if ((g - fa.s).dot(fa.n) > 101) {
        r2 = raw;
        break;
      }
    }
    expect(r2, isNotNull, reason: 'a click whose grid point leaves the band');
    final w2 = await place(ArchitectureTools.window, 'Window', r2!);
    final p2 = doc.components.get<OpeningParams>(w2)!;
    expect(p2.host, a);
    expect(p2.kind, OpeningKind.window);
    expect(p2.width, 1000);
    expect(p2.position, closeTo(oracleU(fa, gridOf(doc, r2)), 1e-6));
    expect((p2.hinge, p2.swing), (HingeEnd.start, SwingSide.left));

    // G: a gap on B, 1,100 along it and 20 right of it.
    await press(tester, LogicalKeyboardKey.keyG);
    await enterAndSubmit(tester, settingWidth, '640');
    expect(status(tester), 'Gap');
    final r3 = oracleAt(fb, 1100, 20);
    final g3 = await place(ArchitectureTools.gap, 'Gap', r3);
    final p3 = doc.components.get<OpeningParams>(g3)!;
    expect(p3.host, b);
    expect(p3.kind, OpeningKind.gap);
    expect(p3.width, 640);
    expect(p3.position, closeTo(oracleU(fb, gridOf(doc, r3)), 1e-6));
    expect((p3.hinge, p3.swing), (HingeEnd.start, SwingSide.left));
    expect(diagnosticsOf(doc), isEmpty);

    // D near A's mitre: 150 short of the straight span's end, so the door's
    // stored interval would run into the corner; it is stored at the
    // clamped centre, where it is drawn, and is not diagnosed.
    await press(tester, LogicalKeyboardKey.keyD);
    final (_, uE) = OpeningOracle(doc).span(a);
    final r4 = oracleAt(fa, uE - 150, -45);
    final d4 = await place(ArchitectureTools.door, 'Door', r4);
    final p4 = doc.components.get<OpeningParams>(d4)!;
    final projected = oracleU(fa, gridOf(doc, r4));
    expect(projected + 375, greaterThan(uE + 100), reason: 'into the corner');
    expect(diagnosticsOf(doc), isEmpty, reason: 'not clamped from birth');
    expect(OpeningOracle(doc).cut(p4)!.a, closeTo(p4.position - 375, 1e-6),
        reason: 'drawn where it is stored');
    expect(p4.position, closeTo(uE - 375, 1e-6), reason: 'the clamped centre');
    expect(driftOf(doc), isEmpty);

    // A click in no band places nothing.
    final before = openings(doc);
    final depth = doc.commands.undoDepth;
    await tapWorld(tester, c, plan(2500, 1500));
    expect(openings(doc), before);
    expect(doc.commands.undoDepth, depth);

    // One undo step takes the last door away; Esc returns to Select.
    await undoKey(tester);
    expect(openings(doc), [d1, w2, g3]);
    expect(status(tester), 'Door');
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
    expect(driftOf(doc), isEmpty);
  });

  testWidgets(
      'OT1 (rv9-guardDNG) D, N and G typed into the Text tool\'s field and '
      'into the page panel\'s scale field are text, not shortcuts (as '
      'planner_draw_test.dart\'s A8 and A9)', (tester) async {
    final c = openingController(openingPlanText(shellPage, (_) {}));
    await pumpEditor(tester, c, centre: plan(2500, 1500), scale: 0.15);
    await press(tester, LogicalKeyboardKey.keyT);
    expect(status(tester), 'Text');
    await tapWorld(tester, c, plan(1200, 800));
    for (final key in const [
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyN,
      LogicalKeyboardKey.keyG,
    ]) {
      expect(await tester.sendKeyEvent(key), isFalse,
          reason: '$key reaches the platform as text');
      await tester.pump();
      expect(status(tester), 'Text', reason: '$key in the text field');
    }
    await press(tester, LogicalKeyboardKey.escape);
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
    await tester.tap(find.byKey(const Key('page-scale')));
    await tester.pump();
    for (final key in const [
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyN,
      LogicalKeyboardKey.keyG,
    ]) {
      expect(await tester.sendKeyEvent(key), isFalse,
          reason: '$key reaches the platform as text');
      await tester.pump();
      expect(status(tester), 'Select', reason: '$key in the scale field');
    }
  });
}
