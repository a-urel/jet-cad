// The arc/circle snap-centre tree, and every path that has to maintain it.
//
// An arc's indexed box bounds its drawn *sweep* and need not contain its own
// centre — a narrow arc's box is a sliver a full radius away from it — yet
// `snapInto` offers that centre as a `SnapKind.center` candidate. The index
// answers that by giving centres a `PackedRTree` of their own inside each
// `ContainerIndex`, rather than by widening every centre-including query
// (which is what the Plan 2 throughput gate measured at ~87% of a default
// snap's cost at 500,000 entities).
//
// A second structure is a second thing to keep current, and this branch's
// history says plainly where such bugs land: a review found that deleting
// `noteLeaf`'s one slack-maintenance line left all 545 tests green while
// producing real misses. So every maintenance path below is pinned by a test
// written to fail when *that specific line* is removed:
//
//   build / rebuildAll        -> 'a root-level arc centre outside its own box'
//   rebuildContainer          -> 'survives a container rebuild'
//   dirty overlay (put)       -> 'a moved arc offers its NEW centre'
//   markLeafDead              -> 'a moved arc stops offering its OLD centre'
//   markLeafAlive             -> 'remove-then-undo restores the centre'
//   slot reuse / revive check -> 'same box, different centre'
//   purge()                   -> 'survives purge'
//   instance descent margin   -> 'a centre outside its definition's bound'
//   noteLeaf's centre reach   -> 'an arc edited out of its definition's bound'
//
// Every test here uses a `center`-only mask, so nothing but a centre
// candidate can satisfy it and no assertion can pass on an endpoint or a
// quadrant point by accident.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// `center` and nothing else.
final SnapMask centreOnly = const SnapMask(0).with_(SnapKind.center);

Handle _add(
  DraftDocument doc, {
  required Handle owner,
  required EntityKind kind,
  required List<double> coords,
  List<double> scalars = const [],
  Handle? handle,
}) {
  final h = handle ?? doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: h,
      owner: owner,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    ),
  ));
  return h;
}

Handle _addArc(DraftDocument doc, Handle owner, double cx, double cy, double r,
        double start, double sweep) =>
    _add(doc,
        owner: owner,
        kind: EntityKind.arc,
        coords: [cx, cy],
        scalars: [r, start, sweep]);

Handle _addLine(DraftDocument doc, Handle owner, List<double> coords) =>
    _add(doc, owner: owner, kind: EntityKind.line, coords: coords);

Handle _addDefinition(DraftDocument doc, String name) {
  final handle = doc.handleSeed.next();
  doc.tree.addDefinition(Definition(
    handle: handle,
    name: name,
    basePoint: Vector2.zero(),
    children: const [],
  ));
  return handle;
}

Handle _addInstance(DraftDocument doc, Handle definition, Transform2 t) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: handle,
    parent: doc.rootHandle,
    transform: t,
    definition: definition,
    layer: ReservedHandles.layerZero,
  )));
  return handle;
}

/// A deliberately narrow arc: 0.2 radians of a radius-100 circle, so its box
/// (`[95.53, 9.98] .. [99.50, 29.55]` at the origin) sits ~96 units away from
/// the centre it offers as a snap candidate. This is the shape the whole
/// centre tree exists for; a fat arc would be indexed correctly by accident.
Handle _addNarrowArc(DraftDocument doc, Handle owner, double cx, double cy) =>
    _addArc(doc, owner, cx, cy, 100.0, 0.1, 0.2);

/// The box of [_addNarrowArc] never contains its centre, which is what makes
/// every assertion below meaningful. Checked once, here, rather than asserted
/// in prose.
void _expectCentreOutsideItsOwnBox(DraftDocument doc, Handle arc) {
  final slot = doc.entities.slotOf(arc)!;
  final record = doc.entities.read(slot);
  final payload = doc.geometry.peek(record.geomIndex);
  final box = entityBounds(
    kind: record.kind,
    payload: payload,
    measurer: doc.textMeasurer,
    textStyle: ReservedHandles.standardTextStyle,
  );
  final cx = payload.coords[0], cy = payload.coords[1];
  expect(cx >= box.minX && cx <= box.maxX && cy >= box.minY && cy <= box.maxY,
      isFalse,
      reason: 'fixture is not exercising anything: the arc centre ($cx, $cy) '
          'is inside its own indexed box $box, so a tight query would reach '
          'it with no centre tree at all');
}

