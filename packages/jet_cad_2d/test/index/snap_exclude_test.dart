// 4a spec R2 O1 (the engine seam): snapInto's `exclude` takes the objects a
// drag moves out of every snap kind -- a leaf named itself, a leaf in an
// excluded group, a leaf reached through an excluded instance -- while every
// other candidate is still offered. Fixtures sit off the origin and the
// excluded object's midpoint is the nearest candidate to the probe, so an
// ignored exclusion is seen.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

Handle _line(DraftDocument doc, Handle owner, List<double> coords) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
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
        coords: Float64List.fromList(coords), scalars: Float64List(0)),
  ));
  return handle;
}

const SnapMask _mid = SnapMask(1 << 1);

SnapResult _snap(SpatialIndex i, Vector2 at, {Set<Handle>? exclude}) {
  final out = SnapResult();
  i.snapInto(at, 40, _mid, out, exclude: exclude);
  return out;
}

void main() {
  test('premise: the mask is the midpoint alone', () {
    expect(_mid.bits, SnapMask.none.with_(SnapKind.midpoint).bits);
  });

  test('a leaf named in exclude offers no candidate; the others still do', () {
    final doc = DraftDocument.empty();
    final a = _line(doc, doc.rootHandle, [4200.5, -2000.25, 4400.5, -2000.25]);
    final b = _line(doc, doc.rootHandle, [4210.5, -2015.25, 4410.5, -2015.25]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final probe = Vector2(4301, -2001);
    expect(_snap(index, probe).entity, a, reason: 'premise: a is nearest');
    // Mutation: ignore the exclusion in the leaf visitor.
    final out = _snap(index, probe, exclude: {a});
    expect(out.found, isTrue);
    expect(out.entity, b);
    expect(out.point.x, closeTo(4310.5, 1e-9));
    expect(out.point.y, closeTo(-2015.25, 1e-9));
    expect(_snap(index, probe, exclude: {a, b}).found, isFalse);
    expect(_snap(index, probe, exclude: <Handle>{}).entity, a,
        reason: 'empty excludes nothing');
    expect(_snap(index, probe).entity, a, reason: 'not held after the call');
  });

  test('an excluded group excludes its leaves, not its neighbours', () {
    final doc = DraftDocument.empty();
    final group = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.translation(100, -50),
        children: const [])));
    final inGroup = _line(doc, group, [4100.5, -1950.25, 4300.5, -1950.25]);
    final other =
        _line(doc, doc.rootHandle, [4210.5, -2015.25, 4410.5, -2015.25]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final probe = Vector2(4301, -2001);
    expect(_snap(index, probe).entity, inGroup, reason: 'premise');
    // Mutation: test only the leaf's own handle (no owner walk).
    expect(_snap(index, probe, exclude: {group}).entity, other);
  });

  test('an excluded instance excludes the leaves reached through it', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);
    doc.tree.addDefinition(Definition(
        handle: def, name: 'T', basePoint: Vector2.zero(), children: const []));
    _line(doc, def, [0, 0, 200, 0]);
    doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: Transform2.translation(4200.5, -2000.25),
        definition: def,
        layer: ReservedHandles.layerZero)));
    final other =
        _line(doc, doc.rootHandle, [4210.5, -2015.25, 4410.5, -2015.25]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final probe = Vector2(4301, -2001);
    expect(_snap(index, probe).entity, isNot(other),
        reason: 'premise: the instance wins');
    // Mutation: do not skip an excluded instance in the descent.
    expect(_snap(index, probe, exclude: {instance}).entity, other);
  });

  test('an intersection with an excluded line is not offered', () {
    final doc = DraftDocument.empty();
    final a = _line(doc, doc.rootHandle, [4200.5, -2100.25, 4400.5, -1900.25]);
    _line(doc, doc.rootHandle, [4200.5, -1900.25, 4400.5, -2100.25]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final out = SnapResult();
    final probe = Vector2(4300.5, -2000.25);
    final mask = SnapMask.none.with_(SnapKind.intersection);
    index.snapInto(probe, 40, mask, out);
    expect(out.found, isTrue, reason: 'premise');
    // Mutation: drop the skip in the intersection collection.
    index.snapInto(probe, 40, mask, out, exclude: {a});
    expect(out.found, isFalse);
  });

  test('resolveDragPoint passes the exclusion to the snap', () {
    final doc = DraftDocument.empty();
    final a = _line(doc, doc.rootHandle, [4200.5, -2000.25, 4400.5, -2000.25]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final raw = Vector2(4310.5, -2000.25);
    final out = DragPoint();
    void run(Set<Handle>? ex) => resolveDragPoint(
        raw: raw,
        orthoBase: null,
        index: index,
        apertureWorld: 40,
        objectSnap: true,
        page: null,
        gridStepMm: null,
        scratch: SnapResult(),
        out: out,
        exclude: ex);
    run(null);
    expect(out.point.x, 4300.5, reason: 'premise: the midpoint wins');
    // Mutation: resolveDragPoint does not forward `exclude`.
    run({a});
    expect(out.objectKind, isNull);
    expect(out.point.x, 4310.5);
  });
}
