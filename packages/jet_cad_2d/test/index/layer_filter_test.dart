import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import '../invariants/vm_allocation_meter.dart';
import '../support/layer_fixture.dart';

/// Spec 12b D6, the engine half: the index sees layer changes (plan P-4).
///
/// Fixture: `test/support/layer_fixture.dart` (P-6). Every query point is a
/// world point through a turned, moved group or instance transform, never
/// the origin; the hidden layer is `C` unless a test hides another on
/// purpose.

const _pick = QueryFilter.picking();
const _render = QueryFilter.rendering();
const _radius = 1.0;
final SnapMask _nearest = const SnapMask(0).with_(SnapKind.nearest);
final SnapMask _centre = const SnapMask(0).with_(SnapKind.center);

/// A small world box around [p].
Aabb2 _around(Vector2 p, [double half = 2]) =>
    Aabb2(Vector2(p.x - half, p.y - half), Vector2(p.x + half, p.y + half));

/// The root leaves [index] renders in a box around [p].
Set<Handle> _drawnNear(DraftDocument doc, SpatialIndex index, Vector2 p) {
  final out = <Handle>{};
  index.forEachInRect(
      _around(p), _render, (slot) => out.add(doc.entities.handleAt(slot)));
  return out;
}

/// The root instances [index] renders in a box around [p].
Set<Handle> _instancesNear(SpatialIndex index, Vector2 p) {
  final out = <Handle>{};
  index.forEachInstanceInRect(_around(p), _render, out.add);
  return out;
}

/// The leaf a pick at [p] reports, or null on a miss.
Handle? _picked(SpatialIndex index, Vector2 p, [HitPath? path]) {
  final hit = path ?? HitPath();
  return index.pickInto(p, _radius, _pick, hit) ? hit.entity : null;
}

/// The leaf a snap at [p] reports, or null when none is found.
Handle? _snapped(SpatialIndex index, Vector2 p, SnapMask mask,
    [SnapResult? result]) {
  final out = result ?? SnapResult();
  index.snapInto(p, _radius, mask, out);
  return out.found ? out.entity : null;
}

/// The root instances a band over [box] selects.
Set<Handle> _banded(SpatialIndex index, Aabb2 box, BandMode mode) {
  final out = <Handle>{};
  index.forEachInstanceInBand(box, mode, _pick, out.add);
  return out;
}

/// Hides layer 0 through the dispatcher. Layer 0 is the effective current
/// layer of a fresh document, which decision 7 forbids hiding, so `A` is
/// made current first.
void _hideLayerZero(LayerFixture f) {
  f.doc.commands.execute(SetCurrentLayerCommand(f.a));
  f.doc.commands.execute(SetLayerCommand(
      f.layer(ReservedHandles.layerZero).copyWith(visible: false)));
}

/// A layer record named [name] at [handle], written straight into the
/// table: handles are unique by convention only, and no command or loader
/// refuses a table handle that an entity or node also carries (Task 3
/// review, finding 1).
void _layerAt(LayerFixture f, Handle handle, String name) {
  final zero = f.layer(ReservedHandles.layerZero);
  f.doc.tables.layers.add(LayerRecord(
    handle: handle,
    name: name,
    color: const IndexedColor(2),
    linetype: zero.linetype,
    lineweight: zero.lineweight,
    transparency: zero.transparency,
    visible: true,
    locked: false,
  ));
}

/// An add of a [kind] entity on [layer] owned by [owner].
AddEntityCommand _add(Handle handle, Handle owner, Handle layer,
        EntityKind kind, List<double> coords, List<double> scalars,
        {String text = ''}) =>
    AddEntityCommand(
      record: EntityRecord(
        handle: handle,
        owner: owner,
        kind: kind,
        layer: layer,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: kByLayer,
        transparency: kByLayer,
        flags: 0,
        text: text,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars),
      ),
    );

/// An add of a line on [layer] owned by [owner], from (x1, y1) to (x2, y2).
AddEntityCommand _addLine(Handle handle, Handle owner, Handle layer, double x1,
        double y1, double x2, double y2) =>
    _add(handle, owner, layer, EntityKind.line, [x1, y1, x2, y2], const []);

