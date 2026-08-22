// The closed-run seam, exercised through the frame path rather than against
// the `DrawSink` interface.
//
// Plan 3d pinned the seam join and the closing chord in unit tests that call
// `VerticesDrawSink` directly, and its results note recorded that no fixture
// reached them through `DraftPainter`. This is that fixture: solid circles,
// drawn by the real widget, scan-converted, and read back.
//
// A circle is the only closed run the painter produces. `polyline` forwards
// `closed`, but all four painter call sites pass `false`, and a dashed circle
// never reaches the closed path either -- the dasher emits open spans. So the
// fixture's circle must be *solid*, which is exactly what the dash ladder's
// circle is not.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

import 'support/triangle_rasterizer.dart';

const Size _viewport = Size(400, 300);
const double _radius = 90.0;
const double _halfSpan = 150.0;

/// One entity at the origin, thick enough that a sub-pixel chord error cannot
/// move a sample off the stroke.
///
/// Lineweight 60 (0.60 mm) rather than the dash ladder's 30: the centreline
/// assertion samples the *true* circle while the sink draws an inscribed
/// polygon, so the stroke has to be wider than the flattener's sagitta with
/// room to spare. At this radius that sagitta is about a quarter of a logical
/// pixel against a half-width near 1.1 -- a factor of four, not a coin flip.
DraftDocument _fixture(EntityKind kind, List<double> scalars) {
  final measurer = FlutterTextMeasurer();
  addTearDown(measurer.clear);
  final doc = DraftDocument.empty(measurer: measurer);
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: doc.handleSeed.next(),
      owner: doc.rootHandle,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x000000),
      lineweight: 60,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList(const [0, 0]),
        scalars: Float64List.fromList(scalars)),
  ));
  return doc;
}

/// What one frame of [doc] put in the vertices buffer.
typedef _Frame = ({
  TriangleRasterizer rasterizer,
  int triangles,
  Float32List positions,
  ViewportTransform camera,
  double dpr,
});

/// Paints [doc] once through the real widget on the vertices backend and hands
/// back the frame's triangles, both counted and scan-converted.
Future<_Frame> _paint(WidgetTester tester, DraftDocument doc) async {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final camera = CameraController(ViewportTransform.fit(
      Aabb2(Vector2(-_halfSpan, -_halfSpan), Vector2(_halfSpan, _halfSpan)),
      _viewport));
  addTearDown(camera.dispose);

  final key = GlobalKey<DraftCanvasState>();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: _viewport.width,
          height: _viewport.height,
          child: DraftCanvas(
              key: key,
              document: doc,
              index: index,
              resolver: DocumentStyleResolver(doc),
              camera: camera,
              backend: RenderBackend.vertices),
        ),
      ),
    ),
  ));

  // Device resolution, for the reason the dash ladder records: the buffer's
  // positions are logical pixels but the sink's width floor is a device
  // quantity, and a logical-resolution sampler can miss a stroke Impeller inks
  // along its whole length.
  final dpr = tester.view.devicePixelRatio;
  final rasterizer = TriangleRasterizer(
      (_viewport.width * dpr).round(), (_viewport.height * dpr).round());
  var triangles = 0;
  var captured = Float32List(0);
  key.currentState!.vertices!.observer = (positions, colors) {
    triangles += colors.length ~/ 3;
    // A copy: `flush` rewinds and reuses the buffer the moment this returns.
    captured = Float32List.fromList(positions);
    final scaled = Float32List(positions.length);
    for (var i = 0; i < positions.length; i++) {
      scaled[i] = positions[i] * dpr;
    }
    rasterizer.observe(scaled, colors);
  };
  // The first pump painted without an observer, and `shouldRepaint` is
  // unconditionally false, so a bare `pump()` finds nothing dirty.
  tester
      .renderObject<RenderObject>(find.descendant(
          of: find.byType(DraftCanvas), matching: find.byType(CustomPaint)))
      .markNeedsPaint();
  await tester.pump();

  return (
    rasterizer: rasterizer,
    triangles: triangles,
    positions: captured,
    camera: camera.value,
    dpr: dpr
  );
}

