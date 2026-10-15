// Spec 08 D16: the Selection panel's Opening section. Every wall is at the
// far origin in its own rotated group, the plan is turned 23 degrees, the
// camera is rotated, no opening is central, and the door's own group is off
// the identity.
// Ported (spec 3a C6, C7); over architectureController in PlanEditor.
// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/opening_support.dart';

/// The panel's fixture.
typedef Plan = ({
  Handle a,
  Handle c,
  Handle door,
  Handle gap,
  Handle window,
  Handle e,
  Handle box,
});

/// A 1:20 page near the far origin, grid snap on at 10 mm, no history:
///
/// - wall A (6,000, 200, centred) with a door at 1,730 (900, hinge end,
///   swing right, in its own rotated group), a gap at 3,000 (800) and a
///   window at 4,100 (1,200);
/// - wall C (about 3,026, 150, right) with a door E at 1,100 (800);
/// - a box in its own rotated group.
(PlanController, Plan) panelPlan(
    {void Function(DraftDocument d, Plan p)? after}) {
  late Handle a, c, door, gap, window, e, box;
  Plan p() => (
        a: a,
        c: c,
        door: door,
        gap: gap,
        window: window,
        e: e,
        box: box,
      );
  final text = openingPlanText(shellPage, (doc) {
    Handle next() => doc.handleSeed.next();
    a = next();
    doc.commands.execute(
        addWall(doc, a, plan(0, 0), plan(6000, 0), 200, Justification.centre));
    door = next();
    doc.commands.execute(addOpening(
        doc,
        door,
        OpeningParams(a, 1730, 900, OpeningKind.door,
            hinge: HingeEnd.end, swing: SwingSide.right),
        at: doorGroup));
    gap = next();
    doc.commands.execute(
        addOpening(doc, gap, OpeningParams(a, 3000, 800, OpeningKind.gap)));
    window = next();
    doc.commands.execute(addOpening(
        doc, window, OpeningParams(a, 4100, 1200, OpeningKind.window)));
    c = next();
    doc.commands.execute(addWall(
        doc, c, plan(500, 2500), plan(3500, 2900), 150, Justification.right));
    e = next();
    doc.commands.execute(
        addOpening(doc, e, OpeningParams(c, 1100, 800, OpeningKind.door)));
    box = next();
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: box,
          parent: doc.rootHandle,
          transform: groupAt(box.value),
          children: const [])),
      SetComponentCommand<BoxParams>(box, const BoxParams(120, 70)),
    ], label: 'Add box'));
  }, after: after == null ? null : (d) => after(d, p()));
  return (openingController(text), p());
}

/// A tap on the section's title: outside every field.
Future<void> blur(WidgetTester tester) async {
  await tester.tap(section);
  await tester.pump();
}

