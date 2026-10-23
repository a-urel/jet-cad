// The alignment-guide reference cache (alignment guides spec, "The boxes"
// and "The reference cache"). Every fixture is off the origin, turned or
// mirrored, so a box that skipped the transform, or took the wrong corner,
// lands elsewhere.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show CatalogCircle, CatalogSymbol, CatalogUnit;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/guides/guide_references.dart';
import 'package:jet_cad_2d_plan/src/guides/guide_solver.dart';
import 'package:jet_cad_2d_plan/src/kits/locks.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show definitionForEntry;
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';
import '../support/unit_fixtures.dart';

/// [tableSymbol]'s outline plus its two chairs, in definition space.
const _tableBox = SymbolBox(left: 300, right: 1500, front: -50, back: 1450);

/// The AABB of [box]'s four corners through [t], computed point by point.
List<double> _aabb(SymbolBox box, Transform2 t) {
  final pts = [
    t.transformPoint(Vector2(box.left, box.front)),
    t.transformPoint(Vector2(box.right, box.front)),
    t.transformPoint(Vector2(box.right, box.back)),
    t.transformPoint(Vector2(box.left, box.back)),
  ];
  return [
    pts.map((p) => p.x).reduce(math.min),
    pts.map((p) => p.y).reduce(math.min),
    pts.map((p) => p.x).reduce(math.max),
    pts.map((p) => p.y).reduce(math.max),
  ];
}

List<double> _boxAt(GuideReferences r, Handle h) {
  final i = r.handles.indexOf(h);
  expect(i, isNonNegative, reason: '$h is a reference');
  return [for (var k = 0; k < 4; k++) r.boxes[4 * i + k]];
}

void _near(List<double> got, List<double> want) {
  expect(got.length, 4);
  for (var k = 0; k < 4; k++) {
    expect(got[k], closeTo(want[k], 1e-9), reason: 'component $k');
  }
}

({
  GuideReferenceCache cache,
  UnitIndexCache units,
  ValueNotifier<Set<Handle>> locked
}) _rig(DraftDocument doc, {ParametricCatalog? catalog}) {
  final locked = ValueNotifier<Set<Handle>>(const {});
  final units = UnitIndexCache(doc,
      catalog: catalog ?? ParametricCatalog(),
      locks: LockSet.scan(doc, (_) => true),
      locked: locked);
  addTearDown(() {
    units.dispose();
    locked.dispose();
  });
  return (
    cache: GuideReferenceCache(doc, units: () => units),
    units: units,
    locked: locked
  );
}

