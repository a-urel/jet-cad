import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart' show kDefaultOriginX;
import 'package:jet_cad_2d_flutter/src/camera_controller.dart'
    show rebaseOriginFor;
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
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
}
