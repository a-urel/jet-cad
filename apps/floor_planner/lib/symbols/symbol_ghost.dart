// The symbol placement ghost (spec 09b D6 "The ghost", F-14, R-3): the
// symbol's leaves as one cached `ui.Path` in the symbol's local frame, and
// the matrix that carries that frame to `world − origin` for a tool's
// `paintWorldOverlay`.
//
// `dart:ui` only, no widget: the placement tool (plan Task 6) owns the
// painting. Nothing here allocates per paint: the path is built once per
// entry, and the placement transform is computed only when the placement
// changes; a paint writes two doubles of a reused `Float64List(16)`.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'symbol_library.dart';
import 'symbol_placer.dart';

final Expando<ui.Path> _ghostPaths = Expando<ui.Path>('ghostPath');

/// The outline of [entry]'s leaves in the symbol's **local** frame (the
/// definition's coordinates, base point not subtracted), built on the first
/// call and the same object on every later call for the same entry.
///
/// A line is a segment, a polyline its segments (closed when
/// [isClosedPolyline]), a circle `addOval` and an arc `addArc` with the
/// payload's start and sweep unchanged (`[r, start, sweep]`): the path's
/// angles are the engine's `c + r·(cos θ, sin θ)`, and a matrix with a
/// y-flip or a mirror carries them as it carries every other point (F-14).
/// Points, texts and fills draw nothing.
ui.Path ghostPathFor(SymbolEntry entry) =>
    _ghostPaths[entry] ??= _buildGhostPath(entry);

ui.Path _buildGhostPath(SymbolEntry entry) {
  final path = ui.Path();
  for (final leaf in entry.leaves) {
    final p = leaf.payload;
    final c = p.coords;
    switch (leaf.record.kind) {
      case EntityKind.line:
      case EntityKind.polyline:
        if (c.length < 4) continue;
        path.moveTo(c[0], c[1]);
        for (var i = 2; i + 1 < c.length; i += 2) {
          path.lineTo(c[i], c[i + 1]);
        }
        if (leaf.record.kind == EntityKind.polyline && isClosedPolyline(p)) {
          path.close();
        }
      case EntityKind.circle:
        if (c.length < 2 || p.scalars.isEmpty) continue;
        path.addOval(ui.Rect.fromCircle(
            center: ui.Offset(c[0], c[1]), radius: p.scalars[0]));
      case EntityKind.arc:
        if (c.length < 2 || p.scalars.length < 3) continue;
        path.addArc(
            ui.Rect.fromCircle(
                center: ui.Offset(c[0], c[1]), radius: p.scalars[0]),
            p.scalars[1],
            p.scalars[2]);
      case EntityKind.point:
      case EntityKind.text:
      case EntityKind.attrib:
      case EntityKind.fill:
        continue;
    }
  }
  return path;
}

/// A column-major 4×4 identity, the storage [writeGhostMatrix] expects.
Float64List identityGhostMatrix() => Float64List(16)
  ..[0] = 1
  ..[5] = 1
  ..[10] = 1
  ..[15] = 1;

/// Writes `translate(−origin) ∘ p` into [m], an identity-initialised
/// column-major 4×4 (`canvas.transform`'s layout): the linear part of [p] in
/// `[0] [1] [4] [5]`, its translation less [origin] in `[12] [13]`. Composed
/// in doubles; the other ten entries are left as they are.
void writeGhostMatrix(Float64List m, Transform2 p, Vector2 origin) {
  _writeLinear(m, p);
  _writeTranslation(m, p, origin);
}

void _writeLinear(Float64List m, Transform2 p) {
  m[0] = p.a;
  m[1] = p.b;
  m[4] = p.c;
  m[5] = p.d;
}

void _writeTranslation(Float64List m, Transform2 p, Vector2 origin) {
  m[12] = p.e - origin.x;
  m[13] = p.f - origin.y;
}

/// The ghost's reused matrix (spec D6): the placement transform `P =
/// placementTransform(at, basePoint, turns, mirrored)` is computed, and its
/// linear part written, only when one of those four changes ([update]); a
/// paint ([forOrigin]) writes only the translation less the rebase origin.
final class GhostMatrix {
  /// The column-major storage handed to `canvas.transform`, reused for the
  /// holder's life.
  final Float64List storage = identityGhostMatrix();

  Transform2? _p;
  double _atX = 0, _atY = 0, _baseX = 0, _baseY = 0;
  int _turns = 0;
  bool _mirrored = false;
  int _computations = 0;

  /// How many times `P` was computed: a test's count (spec D6).
  @visibleForTesting
  int get computations => _computations;

  /// The current placement transform, or null before the first [update].
  Transform2? get placement => _p;

  /// Sets the placement; recomputes `P` only when [at], [basePoint],
  /// [quarterTurns] or [mirrored] differ from the last call (stored values,
  /// compared exactly). [at] and [basePoint] are read, not kept.
  void update({
    required Vector2 at,
    required Vector2 basePoint,
    int quarterTurns = 0,
    bool mirrored = false,
  }) {
    if (_p != null &&
        at.x == _atX &&
        at.y == _atY &&
        basePoint.x == _baseX &&
        basePoint.y == _baseY &&
        quarterTurns == _turns &&
        mirrored == _mirrored) {
      return;
    }
    _atX = at.x;
    _atY = at.y;
    _baseX = basePoint.x;
    _baseY = basePoint.y;
    _turns = quarterTurns;
    _mirrored = mirrored;
    final p = placementTransform(
      at: at,
      basePoint: basePoint,
      quarterTurns: quarterTurns,
      mirrored: mirrored,
    );
    _p = p;
    _computations++;
    _writeLinear(storage, p);
  }

  /// [storage] with its translation set for [origin] (`world − origin`, the
  /// frame `paintWorldOverlay` paints in). Call [update] first.
  Float64List forOrigin(Vector2 origin) {
    final p = _p;
    if (p == null) {
      throw StateError('GhostMatrix.forOrigin before update');
    }
    _writeTranslation(storage, p, origin);
    return storage;
  }
}
