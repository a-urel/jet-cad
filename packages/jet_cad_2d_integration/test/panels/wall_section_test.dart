// Spec 07 D11's Wall section. Every wall sits at the far origin in its own
// rotated group (`groupAt`), the plan is turned 23 degrees, and the camera
// is rotated.
// Ported from jet_cad_floor_plan/test/selection_panel_test.dart (WS1-WS11;
// WS7 (Box) is 2a's) for jet_cad_2d_integration (3a Task 27); assertions
// unchanged but rulings IP-R1, IP-R2, IP-R8. WS9 becomes WS9-open (the
// controller's ruling, Task 18's rule); it reads `frozen`, @internal
// (ruling R-P9).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show Tool;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show KitDiagnosticCode;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart'
    show PlanController, PlanLocked;
import 'package:jet_cad_2d_plan/src/chrome/text_field.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_rig.dart';
import '../support/plans.dart' hide textOf;
import '../support/room_plans.dart' show clickAt, select;

Finder get width => field('width');
Finder get height => field('height');
Finder get thickness => field('thickness');
Finder get wallSection =>
    sectionFinder(ArchitectureTypes.wall, ArchitectureTools.wall);

String textOf(WidgetTester tester, Finder f) =>
    tester.widget<PlanTextField>(f).controller.text;

/// The justification choice's selection (today's segment set: one value).
Set<Justification> shownJustification(WidgetTester tester) =>
    {menuOf(tester, 'justification').value! as Justification};

/// The kit's thickness bound (kit-internal, R-P1).
const double kWallMaxThickness =
    1e7; // jet_cad_floor_plan/lib/src/parametric/wall.dart:35 (kit-internal)

const Handle wa = Handle(1300), wb = Handle(2600), wc = Handle(3900);
const Handle bx = Handle(5200);

/// An L at the far origin: A (200, centre) runs into [lCorner] and B (115,
/// left) runs out of it at 110 degrees, each in its own rotated group.
final Vector2 lStart = plan(0, 0), lCorner = plan(3000, 0);
final Vector2 lEnd = polar(lCorner, 23 + 110, 2500);

/// A 1:20 page near the far origin, grid snap on at 10 mm; the L, a free
/// wall C (150, right) and a box in its own rotated group; no history.
String panelPlanJson() => planWith((doc) {
      doc.commands.execute(SetComponentCommand<PageComponent>(
          doc.rootHandle,
          PageComponent(
              scaleDenominator: 20,
              originX: ox - 2000,
              originY: oy - 2000,
              gridStepMm: 10)));
      doc.commands.execute(
          addWall(doc, wa, lStart, lCorner, 200, Justification.centre));
      doc.commands
          .execute(addWall(doc, wb, lCorner, lEnd, 115, Justification.left));
      doc.commands.execute(addWall(doc, wc, plan(500, 1500), plan(2500, 1900),
          150, Justification.right));
      doc.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: bx,
            parent: doc.rootHandle,
            transform: groupAt(bx.value),
            children: const [])),
        SetComponentCommand<BoxParams>(bx, const BoxParams(120, 70)),
      ], label: 'Add box'));
    });

/// Pumps the editor over [json] (a controller disposed at tear-down), then
/// sets a rotated, non-reflecting camera centred on the L's corner.
Future<PlanController> pumpPanel(WidgetTester tester, String json) async {
  final c = architectureController(json: json);
  addTearDown(c.dispose);
  await pumpEditor(tester, c, centre: lCorner, scale: 0.15, turn: 0.35);
  return c;
}

/// A primary click at world [p] (the integration rig's `clickAt`).
Future<void> clickWorld(WidgetTester tester, PlanController c, Vector2 p) =>
    clickAt(tester, c, p);

