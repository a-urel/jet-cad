import 'dart:async' show StreamSubscription, unawaited;
import 'dart:math' as math;
import 'dart:typed_data' show Float64List;
import 'dart:ui' show Canvas, Offset, Paint, PaintingStyle, Size;

import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, visibleForTesting;
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'dimension.dart';
import 'dimension_attach.dart';
import 'opening_geometry.dart' show wallsInDocument;
import 'wall.dart' show wallJoin;

/// An attach ring's radius, screen pixels (spec 11 D12, R-24).
const double kAttachRingPixels = 4;

/// The page a dimension reads when the root carries none (spec 11 D3), for
/// the preview and its value: the one `generate` reads.
final PageComponent _defaultPage = PageComponent();

/// The hover memo's size bound: a long hover among unchanged walls starts
/// it afresh past this many points, so it never grows without end.
const int _kMemoCap = 1024;

/// Spec 11 D12: the Dimension tool (I). A `PlacementTool` of **three clicks
/// per dimension** (decision 9), not chained (R-25): after the commit it
/// waits for a new first click, as 10's Separator tool.
///
/// - **Points** resolve through the drawing tools' chain (05 D4,
///   `kDragSnapMask`): object snap (F3), then the grid, else the raw point.
///   The third point too (R-22): only its height along the measuring
///   direction's normal, and for a linear kind its side, is used.
/// - **Shift** (R-20): at the second click, 05's ortho from the first
///   point; at the third, **linear**, with ortho off ([orthoBase] is null
///   once two points are placed). The tool records Shift from the pointer
///   events and the Shift key before `PlacementTool` sees them (S-8), since
///   [accept] does not carry it.
/// - **Click 2** is ignored when the pair is degenerate (R-23): the two
///   points within `wallJoin.linear`, or their attach candidates sharing a
///   wall end point. The tool keeps waiting for the second point.
/// - **Click 3** commits: the kind ([kindFor]), both ends decided **at the
///   commit** (decision 22) from candidates gathered afresh against the
///   document as it is then ([attachCandidates], [decideEnd]; decision 23:
///   by position while F3 is on), a [FixedEnd] where none attaches, and the
///   offset by D6's placement function ([offsetFor]). One
///   [CompoundCommand], the group at the identity and its
///   [DimensionParams]: one undo step, in which the dimension generates. A
///   refused commit places nothing.
/// - **Enter** does nothing while points are pending (R-33: `finish` stays
///   the default no-op); **Esc** and undo are `PlacementTool`'s (05 D3, D5).
///
/// **The preview** (R-24): after click 1 the rubber band from it to the
/// resolved hover point; after click 2 the would-be dimension's five lines
/// in world, for the kind Shift selects now, laid out by the functions
/// `generate` uses (the plan's Ruling 11-3: [kindFor], [decideEnd] among
/// the memoised candidates, [offsetFor], [layoutDimension]), so it equals
/// the committed children. It is rebuilt only when the resolved point,
/// Shift or the generation changes, into a cached array
/// ([debugPreviewBuilds]); [paintRubberBand] draws from it and computes
/// nothing. A dimension that cannot be laid out previews nothing and has no
/// value.
///
/// **The rings:** a [kAttachRingPixels] circle in the preview colour at each
/// placed or hovered point whose attach candidates are not empty, only
/// while F3 is on; decided on the pointer move, drawn per frame from flags.
///
/// **The notice** ([notice]): the would-be value while two points are
/// placed, exactly the TEXT's string in the page's unit (`4.69`); the
/// shell's status line appends it (`Dimension — 4.69`, S-8). Null
/// otherwise: after the commit, on Esc and on deactivation.
///
/// **The hover memo** (the plan's Ruling 11-8): the attach candidates per
/// distinct resolved point, and `T` ([thickestWall]), valid for one
/// **generation**. The generation moves on each `doc.changes` event, at the
/// tool's own commit, and on activation. `ToolController` calls no hook on
/// activation, only [cancel] on deactivation, so the tool learns it is
/// active at its first event with a context: it subscribes to the
/// document's changes there and moves the generation, and [cancel] drops
/// the subscription. **Every click gathers afresh** against the document as
/// it is then, and never reads the memo ([debugAttachSearches] counts every
/// search, hover or click).
class DimensionTool extends PlacementTool {
  DimensionTool();

