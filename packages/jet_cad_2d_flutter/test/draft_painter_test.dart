import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/fixtures.dart';

void main() {
  test('a conformal leaf reaches the sink under a translation-only residual',
      () {
    final doc = DraftDocument.empty();
    final def = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
        handle: def, name: 'd', basePoint: Vector2.zero(), children: const []));
    addEntity(doc, def, doc.handleSeed.next(), EntityKind.line, [0, 0, 10, 4],
        const []);
    // Conformal: equal scale on both axes, plus a rotation. Ratio is 1.0, so
    // this leaf took the residual path before this task.
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: doc.handleSeed.next(),
      parent: doc.rootHandle,
      definition: def,
      transform: Transform2(2.4, 1.1, -1.1, 2.4, 60, 45),
      layer: ReservedHandles.layerZero,
    )));

    final recording = RecordingDrawSink();
    final index = SpatialIndex(doc);
    DraftPainter(
            document: doc, index: index, resolver: DocumentStyleResolver(doc))
        .paint(recording, ViewportTransform.fit(doc.extents, kViewport),
            kViewport);

    final residuals = recording.ops.whereType<BeginResidualOp>().toList();
    expect(residuals, isNotEmpty);
    for (final r in residuals) {
      expect(r.residual.a, 1.0);
      expect(r.residual.b, 0.0);
      expect(r.residual.c, 0.0);
      expect(r.residual.d, 1.0);
    }
  });

  test('every frame pushes one residual value for its line-like leaves', () {
    // Two leaves in different definitions at different placements. If the
    // residual still carried the placement, these would differ — which is
    // exactly what stops a sink from batching them.
    //
    // Filtered to the residuals whose linear part is the exact identity.
    // `_emitScreenSpace` always pushes `Transform2.translation(...)`, so that
    // is the signature of the screen-space path and only that path — a
    // curve's residual still composes the camera matrix (unchanged by this
    // task), so it is never (1, 0, 0, 1) by coincidence in this fixture.
    // Left unfiltered, `generateDocument`'s default kind mix includes circles,
    // arcs and text, whose per-placement residuals still carry floating-point
    // noise from the unrelated chain path (about 41 distinct values here) and
    // would fail this assertion for a reason outside this task's scope.
    final doc = generateDocument(400, definitionCount: 8, instanceCount: 40);
    final recording = RecordingDrawSink();
    final index = SpatialIndex(doc);
    DraftPainter(
            document: doc, index: index, resolver: DocumentStyleResolver(doc))
        .paint(recording, ViewportTransform.fit(doc.extents, kViewport),
            kViewport);

    final translations = recording.ops
        .whereType<BeginResidualOp>()
        .where((op) =>
            op.residual.a == 1.0 &&
            op.residual.b == 0.0 &&
            op.residual.c == 0.0 &&
            op.residual.d == 1.0)
        .map((op) => '${op.residual.e},${op.residual.f}')
        .toSet();
    expect(translations.length, 1,
        reason: 'one rebase origin per frame means one residual value; '
            'more than one means a placement is still riding along');
  });

  DraftDocument dashedFixture({required Transform2 placement}) {
    final doc = DraftDocument.empty();
    final dashed = doc.handleSeed.next();
    doc.tables.linetypes.add(LinetypeRecord(
      handle: dashed,
      name: 'DASHED',
      description: '__ __ __',
      pattern: const DashPattern(dashes: [12.0, -6.0], totalLength: 18.0),
    ));
    final def = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
        handle: def, name: 'd', basePoint: Vector2.zero(), children: const []));
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: doc.handleSeed.next(),
        owner: def,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: dashed,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: 25,
        transparency: 0,
        flags: 0,
      ),
      payload: GeometryPayload(
          coords: Float64List.fromList([0, 0, 360, 0]),
          scalars: Float64List(0)),
    ));
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: doc.handleSeed.next(),
      parent: doc.rootHandle,
      definition: def,
      transform: placement,
      layer: ReservedHandles.layerZero,
    )));
    return doc;
  }

  List<PolylineOp> paintDashed(DraftDocument doc, ViewportTransform camera) {
    final recording = RecordingDrawSink();
    DraftPainter(
            document: doc,
            index: SpatialIndex(doc),
            resolver: DocumentStyleResolver(doc))
        .paint(recording, camera, kViewport);
    return recording.ops.whereType<PolylineOp>().toList();
  }

  test('a dashed entity reaches the sink as many spans, not one polyline', () {
    final doc = dashedFixture(placement: Transform2(1.4, 0.3, -0.3, 1.4, 5, 7));
    final ops = paintDashed(doc, ViewportTransform.fit(doc.extents, kViewport));
    expect(ops.length, greaterThan(4));
    for (final op in ops) {
      expect(op.points.length, 4, reason: 'each span is one two-point run');
    }
  });

  test('the instance scale multiplies the on-screen dash length', () {
    // Same geometry, same camera, twice the placement scale: each span must be
    // twice as long on screen. This is the scale chain, and nothing else in the
    // suite can see it.
    final cam = ViewportTransform.fit(
        Aabb2(Vector2(-50, -50), Vector2(1200, 1200)), kViewport);
    double firstSpanLength(DraftDocument doc) {
      final op = paintDashed(doc, cam).first;
      final dx = op.points[2] - op.points[0];
      final dy = op.points[3] - op.points[1];
      return math.sqrt(dx * dx + dy * dy);
    }

    final one =
        firstSpanLength(dashedFixture(placement: Transform2(1, 0, 0, 1, 0, 0)));
    final two =
        firstSpanLength(dashedFixture(placement: Transform2(2, 0, 0, 2, 0, 0)));
    expect(two / one, closeTo(2.0, 1e-6));
  });

  test('globalLinetypeScale multiplies it too', () {
    final cam = ViewportTransform.fit(
        Aabb2(Vector2(-50, -50), Vector2(1200, 1200)), kViewport);
    final doc = dashedFixture(placement: Transform2(1, 0, 0, 1, 0, 0));
    final before = paintDashed(doc, cam).length;
    doc.header.globalLinetypeScale = 3.0;
    final after = paintDashed(doc, cam).length;
    expect(after, lessThan(before),
        reason: 'a longer pattern means fewer spans over the same line');
  });

  test('a continuous entity is drawn as one polyline and is not counted', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, doc.handleSeed.next(), EntityKind.line,
        [0, 0, 360, 0], const []);
    final ops = paintDashed(doc, ViewportTransform.fit(doc.extents, kViewport));
    expect(ops.length, 1);
  });

  // Radius 20 in the circle's own local space, centred at the local origin,
  // unless a test asks otherwise. Small enough to stay clear of both camera
  // boxes the tests below use (fixed, not fit to this doc's own extents —
  // see those tests for why), and large enough that the pattern's local
  // circumference (2*pi*20 =~ 125.7 units, versus an 18-unit period) draws
  // several dashes rather than one or two.
  //
  // [center] is the circle's own stored coordinate, distinct from
  // [placement]: the rebase-clip test below needs an entity whose *own*
  // coordinates carry a translation, with the instance placement left at
  // the identity, to match the exact reproduction that exposed the bug —
  // see that test for why the two are not interchangeable here.
  DraftDocument dashedCircleFixture(
      {required Transform2 placement, double r = 20, Vector2? center}) {
    final c = center ?? Vector2.zero();
    final doc = DraftDocument.empty();
    final dashed = doc.handleSeed.next();
    doc.tables.linetypes.add(LinetypeRecord(
      handle: dashed,
      name: 'DASHED',
      description: '__ __ __',
      pattern: const DashPattern(dashes: [12.0, -6.0], totalLength: 18.0),
    ));
    final def = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
        handle: def, name: 'd', basePoint: Vector2.zero(), children: const []));
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: doc.handleSeed.next(),
        owner: def,
        kind: EntityKind.circle,
        layer: ReservedHandles.layerZero,
        linetype: dashed,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: 25,
        transparency: 0,
        flags: 0,
      ),
      payload: GeometryPayload(
          coords: Float64List.fromList([c.x, c.y]),
          scalars: Float64List.fromList([r])),
    ));
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: doc.handleSeed.next(),
      parent: doc.rootHandle,
      definition: def,
      transform: placement,
      layer: ReservedHandles.layerZero,
    )));
    return doc;
  }

  // A fixed camera, shared by both placements below, deliberately *not*
  // `ViewportTransform.fit(doc.extents, kViewport)`. Fitting to each doc's
  // own extents would defeat the test: `doc.extents` scales with `placement`
  // exactly as the circle's world size does, so `ViewportTransform.fit`
  // would zoom out by the same factor the placement zoomed in by, and the
  // composed screen scale a curve leaf sees would come out identical for
  // every placement regardless of whether the painter is right — canceling
  // the very thing under test. A fixed box breaks that cancellation: r=20
  // stays clear of it at both 1x and 2x placement (world radius up to 40,
  // against a box reaching to 125 on each axis), so the circle is never
  // clipped and the two runs differ only by whatever the placement scale
  // actually does downstream.
  //
  // Centred on the origin, and that is fine: an earlier version of this box
  // was deliberately off-centre, worked around a case where a centred box's
  // near-zero-but-negative computed centre sent `rebaseOriginFor`'s
  // power-of-two floor onto the wrong step, which (via the frame mismatch
  // `_localClipFor` had at the time — see
  // `'rebasing does not clip a dashed curve out of its own frame'` below)
  // clipped the circle out of view entirely. That was the same bug, not a
  // second one: retried after the fix with this centred box restored, both
  // placements draw 7 identical spans, same as the off-centre box gave.
  final ViewportTransform curveTestCamera = ViewportTransform.fit(
      Aabb2(Vector2(-125, -125), Vector2(125, 125)), kViewport);

  test('the instance scale does not change a curve\'s dash pattern', () {
    // The mirror image of the line-path test above, and it has to be, because
    // the two paths carry different scales on purpose. A line is drawn from
    // points already in pixels, so its period is a screen length and doubling
    // the placement doubles a span. A circle keeps the residual path, so its
    // radius and angles stay in the leaf's own space — the pattern is measured
    // in the same units the radius is, and the placement cannot touch it.
    //
    // Concretely: adding toScreen.scaleMagnitude to the curve branch's `scale`
    // argument (as `_dashScale` does for the line path) passes the whole
    // suite without this test — confirmed by making that exact edit and
    // running the file: 7 spans at 1x becomes 5, and 7 at 2x becomes 3.
    List<ArcOp> spansAt(double placementScale) {
      final doc = dashedCircleFixture(
          placement: Transform2(placementScale, 0, 0, placementScale, 0, 0));
      final recording = RecordingDrawSink();
      DraftPainter(
              document: doc,
              index: SpatialIndex(doc),
              resolver: DocumentStyleResolver(doc))
          .paint(recording, curveTestCamera, kViewport);
      return recording.ops.whereType<ArcOp>().toList();
    }

    final one = spansAt(1.0);
    final two = spansAt(2.0);

    expect(one.length, greaterThan(3),
        reason: 'the circle must actually dash, or the comparison below is '
            'between two empty lists');
    expect(two.length, one.length,
        reason: 'the pattern is measured in the leaf\'s own units, so the '
            'placement scale cannot change how many dashes fit round the '
            'circle');
    for (var i = 0; i < one.length; i++) {
      expect(two[i].start, closeTo(one[i].start, 1e-9));
      expect(two[i].sweep, closeTo(one[i].sweep, 1e-9));
    }
  });

  test('pixelScale reaches the collapse decision through the painter', () {
    // Same circle, same 1x placement, but a camera fit to a box thousands of
    // times the circle's size — so the composed screen scale (`pixelScale`)
    // is tiny, and the 18-local-unit period, though unaffected by the camera
    // in local units, maps to well under the 3px floor on screen. Unlike
    // `curveTestCamera` above, an exactly-centred box is fine here: the box
    // is so large that the floating-point noise in its computed centre is
    // many orders of magnitude below the power-of-two step `rebaseOriginFor`
    // would snap a mis-signed centre to, so there is no equivalent trap.
    final doc = dashedCircleFixture(placement: Transform2(1, 0, 0, 1, 0, 0));
    final tinyCamera = ViewportTransform.fit(
        Aabb2(Vector2(-100000, -75000), Vector2(100000, 75000)), kViewport);
    final recording = RecordingDrawSink();
    final painter = DraftPainter(
        document: doc,
        index: SpatialIndex(doc),
        resolver: DocumentStyleResolver(doc));
    painter.paint(recording, tinyCamera, kViewport);

    expect(recording.ops.whereType<ArcOp>(), isEmpty);
    expect(recording.ops.whereType<CircleOp>().length, 1);
    expect(painter.collapsedDashCount, 1);
  });

  test('rebasing does not clip a dashed curve out of its own frame', () {
    // `_localClipFor` once pulled the clip back through `toScreen`, while the
    // circle's centre had already had the rebase origin subtracted from it —
    // two frames an origin apart. A circle sitting well inside the viewport
    // lost over 90% of its dashes, on any pan where the rebase origin is not
    // zero. `debugDisableRebasing` exists to make exactly this measurable:
    // rebasing changes the arithmetic route, never the picture, so the two
    // must agree on how many dashes there are.
    //
    // This is the reviewer's own reproduction: camera fitted to
    // `Aabb2((300,300),(600,600))` puts the rebase origin at (256,256) — a
    // plain pan, no floating-point ambiguity — and a radius-100 circle
    // centred at (450,450) — the box's own centre, so it sits well inside
    // the resulting viewport — under an otherwise-identity placement. The
    // circle's own coordinate has to carry the offset rather than the
    // placement: `_localOriginFor` is `placement.invert().transformPoint
    // (origin)`, so with an identity placement, `localOrigin` is exactly
    // the rebase origin (256,256) and the rebased-local centre comes out at
    // (194,194) — just outside the pulled-back-through-`toScreen` clip on
    // one edge, which is what produced the reported 3 spans instead of 35.
    // Moving the same offset into the placement instead changes which
    // corner of the mismatch is exposed (verified separately: it still
    // reproduces a divergence, just not the reviewer's specific 3-vs-35),
    // so this shape is pinned deliberately, not incidentally.
    final doc = dashedCircleFixture(
        placement: Transform2(1, 0, 0, 1, 0, 0),
        r: 100,
        center: Vector2(450, 450));
    final camera = ViewportTransform.fit(
        Aabb2(Vector2(300, 300), Vector2(600, 600)), kViewport);

    int spansWith({required bool disableRebasing}) {
      final recording = RecordingDrawSink();
      DraftPainter(
              document: doc,
              index: SpatialIndex(doc),
              resolver: DocumentStyleResolver(doc),
              debugDisableRebasing: disableRebasing)
          .paint(recording, camera, kViewport);
      return recording.ops.whereType<ArcOp>().length;
    }

    final rebased = spansWith(disableRebasing: false);
    final unrebased = spansWith(disableRebasing: true);
    // Guards the comparison below against a vacuous pass (0 == 0, e.g. if a
    // future edit moved the fixture out of view): the whole circle, wholly
    // visible, is 2*pi*100/18 =~ 34.9 spans — 35, measured — so both counts
    // must actually be near that, not just equal to each other.
    expect(unrebased, greaterThan(30),
        reason: 'sanity check: the circle must be visible and wholly '
            'undashed-away with rebasing off, or the comparison below is '
            'vacuous');
    expect(rebased, unrebased,
        reason: 'the rebase must not change what is visible');
  });
}