void main() {
  testWidgets(
      'OS1 the section shows for one opening and hides for none, two, a '
      'wall and a box; width and position commit one step each; invalid '
      'values revert; the flips are a door\'s, one step each, and take the '
      'focus as the justification toggle does', (tester) async {
    final (c, p) = panelPlan();
    final doc = c.document;
    await pumpEditor(tester, c, centre: plan(3000, 1400), scale: 0.15);
    expect(section, findsNothing, reason: 'none');
    await select(tester, c, [p.door]);
    expect(section, findsOneWidget);
    expect(tester.widget<Text>(section).data, 'Door');
    expect([textOf(tester, width), textOf(tester, position)], ['900', '1730']);
    expect(flipHinge, findsOneWidget);
    expect(flipSwing, findsOneWidget);
    await select(tester, c, [p.door, p.window]);
    expect(section, findsNothing, reason: 'two');
    await select(tester, c, [p.a]);
    expect(section, findsNothing, reason: 'a wall');
    expect(find.byKey(const Key('section-architecture.wall')), findsOneWidget);
    await select(tester, c, [p.box]);
    expect(section, findsNothing, reason: 'a box');
    expect(find.byKey(const Key('section-architecture.box')), findsOneWidget);
    for (final (h, title, w, u) in [
      (p.window, 'Window', '1200', '4100'),
      (p.gap, 'Gap', '800', '3000'),
    ]) {
      await select(tester, c, [h]);
      expect(tester.widget<Text>(section).data, title);
      expect([textOf(tester, width), textOf(tester, position)], [w, u]);
      expect(flipHinge, findsNothing, reason: 'a door\'s only');
      expect(flipSwing, findsNothing, reason: 'a door\'s only');
    }

    // A width and a position: one step each, exactly.
    final d0 = paramsOf(doc, p.door);
    await select(tester, c, [p.door]);
    await enterAndSubmit(tester, width, '850');
    expect(doc.commands.undoDepth, 1);
    expect(paramsOf(doc, p.door), d0.copyWith(width: 850));
    await enterAndSubmit(tester, position, '1812.5');
    expect(doc.commands.undoDepth, 2);
    expect(paramsOf(doc, p.door), d0.copyWith(width: 850, position: 1812.5));
    expect(driftOf(doc), isEmpty);
    // Both ends of the range, inclusive: stored as typed, drawn clamped.
    final wall = doc.components.get<WallParams>(p.a)!;
    final l = (wall.end - wall.start).length;
    for (final end in [0.0, l]) {
      await enterAndSubmit(tester, position, '$end');
      expect(paramsOf(doc, p.door).position, end, reason: 'position $end');
      expect(doc.commands.undoDepth, 3);
      doc.commands.undo();
      await tester.pump();
      expect(textOf(tester, position), '1812.5');
    }

    // Invalid values revert and commit nothing.
    final d1 = paramsOf(doc, p.door);
    for (final bad in [
      '0',
      '-40',
      '0.000001', // wallJoin.linear itself
      'abc',
      '',
      'Infinity',
      'NaN',
    ]) {
      await enterAndSubmit(tester, width, bad);
      expect(textOf(tester, width), '850', reason: 'width $bad');
    }
    for (final bad in ['-0.5', '6001', 'abc', '', 'Infinity', 'NaN']) {
      await enterAndSubmit(tester, position, bad);
      expect(textOf(tester, position), '1812.5', reason: 'position $bad');
    }
    expect(paramsOf(doc, p.door), d1);
    expect(doc.commands.undoDepth, 2);
    // A gap's width must exceed 4 × wallJoin.linear (D6, D10's inset).
    final g0 = paramsOf(doc, p.gap);
    await select(tester, c, [p.gap]);
    for (final bad in ['0.000003', '0.000004', '0.000002']) {
      await enterAndSubmit(tester, width, bad);
      expect(textOf(tester, width), '800', reason: 'gap width $bad');
    }
    expect(paramsOf(doc, p.gap), g0);
    expect(doc.commands.undoDepth, 2);

    // The flips: a door's, one step each.
    await select(tester, c, [p.door]);
    await tester.tap(flipHinge);
    await tester.pump();
    expect(doc.commands.undoDepth, 3);
    expect(paramsOf(doc, p.door), d1.copyWith(hinge: HingeEnd.start));
    await tester.tap(flipSwing);
    await tester.pump();
    expect(doc.commands.undoDepth, 4);
    expect(paramsOf(doc, p.door),
        d1.copyWith(hinge: HingeEnd.start, swing: SwingSide.left));
    expect(driftOf(doc), isEmpty);

    // Typed with no Enter, then a flip: the width commits on the focus
    // loss, the flip is its own step, and the canvas has the letters back,
    // as after the justification toggle.
    await tester.tap(width);
    await tester.pump();
    await tester.enterText(width, '870');
    await tester.pump();
    await tester.tap(flipHinge);
    await tester.pump();
    expect(doc.commands.undoDepth, 6);
    expect(paramsOf(doc, p.door),
        d1.copyWith(width: 870, hinge: HingeEnd.end, swing: SwingSide.left));
    await press(tester, LogicalKeyboardKey.keyV);
    await press(tester, LogicalKeyboardKey.escape);
    expect(c.selection.keys, isEmpty, reason: 'Escape reached the canvas');
  });

  testWidgets(
      'OS1 under runtime the section is read-only and the flips are '
      'disabled; D, N and G typed in a field do not switch tools; Escape '
      'works after Enter', (tester) async {
    final (c, p) = panelPlan();
    final doc = c.document;
    await pumpEditor(tester, c, centre: plan(3000, 1400), scale: 0.15);
    final d0 = paramsOf(doc, p.door);
    doc.commands.permissions = DraftPermissions.runtime;
    await select(tester, c, [p.door]);
    expect(tester.widget<TextField>(width).readOnly, isTrue);
    expect(tester.widget<TextField>(position).readOnly, isTrue);
    expect(tester.widget<OutlinedButton>(flipHinge).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(flipSwing).onPressed, isNull);
    await tester.tap(flipHinge);
    await tester.pump();
    expect(paramsOf(doc, p.door), d0);
    expect(doc.commands.undoDepth, 0);
    // Components denied alone: still read-only (07 WS8).
    doc.commands.permissions = const DraftPermissions(
        transform: true, components: false, geometry: true, structure: true);
    await select(tester, c, [p.e]);
    await select(tester, c, [p.door]);
    expect(tester.widget<TextField>(width).readOnly, isTrue);
    expect(tester.widget<OutlinedButton>(flipSwing).onPressed, isNull);
    doc.commands.permissions = DraftPermissions.all;
    await select(tester, c, [p.e]);
    await select(tester, c, [p.door]);
    expect(tester.widget<TextField>(width).readOnly, isFalse);
    expect(tester.widget<OutlinedButton>(flipSwing).onPressed, isNotNull);

    // D, N and G in a field: no tool switch.
    for (final f in [width, position]) {
      await tester.tap(f);
      await tester.pump();
      for (final k in [
        LogicalKeyboardKey.keyD,
        LogicalKeyboardKey.keyN,
        LogicalKeyboardKey.keyG,
      ]) {
        await press(tester, k);
        expect(status(tester), startsWith('Select'), reason: '$k');
      }
    }
    // Enter hands the focus back to the canvas: Escape clears the
    // selection there.
    await enterAndSubmit(tester, position, '1740');
    expect(paramsOf(doc, p.door).position, 1740);
    await press(tester, LogicalKeyboardKey.escape);
    expect(c.selection.keys, isEmpty);
    expect(section, findsNothing);
  });

  testWidgets(
      'OS2 (M-08pin) the commit target is pinned at focus gain: select A, '
      'type in Width, select B without taking the focus, blur: A changes, '
      'B does not; the same for Position; a pinned opening that dies drops '
      'the text', (tester) async {
    final (c, p) = panelPlan();
    final doc = c.document;
    await pumpEditor(tester, c, centre: plan(3000, 1400), scale: 0.15);
    final a0 = paramsOf(doc, p.door), b0 = paramsOf(doc, p.e);
    for (final (field, text, want, shown) in [
      (width, '870', a0.copyWith(width: 870), '800'),
      (position, '2000.25', a0.copyWith(width: 870, position: 2000.25), '1100'),
    ]) {
      await select(tester, c, [p.door]);
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, text);
      await tester.pump();
      await select(tester, c, [p.e]);
      expect(textOf(tester, field), text, reason: 'focused: not reloaded');
      await blur(tester);
      expect(paramsOf(doc, p.door), want);
      expect(paramsOf(doc, p.e), b0);
      expect(textOf(tester, field), shown, reason: 'now B\'s');
    }
    expect(doc.commands.undoDepth, 2);

    // Enter after the selection change: A still, once.
    await select(tester, c, [p.door]);
    await tester.tap(width);
    await tester.pump();
    await tester.enterText(width, '880');
    await select(tester, c, [p.e]);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(paramsOf(doc, p.door).width, 880);
    expect(paramsOf(doc, p.e), b0);
    expect(doc.commands.undoDepth, 3);

    // The pinned opening dies while B is shown: the text is dropped.
    await select(tester, c, [p.window]);
    await tester.tap(width);
    await tester.pump();
    await tester.enterText(width, '1000');
    await select(tester, c, [p.e]);
    doc.commands.execute(deleteLikeSelectTool(doc, p.window));
    await tester.pump();
    expect(doc.tree[p.window], isNull);
    await blur(tester);
    expect(paramsOf(doc, p.e), b0);
    expect(doc.commands.undoDepth, 4, reason: 'the delete alone');
  });

  testWidgets(
      'OS3 tool mode: with D active the Width field edits the Door tool\'s '
      'settings keystroke by keystroke, even with an opening selected; a '
      'canvas click without Enter places a door with the typed width; N and '
      'G have their own settings', (tester) async {
    final (c, p) = panelPlan();
    final doc = c.document;
    await pumpEditor(tester, c, centre: plan(3000, 1400), scale: 0.15);
    await press(tester, LogicalKeyboardKey.keyD);
    expect(status(tester), 'Door');
    expect(
        tester.widget<Text>(toolSection(ArchitectureTools.door)).data, 'Door');
    expect(textOf(tester, settingWidth), '900');
    expect(position, findsNothing, reason: 'no position in tool mode');
    expect(flipHinge, findsNothing);
    // An opening selected under the tool: still the tool's settings.
    final w0 = paramsOf(doc, p.window);
    await select(tester, c, [p.window]);
    expect(
        tester.widget<Text>(toolSection(ArchitectureTools.door)).data, 'Door');
    expect(textOf(tester, settingWidth), '900');
    // Assertion changed by binding spec (2a P-panel, controller ruling on
    // Task 15's OS3): the 2a design-mode spec's `PlanPropertyPanel` row
    // (docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md:
    // 345) shows the active tool's settings and, below them, the one
    // selected object's section. Today's `expect(position, findsNothing)`
    // becomes: the tool's width row leads, the window's section follows.
    expect(settingWidth, findsOneWidget);
    expect(position, findsOneWidget);
    expect(tester.getTopLeft(position).dy,
        greaterThan(tester.getBottomLeft(settingWidth).dy),
        reason: 'the selected object\'s section is below the tool\'s settings');

    await tester.tap(settingWidth);
    await tester.pump();
    for (final (typed, want) in [
      ('7', 7.0),
      ('75', 75.0),
      ('750', 750.0),
      ('750.', 750.0),
      ('750.5', 750.5),
      ('', 750.5), // erased: the last valid value stays
      ('0', 750.5), // invalid: not written
      ('640', 640.0),
    ]) {
      await tester.enterText(settingWidth, typed);
      await tester.pump();
      expect(settingsText(c, ArchitectureTools.door), 'OpeningSettings($want)',
          reason: 'typed "$typed"');
    }
    expect(settingsText(c, ArchitectureTools.window), 'OpeningSettings(1200.0)',
        reason: 'N\'s untouched');
    expect(settingsText(c, ArchitectureTools.gap), 'OpeningSettings(900.0)',
        reason: 'G\'s untouched');
    expect(paramsOf(doc, p.window), w0, reason: 'the selection untouched');
    expect(doc.commands.undoDepth, 0, reason: 'settings are not the model');

    // A canvas click with no Enter: the door has the typed width.
    final before = openings(doc);
    final fc = oracleFrameOf(doc, p.c);
    await tester.enterText(settingWidth, '720');
    await tester.pump();
    await tapWorld(tester, c, oracleAt(fc, 2300, -75));
    final placed = openings(doc).where((h) => !before.contains(h)).toList();
    expect(placed, hasLength(1));
    final o = paramsOf(doc, placed.single);
    expect([o.kind, o.width, o.host], [OpeningKind.door, 720, p.c]);
    expect(status(tester), startsWith('Door'));

    // N and G: each tool's own settings.
    await press(tester, LogicalKeyboardKey.keyN);
    expect(tester.widget<Text>(toolSection(ArchitectureTools.window)).data,
        'Window');
    expect(textOf(tester, settingWidth), '1200');
    await tester.tap(settingWidth);
    await tester.pump();
    await tester.enterText(settingWidth, '1500');
    await tester.pump();
    expect(
        settingsText(c, ArchitectureTools.window), 'OpeningSettings(1500.0)');
    expect(settingsText(c, ArchitectureTools.door), 'OpeningSettings(720.0)');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyG);
    expect(tester.widget<Text>(toolSection(ArchitectureTools.gap)).data, 'Gap');
    expect(textOf(tester, settingWidth), '900');
    await tester.tap(settingWidth);
    await tester.pump();
    for (final (typed, want) in [
      ('0.000003', 900.0), // not above 4 × wallJoin.linear
      ('0.000005', 0.000005),
      ('650', 650.0),
    ]) {
      await tester.enterText(settingWidth, typed);
      await tester.pump();
      expect(settingsText(c, ArchitectureTools.gap), 'OpeningSettings($want)',
          reason: 'gap "$typed"');
    }
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyD);
    expect(textOf(tester, settingWidth), '720');
    // Back to Select: the section follows the selection again.
    await press(tester, LogicalKeyboardKey.keyV);
    expect(section, findsNothing);
    await select(tester, c, [p.window]);
    expect(textOf(tester, width), '1200');
    expect(textOf(tester, position), '4100');
  });

  testWidgets(
      'OS4 (X12-catch) a loaded opening whose host is missing: a width edit '
      'is refused with DanglingReferenceError and the field reverts to the '
      'model\'s value, by Enter and by the focus loss; the flips are '
      'refused alike; no exception escapes', (tester) async {
    // The host wall's node is removed with no parametric system installed,
    // so nothing cascades: the saved file holds a door naming a wall that
    // is no longer a live object.
    final (c, p) = panelPlan(
        after: (d, p) => d.commands.execute(deleteLikeSelectTool(d, p.c)));
    expect(c.document.tree[p.c], isNull);
    final doc = c.document;
    await pumpEditor(tester, c, centre: plan(3000, 1400), scale: 0.15);
    final e0 = paramsOf(doc, p.e);
    expect(e0.host, p.c);
    expect(
        () => doc.commands.execute(
            SetComponentCommand<OpeningParams>(p.e, e0.copyWith(width: 850))),
        throwsA(isA<DanglingReferenceError>()),
        reason: 'the document refuses it');
    final before = enc(doc);
    expect(doc.commands.undoDepth, 0);

    await select(tester, c, [p.e]);
    expect(textOf(tester, width), '800');
    await tester.tap(width);
    await tester.pump();
    await enterAndSubmit(tester, width, '850');
    expect(tester.takeException(), isNull);
    expect(textOf(tester, width), '800', reason: 'reverted');
    expect(enc(doc), before);
    // Re-pinned: the focus loss alone is refused alike.
    await tester.tap(width);
    await tester.pump();
    await tester.enterText(width, '860');
    await tester.pump();
    await blur(tester);
    expect(tester.takeException(), isNull);
    expect(textOf(tester, width), '800');
    // The position: the dead wall's component is still stored (only its
    // node went), so 500 is within its length and reaches the document,
    // which refuses it alike.
    await enterAndSubmit(tester, position, '500');
    expect(tester.takeException(), isNull);
    expect(textOf(tester, position), '1100');
    // The flips: refused, nothing changed.
    await tester.tap(flipHinge);
    await tester.pump();
    await tester.tap(flipSwing);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, 0);

    // A sound door edits as usual.
    await select(tester, c, [p.door]);
    await enterAndSubmit(tester, width, '850');
    expect(paramsOf(doc, p.door).width, 850);
    expect(doc.commands.undoDepth, 1);
  });

  testWidgets(
      'OT-panel-range (spec 3a C1.1, Review Focus 4) a position typed past '
      'the host wall\'s length, or below 0, shows the stored value and adds '
      'no history and no diagnostic; L itself commits; an opening a box '
      'hosts refuses every position alike', (tester) async {
    late Handle a, door, box, onBox;
    final c = openingController(openingPlanText(shellPage, (d) {
      Handle next() => d.handleSeed.next();
      a = next();
      d.commands.execute(
          addWall(d, a, plan(0, 0), plan(6000, 0), 200, Justification.centre));
      door = next();
      d.commands.execute(addOpening(
          d,
          door,
          OpeningParams(a, 1730, 900, OpeningKind.door,
              hinge: HingeEnd.end, swing: SwingSide.right),
          at: doorGroup));
      box = next();
      d.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: box,
            parent: d.rootHandle,
            transform: groupAt(box.value),
            children: const [])),
        SetComponentCommand<BoxParams>(box, const BoxParams(1200, 800)),
      ], label: 'Add box'));
      onBox = next();
      d.commands.execute(addOpening(
          d, onBox, OpeningParams(box, 300, 600, OpeningKind.window)));
    }));
    await pumpEditor(tester, c, centre: plan(3000, 1400), scale: 0.15);
    final doc = c.document;
    final wall = doc.components.get<WallParams>(a)!;
    final l = (wall.end - wall.start).length;
    expect(c.diagnostics.value, isEmpty, reason: 'premise');

    await select(tester, c, [door]);
    final d0 = paramsOf(doc, door);
    for (final bad in ['${nextUp(l)}', '6000.5', '-0.5']) {
      await enterAndSubmit(tester, position, bad);
      expect(textOf(tester, position), '1730', reason: bad);
    }
    expect(paramsOf(doc, door), d0);
    expect(doc.commands.undoDepth, 0);
    expect(c.diagnostics.value, isEmpty);
    await enterAndSubmit(tester, position, '$l');
    expect(paramsOf(doc, door).position, l, reason: 'L itself: inclusive');
    expect(doc.commands.undoDepth, 1);
    doc.commands.undo();
    await tester.pump();

    await select(tester, c, [onBox]);
    expect(section, findsOneWidget);
    final o0 = paramsOf(doc, onBox);
    for (final v in ['0', '10', '300.5', '1730']) {
      await enterAndSubmit(tester, position, v);
      expect(textOf(tester, position), '300', reason: 'a box host: $v');
    }
    expect(paramsOf(doc, onBox), o0);
    expect(doc.commands.undoDepth, 0);
    expect(c.diagnostics.value, isEmpty);
  });
}