  /// Whether Shift is held, as the last pointer event or Shift key said.
  bool _shift = false;

  /// The context of the last event, for the resolutions `PlacementTool`
  /// makes without one (a Shift press, a camera change) and the document's
  /// changes.
  ToolContext? _ctx;
  StreamSubscription<DocChange>? _changes;
  DraftDocument? _listened;
  bool _disposed = false;

  // The memo (Ruling 11-8), valid while [_memoGeneration] is [_generation].
  int _generation = 0;
  int _memoGeneration = -1;
  final Map<(double, double), List<AttachedEnd>> _memo = {};
  double _thickest = 0;

  /// The world point of each attached end the preview decided, per
  /// generation: laying out a wall among every other costs O(walls), so it
  /// is done once per end, not per move.
  final Map<AttachedEnd, Vector2?> _endPoints = {};

  // The rings: at the placed points and at the hover point.
  bool _ring0 = false, _ring1 = false, _ringHover = false;
  final Paint _ringPaint = Paint()
    ..color = kPreviewColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = kPreviewStrokePixels;

  /// The preview's five lines in world, `x0, y0, x1, y1` each: the
  /// dimension line, the extension lines at `a` and `b`, the slashes at `a`
  /// and `b` (the order `generate` makes them in).
  final Float64List _preview = Float64List(20);
  bool _hasPreview = false;
  DimKind? _previewKind;

  // What the cached preview was built for.
  bool _keyed = false;
  double _keyX = 0, _keyY = 0;
  bool _keyShift = false;
  int _keyGeneration = -1;

  final ValueNotifier<String?> _notice = ValueNotifier<String?>(null);

  /// How many `attachCandidates` searches the tool made, for hovers and
  /// clicks (spec 11 D12's costs, `TL8`).
  @visibleForTesting
  int debugAttachSearches = 0;

  /// How many times the preview after click 2 was built (`TL5`): once per
  /// change of the resolved point, Shift or the generation, never per
  /// frame.
  @visibleForTesting
  int debugPreviewBuilds = 0;

  /// The cached preview's five lines in world, as [paintRubberBand] draws
  /// them; empty when none is shown.
  @visibleForTesting
  List<(Vector2, Vector2)> get debugPreview => [
        if (_hasPreview)
          for (var i = 0; i < 20; i += 4)
            (
              Vector2(_preview[i], _preview[i + 1]),
              Vector2(_preview[i + 2], _preview[i + 3]),
            ),
      ];

  /// The kind the cached preview was built for, or null before any.
  @visibleForTesting
  DimKind? get debugPreviewKind => _previewKind;

  /// The would-be value while two points are placed, the page's unit (spec
  /// 11 D12, S-8); null otherwise. The shell's status line appends it.
  ValueListenable<String?> get notice => _notice;

  @override
  String get name => 'Dimension';

