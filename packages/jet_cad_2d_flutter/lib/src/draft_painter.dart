import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'camera_controller.dart';
import 'draw_sink.dart';
import 'viewport_transform.dart';

/// Walks the document and writes to a [DrawSink]. No cache of any kind.
///
/// This is not scaffolding for the cached painter of Plan 3b — it is the
/// differential oracle that one is tested against, in the same role brute-force
/// queries played for the spatial index.
class DraftPainter {
  DraftPainter({
    required this.document,
    required this.index,
    required this.resolver,
  });

  final DraftDocument document;
  final SpatialIndex index;
  final StyleResolver resolver;

  /// Reused across frames; the frame path must not allocate once warm.
  Float64List _points = Float64List(256);
  int get leafBufferCapacity => _points.length;

  /// This frame's visible root-level instances, ascending. Copied out of the
  /// query rather than held by reference: both rect queries share one set of
  /// scratch buffers inside `SpatialIndex`.
  Uint32List _instances = Uint32List(64);
  int _instanceCount = 0;
  int get instanceBufferCapacity => _instances.length;

  int _skippedText = 0;

  /// Text entities not drawn in the last frame.
  ///
  /// Text has no content in the model yet (Plan 3b adds it), so it cannot be
  /// drawn — and text is the product's payload, which makes every measurement
  /// here optimistic by exactly this many entities. Recorded rather than
  /// assumed away.
  int get skippedTextCount => _skippedText;

  /// Draws everything visible, in ascending handle order.
  ///
  /// Root-level leaves and root-level instances arrive from two different
  /// queries, each ascending on its own. Running them back to back would give
  /// "all leaves, then all instances" — a different order, invisible while
  /// nothing is filled, and deciding what covers what the moment Plan 3b adds
  /// fills. They are merged instead.
  void paint(DrawSink sink, ViewportTransform camera, Size viewport) {
    _skippedText = 0;
    final world = camera.visibleWorld(viewport);
    final origin = rebaseOriginFor(world);
    final rootIndex = index.rootIndex;

    // Drain the instance query completely first. Holding its results across
    // the leaf query is safe only because they are copied out here.
    _instanceCount = 0;
    index.forEachInstanceInRect(world, const QueryFilter.rendering(), (h) {
      if (_instanceCount == _instances.length) _growInstances();
      _instances[_instanceCount++] = h.value;
    });

    // Stream the leaves, flushing every lower-handled instance first.
    //
    // `_drawInstance` runs *inside* this visitor. That is legal only because
    // it uses `ContainerIndex` queries and never a `SpatialIndex`-level one:
    // `_beginQuery` is called by `SpatialIndex` methods alone, so reaching for
    // one here would throw `QueryReentrancyError`.
    var next = 0;
    index.forEachInRect(world, const QueryFilter.rendering(), (slot) {
      final leafHandle = document.entities.handleAt(slot).value;
      while (next < _instanceCount && _instances[next] < leafHandle) {
        _drawInstance(sink, camera, origin, Handle(_instances[next++]));
      }
      _drawLeaf(sink, camera, origin, rootIndex.transformOfLeaf(slot), slot,
          StyleContext.documentRoot);
    });

    // Whatever is left sorts after every visible leaf.
    while (next < _instanceCount) {
      _drawInstance(sink, camera, origin, Handle(_instances[next++]));
    }
  }

  void _growInstances() {
    final grown = Uint32List(_instances.length * 2)
      ..setRange(0, _instances.length, _instances);
    _instances = grown;
  }

  /// Draws one root-level instance.
  ///
  /// Task 8 fills in the descent into the definition's contents; today this
  /// establishes the instance's residual and its place in the draw order.
  void _drawInstance(DrawSink sink, ViewportTransform camera, Vector2 origin,
      Handle instance) {
    final node = document.tree[instance];
    if (node is! InstanceNode) return;

    final localOrigin = _localOriginFor(node.transform, origin);
    final chain = camera.worldToScreenMatrix
        .multiply(node.transform)
        .multiply(Transform2.translation(localOrigin.x, localOrigin.y));

    sink.beginResidual(chain, debugHandle: instance);
    sink.endResidual();
  }

