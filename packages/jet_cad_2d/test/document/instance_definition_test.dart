// Spec 09c D7: SetInstanceDefinitionCommand points an instance at another
// definition. Fixtures off the origin: two definitions with different base
// points and leaves, an instance turned a quarter turn at (1000, 500), so
// the world position of each definition's leaf differs and the index's
// pick tells which definition the instance draws.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

final Transform2 kPlace = Transform2.translation(1000, 500)
    .multiply(Transform2.rotation(math.pi / 2));

AddEntityCommand leaf(Handle handle, Handle owner, List<double> coords) =>
    AddEntityCommand(
      record: EntityRecord(
        handle: handle,
        owner: owner,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byBlockLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByBlockColor(),
        lineweight: kByBlock,
        transparency: kByBlock,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List(0),
      ),
    );

/// Definition A: a leaf (20, 30)-(60, 30), world (970, 520)-(970, 560).
/// Definition B: a leaf (0, 100)-(80, 100), world (900, 500)-(900, 580).
/// An instance of A under the root.
({
  DraftDocument doc,
  Handle a,
  Handle b,
  Handle leafA,
  Handle leafB,
  Handle instance
}) fixture() {
  final doc = DraftDocument.empty();
  final a = doc.handleSeed.next(), b = doc.handleSeed.next();
  for (final (h, base) in [(a, Vector2(40, 30)), (b, Vector2(0, 0))]) {
    doc.commands.execute(AddDefinitionCommand(Definition(
        handle: h, name: 'D${h.value}', basePoint: base, children: const [])));
  }
  final leafA = doc.handleSeed.next(), leafB = doc.handleSeed.next();
  doc.commands.execute(leaf(leafA, a, [20, 30, 60, 30]));
  doc.commands.execute(leaf(leafB, b, [0, 100, 80, 100]));
  final instance = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: kPlace,
      definition: a,
      layer: ReservedHandles.layerZero)));
  return (doc: doc, a: a, b: b, leafA: leafA, leafB: leafB, instance: instance);
}

Handle? pickAt(SpatialIndex index, double x, double y) {
  final hit = HitPath();
  return index.pickInto(Vector2(x, y), 1.0, const QueryFilter.all(), hit)
      ? hit.entity
      : null;
}

void main() {
  test(
      'ID1 the instance draws the new definition; one undo draws the old; '
      'redo the new; the old definition stays (M-09c-w)', () {
    final f = fixture();
    final index = SpatialIndex(f.doc);
    addTearDown(index.dispose);
    expect(pickAt(index, 970, 540), f.leafA);
    expect(f.doc.extents.min.x, closeTo(970, 1e-9));
    final depth = f.doc.commands.undoDepth;

    f.doc.commands.execute(SetInstanceDefinitionCommand(f.instance, f.b));
    expect((f.doc.tree[f.instance]! as InstanceNode).definition, f.b);
    expect((f.doc.tree[f.instance]! as InstanceNode).transform.e, kPlace.e,
        reason: 'the transform is untouched');
    expect(f.doc.commands.undoDepth, depth + 1);
    expect(pickAt(index, 900, 540), f.leafB, reason: 'the index follows');
    expect(pickAt(index, 970, 540), isNull);
    expect(f.doc.tree.definition(f.a), isNotNull, reason: 'kept, unused');
    expect(f.doc.extents.min.x, closeTo(900, 1e-9),
        reason: 'the derived extents follow');

    f.doc.commands.undo();
    expect((f.doc.tree[f.instance]! as InstanceNode).definition, f.a);
    expect(pickAt(index, 970, 540), f.leafA);
    expect(pickAt(index, 900, 540), isNull);

    f.doc.commands.redo();
    expect((f.doc.tree[f.instance]! as InstanceNode).definition, f.b);
    expect(pickAt(index, 900, 540), f.leafB);
  });

  test('ID2 an edit to the new definition\'s leaf propagates to the instance',
      () {
    final f = fixture();
    final index = SpatialIndex(f.doc);
    addTearDown(index.dispose);
    f.doc.commands.execute(SetInstanceDefinitionCommand(f.instance, f.b));
    f.doc.commands.execute(SetEntityGeometryCommand(
        f.leafB,
        GeometryPayload(
            coords: Float64List.fromList([0, 200, 80, 200]),
            scalars: Float64List(0))));
    // Local (0, 200)-(80, 200) lands on world x 800.
    expect(pickAt(index, 800, 540), f.leafB);
    expect(pickAt(index, 900, 540), isNull);
  });

  test(
      'ID3 refused: a missing node, a group, a missing definition, a cycle; '
      'nothing changes', () {
    final f = fixture();
    final group = f.doc.handleSeed.next();
    f.doc.commands.execute(AddNodeCommand(GroupNode(
        handle: group,
        parent: f.doc.rootHandle,
        transform: Transform2.identity(),
        children: const [])));
    // An instance of A inside B, so pointing it at B is a cycle.
    final inner = f.doc.handleSeed.next();
    f.doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: inner,
        parent: f.b,
        transform: Transform2.translation(5, 7),
        definition: f.a,
        layer: ReservedHandles.layerZero)));
    final depth = f.doc.commands.undoDepth;
    final before = DraftDocumentCodec.encodeToString(f.doc);
    for (final (what, command, error) in [
      (
        'a missing node',
        SetInstanceDefinitionCommand(Handle(0xFFFFF), f.b),
        isStateError
      ),
      ('a group', SetInstanceDefinitionCommand(group, f.b), isStateError),
      (
        'a missing definition',
        SetInstanceDefinitionCommand(f.instance, Handle(0xFFFFE)),
        isStateError
      ),
      (
        'a cycle',
        SetInstanceDefinitionCommand(inner, f.b),
        isA<CycleDetectedError>()
      ),
    ]) {
      expect(() => f.doc.commands.execute(command), throwsA(error),
          reason: what);
    }
    expect(f.doc.commands.undoDepth, depth);
    expect(DraftDocumentCodec.encodeToString(f.doc), before);
  });

  test('ID4 it needs structure: refused under runtime permissions', () {
    final f = fixture();
    expect(SetInstanceDefinitionCommand(f.instance, f.b).capabilities,
        {Capability.structure});
    expect(DraftPermissions.runtime.allows(Capability.structure), isFalse);
  });
}
