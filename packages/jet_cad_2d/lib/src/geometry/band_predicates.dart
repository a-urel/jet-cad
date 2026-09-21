import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import '../document/tables.dart' show TextStyleRecord;
import '../document/text_geometry.dart';
import '../document/text_metrics.dart';
import '../store/entity_store.dart' show EntityKind;
import '../store/geometry_store.dart';
import 'aabb2.dart';
import 'primitives.dart' show angleInSweep;
import 'segment_clip.dart';
import 'transform2.dart';

/// The oriented glyph box of a text or attrib in the leaf's own space.
final class TextBox {
  const TextBox(this.minX, this.minY, this.maxX, this.maxY, this.local);
  final double minX, minY, maxX, maxY;

  /// Box space → leaf space (`textLocalTransform`).
  final Transform2 local;
}

/// The four oriented corners of a text or attrib in the leaf's own space, laid
/// out as `SpatialIndex._considerLeaf` does. Null when the box is degenerate
/// — an empty string, or the zero metrics `InsertionPointMeasurer` answers
/// with — matching that method's own "nothing to fill" rule.
TextBox? textBoxOf(GeometryPayload payload, int textAttrs,
    TextStyleRecord style, TextMetrics metrics) {
  final attrs = resolveTextAttributes(payload, textAttrs, style);
  final box = textLocalBounds(attrs, metrics);
  if (box.maxX <= box.minX || box.maxY <= box.minY) return null;
  final local = textLocalTransform(attrs, metrics, payload.pointAt(0));
  return TextBox(box.minX, box.minY, box.maxX, box.maxY, local);
}

/// Every point of the leaf's world AABB lies inside [band] (spec D8, window).
///
/// Inclusive on the edge, on purpose: a leaf whose box exactly meets the
/// band's boundary is fully inside a closed band, the same convention
/// [Aabb2.containsPoint] and [Aabb2.intersects] already use.
bool boxEnclosedByBand(Aabb2 worldBox, Aabb2 band) =>
    !worldBox.isEmpty &&
    worldBox.minX >= band.minX &&
    worldBox.maxX <= band.maxX &&
    worldBox.minY >= band.minY &&
    worldBox.maxY <= band.maxY;

/// Scratch for [clipSegment]'s `t` pair and [circleClipWindows]'s windows.
final Float64List _t = Float64List(2);
final Float64List _windows = Float64List(8);

bool _segmentTouches(double x0, double y0, double x1, double y1, Aabb2 band) =>
    clipSegment(x0, y0, x1, y1, band, _t);

/// Some point of the stroke lies inside [band] (spec D8, crossing).
bool leafTouchedByBand(EntityKind kind, GeometryPayload payload, double ta,
    double tb, double tc, double td, double te, double tf, Aabb2 band,
    {TextBox? textBox}) {
  final c = payload.coords;
  final n = payload.pointCount;
  if (n == 0 && kind != EntityKind.text && kind != EntityKind.attrib) {
    return false; // a fill has no coordinates and is never picked (spec D8)
  }
  switch (kind) {
    case EntityKind.point:
      final wx = ta * c[0] + tc * c[1] + te, wy = tb * c[0] + td * c[1] + tf;
      return wx >= band.minX &&
          wx <= band.maxX &&
          wy >= band.minY &&
          wy <= band.maxY;
    case EntityKind.line:
    case EntityKind.polyline:
      if (n == 1) {
        final wx = ta * c[0] + tc * c[1] + te, wy = tb * c[0] + td * c[1] + tf;
        return band.containsPoint(Vector2(wx, wy));
      }
      var px = ta * c[0] + tc * c[1] + te, py = tb * c[0] + td * c[1] + tf;
      for (var i = 1; i < n; i++) {
        final lx = c[i * 2], ly = c[i * 2 + 1];
        final qx = ta * lx + tc * ly + te, qy = tb * lx + td * ly + tf;
        if (_segmentTouches(px, py, qx, qy, band)) return true;
        px = qx;
        py = qy;
      }
      return false;
    case EntityKind.circle:
      final cx = ta * c[0] + tc * c[1] + te, cy = tb * c[0] + td * c[1] + tf;
      final r = payload.scalars[0] * _scaleMagnitude(ta, tb, tc, td);
      return circleClipWindows(cx, cy, r, band, _windows) != 0;
    case EntityKind.arc:
      final cx = ta * c[0] + tc * c[1] + te, cy = tb * c[0] + td * c[1] + tf;
      final r = payload.scalars[0] * _scaleMagnitude(ta, tb, tc, td);
      // World start angle from the transformed start point; a mirror flips
      // the turning sense — the same rule `_considerLeaf` uses for arcs.
      final s0 = payload.scalars[1], sweep0 = payload.scalars[2];
      final lsx = c[0] + payload.scalars[0] * math.cos(s0);
      final lsy = c[1] + payload.scalars[0] * math.sin(s0);
      final wsx = ta * lsx + tc * lsy + te, wsy = tb * lsx + td * lsy + tf;
      final start = math.atan2(wsy - cy, wsx - cx);
      final sweep = (ta * td - tb * tc) < 0 ? -sweep0 : sweep0;
      final count = circleClipWindows(cx, cy, r, band, _windows);
      if (count == -1) return true;
      for (var i = 0; i < count; i++) {
        final a = _windows[i * 2], b = _windows[i * 2 + 1];
        // A window intersects the sweep when an endpoint of either lies in
        // the other, or the window contains the sweep's start.
        if (angleInSweep(a, start, sweep) ||
            angleInSweep(b, start, sweep) ||
            _angleInWindow(start, a, b)) {
          return true;
        }
      }
      return false;
    case EntityKind.text:
    case EntityKind.attrib:
      final box = textBox;
      if (box == null) return false;
      // Compose leaf→world with box→leaf, then walk the four edges.
      final l = box.local;
      final ma = ta * l.a + tc * l.b, mb = tb * l.a + td * l.b;
      final mc = ta * l.c + tc * l.d, md = tb * l.c + td * l.d;
      final me = ta * l.e + tc * l.f + te, mf = tb * l.e + td * l.f + tf;
      double xOf(double x, double y) => ma * x + mc * y + me;
      double yOf(double x, double y) => mb * x + md * y + mf;
      final xs = [box.minX, box.maxX, box.maxX, box.minX];
      final ys = [box.minY, box.minY, box.maxY, box.maxY];
      for (var i = 0; i < 4; i++) {
        final j = (i + 1) % 4;
        if (_segmentTouches(xOf(xs[i], ys[i]), yOf(xs[i], ys[i]),
            xOf(xs[j], ys[j]), yOf(xs[j], ys[j]), band)) {
          return true;
        }
      }
      return false;
    case EntityKind.fill:
      return false;
  }
}

bool _angleInWindow(double angle, double a, double b) {
  const twoPi = 2 * math.pi;
  var d = (angle - a) % twoPi;
  if (d < 0) d += twoPi;
  return d <= b - a;
}

double _scaleMagnitude(double a, double b, double c, double d) =>
    math.sqrt((a * d - b * c).abs());

/// Transform2-taking wrapper for tests and the differential arm.
bool leafTouchedByBandT(
        EntityKind kind, GeometryPayload payload, Transform2 t, Aabb2 band,
        {TextBox? textBox}) =>
    leafTouchedByBand(kind, payload, t.a, t.b, t.c, t.d, t.e, t.f, band,
        textBox: textBox);