  void _drawLeaf(DrawSink sink, ViewportTransform camera, Vector2 origin,
      Transform2? leafTransform, int slot, StyleContext ctx) {
    final placement = leafTransform ?? _identity;

    // The rebase subtraction happens in the leaf's own space, because that is
    // the space the stored coordinates are in. So the origin — a world point —
    // is pulled back through the placement first, and the rebase translation
    // the chain carries is that *local* origin, not the world one. With a
    // non-identity placement the two differ, and composing the world origin
    // here would put every group-owned leaf in the wrong place while a fixture
    // with an identity placement still passed.
    final localOrigin = _localOriginFor(placement, origin);
    final chain = camera.worldToScreenMatrix
        .multiply(placement)
        .multiply(Transform2.translation(localOrigin.x, localOrigin.y));

    final payload = document.geometry.peek(document.entities.geomIndexAt(slot));
    final style = resolver.styleFor(slot, ctx);
    sink.beginResidual(chain, debugHandle: document.entities.handleAt(slot));
    _emit(sink, document.entities.kindAt(slot), payload, localOrigin, style);
    sink.endResidual();
  }

  /// The rebase origin expressed in a leaf's own space.
  ///
  /// A placement with no inverse — a group scaled to zero on one axis — cannot
  /// express the origin at all. Rebasing is then skipped for that leaf rather
  /// than throwing: `invert()` runs per leaf per frame, and one degenerate
  /// group must not take the whole frame down. Such a leaf collapses to a line
  /// or a point on screen anyway.
  Vector2 _localOriginFor(Transform2 placement, Vector2 origin) {
    final det = placement.determinant;
    if (det == 0.0 || !det.isFinite) return Vector2.zero();
    return placement.invert().transformPoint(origin);
  }

  void _emit(DrawSink sink, EntityKind kind, GeometryPayload payload,
      Vector2 localOrigin, ResolvedStyle style) {
    final coords = payload.coords;
    final ox = localOrigin.x;
    final oy = localOrigin.y;

    switch (kind) {
      case EntityKind.point:
        sink.point(coords[0] - ox, coords[1] - oy, style);

      case EntityKind.line:
      case EntityKind.polyline:
        final count = payload.pointCount;
        if (count == 0) return;
        _ensurePoints(count);
        for (var i = 0; i < count; i++) {
          _points[i * 2] = coords[i * 2] - ox;
          _points[i * 2 + 1] = coords[i * 2 + 1] - oy;
        }
        // `closed` is always false: the model carries no closed-polyline flag
        // yet. A DXF LWPOLYLINE has one, so this becomes a real read when the
        // DXF plan adds the field — not a decision made here.
        sink.polyline(_points, count, style, closed: false);

      case EntityKind.circle:
        // The radius is not a point and is not rebased; subtracting the origin
        // from it would shrink every circle by its distance to the origin.
        sink.circle(coords[0] - ox, coords[1] - oy, payload.scalars[0], style);

      case EntityKind.arc:
        // Neither the radius nor the two angles are rebased, for the same
        // reason. The residual carries no rotation of its own, so world angles
        // stay world angles.
        sink.arc(coords[0] - ox, coords[1] - oy, payload.scalars[0],
            payload.scalars[1], payload.scalars[2], style);

      case EntityKind.text:
      case EntityKind.attrib:
        _skippedText++;
    }
  }

  void _ensurePoints(int pointCount) {
    final needed = pointCount * 2;
    if (_points.length >= needed) return;
    var capacity = _points.length;
    while (capacity < needed) {
      capacity *= 2;
    }
    _points = Float64List(capacity);
  }
}

final Transform2 _identity = Transform2.identity();
