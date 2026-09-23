import 'dart:ui' show Canvas, Offset, Paint, PaintingStyle, Path, Size;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart'
    show
        HardwareKeyboard,
        KeyDownEvent,
        KeyEvent,
        KeyRepeatEvent,
        KeyUpEvent,
        LogicalKeyboardKey,
        MouseCursor,
        SystemMouseCursors;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../selection_style.dart';
import '../snap_marker.dart';
import '../tool.dart';
import '../viewport_transform.dart';

/// Spec 05 D3: what every drawing tool shares.
/// - Points resolve through the tool's own placed points first, then 03's
///   `resolveDragPoint` (D4).
/// - The hover marker, and a camera listener while a shape is pending.
/// - Escape, Enter and shift; every other key-down is swallowed mid-shape.
/// - One command per finished shape, checked against the permissions
///   before its handle is allocated (Ruling 05-3).
///
/// Placement is click by click: only a primary press places a point, and a
/// move with the button held is a hover (Ruling 05-13).
abstract class PlacementTool extends Tool {
  PlacementTool({this.fill});

  /// Spec 05 D13: the shell's Fill toggle. Null, or false: outlines only.
  final ValueListenable<bool>? fill;

  /// The placed points, as exact world values (invariant 1).
  final List<Vector2> points = <Vector2>[];

  /// True only while [accept] runs on a self-snap's stored point (Ruling
  /// 05-4).
  bool acceptingSelf = false;

  /// Spec 05 D12: reset each frame, never reallocated.
  final Path band = Path();
  final Paint bandPaint = Paint()
    ..color = kPreviewColor
    ..style = PaintingStyle.stroke;

  final DragPoint _hover = DragPoint();
  final SnapResult _scratch = SnapResult();
  final Paint _markerPaint = Paint()
    ..color = kSnapMarkerColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = kSnapMarkerStrokePixels;
  bool _hoverVisible = false;
  Offset _lastScreen = Offset.zero;
  bool _lastShift = false;
  ToolContext? _listening;

  @override
  ToolPhase get phase => ToolPhase.idle;

  @override
  MouseCursor get cursor => SystemMouseCursors.precise;

  bool get isPending => points.isNotEmpty;
  Vector2 get hoverPoint => _hover.point;
  bool get hoverVisible => _hoverVisible;
  SnapKind? get hoverKind => _hover.objectKind;

  /// Spec 05 D4: the last placed point, or none.
  Vector2? get orthoBase => points.isEmpty ? null : points.last;

  /// A stored placed point this raw point should land on exactly, or null.
  Vector2? selfSnap(Vector2 raw, double apertureWorld) => null;

  void accept(Vector2 point, ToolContext ctx);

  /// Enter while a shape is pending.
  void finish(ToolContext ctx) {}

  /// Every hover's raw world point (the arc tracks it).
  void hovered(Vector2 raw) {}

  void clearShape() => points.clear();

