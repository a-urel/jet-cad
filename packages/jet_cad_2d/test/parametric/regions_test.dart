// Generated regions in the planner (spec 07 D8): a fill and the closed
// POLYLINE it names, matched through the fill, rewritten in place, added
// fill first and removed through the boundary.
import 'dart:convert';
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

Float64List centreline(RegionRect p) => regionRectCentreline(p).coords;

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
/// child of [g] that names it back, and every polyline child but the one
/// open centreline is some fill's boundary. Returns the boundaries in fill
/// order.
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
  final plain = [
    for (final k in ks)
      if (kindOf(doc, k) == EntityKind.polyline && !boundaries.contains(k)) k
  ];
  expect(plain, hasLength(1), reason: 'no orphan boundary: $plain');
  expect(payloadOf(doc, plain.single).pointCount, 2,
      reason: 'the one plain POLYLINE is the open centreline');
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
      'RG1 a new object gets fill < boundary < line < centreline, and the '
      'fill names its boundary', () {
    final doc = paramDoc();
    const p = RegionRect(2000, 1000, 1);
    doc.commands.execute(create(doc, hA, atA, p));
    final base = hA.value;
    expect(shape(doc, hA), [
      (EntityKind.fill, base + 1),
      (EntityKind.polyline, base + 2),
      (EntityKind.line, base + 3),
      (EntityKind.polyline, base + 4),
    ]);
    final [fill, boundary, line, centre] = kids(doc, hA);
    expect(boundaryOf(doc, fill), boundary);
    expect(doc.fills.fillsOf(boundary), [fill]);
    expect(payloadOf(doc, boundary).coords, loopCoords(p, 0));
    expect(payloadOf(doc, line).coords, diagonal(p));
    expect(payloadOf(doc, centre).coords, centreline(p));
    expect(doc.fills.fillsOf(centre), isEmpty);
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
    // Plain children, the POLYLINE included, never match a boundary.
    expect(shape(doc, hA).sublist(4), [
      (EntityKind.line, handles[4].value),
      (EntityKind.polyline, handles[5].value)
    ]);
    expect(payloadOf(doc, handles[4]).coords, diagonal(p1));
    expect(payloadOf(doc, handles[5]).coords, centreline(p1));
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
    final [f1, b1, line, centre] = kids(doc, hA);
    final seed = doc.handleSeed.current.value;

    doc.commands.execute(SetComponentCommand<RegionRect>(hA, p2));
    expect(shape(doc, hA), [
      (EntityKind.fill, f1.value),
      (EntityKind.polyline, b1.value),
      (EntityKind.line, line.value),
      (EntityKind.polyline, centre.value),
      (EntityKind.fill, seed + 1),
      (EntityKind.polyline, seed + 2),
    ]);
    expect(expectRegionsWhole(doc, hA), [b1, Handle(seed + 2)]);
    expect(payloadOf(doc, b1).coords, loopCoords(p2, 0));
    expect(payloadOf(doc, Handle(seed + 2)).coords, loopCoords(p2, 1));
    expect(payloadOf(doc, centre).coords, centreline(p2));
    expect(triangleArea(doc, Handle(seed + 2)), closeTo(1980 * 980, 1e-6));
    final two = canon(doc);

    doc.commands.execute(SetComponentCommand<RegionRect>(hA, p1));
    expect(kids(doc, hA), [f1, b1, line, centre]);
    expect(payloadOf(doc, centre).coords, centreline(p1));
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
    final [fill, boundary, _, _] = kids(doc, hA);
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
      'detaches the component; undo restores the four children', () {
    final doc = paramDoc();
    const p = RegionRect(2000, 1000, 1);
    doc.commands.execute(create(doc, hA, atA, p));
    final handles = kids(doc, hA);
    expect(handles, hasLength(4));
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

  test(
      'RG9 a loaded fill naming a foreign or missing boundary: an edit '
      'throws StateError and nothing changes; also a surplus fill, when the '
      'client generates fewer regions (final review m3)', () {
    // The fill corrupted is A's first, matched by an edit that keeps two
    // regions, or -- surplus -- its second, left over by an edit down to
    // one. It names B's boundary, a missing handle, B's centreline, or a
    // closed POLYLINE drafted at the root.
    //
    // Without the owner check on the surplus path the document ends the
    // same: `RemoveEntityCommand` refuses a boundary whose fill has another
    // owner (or that carries two fills), and `_run` rolls back. The check
    // refuses in the plan, before anything applies, and names the
    // malformed fill; the message is what tells the two apart.
    for (final (named, surplus) in [
      ('B boundary', false),
      ('missing', false),
      ('B boundary', true),
      ('B centreline', true),
      ('drafted', true),
    ]) {
      final why = '$named${surplus ? ', surplus' : ''}';
      final doc = paramDoc();
      doc.commands
          .execute(create(doc, hA, atA, const RegionRect(2000, 1000, 2)));
      doc.commands
          .execute(create(doc, hB, parked, const RegionRect(700, 900, 1)));
      final drafted = addDrafted(
          doc,
          EntityKind.polyline,
          polylinePayload(
              [Vector2(-500, -500), Vector2(-100, -500), Vector2(-100, -200)],
              closed: true));
      doc.commands.execute(drafted);
      final [aFill0, _, aFill1, _, _, _] = kids(doc, hA);
      expect(kindOf(doc, aFill1), EntityKind.fill);
      final [_, bBoundary, _, bCentreline] = kids(doc, hB);
      final corrupted = surplus ? aFill1 : aFill0;
      // 1500 is below the seed and names no entity.
      expect(doc.entities.slotOf(const Handle(1500)), isNull);
      final foreign = switch (named) {
        'B boundary' => bBoundary,
        'B centreline' => bCentreline,
        'drafted' => drafted.record.handle,
        _ => const Handle(1500),
      };
      final j = jsonDecode(enc(doc)) as Map<String, Object?>;
      for (final e in j['entities']! as List) {
        final entity = e as Map<String, Object?>;
        if ((entity['record']! as Map)['handle'] == corrupted.value) {
          (entity['geometry']! as Map)['scalars'] = [foreign.value.toDouble()];
        }
      }
      final loaded = reload(jsonEncode(j));
      expect(boundaryOf(loaded, corrupted), foreign);
      final before = enc(loaded);
      final kept = foreign.value == 1500
          ? null
          : (
              payloadOf(loaded, foreign).coords,
              loaded.fills.fillsOf(foreign),
            );
      expect(
          () => loaded.commands.execute(SetComponentCommand<RegionRect>(
              hA, RegionRect(surplus ? 2000 : 2100, 1000, surplus ? 1 : 2))),
          throwsA(isA<StateError>().having(
              (e) => e.message,
              'message',
              'fill ${corrupted.toHex()} of ${hA.toHex()} names '
                  '${foreign.toHex()}, which is not a child of the same '
                  'object')),
          reason: why);
      expect(enc(loaded), before, reason: why);
      expect(loaded.commands.undoDepth, 0, reason: why);
      if (kept case (final coords, final fills)) {
        expect(loaded.entities.slotOf(foreign), isNotNull, reason: why);
        expect(payloadOf(loaded, foreign).coords, coords, reason: why);
        expect(loaded.fills.fillsOf(foreign), fills, reason: why);
      }
    }
  });

  test(
      'RG10 two region objects raised in one command: either child order, '
      'same bytes (06 D11)', () {
    String run(bool bFirst) {
      final d = paramDoc();
      d.commands.execute(create(d, hA, atA, const RegionRect(2000, 1000, 1)));
      d.commands.execute(
          create(d, hB, onA(2600, -400, 0.4), const RegionRect(700, 900, 1)));
      final seed = d.handleSeed.current.value;
      final edits = [
        SetComponentCommand<RegionRect>(hA, const RegionRect(2000, 1000, 2)),
        SetComponentCommand<RegionRect>(hB, const RegionRect(700, 900, 2)),
      ];
      d.commands.execute(CompoundCommand(
          bFirst ? edits.reversed.toList() : edits,
          label: 'Edit'));
      // The closure is planned ascending: A reserves first.
      expect(shape(d, hA).sublist(4),
          [(EntityKind.fill, seed + 1), (EntityKind.polyline, seed + 2)]);
      expect(shape(d, hB).sublist(4),
          [(EntityKind.fill, seed + 3), (EntityKind.polyline, seed + 4)]);
      expect(payloadOf(d, Handle(seed + 4)).coords,
          loopCoords(const RegionRect(700, 900, 2), 1));
      return enc(d);
    }

    expect(run(true), run(false));
  });

  test(
      'RG11 a generated child is added in its Generated colour, region '
      'halves alike, and a regeneration never rewrites it; ByLayer by '
      'default (07 D3)', () {
    const regionColor = TrueColor(0x123456), plainColor = TrueColor(0x654321);
    final painted = ParametricCatalog()
      ..register<RegionRect>(
          RegionRect.id,
          RegionRect.fromJson,
          const RegionRectType(
              regionColor: regionColor, plainColor: plainColor));
    final doc = DraftDocument.empty();
    ParametricSystem(doc, painted).install();
    int colourOf(Handle h) => doc.entities.colorAt(doc.entities.slotOf(h)!);
    List<int> colours() => [for (final k in kids(doc, hA)) colourOf(k)];
    final region = encodeColor(regionColor), plain = encodeColor(plainColor);

    doc.commands.execute(create(doc, hA, atA, const RegionRect(2000, 1000, 1)));
    // fill, boundary, diagonal, centreline.
    expect(colours(), [region, region, plain, plain]);
    final boundary = kids(doc, hA)[1];
    final before = payloadOf(doc, boundary).coords.toList();
    doc.commands.execute(
        SetComponentCommand<RegionRect>(hA, const RegionRect(2600, 1000, 1)));
    expect(payloadOf(doc, boundary).coords, isNot(before), reason: 'rewritten');
    expect(colours(), [region, region, plain, plain]);
    doc.commands.execute(
        SetComponentCommand<RegionRect>(hA, const RegionRect(2600, 1000, 2)));
    expect(colours(), [region, region, plain, plain, region, region]);

    // The default client, through the default catalog: ByLayer throughout.
    final plainDoc = paramDoc();
    plainDoc.commands
        .execute(create(plainDoc, hA, atA, const RegionRect(2000, 1000, 2)));
    expect([
      for (final k in kids(plainDoc, hA))
        plainDoc.entities.colorAt(plainDoc.entities.slotOf(k)!)
    ], List.filled(6, kByLayer));
  });
}