void main() {
  group('the filter cache follows the tables (D6)', () {
    test(
        'a layer hidden by a direct table write after a query is excluded '
        'from the next rendering, picking and snapping query; showing it '
        'brings it back (M-LP-1)', () {
      final f = LayerFixture();
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      // The premise: the filter has answered for A already.
      expect(_drawnNear(f.doc, index, f.lineAAt), contains(f.lineA));
      expect(_picked(index, f.lineAAt), f.lineA);
      expect(_snapped(index, f.lineAAt, _nearest), f.lineA);

      f.writeLayer(f.layer(f.a).copyWith(visible: false));
      expect(_drawnNear(f.doc, index, f.lineAAt), isNot(contains(f.lineA)));
      expect(_picked(index, f.lineAAt), isNull);
      expect(_snapped(index, f.lineAAt, _nearest), isNull);
      // Neighbours on other layers are unaffected.
      expect(_picked(index, f.lineZeroAt), f.lineZero);

      f.writeLayer(f.layer(f.a).copyWith(visible: true));
      expect(_drawnNear(f.doc, index, f.lineAAt), contains(f.lineA));
      expect(_picked(index, f.lineAAt), f.lineA);
      expect(_snapped(index, f.lineAAt, _nearest), f.lineA);
    });

    test('the same through SetLayerCommand, its undo and its redo', () {
      final f = LayerFixture();
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      expect(_picked(index, f.lineAAt), f.lineA);

      f.doc.commands
          .execute(SetLayerCommand(f.layer(f.a).copyWith(visible: false)));
      expect(_drawnNear(f.doc, index, f.lineAAt), isNot(contains(f.lineA)));
      expect(_picked(index, f.lineAAt), isNull);
      expect(_snapped(index, f.lineAAt, _nearest), isNull);

      f.doc.commands.undo();
      expect(_drawnNear(f.doc, index, f.lineAAt), contains(f.lineA));
      expect(_picked(index, f.lineAAt), f.lineA);
      expect(_snapped(index, f.lineAAt, _nearest), f.lineA);

      f.doc.commands.redo();
      expect(_picked(index, f.lineAAt), isNull);
      expect(_snapped(index, f.lineAAt, _nearest), isNull);
    });

    test(
        'a lock after a query: picking excludes, rendering and snapping keep; '
        'unlock restores the pick', () {
      final f = LayerFixture();
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      expect(_picked(index, f.lineAAt), f.lineA);
      // B is locked from the start: drawn and snapped, never picked.
      expect(_picked(index, f.lineBAt), isNull);
      expect(_snapped(index, f.lineBAt, _nearest), f.lineB);

      f.doc.commands
          .execute(SetLayerCommand(f.layer(f.a).copyWith(locked: true)));
      expect(_picked(index, f.lineAAt), isNull);
      expect(_drawnNear(f.doc, index, f.lineAAt), contains(f.lineA));
      expect(_snapped(index, f.lineAAt, _nearest), f.lineA);

      f.doc.commands
          .execute(SetLayerCommand(f.layer(f.b).copyWith(locked: false)));
      expect(_picked(index, f.lineBAt), f.lineB);
      f.doc.commands.undo();
      f.doc.commands.undo();
      expect(_picked(index, f.lineAAt), f.lineA);
      expect(_picked(index, f.lineBAt), isNull);
    });

    test(
        'hide, show, lock, unlock, rename, recolour and a current-layer change '
        'cost the index no rebuild (M-LP-2)', () {
      final f = LayerFixture();
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      final rebuilds = index.rebuildCount;
      final commands = f.doc.commands;
      commands.execute(SetLayerCommand(f.layer(f.a).copyWith(visible: false)));
      commands.execute(SetLayerCommand(f.layer(f.a).copyWith(visible: true)));
      commands.execute(SetLayerCommand(f.layer(f.a).copyWith(locked: true)));
      commands.execute(SetLayerCommand(f.layer(f.a).copyWith(locked: false)));
      commands.execute(SetLayerCommand(f.layer(f.a).copyWith(name: 'Walls')));
      commands.execute(
          SetLayerCommand(f.layer(f.a).copyWith(color: const IndexedColor(6))));
      commands.execute(SetCurrentLayerCommand(f.a));
      commands.undo();
      commands.redo();
      expect(index.rebuildCount, rebuilds);
      // And the answers are current, not merely cheap.
      expect(_picked(index, f.lineAAt), f.lineA);
      commands.execute(SetLayerCommand(f.layer(f.c).copyWith(visible: true)));
      expect(_picked(index, f.lineCAt), f.lineC);
      expect(index.rebuildCount, rebuilds);
    });

    test(
        'a layer handle no longer in the table still rebuilds once: the undo '
        'of an add (S-4)', () {
      final f = LayerFixture();
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      final rebuilds = index.rebuildCount;
      final zero = f.layer(ReservedHandles.layerZero);
      f.doc.commands.execute(AddLayerCommand(LayerRecord(
        handle: f.doc.handleSeed.next(),
        name: 'D',
        color: const IndexedColor(2),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency,
        visible: true,
        locked: false,
      )));
      expect(index.rebuildCount, rebuilds, reason: 'the added layer resolves');
      f.doc.commands.undo();
      expect(index.rebuildCount, rebuilds + 1,
          reason: 'the removed one does not, and falls through as before');
    });

    test(
        'an entity that shares its handle with a layer record: an edit to it '
        'still reaches the index (Task 3 review, finding 1)', () {
      final f = LayerFixture();
      _layerAt(f, f.lineA, 'Shadow');
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      expect(_picked(index, f.lineAAt), f.lineA);
      f.doc.commands.execute(SetEntityGeometryCommand(
          f.lineA,
          GeometryPayload(
            coords: Float64List.fromList([300, 40, 380, 50]),
            scalars: Float64List(0),
          )));
      final moved =
          LayerFixture.groupTransform.transformPoint(Vector2(340, 45));
      expect(_picked(index, moved), f.lineA);
      expect(_picked(index, f.lineAAt), isNull);
    });

    test(
        'an entity added at a layer record\'s handle is indexed (the '
        'containsHandle guard)', () {
      final f = LayerFixture();
      final shared = f.doc.handleSeed.next();
      _layerAt(f, shared, 'Shadow');
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      f.doc.commands.execute(
          _addLine(shared, f.doc.rootHandle, f.a, -800, 250, -700, 290));
      expect(_picked(index, Vector2(-750, 270)), shared);
    });

    test(
        'an entity removed at a layer record\'s handle leaves the index (the '
        'last-known-slot guard)', () {
      final f = LayerFixture();
      final shared = f.doc.handleSeed.next();
      f.doc.commands.execute(
          _addLine(shared, f.doc.rootHandle, f.a, -800, 250, -700, 290));
      _layerAt(f, shared, 'Shadow');
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      expect(_picked(index, Vector2(-750, 270)), shared);
      f.doc.commands.execute(RemoveEntityCommand(shared));
      expect(_picked(index, Vector2(-750, 270)), isNull);
    });

    test(
        'an instance added at a layer record\'s handle is indexed (the node '
        'guard)', () {
      final f = LayerFixture();
      final shared = f.doc.handleSeed.next();
      _layerAt(f, shared, 'Shadow');
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      final placed = Transform2.translation(-1400, 600)
          .multiply(Transform2.rotation(-math.pi / 4));
      f.doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: shared,
        parent: f.doc.rootHandle,
        transform: placed,
        definition: f.table,
        layer: f.a,
      )));
      expect(_instancesNear(index, placed.transformPoint(Vector2(40, 25))),
          {shared});
    });
  });

  group('the effective layer: layer-0 substitution (D6, P-4)', () {
    test(
        'with layer 0 hidden, the instance on A is still drawn, and so is its '
        'ATTRIB; a root line on layer 0 is not', () {
      final f = LayerFixture();
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      expect(_drawnNear(f.doc, index, f.lineZeroAt), contains(f.lineZero));
      _hideLayerZero(f);
      expect(
          _drawnNear(f.doc, index, f.lineZeroAt), isNot(contains(f.lineZero)));
      expect(_instancesNear(index, f.tableLineAt), {f.instance});
      expect(_drawnNear(f.doc, index, f.attribProbe), contains(f.attrib),
          reason: 'the ATTRIB on layer 0 follows its instance on A (M-LP-23)');
    });

    test('with layer 0 hidden, picking reaches every level of the instance',
        () {
      final f = LayerFixture();
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      _hideLayerZero(f);
      final path = HitPath();
      expect(_picked(index, f.tableLineAt, path), f.tableLine,
          reason: 'a definition leaf on layer 0 follows the instance on A '
              '(M-LP-14, pick)');
      expect(path.chainLength, 1);
      expect(Handle(path.chain[0]), f.instance);
      expect(_picked(index, f.legLineAt, path), f.legLine,
          reason: 'the nested instance on layer 0 follows A (M-LP-24), and '
              'so does its own leaf, two levels down (M-LP-14, recursion)');
      expect(path.chainLength, 2);
      expect(Handle(path.chain[1]), f.nested);
      expect(_picked(index, f.attribProbe), f.attrib,
          reason: 'the ATTRIB follows its instance (M-LP-23)');
      expect(_picked(index, f.lineZeroAt), isNull);
    });

    test('with layer 0 hidden, snapping reaches every level of the instance',
        () {
      final f = LayerFixture();
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      _hideLayerZero(f);
      final out = SnapResult();
      expect(_snapped(index, f.tableCircleCentre, _centre, out), f.tableCircle,
          reason: 'the centre walk substitutes too (M-LP-14, snap)');
      expect(out.kind, SnapKind.center);
      expect(_snapped(index, f.legLineAt, _nearest, out), f.legLine);
      expect(out.chainLength, 2);
      expect(_snapped(index, f.lineZeroAt, _nearest), isNull);
    });

    test('with layer 0 hidden, a band selects the instance through its leaves',
        () {
      final f = LayerFixture();
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      _hideLayerZero(f);
      // A crossing band touching only the nested instance's leaf: the
      // instance is selected through two levels of substitution.
      expect(_banded(index, _around(f.legLineAt, 1), BandMode.crossing),
          {f.instance},
          reason: 'M-LP-14 (band, recursion), M-LP-24 (band)');
      // A crossing band touching only the definition's own line.
      expect(_banded(index, _around(f.tableLineAt, 1), BandMode.crossing),
          {f.instance},
          reason: 'M-LP-14 (band)');
      // A window around the whole instance, ATTRIB aside.
      expect(
          _banded(
              index,
              Aabb2(Vector2(f.tableLineAt.x - 200, f.tableLineAt.y - 200),
                  Vector2(f.tableLineAt.x + 200, f.tableLineAt.y + 200)),
              BandMode.window),
          {f.instance});
    });

    test(
        'a pick and a band after a snap through an instance on locked B still '
        'test the instance on A by A: each query writes its own depth array',
        () {
      final f = LayerFixture();
      final onB = f.doc.handleSeed.next();
      final transformB = Transform2.translation(-900, 1500)
          .multiply(Transform2.rotation(-math.pi / 3));
      f.doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: onB,
        parent: f.doc.rootHandle,
        transform: transformB,
        definition: f.table,
        layer: f.b,
      )));
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      // A snap at B's nested leg line descends two levels into the instance
      // on B (a locked layer still snaps) and leaves B as the effective
      // layer at both depths. Each pick and band after it, with picking's
      // filter, must test the instance on A's leaves against A, not against
      // what the snap left behind — so each one follows a fresh snap.
      final onBLeg = transformB
          .multiply(LayerFixture.nestedTransform)
          .transformPoint(Vector2(15, 10));
      void snapOnB() => expect(_snapped(index, onBLeg, _nearest), f.legLine);
      snapOnB();
      expect(_picked(index, f.tableLineAt), f.tableLine);
      snapOnB();
      expect(_picked(index, f.legLineAt), f.legLine);
      snapOnB();
      expect(_banded(index, _around(f.tableLineAt, 1), BandMode.crossing),
          {f.instance});
      snapOnB();
      expect(_banded(index, _around(f.legLineAt, 1), BandMode.crossing),
          {f.instance});
    });

    test(
        'a pick and a snap after a band through an instance on layer 0, then '
        'layer 0 hidden, still test the instance on A by A', () {
      final f = LayerFixture();
      final onZero = f.doc.handleSeed.next();
      final transformZero = Transform2.translation(2400, -700)
          .multiply(Transform2.rotation(math.pi / 5));
      f.doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: onZero,
        parent: f.doc.rootHandle,
        transform: transformZero,
        definition: f.table,
        layer: ReservedHandles.layerZero,
      )));
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      // The band descends into the instance on layer 0 and leaves layer 0 as
      // the effective layer one level down.
      expect(
          _banded(
              index,
              _around(transformZero.transformPoint(Vector2(40, 25)), 1),
              BandMode.crossing),
          {onZero});
      _hideLayerZero(f);
      expect(_picked(index, f.tableLineAt), f.tableLine);
      expect(_snapped(index, f.legLineAt, _nearest), f.legLine);
    });

    test(
        'hiding A hides and unpicks the instance, everything in it, its ATTRIB '
        'and the region on A', () {
      final f = LayerFixture();
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      expect(_picked(index, f.attribProbe), f.attrib);
      expect(_drawnNear(f.doc, index, f.regionEdge),
          {f.regionFill, f.regionBoundary});
      f.doc.commands
          .execute(SetLayerCommand(f.layer(f.a).copyWith(visible: false)));
      expect(_instancesNear(index, f.tableLineAt), isEmpty);
      expect(_picked(index, f.tableLineAt), isNull);
      expect(_picked(index, f.legLineAt), isNull);
      expect(_snapped(index, f.tableCircleCentre, _centre), isNull);
      expect(_drawnNear(f.doc, index, f.attribProbe), isNot(contains(f.attrib)),
          reason: 'the ATTRIB on layer 0 follows its hidden instance '
              '(M-LP-23)');
      expect(_picked(index, f.attribProbe), isNull);
      expect(_snapped(index, f.attribProbe, SnapMask.all), isNull);
      expect(_drawnNear(f.doc, index, f.regionEdge), isEmpty);
      expect(
          _banded(index, _around(f.legLineAt, 1), BandMode.crossing), isEmpty);
    });

    test('locking A makes its ATTRIB unpickable and keeps it snappable', () {
      final f = LayerFixture();
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      f.doc.commands
          .execute(SetLayerCommand(f.layer(f.a).copyWith(locked: true)));
      expect(_picked(index, f.attribProbe), isNull,
          reason: 'the ATTRIB on layer 0 follows its locked instance');
      expect(_picked(index, f.tableLineAt), isNull);
      expect(_snapped(index, f.legLineAt, _nearest), f.legLine);
    });

    test(
        'moving the instance to a hidden layer takes its ATTRIB along; the '
        'undo brings both back', () {
      final f = LayerFixture();
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      expect(_picked(index, f.attribProbe), f.attrib);
      f.doc.commands.execute(SetInstanceLayerCommand(f.instance, f.c));
      expect(_picked(index, f.attribProbe), isNull);
      expect(
          _drawnNear(f.doc, index, f.attribProbe), isNot(contains(f.attrib)));
      expect(_picked(index, f.tableLineAt), isNull);
      f.doc.commands.undo();
      expect(_picked(index, f.attribProbe), f.attrib);
      expect(_picked(index, f.tableLineAt), f.tableLine);
    });

    test(
        'with layer 0 hidden, an ATTRIB on layer 0 owned by the nested '
        'instance on layer 0 follows the instance on A; locking A unpicks it '
        '(Task 3 review, finding 2)', () {
      final f = LayerFixture();
      final nestedAttrib = f.doc.handleSeed.next();
      f.doc.commands.execute(_add(nestedAttrib, f.nested,
          ReservedHandles.layerZero, EntityKind.attrib, [-50, 35], [4, 0],
          text: 'LEG'));
      final probe = LayerFixture.instanceTransform
          .multiply(LayerFixture.nestedTransform)
          .transformPoint(Vector2(-48.5, 36.5));
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      expect(_picked(index, probe), nestedAttrib);
      _hideLayerZero(f);
      final path = HitPath();
      expect(_picked(index, probe, path), nestedAttrib);
      // Indexed as a leaf of Table's container, transformed by the nested
      // placement: the hit path names the root instance only.
      expect(path.chainLength, 1);
      expect(Handle(path.chain[0]), f.instance);
      final drawn = <Handle>{};
      // A crossing band over the glyph box's left edge, with the rendering
      // filter (visibility, no lock).
      index.forEachInstanceInBand(
          _around(probe, 3), BandMode.crossing, _render, drawn.add);
      expect(drawn, {f.instance},
          reason: 'drawn through the instance on A, not on hidden layer 0');
      f.doc.commands
          .execute(SetLayerCommand(f.layer(f.a).copyWith(locked: true)));
      expect(_picked(index, probe), isNull);
    });

    test(
        'a line on an unlocked layer D inside Leg is unpickable once A is '
        'locked: the nested instance on layer 0 follows A and is pruned '
        'whole (Task 3 review, finding 3)', () {
      final f = LayerFixture();
      final d = f.doc.handleSeed.next();
      _layerAt(f, d, 'D');
      final onD = f.doc.handleSeed.next();
      f.doc.commands.execute(_addLine(onD, f.leg, d, 5, 30, 25, 40));
      final at = LayerFixture.instanceTransform
          .multiply(LayerFixture.nestedTransform)
          .transformPoint(Vector2(15, 35));
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      expect(_picked(index, at), onD);
      f.doc.commands
          .execute(SetLayerCommand(f.layer(f.a).copyWith(locked: true)));
      expect(_picked(index, at), isNull);
      expect(_snapped(index, at, _nearest), onD, reason: 'locked still snaps');
    });

    test(
        'with layer 0 locked, the nested instance on layer 0 follows the '
        'unlocked A: its leaves on D and on layer 0 stay pickable (Task 3 '
        'review, finding 3; O2)', () {
      // Locking A cannot tell O2 apart: the root instance on A is pruned
      // before the nested one is reached. Locking layer 0 is the converse
      // and can: a nested instance tested by its stored layer 0 would be
      // pruned, though its effective layer is A.
      final f = LayerFixture();
      final d = f.doc.handleSeed.next();
      _layerAt(f, d, 'D');
      final onD = f.doc.handleSeed.next();
      f.doc.commands.execute(_addLine(onD, f.leg, d, 5, 30, 25, 40));
      final at = LayerFixture.instanceTransform
          .multiply(LayerFixture.nestedTransform)
          .transformPoint(Vector2(15, 35));
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      f.doc.commands.execute(SetCurrentLayerCommand(f.a));
      f.doc.commands.execute(SetLayerCommand(
          f.layer(ReservedHandles.layerZero).copyWith(locked: true)));
      expect(_picked(index, f.lineZeroAt), isNull,
          reason: 'the premise: layer 0 is locked');
      expect(_picked(index, at), onD);
      expect(_picked(index, f.legLineAt), f.legLine);
      expect(_picked(index, f.tableLineAt), f.tableLine);
    });

    test('a nested instance on a non-zero layer answers for its own layer', () {
      final f = LayerFixture();
      // The nested Leg moved onto C (hidden) inside an instance on A: its
      // leaf, on layer 0, now follows C, and the rest of the table stays.
      final node = f.doc.tree[f.nested]! as InstanceNode;
      f.doc.tree.replaceNode(InstanceNode(
        handle: node.handle,
        parent: node.parent,
        transform: node.transform,
        definition: node.definition,
        layer: f.c,
      ));
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      expect(_picked(index, f.legLineAt), isNull);
      expect(_picked(index, f.tableLineAt), f.tableLine);
    });
  });

  group('allocation probe (D6, the frame path)', () {
    AllocationMeter? meter;
    setUpAll(() async => meter = await AllocationMeter.connect());
    tearDownAll(() async => meter?.dispose());

    // Classes a per-query or per-candidate allocation on the new path would
    // build: the container-visibility walk's `seen` set (`_Set`), which a
    // filter cache dropped on every query re-allocates per container, and
    // the classes query_allocation_test.dart already watches per candidate.
    // `_Uint32List` (a fresh depth array) cannot be watched: it reads about
    // 18,000 accumulated instances with no query run at all, the VM
    // service's own traffic. The depth-bound `Aabb2`/`Transform2` costs
    // `_descend` documents are watched at that file's ceilings, not at zero.
    const watched = {'Vector2', '_Record', 'TextMetrics', '_Set'};
    const depthBound = {'Aabb2': 7.0, 'Transform2': 10.0};
    const budget = 0.5;

    Future<void> probe(String name, void Function() query) async {
      final m = meter;
      if (m == null) {
        markTestSkipped(vmServiceUnavailableReason);
        return;
      }
      for (var i = 0; i < 20000; i++) {
        query();
      }
      await m.reset();
      const iters = 1000;
      for (var i = 0; i < iters; i++) {
        query();
      }
      final counts =
          await m.accumulatedInstances({...watched, ...depthBound.keys});
      for (final cls in watched) {
        expect(counts[cls]! / iters, lessThan(budget),
            reason: '$name: $cls ${counts[cls]! / iters} per call');
      }
      for (final cls in depthBound.keys) {
        expect(counts[cls]! / iters, lessThan(depthBound[cls]!),
            reason: '$name: $cls ${counts[cls]! / iters} per call');
      }
    }

    test('a pick two instances deep, substituting, allocates nothing per call',
        () async {
      final f = LayerFixture();
      _hideLayerZero(f);
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      final hit = HitPath();
      final point = f.legLineAt;
      expect(index.pickInto(point, _radius, _pick, hit), isTrue);
      expect(hit.chainLength, 2);
      await probe('pickInto', () => index.pickInto(point, _radius, _pick, hit));
    });

    test('a snap two instances deep, substituting, allocates nothing per call',
        () async {
      final f = LayerFixture();
      _hideLayerZero(f);
      final index = SpatialIndex(f.doc);
      addTearDown(index.dispose);
      final out = SnapResult();
      final point = f.legLineAt;
      index.snapInto(point, 4, SnapMask.all, out);
      expect(out.found, isTrue);
      expect(out.chainLength, 2);
      await probe(
          'snapInto', () => index.snapInto(point, 4, SnapMask.all, out));
    });
  });
}
