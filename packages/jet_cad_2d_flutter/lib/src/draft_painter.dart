import 'dart:math' as math;
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

/// Text whose on-screen cap height is below this many **logical** pixels is not
/// drawn, and not laid out either.
///
/// Below three pixels of cap height a glyph cannot resolve two strokes, so
/// nothing readable is lost. Logical rather than device pixels is deliberate:
/// on a 2x display the same text is six device pixels tall, so this culls
/// *less* than a device-pixel rule would — the safe direction, the same one
/// [kScreenClipInflate] takes.
///
/// **Two alternatives were considered and are not taken.** *Greeking* — drawing
/// a bar the width of the text instead of the glyphs, so a zoomed-out plan
/// keeps its visual weight — is cheap to draw (two batched triangles in
/// `VerticesDrawSink`) but needs `advanceWidth`, so either the layout happens
/// anyway and the saving is lost, or a font-free width model
/// (`text.length * ratio`, the shape `MetricModelMeasurer` uses) becomes a new
/// approximation to defend. *Two tiers* — greek in a middle band, nothing
/// beyond it — is closest to real CAD and the most control, at two constants,
/// two counters, two golden ladders, and the same font-free width model.
/// Neither is ruled out later; both were priced and deferred.
const double kMinTextCapPixels = 3.0;

