// Spec 2a P2 ("The widgets"), P3 (properties, colour), P4 (locks), Review
// Focus 3 and 4: PlanPropertyPanel over the box and disc kits, in the
// design composition (the keyboard, the palette, the canvas, the panel on
// the right) under the drawing fixture's rotated, zoomed camera. The boxes
// sit off the origin; box values are away from their defaults.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/panel_kits.dart';
import '../support/canvas_fixture.dart';
import '../support/design_harness.dart';
import '../support/test_kit.dart' show addObject;
import '../support/throwing_kit.dart';

Finder byKey(String k) => find.byKey(Key(k));

String textOf(WidgetTester tester, String key) =>
    tester.widget<TextField>(byKey(key)).controller!.text;

bool readOnly(WidgetTester tester, String key) =>
    tester.widget<TextField>(byKey(key)).readOnly;

Future<void> select(
    WidgetTester tester, PlanController c, List<Handle> hs) async {
  c.selection.replace([for (final h in hs) SelectionKey.root(h)]);
  await tester.pump();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key).last);
  await tester.tap(byKey(key).last);
  await tester.pumpAndSettle();
}

Future<void> enterAndSubmit(
    WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await tester.pump();
  await tester.enterText(byKey(key), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

Future<PlanController> panel(WidgetTester tester, PlanController c) async {
  await pumpDesign(tester, c, right: PlanPropertyPanel(controller: c));
  return c;
}

void main() {
  testWidgets(
      'P-1 every kind shows the stored value (an angle in degrees, an area '
      'in m²) and each edit is one step storing exactly its value (M-P-1a, '
      'M-P-1b, M-P-1c)', (tester) async {
    final c = boxController();
    final b = addBox(c, Vector2(7010, 3020),
        const BoxParams(120, 70, turn: math.pi / 6, count: 3, label: 'Shelf'),
        turn: 0.61);
    await panel(tester, c);
    await select(tester, c, [b]);
    BoxParams p() => c.document.components.get<BoxParams>(b)!;
    final depth = c.document.commands.undoDepth;
    expect(textOf(tester, 'property-width'), '120');
    expect(textOf(tester, 'property-turn'), '30');
    expect(textOf(tester, 'property-count'), '3');
    expect(textOf(tester, 'property-label'), 'Shelf');
    expect(tester.widget<Text>(byKey('property-area')).data, '0.0084 m²');

    await enterAndSubmit(tester, 'property-turn', '45');
    // M-P-1a: degrees stored as typed.
    expect(p().turn, 45 * math.pi / 180);
    await tapKey(tester, 'property-solid');
    expect(p().solid, isTrue);
    await enterAndSubmit(tester, 'property-count', '2.26');
    expect(p().count, 2.3, reason: 'one decimal (Task 3 rounds)');
    await enterAndSubmit(tester, 'property-label', 'Desk');
    expect(p().label, 'Desk');
    await tapKey(tester, 'property-finish');
    await tapKey(tester, 'property-finish-gloss');
    expect(p().finish, BoxFinish.gloss);
    expect(
        find.descendant(
            of: byKey('property-finish'), matching: find.text('Gloss')),
        findsOneWidget);
    await tapKey(tester, 'property-swap');
    expect([p().width, p().height], [70, 120]);
    // M-P-1b: the unchanged-text check dropped makes an Enter on the shown
    // text a second step.
    await enterAndSubmit(tester, 'property-label', 'Desk');
    expect(c.document.commands.undoDepth, depth + 6);
    // M-P-1c: a value the spec refuses (Task 3: over maxLength) reverts.
    await enterAndSubmit(tester, 'property-label', 'A label of 13');
    expect(textOf(tester, 'property-label'), 'Desk');
    expect(c.document.commands.undoDepth, depth + 6);
  });

  testWidgets(
      'P-2 a field\'s gate: reshape off makes Width and Height read-only and '
      'refuses their commit; ungated fields stay editable (M-P-2)',
      (tester) async {
    final c = boxController();
    final b = addBox(c, Vector2(7010, 3020), const BoxParams(120, 70));
    await panel(tester, c);
    c.permissions = PlanPermissions.full.copyWith(reshape: false);
    await tester.pump();
    await select(tester, c, [b]);
    expect(readOnly(tester, 'property-width'), isTrue);
    expect(readOnly(tester, 'property-height'), isTrue);
    expect(readOnly(tester, 'property-label'), isFalse);
    final depth = c.document.commands.undoDepth;
    await enterAndSubmit(tester, 'property-width', '150');
    expect(c.document.components.get<BoxParams>(b)!.width, 120);
    expect(c.document.commands.undoDepth, depth);
  });

  testWidgets(
      'P-3 a field the spec\'s enabled rule refuses is read-only until the '
      'rule holds (M-P-3)', (tester) async {
    final c = boxController();
    final b = addBox(c, Vector2(7010, 3020), const BoxParams(120, 70));
    await panel(tester, c);
    await select(tester, c, [b]);
    expect(readOnly(tester, 'property-count'), isTrue);
    await tapKey(tester, 'property-solid');
    expect(readOnly(tester, 'property-count'), isFalse);
  });

  testWidgets(
      'P-4 the section is titled by the type\'s title hook: Box, then Solid '
      'box once solid; Kutu in Turkish (M-P-4)', (tester) async {
    final c = boxController();
    final b = addBox(c, Vector2(7010, 3020), const BoxParams(120, 70));
    await panel(tester, c);
    await select(tester, c, [b]);
    Text title() => tester.widget<Text>(byKey('section-box.box'));
    expect(title().data, 'Box');
    await tapKey(tester, 'property-solid');
    expect(title().data, 'Solid box');
    c.reportLocale(const Locale('tr'));
    await tapKey(tester, 'property-solid');
    expect(title().data, 'Kutu');
  });

  testWidgets(
      'P-5 an armed tool with settings shows them; a typed radius reaches the '
      'settings at once, no undo step, and the next click\'s disc has it '
      '(M-P-5a, M-P-5b)', (tester) async {
    final c = boxController(kits: [boxKit, discKit]);
    await panel(tester, c);
    await focusCanvas(tester);
    await press(tester, LogicalKeyboardKey.keyD);
    expect(byKey('settings-disc.draw'), findsOneWidget);
    expect(textOf(tester, 'setting-radius'), '400');
    final depth = c.document.commands.undoDepth;
    await tester.tap(byKey('setting-radius'));
    await tester.pump();
    await tester.enterText(byKey('setting-radius'), '250');
    await tester.pump();
    expect(c.document.commands.undoDepth, depth, reason: 'settings: no step');
    // At once: the field still has the focus, and nothing has committed it.
    expect(c.toolSettings.valueOf('disc.draw'),
        const DiscToolSettings(radius: 250));
    // No Enter: the click places with what the keystrokes stored.
    await tester.tapAt(globalOf(tester, c, 7150, 3110));
    await tester.pump();
    final discs = c.document.components.withComponent<DiscParams>().toList();
    expect(discs, hasLength(1));
    expect(c.document.components.get<DiscParams>(discs.single)!.radius, 250);
    expect(c.document.commands.undoDepth, depth + 1);
  });

  testWidgets(
      'P-6 a locked object shows no section and no colour row (spec P4) '
      '(M-P-6a, M-P-6b)', (tester) async {
    final c = boxController();
    final b = addBox(c, Vector2(7010, 3020), const BoxParams(120, 70));
    await panel(tester, c);
    await select(tester, c, [b]);
    expect(byKey('section-box.box'), findsOneWidget);
    expect(byKey('color-picker'), findsOneWidget);
    c.lockBroken({b});
    await select(tester, c, []);
    await select(tester, c, [b]);
    expect(byKey('section-box.box'), findsNothing);
    expect(byKey('color-picker'), findsNothing);
  });

  testWidgets(
      'P-lock-recolour (Task 10 carry) a recolour of a locked object is '
      'refused: beside a free box the row recolours the free one only, in '
      'one step, and a recolour of the locked one through the controller '
      'answers false and shows the lock hint (M-P-6b)', (tester) async {
    final c = boxController();
    final locked =
        addBox(c, Vector2(7010, 3020), const BoxParams(120, 70), turn: 0.61);
    final free = addBox(c, Vector2(7400, 3120), const BoxParams(90, 60));
    await panel(tester, c);
    c.lockBroken({locked});
    await select(tester, c, [locked, free]);
    expect(byKey('color-picker'), findsOneWidget, reason: 'premise: free');
    final depth = c.document.commands.undoDepth;
    await tapKey(tester, 'color-swatch-teal');
    expect(c.document.components.get<BoxParams>(free)!.colour, 'teal');
    expect(c.document.components.get<BoxParams>(locked)!.colour, isNull);
    expect(c.document.commands.undoDepth, depth + 1);
    final command = boxType.recolour(c.document, locked, 'purple');
    expect(command, isNotNull, reason: 'premise: a change to refuse');
    expect(c.execute(command!), isFalse);
    expect(c.lockHint.value, isTrue);
    expect(c.document.components.get<BoxParams>(locked)!.colour, isNull);
    expect(c.document.commands.undoDepth, depth + 1);
  });

  testWidgets(
      'P-7 the escape hatch: its commit is one step; a builder that throws is '
      'contained and the fields stay (M-P-7)', (tester) async {
    final c = boxController(kits: [boxKit, discKit]);
    final d = addDisc(c, Vector2(7300, 3150), const DiscParams(300));
    final big = addDisc(c, Vector2(7600, 3150), const DiscParams(6000));
    await panel(tester, c);
    await select(tester, c, [d]);
    final depth = c.document.commands.undoDepth;
    await tapKey(tester, 'disc-grow');
    expect(c.document.components.get<DiscParams>(d)!.radius, 600);
    expect(c.document.commands.undoDepth, depth + 1);
    await select(tester, c, [big]);
    expect(tester.takeException(), isNull);
    expect(textOf(tester, 'property-radius'), '6000');
    expect(byKey('disc-grow'), findsNothing);
  });

  testWidgets(
      'P-two-types (Review Focus 3) two kits\' types of different component '
      'types: each edits through its fields, and one tap recolours both in '
      'one step, with no runtime type error (M-P-two)', (tester) async {
    final c = boxController(kits: [boxKit, discKit]);
    final b =
        addBox(c, Vector2(7010, 3020), const BoxParams(120, 70), turn: 0.61);
    final d = addDisc(c, Vector2(7300, 3150), const DiscParams(300));
    await panel(tester, c);
    await select(tester, c, [b]);
    await enterAndSubmit(tester, 'property-width', '150');
    expect(c.document.components.get<BoxParams>(b)!.width, 150);
    await select(tester, c, [d]);
    await enterAndSubmit(tester, 'property-radius', '350');
    expect(c.document.components.get<DiscParams>(d)!.radius, 350);
    await select(tester, c, [b, d]);
    final depth = c.document.commands.undoDepth;
    await tapKey(tester, 'color-swatch-teal');
    expect(c.document.components.get<BoxParams>(b)!.colour, 'teal');
    expect(c.document.components.get<DiscParams>(d)!.colour, 'teal');
    expect(c.document.commands.undoDepth, depth + 1);
    expect(tester.takeException(), isNull);
    expect([
      for (final x in c.diagnostics.value)
        if (x.code == KitDiagnosticCode.hookFailed) x
    ], isEmpty);
  });

  testWidgets(
      'P-swap-pending (Review Focus 4) load while a field holds a typed, '
      'uncommitted value: no exception; the value settles into the old plan '
      'and never into the new one (M-P-swap)', (tester) async {
    final other = boxController();
    final twin = addBox(other, Vector2(7010, 3020), const BoxParams(120, 70));
    final json = other.save();
    final c = boxController();
    final b = addBox(c, Vector2(7010, 3020), const BoxParams(120, 70));
    expect(twin, b, reason: 'premise: the same handle in both plans');
    await panel(tester, c);
    await select(tester, c, [b]);
    await tester.tap(byKey('property-width'));
    await tester.pump();
    await tester.enterText(byKey('property-width'), '150');
    await tester.pump();
    final old = c.document;
    c.load(json);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(identical(c.document, old), isFalse, reason: 'premise: swapped');
    expect(old.components.get<BoxParams>(b)!.width, 150,
        reason: 'settled into the plan it was typed for');
    expect(c.document.components.get<BoxParams>(b)!.width, 120);
    // A later focus loss writes nothing into the new plan.
    await select(tester, c, [b]);
    await tester.tap(byKey('section-box.box'));
    await tester.pump();
    expect(c.document.components.get<BoxParams>(b)!.width, 120);
    expect(c.document.commands.canUndo, isFalse);
  });

  // ---- Fix round 1 (controller ruling): the kit hooks the panel calls
  // while it builds or acts are called at the contract's boundary (spec
  // P4). The throwing kit's boom.block beside a box of the box kit.

  ({PlanController c, ThrowingKit boom, Handle block, Handle box}) boomPlan() {
    final boom = ThrowingKit();
    final c = boxController(kits: [boxKit, boom.kit]);
    final block = addObject<BlockComponent>(
        c.document, const BlockComponent(size: 400, swatch: 'purple'),
        at: Vector2(7500, 3200));
    final box =
        addBox(c, Vector2(7010, 3020), const BoxParams(120, 70), turn: 0.61);
    return (c: c, boom: boom, block: block, box: box);
  }

  /// The boom kit's hookFailed diagnostics, each as its failing hook.
  List<String> boomFailures(PlanController c) => [
        for (final d in c.diagnostics.value)
          if (d.kitId == 'boom' && d.code == KitDiagnosticCode.hookFailed)
            '${d.subject}: ${(d.error! as BoomFailure).hook}',
      ];

  bool swatchMarked(WidgetTester tester, String name) =>
      tester
          .widget<Semantics>(find
              .ancestor(
                  of: byKey('color-swatch-$name'),
                  matching: find.byWidgetPredicate(
                      (w) => w is Semantics && w.properties.label != null))
              .first)
          .properties
          .selected ??
      false;

  testWidgets(
      'P-G1 a spec read that throws while the section builds replaces the '
      'section with the "section failed" box, one diagnostic; a document '
      'change reloads nothing into it; the rest of the panel edits '
      '(M-P-G1)', (tester) async {
    final p = boomPlan();
    final c = p.c;
    await panel(tester, c);
    p.boom.failing.add('read');
    await select(tester, c, [p.block]);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(byKey('kit-section-failed'), findsOneWidget);
    expect(byKey('section-boom.block'), findsNothing);
    expect(byKey('property-size'), findsNothing);
    expect(boomFailures(c), ['boom.block: read']);
    // A document change while the block is selected: the panel's listener
    // binds the fields again, at the boundary.
    c.document.commands.execute(SetComponentCommand<BoxParams>(p.box,
        c.document.components.get<BoxParams>(p.box)!.withColour('teal')));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(boomFailures(c), ['boom.block: read']);
    // The rest of the panel stays usable.
    await select(tester, c, [p.box]);
    await enterAndSubmit(tester, 'property-width', '150');
    expect(c.document.components.get<BoxParams>(p.box)!.width, 150);
    // The hook heals: the block's section is back.
    p.boom.failing.clear();
    await select(tester, c, [p.block]);
    expect(byKey('kit-section-failed'), findsNothing);
    expect(textOf(tester, 'property-size'), '400');
  });

  testWidgets(
      'P-G2 a title hook that throws replaces the section with the box, one '
      'diagnostic; the box\'s section still shows (M-P-G2)', (tester) async {
    final p = boomPlan();
    final c = p.c;
    await panel(tester, c);
    p.boom.failing.add('title');
    await select(tester, c, [p.block]);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(byKey('kit-section-failed'), findsOneWidget);
    expect(byKey('section-boom.block'), findsNothing);
    expect(byKey('property-size'), findsNothing);
    expect(boomFailures(c), ['boom.block: title']);
    await select(tester, c, [p.box]);
    expect(tester.widget<Text>(byKey('section-box.box')).data, 'Box');
    expect(byKey('kit-section-failed'), findsNothing);
  });

  testWidgets(
      'P-G3 (read) a colour read that throws marks nothing for that object, '
      'one diagnostic; the row stays and recolours (M-P-G3r)', (tester) async {
    final p = boomPlan();
    final c = p.c;
    await panel(tester, c);
    await select(tester, c, [p.block]);
    expect(swatchMarked(tester, 'purple'), isTrue,
        reason: 'premise: the block is purple');
    p.boom.failing.add('colourRead');
    await select(tester, c, []);
    await select(tester, c, [p.block]);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(byKey('color-picker'), findsOneWidget);
    expect(swatchMarked(tester, 'purple'), isFalse);
    expect(boomFailures(c), ['boom.block: colourRead']);
    final depth = c.document.commands.undoDepth;
    await tapKey(tester, 'color-swatch-teal');
    expect(c.document.components.get<BlockComponent>(p.block)!.swatch, 'teal');
    expect(c.document.commands.undoDepth, depth + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'P-G3 (write) a colour write that throws refuses the whole recolour: '
      'nothing changes, no step, one diagnostic; the row then recolours '
      'the box alone (M-P-G3w)', (tester) async {
    final p = boomPlan();
    final c = p.c;
    await panel(tester, c);
    p.boom.failing.add('colourWrite');
    await select(tester, c, [p.box, p.block]);
    final depth = c.document.commands.undoDepth;
    await tapKey(tester, 'color-swatch-teal');
    expect(tester.takeException(), isNull);
    expect(c.document.components.get<BoxParams>(p.box)!.colour, isNull);
    expect(
        c.document.components.get<BlockComponent>(p.block)!.swatch, 'purple');
    expect(c.document.commands.undoDepth, depth);
    expect(boomFailures(c), ['boom.block: colourWrite']);
    await select(tester, c, [p.box]);
    await tapKey(tester, 'color-swatch-teal');
    expect(c.document.components.get<BoxParams>(p.box)!.colour, 'teal');
    expect(c.document.commands.undoDepth, depth + 1);
  });
}
