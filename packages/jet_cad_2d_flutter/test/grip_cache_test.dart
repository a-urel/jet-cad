import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/selection_style.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/grip_fixture.dart';
import 'support/selection_fixture.dart';

/// Selection, outlines and grips over [doc], built in the shell's order
/// (spec D6) and torn down with the test.
(SelectionController, OutlineCache, GripCache) wire(DraftDocument doc) {
  final selection = SelectionController(doc);
  final outlines = OutlineCache(doc, selection);
  final grips = GripCache(doc, selection, outlines);
  addTearDown(() {
    grips.dispose();
    outlines.dispose();
    selection.dispose();
  });
  return (selection, outlines, grips);
}

SelectionKey k(Handle h) => SelectionKey.root(h);

void main() {
  test(
      'grips of the selected root leaves, in world, in ascending handle '
      'order (M-03y)', () {
    final s = gripScene();
    final doc = s.document;
    final (selection, _, grips) = wire(doc);
    selection.replace([
      k(s.instA),
      k(s.arcNeg),
      k(s.group),
      k(s.room),
      k(s.circle),
      k(s.line),
    ]);
    final expected = <(Handle, Grip)>[
      for (final h in [s.line, s.room, s.circle, s.arcNeg])
        for (final g in leafGrips(
            doc.entities.kindAt(doc.entities.slotOf(h)!), payloadOf(doc, h)))
          (h, g),
    ];
    expect([for (final r in grips.grips) (r.key.target, r.grip)], expected);
    expect(grips.grips, hasLength(2 + 4 + 5 + 4),
        reason: 'a group and an instance have no grips (spec D3)');
    expect(
        [for (final r in grips.grips) r.ordinal].take(6), [0, 1, 0, 1, 2, 3]);
    expect(grips.moveCount, 2, reason: "the circle's and the arc's centres");
    expect(grips.stretchCount, 13);
  });

  test(
      'the selection box is the union of worldBoundsOf; fills alone have '
      'none (M-03ah)', () {
    final s = gripScene();
    final doc = s.document;
    final region = AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: GeometryPayload(
          coords: Float64List.fromList(
              [7600, 3000, 7700, 3000, 7700, 3100, 7600, 3000]),
          scalars: Float64List(0)),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x8844AA),
      boundaryColor: const ByLayerColor(),
    );
    doc.commands.execute(region);
    final (selection, outlines, grips) = wire(doc);
    selection.replace([k(s.arcNeg), k(s.point)]);
    final arc = outlines.worldBoundsOf(k(s.arcNeg))!;
    final box = grips.box!;
    expect(box.minX, arc.minX);
    expect(box.minY, arc.minY);
    expect(box.maxX, 7250, reason: 'the point counts by its position');
    expect(box.maxY, 3300);
    expect(grips.rotatable, isTrue);
    selection.replace([k(region.fill.handle)]);
    expect(grips.box, isNull);
    expect(grips.rotatable, isFalse,
        reason: 'a fill has no outline of its own (spec D4, Ruling 03-15)');
    expect(grips.grips, isEmpty);
  });

  test('a DocChange rebuilds the grips after the outline cache (M-03al)',
      () async {
    final s = gripScene();
    final doc = s.document;
    final (selection, _, grips) = wire(doc);
    selection.replace([k(s.line)]);
    expect(grips.grips[1].grip.x, 7130);
    var notified = 0;
    grips.addListener(() => notified++);
    doc.commands.execute(SetEntityGeometryCommand(
        s.line,
        GeometryPayload(
            coords: Float64List.fromList([7010, 3020, 7160, 3090]),
            scalars: Float64List(0))));
    await Future<void>.delayed(Duration.zero);
    expect(grips.grips[1].grip.x, 7160);
    expect(grips.box!.maxY, 3090);
    expect(notified, greaterThan(0));
  });

  test('the cap: kMaxGrips grips are kept, kMaxGrips + 1 keep none (M-03z)',
      () {
    final doc = DraftDocument.empty();
    List<double> zigzag(int n) => [
          for (var i = 0; i < n; i++) ...[
            7000.0 + i,
            i.isEven ? 3000.0 : 3005.0
          ],
        ];
    final atCap = addEntity(
        doc, doc.rootHandle, EntityKind.polyline, zigzag(kMaxGrips), []);
    final overCap = addEntity(
        doc, doc.rootHandle, EntityKind.polyline, zigzag(kMaxGrips + 1), []);
    final (selection, _, grips) = wire(doc);
    selection.replace([k(atCap)]);
    expect(grips.grips, hasLength(kMaxGrips));
    selection.replace([k(overCap)]);
    expect(grips.grips, isEmpty);
    expect(grips.box, isNotNull,
        reason: 'body move and rotate still work over the cap (spec D6)');
  });

  test(
      'a hover change does not rebuild or reset hot (Ruling 03-19; '
      'M-03ba)', () {
    final s = gripScene();
    final doc = s.document;
    final (selection, _, grips) = wire(doc);
    selection.replace([k(s.line)]);
    grips.hot = 1;
    selection.setHover(k(s.circle));
    expect(grips.hot, 1,
        reason: 'a hover change is not a selection-key change: rebuilding '
            'for it would reset hot under the pointer');
  });

  test('leaf grips are not live under a geometry denial (M-03ad)', () {
    final s = gripScene();
    final doc = s.document;
    final (selection, _, grips) = wire(doc);
    selection.replace([k(s.line), k(s.instA)]);
    final camera = gripCamera();
    addTearDown(camera.dispose);
    final m = camera.value.worldToScreenMatrix;
    final vertex = screenOf(camera, 7130, 3060);
    expect(grips.leafGripsLive, isTrue);
    expect(grips.hitTest(vertex, m), 1);
    doc.commands.permissions = DraftPermissions.runtime;
    expect(grips.leafGripsLive, isFalse);
    expect(grips.hitTest(vertex, m), -1);
    expect(grips.rotatable, isTrue,
        reason: 'the rotation grip is not a leaf grip (Ruling 03-6)');
  });

  test(
      'hitTest: the nearest, then the greater handle, then the lower '
      'ordinal (M-03ai)', () {
    // The unflipped camera exposes an `m.b`/`m.c` transposition in the
    // hit projection that the flipped one's `b == c` hides.
    for (final flipY in const [true, false]) {
      final doc = DraftDocument.empty();
      final wallA = addEntity(
          doc, doc.rootHandle, EntityKind.line, [7600, 3400, 7650, 3400], []);
      final wallB = addEntity(
          doc, doc.rootHandle, EntityKind.line, [7650, 3400, 7650, 3450], []);
      final twin = addEntity(doc, doc.rootHandle, EntityKind.polyline,
          [7800, 3400, 7800, 3400, 7850, 3420], []);
      final (selection, _, grips) = wire(doc);
      selection.replace([k(wallA), k(wallB), k(twin)]);
      final camera = gripCamera(centre: Vector2(7700, 3420), flipY: flipY);
      addTearDown(camera.dispose);
      final m = camera.value.worldToScreenMatrix;

      final corner =
          grips.hitTest(screenOf(camera, 7650, 3400) + const Offset(2, 1), m);
      expect(corner, isNonNegative, reason: 'flipY $flipY: a grip is hit');
      expect(grips.grips[corner].key.target, wallB,
          reason: 'coincident grips of two objects: the greater handle moves');
      expect(grips.grips[corner].ordinal, 0);
      final dup = grips.hitTest(screenOf(camera, 7800, 3400), m);
      expect(grips.grips[dup].key.target, twin);
      expect(grips.grips[dup].ordinal, 0,
          reason: "one object's coincident grips: the lower ordinal");
      final near =
          grips.hitTest(screenOf(camera, 7600, 3400) + const Offset(5, 0), m);
      expect(grips.grips[near].key.target, wallA);
      expect(
          grips.hitTest(screenOf(camera, 7600, 3400) + const Offset(8, 0), m),
          -1,
          reason: 'kGripHitPixels is 7');
    }
  });

  test(
      'hitTest picks the nearer object, not the greater handle '
      '(M-03bb)', () {
    final doc = DraftDocument.empty();
    // Added in this order so `far`'s handle is the *lower* one: a distance
    // bug that always prefers the earlier-seen candidate would pick `far`,
    // not the object whose grip is actually nearer the probe.
    final far = addEntity(
        doc, doc.rootHandle, EntityKind.line, [7604, 3400, 7654, 3450], []);
    final near = addEntity(
        doc, doc.rootHandle, EntityKind.line, [7600, 3400, 7650, 3450], []);
    final (selection, _, grips) = wire(doc);
    selection.replace([k(far), k(near)]);
    final camera = gripCamera();
    addTearDown(camera.dispose);
    final m = camera.value.worldToScreenMatrix;
    // The probe sits exactly on `near`'s vertex and about 4.4 screen px
    // (world 4 * scale 1.1) from `far`'s -- both inside kGripHitPixels (7),
    // at different distances.
    final probe = screenOf(camera, 7600, 3400);
    final hit = grips.hitTest(probe, m);
    expect(grips.grips[hit].key.target, near,
        reason: 'near is 0 px from the probe, far is about 4.4 px away: '
            'distance decides, not which handle is greater');
  });

  test(
      'the rotation grip hangs 24 px above the screen box, screen-up '
      '(M-03ak)', () {
    final camera = gripCamera();
    addTearDown(camera.dispose);
    final m = camera.value.worldToScreenMatrix;
    expect(m.b, isNot(closeTo(0, 1e-3)),
        reason: 'rotated, so the screen box is not the projected world box');
    const box = Aabb2.raw(7010, 3020, 7130, 3060);
    final corners = [
      for (final (x, y) in const [
        (7010.0, 3020.0),
        (7130.0, 3020.0),
        (7010.0, 3060.0),
        (7130.0, 3060.0),
      ])
        screenOf(camera, x, y),
    ];
    final minX = corners.map((c) => c.dx).reduce(math.min);
    final maxX = corners.map((c) => c.dx).reduce(math.max);
    final minY = corners.map((c) => c.dy).reduce(math.min);
    final g = rotationGripOf(box, m);
    expect(g.anchor.dx, closeTo((minX + maxX) / 2, 1e-9));
    expect(g.anchor.dy, closeTo(minY, 1e-9));
    expect(g.centre.dx, closeTo(g.anchor.dx, 1e-12));
    expect(g.centre.dy, closeTo(minY - kRotationGripOffset, 1e-9));
  });

  test(
      'a carry pending when the selection changes is dropped, not applied '
      'to the new selection (M-RFk)', () {
    final s = gripScene();
    final doc = s.document;
    final (selection, outlines, grips) = wire(doc);
    selection.replace([k(s.line)]);
    grips.carry(Transform2.rotation(0.4));
    selection.replace([k(s.room)]);
    expect(grips.frame.isIdentity, isTrue);
    final room = outlines.worldBoundsOf(k(s.room))!;
    expect([grips.box!.minX, grips.box!.maxY], [room.minX, room.maxY]);
  });

  test(
      'an unrotated frame places the grip exactly as D6 does, with the '
      "stem to the disc's rim (M-RFl)", () {
    final camera = gripCamera(flipY: false);
    addTearDown(camera.dispose);
    final m = camera.value.worldToScreenMatrix;
    const box = Aabb2.raw(7010, 3020, 7130, 3060);
    final plain = rotationGripOf(box, m);
    final moved = rotationGripOf(const Aabb2.raw(6970, 3000, 7090, 3040), m,
        Transform2.translation(40, 20));
    expect(moved.centre.dx, closeTo(plain.centre.dx, 1e-9));
    expect(moved.centre.dy, closeTo(plain.centre.dy, 1e-9));
    expect(plain.stem.dx, plain.centre.dx);
    expect(plain.stem.dy, plain.centre.dy + kRotationGripPixels / 2);
  });
}
