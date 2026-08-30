import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

import '../support/instance_expander.dart';

void main() {
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
    final out = expandInstances(data, 1, Transform2.identity());

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
    final out = expandInstances(data, 1, Transform2.identity());

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
    final out = expandInstances(data, 1, Transform2.identity());
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
    final out = expandInstances(data, 1, Transform2.identity());
    for (var i = 0; i < 6; i++) {
      expect(out.positions[i * 2], closeTo(50, 1e-4));
      expect(out.positions[i * 2 + 1], closeTo(50, 1e-4));
    }
  });

  test('a point expands to a square of the stroke width', () {
    final data = Float32List(kFloatsPerInstance);
    writePoint(data, 0, x: 10, y: 20, halfWidth: 3, argb: 0xFF000000);
    final out = expandInstances(data, 1, Transform2.identity());
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
    final out = expandInstances(data, 1, Transform2.scale(5, 5));
    expect(out.positions[4], closeTo(500, 1e-3),
        reason: 'the centreline scaled');
    expect(out.positions[3] - out.positions[1], closeTo(8, 1e-3),
        reason: 'the width did not');
  });
}
