// The symbol placement tool (spec 09b D6, F-5, F-6, F-14): a ghost of the
// armed symbol's real outline follows the pointer, snapping like the drawing
// tools; press, drag, release places the symbol at the release point; one
// undo step per placement; the tool stays armed.
//
// Plan 09b Task 6 (pointer, snap, ghost). Keys and the permission check are
// Task 7's: [SymbolPlaceTool.onKey] ignores every key for now, and every
// placement goes through the one private `_place`, where Task 7 checks the
// permissions before `placeSymbol` allocates a handle (Ruling 05-3).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart'
    show KeyEvent, MouseCursor, SystemMouseCursors;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'symbol_ghost.dart';
import 'symbol_library.dart';
import 'symbol_placer.dart';

/// The half-size of the ghost's base-point cross, in screen pixels.
const double kGhostCrossPixels = 6.0;

/// Spec 09b D6: places the [armed] symbol on release.
///
/// - `armed.value == null` is idle: every pointer event is ignored and the
///   cursor is deferred.
/// - A hover (mouse) moves the ghost; a primary press starts a placement and
///   shows the ghost at the press (touch has no hover, F-6); a move while
///   pressed follows; the release places at the **snapped release point**.
/// - [cancel] (a pointer cancel, a tool switch, the layer leaving) drops the
///   press and hides the ghost. The layer still delivers a cancelled press's
///   moves and up (F-6): a pressed move with no live press is ignored, and an
///   up with no live press places nothing.
/// - It listens to [armed]: a re-arm while active (a second gallery cell)
///   drops the press, looks up the new ghost path and notifies.
class SymbolPlaceTool extends Tool {
  SymbolPlaceTool(this.armed) {
    armed.addListener(_onArmed);
    _syncPath();
  }

  /// The armed symbol; owned by the shell (spec D8), read here.
  final ValueNotifier<SymbolEntry?> armed;

  final DragPoint _at = DragPoint();
  final SnapResult _scratch = SnapResult();
  final GhostMatrix _matrix = GhostMatrix();
  final ui.Paint _ghostPaint = ui.Paint()
    ..color = kPreviewColor
    ..style = ui.PaintingStyle.stroke;
  final ui.Paint _markerPaint = ui.Paint()
    ..color = kSnapMarkerColor
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = kSnapMarkerStrokePixels;

  ui.Path? _path;
  bool _ghostVisible = false;
  bool _pressed = false;
  int _pressPointer = -1;
  // Final until plan Task 7's R, Shift+R and M change them; the ghost and
  // the placement already read them.
  final int _quarterTurns = 0;
  final bool _mirrored = false;

  @override
  String get name => 'Symbol';

  @override
  ToolPhase get phase => _pressed ? ToolPhase.pressed : ToolPhase.idle;

  /// Spec D6, 12a F-2: true while a press is down.
  @override
  bool get isMidShape => _pressed;

  @override
  MouseCursor get cursor =>
      armed.value == null ? MouseCursor.defer : SystemMouseCursors.precise;

  /// Whether the ghost (and its snap marker) is painted.
  bool get ghostVisible => _ghostVisible && armed.value != null;

  /// The resolved (snapped) point the ghost's base point sits on, and a
  /// release would place at. Read only; reused.
  Vector2 get ghostAt => _at.point;

  /// The ghost's cached local path, or null while idle.
  @visibleForTesting
  ui.Path? get ghostPath => _path;

  /// The rotation, in counter-clockwise quarter turns, of the next placement.
  int get quarterTurns => _quarterTurns;

  /// Whether the next placement is mirrored.
  bool get mirrored => _mirrored;

  void _syncPath() {
    final entry = armed.value;
    _path = entry == null ? null : ghostPathFor(entry);
  }

  void _onArmed() {
    _syncPath();
    _pressed = false;
    _pressPointer = -1;
    notifyListeners();
  }