void main() {
  test('a root-level arc centre outside its own box is snappable', () {
    final doc = DraftDocument.empty();
    final arc = _addNarrowArc(doc, doc.rootHandle, 0, 0);
    _expectCentreOutsideItsOwnBox(doc, arc);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(index.rootIndex.snapCentreCount, 1,
        reason: 'ContainerIndex.build must put one entry in the centre tree '
            'for the one arc this document holds');

    final out = SnapResult();
    index.snapInto(Vector2(0.2, 0.2), 1.0, centreOnly, out);
    expect(out.found, isTrue);
    expect(out.kind, SnapKind.center);
    expect(out.entity, arc);
    expect(out.point.x, closeTo(0, 1e-9));
    expect(out.point.y, closeTo(0, 1e-9));
  });

  test('a circle centre is snappable through the same tree', () {
    // Not redundant with the arc case: a circle's centre *is* inside its own
    // box, so it used to be reached by the ordinary leaf walk. Routing both
    // through one path is only safe if the circle still works.
    final doc = DraftDocument.empty();
    final circle = _add(doc,
        owner: doc.rootHandle,
        kind: EntityKind.circle,
        coords: [7, 3],
        scalars: [2.0]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    expect(index.rootIndex.snapCentreCount, 1);

    final out = SnapResult();
    index.snapInto(Vector2(7.1, 3.1), 1.0, centreOnly, out);
    expect(out.found, isTrue);
    expect(out.entity, circle);
    expect(out.point.x, closeTo(7, 1e-9));
    expect(out.point.y, closeTo(3, 1e-9));
  });

  test('a straight entity contributes no centre entry', () {
    final doc = DraftDocument.empty();
    _addLine(doc, doc.rootHandle, [0, 0, 10, 10]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    expect(index.rootIndex.snapCentreCount, 0);

    final out = SnapResult();
    index.snapInto(Vector2(5, 5), 1.0, centreOnly, out);
    expect(out.found, isFalse,
        reason: 'a line has no centre, and the centre walk must not invent '
            'one from its coordinates');
  });

  test('the arc centre survives a container rebuild', () {
    final doc = DraftDocument.empty();
    final arc = _addNarrowArc(doc, doc.rootHandle, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final rebuildsBefore = index.rebuildCount;

    // Past `rebuildThreshold` (a floor of 64), so `_reconcile` calls
    // `rebuildContainer` on the root and the arc's centre has to come back
    // from a freshly built tree rather than from the dirty overlay.
    for (var i = 0; i < 70; i++) {
      _addLine(doc, doc.rootHandle, [i * 1000.0, 5000, i * 1000.0 + 1, 5001]);
    }
    expect(index.rebuildCount, greaterThan(rebuildsBefore),
        reason: 'fixture did not actually trigger a rebuild');
    expect(index.rootIndex.dirty.contains(doc.entities.slotOf(arc)!), isFalse,
        reason: 'the arc must be back in the rebuilt tree and not on the '
            'dirty overlay, so the assertion below can only be satisfied by '
            'the freshly built centre tree');

    final out = SnapResult();
    index.snapInto(Vector2(0.2, 0.2), 1.0, centreOnly, out);
    expect(out.found, isTrue);
    expect(out.entity, arc);
  });

  test('the arc centre survives purge()', () {
    final doc = DraftDocument.empty();
    // Removed first so `purge()` genuinely compacts and renumbers slots,
    // which is what invalidates every slot-keyed structure including the
    // centre tree.
    final doomed = _addLine(doc, doc.rootHandle, [0, 0, 1, 1]);
    final arc = _addNarrowArc(doc, doc.rootHandle, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    doc.commands.execute(RemoveEntityCommand(doomed));
    doc.purge();

    expect(index.rootIndex.snapCentreCount, 1);
    final out = SnapResult();
    index.snapInto(Vector2(0.2, 0.2), 1.0, centreOnly, out);
    expect(out.found, isTrue);
    expect(out.entity, arc);
  });

  group('a moved arc', () {
    // Remove-then-add-shifted, with a *new* handle, is how this package moves
    // an entity (there is no geometry-edit command). The freed slot is reused
    // for a box that does not match what was there before, which is what
    // defeats the revive shortcut in `_reconcileEntity` and forces a real
    // `DirtyList.put`.
    ({SpatialIndex index, Handle moved}) moveIt() {
      final doc = DraftDocument.empty();
      final arc = _addNarrowArc(doc, doc.rootHandle, 0, 0);
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);

      doc.commands.execute(RemoveEntityCommand(arc));
      final moved = _addNarrowArc(doc, doc.rootHandle, 400, 700);
      expect(index.rootIndex.dirty.length, 1,
          reason: 'fixture must produce exactly one dirty entry');
      return (index: index, moved: moved);
    }

    test('offers its NEW centre, carried on the dirty overlay', () {
      final fixture = moveIt();
      final out = SnapResult();
      fixture.index.snapInto(Vector2(400.2, 700.2), 1.0, centreOnly, out);
      expect(out.found, isTrue,
          reason: 'DirtyList.put must record the centre alongside the box; '
              'the tree still holds the old one');
      expect(out.entity, fixture.moved);
      expect(out.point.x, closeTo(400, 1e-9));
      expect(out.point.y, closeTo(700, 1e-9));
    });

    test('offers its NEW centre through the FUSED leaf-and-centre search', () {
      // The test above uses a `center`-only mask, which takes the unfused
      // `searchSnapCentres` path. Every real snap uses a mask with other
      // kinds in it too (`SnapMask.cheap` is the default), and that takes
      // `searchLeavesAndSnapCentres`, whose single pass over the dirty
      // overlay tests boxes and centres together. Without this the fused
      // pass's centre half was dead code no test executed: deleting it left
      // the whole suite green.
      //
      // The radius is small enough that no endpoint, midpoint or quadrant of
      // the arc is anywhere near -- they are all a full radius away, out on
      // the rim -- so `center` is the only kind that can answer, even though
      // `endpoint` and `midpoint` outrank it.
      final fixture = moveIt();
      final out = SnapResult();
      fixture.index.snapInto(Vector2(400.2, 700.2), 1.0, SnapMask.cheap, out);
      expect(out.found, isTrue);
      expect(out.kind, SnapKind.center);
      expect(out.entity, fixture.moved);
    });

    test('stops offering its OLD centre', () {
      final fixture = moveIt();
      final out = SnapResult();
      fixture.index.snapInto(Vector2(0.2, 0.2), 1.0, centreOnly, out);
      expect(out.found, isFalse,
          reason: 'markLeafDead must kill the centre tree entry as well as '
              'the leaf entry, or the arc keeps offering the centre it had '
              'before it moved -- a stale hit, not a missed one');
    });
  });

  test('remove-then-undo restores the arc centre', () {
    final doc = DraftDocument.empty();
    final arc = _addNarrowArc(doc, doc.rootHandle, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    doc.commands.execute(RemoveEntityCommand(arc));
    final gone = SnapResult();
    index.snapInto(Vector2(0.2, 0.2), 1.0, centreOnly, gone);
    expect(gone.found, isFalse, reason: 'removal must bury the centre too');

    doc.commands.undo();
    final back = SnapResult();
    index.snapInto(Vector2(0.2, 0.2), 1.0, centreOnly, back);
    expect(back.found, isTrue,
        reason: 'markLeafAlive must revive the centre entry along with the '
            'leaf entry');
    expect(back.entity, arc);
  });

  test(
      'a slot reused by an arc with the SAME box but a different centre '
      'reports the new centre, not the old', () {
    // Two arcs whose indexed boxes are bit-identical while their centres are
    // not: the second is the first rotated a half turn about the box centre,
    // built from sin(1)/cos(1) so that every coordinate involved is exactly
    // representable and the two boxes come out equal to the last bit (which
    // `_sameBox` requires -- it is a stored-value comparison, not a
    // tolerance).
    //
    // This is the one case a box comparison alone cannot see. Without the
    // centre term in `_reconcileEntity`'s revive check, the dead tree entry
    // is brought back to life carrying the *old* centre and no dirty entry
    // is written, so the arc offers a centre it no longer has.
    const sin1 = 0.8414709848078965;
    final doc = DraftDocument.empty();
    final first = _addArc(doc, doc.rootHandle, 0, 0, 1.0, 0.0, 1.0);
    final firstSlot = doc.entities.slotOf(first)!;
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final firstBox = index.rootIndex.boxOfLeaf(firstSlot)!;

    doc.commands.execute(RemoveEntityCommand(first));
    final second = _addArc(doc, doc.rootHandle, 0, sin1, 1.0, -1.0, 1.0);
    final secondSlot = doc.entities.slotOf(second)!;

    // The two premises this test rests on, checked rather than asserted in
    // prose: the freed slot really is reused, and the two boxes really are
    // bit-identical.
    expect(secondSlot, firstSlot,
        reason: 'fixture must reuse the freed slot, or the revive path is '
            'never reached');
    final secondRecord = doc.entities.read(secondSlot);
    final secondBox = entityBounds(
      kind: secondRecord.kind,
      payload: doc.geometry.peek(secondRecord.geomIndex),
      measurer: doc.textMeasurer,
      textStyle: ReservedHandles.standardTextStyle,
    );
    expect([secondBox.minX, secondBox.minY, secondBox.maxX, secondBox.maxY],
        [firstBox.minX, firstBox.minY, firstBox.maxX, firstBox.maxY],
        reason: 'fixture must produce a bit-identical box, or `_sameBox` '
            'rejects it on the box alone and the centre term is never the '
            'thing under test');

    final atNew = SnapResult();
    index.snapInto(Vector2(0.0, sin1), 0.05, centreOnly, atNew);
    expect(atNew.found, isTrue,
        reason: 'the arc now in this slot has its centre at (0, sin 1)');
    expect(atNew.entity, second);

    final atOld = SnapResult();
    index.snapInto(Vector2(0, 0), 0.05, centreOnly, atOld);
    expect(atOld.found, isFalse,
        reason: 'nothing has a centre at the origin any more; reviving the '
            'dead entry on a box match alone would leave the old centre '
            'indexed');
  });

  group('through an instance', () {
    test("a centre outside its definition's own bound is still reached", () {
      final doc = DraftDocument.empty();
      final def = _addDefinition(doc, 'NarrowArc');
      // The definition holds nothing but the narrow arc, so its bound *is*
      // the arc's sliver of a box and the centre lies ~96 units outside it.
      // The instance box a parent indexes is that bound transformed, and it
      // may not be grown to swallow the centre -- `forEachInstanceInRect`
      // reports against it. So the instance search, and only the instance
      // search, is widened.
      final arc = _addNarrowArc(doc, def, 0, 0);
      _addInstance(doc, def, Transform2.translation(1000, 2000));

      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      expect(index.indexFor(def)!.ownSnapCentreReach, greaterThan(90.0),
          reason: 'the definition must report how far its centre escapes its '
              'own bound, or the parent has nothing to widen by');

      final out = SnapResult();
      index.snapInto(Vector2(1000, 2000), 1.0, centreOnly, out);
      expect(out.found, isTrue,
          reason: 'a tight instance query never overlaps the instance box, '
              'so without the centre-descent margin the walk never enters '
              'the definition at all');
      expect(out.entity, arc);
      expect(out.chainLength, 1);
    });

    test('an arc edited out of its definition\'s bound is still reached', () {
      final doc = DraftDocument.empty();
      final def = _addDefinition(doc, 'Mixed');
      // A long line fixes the definition's bound at +/-500, so the arc's
      // centre starts comfortably inside it and the built-in reach is zero.
      _addLine(doc, def, [-500, -500, 500, 500]);
      final arc = _addArc(doc, def, 0, 0, 10.0, 0.1, 0.2);
      _addInstance(doc, def, Transform2.translation(10000, 10000));

      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      expect(index.indexFor(def)!.ownSnapCentreReach, 0.0,
          reason: 'the fixture must start with nothing to compensate for, so '
              'the assertion below can only pass if the *edit* updated it');

      // Replace it with an arc whose *drawn sliver* still sits well inside
      // the definition's bound while its centre is 4500 units outside it: a
      // 0.02-radian sweep of a radius-5000 circle centred at (-5000, 0)
      // draws from (0, 0) to about (-1, 100).
      //
      // The escaping centre, and not an escaping box, is the whole point.
      // A leaf whose *box* leaves the bound grows the bound, and with it
      // every instance box that places this definition (see
      // `SpatialIndex._growPlacements`), so the parent would reach the new
      // centre for a reason that has nothing to do with the centre reach.
      // Here the bound does not move at all, and reaching the centre depends
      // entirely on `noteLeaf` having folded it into that reach.
      doc.commands.execute(RemoveEntityCommand(arc));
      final moved = _addArc(doc, def, -5000, 0, 5000.0, 0, 0.02);
      expect(index.indexFor(def)!.bounds.minX, -500.0,
          reason: "the replacement's box must stay inside the bound, or this "
              'tests instance-box growth instead of the centre reach');
      expect(index.indexFor(def)!.ownSnapCentreReach, greaterThan(4000.0),
          reason: 'noteLeaf must fold the reconciled leaf centre into the '
              "container's own reach");

      final out = SnapResult();
      index.snapInto(Vector2(5000, 10000), 5.0, centreOnly, out);
      expect(out.found, isTrue);
      expect(out.entity, moved);
    });
  });

  test('a pick never pays for the centre margin', () {
    // The centre-descent margin is charged to `snapInto` and only when the
    // mask can produce a centre candidate. A pick has no centre candidate at
    // all, so widening its instance search for one would be pure waste --
    // and the fixture above shows the margin is not small.
    final doc = DraftDocument.empty();
    final def = _addDefinition(doc, 'NarrowArc');
    _addNarrowArc(doc, def, 0, 0);
    _addInstance(doc, def, Transform2.translation(1000, 2000));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(
        index.pickInto(Vector2(1000, 2000), 1.0, const QueryFilter.all(), hit),
        isFalse,
        reason: 'there is no geometry at the arc centre -- an arc is drawn on '
            'its rim, and its centre is not part of it');

    // ... and the rim still picks, so the fixture is reachable at all.
    expect(
        index.pickInto(
            Vector2(1000 + 100 * math.cos(0.2), 2000 + 100 * math.sin(0.2)),
            1.0,
            const QueryFilter.all(),
            hit),
        isTrue);
  });

  test('snapInto ignores geometry on a hidden layer by default', () {
    final doc = DraftDocument.empty();
    final hiddenLayer = doc.handleSeed.next();
    doc.tables.layers.add(LayerRecord(
      handle: hiddenLayer,
      name: 'HIDDEN',
      color: const IndexedColor(7),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
      visible: false,
    ));
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: handle,
        owner: doc.rootHandle,
        kind: EntityKind.circle,
        layer: hiddenLayer,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: kByLayer,
        transparency: kByLayer,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList([0, 0]),
        scalars: Float64List.fromList([5.0]),
      ),
    ));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final byDefault = SnapResult();
    index.snapInto(Vector2(0.1, 0.1), 1.0, SnapMask.all, byDefault);
    expect(byDefault.found, isFalse,
        reason: 'snapping the cursor onto something the user cannot see is a '
            'bug; snapInto defaults to QueryFilter.rendering() for that '
            'reason, matching what pickInto already did');

    final unfiltered = SnapResult();
    index.snapInto(Vector2(0.1, 0.1), 1.0, SnapMask.all, unfiltered,
        filter: const QueryFilter.all());
    expect(unfiltered.found, isTrue,
        reason: 'the filter is a parameter, not a hard-coded policy');
    expect(unfiltered.entity, handle);
  });

  test('SnapResult reports a truncated chain, keeping the innermost hops', () {
    // Two instance boundaries deep, into a SnapResult whose chain holds one.
    final doc = DraftDocument.empty();
    final inner = _addDefinition(doc, 'Inner');
    _add(doc,
        owner: inner, kind: EntityKind.circle, coords: [0, 0], scalars: [1.0]);
    final outer = _addDefinition(doc, 'Outer');
    final innerInstance = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: innerInstance,
      parent: outer,
      transform: Transform2.translation(10, 0),
      definition: inner,
      layer: ReservedHandles.layerZero,
    )));
    final outerInstance =
        _addInstance(doc, outer, Transform2.translation(0, 5));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final roomy = SnapResult(8);
    index.snapInto(Vector2(10, 5), 0.5, centreOnly, roomy);
    expect(roomy.found, isTrue);
    expect(roomy.truncated, isFalse);
    expect(roomy.chainLength, 2);
    expect(roomy.chain[0], outerInstance.value);
    expect(roomy.chain[1], innerInstance.value);

    final cramped = SnapResult(1);
    index.snapInto(Vector2(10, 5), 0.5, centreOnly, cramped);
    expect(cramped.found, isTrue);
    expect(cramped.truncated, isTrue,
        reason: 'a chain cut short must say so; without the flag, "short "'
            'because the path is short" and "short because it was cut" are '
            'the same observation');
    expect(cramped.chainLength, 1);
    expect(cramped.chain[0], innerInstance.value,
        reason: 'truncation drops from the ROOT end, keeping the hops '
            'nearest the leaf -- that is what keeps SnapResult.entity and '
            'its immediate parent consistent with each other');
  });
}