void main() {
  test('a table turned 30 degrees off the origin has the AABB of its corners',
      () {
    final doc = unitPlan();
    final t = placementAt(4000, -2500, 30 * math.pi / 180);
    final h = placeUnit(doc, tableSymbol(), transform: t);
    final refs = _rig(doc).cache.current;
    expect(refs.handles, [h]);
    _near(_boxAt(refs, h), _aabb(_tableBox, t));
  });

  test('a mirrored instance at a 90 degree turn keeps min below max', () {
    final doc = unitPlan();
    final t = placementAt(-3100, 1800, math.pi / 2, mirrored: true);
    final h = placeUnit(doc, tableSymbol(), transform: t);
    final box = _boxAt(_rig(doc).cache.current, h);
    expect(box[0], lessThan(box[2]));
    expect(box[1], lessThan(box[3]));
    _near(box, _aabb(_tableBox, t));
  });

  test('a UNIT label outside the outline does not widen the box', () {
    final doc = unitPlan();
    final t = placementAt(2200, 900, kDeg37);
    final h = placeUnit(doc, tableSymbol(), transform: t);
    final before = _boxAt(_rig(doc).cache.current, h);
    addUnitLabel(doc, h, 'LABEL-FAR-OUTSIDE');
    final after = _boxAt(_rig(doc).cache.current, h);
    _near(after, before);
    _near(after, _aabb(_tableBox, t));
  });

  test('worldBoxOf writes the corner AABB of a box through a transform', () {
    final t = placementAt(-700, 4100, 2.2, mirrored: true);
    final out = Float64List(4);
    worldBoxOf(_tableBox, t, out);
    _near(out.toList(), _aabb(_tableBox, t));
  });

  test(
      'a seat and a table on a hidden layer are no references; a bar counter '
      '(no unit) is, and honours its own layer', () {
    final doc = unitPlan();
    final hidden = addLayer(doc, 'Hidden', visible: false);
    final seat = placeUnit(
        doc,
        const CatalogSymbol(
          key: 'fx.seat.one',
          name: 'Seat',
          category: 'Tests',
          tags: ['seat'],
          unit: CatalogUnit(kind: UnitKinds.seat, capacity: 1),
          base: (100, 100),
          shapes: [CatalogCircle((100, 100), 100)],
        ),
        transform: placementAt(900, 900, 0.3, baseX: 100, baseY: 100));
    final table =
        placeUnit(doc, tableSymbol(), transform: placementAt(5000, 700, 0.4));
    final offTable = placeUnit(doc, tableSymbol(),
        transform: placementAt(-6000, 700, 0.4), layer: hidden);
    final barT = placementAt(-2000, 8000, 1.0, baseX: 250, baseY: 250);
    final bar = placeUnit(doc, planterSymbol, transform: barT);
    final offBar = placeUnit(doc, planterSymbol,
        transform: placementAt(-2000, 9000, 1.0, baseX: 250, baseY: 250),
        layer: hidden);
    final refs = _rig(doc).cache.current;
    expect(refs.handles, [table, bar]);
    expect(refs.handles, isNot(contains(seat)));
    expect(refs.handles, isNot(contains(offTable)));
    expect(refs.handles, isNot(contains(offBar)));
    expect(refs.length, 2);
    _near(_boxAt(refs, bar),
        _aabb(const SymbolBox(left: 0, right: 500, front: 0, back: 500), barT));
  });

  test('a hidden node is no reference, hidden root group included', () {
    final doc = unitPlan();
    final def = definitionForEntry(doc, entryOf(planterSymbol));
    doc.commands.execute(CompoundCommand(def.commands, label: 'Def'));
    Handle plant(Handle parent, double x, {bool visible = true}) {
      final h = doc.handleSeed.next();
      doc.commands.execute(AddNodeCommand(InstanceNode(
          handle: h,
          parent: parent,
          definition: def.definition,
          layer: ReservedHandles.layerZero,
          transform: placementAt(x, 300, 0.5, baseX: 250, baseY: 250),
          visible: visible)));
      return h;
    }

    final shown = plant(doc.rootHandle, 1000);
    plant(doc.rootHandle, 2000, visible: false);
    final refs = _rig(doc).cache.current;
    expect(refs.handles, [shown]);
  });

  /// A root group (the test kit's slab, turned and off the origin) holding
  /// one stool; [hidden] hides the group.
  ({
    DraftDocument doc,
    Handle group,
    Handle stool,
    Transform2 world,
    ParametricCatalog catalog
  }) groupPlan({bool hidden = false}) {
    final catalog = catalogOf([testKit()]);
    final doc = plan(catalog: catalog);
    final group = doc.handleSeed.next();
    final groupT = Transform2.translation(3100.5, -1700.25)
        .multiply(Transform2.rotation(0.4));
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: group,
          parent: doc.rootHandle,
          transform: groupT,
          visible: !hidden,
          children: const [])),
      SetComponentCommand<SlabComponent>(
          group, SlabComponent(width: 1800, height: 900, angle: 0.4)),
    ], label: 'Holder'));
    final made = definitionForEntry(doc, entryOf(stoolSymbol));
    doc.commands.execute(CompoundCommand(made.commands, label: 'Stool'));
    final stool = doc.handleSeed.next();
    final local = placementAt(120, -80, kDeg37, baseX: 400, baseY: 300);
    doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: stool,
        parent: group,
        transform: local,
        definition: made.definition,
        layer: ReservedHandles.layerZero)));
    return (
      doc: doc,
      group: group,
      stool: stool,
      world: groupT.multiply(local),
      catalog: catalog
    );
  }

  test('a generated unit gets its group\'s transform; a hidden group skips it',
      () {
    final g = groupPlan();
    addTearDown(g.doc.dispose);
    final refs = _rig(g.doc, catalog: g.catalog).cache.current;
    expect(refs.handles, [g.stool]);
    _near(
        _boxAt(refs, g.stool),
        _aabb(const SymbolBox(left: 210, right: 590, front: 110, back: 490),
            g.world));
    final h = groupPlan(hidden: true);
    addTearDown(h.doc.dispose);
    expect(_rig(h.doc, catalog: h.catalog).cache.current.length, 0);
  });

  test('locking an object gives a new current once the unit index rebuilds',
      () {
    final doc = unitPlan();
    final h =
        placeUnit(doc, tableSymbol(), transform: placementAt(900, 900, 1));
    final rig = _rig(doc);
    final first = rig.cache.current;
    rig.locked.value = {h};
    final second = rig.cache.current;
    expect(identical(second, first), isFalse);
    _near(_boxAt(second, h), _boxAt(first, h));
    expect(identical(rig.cache.current, second), isTrue);
  });

  test('current is identical across reads; a placement and its undo move it',
      () {
    final doc = unitPlan();
    placeUnit(doc, tableSymbol(), transform: placementAt(900, 900, 1));
    final cache = _rig(doc).cache;
    final first = cache.current;
    expect(identical(cache.current, first), isTrue);
    expect(first.length, 1);

    placeUnit(doc, tableSymbol(), transform: placementAt(-4000, 900, 2));
    final second = cache.current;
    expect(identical(second, first), isFalse);
    expect(second.length, 2);

    doc.commands.undo();
    final third = cache.current;
    expect(identical(third, second), isFalse);
    expect(third.length, 1);
    expect(third.handles, first.handles);
  });

  test('unionOf unions the boxes, ignores non-references, false when none', () {
    final doc = unitPlan();
    final ta = placementAt(4000, -2500, 0.52);
    final tb = placementAt(-3000, 3500, 1.9, mirrored: true);
    final a = placeUnit(doc, tableSymbol(), transform: ta);
    final b = placeUnit(doc, tableSymbol(), transform: tb);
    final hidden = addLayer(doc, 'Hidden', visible: false);
    final off = placeUnit(doc, tableSymbol(),
        transform: placementAt(900, 900, 1), layer: hidden);
    final leaf = doc.entities.handleAt(doc.entities.liveSlots.first);
    final cache = _rig(doc).cache;
    final ba = _aabb(_tableBox, ta), bb = _aabb(_tableBox, tb);
    final out = Float64List(4);
    expect(cache.unionOf([a, leaf, b], out), isTrue);
    _near(out.toList(), [
      math.min(ba[0], bb[0]),
      math.min(ba[1], bb[1]),
      math.max(ba[2], bb[2]),
      math.max(ba[3], bb[3]),
    ]);
    expect(cache.unionOf([a], out), isTrue);
    _near(out.toList(), ba);
    out.fillRange(0, 4, 7);
    expect(cache.unionOf([off, leaf], out), isFalse);
    expect(out.toList(), [7, 7, 7, 7], reason: 'out untouched on false');
  });
}
