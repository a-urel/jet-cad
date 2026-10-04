// Spec 09 D10, F-7, plan 09a Task 6: a REAL library symbol (bed.double, from
// the committed asset) placed through the real dispatcher, rotated one
// quarter turn AND mirrored, far from the origin, with a concrete instance
// colour and lineweight, then read back through the painter, the pick, the
// snap, the extents and the codec. Nothing has combined these before (F-7).
//
// Every expected number is computed here from the symbol's LOCAL coordinates
// (written out below from the catalog) by `world()`, never through the
// placer's `Transform2`.
//
//   bed.double: basePoint (800, 1000);
//     leaf 0 outer rect   (0,0) (1600,0) (1600,2000) (0,2000)
//     leaf 1 pillow       (100,1680) (750,1680) (750,1920) (100,1920)
//     leaf 2 pillow       (850,1680) (1500,1680) (1500,1920) (850,1920)
//     leaf 3 line         (0,1300) - (1600,1300)
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:jet_cad_floor_plan/src/new_document.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/select_rig.dart';

final Vector2 at = Vector2(12345, -6789);
const double baseX = 800, baseY = 1000;

/// Quarter turn 1 (counter-clockwise) and mirrored: the local x axis is
/// flipped about the base point, then the plan turns 90 degrees, then the
/// base point lands on [at]. Written out by hand: (x, y) -> (-x, y) ->
/// (-y, -x) -> + at.
Vector2 world(double lx, double ly) {
  final qx = lx - baseX, qy = ly - baseY;
  return Vector2(at.x - qy, at.y - qx);
}

/// Same point under the same turn but NOT mirrored (the control).
Vector2 worldUnmirrored(double lx, double ly) {
  final qx = lx - baseX, qy = ly - baseY;
  return Vector2(at.x - qy, at.y + qx);
}

const int instanceArgb = 0xFF33AA77; // TrueColor(0x33AA77), opaque
const int instanceWeight = 70;
const int rootArgb = 0xFFFFFFFF; // StyleContext.documentRoot: ACI 7
const int rootWeight = 25; // StyleContext.documentRoot: 0.25 mm

SymbolEntry bed() {
  final lib = SymbolLibrary.decode(
      File('assets/library/furniture.jetlib').readAsBytesSync());
  return lib.entries.firstWhere((e) => e.key == 'bed.double');
}

DraftDocument placed(SymbolEntry entry, {InstanceStyle? style}) {
  final doc = prepareDocument(const InsertionPointMeasurer());
  doc.commands.execute(placeSymbol(doc, entry,
      at: at,
      quarterTurns: 1,
      mirrored: true,
      style: style ?? const InstanceStyle()));
  return doc;
}

const Size viewport = Size(800, 600);

/// The recorded polylines, each with the points the sink was told to draw
/// reconstructed in WORLD space from the residual in force (the painter
/// rebases, so a recorded point is local to its residual).
List<({List<Vector2> points, ResolvedStyle style, bool closed})> painted(
    DraftDocument doc) {
  final index = SpatialIndex(doc);
  final painter = DraftPainter(
      document: doc, index: index, resolver: DocumentStyleResolver(doc));
  final camera = ViewportTransform.fit(doc.extents, viewport);
  final sink = RecordingDrawSink();
  painter.paint(sink, camera, viewport);
  index.dispose();
  final out = <({List<Vector2> points, ResolvedStyle style, bool closed})>[];
  Transform2? residual;
  for (final op in sink.ops) {
    if (op is BeginResidualOp) residual = op.residual;
    if (op is PolylineOp) {
      final pts = <Vector2>[];
      for (var i = 0; i < op.points.length; i += 2) {
        final s =
            residual!.transformPoint(Vector2(op.points[i], op.points[i + 1]));
        pts.add(camera.screenToWorld(s));
      }
      out.add((points: pts, style: op.style, closed: op.closed));
    }
  }
  return out;
}

/// The placed leaves of the document's one definition, ascending by handle.
List<Handle> placedLeaves(DraftDocument doc) {
  final def = doc.tree.definitions.single.handle;
  final out = <Handle>[];
  for (final slot in doc.entities.liveSlots) {
    if (doc.entities.ownerAt(slot) == def) out.add(doc.entities.handleAt(slot));
  }
  out.sort((a, b) => a.value.compareTo(b.value));
  return out;
}

void expectPoint(Vector2 got, Vector2 want, String reason, {double slack = 0}) {
  final tol = Tolerance.standard.linear + slack;
  expect((got.x - want.x).abs() <= tol && (got.y - want.y).abs() <= tol, isTrue,
      reason: '$reason: got $got, want $want');
}

Vector2 midOf(Vector2 a, Vector2 b) =>
    Vector2((a.x + b.x) / 2, (a.y + b.y) / 2);

