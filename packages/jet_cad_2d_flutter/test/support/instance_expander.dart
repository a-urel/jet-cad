/// `cad_stroke.vert`, in Dart, so `flutter test` can reach it.
///
/// **This is a deliberate second copy of a file no test can run.** The suite
/// has no GPU, so every line of the vertex shader is otherwise unreachable —
/// including the miter arithmetic, which is the part most likely to be
/// wrong. Transcribing it here converts an untestable file into a tested one
/// and reduces the risk to a single file diff.
///
/// **Read it beside the GLSL and keep the statement order.** Where the
/// shader writes `dot(d0, d1) >= kMinMiterCosine`, so does this; where it
/// collapses a corner onto the vertex, so does this. A "cleaner" Dart
/// rewrite is worth nothing here — the value of this file is that a reader
/// can diff it against the shader line by line.
///
/// It takes an instance buffer and a transform. It must never read the
/// collector: the collector's output is the input, which is exactly what the
/// GPU sees.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

/// The shader's `kMinMiterCosine` literal, mirrored so a test can assert it
/// against `VerticesDrawSink.kMinMiterCosine`.
const double kExpanderMinMiterCosine = -0.875;

/// The corner table's six entries, `(corner.xy, join_weight.xyzw)`.
///
/// Read from [ResidentGeometry.kCornerVertices] rather than restated, so a
/// reordering there is a change here too.
class _Corner {
  const _Corner(this.x, this.y, this.wv, this.wa, this.wb, this.wm);
  final double x, y, wv, wa, wb, wm;
}

List<_Corner> _corners() {
  const stride = ResidentGeometry.kFloatsPerCorner;
  final src = ResidentGeometry.kCornerVertices;
  return List<_Corner>.generate(
      6,
      (i) => _Corner(src[i * stride], src[i * stride + 1], src[i * stride + 2],
          src[i * stride + 3], src[i * stride + 4], src[i * stride + 5]));
}

/// The triangle list the GPU would produce, in the shape
/// `TriangleRasterizer.observe` takes.
class ExpandedTriangles {
  ExpandedTriangles(this.positions, this.colors);

  /// Two floats per vertex, six vertices per instance, in instance order.
  final Float32List positions;

  /// One `0xAARRGGBB` per vertex.
  final Int32List colors;

  int get vertexCount => colors.length;
}

