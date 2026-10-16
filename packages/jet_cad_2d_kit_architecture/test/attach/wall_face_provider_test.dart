// 3a Task 24 (spec C5, C2 "Shared caches", C1.5; D-06, D-07, D-08): the
// wall-face provider over FakePlanServices. Every scene is the 09c fixture's:
// walls in their own rotated groups near (1e5, −7e4), never at the identity.
// The oracle is today's attachToWall over the same runs; the expected points
// are the run's own frame, a + t·u + m·s.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart'
    show ArchitectureTypes;
import 'package:jet_cad_2d_kit_architecture/src/attach/wall_attach.dart';
import 'package:jet_cad_2d_kit_architecture/src/attach/wall_face_provider.dart';
import 'package:jet_cad_2d_kit_architecture/src/attach/wall_faces.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening_tool.dart'
    show isUsableHost;
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/place_entry.dart';
import '../support/wall_attach_fixture.dart';

/// 16 px and 6 px at 0.1 px/mm: today's capture and edge snap in world.
const double capture = 160, edge = 60;

/// An off-origin box, its front not its back: x 120..1320, y 40..640.
const SymbolBox box = SymbolBox(left: 120, right: 1320, front: 40, back: 640);

/// The point `u` along [r] and `s` into the room from its face.
Vector2 at(FaceRun r, double u, double s) => r.a + r.t * u + r.m * s;

AttachmentQuery query(Aabb2 footprint, Vector2 p,
        {bool mirrored = false,
        bool mayRotate = true,
        Transform2? current,
        Set<Handle> exclude = const {},
        Attachment? keep}) =>
    AttachmentQuery(
      footprint: footprint,
      current: current ?? Transform2.identity(),
      pointer: p,
      capture: capture,
      edgeCapture: edge,
      mirrored: mirrored,
      mayRotate: mayRotate,
      exclude: exclude,
      keep: keep,
    );

/// The kit's services over [doc], frozen [frozen], disposed at tear-down.
/// [frozen] is read at each call, so a test freezes by adding to it.
FakePlanServices servicesOf(DraftDocument doc,
    {Set<Handle> frozen = const {}}) {
  final s = FakePlanServices(
      document: doc, catalog: testCatalog(), frozen: frozen, scale: 0.1);
  addTearDown(s.dispose);
  return s;
}

List<double> linear(Transform2 g) => [g.a, g.b, g.c, g.d];
List<double> all(Transform2 g) => [g.a, g.b, g.c, g.d, g.e, g.f];

/// The committed library's [key].
SymbolEntry furniture(String key) => SymbolLibrary.decode(
        File('assets/library/furniture.jetlib').readAsBytesSync())
    .entries
    .firstWhere((e) => e.symbol.key == key);

/// [doc]'s last root-level instance.
Handle lastInstance(DraftDocument doc) {
  final root = doc.tree[doc.tree.root]! as GroupNode;
  return [
    for (final h in doc.tree.childNodesOf(root.children))
      if (doc.tree[h] is InstanceNode) h,
  ].last;
}