  /// F-5: object snap at `kSnapAperturePixels / scale`, else the grid, else
  /// the raw point. No ortho base: a symbol has no previous point.
  void _resolve(ToolContext ctx, Vector2 raw) {
    final cam = ctx.camera.value;
    final page = ctx.page?.value;
    resolveDragPoint(
      raw: raw,
      orthoBase: null,
      index: ctx.index,
      apertureWorld: kSnapAperturePixels / cam.scale,
      objectSnap: ctx.snap?.objectSnap ?? true,
      page: page,
      gridStepMm: dragGridStepMm(page, cam.scale),
      scratch: _scratch,
      out: _at,
    );
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    if (armed.value == null) return;
    if (e.buttons & kPrimaryButton == 0) return;
    _pressed = true;
    _pressPointer = e.pointer;
    _resolve(ctx, e.world);
    _ghostVisible = true;
    notifyListeners();
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    if (armed.value == null) return;
    final pressedMove = e.buttons & kPrimaryButton != 0;
    // A cancelled press's remaining moves (F-6), or another pointer's.
    if (pressedMove && (!_pressed || e.pointer != _pressPointer)) return;
    _resolve(ctx, e.world);
    _ghostVisible = true;
    notifyListeners();
  }

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {
    if (!_pressed || e.pointer != _pressPointer) return;
    _pressed = false;
    _pressPointer = -1;
    final entry = armed.value;
    if (entry != null) {
      _resolve(ctx, e.world);
      _ghostVisible = true;
      _place(ctx, entry, _at.point);
    }
    notifyListeners();
  }

  @override
  void onPointerExit(ToolContext ctx) {
    if (!_ghostVisible) return;
    _ghostVisible = false;
    notifyListeners();
  }

  /// Keys are plan Task 7's; until then every key bubbles to the shell.
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;

  /// Every cancel path: the press is dropped (its up places nothing) and the
  /// ghost hides; the document is never touched. Idempotent: an idle,
  /// hidden tool returns before notifying.
  @override
  void cancel(ToolContext ctx) {
    if (!_pressed && !_ghostVisible) return;
    _pressed = false;
    _pressPointer = -1;
    _ghostVisible = false;
    notifyListeners();
  }

  /// The one commit path (spec D6): one command, one undo step. The
  /// instance is not selected.
  void _place(ToolContext ctx, SymbolEntry entry, Vector2 at) {
    ctx.execute(placeSymbol(ctx.document, entry,
        at: at, quarterTurns: _quarterTurns, mirrored: _mirrored));
  }

  /// The snap marker, in screen space (`placement_tool.dart`'s pattern).
  @override
  void paintOverlay(
      ui.Canvas canvas, ViewportTransform camera, ui.Size viewport) {
    if (!ghostVisible) return;
    final m = camera.worldToScreenMatrix;
    final p = _at.point;
    drawSnapMarker(
        canvas,
        ui.Offset(m.a * p.x + m.c * p.y + m.e, m.b * p.x + m.d * p.y + m.f),
        _at.objectKind,
        grid: _at.grid,
        paint: _markerPaint);
  }

  /// Spec D6: the cached local path under `translate(−origin) ∘ P`, then a
  /// cross at the local base point. Allocates no path, transform, matrix or
  /// paint: `P` is recomputed only when the placement changes.
  @override
  void paintWorldOverlay(ui.Canvas canvas, Vector2 origin, double scale) {
    final entry = armed.value;
    final path = _path;
    if (!_ghostVisible || entry == null || path == null) return;
    final base = entry.definition.basePoint;
    _matrix.update(
        at: _at.point,
        basePoint: base,
        quarterTurns: _quarterTurns,
        mirrored: _mirrored);
    final Float64List m = _matrix.forOrigin(origin);
    _ghostPaint.strokeWidth = kPreviewStrokePixels / scale;
    final k = kGhostCrossPixels / scale;
    canvas.save();
    canvas.transform(m);
    canvas.drawPath(path, _ghostPaint);
    canvas.drawLine(ui.Offset(base.x - k, base.y),
        ui.Offset(base.x + k, base.y), _ghostPaint);
    canvas.drawLine(ui.Offset(base.x, base.y - k),
        ui.Offset(base.x, base.y + k), _ghostPaint);
    canvas.restore();
  }

  @override
  void dispose() {
    armed.removeListener(_onArmed);
    super.dispose();
  }
}
