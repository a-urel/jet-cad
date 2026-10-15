// Spec 3a C1.1, C1.7, Review Focus 4 (the plan half): the property panel
// over the object-view kit. A text display reads the object (a child's
// text as drawn, the world turn) and omits its line when it reads nothing;
// a position's range comes from the host's component, a value outside it
// is refused with no command and no diagnostic, and a host that is no rail
// refuses every value; a hidden field takes no room; an action whose gate
// is refused is not shown; the section gets the object and the kit's
// services; and the new hooks are at the failure boundary.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/design_harness.dart';
import '../support/object_kit.dart';
import '../support/panel_kits.dart' show boxController, boxKit;
import '../support/test_kit.dart' show addObject;
import '../support/throwing_kit.dart';

Finder byKey(String k) => find.byKey(Key(k));

String textOf(WidgetTester tester, String key) =>
    tester.widget<TextField>(byKey(key)).controller!.text;

String shown(WidgetTester tester, String key) =>
    tester.widget<Text>(byKey(key)).data!;

Future<void> select(WidgetTester tester, PlanController c, Handle h) async {
  c.selection.replace([SelectionKey.root(h)]);
  await tester.pump();
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

List<KitDiagnostic> hookFailures(PlanController c) => [
      for (final d in c.diagnostics.value)
        if (d.code == KitDiagnosticCode.hookFailed) d
    ];

/// A 1:20 page (boxController's) with the box kit and the object kit; a
/// rail of 3200 labelled `R-7`, turned 0.7 rad at (7010, 3020), a bead on
/// it at 1250, a second rail unturned and unlabelled, and a bead whose
/// host is that bead (no rail).
({PlanController c, Handle rail, Handle bead, Handle flat, Handle stray})
    plan() {
  final c = boxController(kits: [boxKit, objectKit]);
  final d = c.document;
  final rail = addTurned(
      d, const RailComponent(3200, label: 'R-7'), Vector2(7010, 3020), 0.7);
  final bead =
      addTurned(d, BeadComponent(rail, 1250), Vector2(7400, 3300), -0.4);
  final flat = addTurned(d, const RailComponent(1800), Vector2(7600, 2900), 0);
  final stray =
      addTurned(d, BeadComponent(bead, 40), Vector2(7700, 3100), 0.25);
  d.commands.clearHistory();
  return (c: c, rail: rail, bead: bead, flat: flat, stray: stray);
}

Future<void> panel(WidgetTester tester, PlanController c) =>
    pumpDesign(tester, c, right: PlanPropertyPanel(controller: c));

void main() {
  testWidgets(
      'PO-panel-display a text display shows what it reads from the object: '
      'the TEXT child as drawn, the world turn; a rail without a label shows '
      '— and an unturned one has no Turn line (M-PO-null, M-PO-panel-row)',
      (tester) async {
    final p = plan();
    await panel(tester, p.c);
    await select(tester, p.c, p.rail);
    expect(shown(tester, 'property-drawn'), 'R-7');
    expect(shown(tester, 'property-turn'), '40.1°');
    // R-P4: the object's words are its own kit's (M-PO-panel-words).
    expect(shown(tester, 'property-named'), 'Rail');
    // Edited: the TEXT child regenerates and the line follows.
    await enterAndSubmit(tester, 'property-label', 'R-8');
    expect(shown(tester, 'property-drawn'), 'R-8');
    await select(tester, p.c, p.flat);
    expect(shown(tester, 'property-drawn'), '—');
    expect(byKey('property-turn'), findsNothing);
  });

  testWidgets(
      'PO-range (Review Focus 4) a position past the host\'s length is '
      'refused: the field shows the stored value, no command, no '
      'diagnostic; the ends themselves are allowed; a host that is no rail '
      'refuses every value (M-PO-range, M-PO-range-null)', (tester) async {
    final p = plan();
    final c = p.c;
    await panel(tester, c);
    await select(tester, c, p.bead);
    BeadComponent bead() => c.document.components.get<BeadComponent>(p.bead)!;
    final depth = c.document.commands.undoDepth;
    await enterAndSubmit(tester, 'property-position', '3200.5');
    expect(bead().position, 1250);
    expect(textOf(tester, 'property-position'), '1250');
    expect(c.document.commands.undoDepth, depth);
    expect(hookFailures(c), isEmpty);
    await enterAndSubmit(tester, 'property-position', '3200');
    expect(bead().position, 3200);
    await enterAndSubmit(tester, 'property-position', '0');
    expect(bead().position, 0);
    expect(c.document.commands.undoDepth, depth + 2);
    // The stray bead's host is a bead: every value is refused, 0 included.
    await select(tester, c, p.stray);
    final strayDepth = c.document.commands.undoDepth;
    for (final v in ['0', '40.5', '20']) {
      await enterAndSubmit(tester, 'property-position', v);
      expect(c.document.components.get<BeadComponent>(p.stray)!.position, 40,
          reason: v);
      expect(textOf(tester, 'property-position'), '40', reason: v);
    }
    expect(c.document.commands.undoDepth, strayDepth);
    expect(hookFailures(c), isEmpty);
  });

  testWidgets(
      'PO-hidden a field whose visible says no takes no row and no room: a '
      'door\'s Flip shows, a window\'s does not, and the Door row moves up '
      'by its height (M-PO-hidden)', (tester) async {
    final p = plan();
    final c = p.c;
    await panel(tester, c);
    await select(tester, c, p.bead);
    expect(byKey('property-flip'), findsOneWidget);
    // Measured from the row above (Position): the harness centres the
    // panel's column vertically, so a shorter panel moves every row down
    // by half the height it lost.
    double doorBelowPosition() =>
        tester.getTopLeft(byKey('property-door')).dy -
        tester.getTopLeft(byKey('property-position')).dy;
    final withFlip = doorBelowPosition();
    final flipHeight = tester.getSize(byKey('property-flip')).height;
    await tester.tap(byKey('property-door'));
    await tester.pumpAndSettle();
    expect(c.document.components.get<BeadComponent>(p.bead)!.door, isFalse,
        reason: 'premise: the bead is a window now');
    expect(byKey('property-flip'), findsNothing);
    expect(doorBelowPosition(), lessThanOrEqualTo(withFlip - flipHeight));
  });

  testWidgets(
      'PO-gate-hidden an action whose gate the permissions refuse is not '
      'shown (today\'s S-11), where a gated field is read-only '
      '(M-PO-gate-hidden)', (tester) async {
    final p = plan();
    final c = p.c;
    await panel(tester, c);
    c.permissions = PlanPermissions.full.copyWith(reshape: false);
    await tester.pump();
    await select(tester, c, p.bead);
    expect(c.document.components.get<BeadComponent>(p.bead)!.door, isTrue,
        reason: 'premise: visible says yes');
    expect(byKey('property-flip'), findsNothing);
    expect(byKey('property-door'), findsOneWidget);
    c.permissions = PlanPermissions.full;
    await tester.pump();
    expect(byKey('property-flip'), findsOneWidget);
    await tester.tap(byKey('property-flip'));
    await tester.pumpAndSettle();
    expect(c.document.components.get<BeadComponent>(p.bead)!.flipped, isTrue);
  });

  testWidgets(
      'PO-section the section is built over the object and its own kit\'s '
      'services (M-PO-services)', (tester) async {
    final p = plan();
    await panel(tester, p.c);
    await select(tester, p.c, p.rail);
    expect(shown(tester, 'view-rail-section'), 'Rail ${p.rail.value}');
  });

  group('the failure boundary (spec C2: the new hooks)', () {
    ({PlanController c, ThrowingKit boom, Handle block}) boomPlan() {
      final boom = ThrowingKit();
      final c = boxController(kits: [boxKit, boom.kit]);
      final block = addObject<BlockComponent>(
          c.document, const BlockComponent(size: 400, swatch: 'purple'),
          at: Vector2(7500, 3200));
      return (c: c, boom: boom, block: block);
    }

    List<String> boomFailures(PlanController c) => [
          for (final d in hookFailures(c))
            if (d.kitId == 'boom')
              '${d.subject}: ${(d.error! as BoomFailure).hook}',
        ];

    for (final hook in ['display', 'visible']) {
      testWidgets(
          'PO-G-$hook a $hook hook that throws while the section binds: the '
          '"section failed" box, one diagnostic, no exception (M-PO-G-$hook)',
          (tester) async {
        final b = boomPlan();
        await panel(tester, b.c);
        await select(tester, b.c, b.block);
        expect(shown(tester, 'property-shown'), '400 mm at ${b.block.value}',
            reason: 'premise: the display reads');
        b.boom.failing.add(hook);
        b.c.selection.replace(const []);
        await tester.pump();
        await select(tester, b.c, b.block);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(byKey('kit-section-failed'), findsOneWidget);
        expect(boomFailures(b.c), ['boom.block: $hook']);
      });
    }

    testWidgets(
        'PO-G-range a range that throws at the commit: one diagnostic, '
        'nothing stored, the section stays (M-PO-G-range)', (tester) async {
      final b = boomPlan();
      await panel(tester, b.c);
      await select(tester, b.c, b.block);
      b.boom.failing.add('range');
      await enterAndSubmit(tester, 'property-span', '640');
      expect(tester.takeException(), isNull);
      expect(b.c.document.components.get<BlockComponent>(b.block)!.size, 400);
      expect(textOf(tester, 'property-span'), '400');
      expect(byKey('kit-section-failed'), findsNothing);
      expect(boomFailures(b.c), ['boom.block: range']);
    });
  });
}