void main() {
  testWidgets('a solid circle inks its whole centreline, seam included',
      (tester) async {
    final frame =
        await _paint(tester, _fixture(EntityKind.circle, const [_radius]));

    expect(frame.rasterizer.pixels.any((p) => p != 0), isTrue,
        reason: 'the circle never reached the rasterizer, so every assertion '
            'below would pass against a blank surface');

    // Walk the true circle. The sink draws an inscribed polygon whose first
    // vertex is at angle 0 -- the seam -- so a missing closing chord leaves a
    // run of blank samples starting there and nowhere else.
    const samples = 360;
    final blank = <int>[];
    for (var i = 0; i < samples; i++) {
      final angle = 2 * math.pi * i / samples;
      final world =
          Vector2(_radius * math.cos(angle), _radius * math.sin(angle));
      final screen = frame.camera.worldToScreen(world);
      if (!frame.rasterizer.inked(
          (screen.x * frame.dpr).round(), (screen.y * frame.dpr).round())) {
        blank.add(i);
      }
    }

    expect(blank, isEmpty,
        reason: 'the stroke has a gap at these degree samples: $blank. A run '
            'starting at 0 is the closing chord the closed branch of '
            '`_endRun` draws; without it the circle is an open polyline that '
            'stops one chord short of its own start.');

    // The seam *join* -- the corner wedge, as opposed to the closing chord
    // above -- cannot be pinned by reading pixels. Its ink is one bevel plus
    // one tip triangle, whose area goes as `half^2`, and at a realistic DXF
    // lineweight that is under one device pixel. Measured on this fixture,
    // through this frame path, by deleting the seam join and counting inked
    // pixels: 0.60 mm inks **0** device pixels of difference out of 10,964;
    // 2.00 mm, the widest lineweight DXF defines, inks 10 out of 36,540. A
    // pixel assertion at any honest lineweight would stay green against a sink
    // that draws no seam join at all.
    //
    // So the seam join is pinned structurally instead, on a property that
    // holds at every radius, lineweight and flattening tolerance: **a closed
    // run has exactly as many joins as it has chords.** Each chord is a quad
    // (2 triangles) and each join is a bevel plus a tip (2 triangles), so a
    // closed run's triangle count is `4 x chords`, divisible by 4. Drop the
    // seam join and it is `4c - 2`; drop the whole closed branch and it is
    // `4c - 2` again, one chord shorter. Both leave a remainder of 2. The
    // fixture holds one entity, so the frame's buffer is this circle alone.
    expect(frame.triangles, greaterThan(0),
        reason: 'no triangles reached the observer at all');
    expect(frame.triangles % 4, 0,
        reason: 'a closed run emits one join per chord, so its triangle count '
            'is 4 x chords. ${frame.triangles} leaves a remainder of '
            '${frame.triangles % 4}, which is one join pair missing -- the '
            'seam, the corner no vertex list contains.');
  });

  testWidgets('closing a run costs exactly one join over the open sweep',
      (tester) async {
    // The same geometry twice: once as a CIRCLE, which `_flatten` walks with
    // `closed: true`, and once as an ARC of a full turn, which it walks with
    // `closed: false`. Both draw the same chords, because the closed walk
    // stops one sample short and lets `_endRun` draw the chord it skipped.
    // The only difference is the seam join: 2 triangles.
    //
    // This is the assertion the divisibility check above cannot make. Letting
    // the closed walk run to `steps` instead of `steps - 1` leaves the count
    // divisible by 4 -- measured 172 against 168 on this fixture -- because it
    // adds a whole chord *and* a whole join. `cos(2 * pi)` does not land back
    // on the first point exactly, so that extra chord is a real, sub-pixel,
    // numerically noisy step, and the seam join is then taken from *its*
    // direction rather than the last real chord's. Only a comparison against
    // the open sweep sees it.
    //
    // The open arm is the full-sweep ARC the Plan 3d results note records as
    // drawing an unjoined seam. It is used here as a count of reference, not
    // as a drawing asserted to be right.
    final closed =
        await _paint(tester, _fixture(EntityKind.circle, const [_radius]));
    final open = await _paint(
        tester, _fixture(EntityKind.arc, const [_radius, 0.0, 2 * math.pi]));

    expect(open.triangles, greaterThan(0),
        reason: 'the full-sweep arc drew nothing, so the comparison below is '
            'against zero');
    expect(closed.triangles, open.triangles + 2,
        reason: 'a closed run draws the same chords as the open sweep and one '
            'more join. closed=${closed.triangles} open=${open.triangles}, a '
            'difference of ${closed.triangles - open.triangles} rather than '
            '2.');
  });

  testWidgets('the seam wedge fills the outside of the turn', (tester) async {
    // Neither the pixel walk nor the triangle count sees which *side* of the
    // corner the seam join fills. Swap `_emitJoin`'s two direction arguments
    // at the seam call site and the wedge lands on the inside of the turn,
    // where the two chord quads already overlap: the count is unchanged, the
    // outer notch stays open, and the notch is sub-pixel. Both other tests
    // stay green.
    //
    // The side is visible in the buffer, though. The wedge is `(V, A, B)` plus
    // `(A, M, B)` with `A`, `B` one half-width off the vertex and `M` the
    // miter point; on the outside of a circle every one of them but `V` is
    // *further* from the centre than `V` is, and on the inside every one of
    // them is nearer. So the seam wedge's farthest vertex from the circle's
    // centre decides it.
    //
    // Reading the last two triangles relies on emission order, which this sink
    // treats as load-bearing everywhere else: `_endRun` draws the closing
    // chord's join and quad and then the seam join, so for a frame holding one
    // circle the seam wedge is the final six vertices in the buffer.
    final frame =
        await _paint(tester, _fixture(EntityKind.circle, const [_radius]));

    final centre = frame.camera.worldToScreen(Vector2.zero());
    final screenRadius = _radius * frame.camera.scale;
    final tail = frame.positions.length - 12; // 2 triangles x 3 vertices x 2
    expect(tail, greaterThan(0),
        reason: 'the buffer is too short to hold a '
            'seam wedge, so the assertion below reads nothing');

    var farthest = 0.0;
    for (var i = tail; i < frame.positions.length; i += 2) {
      final dx = frame.positions[i] - centre.x;
      final dy = frame.positions[i + 1] - centre.y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > farthest) farthest = d;
    }

    expect(farthest, greaterThan(screenRadius),
        reason: 'the seam wedge reaches ${farthest.toStringAsFixed(3)} from '
            'the centre against a centreline radius of '
            '${screenRadius.toStringAsFixed(3)}: every vertex of it is inside '
            'the circle, so it was drawn on the inner side of the turn, where '
            'the two chord quads already overlap. The notch it should have '
            'filled is still open.');
  });
}
