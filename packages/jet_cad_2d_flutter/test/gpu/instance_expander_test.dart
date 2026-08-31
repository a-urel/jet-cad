import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

import '../support/instance_expander.dart';

/// A single solid stroke: `dashPeriod` stays at its default, `0`, so
/// `dash.x` is exactly `0` and the shader's default sentinel
/// `v_dash = vec3(0, -1, 0)` survives untouched.
final Float32List solidStrokeBuffer = (() {
  final data = Float32List(kFloatsPerInstance);
  writeStroke(data, 0,
      x0: 0, y0: 0, x1: 10, y1: 0, halfWidth: 4, argb: 0xFF000000);
  return data;
})();

/// A 30-unit segment, period 18, phase 3, with one drawn element spanning
/// the whole primitive (`fracStart` 0, `fracEnd` 1) so the test can read
/// `t` alone without also exercising the fragment-side extent test.
final Float32List oneDashedStroke = (() {
  final data = Float32List(kFloatsPerInstance);
  writeStroke(data, 0,
      x0: 0,
      y0: 0,
      x1: 30,
      y1: 0,
      halfWidth: 4,
      argb: 0xFF000000,
      dashPeriod: 18,
      dashPhase: 3,
      dashFracStart: 0,
      dashFracEnd: 1);
  return data;
})();

/// Two instances of one dashed primitive's element chain, both at period
/// 18 collection units: instance 0 carries the negative period that marks
/// it the collapse representative, instance 1 an ordinary positive-period
/// sibling. At `dashScale: 0.1` the live period is `18 * 0.1 == 1.8`,
/// under `kDashCollapsePx` (3.0), so the primitive has collapsed.
final Float32List twoElementDashedStroke = (() {
  final data = Float32List(kFloatsPerInstance * 2);
  writeStroke(data, 0,
      x0: 0,
      y0: 0,
      x1: 30,
      y1: 0,
      halfWidth: 4,
      argb: 0xFF000000,
      dashPeriod: -18,
      dashPhase: 3,
      dashFracStart: 0,
      dashFracEnd: 0.5);
  writeStroke(data, 1,
      x0: 30,
      y0: 0,
      x1: 60,
      y1: 0,
      halfWidth: 4,
      argb: 0xFF000000,
      dashPeriod: 18,
      dashPhase: 0,
      dashFracStart: 0,
      dashFracEnd: 0.5);
  return data;
})();

/// A `point()` record. Never dashed -- `writePoint` takes no dash
/// arguments and writes all four dash slots to zero.
final Float32List pointBuffer = (() {
  final data = Float32List(kFloatsPerInstance);
  writePoint(data, 0, x: 10, y: 20, halfWidth: 3, argb: 0xFF000000);
  return data;
})();

/// The three vertices of [triangle] (0 or 1) of [instance]'s expanded quad,
/// read straight off `ExpandedTriangles.positions` -- the per-instance
/// stride and vertex order match `ResidentGeometry.kCornerVertices`.
List<Offset> triangleOf(ExpandedTriangles e,
    {required int instance, required int triangle}) {
  final stride = ResidentGeometry.cornerVertexCount;
  final base = (instance * stride + triangle * 3) * 2;
  return <Offset>[
    Offset(e.positions[base], e.positions[base + 1]),
    Offset(e.positions[base + 2], e.positions[base + 3]),
    Offset(e.positions[base + 4], e.positions[base + 5]),
  ];
}

/// Twice-signed area via the shoelace formula, absolute -- winding is not
/// under test here, only whether the triangle has collapsed to a point.
double area(List<Offset> triangle) {
  final a = triangle[0], b = triangle[1], c = triangle[2];
  return ((b.dx - a.dx) * (c.dy - a.dy) - (c.dx - a.dx) * (b.dy - a.dy)).abs() /
      2.0;
}

