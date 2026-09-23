import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Copied from `snap_test.dart`'s `addEntity`, never imported from a test
/// file.
Handle addLine(DraftDocument doc, List<double> coords) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: doc.rootHandle,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords), scalars: Float64List(0)),
  ));
  return handle;
}

/// An index over [lines], torn down with the test.
SpatialIndex indexOver(List<List<double>> lines) {
  final doc = DraftDocument.empty();
  for (final l in lines) {
    addLine(doc, l);
  }
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  return index;
}

/// A 100 mm lattice anchored off the origin.
final PageComponent grid100 =
    PageComponent(originX: 7000, originY: 3000, gridStepMm: 100);

DragPoint resolve(SpatialIndex index, Vector2 raw,
    {Vector2? orthoBase,
    bool objectSnap = true,
    PageComponent? page,
    SnapResult? scratch}) {
  final out = DragPoint();
  resolveDragPoint(
    raw: raw,
    orthoBase: orthoBase,
    index: index,
    apertureWorld: 10,
    objectSnap: objectSnap,
    page: page,
    gridStepMm: page?.gridStepMm,
    scratch: scratch ?? SnapResult(),
    out: out,
  );
  return out;
}

void main() {
  test('kDragSnapMask is the cheap kinds plus intersection', () {
    expect(
        kDragSnapMask.bits, SnapMask.cheap.with_(SnapKind.intersection).bits);
  });

  test('the raw point passes through when nothing snaps', () {
    final index = indexOver([]);
    final free = resolve(index, Vector2(7043.25, 3011.5), page: null);
    expect([free.point.x, free.point.y], [7043.25, 3011.5]);
    expect(free.objectKind, isNull);
    expect(free.grid, isFalse);
    final off = resolve(index, Vector2(7043.25, 3011.5),
        page: grid100.copyWith(snapToGrid: false));
    expect([off.point.x, off.point.y], [7043.25, 3011.5],
        reason: "page.snapToGrid == false is the caller's check (04 D6)");
  });

  test('ortho pins the minor world axis to the base (M-03f)', () {
    final index = indexOver([]);
    final base = Vector2(7000.3, 3000.7);
    final x = resolve(index, Vector2(7050.2, 3010.9),
        orthoBase: base, objectSnap: false);
    expect([x.point.x, x.point.y], [7050.2, 3000.7]);
    final y = resolve(index, Vector2(7010.2, 3060.9),
        orthoBase: base, objectSnap: false);
    expect([y.point.x, y.point.y], [7000.3, 3060.9]);
  });

  test(
      'an object snap overrides ortho, and is copied out of the scratch '
      '(invariant 7)', () {
    final index = indexOver([
      [7093, 3004, 7093, 3304],
    ]);
    final scratch = SnapResult();
    final out = resolve(index, Vector2(7094.5, 3006.0),
        orthoBase: Vector2(7500, 3500), scratch: scratch);
    expect([out.point.x, out.point.y], [7093, 3004],
        reason: 'released near an endpoint, a drag lands on it exactly');
    expect(out.objectKind, SnapKind.endpoint);
    expect(out.grid, isFalse);
    index.snapInto(Vector2(7093, 3300), 10, SnapMask.cheap, scratch);
    expect(scratch.point.y, 3304);
    expect([out.point.x, out.point.y], [7093, 3004],
        reason: 'no SnapResult.point is held past the call that filled it');
  });

  test(
      'a reused DragPoint clears objectKind and grid between calls '
      '(M-03az)', () {
    final index = indexOver([
      [7093, 3004, 7093, 3304],
    ]);
    final out = DragPoint();
    resolveDragPoint(
      raw: Vector2(7094.5, 3006.0),
      orthoBase: null,
      index: index,
      apertureWorld: 10,
      objectSnap: true,
      page: null,
      gridStepMm: null,
      scratch: SnapResult(),
      out: out,
    );
    expect(out.objectKind, SnapKind.endpoint,
        reason: 'the first call lands an object snap');
    // Second call, same DragPoint: nothing in the aperture and no grid --
    // a stale objectKind or grid from the first call must not survive.
    resolveDragPoint(
      raw: Vector2(7500, 3500),
      orthoBase: null,
      index: index,
      apertureWorld: 10,
      objectSnap: true,
      page: null,
      gridStepMm: null,
      scratch: SnapResult(),
      out: out,
    );
    expect(out.objectKind, isNull,
        reason: 'a reused DragPoint is reset at the top of every call');
    expect(out.grid, isFalse);
  });

  test('an object snap beats a nearer grid point (M-03g)', () {
    final index = indexOver([
      [7093, 3004, 7093, 3304],
    ]);
    // Grid (7100, 3000) is 2.2 away; the endpoint (7093, 3004) is 5.8 away.
    final out = resolve(index, Vector2(7098, 3001), page: grid100);
    expect([out.point.x, out.point.y], [7093, 3004]);
    expect(out.objectKind, SnapKind.endpoint);
    expect(out.grid, isFalse);
  });

  test('kind decides between object snaps through a drag (M-03b)', () {
    final index = indexOver([
      [7200, 3500, 7212, 3500],
    ]);
    // The midpoint (7206, 3500) is 1.5 away, the endpoint (7200, 3500) 4.5.
    final out = resolve(index, Vector2(7204.5, 3500.2));
    expect(out.objectKind, SnapKind.endpoint);
    expect([out.point.x, out.point.y], [7200, 3500]);
  });

  test('a grid snap re-pins the ortho axis afterwards (M-03q)', () {
    final index = indexOver([]);
    final base = Vector2(7003.7, 3017.3);
    final x = resolve(index, Vector2(7160.2, 3040.1),
        orthoBase: base, objectSnap: false, page: grid100);
    expect([x.point.x, x.point.y], [7200, 3017.3],
        reason: 'a shift-drag from an off-grid base stays on its line');
    expect(x.grid, isTrue);
    final y = resolve(index, Vector2(7010.2, 3160.1),
        orthoBase: base, objectSnap: false, page: grid100);
    expect([y.point.x, y.point.y], [7003.7, 3200]);
  });

  test('object snap off never snaps to an object: the grid wins (M-03x)', () {
    final index = indexOver([
      [7093, 3004, 7093, 3304],
    ]);
    final out =
        resolve(index, Vector2(7096, 3006), objectSnap: false, page: grid100);
    expect([out.point.x, out.point.y], [7100, 3000]);
    expect(out.objectKind, isNull);
    expect(out.grid, isTrue);
  });

  test(
      'dragGridStepMm: the page step exactly, else the adaptive minor '
      '(M-03aw)', () {
    expect(dragGridStepMm(null, 0.5), isNull);
    expect(dragGridStepMm(grid100.copyWith(gridStepMm: 250.0), 0.5), 250,
        reason: 'a fixed step is used exactly at every zoom (04 D6)');
    expect(dragGridStepMm(grid100.copyWith(gridStepMm: 250.0), 7.0), 250);
    // Adaptive, metric, 0.5 px/mm: the first rung with a 64 px major is
    // 200 mm, divisor 4, so the minor is 50 mm (25 px, above 8).
    expect(
        dragGridStepMm(PageComponent(originX: 7000, originY: 3000), 0.5), 50);
  });
}