/// Expands [instanceCount] records of [data] under [collectionToDevice].
///
/// [collectionToDevice] stands in for the shader's `mvp` composed with
/// `half_viewport`: the shader maps collection space to device pixels in two
/// steps because a `mat4` is what a uniform block carries, and the
/// composition is the same affine map. Feeding it directly here removes a
/// clip-space round trip that has no observable effect and would only add a
/// place for the two copies to disagree.
ExpandedTriangles expandInstances(
    Float32List data, int instanceCount, Transform2 collectionToDevice) {
  final corners = _corners();
  final positions = Float32List(instanceCount * 6 * 2);
  final colors = Int32List(instanceCount * 6);
  final t = collectionToDevice;

  double toX(double x, double y) => t.a * x + t.c * y + t.e;
  double toY(double x, double y) => t.b * x + t.d * y + t.f;

  for (var i = 0; i < instanceCount; i++) {
    final o = i * kFloatsPerInstance;
    final kind = data[o + InstanceFieldOffset.kind];
    final halfWidth = data[o + InstanceFieldOffset.halfWidth];
    final argb = _argbOf(data, o);

    final x0 = data[o + InstanceFieldOffset.x0];
    final y0 = data[o + InstanceFieldOffset.y0];
    final x1 = data[o + InstanceFieldOffset.x1];
    final y1 = data[o + InstanceFieldOffset.y1];
    final x2 = data[o + InstanceFieldOffset.x2];
    final y2 = data[o + InstanceFieldOffset.y2];

    for (var v = 0; v < 6; v++) {
      final c = corners[v];
      double px, py;

      if (kind < 0.5) {
        // kKindStroke: two triangles around a centreline.
        final ax = toX(x0, y0), ay = toY(x0, y0);
        final bx = toX(x1, y1), by = toY(x1, y1);
        final dx = bx - ax, dy = by - ay;
        final len = math.sqrt(dx * dx + dy * dy);
        // Reachable, not merely defensive -- see the join branch's identical
        // guard below for why.
        final dirX = len > 0 ? dx / len : 1.0;
        final dirY = len > 0 ? dy / len : 0.0;
        final nx = -dirY, ny = dirX;
        px = ax + (bx - ax) * c.x + nx * halfWidth * c.y;
        py = ay + (by - ay) * c.x + ny * halfWidth * c.y;
      } else if (kind < 1.5) {
        // kKindJoin: the notch at a corner, as the bevel (V, A, B) plus the
        // miter tip (A, M, B). Exactly `VerticesDrawSink._emitJoin`, in
        // device pixels, which is the space that function works in too.
        final vx = toX(x0, y0), vy = toY(x0, y0);
        final pxp = toX(x1, y1), pyp = toY(x1, y1);
        final nxp = toX(x2, y2), nyp = toY(x2, y2);

        final inX = vx - pxp, inY = vy - pyp;
        final outX = nxp - vx, outY = nyp - vy;
        final inLen = math.sqrt(inX * inX + inY * inY);
        final outLen = math.sqrt(outX * outX + outY * outY);
        final d0x = inLen > 0 ? inX / inLen : 1.0;
        final d0y = inLen > 0 ? inY / inLen : 0.0;
        final d1x = outLen > 0 ? outX / outLen : d0x;
        final d1y = outLen > 0 ? outY / outLen : d0y;

        final crossZ = d0x * d1y - d0y * d1x;
        // Collinear: either straight through, where the quads already meet,
        // or a reversal, where both the miter and the bevel are degenerate.
        // The reference emits nothing; collapsing every corner onto the
        // vertex gives two zero-area triangles, which is the same picture.
        //
        // **Transcribed verbatim, including `inLen == 0 || outLen == 0`, and
        // it is a known, bounded divergence between the two arms, not an
        // oversight.** The reference (`VerticesDrawSink._emitJoin`) computes
        // its directions in `double`, already in device space, from a
        // residual the collector maintains incrementally. This branch
        // instead re-projects `p0`/`p1`/`p2` from collection space through
        // `to_pixels` on every vertex -- exactly what the real shader does,
        // in `float32`. At extreme zoom-out two distinct float32 device
        // points can coincide (or two distinct collection-space points can
        // project to the same float32 pixel) where the reference's `double`
        // residual still sees them as separate, so the real GLSL can take
        // this branch where the sink does not. This file runs the same
        // formula in Dart `double`, so it will not reproduce that
        // collapse on the same input -- it takes the *other* branch. That is
        // expected: this file's job is to mirror the GLSL statement for
        // statement, not to be correct where the GLSL is only approximate.
        if (crossZ == 0 || inLen == 0 || outLen == 0) {
          px = vx;
          py = vy;
        } else {
          // The outer side of the turn is the one away from it: a left turn
          // (cross > 0) opens a notch on the right.
          final s = crossZ > 0 ? -halfWidth : halfWidth;
          final n0x = -d0y * s, n0y = d0x * s;
          final n1x = -d1y * s, n1y = d1x * s;
          final ax = vx + n0x, ay = vy + n0y;
          final bx = vx + n1x, by = vy + n1y;

          // Bevel by default: with M at A the tip triangle (A, M, B) has
          // zero area and disappears, which is what the reference's early
          // return achieves by not emitting it.
          var mx = ax, my = ay;
          if (d0x * d1x + d0y * d1y >= kExpanderMinMiterCosine) {
            final sumX = n0x + n1x, sumY = n0y + n1y;
            final sumLen = math.sqrt(sumX * sumX + sumY * sumY);
            if (sumLen > 0 && halfWidth > 0) {
              final muX = sumX / sumLen, muY = sumY / sumLen;
              // `n0` has length `halfWidth`, so this is the cosine of half
              // the included angle.
              final cosHalf = (muX * n0x + muY * n0y) / halfWidth;
              if (cosHalf > 0) {
                final reach = halfWidth / cosHalf;
                mx = vx + muX * reach;
                my = vy + muY * reach;
              }
            }
          }

          // **This blend poisons all six vertices -- including triangle 0
          // (V, A, B), which does not read `m` at all -- if `m` is
          // non-finite, because `0.0 * Inf` is `NaN` in IEEE 754, not `0.0`.**
          // Transcribed as the shader has it anyway: the guard above bails
          // to the bevel unless `dot(d0, d1) >= kExpanderMinMiterCosine`
          // (-0.875), which bounds the half-angle under roughly 76 degrees
          // and therefore bounds `reach = halfWidth / cosHalf` to at most
          // `4 * halfWidth` -- `m` cannot go non-finite through this guard
          // as written. It is unreachable *today*, not unreachable by
          // construction: a differential test comparing this file's output
          // against the reference sink would see both arms agree (both
          // finite, or in some future change to the guard, both NaN) and
          // report agreement even if this arithmetic were the thing that
          // regressed. Only a device run, or a change to the guard, would
          // catch that.
          px = c.wv * vx + c.wa * ax + c.wb * bx + c.wm * mx;
          py = c.wv * vy + c.wa * ay + c.wb * by + c.wm * my;
        }
      } else {
        // kKindPoint: a square of the stroke's width centred on p0. Both
        // axes are expanded here, in device pixels, so the dot stays square
        // and stays the same size at every zoom -- which is what the
        // reference gets for free by computing its `+/- half` in device
        // space.
        final cx = toX(x0, y0), cy = toY(x0, y0);
        px = cx + (c.x * 2.0 - 1.0) * halfWidth;
        py = cy + c.y * halfWidth;
      }

      final vi = (i * 6 + v);
      positions[vi * 2] = px;
      positions[vi * 2 + 1] = py;
      colors[vi] = argb;
    }
  }

  return ExpandedTriangles(positions, colors);
}

/// Reads the record's four colour floats back to `0xAARRGGBB`.
///
/// Exact round trip: the writer stored `channel / 255.0` and an 8-bit value
/// divided by 255 then multiplied by 255 is that value again in float32,
/// with the round only guarding against a representation surprise.
int _argbOf(Float32List data, int o) {
  int ch(int offset) =>
      (data[o + offset] * 255.0).round().clamp(0, 255).toInt();
  return (ch(InstanceFieldOffset.a) << 24) |
      (ch(InstanceFieldOffset.r) << 16) |
      (ch(InstanceFieldOffset.g) << 8) |
      ch(InstanceFieldOffset.b);
}