void main() {
  test(
      'a real symbol, rotated and mirrored far from the origin, with an '
      'instance colour and weight: painter, pick, snap, extents, validate, '
      'codec', () {
    final entry = bed();
    expect(entry.definition.basePoint.x, baseX);
    expect(entry.definition.basePoint.y, baseY);
    expect(entry.leaves.length, 4);

    final doc = placed(entry,
        style: const InstanceStyle(
            color: TrueColor(0x33AA77), lineweight: instanceWeight));
    final leaves = placedLeaves(doc);
    expect(leaves.length, 4);
    final instance = doc.tree.nodes.whereType<InstanceNode>().single;

    // (1) The painter: four strokes, in ascending handle order, at the
    // transformed positions, each carrying the instance colour and weight.
    // The camera round trip (world -> screen -> residual -> world) carries a
    // few ulps at 1e4: 1e-6 slack, on purpose.
    const slack = 1e-6;
    final expected = <List<Vector2>>[
      [
        world(0, 0),
        world(1600, 0),
        world(1600, 2000),
        world(0, 2000),
        world(0, 0)
      ],
      [
        world(100, 1680),
        world(750, 1680),
        world(750, 1920),
        world(100, 1920),
        world(100, 1680)
      ],
      [
        world(850, 1680),
        world(1500, 1680),
        world(1500, 1920),
        world(850, 1920),
        world(850, 1680)
      ],
      [world(0, 1300), world(1600, 1300)],
    ];
    final ops = painted(doc);
    expect(ops.length, 4);
    for (var i = 0; i < 4; i++) {
      expect(ops[i].points.length, expected[i].length, reason: 'leaf $i');
      for (var j = 0; j < expected[i].length; j++) {
        expectPoint(ops[i].points[j], expected[i][j], 'leaf $i vertex $j',
            slack: slack);
      }
      expect(ops[i].style.argb, instanceArgb, reason: 'leaf $i colour');
      expect(ops[i].style.lineweightHundredths, instanceWeight,
          reason: 'leaf $i weight');
    }
    // The mirror and the turn, stated as literals: the first pillow's first
    // vertex is at (11665, -6089); unmirrored it would be at (11665, -7489).
    expectPoint(ops[1].points[0], Vector2(11665, -6089), 'pillow 1 vertex 0',
        slack: slack);
    expect(worldUnmirrored(100, 1680).y, -7489);

    // The control: the same placement with the default style draws the
    // BYBLOCK resolution of the document root (ACI 7 foreground, 0.25 mm),
    // so the assertions above cannot pass at defaults.
    final control = painted(placed(entry));
    expect(control.length, 4);
    for (var i = 0; i < 4; i++) {
      expect(control[i].style.argb, rootArgb, reason: 'control leaf $i');
      expect(control[i].style.lineweightHundredths, rootWeight,
          reason: 'control leaf $i');
      expect(control[i].style.argb, isNot(instanceArgb));
      expect(control[i].style.lineweightHundredths, isNot(instanceWeight));
    }

    // (2) Pick: a point ON a named leaf returns it, through the instance.
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final hit = HitPath();
    void expectPick(Vector2 p, Handle leaf, String reason) {
      expect(index.pickInto(p, 1.0, const QueryFilter.all(), hit), isTrue,
          reason: reason);
      expect(hit.entity, leaf, reason: reason);
      expect(hit.chainLength, 1, reason: reason);
      expect(hit.chain[0], instance.handle.value, reason: reason);
    }

    expectPick(world(800, 1300), leaves[3], 'the line leaf, mid-span');
    // The mirror, through pick: pillow 1's bottom edge midpoint is at
    // (11665, -6414). Unmirrored, that world point would belong to pillow 2.
    expectPick(world(425, 1680), leaves[1], 'pillow 1 edge');
    expectPick(world(1175, 1680), leaves[2], 'pillow 2 edge');
    expect(world(425, 1680).x, 11665);
    expect(world(425, 1680).y, -6414);
    expectPoint(worldUnmirrored(425, 1680), world(1175, 1680), 'control');
    expect(index.pickInto(Vector2(0, 0), 1.0, const QueryFilter.all(), hit),
        isFalse);

    // (3) Snap onto named leaf endpoints (F-12: the insertion point is not a
    // candidate, so it is not asserted).
    final snap = SnapResult();
    void expectSnap(Vector2 near, Vector2 at_, Handle leaf, String reason) {
      index.snapInto(Vector2(near.x + 3, near.y - 2), 10, SnapMask.cheap, snap);
      expect(snap.found, isTrue, reason: reason);
      expect(snap.kind, SnapKind.endpoint, reason: reason);
      expect(snap.entity, leaf, reason: reason);
      expectPoint(snap.point, at_, reason);
    }

    expectSnap(world(100, 1680), world(100, 1680), leaves[1],
        "pillow 1's first vertex (11665, -6089)");
    expectSnap(world(0, 1300), world(0, 1300), leaves[3],
        "the line's first endpoint (12045, -5989)");

    // (4) Extents: the outer rectangle's world box.
    final ex = doc.extents;
    expectPoint(
        Vector2(ex.minX, ex.minY), Vector2(11345, -7589), 'extents min');
    expectPoint(
        Vector2(ex.maxX, ex.maxY), Vector2(13345, -5989), 'extents max');

    // (5) validate() is empty.
    expect(doc.validate(), isEmpty);

    // (6) Save, load (registerAppComponents), save: byte-identical.
    final bytes = DraftDocumentCodec.encodeToString(doc);
    final back = DraftDocumentCodec.decodeString(bytes,
        registerComponents: registerAppComponents);
    expect(DraftDocumentCodec.encodeToString(back), bytes);
  });

  test(
      'the Select tool moves and rotates a placed, mirrored instance '
      '(P-6 item 2)', () async {
    final doc = placed(bed(),
        style: const InstanceStyle(
            color: TrueColor(0x33AA77), lineweight: instanceWeight));
    final leaves = placedLeaves(doc);
    final instance = doc.tree.nodes.whereType<InstanceNode>().single;
    final rig = SelectRig(doc, selectCamera(at));
    addTearDown(rig.dispose);
    rig.selection.replace([SelectionKey.root(instance.handle)]);
    final depth0 = doc.commands.undoDepth;

    // Move: press on the selected instance's line leaf, drag 40 px right and
    // 25 px down the screen (y is flipped: 200 world units right, 125 down).
    final body = world(800, 1300);
    final from = rig.screenOf(body.x, body.y);
    final to = from + const Offset(40, 25);
    rig.tool.onPointerDown(rig.pointerAt(from), rig.context);
    expect(rig.tool.pressClass, PressClass.selectedBody);
    rig.tool.onPointerMove(rig.pointerAt(to), rig.context);
    rig.tool.onPointerUp(rig.pointerAt(to, buttons: 0), rig.context);
    await Future<void>.delayed(
        Duration.zero); // the caches follow the change stream
    expect(doc.commands.undoDepth, depth0 + 1, reason: 'one Move step');
    final delta = Vector2(200, -125);
    final moved = doc.tree[instance.handle]! as InstanceNode;
    expect(moved.definition, instance.definition);
    expect(moved.color, instance.color);
    expect(moved.lineweight, instance.lineweight);
    expect((moved.transform.e - (instance.transform.e + delta.x)).abs(),
        lessThan(1e-6));
    expect((moved.transform.f - (instance.transform.f + delta.y)).abs(),
        lessThan(1e-6));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final hit = HitPath();
    Vector2 shifted(Vector2 p) => Vector2(p.x + delta.x, p.y + delta.y);
    expect(
        index.pickInto(
            shifted(world(425, 1680)), 1.0, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, leaves[1], reason: 'pillow 1 moved with the instance');

    // Rotate: the rotation grip of the selection box, about the box centre.
    final box = rig.grips.box!;
    final pivot = rig.grips.pivot!;
    expectPoint(pivot, shifted(at), 'pivot is the moved symbol box centre',
        slack: 1e-6);
    expectPoint(Vector2((box.minX + box.maxX) / 2, (box.minY + box.maxY) / 2),
        shifted(at), 'box centre',
        slack: 1e-6);
    final grip =
        rotationGripOf(box, rig.camera.value.worldToScreenMatrix).centre;
    final aim = grip + const Offset(-45, 38);
    rig.drag(grip, aim);
    await Future<void>.delayed(Duration.zero);
    expect(doc.commands.undoDepth, depth0 + 2, reason: 'one Rotate step');
    final w0 = rig.worldOf(grip) - pivot;
    final w1 = rig.worldOf(aim) - pivot;
    final theta = math.atan2(w1.y, w1.x) - math.atan2(w0.y, w0.x);
    expect(theta.abs(), greaterThan(0.1), reason: 'a real turn');
    Vector2 rotated(Vector2 p) {
      final x = p.x - pivot.x, y = p.y - pivot.y;
      return Vector2(pivot.x + math.cos(theta) * x - math.sin(theta) * y,
          pivot.y + math.sin(theta) * x + math.cos(theta) * y);
    }

    for (final (lx, ly, leaf) in [
      (425.0, 1680.0, leaves[1]),
      (1175.0, 1680.0, leaves[2]),
      (800.0, 1300.0, leaves[3]),
    ]) {
      expect(
          index.pickInto(rotated(shifted(world(lx, ly))), 1.0,
              const QueryFilter.all(), hit),
          isTrue,
          reason: 'leaf at ($lx, $ly) after move and rotate');
      expect(hit.entity, leaf);
    }
    expect(doc.validate(), isEmpty);
  });
}