  /// R-20: 05's ortho at the second click; none once two points are placed,
  /// so the third point's drag side is where the person dragged, not an
  /// ortho-pinned point (M-11ortho3).
  @override
  Vector2? get orthoBase => points.length >= 2 ? null : super.orthoBase;

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    _attach(ctx);
    _shift = e.shift;
    super.onPointerMove(e, ctx);
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    _attach(ctx);
    _shift = e.shift;
    super.onPointerDown(e, ctx);
  }

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    _attach(ctx);
    final key = event.logicalKey;
    if ((key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight) &&
        event is! KeyRepeatEvent) {
      _shift = event is KeyDownEvent;
    }
    return super.onKey(event, ctx);
  }

  /// The kind a third point [q] commits for the pair [p0], [p1] (spec 11
  /// D12, R-21), in world (the tool's group is the identity):
  ///
  /// - without [shift], aligned;
  /// - with it, the side dragged to: `e_x` and `e_y`, how far [q] lies
  ///   outside the two points' x and y spans (0 inside); `e_y > e_x` is
  ///   horizontal (dragged above or below), `e_x > e_y` vertical (dragged
  ///   left or right), and a tie (both 0 inside the span box included)
  ///   horizontal when `|dx| ≥ |dy|`, else vertical;
  /// - a linear kind that would measure ≤ `wallJoin.linear` (a vertical pair
  ///   dragged above) gives way to the other, so a non-degenerate pair never
  ///   makes a zero linear dimension.
  ///
  /// The comparisons are exact: they choose between two valid outcomes from
  /// a pointer position, and a tie has no wrong answer.
  static DimKind kindFor(Vector2 q, Vector2 p0, Vector2 p1,
      {required bool shift}) {
    if (!shift) return DimKind.aligned;
    final ex = _outside(q.x, p0.x, p1.x), ey = _outside(q.y, p0.y, p1.y);
    final dx = (p1.x - p0.x).abs(), dy = (p1.y - p0.y).abs();
    final horizontal = ey > ex || (ey == ex && dx >= dy);
    if (horizontal) {
      return dx <= wallJoin.linear ? DimKind.vertical : DimKind.horizontal;
    }
    return dy <= wallJoin.linear ? DimKind.horizontal : DimKind.vertical;
  }

  /// How far [v] lies outside the span of [a] and [b]; 0 inside.
  static double _outside(double v, double a, double b) {
    final lo = math.min(a, b), hi = math.max(a, b);
    if (v < lo) return lo - v;
    if (v > hi) return v - hi;
    return 0;
  }

  static bool _objectSnap(ToolContext ctx) => ctx.snap?.objectSnap ?? true;

  /// [p]'s attach candidates against [ctx]'s document as it is now, with
  /// [thickest] its `T` computed now: never a memo (the plan's Ruling 11-8).
  List<AttachedEnd> _candidatesAt(ToolContext ctx, Vector2 p, double thickest) {
    debugAttachSearches++;
    return attachCandidates(ctx.document, ctx.index, p,
        objectSnap: _objectSnap(ctx), thickest: thickest);
  }

  /// R-23: whether [p1] as the second point makes a dimension of nothing
  /// with [p0]: within `wallJoin.linear` of it, or on a wall end point it
  /// also lies on.
  bool _degenerate(ToolContext ctx, Vector2 p0, Vector2 p1) {
    if ((p1 - p0).length <= wallJoin.linear) return true;
    final t = thickestWall(ctx.document);
    final c1 = _candidatesAt(ctx, p1, t);
    if (c1.isEmpty) return false;
    return _candidatesAt(ctx, p0, t).any(c1.contains);
  }

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      _refresh(ctx);
      return;
    }
    if (points.length == 1) {
      if (!_degenerate(ctx, points.first, point)) points.add(point);
      _refresh(ctx);
      return;
    }
    _commit(point, ctx);
    // The document changed: nothing memoised before it is read again. The
    // hover's ring is re-read at the next move (or when the change is
    // heard), so the commit itself makes its two searches only.
    _generation++;
    clearShape();
  }

  /// The third click at [q]: spec 11 D12's commit.
  void _commit(Vector2 q, ToolContext ctx) {
    final doc = ctx.document;
    final p0 = points[0], p1 = points[1];
    final kind = kindFor(q, p0, p1, shift: _shift);
    final m = Transform2.identity();
    final t = thickestWall(doc);
    // Decision 22: both ends at the commit, with the committed kind's
    // measuring direction, from candidates gathered now.
    DimEnd end(Vector2 at, Vector2 other) =>
        decideEnd(doc, _candidatesAt(ctx, at, t),
            kind: kind, at: at, other: other, m: m) ??
        FixedEnd(at.x, at.y);
    final a = end(p0, p1), b = end(p1, p0);
    final offset = offsetFor(q, p0, p1, kind, m);
    try {
      commit(ctx, () {
        // Allocated inside the build, after the permission check (Ruling
        // 05-3), never predicted.
        final h = doc.handleSeed.next();
        return CompoundCommand([
          AddNodeCommand(GroupNode(
              handle: h,
              parent: doc.rootHandle,
              transform: Transform2.identity(),
              children: const [])),
          SetComponentCommand<DimensionParams>(
              h, DimensionParams(a, b, kind, offset)),
        ], label: 'Add dimension');
      }, needs: const {
        Capability.structure,
        Capability.components,
        Capability.geometry,
      });
    } on ArgumentError {
      // Refused: nothing is placed.
    } on StateError {
      // Likewise.
    } on DanglingReferenceError {
      // An end's wall stopped being an object: nothing is placed.
    }
  }

  // ---------------------------------------------------------------------
  // The preview, the rings and the notice (spec 11 D12, R-24).

  /// The tool's first event with [ctx] since it was activated (or since a
  /// cancel): subscribes to the document's changes and moves the
  /// generation (Ruling 11-8). Every event records [ctx].
  void _attach(ToolContext ctx) {
    _ctx = ctx;
    if (_changes != null && identical(_listened, ctx.document)) return;
    _detach();
    _listened = ctx.document;
    _changes = ctx.document.changes.listen((_) => _onDocumentChange());
    _generation++;
  }

  void _detach() {
    final changes = _changes;
    if (changes != null) unawaited(changes.cancel());
    _changes = null;
    _listened = null;
  }

  /// A document change: nothing memoised before it is read again, and what
  /// the tool shows is re-read at the pointer's last point, so no ring, no
  /// preview and no value outlives the document it was read from.
  void _onDocumentChange() {
    if (_disposed) return;
    _generation++;
    final ctx = _ctx;
    if (ctx == null || !hoverVisible) return;
    _refresh(ctx);
    notifyListeners();
  }

  /// Starts the memo afresh when the generation has moved: the candidates,
  /// the preview's end points, and `T` read once.
  void _syncMemo(ToolContext ctx) {
    if (_memoGeneration == _generation) return;
    _memoGeneration = _generation;
    _memo.clear();
    _endPoints.clear();
    _thickest = thickestWall(ctx.document);
  }

  /// [p]'s attach candidates for the hover (object snap on): one search per
  /// distinct resolved point per generation (exact `==`).
  List<AttachedEnd> _memoised(ToolContext ctx, Vector2 p) {
    _syncMemo(ctx);
    final key = (p.x, p.y);
    final hit = _memo[key];
    if (hit != null) return hit;
    if (_memo.length >= _kMemoCap) _memo.clear();
    debugAttachSearches++;
    return _memo[key] = attachCandidates(ctx.document, ctx.index, p,
        objectSnap: true, thickest: _thickest);
  }

  /// Whether [p] is a placed point, exactly.
  bool _isPlaced(Vector2 p) {
    for (var i = 0; i < points.length; i++) {
      if (points[i].x == p.x && points[i].y == p.y) return true;
    }
    return false;
  }

  /// The rings, and after click 2 the preview and the notice, for the
  /// placed points and the resolved hover point.
  void _refresh(ToolContext ctx) {
    if (_objectSnap(ctx)) {
      final n = points.length;
      _ring0 = n > 0 && _memoised(ctx, points[0]).isNotEmpty;
      _ring1 = n > 1 && _memoised(ctx, points[1]).isNotEmpty;
      _ringHover = hoverVisible &&
          !_isPlaced(hoverPoint) &&
          _memoised(ctx, hoverPoint).isNotEmpty;
    } else {
      _ring0 = _ring1 = _ringHover = false;
    }
    if (points.length == 2) _buildPreview(ctx);
  }

  /// After click 2: the would-be dimension at the resolved hover point,
  /// unless the cached one was built for the same point, Shift and
  /// generation.
  void _buildPreview(ToolContext ctx) {
    final q = hoverPoint;
    if (_keyed &&
        q.x == _keyX &&
        q.y == _keyY &&
        _shift == _keyShift &&
        _generation == _keyGeneration) {
      return;
    }
    _keyed = true;
    _keyX = q.x;
    _keyY = q.y;
    _keyShift = _shift;
    _keyGeneration = _generation;
    debugPreviewBuilds++;
    final p0 = points[0], p1 = points[1];
    final kind = kindFor(q, p0, p1, shift: _shift);
    _previewKind = kind;
    final m = Transform2.identity();
    final w0 = _wouldBe(ctx, p0, p1, kind, m);
    final w1 = _wouldBe(ctx, p1, p0, kind, m);
    final l = w0 == null || w1 == null
        ? null
        : layoutDimension(w0, w1, kind, m, offsetFor(q, p0, p1, kind, m),
            ctx.page?.value ?? _defaultPage);
    if (l == null) {
      _hasPreview = false;
      if (!_disposed) _notice.value = null;
      return;
    }
    var i = 0;
    for (final (a, b) in [(l.q0, l.q1), l.ext0, l.ext1, l.slash0, l.slash1]) {
      _preview
        ..[i++] = a.x
        ..[i++] = a.y
        ..[i++] = b.x
        ..[i++] = b.y;
    }
    _hasPreview = true;
    if (!_disposed) _notice.value = l.text;
  }

  /// The world point the commit would give the end at placed point [at]
  /// (the other at [other]) for [kind]: decision 19's choice among its
  /// memoised candidates, as the commit decides it, and that wall end
  /// point, or [at] itself for a fixed end (the group is the identity).
  /// Null for a wall end point that cannot be laid out.
  Vector2? _wouldBe(
      ToolContext ctx, Vector2 at, Vector2 other, DimKind kind, Transform2 m) {
    final candidates =
        _objectSnap(ctx) ? _memoised(ctx, at) : const <AttachedEnd>[];
    final end = decideEnd(ctx.document, candidates,
        kind: kind, at: at, other: other, m: m);
    if (end == null) return at;
    return _endPoints.putIfAbsent(end, () {
      final ws = wallsInDocument(ctx.document, end.wall);
      return ws == null
          ? null
          : wallEndPoint(ws.host, ws.walls, end.k, end.side);
    });
  }

  /// Every placed point is dropped, and with them the preview, the placed
  /// points' rings and the notice: after the commit, on Esc and on
  /// deactivation.
  @override
  void clearShape() {
    super.clearShape();
    _hasPreview = false;
    _keyed = false;
    _ring0 = _ring1 = false;
    if (!_disposed) _notice.value = null;
  }

  /// Every cancel path (Escape, a switch to another tool, the layer's
  /// deactivate and dispose): the shape, the rings and the notice go, and
  /// the document's changes are no longer heard until the next event.
  @override
  void cancel(ToolContext ctx) {
    _detach();
    _ringHover = false;
    super.cancel(ctx);
  }

  @override
  void dispose() {
    _disposed = true;
    _detach();
    _notice.dispose();
    super.dispose();
  }

  /// Runs after every hover's resolution, a Shift press or release and a
  /// camera change included.
  @override
  void hovered(Vector2 raw) {
    final ctx = _ctx;
    if (ctx != null) _refresh(ctx);
  }

  /// The snap marker, then a ring at each attaching placed or hovered point
  /// (decided on the pointer move; nothing is searched here).
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {
    super.paintOverlay(canvas, camera, viewport);
    final m = camera.worldToScreenMatrix;
    void ring(Vector2 p) => canvas.drawCircle(
        Offset(m.a * p.x + m.c * p.y + m.e, m.b * p.x + m.d * p.y + m.f),
        kAttachRingPixels,
        _ringPaint);
    if (_ring0 && points.isNotEmpty) ring(points[0]);
    if (_ring1 && points.length > 1) ring(points[1]);
    if (_ringHover && hoverVisible) ring(hoverPoint);
  }

  /// After the first click, the rubber band from it to the resolved hover
  /// point, as the Line tool draws it; after the second, the cached
  /// preview's five lines (spec 11 D12's preview, R-24). Painted per frame
  /// from stored numbers; nothing is computed here.
  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (!hoverVisible) return;
    final ox = origin.x, oy = origin.y;
    if (points.length == 1) {
      final p = points.first, h = hoverPoint;
      band
        ..reset()
        ..moveTo(p.x - ox, p.y - oy)
        ..lineTo(h.x - ox, h.y - oy);
      canvas.drawPath(band, bandPaint);
      return;
    }
    if (points.length != 2 || !_hasPreview) return;
    final c = _preview;
    band.reset();
    for (var i = 0; i < 20; i += 4) {
      band
        ..moveTo(c[i] - ox, c[i + 1] - oy)
        ..lineTo(c[i + 2] - ox, c[i + 3] - oy);
    }
    canvas.drawPath(band, bandPaint);
  }
}