  /// Coordinates handed to [canvas] are `world − origin` (Ruling 03-3).
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale);

  /// Spec 05 D4, in exactly this order: the self-snap wins outright, even
  /// over a nearer entity endpoint; otherwise 03's chain, unchanged.
  /// Returns the self-snap's stored point when one won.
  Vector2? _resolve(ToolContext ctx, Vector2 raw, bool shift) {
    final cam = ctx.camera.value;
    final aperture = kSnapAperturePixels / cam.scale;
    final self = selfSnap(raw, aperture);
    if (self != null) {
      _hover.point.setFrom(self);
      _hover.objectKind = SnapKind.endpoint; // Ruling 05-2
      _hover.grid = false;
      return self;
    }
    final page = ctx.page?.value;
    resolveDragPoint(
      raw: raw,
      orthoBase: shift ? orthoBase : null,
      index: ctx.index,
      apertureWorld: aperture,
      objectSnap: ctx.snap?.objectSnap ?? true,
      page: page,
      gridStepMm: dragGridStepMm(page, cam.scale),
      scratch: _scratch,
      out: _hover,
    );
    return null;
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    _lastScreen = e.screen;
    _lastShift = e.shift;
    _resolve(ctx, e.world, e.shift);
    _hoverVisible = true;
    hovered(e.world);
    notifyListeners();
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    if (e.buttons & kPrimaryButton == 0) return;
    _lastScreen = e.screen;
    _lastShift = e.shift;
    // Spec 05 D4: `e.world`, the layer's inverse camera at this event;
    // never `e.screen` (M-05a).
    final self = _resolve(ctx, e.world, e.shift);
    _hoverVisible = true;
    acceptingSelf = self != null;
    try {
      accept(self ?? Vector2.copy(_hover.point), ctx);
    } finally {
      acceptingSelf = false;
    }
    _syncCamera(ctx);
    notifyListeners();
  }

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}

  /// The shape stays: placement is click by click, not a drag.
  @override
  void onPointerExit(ToolContext ctx) {
    _hoverVisible = false;
    notifyListeners();
  }

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    final key = event.logicalKey;
    if ((key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight) &&
        event is! KeyRepeatEvent) {
      _lastShift = event is KeyDownEvent;
      if (_hoverVisible) _reresolve(ctx);
    }
    if (event is KeyUpEvent || !isPending) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.escape) {
        cancel(ctx);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        finish(ctx);
        _syncCamera(ctx);
        notifyListeners();
        return KeyEventResult.handled;
      }
      // Ruling F-2 (spec 05 D3, amended at execution): F3 (object snap) and
      // F (Fill), with no modifier held, bubble to the shell even mid-shape.
      // Neither ever touches the document, so the reason D3 swallows every
      // other key-down -- keeping undo and redo off a half-placed shape --
      // does not apply to them, and F3 is otherwise unreachable while a
      // polyline is pending.
      if ((key == LogicalKeyboardKey.f3 || key == LogicalKeyboardKey.keyF) &&
          !_hasModifier()) {
        return KeyEventResult.ignored;
      }
    }
    // Every other key-down and repeat mid-shape: undo and redo never land
    // on a half-placed shape (spec 05 D3, as 03 D5 during a drag).
    return KeyEventResult.handled;
  }

  static bool _hasModifier() {
    final hw = HardwareKeyboard.instance;
    return hw.isControlPressed || hw.isMetaPressed || hw.isAltPressed;
  }

  /// Every cancel path (Escape, `ToolController.activate`, the layer's
  /// deactivate and dispose) drops the pending shape and never touches the
  /// document (invariant 3).
  @override
  void cancel(ToolContext ctx) {
    clearShape();
    // Ruling F-3: a tool that returns after a switch away paints no stale
    // snap marker; the next pointer move resolves a fresh one.
    _hoverVisible = false;
    _syncCamera(ctx);
    notifyListeners();
  }

  /// Ruling 05-3: the permission check runs before [build], so a denied
  /// shape allocates no handle. [needs] is every capability the built
  /// command will need (spec 06 D13, Ruling 06-10); 05's shapes need
  /// geometry alone. Returns whether the command ran.
  bool commit(ToolContext ctx, DraftCommand Function() build,
      {Set<Capability> needs = const {Capability.geometry}}) {
    final permissions = ctx.document.commands.permissions;
    if (!needs.every(permissions.allows)) return false;
    ctx.execute(build());
    return true;
  }

  /// Spec 05 D13: with Fill on and a [fillable] shape, one region when the
  /// boundary can fill, and the plain boundary when it cannot.
  bool commitShape(ToolContext ctx, EntityKind kind, GeometryPayload payload,
          {bool fillable = false}) =>
      commit(ctx, () {
        if (fillable && (fill?.value ?? false)) {
          final region = addDraftedRegion(ctx.document, kind, payload);
          if (region != null) return region;
        }
        return addDrafted(ctx.document, kind, payload);
      });

  void _reresolve(ToolContext ctx) {
    final world =
        ctx.camera.value.screenToWorld(Vector2(_lastScreen.dx, _lastScreen.dy));
    _resolve(ctx, world, _lastShift);
    hovered(world);
    notifyListeners();
  }

  void _syncCamera(ToolContext ctx) {
    if (isPending && _listening == null) {
      _listening = ctx;
      ctx.camera.addListener(_onCamera);
    } else if (!isPending && _listening != null) {
      _listening!.camera.removeListener(_onCamera);
      _listening = null;
    }
  }

  void _onCamera() {
    final ctx = _listening;
    if (ctx != null) _reresolve(ctx);
  }

  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {
    if (!_hoverVisible) return;
    final m = camera.worldToScreenMatrix;
    final p = _hover.point;
    drawSnapMarker(
        canvas,
        Offset(m.a * p.x + m.c * p.y + m.e, m.b * p.x + m.d * p.y + m.f),
        _hover.objectKind,
        grid: _hover.grid,
        paint: _markerPaint);
  }

  @override
  void paintWorldOverlay(Canvas canvas, Vector2 origin, double scale) {
    bandPaint.strokeWidth = kPreviewStrokePixels / scale;
    paintRubberBand(canvas, origin, scale);
  }

  @override
  void dispose() {
    _listening?.camera.removeListener(_onCamera);
    _listening = null;
    super.dispose();
  }
}
