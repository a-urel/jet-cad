import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter/rendering.dart' show RenderCustomPaint;
import 'package:flutter/widgets.dart'
    show
        Center,
        CustomPaint,
        Directionality,
        Listenable,
        SizedBox,
        TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart' show kDefaultOriginX;
import 'package:jet_cad_2d_flutter/src/camera_controller.dart'
    show CameraController, rebaseOriginFor;
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/selection_overlay.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/selection_fixture.dart';

/// A cache wired to a fresh controller, both torn down with the test.
(SelectionController, OutlineCache) wire(DraftDocument doc) {
  final selection = SelectionController(doc);
  addTearDown(selection.dispose);
  final cache = OutlineCache(doc, selection);
  addTearDown(cache.dispose);
  return (selection, cache);
}

GeometryPayload payload(List<double> coords, List<double> scalars) =>
    GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    );

// ---- Spec 10 D24: a drawn fill whose boundary is not drawn ---------------

/// The corpus far origin, turned 23° and scaled 1.5: a non-identity
/// similarity, so a dropped rotation, scale or translation shows (OL1).
final Transform2 kFarGroup = Transform2.translation(4500000, 1200000)
    .multiply(Transform2.rotation(23 * math.pi / 180))
    .multiply(Transform2.scale(1.5, 1.5));

/// A closed pentagon in local space, fractional and with no symmetry; the
/// first point is repeated as the last (closedness, 05 D11).
const List<double> kLoop = [
  12.5, -7.25, 310.75, 4.5, 280.125, 190.375, //
  96.625, 240.875, -20.25, 160.625, 12.5, -7.25,
];

/// A region under [owner], built by [AddRegionCommand]: its fill keeps
/// layer zero unless [fillLayer] is given; its boundary carries
/// [boundaryFlags] and, when given, [boundaryLayer].
({Handle fill, Handle boundary}) addRegion(
    DraftDocument doc, Handle owner, EntityKind kind, List<double> coords,
    {List<double> scalars = const [],
    int boundaryFlags = 0,
    Handle? fillLayer,
    Handle? boundaryLayer}) {
  final r = AddRegionCommand.allocate(
    seed: doc.handleSeed,
    owner: owner,
    boundaryKind: kind,
    boundaryPayload: payload(coords, scalars),
    layer: ReservedHandles.layerZero,
    fillColor: const TrueColor(0x3366CC),
    boundaryColor: const ByLayerColor(),
    fillTransparency: 64,
  );
  doc.commands.execute(AddRegionCommand(
    fill: r.fill.copyWith(layer: fillLayer),
    boundary: r.boundary.copyWith(flags: boundaryFlags, layer: boundaryLayer),
    boundaryPayload: r.boundaryPayload,
  ));
  return (fill: r.fill.handle, boundary: r.boundary.handle);
}

/// Whether the canvas draws the leaf [h]: `QueryFilter.rendering()`, asked
/// the way the outline cache asks it.
bool drawn(DraftDocument doc, Handle h) => FilterEvaluator(doc)
    .acceptsEntity(doc.entities.slotOf(h)!, const QueryFilter.rendering());

/// [local]'s points mapped by [t], interleaved.
List<double> mapped(Transform2 t, List<double> local) => [
      for (var i = 0; i + 1 < local.length; i += 2)
        ...() {
          final p = t.transformPoint(Vector2(local[i], local[i + 1]));
          return [p.x, p.y];
        }(),
    ];

/// [actual] equals [expected] pairwise within [tolerance].
void expectCoords(Float64List? actual, List<double> expected,
    {double tolerance = 1e-6, String? reason}) {
  expect(actual, isNotNull, reason: reason);
  expect(actual!.length, expected.length, reason: reason);
  for (var i = 0; i < expected.length; i++) {
    expect(actual[i], closeTo(expected[i], tolerance),
        reason: '${reason ?? ''} [$i]');
  }
}

