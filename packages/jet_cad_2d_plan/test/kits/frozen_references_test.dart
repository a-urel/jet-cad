// Spec 3a C1.10 (Task 7), decision 6: a frozen object's live referents are
// locked with it. A frozen square references a healthy square (its
// cascade partner, as a frozen opening references its host wall): the
// partner can be neither edited nor deleted, up front or on commit, with
// PlanLocked's hint; a square nothing frozen references still edits and
// deletes. Squares off the origin, turned.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/box_kit.dart';

/// A host square, a poisoned square referencing it, and a third square;
/// the poisoned one frozen by one refused move (its reach throws); the
/// hint cleared.
({PlanController c, Handle host, Handle referrer, Handle other, String before})
    frozenReferrer() {
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
  sw.failing.add('reach');
  expect(c.execute(TransformNodeCommand(referrer, nearSquare(100.5, 50.25, 0))),
      isFalse);
  expect(c.frozen, {referrer}, reason: 'fixture: the referrer is frozen');
  c.lockHint.value = false;
  return (c: c, host: host, referrer: referrer, other: other, before: canon(d));
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
    expect(c.locked.value, {s.referrer, s.host});
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
    expect(c.execute(deleteOf(d, s.other)), isTrue, reason: 'positive control');
    expect(d.tree[s.other], isNull);
  });
}