/// The brief's malformed plan (ruling IP-R8): [panelPlanJson] with A's
/// fill naming B's outline, a file the planner refuses to regenerate
/// (spec 07 D8).
String malformedPlanJson() {
  final j = jsonDecode(panelPlanJson()) as Map<String, Object?>;
  final source = architectureController(json: panelPlanJson());
  try {
    final src = source.document;
    final aFill =
        kids(src, wa).firstWhere((k) => kindOf(src, k) == EntityKind.fill);
    final bFill =
        kids(src, wb).firstWhere((k) => kindOf(src, k) == EntityKind.fill);
    final bOutline = payloadOf(src, bFill).scalars[0];
    for (final e in j['entities']! as List) {
      final entity = e as Map<String, Object?>;
      if ((entity['record']! as Map)['handle'] == aFill.value) {
        (entity['geometry']! as Map)['scalars'] = [bOutline];
      }
    }
  } finally {
    source.dispose();
  }
  return jsonEncode(j);
}

Future<void> enterAndSubmit(
    WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  testWidgets(
      'WS1 the Wall section shows for exactly one selected wall; hidden for '
      'none, two, and a box (which shows the Box section)', (tester) async {
    final view = await pumpPanel(tester, panelPlanJson());
    expect(wallSection, findsNothing);
    await select(tester, view, [wb]);
    expect(wallSection, findsOneWidget);
    expect(width, findsNothing);
    expect(textOf(tester, thickness), '115');
    expect(shownJustification(tester), {Justification.left});
    await select(tester, view, [wc]);
    expect(textOf(tester, thickness), '150');
    expect(shownJustification(tester), {Justification.right});
    await select(tester, view, [wa, wb]);
    expect(wallSection, findsNothing);
    await select(tester, view, [bx]);
    expect(wallSection, findsNothing);
    expect(textOf(tester, width), '120');
    await select(tester, view, []);
    expect(wallSection, findsNothing);
    expect(width, findsNothing);
  });

  testWidgets(
      'WS2 Enter commits the thickness in one undo step; the joined L '
      'regenerates, still mitred; undo shows the old value', (tester) async {
    final view = await pumpPanel(tester, panelPlanJson());
    final doc = view.document;
    final pa = doc.components.get<WallParams>(wa)!;
    final pb = doc.components.get<WallParams>(wb)!;
    await select(tester, view, [wa]);
    await enterAndSubmit(tester, thickness, '262.5');
    expect(doc.commands.undoDepth, 1);
    expect(doc.components.get<WallParams>(wa), pa.copyWith(thickness: 262.5),
        reason: 'only the thickness, exactly');
    expect(doc.components.get<WallParams>(wb), pb);
    expectMitre(doc, wa, wb);
    expect(driftOf(doc), isEmpty);
    expect(textOf(tester, thickness), '262.5');
    doc.commands.undo();
    await tester.pump();
    expect(textOf(tester, thickness), '200');
    expect(doc.components.get<WallParams>(wa), pa);
  });

  testWidgets(
      'WS3 a thickness <= wallJoin.linear or unparseable reverts and commits '
      'nothing, for a wall and for the tool settings (final review m1)',
      (tester) async {
    final view = await pumpPanel(tester, panelPlanJson());
    final doc = view.document;
    final pc = doc.components.get<WallParams>(wc)!;
    await select(tester, view, [wc]);
    // 1e-12 and wallJoin.linear itself are positive: the model would store
    // either (C's local outline triangulates), so only the floor refuses.
    for (final bad in ['0', '-40', '-0', 'abc', '', '1e-12', '0.000001']) {
      await enterAndSubmit(tester, thickness, bad);
      expect(textOf(tester, thickness), '150', reason: bad);
    }
    expect(doc.commands.undoDepth, 0);
    expect(doc.components.get<WallParams>(wc), pc);
    // W itself: Enter handed focus back to the canvas.
    await pressKey(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
    expect(textOf(tester, thickness), '200');
    for (final bad in ['0', '-40', '1e-12', '0.000001']) {
      await enterAndSubmit(tester, thickness, bad);
      expect(textOf(tester, thickness), '200', reason: bad);
      // Not ported (ruling IP-R2): expect((view.tools.active as
      // WallTool).settings.value.thickness, 200, reason: bad);
    }
    await clickWorld(tester, view, plan(400, 900));
    await clickWorld(tester, view, plan(1900, 800));
    final w = walls(doc).last;
    expect(w, isNot(wc));
    expect(doc.components.get<WallParams>(w)!.thickness, 200);
  });

  testWidgets(
      "WS4 a justification change on a joined wall moves both walls' "
      'corners, in one undo step (Review Focus 4)', (tester) async {
    final view = await pumpPanel(tester, panelPlanJson());
    final doc = view.document;
    expectMitre(doc, wa, wb);
    final ra0 = worldOutline(doc, wa), rb0 = worldOutline(doc, wb);
    final shared0 = sharedNear(ra0, rb0);
    final pa = doc.components.get<WallParams>(wa)!;
    await select(tester, view, [wa]);
    expect(shownJustification(tester), {Justification.centre});
    await choose(tester, 'justification', 'left');
    expect(doc.commands.undoDepth, 1);
    expect(doc.components.get<WallParams>(wa),
        pa.copyWith(justification: Justification.left));
    expect(shownJustification(tester), {Justification.left});
    // The corners: A's two faces now sit at (200, 0), so both mitre
    // corners are the oracle meets of the new faces with B's.
    expectMitre(doc, wa, wb);
    final ra1 = worldOutline(doc, wa), rb1 = worldOutline(doc, wb);
    final shared1 = sharedNear(ra1, rb1);
    for (final p in shared0) {
      expect(nearestIn(shared1, p), greaterThan(50),
          reason: 'every shared corner moved');
    }
    // B's corners at the joint moved; its two at the far end did not.
    expect(sharedNear(rb0, rb1), hasLength(2));
    expect([for (final p in sharedNear(rb0, rb1)) nearestIn(shared0, p)],
        everyElement(greaterThan(1000)));
    // A's start is free: its square end moved by the face shift alone.
    expect(sharedNear(ra0, ra1), isEmpty);
    expect(driftOf(doc), isEmpty);
    await choose(tester, 'justification', 'left');
    expect(doc.commands.undoDepth, 1, reason: 'the same value is no step');
    doc.commands.undo();
    await tester.pump();
    await tester.pump();
    expect(shownJustification(tester), {Justification.centre});
    expect(sharedNear(worldOutline(doc, wa), ra0), hasLength(4));
    expectMitre(doc, wa, wb);
  });

  testWidgets(
      'WS5 under runtime the Wall section is read-only: the field and the '
      'toggle', (tester) async {
    final view = await pumpPanel(tester, panelPlanJson());
    final doc = view.document;
    final pa = doc.components.get<WallParams>(wa)!;
    doc.commands.permissions = DraftPermissions.runtime;
    await select(tester, view, [wa]);
    expect(tester.widget<PlanTextField>(thickness).readOnly, isTrue);
    expect(menuOf(tester, 'justification').enabled, isFalse);
    await choose(tester, 'justification', 'right');
    expect(doc.components.get<WallParams>(wa), pa);
    expect(doc.commands.undoDepth, 0);
    doc.commands.permissions = DraftPermissions.all;
    await select(tester, view, [wb]);
    expect(tester.widget<PlanTextField>(thickness).readOnly, isFalse);
  });

  testWidgets(
      "WS6 with the Wall tool active the section edits the tool's settings "
      '(no undo step) and the next wall uses them; tool letters typed in '
      'the field do not switch tools', (tester) async {
    final view = await pumpPanel(tester, panelPlanJson());
    final doc = view.document;
    await pressKey(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
    expect(wallSection, findsOneWidget);
    expect(textOf(tester, thickness), '200');
    expect(shownJustification(tester), {Justification.centre});
    await enterAndSubmit(tester, thickness, '115');
    await choose(tester, 'justification', 'left');
    expect(doc.commands.undoDepth, 0, reason: 'settings are not the model');
    await tester.tap(thickness);
    await tester.pump();
    for (final k in [LogicalKeyboardKey.keyV, LogicalKeyboardKey.keyB]) {
      await pressKey(tester, k);
      expect(status(tester), 'Wall');
    }
    await clickWorld(tester, view, plan(400, 900));
    await clickWorld(tester, view, plan(1900, 800));
    await pressKey(tester, LogicalKeyboardKey.enter);
    final w = walls(doc).last;
    expect(w, isNot(wc));
    final p = doc.components.get<WallParams>(w)!;
    expect([p.thickness, p.justification], [115, Justification.left]);
    expect(textOf(tester, thickness), '115');
    expect(shownJustification(tester), {Justification.left});
    // Ruling IP-R2: today's `PlacementTool` cast and `isPending` are the
    // guarded tool's `isMidShape` (the guard forwards it).
    Tool tool() => activeTool(tester);

    // Typed with no Enter, then a click mid-chain: the keystrokes already
    // reached the settings, so that click's wall has them (review round 1,
    // I1).
    await clickWorld(tester, view, plan(1500, -900));
    await tester.tap(thickness);
    await tester.pump();
    await tester.enterText(thickness, '400');
    await tester.pump();
    await clickWorld(tester, view, plan(2800, -1000));
    final w400 = walls(doc).last;
    expect(w400, isNot(w));
    expect(doc.components.get<WallParams>(w400)!.thickness, 400);
    expect(tool().isMidShape, isTrue);

    // Mid-chain, Enter in the field hands focus back to the canvas: Escape
    // ends the chain with no extra wall, and the letters work again.
    final count = walls(doc).length;
    await tester.tap(thickness);
    await tester.pump();
    await enterAndSubmit(tester, thickness, '90');
    expect(tool().isMidShape, isTrue);
    await pressKey(tester, LogicalKeyboardKey.escape);
    expect(tool().isMidShape, isFalse);
    expect(walls(doc), hasLength(count));
    expect(status(tester), 'Wall');
    await tester.tap(thickness);
    await tester.pump();
    await enterAndSubmit(tester, thickness, '95');
    await pressKey(tester, LogicalKeyboardKey.keyV);
    expect(status(tester), 'Select');
    await pressKey(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
    expect(textOf(tester, thickness), '95');

    // Back to Select: the section follows the selection again.
    await pressKey(tester, LogicalKeyboardKey.keyV);
    expect(wallSection, findsNothing);
    await select(tester, view, [wa]);
    expect(textOf(tester, thickness), '200');
  });

  testWidgets(
      'WS7 (Wall) the commit target is pinned at focus gain: a selection '
      'change while a field has focus does not redirect its commit (M-07p); '
      'a pinned wall that dies drops the text', (tester) async {
    final view = await pumpPanel(tester, panelPlanJson());
    final doc = view.document;
    final pa = doc.components.get<WallParams>(wa)!;
    final pc = doc.components.get<WallParams>(wc)!;
    await select(tester, view, [wa]);
    await tester.tap(thickness);
    await tester.pump();
    await tester.enterText(thickness, '260');
    await tester.pump();
    await select(tester, view, [wc]);
    expect(textOf(tester, thickness), '260', reason: 'focused: not reloaded');
    // Blur: a tap outside the field, on the section's title.
    await tester.tap(wallSection);
    await tester.pump();
    expect(doc.components.get<WallParams>(wa), pa.copyWith(thickness: 260));
    expect(doc.components.get<WallParams>(wc), pc);
    expect(doc.commands.undoDepth, 1);
    expect(textOf(tester, thickness), '150', reason: "now C's");

    // Enter after the selection change: the value still lands on A, once,
    // and the field then shows C (review round 1, I3).
    await select(tester, view, [wa]);
    await tester.tap(thickness);
    await tester.pump();
    await tester.enterText(thickness, '275');
    await select(tester, view, [wc]);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(doc.components.get<WallParams>(wa), pa.copyWith(thickness: 275));
    expect(doc.components.get<WallParams>(wc), pc);
    expect(doc.commands.undoDepth, 2);
    expect(textOf(tester, thickness), '150');

    // The pinned wall dies while another wall is shown, so the field stays
    // mounted: blurring drops the text (review round 1, I2).
    const we = Handle(7800);
    doc.commands.execute(addWall(
        doc, we, plan(0, -900), plan(1400, -1300), 90, Justification.left));
    await select(tester, view, [we]);
    await tester.tap(thickness);
    await tester.pump();
    await tester.enterText(thickness, '333');
    await select(tester, view, [wc]);
    doc.commands.undo();
    await tester.pump();
    expect(doc.tree[we], isNull);
    expect(wallSection, findsOneWidget);
    await tester.tap(wallSection);
    await tester.pump();
    expect(doc.components.get<WallParams>(wc), pc);
    expect(doc.commands.canRedo, isTrue, reason: 'nothing was executed');
    expect(textOf(tester, thickness), '150');

    // The pinned wall dies while the field has focus: the section hides,
    // the field loses focus, and the text is dropped.
    const wd = Handle(6500);
    doc.commands.execute(addWall(
        doc, wd, plan(0, -900), plan(1400, -1300), 90, Justification.left));
    await select(tester, view, [wd]);
    await tester.tap(thickness);
    await tester.pump();
    await tester.enterText(thickness, '333');
    await tester.pump();
    doc.commands.undo();
    await tester.idle();
    await tester.pump();
    expect(doc.tree[wd], isNull);
    expect(wallSection, findsNothing);
    expect(doc.commands.canRedo, isTrue, reason: 'nothing was executed');
    expect(doc.commands.undoDepth, 2);
    expect([
      for (final h in walls(doc)) doc.components.get<WallParams>(h)!.thickness
    ], [
      275,
      115,
      150
    ]);
  });

  testWidgets(
      'WS8 with geometry allowed and components denied, the Wall and Box '
      'fields are read-only: a commit is a SetComponentCommand (final '
      'review m4)', (tester) async {
    final view = await pumpPanel(tester, panelPlanJson());
    final doc = view.document;
    final pa = doc.components.get<WallParams>(wa)!;
    doc.commands.permissions = const DraftPermissions(
        transform: true, components: false, geometry: true, structure: true);
    await select(tester, view, [wa]);
    expect(tester.widget<PlanTextField>(thickness).readOnly, isTrue);
    expect(menuOf(tester, 'justification').enabled, isFalse);
    await choose(tester, 'justification', 'right');
    expect(doc.components.get<WallParams>(wa), pa);
    await select(tester, view, [bx]);
    expect(tester.widget<PlanTextField>(width).readOnly, isTrue);
    expect(tester.widget<PlanTextField>(height).readOnly, isTrue);
    expect(doc.commands.undoDepth, 0);
    expect(tester.takeException(), isNull);
  });

  // Decided: premise impossible under C1.10's freeze at open (Task 18's
  // rule). Today's WS9 edited the malformed wall A and saw the document
  // refuse it at the commit; the plan freezes and locks A when it opens the
  // file (a hookFailed diagnostic), and a frozen object shows no section.
  // The old intent (a refusal the document makes: `execute` answers false,
  // the field reverts, the toggle keeps its value, nothing escapes) holds
  // on the live walls C and B, which the lock refuses: A's fill names B's
  // outline, so B regenerating without the frozen A (C1.5) would rewrite
  // that fill, owned by the locked A; C's edit reaches B through the bands.
  testWidgets(
      'WS9-open a loaded fill naming another wall\'s outline freezes that '
      'wall at open (a hookFailed diagnostic, no Wall section, a raw edit '
      'refused); an edit of C or B the lock refuses reverts the field and '
      'the toggle, no exception escapes; the box still edits', (tester) async {
    final view = await pumpPanel(tester, malformedPlanJson());
    final doc = view.document;
    // ignore: invalid_use_of_internal_member
    expect(view.frozen, contains(wa));
    expect(view.locked.value, {wa}, reason: 'the lock set is A alone');
    expect(
        [for (final d in view.diagnostics.value) (d.code, d.kitId, d.subject)],
        contains((
          KitDiagnosticCode.hookFailed,
          'architecture',
          ArchitectureTypes.wall
        )));
    await select(tester, view, [wa]);
    expect(wallSection, findsNothing);
    expect(thickness, findsNothing);
    final pa = doc.components.get<WallParams>(wa)!;
    final pb = doc.components.get<WallParams>(wb)!;
    final pc = doc.components.get<WallParams>(wc)!;
    final before = canon(doc);
    expect(
        () => doc.commands.execute(
            SetComponentCommand<WallParams>(wa, pa.copyWith(thickness: 250))),
        throwsA(isA<PlanLocked>()));
    expect(canon(doc), before);
    expect(doc.components.get<WallParams>(wa), pa);
    expect(tester.takeException(), isNull);

    // C through the panel: Enter, the lock refuses it.
    await select(tester, view, [wc]);
    await tester.tap(thickness);
    await tester.pump();
    await enterAndSubmit(tester, thickness, '250');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(textOf(tester, thickness), '150', reason: 'reverted');
    expect(doc.components.get<WallParams>(wc), pc);
    expect(canon(doc), before);
    expect(doc.commands.undoDepth, 0);
    // The focus loss alone: typed, then a tap outside.
    await tester.tap(thickness);
    await tester.pump();
    await tester.enterText(thickness, '260');
    await tester.pump();
    await tester.tap(wallSection);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(textOf(tester, thickness), '150');
    expect(canon(doc), before);
    // The justification toggle: refused alike, and it keeps showing C's.
    await choose(tester, 'justification', 'left');
    expect(tester.takeException(), isNull);
    expect(shownJustification(tester), {Justification.right});
    expect(doc.components.get<WallParams>(wc), pc);
    expect(canon(doc), before);
    expect(doc.commands.undoDepth, 0);

    // B, A's neighbour, likewise.
    await select(tester, view, [wb]);
    await tester.tap(thickness);
    await tester.pump();
    await enterAndSubmit(tester, thickness, '130');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(textOf(tester, thickness), '115', reason: 'reverted');
    expect(doc.components.get<WallParams>(wb), pb);
    expect(canon(doc), before);
    expect(doc.commands.undoDepth, 0);

    // The control: the box, outside the lock's reach, edits.
    await select(tester, view, [bx]);
    await tester.tap(width);
    await tester.pump();
    await enterAndSubmit(tester, width, '150');
    expect(doc.components.get<BoxParams>(bx), const BoxParams(150, 70));
    expect(doc.commands.undoDepth, 1);
  });

  // 1e100 is the probe's; 1e25 sits under a bound far too high (1e30) and
  // still collapses this ~1504 mm band.
  for (final typed in ['1e100', '1e25']) {
    testWidgets(
        'WS10 a tool-mode thickness above kWallMaxThickness ($typed) typed '
        'without Enter never reaches the settings: a diagonal click lands a '
        'wall at the kept 200, one step, no exception (post-11 (c))',
        (tester) async {
      final view = await pumpPanel(tester, panelPlanJson());
      final doc = view.document;
      await pressKey(tester, LogicalKeyboardKey.keyW);
      // Not ported (ruling IP-R2): final tool = view.tools.active as
      // WallTool;
      await tester.tap(thickness);
      await tester.pump();
      // One keystroke event carrying the whole text: `onChanged` sees it
      // alone, no prefix of it, so the settings keep the last valid value.
      await tester.enterText(thickness, typed);
      await tester.pump();
      final n0 = walls(doc).length;
      final seed0 = doc.handleSeed.current.value;
      // Off-axis (the plan is turned 23 degrees) and at the far origin: the
      // wall's local direction is not axis-aligned, which the typed value
      // needs to collapse its band.
      await clickWorld(tester, view, plan(400, 900));
      await clickWorld(tester, view, plan(1900, 800));
      // A throw out of the pointer handler would be reported here.
      expect(tester.takeException(), isNull);
      expect(walls(doc), hasLength(n0 + 1));
      final w = walls(doc).last;
      expect(doc.components.get<WallParams>(w)!.thickness, 200);
      expect(doc.commands.undoDepth, 1);
      // The seed moved by that wall's handles alone: its group and the
      // children generated under it, nothing a refused attempt consumed.
      expect([w, ...kids(doc, w)].map((h) => h.value).toSet(),
          {for (var v = seed0 + 1; v <= doc.handleSeed.current.value; v++) v});
      // Not ported (ruling IP-R2): expect(tool.settings.value.thickness,
      // 200);
      expect(textOf(tester, thickness), '200',
          reason: 'the focus loss reverts');
      expect(driftOf(doc), isEmpty);
    });
  }

  testWidgets(
      'WS11 a wall thickness one ulp above kWallMaxThickness is refused on a '
      'turned wall, by Enter and by focus loss: the field reverts and the '
      'document is byte-identical (post-11 (c))', (tester) async {
    final view = await pumpPanel(tester, panelPlanJson());
    final doc = view.document;
    final before = enc(doc);
    final over = nextUp(kWallMaxThickness);
    expect(double.parse('$over'), over);
    await select(tester, view, [wa]);
    await tester.tap(thickness);
    await tester.pump();
    await enterAndSubmit(tester, thickness, '$over');
    expect(tester.takeException(), isNull);
    expect(textOf(tester, thickness), '200');
    await tester.tap(thickness);
    await tester.pump();
    await tester.enterText(thickness, '$over');
    await tester.pump();
    await tester.tap(wallSection);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(textOf(tester, thickness), '200');
    expect(doc.commands.undoDepth, 0);
    expect(enc(doc), before);
  });

  testWidgets(
      'P-choice-focus-settings a value chosen in a tool\'s settings choice '
      'row (setting-justification) reaches the settings and hands the '
      'focus back to the canvas; its letters still work (2a "focus rules '
      'are today\'s"; M-P-choice-focus)', (tester) async {
    final view = await pumpPanel(tester, panelPlanJson());
    await focusCanvas(tester);
    await pressKey(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
    final canvas = canvasFocus(tester);
    expect(FocusManager.instance.primaryFocus, same(canvas),
        reason: 'premise: the canvas has the focus');
    expect(menuOf(tester, 'justification').value, Justification.centre,
        reason: 'premise: centred');
    final depth = view.document.commands.undoDepth;

    await tester.tap(byKey('setting-justification'));
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, isNot(same(canvas)),
        reason: 'premise: the open menu has the focus');
    await tester.tap(byKey('setting-justification-left').last);
    await tester.pumpAndSettle();
    expect(menuOf(tester, 'justification').value, Justification.left);
    expect(view.document.commands.undoDepth, depth,
        reason: 'settings: no step');
    expect(FocusManager.instance.primaryFocus, same(canvas),
        reason: 'the choice hands the focus back');
    expect(await pressKey(tester, LogicalKeyboardKey.keyM), isTrue);
    expect(status(tester), 'Room', reason: "the canvas's letters");

    // The settings kept it: the next wall, two clicks after W, is left.
    await pressKey(tester, LogicalKeyboardKey.keyW);
    final before = walls(view.document);
    await clickWorld(tester, view, plan(400, 900));
    await clickWorld(tester, view, plan(1900, 800));
    final w = walls(view.document).where((h) => !before.contains(h)).single;
    expect(view.document.components.get<WallParams>(w)!.justification,
        Justification.left,
        reason: 'the settings have it');
  });
}
