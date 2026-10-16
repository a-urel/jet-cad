// Spec 3a C1.10 (Task 7), decision 6: a frozen object's live referents are
// locked with it. A frozen square references a healthy square (its
// cascade partner, as a frozen opening references its host wall): the
// partner can be neither edited nor deleted, up front or on commit, with
// PlanLocked's hint; a square nothing frozen references still edits and
// deletes. Two referrers, each with its own partner, are frozen by one
// probe, so every frozen object's partner is locked, not the first's alone. A frozen square whose own `references` throws is locked alone,
// and the edit that froze it is still refused, not thrown (FL-throw); a
// square frozen in service locks its partner as well (FL-service). Squares
// off the origin, turned.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/box_kit.dart';
import '../support/harness.dart' show controllerFor;
import '../support/service_plans.dart'
    show kDeg37, placeDef, turned, unitDefinition;

/// Two host squares, a poisoned square referencing each, and a third
/// square; both poisoned ones frozen by one refused move (their reach
/// throws, and one probe of the type finds both); the hint cleared.
({
  PlanController c,
  Handle host,
  Handle referrer,
  Handle host2,
  Handle referrer2,
  Handle other,
  String before
}) frozenReferrer() {
  final sw = Switches();
  final c = PlanController(kits: [boxKit(sw)]);
  addTearDown(c.dispose);
  final d = c.document;
  final host = addObject(
      d, nearSquare(2600.5, -900.25, 0.4), const SquareParams(side: 900));
  final referrer = addObject(
      d, atSquare, SquareParams(side: 1200, poisoned: true, partner: host));
  final other = addObject(
      d, nearSquare(-3100.75, 1800.5, -0.6), const SquareParams(side: 700));
  final host2 = addObject(
      d, nearSquare(-1800.25, -2700.5, 1.1), const SquareParams(side: 650));
  final referrer2 = addObject(d, nearSquare(3900.75, 2200.25, -0.9),
      SquareParams(side: 1000, poisoned: true, partner: host2));
  sw.failing.add('reach');
  expect(c.execute(TransformNodeCommand(referrer, nearSquare(100.5, 50.25, 0))),
      isFalse);
  expect(c.frozen, {referrer, referrer2},
      reason: 'fixture: both referrers are frozen');
  c.lockHint.value = false;
  return (
    c: c,
    host: host,
    referrer: referrer,
    host2: host2,
    referrer2: referrer2,
    other: other,
    before: canon(d)
  );
}

/// The select tool's delete of the group [h]: its leaves, then the group
/// (`select_tool.dart:787-792`, `_groupCascade`).
DraftCommand deleteOf(DraftDocument d, Handle h) => CompoundCommand([
      for (final k in kids(d, h)) RemoveEntityCommand(k),
      RemoveNodeCommand(h),
    ], label: 'Delete');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      "FL-edit a frozen square's partner cannot be edited: false, the "
      'hint, nothing changed; a square nothing frozen references edits', () {
    final s = frozenReferrer();
    final c = s.c;
    // M-FL-1: `FailureBoundary._freeze` locking the frozen objects alone.
    // M-FL-6: `_freeze` locking the first frozen object's referents alone.
    expect(c.locked.value, {s.referrer, s.host, s.referrer2, s.host2});
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            s.host, const SquareParams(side: 640.5))),
        isFalse);
    expect(c.lockHint.value, isTrue);
    c.lockHint.value = false;
    expect(
        c.execute(
            TransformNodeCommand(s.host, nearSquare(2900.5, -700.25, 0.1))),
        isFalse);
    expect(c.lockHint.value, isTrue);
    c.lockHint.value = false;
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            s.host2, const SquareParams(side: 580.25))),
        isFalse);
    expect(c.lockHint.value, isTrue);
    expect(canon(c.document), s.before);
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            s.other, const SquareParams(side: 640.5))),
        isTrue,
        reason: 'positive control');
  });

  test(
      "FL-delete a frozen square's partner cannot be deleted: the gates "
      'refuse it, and its delete command is refused as locked; a square '
      'nothing frozen references is deleted by the same command', () {
    final s = frozenReferrer();
    final c = s.c;
    final d = c.document;
    c.selection.replace([SelectionKey.root(s.host)]);
    // M-FL-1 again: the gates are open and the partner goes, leaving the
    // frozen square referencing a dead handle.
    expect(c.deleteSelection(), isFalse);
    expect(c.execute(deleteOf(d, s.host)), isFalse);
    expect(c.lockHint.value, isTrue);
    expect(canon(d), s.before);
    expect(d.tree[s.host], isNotNull);
    c.selection.replace([SelectionKey.root(s.host2)]);
    expect(c.deleteSelection(), isFalse);
    expect(c.execute(deleteOf(d, s.host2)), isFalse);
    expect(canon(d), s.before);
    expect(c.execute(deleteOf(d, s.other)), isTrue, reason: 'positive control');
    expect(d.tree[s.other], isNull);
  });

  test(
      "FL-throw a frozen square whose own references throws: the edit that "
      'froze it is refused, not thrown; the square frozen and locked alone; '
      'one diagnostic', () {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    final host = addObject(
        d, nearSquare(2600.5, -900.25, 0.4), const SquareParams(side: 900));
    final referrer = addObject(
        d, atSquare, SquareParams(side: 1200, poisoned: true, partner: host));
    sw.failing.addAll(['reach', 'references']);
    // M-FL-4: `_referencesOf` without its try/catch: the freeze throws, the
    // edit escapes `execute`, and nothing is locked.
    expect(
        c.execute(TransformNodeCommand(referrer, nearSquare(100.5, 50.25, 0))),
        isFalse);
    expect(c.frozen, {referrer});
    expect(c.locked.value, {referrer});
    expect(c.diagnostics.value, hasLength(1));
  });

  testWidgets(
      "FL-service a square frozen by the service copy's boundary locks its "
      'partner with it', (tester) async {
    final sw = Switches();
    final c = controllerFor(kits: [boxKit(sw), ringKit(sw)]);
    final d = c.document;
    final host = addObject(
        d, nearSquare(2600.5, -900.25, 0.4), const SquareParams(side: 900));
    final square = addObject(
        d, atSquare, SquareParams(side: 1200, poisoned: true, partner: host));
    final table = unitDefinition(d, key: 'box.table.square.four');
    final t = placeDef(
        d, table, turned(table, -2600.25, 1400.5, kDeg37, mirrored: true),
        label: '1');
    await tester.pump();
    c.setMode(PlanMode.service);
    final copy = c.activeDocument;
    sw.failing.add('reach');
    final at = (copy.tree[t]! as InstanceNode).transform;
    copy.commands.execute(TransformNodeCommand(
        t, Transform2.translation(750.5, -250.25).multiply(at)));
    expect(c.frozen, {square}, reason: 'premise: frozen in service');
    // M-FL-5: `_buildService` without `referencesOf: _referencesOf,`.
    expect(c.locked.value, {square, host});
    expect(
        () => copy.commands.execute(TransformNodeCommand(
            host,
            Transform2.translation(10.5, 0)
                .multiply((copy.tree[host]! as GroupNode).transform))),
        throwsA(isA<PlanLocked>()),
        reason: 'the partner locked in the copy');
    c.setMode(PlanMode.design);
  });
}
