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
///
/// **Task 8 added the dash varying, transcribed the same way as everything
/// else here.** `ExpandedTriangles.dashVaryings` is `v_dash` -- `(t,
/// fracStart, fracEnd)` per vertex -- and [expandInstances] takes the same
/// `dashScale` `cad_stroke.vert` reads off `frame_info.dash_scale`. Read the
/// dash block in `expandInstances` beside the shader's own tail, in the same
/// order: the sentinel, the period test, the collapse override.
///
/// **Plan D's Task 5 added the fill branch, transcribed the same way.** A
/// fill instance (`kKindFill`) reads no `halfWidth` and expands nothing: its
/// three corners are projected and selected by `join_weight`'s V, A and B,
/// with M folded onto A so the six-vertex corner table's second triangle is
/// degenerate. The point branch is narrowed to `kind < 2.5` in both files so
/// the fill branch's bare `else` cannot swallow it -- see the branch's own
/// comment below for the failure that guards against.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

/// The shader's `kMinMiterCosine` literal, mirrored so a test can assert it
/// against `VerticesDrawSink.kMinMiterCosine`.
const double kExpanderMinMiterCosine = -0.875;

/// The shader's `kDashCollapsePx` literal, mirrored so a test can assert it
/// against the engine's own `kDashCollapsePx` (`dasher.dart`) -- GLSL cannot
/// read a Dart constant, so `cad_stroke.vert` restates `3.0` and this file
/// restates it a second time, the same way `kExpanderMinMiterCosine` keeps
/// the miter literal honest.
const double kExpanderDashCollapsePx = 3.0;

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
      ResidentGeometry.cornerVertexCount,
      (i) => _Corner(src[i * stride], src[i * stride + 1], src[i * stride + 2],
          src[i * stride + 3], src[i * stride + 4], src[i * stride + 5]));
}

/// The triangle list the GPU would produce, in the shape
/// `TriangleRasterizer.observe` takes.
class ExpandedTriangles {
  ExpandedTriangles(this.positions, this.colors, this.dashVaryings);

  /// Two floats per vertex, six vertices per instance, in instance order.
  final Float32List positions;

  /// One `0xAARRGGBB` per vertex.
  final Int32List colors;

  /// Three floats per vertex: `v_dash`'s `(t, fracStart, fracEnd)`. A
  /// negative `fracStart` is the solid sentinel -- see `cad_stroke.vert`'s
  /// `v_dash` doc.
  final Float32List dashVaryings;

  int get vertexCount => colors.length;
}

