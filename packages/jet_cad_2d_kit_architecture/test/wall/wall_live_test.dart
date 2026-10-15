// 3a Task 11 (spec C1.5, C2): the walls' caches and the document adapter
// decide "a live wall" through a LiveTypeOf, never through a catalog of
// their own, so a frozen wall is absent from them exactly as it is absent
// from every regeneration. The walls sit at the far origin in their own
// turned groups; the stray WallParams sits on a nested group inside a
// turned and mirrored one.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_bands.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_geometry.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_fixture.dart';

const Handle a = Handle(1300), b = Handle(2600), f = Handle(3900);
const Handle outer = Handle(5000), nested = Handle(5100);

/// An L of A (200, left) and B (115, centre); F (150, right) apart from it;
/// and a stray `WallParams` from the L's corner on [nested], a group inside
/// the turned and mirrored root group [outer], as only a file brings one.
DraftDocument liveDoc() {
  final doc = wallDoc();
  final corner = plan(1800, 300);
  doc.commands.execute(
      addWall(doc, a, plan(-1200, 300), corner, 200, Justification.left));
  doc.commands.execute(addWall(doc, b, corner, polar(corner, 23 + 105, 2400),
      115, Justification.centre));
  doc.commands.execute(addWall(
      doc, f, plan(-1200, 2300), plan(1800, 2700), 150, Justification.right));
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: outer,
        parent: doc.rootHandle,
        transform: Transform2.translation(ox + 640.5, oy - 410.25)
            .multiply(Transform2.rotation(0.7))
            .multiply(Transform2.scale(-1, 1)),
        children: const [])),
    AddNodeCommand(GroupNode(
        handle: nested,
        parent: outer,
        transform: Transform2.translation(-120.5, 330.75)
            .multiply(Transform2.rotation(-0.45)),
        children: const [])),
  ], label: 'Add groups'));
  final toNested = doc.tree.accumulatedTransform(nested).invert();
  final s = toNested.transformPoint(corner);
  final e = toNested.transformPoint(polar(corner, 23 - 40, 1700));
  doc.components.attach<WallParams>(
      nested, WallParams(s.x, s.y, e.x, e.y, 90, Justification.left));
  return doc;
}

/// A point in the middle of [h]'s band, 40% along it.
Vector2 inBand(DraftDocument doc, Handle h) {
  final w = worldWallOf(doc, h);
  final (l, r) = w.offsets;
  return w.s + (w.e - w.s) * 0.4 + Vector2(-w.d.y, w.d.x) * ((l + r) / 2);
}

void main() {
  test(
      'WL1 a frozen wall has no band: the band cache neither hosts nor joins '
      'at it and liveWalls leaves it out; the live walls keep theirs', () {
    final doc = liveDoc();
    final bands = WallBands(liveOf(doc, frozen: {f}));
    addTearDown(bands.dispose);
    expect(bands.liveWalls(doc), [a, b]);
    for (final (h, host) in [(a, a), (b, b), (f, null)]) {
      final p = inBand(doc, h);
      expect(bands.hostAt(doc, p.x, p.y), host, reason: h.toHex());
      final out = Vector2(7, 7);
      expect(bands.joinInto(doc, p.x, p.y, out), host != null,
          reason: h.toHex());
    }
    // The control: nothing frozen, F is a wall with a band.
    final all = WallBands(liveOf(doc));
    addTearDown(all.dispose);
    expect(all.liveWalls(doc), [a, b, f]);
    final p = inBand(doc, f);
    expect(all.hostAt(doc, p.x, p.y), f);
  });

  test(
      'WL2 the document adapter: a frozen wall and a stray WallParams are no '
      "walls and no host's others; a live host sees the live walls, "
      'ascending, bitwise as WorldWall builds them, and moved stands in', () {
    final doc = liveDoc();
    final live = liveOf(doc, frozen: {f});
    expect(
        doc.components.withComponent<WallParams>().toList(), [a, b, f, nested],
        reason: 'premise: four holders of WallParams');
    expect(wallsInDocument(doc, f, live), isNull);
    expect(wallsInDocument(doc, nested, live), isNull);
    final w = wallsInDocument(doc, a, live)!;
    expect(w.host.handle, a);
    expect([for (final o in w.walls) o.handle], [b]);
    final want = worldWallOf(doc, a);
    expect([w.host.s.x, w.host.s.y, w.host.e.x, w.host.e.y],
        [want.s.x, want.s.y, want.e.x, want.e.y]);
    final pb = doc.components.get<WallParams>(b)!;
    final moved = WorldWall(b, pb.copyWith(end: Vector2(-310.5, 920.25)),
        doc.tree.accumulatedTransform(b));
    expect(
        identical(
            wallsInDocument(doc, a, live, moved: {b: moved})!.walls.single,
            moved),
        isTrue);
    // The control: nothing frozen, F is one of A's others.
    expect(
        [for (final o in wallsInDocument(doc, a, liveOf(doc))!.walls) o.handle],
        [b, f]);
  });

  test(
      "WL3 wallBandsOf: the kit's one WallBands per services, over their "
      'live walls (a frozen one has no band), disposed with them: a change '
      'after the dispose no longer reaches it', () async {
    final doc = liveDoc();
    final services =
        FakePlanServices(document: doc, catalog: testCatalog(), frozen: {f});
    final bands = wallBandsOf(services);
    expect(identical(wallBandsOf(services), bands), isTrue);
    expect(bands.liveWalls(doc), [a, b]);
    // The control: a change reaches the live cache.
    final g0 = bands.generation;
    doc.commands.execute(addWall(doc, const Handle(7000), plan(-900, -800),
        plan(2100, -400), 150, Justification.centre));
    await pumpEventQueue();
    expect(bands.generation, greaterThan(g0));
    services.dispose();
    final g1 = bands.generation;
    doc.commands.execute(addWall(doc, const Handle(7100), plan(-900, -1800),
        plan(2100, -1400), 150, Justification.centre));
    await pumpEventQueue();
    expect(bands.generation, g1, reason: 'disposed with its services');
  });
}
