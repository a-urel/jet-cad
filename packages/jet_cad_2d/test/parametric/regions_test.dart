// Generated regions in the planner (spec 07 D8): a fill and the closed
// POLYLINE it names, matched through the fill, rewritten in place, added
// fill first and removed through the boundary.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

EntityKind kindOf(DraftDocument doc, Handle h) =>
    doc.entities.kindAt(doc.entities.slotOf(h)!);

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

/// The boundary [fill] names: its payload's one scalar.
Handle boundaryOf(DraftDocument doc, Handle fill) {
  final p = payloadOf(doc, fill);
  expect(p.coords, isEmpty);
  expect(p.scalars, hasLength(1));
  return Handle(p.scalars[0].toInt());
}

/// Region [i]'s boundary exactly as the client generates it (stored
/// values: exact `==`).
Float64List loopCoords(RegionRect p, int i) =>
    polylinePayload(regionRectLoop(p, i), closed: true).coords;

Float64List diagonal(RegionRect p) =>
    linePayload(Vector2(0, 0), Vector2(p.width, p.height)).coords;

/// The area the cached triangulation of [boundary] covers, from the
/// boundary's current coordinates.
double triangleArea(DraftDocument doc, Handle boundary) {
  final t = doc.fills.trianglesFor(boundary)!;
  final c = payloadOf(doc, boundary).coords;
  var area = 0.0;
  for (var k = 0; k < t.length; k += 3) {
    final a = t[k] * 2, b = t[k + 1] * 2, d = t[k + 2] * 2;
    area += ((c[b] - c[a]) * (c[d + 1] - c[a + 1]) -
                (c[d] - c[a]) * (c[b + 1] - c[a + 1]))
            .abs() /
        2;
  }
  return area;
}

/// [g]'s children as (kind, handle) pairs, ascending.
List<(EntityKind, int)> shape(DraftDocument doc, Handle g) => [
      for (final k in kids(doc, g)) (kindOf(doc, k), k.value),
    ];

/// Asserts every region of [g] is whole: each fill names a live polyline
/// child of [g] that names it back, and every polyline child is some
/// fill's boundary. Returns the boundaries in fill order.
List<Handle> expectRegionsWhole(DraftDocument doc, Handle g) {
  final ks = kids(doc, g);
  final fills = [
    for (final k in ks)
      if (kindOf(doc, k) == EntityKind.fill) k
  ];
  final boundaries = [for (final f in fills) boundaryOf(doc, f)];
  for (var i = 0; i < fills.length; i++) {
    expect(ks, contains(boundaries[i]), reason: 'fill $i names a live child');
    expect(kindOf(doc, boundaries[i]), EntityKind.polyline);
    expect(doc.fills.fillsOf(boundaries[i]), [fills[i]]);
    expect(fills[i].value, lessThan(boundaries[i].value),
        reason: 'a region\'s fill draws beneath its boundary');
  }
  for (final k in ks) {
    if (kindOf(doc, k) == EntityKind.polyline) {
      expect(boundaries, contains(k), reason: '${k.toHex()} is no orphan');
    }
  }
  return boundaries;
}

