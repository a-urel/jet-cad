// The before-edit view (spec 10 D16.1): the survey snapshots each live
// object's registered component and accumulated transform, and the root's
// page, so a view built over the survey taken before an edit reads the state
// as it was, although the edit has already applied. Nothing but the
// trigger reads the before-view (Ruling 10-3), so it is observed through the
// place boxes the trigger asks: Slab S records, per call, the view, and what
// the view answered for its parameters, its transform and the page. A Lens
// is live far away, so the trigger runs and nothing regenerates it.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

import 'support/clients.dart';
import 'support/fixture.dart';

const Handle hS = Handle(1000); // the Slab
const Handle hR = Handle(2000); // the Lens, far away

const Slab slab = Slab(20.25, 30.5, 800.5, 400.75);
const Slab slab2 = Slab(-60.75, 45.25, 1200.25, 350.5);
const Lens lens = Lens(100.5, 50.25, 2000.5, 1500.75);

/// S on A's frame, turned, off the origin; then moved, turned the other way.
final Transform2 atS = onA(500.5, 300.25, 0.3);
final Transform2 atS2 = onA(900.75, -200.5, -0.4);

final PageComponent page = PageComponent(scaleDenominator: 20.5);
final PageComponent page2 =
    PageComponent(scaleDenominator: 100, displayUnit: DisplayUnit.feetInches);

DraftCommand setPage(DraftDocument doc, PageComponent? p) =>
    SetComponentCommand<PageComponent>(doc.rootHandle, p);

/// The select tool's delete of one object: its children, then its node.
DraftCommand deleteObject(DraftDocument doc, Handle g) => CompoundCommand([
      for (final k in kids(doc, g)) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

/// Exact: a snapshot is the very value the survey read.
bool sameTransform(Transform2 a, Transform2 b) =>
    a.a == b.a &&
    a.b == b.b &&
    a.c == b.c &&
    a.d == b.d &&
    a.e == b.e &&
    a.f == b.f;

List<Handle> drift(DraftDocument doc) => ParametricSystem(doc, catalog).drift();

/// S at [atS] on [page], the Lens parked far away.
DraftDocument scene() {
  final doc = paramDoc();
  PageComponent.register(doc.components);
  doc.commands.execute(setPage(doc, page));
  doc.commands.execute(create(doc, hS, atS, slab));
  doc.commands.execute(create(doc, hR, parked, lens));
  return doc;
}

void main() {
  setUp(() {
    generateCalls.clear();
    Slab.placeCalls.clear();
  });

  test(
      'SV1 the before-view reads a moved object\'s transform as it '
      'was', () {
    final doc = scene();
    // Premises: the transform and the page change; S is off the origin and
    // turned before and after; the Lens is far from S both times.
    expect(sameTransform(atS, atS2), isFalse);
    expect(atS.isIdentity, isFalse);
    expect(page == page2, isFalse);
    final field = lensField(lens, parked);
    expect(slabBox(slab, atS).intersects(field), isFalse);
    expect(slabBox(slab, atS2).intersects(field), isFalse);
    final old = doc.tree.accumulatedTransform(hS);
    expect(sameTransform(old, atS), isTrue);

    Slab.placeCalls.clear();
    final lensCalls = generateCalls[hR] ?? 0;
    doc.commands.execute(CompoundCommand(
        [TransformNodeCommand(hS, atS2), setPage(doc, page2)],
        label: 'Move S, change the page'));
    final calls = Slab.placeCalls;
    expect(calls, hasLength(2), reason: 'one call per view');
    expect(identical(calls[0].view, calls[1].view), isFalse,
        reason: 'from two views');
    final was = calls.where((c) => sameTransform(c.toWorld, old)).toList();
    final now = calls.where((c) => sameTransform(c.toWorld, atS2)).toList();
    expect(was, hasLength(1), reason: 'one call saw the old transform');
    expect(now, hasLength(1), reason: 'one call saw the new transform');
    expect(was.single.page, page, reason: 'and the old page');
    expect(now.single.page, page2);
    expect(was.single.params, slab);
    expect(now.single.params, slab);
    expect(generateCalls[hR] ?? 0, lensCalls, reason: 'the Lens is far');
    expect(drift(doc), isEmpty);
  });

  test(
      'SV2 the before-view reads a re-parameterised object\'s '
      'parameters as they were', () {
    final doc = scene();
    expect(slab == slab2, isFalse);
    expect(slabBox(slab2, atS).intersects(lensField(lens, parked)), isFalse);

    Slab.placeCalls.clear();
    doc.commands.execute(CompoundCommand(
        [SetComponentCommand<Slab>(hS, slab2), setPage(doc, page2)],
        label: 'Resize S, change the page'));
    final calls = Slab.placeCalls;
    expect(calls, hasLength(2));
    expect(identical(calls[0].view, calls[1].view), isFalse);
    final was = calls.where((c) => c.params == slab).toList();
    final now = calls.where((c) => c.params == slab2).toList();
    expect(was, hasLength(1), reason: 'one call saw the old parameters');
    expect(now, hasLength(1));
    expect(was.single.page, page, reason: 'and the old page');
    expect(now.single.page, page2);
    for (final c in calls) {
      expect(sameTransform(c.toWorld, atS), isTrue);
    }
    expect(drift(doc), isEmpty);
  });

  test('SV3 the before-view reads a deleted object as it was', () {
    final doc = scene();
    final old = doc.tree.accumulatedTransform(hS);
    expect(old.isIdentity, isFalse);

    Slab.placeCalls.clear();
    doc.commands.execute(deleteObject(doc, hS));
    expect(doc.tree[hS], isNull);
    expect(doc.components.get<Slab>(hS), isNull);
    final calls = Slab.placeCalls;
    expect(calls, hasLength(1), reason: 'S is live before only');
    expect(calls.single.params, slab, reason: 'not null');
    expect(calls.single.toWorld.isIdentity, isFalse,
        reason: 'not the identity');
    expect(sameTransform(calls.single.toWorld, old), isTrue);
    expect(calls.single.page, page);
    expect(drift(doc), isEmpty);
  });
}