/// How far past the viewport, in device pixels, the frame's clip reaches.
///
/// Half the widest stroke the frame can draw, so a stroke whose centreline is
/// just outside still contributes its visible edge. Named rather than inlined
/// because it is the painter's *published* culling slack: the differential
/// oracle has to know how much extra the painter is entitled to draw, and a
/// number defined in two places is a number the two will eventually disagree
/// on.
const double kScreenClipInflate = 32.0;

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
    this.drawText = true,
    this.minTextCapPixels = kMinTextCapPixels,
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

  /// **Measurement-only, inert at its default of `true`.**
  ///
  /// Task 12's rigs report every text counter twice, once with text drawing
  /// and once without, and the delta between the two rows is only readable as
  /// *the cost of text* if nothing else about the frame moved. Rebuilding the
  /// corpus with `labelFraction: 0` would move the entity mix, the extents and
  /// therefore both cameras; this moves one branch.
  ///
  /// Turning it off skips a text leaf before anything is resolved for it, so
  /// the delta covers attribute resolution, layout composition and the
  /// paragraph lookup together. It also leaves [skippedTextCount] at zero,
  /// because that counter means *empty string*, not *not drawn*.
  final bool drawText;

  /// Cap height in logical pixels below which a text leaf is culled.
  ///
  /// **`0.0` disables level of detail**, which is what the exit gate's control
  /// arm needs: LOD-on and LOD-off must be compared on the same corpus at the
  /// same camera, or the two rows are two different documents.
  ///
  /// `final` for the reason [drawText] is: the painter is built once and a rig
  /// that flipped this after the fact would be measuring a rebuilt painter,
  /// which is a different frame.
  final double minTextCapPixels;

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

  int _skippedFills = 0;

  /// Fills drawn in the last frame, handed to a sink.
  ///
  /// Reset in the same place [screenSpaceLeafCount] is, so it reads as a
  /// per-frame figure alongside [skippedFillCount] rather than a running
  /// total — Task 16's rig reports both.
  int _fills = 0;
  int get fillCount => _fills;

  /// Fills not drawn in the last frame because their boundary could not be
  /// resolved or its triangulation was empty.
  ///
  /// The painter owns this skip rather than a sink: `CanvasDrawSink` fills a
  /// self-intersecting path by non-zero winding while `VerticesDrawSink`,
  /// given no triangles, draws nothing. Handing either of them an unfillable
  /// fill would manufacture a backend divergence on exactly the case this
  /// plan refuses, so neither is ever handed one.
  int get skippedFillCount => _skippedFills;

  int _skippedText = 0;

  /// Text entities not drawn in the last frame.
  ///
  /// Since Plan 3c Task 10 text draws, so this counts one thing only: a text
  /// or attrib entity whose string is empty, which has nothing to hand
  /// `Canvas`. It stays because the generated corpus's plain floor texts are
  /// all blank, and a measurement taken over them would otherwise read as a
  /// measurement of drawn text.
  int get skippedTextCount => _skippedText;

  int _culledText = 0;

  /// Text and attrib entities culled in the last frame for being too small to
  /// read — see [kMinTextCapPixels].
  ///
  /// **Separate from [skippedTextCount] on purpose.** That one means *empty
  /// string*; this one means *below the threshold*. Blended, the exit gate
  /// cannot tell which mechanism fired, which is the mistake Ruling 54 records
  /// for the paragraph cache's hit rate.
  int get culledTextCount => _culledText;

  int _textOps = 0;

  /// Text and attrib entities handed to [DrawSink.text] in the last frame.
  ///
  /// The other half of [skippedTextCount]: together they account for every
  /// text leaf that survived culling. Reported by the rigs because a paragraph
  /// cache's hit rate is meaningless without the number of lookups it is a
  /// rate over — `layoutCount` alone cannot tell one layout in one draw from
  /// one layout in ten thousand.
  int get textOpCount => _textOps;

  /// One text layout for every text leaf in the frame, refilled in place.
  ///
  /// **Measured, not stylistic.** The allocating wrappers over this class —
  /// `resolveTextAttributes` and `textLocalTransform` — build one
  /// `TextLayout` each, plus the `Float64List` each of those carries, plus a
  /// `ResolvedTextAttributes`, plus a `Vector2` for the anchor and its own
  /// `Float64List`, plus an intermediate `Transform2`. That was measured at
  /// **nine allocations per text leaf against a residual-path norm of one**
  /// (`packages/jet_cad_2d/test/invariants/text_paint_allocation_test.dart`),
  /// which is Ruling 20's threshold for doing something about it. Filling one
  /// long-lived layout in place instead takes it back to the norm. The
  /// engine's pick path made the same move, for the same reason and against
  /// the same measurement — see [TextLayout]'s own doc comment.
  final TextLayout _textLayout = TextLayout();

  final Dasher _dasher = Dasher();

  int _dashSpans = 0;

  /// Dash spans emitted in the last frame.
  int get dashSpanCount => _dashSpans;

  /// Entities whose dash pattern collapsed to solid in the last frame.
  int get collapsedDashCount => _dasher.collapsedCount;

  /// The clip the dasher generates inside, in the space the carried points are
  /// in — screen space **minus the frame's screen origin**.
  ///
  /// Inflated by half the widest stroke the frame can draw, so a stroke whose
  /// centreline is just outside still contributes its visible edge. Rebased
  /// once per frame rather than un-rebasing every point back into raw screen
  /// space to compare them.
  Aabb2 _rebasedClip = Aabb2.empty();

  /// The same box before the rebase subtraction, for the curves that stay in
  /// their own local space.
  Aabb2 _screenSpaceClip = Aabb2.empty();

  /// The frame's rebase origin in screen space. Constant for the whole frame,
  /// so it is computed in [paint] rather than per leaf.
  Vector2 _screenOrigin = Vector2.zero();

  /// One two-point buffer, reused per span. A span is emitted through the sink
  /// immediately, so it never needs to outlive the callback.
  final Float64List _span = Float64List(4);

  // The dasher's callbacks, bound once. A closure literal at the call site
  // would allocate per dashed entity per frame; these capture nothing and read
  // the two varying values from fields the caller sets just before the call.
  DrawSink? _spanSink;
  ResolvedStyle? _spanStyle;

  // ignore: prefer_function_declarations_over_variables
  late final DashSpanEmit _emitSpan =
      (double x0, double y0, double x1, double y1) {
    _span[0] = x0;
    _span[1] = y0;
    _span[2] = x1;
    _span[3] = y1;
    _dashSpans++;
    _spanSink!.polyline(_span, 2, _spanStyle!, closed: false);
  };

  double _arcCx = 0, _arcCy = 0, _arcR = 0;

  // ignore: prefer_function_declarations_over_variables
  late final DashArcEmit _emitArc = (double startAngle, double sweep) {
    _dashSpans++;
    _spanSink!.arc(_arcCx, _arcCy, _arcR, startAngle, sweep, _spanStyle!);
  };

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
    _culledText = 0;
    _textOps = 0;
    _skippedDeepInstances = 0;
    _screenSpaceLeaves = 0;
    _anisotropicCurves = 0;
    _fills = 0;
    _skippedFills = 0;
    final world = camera.visibleWorld(viewport);
    _worldRect = world;
    final origin =
        debugDisableRebasing ? Vector2.zero() : rebaseOriginFor(world);
    _dashSpans = 0;
    _dasher.resetCounters();
    _screenOrigin = camera.worldToScreen(origin);
    const inflate = kScreenClipInflate;
    _screenSpaceClip = Aabb2(Vector2(-inflate, -inflate),
        Vector2(viewport.width + inflate, viewport.height + inflate));
    _rebasedClip = Aabb2(
        Vector2(-inflate - _screenOrigin.x, -inflate - _screenOrigin.y),
        Vector2(viewport.width + inflate - _screenOrigin.x,
            viewport.height + inflate - _screenOrigin.y));
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
        _emitScreenSpace(sink, toScreen, slot, kind, payload, style);
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
      case EntityKind.fill:
        _drawFill(sink, camera, origin, placement, slot, style);
        return;
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

    if (kind == EntityKind.text || kind == EntityKind.attrib) {
      _drawText(sink, slot, payload, style, chain, localOrigin);
      return;
    }

    sink.beginResidual(chain, debugHandle: document.entities.handleAt(slot));
    // `chain`, not `toScreen`: the geometry `_emit` receives has already had
    // `localOrigin` subtracted (that is what "rebased local" means), and
    // `chain` — `toScreen . translate(localOrigin)` — is the transform that
    // maps *that* rebased frame to screen, exactly the one this residual
    // pushes. `toScreen` alone maps the *unrebased* local frame to screen, a
    // frame apart by `localOrigin`; handing it to a clip pullback silently
    // clipped a dashed curve against the wrong window on any pan where the
    // rebase origin was non-zero. See `_localClipFor`.
    _emit(sink, kind, payload, localOrigin, style, chain);
    sink.endResidual();
  }

  /// Draws a leaf with its points already carried into screen space.
  ///
  /// The residual left for `Canvas` is a pure translation, so its scale is 1
  /// and the stroke width the sink computes is the exact paper width in device
  /// pixels — nothing divided out of it, and nothing wrong on either axis.
  /// Rebasing here is in screen space, since that is the space the points are
  /// now in. Reads the frame's [_screenOrigin] rather than recomputing
  /// `camera.worldToScreen(origin)` per leaf — it is the same value all frame.
  void _emitScreenSpace(DrawSink sink, Transform2 toScreen, int slot,
      EntityKind kind, GeometryPayload payload, ResolvedStyle style) {
    final coords = payload.coords;
    final count = payload.pointCount;
    if (count == 0) return;

    _ensurePoints(count);
    for (var i = 0; i < count; i++) {
      final x = coords[i * 2];
      final y = coords[i * 2 + 1];
      _points[i * 2] =
          toScreen.a * x + toScreen.c * y + toScreen.e - _screenOrigin.x;
      _points[i * 2 + 1] =
          toScreen.b * x + toScreen.d * y + toScreen.f - _screenOrigin.y;
    }

    sink.beginResidual(Transform2.translation(_screenOrigin.x, _screenOrigin.y),
        debugHandle: document.entities.handleAt(slot));
    if (kind == EntityKind.point) {
      sink.point(_points[0], _points[1], style);
      sink.endResidual();
      return;
    }
    final pattern = _patternFor(style);
    if (pattern == null) {
      // `closed` is always false: the model carries no closed-polyline flag
      // yet. A DXF LWPOLYLINE has one, so this becomes a real read when the
      // DXF plan adds the field — not a decision made here. This is the only
      // place the painter can pass it: `_emit`'s polyline case is dead.
      sink.polyline(_points, count, style, closed: false);
      sink.endResidual();
      return;
    }
    // The emitter is a field bound once (see `_emitSpan` above), not a closure
    // written here: a closure literal that captures `sink` and `style` is a
    // fresh object on every dashed leaf of every frame, against the global
    // constraint that the frame path allocates nothing once warm. The two
    // captured values move into fields instead.
    _spanSink = sink;
    _spanStyle = style;
    if (!_dasher.dashPolyline(_points, count, pattern,
        _dashScale(style, toScreen), _rebasedClip, _emitSpan)) {
      sink.polyline(_points, count, style, closed: false);
    }
    sink.endResidual();
  }

  /// The pattern for [style], or null when the entity is continuous.
  DashPattern? _patternFor(ResolvedStyle style) {
    final record = document.tables.linetypes[style.linetype];
    final pattern = record?.pattern;
    if (pattern == null || pattern.dashes.isEmpty) return null;
    return pattern;
  }

  /// Pattern units to device pixels.
  ///
  /// `entity scale × document scale × the composed screen scale`. The last is
  /// `sqrt(|det|)` of the full world-to-screen chain — the same representative
  /// scale the stroke width uses, and under an anisotropic placement it is an
  /// approximation for the same reason, counted in [anisotropicCurveCount]'s
  /// company rather than assumed away.
  double _dashScale(ResolvedStyle style, Transform2 toScreen) =>
      style.linetypeScale *
      document.header.globalLinetypeScale *
      toScreen.scaleMagnitude;

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

  /// Draws one fill, or skips it and says so.
  ///
  /// A fill has no geometry of its own: it occupies its boundary's loop and
  /// follows its boundary's route through this painter -- screen space for a
  /// polygon, the residual path for a circle -- so a filled shape and its own
  /// outline are transformed by the same code.
  ///
  /// **The skip lives here, not in a sink.** `CanvasDrawSink` fills a
  /// self-intersecting path by non-zero winding while `VerticesDrawSink`,
  /// given no triangles, draws nothing. Handing either of them an unfillable
  /// fill manufactures a backend divergence on exactly the case this plan
  /// refuses, so neither is ever handed one.
  void _drawFill(DrawSink sink, ViewportTransform camera, Vector2 origin,
      Transform2 placement, int slot, ResolvedStyle style) {
    final payload = document.geometry.peek(document.entities.geomIndexAt(slot));
    final boundary = boundaryHandleOf(payload);
    final boundarySlot = document.entities.slotOf(boundary);
    if (boundarySlot == null) {
      _skippedFills++;
      return;
    }
    final boundaryKind = document.entities.kindAt(boundarySlot);
    final boundaryPayload =
        document.geometry.peek(document.entities.geomIndexAt(boundarySlot));
    final toScreen = camera.worldToScreenMatrix.multiply(placement);

    if (boundaryKind == EntityKind.circle) {
      // Never triangulated ahead of time: a circle's tessellation is
      // scale-dependent, and the sink fans it at the step count its own
      // stroke uses.
      //
      // A malformed document can carry a circle boundary with no scalars —
      // `validate()` is what catches that off the frame path. Here it is
      // just another unfillable boundary: skipped and counted, not indexed
      // into and thrown from.
      if (boundaryPayload.scalars.isEmpty) {
        _skippedFills++;
        return;
      }
      final localOrigin = _localOriginFor(placement, origin);
      final chain = camera.worldToScreenMatrix
          .multiply(placement)
          .multiply(Transform2.translation(localOrigin.x, localOrigin.y));
      sink.beginResidual(chain, debugHandle: document.entities.handleAt(slot));
      sink.fillCircle(
          boundaryPayload.coords[0] - localOrigin.x,
          boundaryPayload.coords[1] - localOrigin.y,
          boundaryPayload.scalars[0],
          style);
      sink.endResidual();
      _fills++;
      return;
    }

    // Read, never compute: the triangulation was materialised by the
    // command, the codec or undo. A miss here means the boundary is
    // unfillable, not that the cache is cold.
    final triangles = document.fills.trianglesFor(boundary);
    if (triangles == null || triangles.isEmpty) {
      _skippedFills++;
      return;
    }

    final count = boundaryPayload.pointCount;
    _ensurePoints(count);
    for (var i = 0; i < count; i++) {
      final x = boundaryPayload.coords[i * 2];
      final y = boundaryPayload.coords[i * 2 + 1];
      _points[i * 2] =
          toScreen.a * x + toScreen.c * y + toScreen.e - _screenOrigin.x;
      _points[i * 2 + 1] =
          toScreen.b * x + toScreen.d * y + toScreen.f - _screenOrigin.y;
    }
    sink.beginResidual(Transform2.translation(_screenOrigin.x, _screenOrigin.y),
        debugHandle: document.entities.handleAt(slot));
    sink.fillPolygon(_points, count, triangles, style);
    sink.endResidual();
    _fills++;
  }

  void _emit(DrawSink sink, EntityKind kind, GeometryPayload payload,
      Vector2 localOrigin, ResolvedStyle style, Transform2 chain) {
    final coords = payload.coords;
    final ox = localOrigin.x;
    final oy = localOrigin.y;

    switch (kind) {
      case EntityKind.point:
      case EntityKind.line:
      case EntityKind.polyline:
        // Unreachable, for the same shape of reason as text and attrib below:
        // `_drawLeafComposed` routes all three through `_emitScreenSpace` and
        // returns, unconditionally, before it reaches this call. That routing
        // was the anisotropy bypass and is now the rule, so nothing gates it
        // any more and nothing can fall through to here.
        //
        // These three carried working bodies until they were emptied. They
        // were not layered guards — they were a second implementation of
        // `_emitScreenSpace`'s job, in a different space, that no frame could
        // reach: this one rebases in *local* coordinates and pushes `chain`,
        // where `_emitScreenSpace` rebases in *screen* coordinates and pushes
        // a bare translation. A reader had no way to tell which one the
        // painter used, and the one they would have read is the dead one.
        // Kept as exhaustive cases rather than a `default` so a new
        // EntityKind still fails to compile here.
        break;

      case EntityKind.circle:
        // The radius is not a point and is not rebased; subtracting the origin
        // from it would shrink every circle by its distance to the origin.
        final r = payload.scalars[0];
        final pattern = _patternFor(style);
        if (pattern == null) {
          sink.circle(coords[0] - ox, coords[1] - oy, r, style);
          return;
        }
        _spanSink = sink;
        _spanStyle = style;
        _arcCx = coords[0] - ox;
        _arcCy = coords[1] - oy;
        _arcR = r;
        // The circle's centre is in rebased-local space (localOrigin already
        // subtracted), so the clip has to be pulled back through `chain` —
        // the transform that maps *that* frame to screen — not `toScreen`,
        // which maps the unrebased local frame instead. See the comment on
        // `chain` at the call site and on `_localClipFor`. A curve under a
        // non-invertible placement was already dropped by `_drawContainer`,
        // so `chain` is invertible here.
        if (!_dasher.dashArc(
            _arcCx,
            _arcCy,
            r,
            0,
            2 * math.pi,
            pattern,
            // Local units: no `chain.scaleMagnitude` here, because `r` and
            // the clip are not in pixels either.
            style.linetypeScale * document.header.globalLinetypeScale,
            _localClipFor(chain),
            _emitArc,
            // A pure translation does not change a scale magnitude, so this
            // is the same value `toScreen.scaleMagnitude` would have given —
            // only the clip pullback needed the rebase-aware transform.
            pixelScale: chain.scaleMagnitude)) {
          sink.circle(_arcCx, _arcCy, r, style);
        }

      case EntityKind.arc:
        // Neither the radius nor the two angles are rebased, for the same
        // reason. The residual carries no rotation of its own, so world angles
        // stay world angles.
        final r = payload.scalars[0];
        final start = payload.scalars[1];
        final sweep = payload.scalars[2];
        final pattern = _patternFor(style);
        if (pattern == null) {
          sink.arc(coords[0] - ox, coords[1] - oy, r, start, sweep, style);
          return;
        }
        _spanSink = sink;
        _spanStyle = style;
        _arcCx = coords[0] - ox;
        _arcCy = coords[1] - oy;
        _arcR = r;
        if (!_dasher.dashArc(
            _arcCx,
            _arcCy,
            r,
            start,
            sweep,
            pattern,
            style.linetypeScale * document.header.globalLinetypeScale,
            _localClipFor(chain),
            _emitArc,
            pixelScale: chain.scaleMagnitude)) {
          sink.arc(_arcCx, _arcCy, r, start, sweep, style);
        }

      case EntityKind.text:
      case EntityKind.attrib:
        // Unreachable: `_drawLeafComposed` routes text to `_drawText` before
        // it pushes a residual at all, because a text leaf's residual is not
        // `chain`. Kept as an exhaustive case rather than a `default` so a
        // new EntityKind still fails to compile here.
        break;

      case EntityKind.fill:
        // Unreachable: `_drawLeafComposed` routes a fill to `_drawFill` and
        // returns, unconditionally, before it reaches this call — a fill
        // follows its boundary's route (screen space for a polygon, the
        // residual path for a circle), neither of which is this one. Kept as
        // an exhaustive case rather than a `default` so a new EntityKind
        // still fails to compile here.
        break;
    }
  }

  /// Draws one text or attrib leaf under `chain . textLocal`.
  ///
  /// Text does not go through [_emit]. Its placement — height, rotation,
  /// width factor, oblique angle and justification — *is* a transform, and
  /// `DrawSink.text` carries no coordinates at all, so that placement can
  /// only reach the canvas as part of the residual. It is composed into
  /// `chain` rather than pushed as a second, inner residual because
  /// `beginResidual` does not nest: `CanvasDrawSink` overwrites its residual
  /// and clears it again on `endResidual`, so an inner pair would leave the
  /// outer one at the identity.
  void _drawText(DrawSink sink, int slot, GeometryPayload payload,
      ResolvedStyle style, Transform2 chain, Vector2 localOrigin) {
    if (!drawText) return;
    final text = document.entities.textAt(slot);
    if (text.isEmpty) {
      // Nothing to draw, and still counted: the generated corpus's plain
      // floor texts carry the empty string, so without this the counter
      // would read zero on a document whose text is entirely blank.
      _skippedText++;
      return;
    }
    final styleHandle = document.entities.textStyleAt(slot);
    final record = document.textStyleOf(styleHandle);
    // Resolved before the metrics are asked for, and that ordering is the whole
    // mechanism. `resolve` needs no metrics — height, rotation, width factor,
    // oblique angle and justification all come from the payload, the attribute
    // bits and the style record — while `measure` is the expensive call. A cull
    // placed after `measure` would skip the draw and save no layout at all.
    final layout = _textLayout
      ..resolve(payload, document.entities.textAttrsAt(slot), record);
    // `layout.height` is the effective DXF text height, which *is* the cap
    // height, in world units; `chain` carries camera, ancestors, instance,
    // placement and rebase. The product is the on-screen cap height in pixels,
    // with no measurement involved.
    //
    // `scaleMagnitude` is the geometric mean of the axis scales, so text
    // squashed in y under an anisotropic placement reads taller than it renders
    // and survives longer than it should. Same approximation the painter
    // already makes for curve stroke widths past [kAnisotropyThreshold], and it
    // errs toward drawing.
    if (layout.height * chain.scaleMagnitude < minTextCapPixels) {
      _culledText++;
      return;
    }
    final metrics = document.textMeasurer.measure(text: text, style: record);
    // The anchor is rebased like every other coordinate that reaches `chain`,
    // which already carries `translate(localOrigin)`. An unrebased anchor is
    // exactly right at the origin and one rebase origin wrong everywhere else —
    // the failure a fixture at (0, 0) cannot see.
    layout.composeTransform(metrics, payload.coords[0] - localOrigin.x,
        payload.coords[1] - localOrigin.y);
    sink
      ..beginResidual(
          chain.multiply(Transform2(
              layout.a, layout.b, layout.c, layout.d, layout.e, layout.f)),
          debugHandle: document.entities.handleAt(slot))
      ..text(text, styleHandle, style)
      ..endResidual();
    _textOps++;
  }

  /// The frame's clip expressed in a leaf's own **rebased-local** space —
  /// the frame the coordinates `_emit` draws in actually live in, since
  /// `localOrigin` has already been subtracted from them there.
  ///
  /// A curve is not carried into screen space — it keeps the residual path —
  /// so its coordinates are local and the clip has to meet them there. The
  /// transformed box is an over-approximation under rotation, which is the
  /// safe direction: it clips less, never more.
  ///
  /// [chain] must be the full residual — `toScreen . translate(localOrigin)`
  /// — not `toScreen` alone. `toScreen` maps the *unrebased* local frame to
  /// screen; the circle/arc centre passed to the dasher is in the rebased
  /// frame, one `localOrigin` apart. Pulling the clip back through `toScreen`
  /// intersected a shifted circle against an unshifted window and silently
  /// dropped over 90% of a dashed curve's spans on any pan where the rebase
  /// origin was non-zero — caught by
  /// `'rebasing does not clip a dashed curve out of its own frame'`.
  Aabb2 _localClipFor(Transform2 chain) {
    final det = chain.determinant;
    if (det == 0.0 || !det.isFinite) return _rebasedClip;
    return _screenSpaceClip.transformedBy(chain.invert());
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