/// The select tool's group delete (select_tool.dart `_groupCascade`):
/// leaves except the fills whose boundary is also going, then the node.
DraftCommand deleteLikeSelectTool(DraftDocument doc, Handle g) =>
    CompoundCommand([
      for (final k in kids(doc, g))
        if (kindOf(doc, k) != EntityKind.fill) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

void main() {
  test(
      'RG1 a new object gets fill < boundary < line, and the fill names '
      'its boundary', () {
    final doc = paramDoc();
    const p = RegionRect(2000, 1000, 1);
    doc.commands.execute(create(doc, hA, atA, p));
    final base = hA.value;
    expect(shape(doc, hA), [
      (EntityKind.fill, base + 1),
      (EntityKind.polyline, base + 2),
      (EntityKind.line, base + 3),
    ]);
    final [fill, boundary, line] = kids(doc, hA);
    expect(boundaryOf(doc, fill), boundary);
    expect(doc.fills.fillsOf(boundary), [fill]);
    expect(payloadOf(doc, boundary).coords, loopCoords(p, 0));
    expect(payloadOf(doc, line).coords, diagonal(p));
    expect(triangleArea(doc, boundary), closeTo(2000 * 1000, 1e-6));
    // In world space the boundary sits on A's rotated, off-origin frame.
    final m = doc.tree.accumulatedTransform(hA);
    final c = payloadOf(doc, boundary).coords;
    final far = m.transformPoint(Vector2(c[4], c[5]));
    final want = atA.transformPoint(Vector2(2000, 1000));
    expect(far.x, closeTo(want.x, 1e-9));
    expect(far.y, closeTo(want.y, 1e-9));
    expect(ParametricSystem(doc, catalog).drift(), isEmpty);
  });

  test(
      'RG2 a width edit rewrites each boundary in place: handles kept, '
      'fill re-triangulated, one undo step, exact undo/redo', () {
    final doc = paramDoc();
    const p0 = RegionRect(2000, 1000, 2);
    const p1 = RegionRect(2600, 1400, 2);
    doc.commands.execute(create(doc, hA, atA, p0));
    // A neighbour on its own rotated frame: it overlaps A, so it is in the
    // closure, and its own children must not move.
    doc.commands
        .execute(create(doc, hB, onA(900, 300, 0.4), const ClipRect(400, 900)));
    final handles = kids(doc, hA);
    final bKids = kids(doc, hB);
    final bLines = worldSegments(doc, hB);
    final fills = [handles[0], handles[1]];
    final fillPayloads = [for (final f in fills) payloadOf(doc, f).scalars];
    final before = canon(doc);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(SetComponentCommand<RegionRect>(hA, p1));

    expect(kids(doc, hA), handles);
    expect(kids(doc, hB), bKids);
    expect(worldSegments(doc, hB), bLines);
    expect(doc.commands.undoDepth, depth + 1);
    final boundaries = expectRegionsWhole(doc, hA);
    for (var i = 0; i < 2; i++) {
      expect(payloadOf(doc, fills[i]).scalars, fillPayloads[i],
          reason: 'the fill record is never rewritten');
      // The i-th region goes to the i-th fill, ascending.
      expect(payloadOf(doc, boundaries[i]).coords, loopCoords(p1, i));
      expect(doc.fills.trianglesFor(boundaries[i]),
          triangulationFor(EntityKind.polyline, payloadOf(doc, boundaries[i])));
      final d = 20.0 * i;
      expect(triangleArea(doc, boundaries[i]),
          closeTo((2600 - d) * (1400 - d), 1e-6));
    }
    final line = kids(doc, hA).last;
    expect(payloadOf(doc, line).coords, diagonal(p1));
    expect(ParametricSystem(doc, catalog).drift(), isEmpty);

    final after = canon(doc);
    doc.commands.undo();
    expect(canon(doc), before);
    expect(payloadOf(doc, boundaries[0]).coords, loopCoords(p0, 0));
    expect(triangleArea(doc, boundaries[0]), closeTo(2000 * 1000, 1e-6));
    doc.commands.redo();
    expect(canon(doc), after);
    expect(kids(doc, hA), handles);
  });

  test(
      'RG3 count 1 -> 2 adds one region above the seed, fill first; '
      '2 -> 1 removes the surplus pair, leaving no orphan (M-07m)', () {
    final doc = paramDoc();
    const p1 = RegionRect(2000, 1000, 1);
    const p2 = RegionRect(2000, 1000, 2);
    doc.commands.execute(create(doc, hA, atA, p1));
    final [f1, b1, line] = kids(doc, hA);
    final seed = doc.handleSeed.current.value;

    doc.commands.execute(SetComponentCommand<RegionRect>(hA, p2));
    expect(shape(doc, hA), [
      (EntityKind.fill, f1.value),
      (EntityKind.polyline, b1.value),
      (EntityKind.line, line.value),
      (EntityKind.fill, seed + 1),
      (EntityKind.polyline, seed + 2),
    ]);
    expect(expectRegionsWhole(doc, hA), [b1, Handle(seed + 2)]);
    expect(payloadOf(doc, b1).coords, loopCoords(p2, 0));
    expect(payloadOf(doc, Handle(seed + 2)).coords, loopCoords(p2, 1));
    expect(triangleArea(doc, Handle(seed + 2)), closeTo(1980 * 980, 1e-6));
    final two = canon(doc);

    doc.commands.execute(SetComponentCommand<RegionRect>(hA, p1));
    expect(kids(doc, hA), [f1, b1, line]);
    expect(expectRegionsWhole(doc, hA), [b1]);
    expect(doc.entities.slotOf(Handle(seed + 1)), isNull);
    expect(doc.entities.slotOf(Handle(seed + 2)), isNull);
    expect(doc.fills.linkCount, 1);
    expect(doc.fills.trianglesFor(Handle(seed + 2)), isNull);
    expect(ParametricSystem(doc, catalog).drift(), isEmpty);

    doc.commands.undo();
    expect(canon(doc), two);
  });

  test('RG4 load -> save is byte-identical; drift() empty after reload', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, const RegionRect(2000, 1000, 2)));
    doc.commands.execute(
        create(doc, hB, onA(2600, -400, 0.4), const RegionRect(700, 900, 1)));
    final saved = enc(doc);
    final loaded = reload(saved);
    expect(enc(loaded), saved);
    expect(ParametricSystem(loaded, catalog).drift(), isEmpty);
    for (final g in [hA, hB]) {
      for (final b in expectRegionsWhole(loaded, g)) {
        expect(loaded.fills.trianglesFor(b), doc.fills.trianglesFor(b));
      }
    }
    // A loaded region is matched through its fill: an edit keeps handles.
    final handles = kids(loaded, hA);
    loaded.commands.execute(
        SetComponentCommand<RegionRect>(hA, const RegionRect(2100, 1000, 2)));
    expect(kids(loaded, hA), handles);
  });

  test(
      'RG5 a direct geometry edit of a region boundary is refused with '
      'GeneratedGeometryError; the fill is refused by the engine; nothing '
      'changes', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, const RegionRect(2000, 1000, 1)));
    final [fill, boundary, _] = kids(doc, hA);
    final before = enc(doc);
    final depth = doc.commands.undoDepth;
    final other = polylinePayload(
        [Vector2(0, 0), Vector2(50, 0), Vector2(50, 50)],
        closed: true);
    expect(
        () => doc.commands.execute(SetEntityGeometryCommand(boundary, other)),
        // The guard names the lowest touched generated handle (06 D6):
        // rewriting the boundary re-triangulates its fill, which is lower.
        throwsA(isA<GeneratedGeometryError>()
            .having((e) => e.handle, 'handle', fill)));
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, depth);
    // `SetEntityGeometryCommand` refuses a fill before anything is written
    // (commands.dart), so the parametric guard never sees it.
    expect(() => doc.commands.execute(SetEntityGeometryCommand(fill, other)),
        throwsA(isA<StateError>()));
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, depth);
  });

  test(
      'RG6 the select tool\'s delete (boundaries, not fills, then the node) '
      'detaches the component; undo restores the three children', () {
    final doc = paramDoc();
    const p = RegionRect(2000, 1000, 1);
    doc.commands.execute(create(doc, hA, atA, p));
    final handles = kids(doc, hA);
    final before = canon(doc);
    doc.commands.execute(deleteLikeSelectTool(doc, hA));
    expect(doc.components.get<RegionRect>(hA), isNull);
    expect(doc.tree[hA], isNull);
    for (final k in handles) {
      expect(doc.entities.slotOf(k), isNull);
    }
    expect(doc.fills.linkCount, 0);
    doc.commands.undo();
    expect(canon(doc), before);
    expect(kids(doc, hA), handles);
    expect(doc.components.get<RegionRect>(hA), p);
    expectRegionsWhole(doc, hA);
    expect(ParametricSystem(doc, catalog).drift(), isEmpty);
  });

  test(
      'RG7 a region that is open or does not triangulate throws '
      'ArgumentError; nothing recorded, bytes unchanged', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, const RegionRect(2000, 1000, 1)));
    final before = enc(doc);
    final depth = doc.commands.undoDepth;
    for (final fault in [RegionFault.open, RegionFault.crossed]) {
      // Rewriting an existing region.
      expect(
          () => doc.commands.execute(SetComponentCommand<RegionRect>(
              hA, RegionRect(2000, 1000, 1, fault: fault))),
          throwsArgumentError,
          reason: '$fault, matched');
      expect(enc(doc), before);
      expect(doc.commands.undoDepth, depth);
      // Adding one: region 0 is matched and fine, region 1 is new and
      // broken. (Not a new object: its `AddNodeCommand` raises the seed,
      // and undo never lowers it.)
      expect(
          () => doc.commands.execute(SetComponentCommand<RegionRect>(
              hA, RegionRect(2000, 1000, 2, fault: fault))),
          throwsArgumentError,
          reason: '$fault, added');
      expect(enc(doc), before);
      expect(doc.commands.undoDepth, depth);
    }
  });

  test('RG8 Generated refuses a fill; the region form is a filled polyline',
      () {
    expect(
        () => Generated(
            EntityKind.fill, linePayload(Vector2(1, 2), Vector2(3, 4))),
        throwsArgumentError);
    expect(
        Generated(EntityKind.line, linePayload(Vector2(1, 2), Vector2(3, 4)))
            .filled,
        isFalse);
    final r = Generated.region(polylinePayload(
        [Vector2(0, 0), Vector2(5, 0), Vector2(5, 5)],
        closed: true));
    expect((r.kind, r.filled), (EntityKind.polyline, true));
  });
}