void main() {
  test(
      'WF-query the provider is today\'s attachToWall over the document\'s '
      'faces: kind wall-face; the footprint read as the box (front minY, '
      'back maxY); the marker the face point q; the token the run; the '
      'back-centre on the marker; beyond the capture, nothing; a 30° wall '
      'in a turned group, mirrored and not', () {
    for (final mirrored in const [false, true]) {
      final why = mirrored ? 'mirrored' : 'plain';
      final sc = freeWallScene(30, Justification.left, mirrored: mirrored);
      final provider = wallFaceProvider(servicesOf(sc.doc));
      expect(provider.kind, 'wall-face');
      final runs = faceRunsOf(sc.doc, sc.walls.single, liveOf(sc.doc),
          accept: isUsableHost);
      expect(runs, hasLength(2), reason: why);
      for (final r in runs) {
        final p = at(r, 1500, 90);
        final want = attachToWall(runs, box, p, capture,
            mirrored: mirrored,
            neighbours: [for (final _ in runs) const <FaceNeighbour>[]],
            edgeCaptureWorld: edge)!;
        final got =
            provider.attach(query(footprintOf(box), p, mirrored: mirrored))!;
        final rw = '$why ${r.side.name}';
        expect(all(got.transform), all(want.transform), reason: rw);
        expect(got.marker, want.q, reason: rw);
        expect((got.token as FaceRun).side, r.side, reason: rw);
        expect(
            (got.transform.transformPoint(box.backCentre) - got.marker).length,
            lessThan(1e-6),
            reason: '$rw: the back edge on the face');
        expect(
            provider.attach(query(footprintOf(box), at(r, 1500, capture + 1),
                mirrored: mirrored)),
            isNull,
            reason: '$rw: beyond the capture');
      }
    }
  });

  test(
      'WF-keep (D-08) with mayRotate false the symbol attaches only to a '
      'face its current turn already faces and keeps its linear part bit '
      'for bit, mirrored or not; with mayRotate true, to either face', () {
    // A wall along world x in a turned group: one face looks −y (t = (1, 0),
    // the unturned symbol's), the other +y.
    final sc = freeWallScene(0, Justification.centre);
    final provider = wallFaceProvider(servicesOf(sc.doc));
    final runs = faceRunsOf(sc.doc, sc.walls.single, liveOf(sc.doc));
    expect([for (final r in runs) r.m.y.sign], unorderedEquals([1.0, -1.0]),
        reason: 'premise: one face looks −y, the other +y');
    for (final (mirrored, current) in [
      (false, Transform2.translation(37.5, -12.25)),
      (true, const Transform2(-1, 0, 0, 1, 410.5, 88.75)),
    ]) {
      for (final r in runs) {
        final p = at(r, 1800, 60);
        final why = '${mirrored ? 'mirrored' : 'plain'} m.y ${r.m.y.sign}';
        expect(provider.attach(query(footprintOf(box), p, mirrored: mirrored)),
            isNotNull,
            reason: '$why: free to turn');
        final kept = provider.attach(query(footprintOf(box), p,
            mirrored: mirrored, mayRotate: false, current: current));
        if (r.m.y < 0) {
          expect(kept, isNotNull, reason: '$why: the face it already faces');
          expect(linear(kept!.transform), linear(current), reason: why);
        } else {
          expect(kept, isNull, reason: '$why: a face it would turn to');
        }
      }
    }
  });

  test(
      'WF-hysteresis (D-07) one capture, kept or not: 130 mm from the face '
      '(13 px) attaches with and without the previous answer; 170 mm (17 '
      'px) attaches with neither', () {
    final sc = freeWallScene(30, Justification.centre);
    final provider = wallFaceProvider(servicesOf(sc.doc));
    final r = faceRunsOf(sc.doc, sc.walls.single, liveOf(sc.doc)).first;
    final first = provider.attach(query(footprintOf(box), at(r, 1500, 50)))!;
    final near = at(r, 1500, 130), far = at(r, 1500, 170);
    expect(provider.attach(query(footprintOf(box), near)), isNotNull);
    expect(
        provider.attach(query(footprintOf(box), near, keep: first)), isNotNull,
        reason: 'kept: the same capture, not a smaller one');
    expect(provider.attach(query(footprintOf(box), far)), isNull);
    expect(provider.attach(query(footprintOf(box), far, keep: first)), isNull,
        reason: 'kept: the same capture, not a larger one');
  });

  test(
      'WF-hidden (C5, SS17) a wall on a hidden layer and a wall on a locked '
      'layer offer no face; on a visible, unlocked layer they do', () {
    for (final (name, visible, locked, offers) in const [
      ('visible', true, false, true),
      ('hidden', false, false, false),
      ('locked', true, true, false),
    ]) {
      final sc = freeWallScene(30, Justification.right);
      final zero = sc.doc.tables.layers[ReservedHandles.layerZero]!;
      // The restore form: the record exactly, past the current-layer rule.
      sc.doc.commands.execute(SetLayerCommand.restore(
          zero.copyWith(visible: visible, locked: locked)));
      final provider = wallFaceProvider(servicesOf(sc.doc));
      final r = faceRunsOf(sc.doc, sc.walls.single, liveOf(sc.doc)).first;
      final got = provider.attach(query(footprintOf(box), at(r, 1500, 40)));
      expect(got != null, offers, reason: name);
    }
  });

  test(
      'WF-hidden-toggle (C5) a layer hidden or locked while the faces are '
      'cached is seen at the very next query, before the document\'s '
      'changes are delivered (the layer panel\'s command moves the state, '
      'D-06); the toggle back is seen alike', () {
    for (final (name, visible, locked) in const [
      ('hidden', false, false),
      ('locked', true, true),
    ]) {
      final sc = freeWallScene(-112.5, Justification.left, mirrored: true);
      final s = servicesOf(sc.doc);
      final provider = wallFaceProvider(s);
      final r = faceRunsOf(sc.doc, sc.walls.single, liveOf(sc.doc)).first;
      final p = at(r, 2100, 40);
      expect(provider.attach(query(footprintOf(box), p)), isNotNull,
          reason: '$name: premise, the faces are built and offer');
      final builds = wallFacesOf(s).builds;
      final zero = sc.doc.tables.layers[ReservedHandles.layerZero]!;
      // No pump: the changes stream has not delivered.
      sc.doc.commands.execute(SetLayerCommand.restore(
          zero.copyWith(visible: visible, locked: locked)));
      expect(provider.attach(query(footprintOf(box), p)), isNull,
          reason: '$name: the first query after the toggle');
      expect(wallFacesOf(s).builds, builds + 1, reason: name);
      sc.doc.commands.undo();
      expect(provider.attach(query(footprintOf(box), p)), isNotNull,
          reason: '$name: the toggle undone');
    }
  });

  test(
      'WF-frozen (C1.5) a frozen wall offers no face, though the catalog '
      'still names its type', () {
    final sc = freeWallScene(-112.5, Justification.centre);
    final wall = sc.walls.single;
    final r = faceRunsOf(sc.doc, wall, liveOf(sc.doc)).first;
    final p = at(r, 1500, 40);
    final live = wallFaceProvider(servicesOf(sc.doc));
    expect(live.attach(query(footprintOf(box), p)), isNotNull);
    final s = servicesOf(sc.doc, frozen: {wall});
    expect(testCatalog().typeIdOf(sc.doc, wall), ArchitectureTypes.wall,
        reason: 'premise: the catalog answers a frozen object');
    expect(s.liveTypeIdOf(wall), isNull, reason: 'premise');
    expect(wallFaceProvider(s).attach(query(footprintOf(box), p)), isNull);
  });

  test(
      'WF-frozen-first (C1.5, the freeze rule) a wall frozen while the '
      'faces are cached, with no document change, is gone at the very next '
      'read, whichever reader comes first: the provider, runsOf, '
      'neighboursOf, attach; the other wall of the L keeps its faces', () {
    for (final reader in const [
      'provider',
      'runsOf',
      'neighboursOf',
      'attach'
    ]) {
      final sc = lScene(30, 75, ja: Justification.left);
      final (a, b) = (sc.walls[0], sc.walls[1]);
      final frozen = <Handle>{};
      final s = servicesOf(sc.doc, frozen: frozen);
      final provider = wallFaceProvider(s);
      final faces = wallFacesOf(s);
      final ra = faceRunsOf(sc.doc, a, liveOf(sc.doc)).first;
      final p = at(ra, 1500, 40);
      // The faces built while A is live: A's face takes the symbol.
      final warm = provider.attach(query(footprintOf(box), p));
      expect((warm?.token as FaceRun?)?.wall, a, reason: '$reader: premise');
      final builds = faces.builds;
      final runsB = faceRunsOf(sc.doc, b, liveOf(sc.doc, frozen: {a}),
          accept: isUsableHost);
      expect(runsB, isNotEmpty, reason: '$reader: premise');
      // Frozen with no document change: nothing reaches the stream, and the
      // command state does not move.
      final state = sc.doc.commands.stateId;
      frozen.add(a);
      expect(sc.doc.commands.stateId, state, reason: '$reader: premise');
      switch (reader) {
        case 'provider':
          expect(provider.attach(query(footprintOf(box), p)), isNull,
              reason: reader);
        case 'runsOf':
          final runs = faces.runsOf(sc.doc);
          expect([for (final r in runs) r.wall], everyElement(b),
              reason: reader);
          expect(runs, hasLength(runsB.length), reason: reader);
        case 'neighboursOf':
          expect(faces.neighboursOf(sc.doc), hasLength(runsB.length),
              reason: reader);
        case 'attach':
          expect(
              faces.attach(sc.doc, box, p, capture,
                  mirrored: false, edgeCaptureWorld: edge),
              isNull,
              reason: reader);
      }
      expect(faces.builds, builds + 1, reason: '$reader: one rebuild');
      expect([for (final r in faces.runsOf(sc.doc)) r.wall], everyElement(b),
          reason: reader);
    }
  });

  test(
      'WF-state (D-06) a symbol placed by a command is a neighbour at the '
      'next query, before the document\'s changes are delivered: the next '
      'unit snaps flush to it', () {
    final sc = freeWallScene(30, Justification.centre);
    final doc = sc.doc;
    if (!doc.components.isRegistered<SymbolComponent>()) {
      registerKitComponents(doc.components);
    }
    final provider = wallFaceProvider(servicesOf(doc));
    final unit = furniture('architecture.kitchen.base.600');
    final ubox = boxOfEntry(unit)!;
    final foot = footprintOf(ubox);
    final r = faceRunsOf(doc, sc.walls.single, liveOf(doc)).first;
    // The first unit, centred at u = 1200 (its sides 900 and 1500: no end
    // within the edge capture).
    final first = provider.attach(query(foot, at(r, 1200, 40)))!;
    expect((first.marker - at(r, 1200, 0)).length, lessThan(1e-6),
        reason: 'premise: no snap');
    doc.commands.execute(
        placeEntry(doc, unit, at: first.marker, transform: first.transform));
    // No pump: the changes stream has not delivered. The next unit's left
    // side comes 40 short of the first's right (1500): it snaps to 1500,
    // its centre to 1200 + 600.
    final next = provider.attach(query(foot, at(r, 1840, 40)))!;
    expect((next.marker - at(r, 1200 + ubox.width, 0)).length, lessThan(1e-6),
        reason: 'flush to the neighbour placed one command ago');
  });

  test(
      'WF-exclude the excluded instance is no neighbour; a query excluding '
      'two objects attaches nowhere', () {
    final sc = freeWallScene(30, Justification.centre);
    final doc = sc.doc;
    if (!doc.components.isRegistered<SymbolComponent>()) {
      registerKitComponents(doc.components);
    }
    final provider = wallFaceProvider(servicesOf(doc));
    final unit = furniture('architecture.kitchen.base.600');
    final foot = footprintOf(boxOfEntry(unit)!);
    final r = faceRunsOf(doc, sc.walls.single, liveOf(doc)).first;
    final first = provider.attach(query(foot, at(r, 1200, 40)))!;
    doc.commands.execute(
        placeEntry(doc, unit, at: first.marker, transform: first.transform));
    final neighbour = lastInstance(doc);
    final free =
        provider.attach(query(foot, at(r, 1840, 40), exclude: {neighbour}))!;
    expect((free.marker - at(r, 1840, 0)).length, lessThan(1e-6),
        reason: 'no snap to the excluded instance');
    expect(
        provider.attach(query(foot, at(r, 1840, 40),
            exclude: {neighbour, sc.walls.single})),
        isNull);
  });
}
