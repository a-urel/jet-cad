import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'camera_controller.dart';
import 'draw_sink.dart';
import 'viewport_transform.dart';

/// How far from conformal a curve's screen transform may be before its baked
/// stroke width stops being close enough.
///
/// **Diagnostic only.** It gates no drawing decision: points, lines and
/// polylines are carried into screen space regardless, and curves take the
/// residual path regardless. All it decides is whether a curve is counted in
/// [DraftPainter.anisotropicCurveCount].
const double kAnisotropyThreshold = 2.0;

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
    this.debugDisableRebasing = false,
  });

  final DraftDocument document;
  final SpatialIndex index;
  final StyleResolver resolver;

  /// **Test-only.** Paints with the rebase origin pinned at the world origin.
  ///
  /// Exists so the damage the rebase prevents can be measured rather than
  /// argued about: at 4.5e6, float32 spacing is about 0.5 units, and a test
  /// that shows the drawing moving with this on is what makes the assertions
  /// about small residuals mean something.
  final bool debugDisableRebasing;

  /// Reused across frames; the frame path must not allocate once warm.
  Float64List _points = Float64List(256);
  int get leafBufferCapacity => _points.length;

  /// This frame's visible root-level instances, ascending. Copied out of the
  /// query rather than held by reference: both rect queries share one set of
  /// scratch buffers inside `SpatialIndex`.
  Uint32List _instances = Uint32List(64);
  int _instanceCount = 0;
  int get instanceBufferCapacity => _instances.length;

  /// This frame's culling rectangle in world space. A field, not a parameter,
  /// because the instance walk is reached from inside a query visitor and
  /// threading it through would put a closure on the frame path.
  Aabb2 _worldRect = Aabb2.empty();

  /// One scratch per recursion depth reached so far, reused across frames.
  final List<_DepthScratch> _depths = <_DepthScratch>[];

  List<int> get depthBufferCapacities =>
      [for (final d in _depths) d.leaves.capacity];

  /// Instance chains deeper than this are not drawn.
  ///
  /// The tree rejects cycles, so this should be unreachable — but it is
  /// reached by recursion on the frame path, where an unbounded walk is a
  /// stack overflow rather than a wrong picture. Counted, not silent.
  static const int maxDepth = 64;
  int _skippedDeepInstances = 0;

  /// Instances not drawn in the last frame because they sat below [maxDepth].
  int get skippedDeepInstanceCount => _skippedDeepInstances;

  int _screenSpaceLeaves = 0;
  int _anisotropicCurves = 0;

  /// Leaves drawn with their points already carried into screen space, under
  /// the frame's shared translation residual.
  ///
  /// Every point, line and polyline drawn in the frame. Plan 3a's
  /// `bypassCount` counted the minority that took this path when their
  /// transform was past [kAnisotropyThreshold]; the path is now the rule, so
  /// the name changed with the meaning rather than quietly keeping it.
  int get screenSpaceLeafCount => _screenSpaceLeaves;

  /// Circles and arcs drawn in the last frame under a transform past
  /// [kAnisotropyThreshold], where their stroke width is an approximation.
  ///
  /// They cannot take the bypass: such a transform turns a circle into an
  /// ellipse, and [DrawSink.circle] carries one radius. `Canvas` still draws
  /// the ellipse correctly through the residual — it is only the width that is
  /// wrong, by up to the anisotropy ratio. Counted so the results note can say
  /// how often it happens instead of implying it never does.
  int get anisotropicCurveCount => _anisotropicCurves;

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
  ///
  /// The merge compares handle values across the two streams, so it has no
  /// answer for a tie — and needs none, because a handle names one thing in
  /// the document. `AddEntityCommand` and `AddNodeCommand` each reject a
  /// handle the other store already holds; that guard is what makes this
  /// comparison total.
  void paint(DrawSink sink, ViewportTransform camera, Size viewport) {
    _skippedText = 0;
    _skippedDeepInstances = 0;
    _screenSpaceLeaves = 0;
    _anisotropicCurves = 0;
    final world = camera.visibleWorld(viewport);
    _worldRect = world;
    final origin =
        debugDisableRebasing ? Vector2.zero() : rebaseOriginFor(world);
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

  /// Draws one root-level instance by descending into its definition.
  ///
  /// The instance pushes no residual of its own. Every leaf it reaches pushes
  /// the whole chain — `camera . ancestors . instance . placement . rebase` —
  /// so wrapping them in the instance's transform as well would apply it
  /// twice.
  void _drawInstance(DrawSink sink, ViewportTransform camera, Vector2 origin,
      Handle instance) {
    final node = document.tree[instance];
    if (node is! InstanceNode) return;
    _drawContainer(
      sink: sink,
      camera: camera,
      origin: origin,
      container: node.definition,
      // camera . ancestors . instance, still in Float64 and not yet rebased.
      accumulated: node.transform,
      ctx: resolver.contextFor(instance, StyleContext.documentRoot),
      depth: 0,
    );
  }

  void _drawContainer({
    required DrawSink sink,
    required ViewportTransform camera,
    required Vector2 origin,
    required Handle container,
    required Transform2 accumulated,
    required StyleContext ctx,
    required int depth,
  }) {
    if (depth >= maxDepth) {
      _skippedDeepInstances++;
      return;
    }
    final ci = index.indexFor(container);
    if (ci == null) return;

    // The query rectangle has to be expressed in the container's own space,
    // which a placement with no inverse cannot do. Such a container collapses
    // to a line or a point on screen, so nothing is lost by leaving it out —
    // and `invert()` would otherwise throw here, per instance, per frame.
    final det = accumulated.determinant;
    if (det == 0.0 || !det.isFinite) return;
    final localRect = _worldRect.transformedBy(accumulated.invert());

    final scratch = _scratchAt(depth);
    scratch.leaves.reset();
    // searchLeaves is neither ordered nor deduplicated: it walks the packed
    // tree and then the dirty overlay, and a slot in both is visited twice by
    // design. Both are this caller's job.
    ci.searchLeaves(localRect, scratch.leaves.add);
    scratch.leaves.sortByHandle(document.entities);
    scratch.collectInstances(ci, localRect);

    var next = 0;
    var previous = -1;
    for (var i = 0; i < scratch.leaves.length; i++) {
      final slot = scratch.leaves[i];
      final leafHandle = document.entities.handleAt(slot).value;
      if (leafHandle == previous) continue; // the tree/overlay duplicate
      previous = leafHandle;
      while (next < scratch.instanceCount &&
          scratch.instanceHandles[next] < leafHandle) {
        _descend(
            sink, camera, origin, ci, scratch, next++, accumulated, ctx, depth);
      }
      final leafT = ci.transformOfLeaf(slot);
      _drawLeafComposed(sink, camera, origin,
          leafT == null ? accumulated : accumulated.multiply(leafT), slot, ctx);
    }
    while (next < scratch.instanceCount) {
      _descend(
          sink, camera, origin, ci, scratch, next++, accumulated, ctx, depth);
    }
  }

  void _descend(
      DrawSink sink,
      ViewportTransform camera,
      Vector2 origin,
      ContainerIndex ci,
      _DepthScratch scratch,
      int at,
      Transform2 accumulated,
      StyleContext ctx,
      int depth) {
    final index = scratch.instanceIndices[at];
    if (index < 0) return;
    final handle = Handle(scratch.instanceHandles[at]);
    final node = document.tree[handle];
    if (node is! InstanceNode) return;
    _drawContainer(
      sink: sink,
      camera: camera,
      origin: origin,
      container: node.definition,
      accumulated: accumulated.multiply(ci.instanceTransformAt(index)),
      ctx: resolver.contextFor(handle, ctx),
      depth: depth + 1,
    );
  }

  _DepthScratch _scratchAt(int depth) {
    while (_depths.length <= depth) {
      _depths.add(_DepthScratch());
    }
    return _depths[depth];
  }

  void _drawLeaf(DrawSink sink, ViewportTransform camera, Vector2 origin,
          Transform2? leafTransform, int slot, StyleContext ctx) =>
      _drawLeafComposed(
          sink, camera, origin, leafTransform ?? _identity, slot, ctx);

  /// Draws one leaf whose placement — every transform between its stored
  /// coordinates and world space — is already composed.
  void _drawLeafComposed(DrawSink sink, ViewportTransform camera,
      Vector2 origin, Transform2 placement, int slot, StyleContext ctx) {
    final kind = document.entities.kindAt(slot);
    final payload = document.geometry.peek(document.entities.geomIndexAt(slot));
    final style = resolver.styleFor(slot, ctx);

    // `Paint.strokeWidth` is a single scalar measured in the residual's units,
    // so it can only be right when the residual scales both axes alike. Points,
    // lines and polylines avoid the question entirely: their points are carried
    // into screen space here in Float64 and the residual is a pure translation,
    // so the sink's width is the exact paper width with nothing divided out.
    //
    // This was the anisotropy bypass, taken only past kAnisotropyThreshold. The
    // threshold was never why it works — a conformal transform has the same
    // property — so it is now the rule rather than the exception, and one
    // residual value serves every line-like leaf in the frame.
    final toScreen = camera.worldToScreenMatrix.multiply(placement);
    switch (kind) {
      case EntityKind.point:
      case EntityKind.line:
      case EntityKind.polyline:
        _screenSpaceLeaves++;
        _emitScreenSpace(
            sink, camera, toScreen, origin, slot, kind, payload, style);
        return;
      case EntityKind.circle:
      case EntityKind.arc:
        // Curves keep the residual path: an anisotropic transform turns a
        // circle into an ellipse, and DrawSink.circle carries one radius.
        // What a sink does with that residual is a sink decision.
        if (toScreen.anisotropyRatio > kAnisotropyThreshold) {
          _anisotropicCurves++;
        }
      case EntityKind.text:
      case EntityKind.attrib:
        break;
    }

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

    sink.beginResidual(chain, debugHandle: document.entities.handleAt(slot));
    _emit(sink, kind, payload, localOrigin, style);
    sink.endResidual();
  }

  /// Draws a leaf with its points already carried into screen space.
  ///
  /// The residual left for `Canvas` is a pure translation, so its scale is 1
  /// and the stroke width the sink computes is the exact paper width in device
  /// pixels — nothing divided out of it, and nothing wrong on either axis.
  /// Rebasing here is in screen space, since that is the space the points are
  /// now in.
  void _emitScreenSpace(
      DrawSink sink,
      ViewportTransform camera,
      Transform2 toScreen,
      Vector2 origin,
      int slot,
      EntityKind kind,
      GeometryPayload payload,
      ResolvedStyle style) {
    final screenOrigin = camera.worldToScreen(origin);
    final coords = payload.coords;
    final count = payload.pointCount;
    if (count == 0) return;

    _ensurePoints(count);
    for (var i = 0; i < count; i++) {
      final x = coords[i * 2];
      final y = coords[i * 2 + 1];
      _points[i * 2] =
          toScreen.a * x + toScreen.c * y + toScreen.e - screenOrigin.x;
      _points[i * 2 + 1] =
          toScreen.b * x + toScreen.d * y + toScreen.f - screenOrigin.y;
    }

    sink.beginResidual(Transform2.translation(screenOrigin.x, screenOrigin.y),
        debugHandle: document.entities.handleAt(slot));
    if (kind == EntityKind.point) {
      sink.point(_points[0], _points[1], style);
    } else {
      sink.polyline(_points, count, style, closed: false);
    }
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

/// One recursion depth's reusable buffers.
///
/// A depth, not a container: the walk visits one container at a time per
/// depth, and a definition placed five hundred times reuses the same buffers
/// five hundred times over.
class _DepthScratch {
  final QueryScratch leaves = QueryScratch(64);

  /// Visible instance handles, ascending, and the position each one occupies
  /// in its container's parallel instance arrays.
  Uint32List instanceHandles = Uint32List(16);
  Int32List instanceIndices = Int32List(16);
  int instanceCount = 0;

  void collectInstances(ContainerIndex ci, Aabb2 localRect) {
    instanceCount = 0;
    ci.searchInstances(localRect, _add);
    _sortByHandle();
    if (instanceCount == 0) return;
    // One pass over the container's instances to resolve positions, rather
    // than `transformOfInstance` per visible instance: that accessor is a
    // linear `indexOf`, so calling it once per visible instance is quadratic
    // in a container that holds many.
    for (var i = 0; i < ci.instanceCount; i++) {
      final at = _positionOf(ci.instanceHandleAt(i).value);
      if (at >= 0) instanceIndices[at] = i;
    }
  }

  void _add(Handle node) {
    if (instanceCount == instanceHandles.length) {
      instanceHandles = Uint32List(instanceHandles.length * 2)
        ..setRange(0, instanceCount, instanceHandles);
      instanceIndices = Int32List(instanceIndices.length * 2)
        ..setRange(0, instanceCount, instanceIndices);
    }
    instanceHandles[instanceCount] = node.value;
    // Overwritten by `collectInstances`; -1 means "not found in the
    // container", which `_descend` skips rather than indexing with.
    instanceIndices[instanceCount] = -1;
    instanceCount++;
  }

  /// Insertion sort: a container holds few instances, and the two parallel
  /// arrays have to move together.
  void _sortByHandle() {
    for (var i = 1; i < instanceCount; i++) {
      final handle = instanceHandles[i];
      final index = instanceIndices[i];
      var j = i - 1;
      while (j >= 0 && instanceHandles[j] > handle) {
        instanceHandles[j + 1] = instanceHandles[j];
        instanceIndices[j + 1] = instanceIndices[j];
        j--;
      }
      instanceHandles[j + 1] = handle;
      instanceIndices[j + 1] = index;
    }
  }

  int _positionOf(int handle) {
    var low = 0;
    var high = instanceCount - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final value = instanceHandles[mid];
      if (value == handle) return mid;
      if (value < handle) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return -1;
  }
}