void main() {
  test('the path is built in rebased space', () {
    // M-02v. The corpus this project generates sits at x = 4.5e6, where
    // float32 spacing is about half a unit — a world-space `ui.Path` would
    // land the outline off the entity it outlines.
    final doc = DraftDocument.empty();
    final leaf = addEntity(doc, doc.rootHandle, EntityKind.line,
        [kDefaultOriginX + 10, 20, kDefaultOriginX + 110, 20], []);
    final (selection, cache) = wire(doc);
    final key = SelectionKey.root(leaf);
    selection.replace([key]);

    const size = Size(800, 600);
    final camera = ViewportTransform.fit(
        Aabb2.raw(kDefaultOriginX, 0, kDefaultOriginX + 120, 100), size);
    final origin = rebaseOriginFor(camera.visibleWorld(size));
    expect(origin.x, isNot(0.0), reason: 'the fixture must be off the origin');

    final path = cache.pathFor(key, origin);
    expect(path, isNotNull);
    final left = path!.getBounds().left;
    expect(left, closeTo(10 + (kDefaultOriginX - origin.x), 1e-6));
    // The discriminating half: a world-space path would put the bound here,
    // rounded to the nearest float32 — within a quarter unit at 4.5e6.
    expect((left - (kDefaultOriginX + 10)).abs(), greaterThan(0.25),
        reason: 'an absolute world coordinate reached dart:ui');
  });

  test('the origin tag rebuilds once per change, not per call', () {
    final doc = DraftDocument.empty();
    final leaf =
        addEntity(doc, doc.rootHandle, EntityKind.line, [40, 25, 90, 65], []);
    final (selection, cache) = wire(doc);
    final key = SelectionKey.root(leaf);
    selection.replace([key]);

    final first = Vector2(64.0, 32.0);
    expect(cache.pathFor(key, first), isNotNull);
    expect(cache.debugRebuilds, 1);
    expect(cache.origin, equals(first));
    expect(cache.pathFor(key, first), isNotNull);
    expect(cache.debugRebuilds, 1, reason: 'the same origin must not rebuild');
    expect(cache.pathFor(key, Vector2(128.0, 32.0)), isNotNull);
    expect(cache.debugRebuilds, 2);
  });

  test('a DocChange inside a selected instance rebuilds the outline', () async {
    // M-02w. The edit touches neither the instance handle nor the group
    // handle, so an exact-handle rule never fires for it.
    final doc = DraftDocument.empty();
    final def = addDefinition(doc, 'Def');
    final leaf = addEntity(doc, def, EntityKind.line, [3, 1, 9, 4], []);
    final instance = addInstance(doc, def, kPlacement);
    final (selection, cache) = wire(doc);
    final key = SelectionKey.root(instance);
    selection.replace([key]);

    final before = cache.debugWorldSegmentsOf(key);
    expect(before, isNotNull);
    expect(before!.length, 4);

    doc.commands
        .execute(SetEntityGeometryCommand(leaf, payload([3, 1, 9, 40], [])));
    await Future<void>.delayed(Duration.zero);

    final after = cache.debugWorldSegmentsOf(key);
    expect(after, isNotNull);
    final moved = kPlacement.transformPoint(Vector2(9, 40));
    expect(after![2], closeTo(moved.x, 1e-9));
    expect(after[3], closeTo(moved.y, 1e-9));
    expect((after[3] - before[3]).abs(), greaterThan(1.0),
        reason: 'the stale world record survived the change');
  });

  test('an instance outline composes the placement', () {
    final doc = DraftDocument.empty();
    final def = addDefinition(doc, 'Def');
    addEntity(doc, def, EntityKind.line, [3, 1, 9, 4], []);
    final instance = addInstance(doc, def, kPlacement);
    final (selection, cache) = wire(doc);
    final key = SelectionKey.root(instance);
    selection.replace([key]);

    final segments = cache.debugWorldSegmentsOf(key);
    expect(segments, isNotNull);
    expect(segments!.length, 4);
    final p0 = kPlacement.transformPoint(Vector2(3, 1));
    final p1 = kPlacement.transformPoint(Vector2(9, 4));
    expect(segments[0], closeTo(p0.x, 1e-9));
    expect(segments[1], closeTo(p0.y, 1e-9));
    expect(segments[2], closeTo(p1.x, 1e-9));
    expect(segments[3], closeTo(p1.y, 1e-9));
  });

  test('a grouped leaf inside a definition composes the group transform too',
      () {
    final doc = DraftDocument.empty();
    final def = addDefinition(doc, 'Def');
    final group = addGroup(
        doc,
        def,
        Transform2.translation(-17, 23)
            .multiply(Transform2.rotation(-math.pi / 5)));
    addEntity(doc, group, EntityKind.line, [3, 1, 9, 4], []);
    final instance = addInstance(doc, def, kPlacement);
    final (selection, cache) = wire(doc);
    final key = SelectionKey.root(instance);
    selection.replace([key]);

    final composed = kPlacement.multiply(doc.tree.accumulatedTransform(group));
    final segments = cache.debugWorldSegmentsOf(key);
    expect(segments, isNotNull);
    expect(segments!.length, 4);
    final p0 = composed.transformPoint(Vector2(3, 1));
    final p1 = composed.transformPoint(Vector2(9, 4));
    expect(segments[0], closeTo(p0.x, 1e-9));
    expect(segments[1], closeTo(p0.y, 1e-9));
    expect(segments[2], closeTo(p1.x, 1e-9));
    expect(segments[3], closeTo(p1.y, 1e-9));
    // Dropping the group transform would leave the leaf at the placement
    // alone; the fixture is built so the two are far apart.
    final unplaced = kPlacement.transformPoint(Vector2(3, 1));
    expect((segments[0] - unplaced.x).abs(), greaterThan(1.0));
  });

  test('a leaf the rendering filter rejects is left out of the outline', () {
    // A2. The outline is a statement about what is drawn, so it follows the
    // canvas's own filter: `QueryFilter.rendering()` — hidden out, locked
    // still drawn. A hidden leaf otherwise gets a selection outline with no
    // geometry under it.
    final doc = DraftDocument.empty();
    final group = addGroup(
        doc,
        doc.rootHandle,
        Transform2.translation(-17, 23)
            .multiply(Transform2.rotation(-math.pi / 5)));
    addEntity(doc, group, EntityKind.line, [3, 1, 9, 4], []);
    addEntity(doc, group, EntityKind.line, [40, 60, 44, 70], [],
        layer: addLayer(doc, 'Hidden', visible: false));
    // A locked-but-visible leaf still draws, so it stays in the outline.
    addEntity(doc, group, EntityKind.line, [70, 80, 74, 90], [],
        layer: addLayer(doc, 'Locked', locked: true));
    final (selection, cache) = wire(doc);
    final key = SelectionKey.root(group);
    selection.replace([key]);

    final toWorld = doc.tree.accumulatedTransform(group);
    final segments = cache.debugWorldSegmentsOf(key);
    expect(segments, isNotNull);
    expect(segments!.length, 8,
        reason: 'the visible leaf and the locked one, not the hidden one');
    for (final (i, local) in [
      Vector2(3, 1),
      Vector2(9, 4),
      Vector2(70, 80),
      Vector2(74, 90),
    ].indexed) {
      final p = toWorld.transformPoint(local);
      expect(segments[i * 2], closeTo(p.x, 1e-9));
      expect(segments[i * 2 + 1], closeTo(p.y, 1e-9));
    }
    // The discriminating half: the hidden leaf's world x is far from both of
    // the recorded chains, so its absence cannot be a rounding accident.
    final hidden = toWorld.transformPoint(Vector2(40, 60));
    for (var i = 0; i < segments.length; i += 2) {
      expect((segments[i] - hidden.x).abs(), greaterThan(1.0));
    }
  });

  test(
      'a circle under a non-uniform instance scale is emitted with the '
      'geometric-mean radius', () {
    final doc = DraftDocument.empty();
    final def = addDefinition(doc, 'Def');
    addEntity(doc, def, EntityKind.circle, [5, 3], [2]);
    // det = 16, so the world radius is 2 * 4 = 8 — neither 2 * 2 nor 2 * 8.
    final placement = Transform2.translation(40, -25)
        .multiply(Transform2.rotation(math.pi / 7))
        .multiply(Transform2.scale(2, 8));
    final instance = addInstance(doc, def, placement);
    final (selection, cache) = wire(doc);
    final key = SelectionKey.root(instance);
    selection.replace([key]);

    final origin = Vector2(32.0, -32.0);
    final bounds = cache.pathFor(key, origin)!.getBounds();
    expect(bounds.width, closeTo(16.0, 1e-3));
    expect(bounds.height, closeTo(16.0, 1e-3));
    final centre = placement.transformPoint(Vector2(5, 3));
    expect(bounds.center.dx, closeTo(centre.x - origin.x, 1e-3));
    expect(bounds.center.dy, closeTo(centre.y - origin.y, 1e-3));
  });

  test('keys dropped from the selection leave the cache', () {
    final doc = DraftDocument.empty();
    final a =
        addEntity(doc, doc.rootHandle, EntityKind.line, [40, 25, 90, 65], []);
    final b =
        addEntity(doc, doc.rootHandle, EntityKind.line, [140, 25, 190, 65], []);
    final (selection, cache) = wire(doc);
    final ka = SelectionKey.root(a), kb = SelectionKey.root(b);
    selection.replace([ka, kb]);
    final origin = Vector2(64.0, 32.0);
    expect(cache.pathFor(ka, origin), isNotNull);
    expect(cache.pathFor(kb, origin), isNotNull);

    selection.replace([ka]);
    expect(cache.debugWorldSegmentsOf(kb), isNull);
    expect(cache.pathFor(kb, origin), isNull);
    expect(cache.debugWorldSegmentsOf(ka), isNotNull);

    // The hover is cached beside the selection, and leaves with it.
    selection.setHover(kb);
    expect(cache.debugWorldSegmentsOf(kb), isNotNull);
    selection.setHover(null);
    expect(cache.debugWorldSegmentsOf(kb), isNull);
  });

  test('a point key answers its world position, a line key does not', () {
    // The overlay's affordance: a point has no extent, so its path is a lone
    // `moveTo` and draws nothing. The group carries the fixture off the
    // identity as well as off the origin.
    final doc = DraftDocument.empty();
    final group = addGroup(doc, doc.rootHandle, kPlacement);
    final dot = addEntity(doc, group, EntityKind.point, [13, -7], []);
    final line =
        addEntity(doc, doc.rootHandle, EntityKind.line, [40, 25, 90, 65], []);
    final (selection, cache) = wire(doc);
    // A leaf owned by a group is selected through the group (spec D2).
    final kDot = SelectionKey.root(group);
    final kLine = SelectionKey.root(line);
    selection.replace([kDot, kLine]);

    final expected = kPlacement.transformPoint(Vector2(13, -7));
    final actual = cache.worldPointOf(kDot);
    expect(actual, isNotNull);
    expect(actual!.x, closeTo(expected.x, 1e-9));
    expect(actual.y, closeTo(expected.y, 1e-9));
    // Not the untransformed point: the group placement is load-bearing here.
    expect((actual.x - 13).abs(), greaterThan(1.0));

    expect(cache.worldPointOf(kLine), isNull);
    expect(cache.worldPointOf(SelectionKey.root(doc.handleSeed.next())), isNull,
        reason: 'an unknown key has no point');

    // The leaf key itself answers too, through the other branch of the walk:
    // a leaf whose owner is a group carries that group's transform.
    final kLeaf = SelectionKey.root(dot);
    selection.replace([kLeaf]);
    final viaLeaf = cache.worldPointOf(kLeaf);
    expect(viaLeaf, isNotNull);
    expect(viaLeaf!.x, closeTo(expected.x, 1e-9));
    expect(viaLeaf.y, closeTo(expected.y, 1e-9));
  });

  test('a rotated text is recorded as its four oriented world corners', () {
    final doc = DraftDocument.empty(measurer: const _FixedMeasurer());
    final def = addDefinition(doc, 'Def');
    // Height 40, rotated 0.4 rad, right/top justified — nothing here sits at
    // a default, so a dropped attribute or a dropped `box.local` shows.
    final attrs = packTextAttrs(h: TextJustifyH.right, v: TextJustifyV.top);
    final text = addText(doc, def,
        text: 'JET',
        textStyle: ReservedHandles.standardTextStyle,
        coords: [6, -2],
        scalars: [40, 0.4, 0, 0],
        textAttrs: attrs);
    final instance = addInstance(doc, def, kPlacement);
    final (selection, cache) = wire(doc);
    final key = SelectionKey.root(instance);
    selection.replace([key]);

    final slot = doc.entities.slotOf(text)!;
    final style = doc.textStyleOf(doc.entities.textStyleAt(slot));
    final box = textBoxOf(
      doc.geometry.peek(doc.entities.geomIndexAt(slot)),
      attrs,
      style,
      doc.textMeasurer.measure(text: 'JET', style: style),
    );
    expect(box, isNotNull, reason: 'the fixture must not be a degenerate box');

    // toWorld × box.local, applied to the four box corners, closed back on
    // the first — five points, ten doubles.
    final m = kPlacement.multiply(box!.local);
    final xs = [box.minX, box.maxX, box.maxX, box.minX, box.minX];
    final ys = [box.minY, box.minY, box.maxY, box.maxY, box.minY];
    final segments = cache.debugWorldSegmentsOf(key);
    expect(segments, isNotNull);
    expect(segments!.length, 10,
        reason: 'a closed quad, first corner repeated');
    for (var i = 0; i < 5; i++) {
      final p = m.transformPoint(Vector2(xs[i], ys[i]));
      expect(segments[i * 2], closeTo(p.x, 1e-9));
      expect(segments[i * 2 + 1], closeTo(p.y, 1e-9));
    }
    // The quad is genuinely oriented, not an axis-aligned box: no two
    // adjacent corners share an ordinate.
    expect((segments[0] - segments[2]).abs(), greaterThan(1e-6));
    expect((segments[1] - segments[3]).abs(), greaterThan(1e-6));
  });

  test(
      'a mirrored arc flips its sweep and takes its start from the '
      'transformed start point', () {
    final doc = DraftDocument.empty();
    final def = addDefinition(doc, 'Def');
    const cx = 5.0, cy = 3.0, r0 = 2.0, s0 = 0.9, sweep0 = 1.7;
    addEntity(doc, def, EntityKind.arc, [cx, cy], [r0, s0, sweep0]);
    // A negative determinant: the mirror flips the turning sense.
    final placement = kPlacement.multiply(Transform2.scale(1, -1));
    expect(placement.determinant, lessThan(0));
    final instance = addInstance(doc, def, placement);
    final (selection, cache) = wire(doc);
    final key = SelectionKey.root(instance);
    selection.replace([key]);

    final centre = placement.transformPoint(Vector2(cx, cy));
    final startPoint = placement.transformPoint(
        Vector2(cx + r0 * math.cos(s0), cy + r0 * math.sin(s0)));
    final start = math.atan2(startPoint.y - centre.y, startPoint.x - centre.x);
    final radius = r0 * placement.scaleMagnitude;

    final arcs = cache.debugWorldArcsOf(key);
    expect(arcs, isNotNull);
    expect(arcs!.length, 5);
    expect(arcs[0], closeTo(centre.x, 1e-9));
    expect(arcs[1], closeTo(centre.y, 1e-9));
    expect(arcs[2], closeTo(radius, 1e-9));
    expect(arcs[3], closeTo(start, 1e-9),
        reason: 'the world start angle comes from the transformed start '
            'point, never from the stored one');
    expect(arcs[4], closeTo(-sweep0, 1e-9),
        reason: 'a negative determinant flips the sweep');
    // The stored start angle survives the mirror only by accident; this
    // fixture is built so it does not.
    expect((arcs[3] - s0).abs(), greaterThan(0.1));

    // And the rebased path really covers that sweep. `getBounds` returns the
    // conic control-point bound, which contains the curve but is wider than
    // it, so containment is the exact statement available here.
    final origin = Vector2(256.0, -128.0);
    final bounds = cache.pathFor(key, origin)!.getBounds();
    final exact = arcBounds(centre - origin, radius, start, -sweep0);
    // `slack` is float32 headroom, not geometric slack: the path stores the
    // rebased coordinates in float32, whose spacing at |x| ~ 73 is about
    // 8e-6. It is three orders below the radius, so it cannot hide a wrong
    // start angle or an unflipped sweep.
    const slack = 1e-3;
    expect(bounds.left, lessThanOrEqualTo(exact.minX + slack));
    expect(bounds.top, lessThanOrEqualTo(exact.minY + slack));
    expect(bounds.right, greaterThanOrEqualTo(exact.maxX - slack));
    expect(bounds.bottom, greaterThanOrEqualTo(exact.maxY - slack));
    // Not vacuous: the hull is at most a conic's bulge wider than the arc.
    expect(bounds.width, lessThan(2 * radius * math.sqrt2 + slack));
  });

  test(
      'worldBoundsOf: an arc by arcBounds, a point by its position '
      '(M-03ah)', () {
    final doc = DraftDocument.empty();
    // Start 2.9, sweep −1.6: clockwise to 1.3, through the top extreme
    // (π/2) and no other.
    final arc = addEntity(
        doc, doc.rootHandle, EntityKind.arc, [7050, 3200], [40, 2.9, -1.6]);
    final dot =
        addEntity(doc, doc.rootHandle, EntityKind.point, [7250, 3300], []);
    final line = addEntity(
        doc, doc.rootHandle, EntityKind.line, [7010, 3020, 7130, 3060], []);
    final (selection, cache) = wire(doc);
    selection.replace([
      SelectionKey.root(arc),
      SelectionKey.root(dot),
      SelectionKey.root(line),
    ]);

    final a = cache.worldBoundsOf(SelectionKey.root(arc))!;
    expect(a.minX, closeTo(7050 + 40 * math.cos(2.9), 1e-9));
    expect(a.maxX, closeTo(7050 + 40 * math.cos(2.9 - 1.6), 1e-9));
    expect(a.minY, closeTo(3200 + 40 * math.sin(2.9), 1e-9));
    expect(a.maxY, closeTo(3240, 1e-9),
        reason: 'the top extreme is inside the sweep; a control-point box '
            'or a full circle would say otherwise');
    final p = cache.worldBoundsOf(SelectionKey.root(dot))!;
    expect([p.minX, p.minY, p.maxX, p.maxY], [7250, 3300, 7250, 3300],
        reason: 'a point is its position, never Rect.zero');
    expect(cache.worldBoundsOf(SelectionKey.root(line))!.maxY, 3060);
    expect(
        cache.worldBoundsOf(SelectionKey.root(const Handle(999999))), isNull);
  });

  test(
      'OL1 a selected group with a fill whose boundary is invisible '
      'outlines the boundary\'s loop, under a rotated, translated, scaled '
      'group at the corpus far origin', () {
    final doc = DraftDocument.empty();
    final group = addGroup(doc, doc.rootHandle, kFarGroup);
    final loop = addRegion(doc, group, EntityKind.polyline, kLoop,
        boundaryFlags: EntityFlags.invisible);
    final disc = addRegion(doc, group, EntityKind.circle, [150.25, 90.75],
        scalars: [40.5], boundaryFlags: EntityFlags.invisible);
    // Premises: the fills are drawn, their boundaries are not, and the tree
    // carries exactly the placement the oracle uses.
    for (final r in [loop, disc]) {
      expect(drawn(doc, r.fill), isTrue);
      expect(drawn(doc, r.boundary), isFalse);
    }
    List<double> six(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];
    expect(six(doc.tree.accumulatedTransform(group)), six(kFarGroup));
    final (selection, cache) = wire(doc);
    final key = SelectionKey.root(group);
    selection.replace([key]);

    // The loop: the boundary's local points through the group, closed.
    final segments = cache.debugWorldSegmentsOf(key);
    expectCoords(segments, mapped(kFarGroup, kLoop),
        reason: 'the boundary loop under the group transform');
    expect(segments![0], segments[segments.length - 2]);
    expect(segments[1], segments[segments.length - 1]);
    // Not the untransformed loop: the far origin is load-bearing.
    expect(segments[0], greaterThan(4400000));

    // A circle boundary gives its whole circle, as the circle arm does.
    final centre = kFarGroup.transformPoint(Vector2(150.25, 90.75));
    expectCoords(cache.debugWorldArcsOf(key),
        [centre.x, centre.y, 40.5 * 1.5, 0, 2 * math.pi],
        tolerance: 1e-9, reason: 'the circle boundary');

    // The selection box follows (worldBoundsOf reads the same records).
    final box = cache.worldBoundsOf(key)!;
    final xs = [
      for (var i = 0; i < segments.length; i += 2) segments[i],
    ];
    expect(box.minX, closeTo(xs.reduce(math.min), 1e-6));
    expect(box.maxX, closeTo(xs.reduce(math.max), 1e-6));
  });

  test(
      'OL2 a visible boundary is outlined once; a hidden fill, a missing '
      'boundary and a boundary with another owner outline nothing; a visible '
      'fill whose boundary sits on a hidden layer outlines its loop; a '
      'visible boundary on a locked layer is outlined once', () {
    Transform2 placement(int i) =>
        Transform2.translation(4500000 + 1000.5 * i, 1200000 - 700.25 * i)
            .multiply(Transform2.rotation(0.4 + 0.15 * i))
            .multiply(Transform2.scale(1.5, 1.5));
    final built = DraftDocument.empty();
    final hidden = addLayer(built, 'Hidden', visible: false);
    final locked = addLayer(built, 'Locked', locked: true);
    final groups = [
      for (var i = 0; i < 7; i++)
        addGroup(built, built.rootHandle, placement(i)),
    ];
    final [visible, hiddenFill, missing, foreign, onHidden, other, onLocked] =
        groups;
    addRegion(built, visible, EntityKind.polyline, kLoop);
    addRegion(built, hiddenFill, EntityKind.polyline, kLoop,
        fillLayer: hidden, boundaryFlags: EntityFlags.invisible);
    final lost = addRegion(built, missing, EntityKind.polyline, kLoop,
        boundaryFlags: EntityFlags.invisible);
    final moved = addRegion(built, foreign, EntityKind.polyline, kLoop,
        boundaryFlags: EntityFlags.invisible);
    final layered = addRegion(built, onHidden, EntityKind.polyline, kLoop,
        boundaryLayer: hidden);
    final lockedRegion = addRegion(built, onLocked, EntityKind.polyline, kLoop,
        boundaryLayer: locked);
    // A line of its own, so `other` has an outline of its own to compare.
    addEntity(built, other, EntityKind.line, [0.5, 0.25, 30.75, 10.5], []);

    // The malformed cases by an edited encoding (05's loaders keep them):
    // one boundary dropped, one boundary moved to another owner.
    final json =
        (jsonDecode(jsonEncode(DraftDocumentCodec.encode(built))) as Map)
            .cast<String, Object?>();
    final entities = json['entities']! as List;
    Map<String, Object?> recordOf(Object? e) =>
        ((e! as Map)['record']! as Map).cast<String, Object?>();
    entities.removeWhere(
        (e) => Handle.fromJson(recordOf(e)['handle']) == lost.boundary);
    for (final e in entities) {
      final record = recordOf(e);
      if (Handle.fromJson(record['handle']) == moved.boundary) {
        (e! as Map)['record'] = {...record, 'owner': other.toJson()};
      }
    }
    final doc = DraftDocumentCodec.decode(json);

    // Premises, read from the loaded document.
    final codes = {
      for (final d in doc.validate())
        if (d.code.startsWith('fill.')) (d.code, d.handles.first),
    };
    expect(codes, {
      (ValidationCodes.fillBoundaryMissing, lost.fill),
      (ValidationCodes.fillBoundaryForeignOwner, moved.fill),
    });
    expect(doc.entities.ownerAt(doc.entities.slotOf(moved.boundary)!), other);
    expect(drawn(doc, moved.fill), isTrue);
    expect(drawn(doc, moved.boundary), isFalse);
    expect(drawn(doc, layered.fill), isTrue);
    expect(drawn(doc, layered.boundary), isFalse,
        reason: 'the boundary is rejected by its layer alone');
    expect(doc.entities.flagsAt(doc.entities.slotOf(layered.boundary)!), 0,
        reason: 'not by its flag: a rule keyed on the flag misses this case');
    // A locked layer is drawn but not picked: `rendering()` accepts the
    // boundary where `picking()` would reject it, so a rule asking the wrong
    // filter outlines this loop twice.
    expect(drawn(doc, lockedRegion.boundary), isTrue);
    expect(
        FilterEvaluator(doc).acceptsEntity(
            doc.entities.slotOf(lockedRegion.boundary)!,
            const QueryFilter.picking()),
        isFalse,
        reason: 'the premise: picking rejects a locked leaf');

    final (selection, cache) = wire(doc);
    selection.replace([for (final g in groups) SelectionKey.root(g)]);
    Float64List? of(Handle g) =>
        cache.debugWorldSegmentsOf(SelectionKey.root(g));

    expectCoords(of(visible), mapped(placement(0), kLoop),
        reason: 'a visible boundary: its own leaf, once');
    expect(of(hiddenFill), isEmpty, reason: 'a hidden fill');
    expect(of(missing), isEmpty, reason: 'a missing boundary');
    expect(of(foreign), isEmpty, reason: 'a boundary with another owner');
    expectCoords(of(onHidden), mapped(placement(4), kLoop),
        reason: 'a visible fill whose boundary sits on a hidden layer');
    expectCoords(of(other), mapped(placement(5), [0.5, 0.25, 30.75, 10.5]),
        reason: 'the foreign boundary is drawn by nobody: invisible');
    expectCoords(of(onLocked), mapped(placement(6), kLoop),
        reason: 'a visible boundary on a locked layer: its own leaf, once');
  });

  testWidgets(
      'OL3 steady state: a selected group with an invisible-boundary fill '
      'rebuilds no path across frames', (tester) async {
    final doc = DraftDocument.empty();
    final group = addGroup(doc, doc.rootHandle, kFarGroup);
    addRegion(doc, group, EntityKind.polyline, kLoop,
        boundaryFlags: EntityFlags.invisible);
    final selection = SelectionController(doc);
    final cache = OutlineCache(doc, selection);
    final index = SpatialIndex(doc);
    final world = Aabb2.raw(4499500, 1199500, 4501000, 1201000);
    const size = Size(400, 300);
    final camera = CameraController(ViewportTransform.fit(world, size));
    final context = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);
    final tools = ToolController(initial: SelectTool(), context: context);
    addTearDown(() {
      tools.dispose();
      camera.dispose();
      index.dispose();
      cache.dispose();
      selection.dispose();
    });
    var paints = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: CustomPaint(
            painter: SelectionOverlayPainter(
              selection: selection,
              tools: tools,
              camera: camera,
              outlines: cache,
              repaint: Listenable.merge([selection, tools, camera, cache]),
              onPaintForTest: () => paints++,
            ),
            size: size,
          ),
        ),
      ),
    ));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    final key = SelectionKey.root(group);
    selection.replace([key]);
    await tester.pump();

    final origin = Vector2.copy(cache.origin);
    expect(origin.x, isNot(0.0), reason: 'the rebase origin is non-zero');
    final path = cache.pathFor(key, origin);
    expect(path, isNotNull);
    expect(path!.getBounds().width, greaterThan(100),
        reason: 'the ring is outlined: the premise of a steady state');
    final rebuilds = cache.debugRebuilds;
    expect(rebuilds, greaterThan(0));

    for (var i = 0; i < 10; i++) {
      expect(identical(cache.pathFor(key, origin), path), isTrue);
    }
    expect(cache.debugRebuilds, rebuilds, reason: 'ten pathFor calls');

    final render = tester.renderObject<RenderCustomPaint>(
        find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is SelectionOverlayPainter));
    final before = paints;
    for (var i = 0; i < 10; i++) {
      render.markNeedsPaint();
      await tester.pump();
    }
    expect(paints, before + 10, reason: 'ten frames were painted');
    expect(cache.debugRebuilds, rebuilds, reason: 'ten pumped frames');
    expect(identical(cache.pathFor(key, origin), path), isTrue);
  });
}

/// Fixed, deliberately asymmetric metrics: a measurer whose ascent, descent
/// and advance differ means a layout that swapped two of them would show.
class _FixedMeasurer implements TextMeasurer {
  const _FixedMeasurer();

  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) =>
      const TextMetrics(
        advanceWidth: 260,
        ascent: 78,
        descent: 22,
        capHeight: 70,
      );
}

/// A text entity with a real string, style and packed attributes — the three
/// things [addEntity] cannot carry. Mirrors the engine's own `pick_test.dart`
/// helper rather than importing across packages.
Handle addText(
  DraftDocument doc,
  Handle owner, {
  required String text,
  required Handle textStyle,
  required List<double> coords,
  required List<double> scalars,
  int textAttrs = 0,
}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.text,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
      text: text,
      textStyle: textStyle,
      textAttrs: textAttrs,
    ),
    payload: payload(coords, scalars),
  ));
  return handle;
}