/// Expands [instanceCount] records of [data] under [collectionToDevice].
///
/// [collectionToDevice] stands in for the shader's `mvp` composed with
/// `half_viewport`: the shader maps collection space to device pixels in two
/// steps because a `mat4` is what a uniform block carries. `clip.xy *
/// half_viewport` is viewport-centred and y-up, so it is not literally the
/// same affine map as a direct collection-to-device-pixel `Transform2` --
/// the two differ by a translation and a y-flip. The substitution is still
/// sound: every branch below is equivariant under a translation outright,
/// since each is built from *differences* of already-projected points
/// (deltas, unit directions, the miter blend) and a shared translation
/// cancels out of every difference. A y-flip is different -- it reverses
/// the cross product's sign, and with it which side the `crossZ > 0` test
/// calls the turn's outer side -- but consistently so, because `n0` and
/// `n1` are both derived from the same flipped space, so the triangles that
/// come out are the exact mirror image of the un-flipped ones, which is the
/// geometrically correct picture for a y-flipped space. Feeding the
/// composed transform directly here removes a clip-space round trip that
/// has no observable effect and would only add a place for the two copies
/// to disagree.
ExpandedTriangles expandInstances(
    Float32List data, int instanceCount, Transform2 collectionToDevice,
    {required double dashScale}) {
  final corners = _corners();
  final cornerVertexCount = ResidentGeometry.cornerVertexCount;
  final positions = Float32List(instanceCount * cornerVertexCount * 2);
  final colors = Int32List(instanceCount * cornerVertexCount);
  final dashVaryings = Float32List(instanceCount * cornerVertexCount * 3);
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

    // `dash`: (period, phase, fracStart, fracEnd), collection units. Read
    // once per instance, like `kind`/`halfWidth`/`x0`.. above -- the shader
    // reads the same instance attribute fresh every vertex, which is
    // equivalent since none of these four vary by vertex.
    final dashPeriodSigned = data[o + InstanceFieldOffset.dashPeriod];
    final dashPhase = data[o + InstanceFieldOffset.dashPhase];
    final dashFracStart = data[o + InstanceFieldOffset.dashFracStart];
    final dashFracEnd = data[o + InstanceFieldOffset.dashFracEnd];
    final period = dashPeriodSigned.abs();

    for (var v = 0; v < cornerVertexCount; v++) {
      final c = corners[v];
      double px, py;

      // Distance from the primitive's start to this vertex, in COLLECTION
      // units.
      var along = 0.0;

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
        // Collection units, taken from the attributes rather than from `a`
        // and `b`: `toX`/`toY` have already applied the live camera to
        // those, and the camera must not appear in `t`.
        final rawDx = x1 - x0, rawDy = y1 - y0;
        along = c.x * math.sqrt(rawDx * rawDx + rawDy * rawDy);
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
          // construction: no differential test exercises this poisoning
          // path at all while the guard holds, since `m` never goes
          // non-finite for it to poison. (If it ever did, the two arms
          // would *disagree*, not agree: the reference's triangle 0 never
          // reads `m`, so it would stay finite while this triangle 0 went
          // NaN -- a differential would catch that. What it cannot catch is
          // a regression to *this* arithmetic while the guard still bounds
          // `reach`, because nothing exercises the poisoning branch to
          // begin with.) Only a device run, or a change to the guard, would
          // catch a change here today.
          px = c.wv * vx + c.wa * ax + c.wb * bx + c.wm * mx;
          py = c.wv * vy + c.wa * ay + c.wb * by + c.wm * my;
        }
      } else if (kind < 2.5) {
        // kKindPoint: a square of the stroke's width centred on p0. Both
        // axes are expanded here, in device pixels, so the dot stays square
        // and stays the same size at every zoom -- which is what the
        // reference gets for free by computing its `+/- half` in device
        // space.
        final cx = toX(x0, y0), cy = toY(x0, y0);
        px = cx + (c.x * 2.0 - 1.0) * halfWidth;
        py = cy + c.y * halfWidth;
      } else {
        // kKindFill: one triangle of a pre-triangulated fill. Nothing is
        // expanded -- a fill has no width -- so `halfWidth` is not read here
        // at all. `join_weight` selects the corner: V -> p0, A -> p1,
        // B -> p2, and M folded onto p1, which makes the second triangle
        // (A, M, B) = (p1, p1, p2) degenerate.
        final a0x = toX(x0, y0), a0y = toY(x0, y0);
        final a1x = toX(x1, y1), a1y = toY(x1, y1);
        final a2x = toX(x2, y2), a2y = toY(x2, y2);
        px = c.wv * a0x + (c.wa + c.wm) * a1x + c.wb * a2x;
        py = c.wv * a0y + (c.wa + c.wm) * a1y + c.wb * a2y;
      }

      final vi = (i * cornerVertexCount + v);
      positions[vi * 2] = px;
      positions[vi * 2 + 1] = py;
      colors[vi] = argb;

      // The dash decision. `dash.x` (here `dashPeriodSigned`) is signed:
      // zero is solid, and a negative value marks the one instance per
      // primitive that draws solid when the pattern collapses.
      var vDashT = 0.0, vDashFracStart = -1.0, vDashFracEnd = 0.0;
      if (period > 0.0) {
        if (period * dashScale < kExpanderDashCollapsePx) {
          // Collapsed. The reference stops dashing and draws the whole
          // primitive, so the representative keeps its solid varying and
          // every sibling collapses to a point.
          if (dashPeriodSigned > 0.0) {
            positions[vi * 2] = 0.0;
            positions[vi * 2 + 1] = 0.0;
          }
        } else {
          vDashT = (dashPhase + along) / period;
          vDashFracStart = dashFracStart;
          vDashFracEnd = dashFracEnd;
        }
      }
      dashVaryings[vi * 3] = vDashT;
      dashVaryings[vi * 3 + 1] = vDashFracStart;
      dashVaryings[vi * 3 + 2] = vDashFracEnd;
    }
  }

  return ExpandedTriangles(positions, colors, dashVaryings);
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
