// Spec 2a P2 "Events": the plan's changes, domain-neutral. Re-expressed
// from jet_cad_floor_plan's design_changes_test.dart (DC8, DC9, DC11, DC12,
// DC13, DC17, DC18, DC19) for objects instead of tables.
import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';

List<PlanChange> listen(PlanController c) {
  final seen = <PlanChange>[];
  c.changes.listen(seen.add);
  return seen;
}

void main() {
  testWidgets(
      'C-ch1 an object added, changed, removed and undone, in ascending '
      'order, once per step; a line is an object; a page change and a layer '
      'are none', (tester) async {
    final c = controllerFor(kits: [testKit()]);
    final seen = listen(c);
    final slab = addObject<SlabComponent>(
        c.document, SlabComponent(width: 1800, height: 900, angle: 0.4),
        at: Vector2(2350, -1180));
    await tester.pump();
    // M-C-ch1a: a generated leaf reported as an object of its own.
    expect(seen, [PlanObjectAdded(slab)]);
    seen.clear();

    final line = addLine(c.document, Vector2(-500, 700), Vector2(1800, 2400));
    setSlabWidth(c, slab, 2400);
    final page =
        c.document.components.get<PageComponent>(c.document.rootHandle)!;
    c.document.commands.execute(SetComponentCommand<PageComponent>(
        c.document.rootHandle,
        page.copyWith(decimalSeparator: DecimalSeparator.comma)));
    c.reportLocale(const Locale('tr'));
    await tester.pump();
    // M-C-ch1b: reported in arrival order (the line first).
    expect(seen, [PlanObjectChanged(slab), PlanObjectAdded(line)]);
    seen.clear();

    c.selection.replace([SelectionKey.root(slab)]);
    expect(c.deleteSelection(), isTrue);
    await tester.pump();
    expect(seen, [PlanObjectRemoved(slab)]);
    c.undo();
    await tester.pump();
    expect(seen, [PlanObjectRemoved(slab), PlanObjectAdded(slab)]);
  });

  testWidgets(
      'C-ch2 newPlan is exactly [PlanReplaced()], no Removed per '
      'object; a load the same (DC8)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final seen = listen(c);
    // M-C-ch2: no PlanReplaced at a swap.
    c.newPlan();
    await tester.pump();
    expect(seen, [const PlanReplaced()]);
    expect(slabsOf(c.document), isEmpty, reason: 'premise: an empty plan');
    c.load(slabPlanText());
    await tester.pump();
    expect(seen, [const PlanReplaced(), const PlanReplaced()]);
  });

  testWidgets(
      "C-ch3 an edit then a load in one synchronous step: the edit's change, "
      'then PlanReplaced, then an edit of the loaded plan (DC9)',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final seen = listen(c);
    final first = slabsOf(c.document).first;
    setSlabWidth(c, first, 2100);
    // M-C-ch3: a swap drops the old plan's owed changes.
    c.load(slabPlanText());
    final again = slabsOf(c.document).last;
    setSlabWidth(c, again, 900);
    expect(seen, isEmpty, reason: 'delivered asynchronously');
    await tester.pump();
    expect(seen, [
      PlanObjectChanged(first),
      const PlanReplaced(),
      PlanObjectChanged(again),
    ]);
  });

  testWidgets(
      'C-ch4 nothing is read with no listener, nor after the last cancel; one '
      'read per listen and per moved plan; two edits of one synchronous step '
      'are one read and one report (DC11)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final slab = slabsOf(c.document).first;
    setSlabWidth(c, slab, 2100);
    c.undo();
    c.redo();
    await tester.pump();
    c.load(slabPlanText());
    c.newPlan();
    c.load(slabPlanText());
    await tester.pump();
    // M-C-ch4a: the baseline built whether or not anything listens.
    expect(c.debugChangeScans, 0, reason: 'no listener: nothing read');

    final first = <PlanChange>[];
    final a = c.changes.listen(first.add);
    expect(c.debugChangeScans, 1, reason: 'the baseline');
    final second = <PlanChange>[];
    final b = c.changes.listen(second.add);
    expect(c.debugChangeScans, 1, reason: 'one baseline for every listener');

    final s1 = slabsOf(c.document).first;
    // M-C-ch4b: each mutation reported at once, not per step.
    setSlabWidth(c, s1, 2200);
    setSlabWidth(c, s1, 2300);
    await tester.pump();
    expect(c.debugChangeScans, 2, reason: 'two edits of one step: one read');
    expect(first, [PlanObjectChanged(s1)]);
    expect(second, [PlanObjectChanged(s1)]);

    unawaited(a.cancel());
    setSlabWidth(c, s1, 2400);
    await tester.pump();
    expect(c.debugChangeScans, 3, reason: 'one listener left');
    expect(second, [PlanObjectChanged(s1), PlanObjectChanged(s1)]);
    expect(first, [PlanObjectChanged(s1)]);

    unawaited(b.cancel());
    final scans = c.debugChangeScans;
    setSlabWidth(c, s1, 2500);
    c.undo();
    await tester.pump();
    c.load(slabPlanText());
    c.newPlan();
    await tester.pump();
    expect(c.debugChangeScans, scans, reason: 'after the last cancel: nothing');
  });

  testWidgets(
      'C-ch5 dispose closes the stream: an edit made just before it is not '
      'reported; nor an edit and a load (DC12, DC18)', (tester) async {
    final c = PlanController(kits: [testKit()], json: slabPlanText());
    final seen = <PlanChange>[];
    var done = false;
    c.changes.listen(seen.add, onDone: () => done = true);
    setSlabWidth(c, slabsOf(c.document).first, 2100);
    c.dispose();
    await tester.pump();
    expect(seen, isEmpty);
    expect(done, isTrue);

    final d = PlanController(kits: [testKit()], json: slabPlanText());
    final seenD = <PlanChange>[];
    var doneD = false;
    d.changes.listen(seenD.add, onDone: () => doneD = true);
    setSlabWidth(d, slabsOf(d.document).first, 2100);
    d.load(slabPlanText());
    // M-C-ch5: the stream not filtered once disposed.
    d.dispose();
    await tester.pump();
    expect(seenD, isEmpty);
    expect(doneD, isTrue);
  });

  testWidgets(
      'C-ch6 a failed load reports nothing and drops nothing owed (DC17)',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final seen = listen(c);
    final slab = slabsOf(c.document).first;
    setSlabWidth(c, slab, 2100);
    // M-C-ch6: load lets the tracker go before it decodes.
    expect(() => c.load('not json'), throwsFormatException);
    expect(() => c.load('{"x": 1}'), throwsFormatException);
    await tester.pump();
    expect(seen, [PlanObjectChanged(slab)]);
    expect(() => c.load('not json'), throwsFormatException);
    await tester.pump();
    expect(seen, [PlanObjectChanged(slab)], reason: 'nothing owed');
    setSlabWidth(c, slab, 2200);
    await tester.pump();
    expect(seen, [PlanObjectChanged(slab), PlanObjectChanged(slab)],
        reason: 'the same plan, the same baseline');
  });

  testWidgets(
      'C-ch7 a listener that disposes the controller on the first change of '
      'a report hears no second one, and then done (DC19)', (tester) async {
    final c = PlanController(kits: [testKit()], json: slabPlanText());
    final seen = <PlanChange>[];
    var done = false;
    c.changes.listen((change) {
      seen.add(change);
      c.dispose();
    }, onDone: () => done = true);
    final [a, b] = slabsOf(c.document);
    setSlabWidth(c, a, 2100);
    setSlabWidth(c, b, 900);
    await tester.pump();
    expect(seen, hasLength(1), reason: 'the report had two changes');
    expect(seen.single, isA<PlanObjectChanged>());
    expect(done, isTrue);
  });

  test('C-ch8 the four changes: ==, hashCode and toString (DC13)', () {
    final h = Handle.checked(0x2A);
    // M-C-ch8: == by kind alone.
    expect(PlanObjectAdded(h), PlanObjectAdded(Handle.checked(0x2A)));
    expect(PlanObjectAdded(h), isNot(PlanObjectAdded(Handle.checked(0x2B))));
    expect(PlanObjectAdded(h), isNot(PlanObjectRemoved(h)));
    expect(PlanObjectChanged(h).hashCode,
        PlanObjectChanged(Handle.checked(0x2A)).hashCode);
    expect(const PlanReplaced(), const PlanReplaced());
    expect('${PlanObjectRemoved(h)}', 'PlanObjectRemoved(2A)');
  });
}