void main() {
  test('a solid instance signals solid with a negative fracStart', () {
    final e = expandInstances(solidStrokeBuffer, 1, Transform2.identity(),
        dashScale: 1.0);
    for (var v = 0; v < ResidentGeometry.cornerVertexCount; v++) {
      expect(e.dashVaryings[v * 3 + 1], lessThan(0.0));
    }
  });

  test('t runs from phase/period to (phase + length)/period across the quad',
      () {
    // A 30-unit segment, period 18, phase 3.
    final e = expandInstances(oneDashedStroke, 1, Transform2.identity(),
        dashScale: 1.0);
    final ts = <double>[
      for (var v = 0; v < ResidentGeometry.cornerVertexCount; v++)
        e.dashVaryings[v * 3],
    ];
    expect(ts.reduce(math.min), closeTo(3.0 / 18.0, 1e-6));
    expect(ts.reduce(math.max), closeTo((3.0 + 30.0) / 18.0, 1e-6));
  });

  test('t is measured in COLLECTION units, so the camera cancels', () {
    // The same instance expanded at two different device scales must give
    // the same t at every vertex. This is the design's central claim: the
    // reference's period grows with the camera and so does the distance, so
    // the ratio does not move. A t that changed here would mean the pattern
    // stretching or compressing under zoom -- the defect this plan exists
    // to remove, reintroduced in the shader.
    final a = expandInstances(oneDashedStroke, 1, Transform2.scale(1.0, 1.0),
        dashScale: 1.0);
    final b = expandInstances(oneDashedStroke, 1, Transform2.scale(4.0, 4.0),
        dashScale: 4.0);
    for (var i = 0; i < a.dashVaryings.length; i += 3) {
      expect(b.dashVaryings[i], closeTo(a.dashVaryings[i], 1e-6));
    }
  });

  test(
      'a collapsed non-representative instance produces a degenerate '
      'triangle', () {
    // period 18 collection units at dashScale 0.1 -> 1.8 live logical px,
    // under kDashCollapsePx.
    final e = expandInstances(twoElementDashedStroke, 2, Transform2.identity(),
        dashScale: 0.1);
    // Instance 0 is the representative: real positions, solid varying.
    expect(e.dashVaryings[1], lessThan(0.0));
    expect(area(triangleOf(e, instance: 0, triangle: 0)), greaterThan(0.0));
    // Instance 1 collapses to a point.
    expect(area(triangleOf(e, instance: 1, triangle: 0)), 0.0);
  });

  test('the collapse threshold is the dasher\'s own value', () {
    expect(kExpanderDashCollapsePx, kDashCollapsePx,
        reason: 'GLSL cannot read a Dart constant, so cad_stroke.vert '
            'restates 3.0 as a literal; this assertion is what keeps the '
            'restatement honest, the same way kMinMiterCosine is kept');
  });

  test('a point instance is never dashed', () {
    final e =
        expandInstances(pointBuffer, 1, Transform2.identity(), dashScale: 1.0);
    expect(e.dashVaryings[1], lessThan(0.0));
  });

  test('the miter cosine matches the reference constant', () {
    // `cad_stroke.vert` restates -0.875 as a literal because GLSL cannot
    // read a Dart constant. This is the assertion that keeps the literal
    // honest if the reference's miter limit ever moves.
    expect(kExpanderMinMiterCosine, VerticesDrawSink.kMinMiterCosine);
  });

  test('a horizontal stroke expands to the quad the reference builds', () {
    final data = Float32List(kFloatsPerInstance);
    writeStroke(data, 0,
        x0: 0, y0: 0, x1: 100, y1: 0, halfWidth: 4, argb: 0xFF112233);
    final out = expandInstances(data, 1, Transform2.identity(), dashScale: 1.0);

    expect(out.positions.length, 12, reason: 'six vertices, two floats each');
    // Corner (0,-1) -> (0, -4); (0,1) -> (0, 4); (1,-1) -> (100, -4).
    // The normal of a +x direction is (0, +1), so corner.y = -1 is y = -4.
    expect(out.positions[0], closeTo(0, 1e-4));
    expect(out.positions[1], closeTo(-4, 1e-4));
    expect(out.positions[2], closeTo(0, 1e-4));
    expect(out.positions[3], closeTo(4, 1e-4));
    expect(out.positions[4], closeTo(100, 1e-4));
    expect(out.positions[5], closeTo(-4, 1e-4));
    // `colors` is `Int32List` (matching `TriangleRasterizer.observe` and
    // `VerticesDrawSink._colors`), so a colour with the alpha byte's high
    // bit set reads back negative -- `.toUnsigned(32)` before comparing
    // against a positive ARGB literal is this codebase's established
    // convention (`vertices_draw_sink_test.dart` does the same at every
    // colour assertion).
    expect(out.colors.every((c) => c.toUnsigned(32) == 0xFF112233), isTrue);
  });

  test('a right-angle join is mitred, and the tip is at the outer corner', () {
    // Incoming +x, outgoing +y: a left turn, so the notch is on the right
    // (negative y / positive x side). At 90 degrees the half-angle is 45,
    // cos is sqrt(1/2), and the miter reach is half / cos = 4 * sqrt(2).
    final data = Float32List(kFloatsPerInstance);
    writeJoin(data, 0,
        vx: 100,
        vy: 0,
        prevX: 0,
        prevY: 0,
        nextX: 100,
        nextY: 100,
        halfWidth: 4,
        argb: 0xFF000000);
    final out = expandInstances(data, 1, Transform2.identity(), dashScale: 1.0);

    // Vertex 4 of the six is M, the miter tip.
    final mx = out.positions[8], my = out.positions[9];
    // d0 = (1,0), d1 = (0,1), cross = 1 > 0, so s = -4.
    // n0 = (-0,1)*-4 = (0,-4); n1 = (-1,0)*-4 = (4,0).
    // sum = (4,-4), mu = (1,-1)/sqrt2, cos_half = dot(mu,n0)/4
    //     = ((0*1 + -4*-1)/sqrt2)/4 = (4/sqrt2)/4 = 1/sqrt2.
    // reach = 4 / (1/sqrt2) = 4*sqrt2. m = v + mu*reach = (100+4, 0-4).
    expect(mx, closeTo(104, 1e-3));
    expect(my, closeTo(-4, 1e-3));
  });

  test('a hairpin turn is bevelled: the tip triangle has zero area', () {
    // Incoming +x, outgoing very nearly -x. dot is below -0.875, so the
    // reference bails before the miter and emits the bevel alone.
    final data = Float32List(kFloatsPerInstance);
    writeJoin(data, 0,
        vx: 100,
        vy: 0,
        prevX: 0,
        prevY: 0,
        nextX: 0,
        nextY: 1,
        halfWidth: 4,
        argb: 0xFF000000);
    final out = expandInstances(data, 1, Transform2.identity(), dashScale: 1.0);
    final ax = out.positions[6], ay = out.positions[7];
    final mx = out.positions[8], my = out.positions[9];
    expect(mx, closeTo(ax, 1e-4),
        reason: 'M collapses onto A, so (A, M, B) has no area');
    expect(my, closeTo(ay, 1e-4));
  });

  test('a collinear join collapses onto its vertex', () {
    final data = Float32List(kFloatsPerInstance);
    writeJoin(data, 0,
        vx: 50,
        vy: 50,
        prevX: 0,
        prevY: 50,
        nextX: 100,
        nextY: 50,
        halfWidth: 4,
        argb: 0xFF000000);
    final out = expandInstances(data, 1, Transform2.identity(), dashScale: 1.0);
    for (var i = 0; i < 6; i++) {
      expect(out.positions[i * 2], closeTo(50, 1e-4));
      expect(out.positions[i * 2 + 1], closeTo(50, 1e-4));
    }
  });

  test('a point expands to a square of the stroke width', () {
    final data = Float32List(kFloatsPerInstance);
    writePoint(data, 0, x: 10, y: 20, halfWidth: 3, argb: 0xFF000000);
    final out = expandInstances(data, 1, Transform2.identity(), dashScale: 1.0);
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i < 6; i++) {
      final x = out.positions[i * 2], y = out.positions[i * 2 + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    expect(maxX - minX, closeTo(6, 1e-4));
    expect(maxY - minY, closeTo(6, 1e-4));
    expect((minX + maxX) / 2, closeTo(10, 1e-4));
    expect((minY + maxY) / 2, closeTo(20, 1e-4));
  });

  test('half-width does not scale with the transform', () {
    // The whole reason joins and quads are built in the shader. Under a 5x
    // camera the centreline moves five times as far and the quad stays four
    // device pixels wide.
    final data = Float32List(kFloatsPerInstance);
    writeStroke(data, 0,
        x0: 0, y0: 0, x1: 100, y1: 0, halfWidth: 4, argb: 0xFF000000);
    final out =
        expandInstances(data, 1, Transform2.scale(5, 5), dashScale: 1.0);
    expect(out.positions[4], closeTo(500, 1e-3),
        reason: 'the centreline scaled');
    expect(out.positions[3] - out.positions[1], closeTo(8, 1e-3),
        reason: 'the width did not');
  });

  test(
      'a stroke under a transform with every coefficient non-zero matches by hand',
      () {
    // Every other test in this file uses `identity()` or `scale(k,k)`, so
    // `b`, `c`, `e` and `f` are zero everywhere -- the degenerate fixture
    // CLAUDE.md names as this project's dominant failure mode. A transposed
    // `toX`/`toY` (swapping which of `b`/`c` feeds which axis) or a dropped
    // translation (`e`/`f`) passes every test above unnoticed. This uses the
    // same hand-built, every-coefficient-non-zero transform
    // `geometry_collector_test.dart` uses for its own residual tests, so a
    // reader can cross-check the shape of the fixture against a working
    // precedent in this package.
    const t = Transform2(2, 0.5, -1, 3, 10, 10);
    final data = Float32List(kFloatsPerInstance);
    writeStroke(data, 0,
        x0: 0, y0: 0, x1: 100, y1: 0, halfWidth: 4, argb: 0xFF000000);
    final out = expandInstances(data, 1, t, dashScale: 1.0);

    // toX(x,y) = t.a*x + t.c*y + t.e = 2x -  y + 10
    // toY(x,y) = t.b*x + t.d*y + t.f = 0.5x + 3y + 10
    // a = toPixels(0,0)   = (10, 10)
    // b = toPixels(100,0) = (210, 60)
    // delta = b - a = (200, 50); len = sqrt(200^2 + 50^2) = 50*sqrt(17)
    // dir    = delta / len = (4/sqrt17, 1/sqrt17)
    // normal = (-dir.y, dir.x) = (-1/sqrt17, 4/sqrt17)
    // corner (0,-1): px = a - normal*4 = (10 + 4/sqrt17, 10 - 16/sqrt17)
    // corner (0, 1): px = a + normal*4 = (10 - 4/sqrt17, 10 + 16/sqrt17)
    // corner (1,-1): px = b - normal*4 = (210 + 4/sqrt17, 60 - 16/sqrt17)
    final sqrt17 = math.sqrt(17);
    expect(out.positions[0], closeTo(10 + 4 / sqrt17, 1e-3));
    expect(out.positions[1], closeTo(10 - 16 / sqrt17, 1e-3));
    expect(out.positions[2], closeTo(10 - 4 / sqrt17, 1e-3));
    expect(out.positions[3], closeTo(10 + 16 / sqrt17, 1e-3));
    expect(out.positions[4], closeTo(210 + 4 / sqrt17, 1e-3));
    expect(out.positions[5], closeTo(60 - 16 / sqrt17, 1e-3));
  });

  test('cad_stroke.vert still carries the three renumber-prone constants', () {
    // Partial net, not a substitute for Ruling B6's human diff: this pins
    // the three literals a shader edit is most likely to silently renumber
    // (`instance_record.dart`'s doc explains why the values and order of
    // `kKindStroke`/`kKindJoin`/`kKindPoint` are load-bearing, and this
    // file's own `kExpanderMinMiterCosine` is the fourth, Dart-side, copy
    // of the miter-limit literal). It reads the GLSL as text and checks
    // for the constants, not the arithmetic around them -- a change to the
    // *formula* that keeps these three literals untouched (for example,
    // Task 8's own M-B5/M-B6 mutations) is invisible to this test and
    // remains a human diff against `instance_expander.dart`.
    final source = File('shaders/cad_stroke.vert').readAsStringSync();
    expect(
      RegExp(r'kMinMiterCosine\s*=\s*-0\.875').hasMatch(source),
      isTrue,
      reason: 'the miter-limit literal instance_expander.dart mirrors as '
          'kExpanderMinMiterCosine',
    );
    expect(
      RegExp(r'kind\s*<\s*0\.5').hasMatch(source),
      isTrue,
      reason: 'the stroke/join dispatch threshold',
    );
    expect(
      RegExp(r'kind\s*<\s*1\.5').hasMatch(source),
      isTrue,
      reason: 'the join/point dispatch threshold',
    );
  });
}
