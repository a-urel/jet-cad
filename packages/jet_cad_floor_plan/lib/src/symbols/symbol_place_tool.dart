// The symbol placement tool (spec 09b D6, F-5, F-6, F-14): a ghost of the
// armed symbol's real outline follows the pointer, snapping like the drawing
// tools; press, drag, release places the symbol at the release point; one
// undo step per placement; the tool stays armed.
//
// Plan 09b Task 6 (pointer, snap, ghost) and Task 7 (keys, F-12; the
// permission check before `placeSymbol` allocates a handle, Ruling 05-3,
// F-16). Plan 09c-1 Task 8 (spec 09c D12): the ghost follows a camera change.
// Plan 09c-1 Task 7 (spec 09c D6): a symbol tagged `against-wall` attaches
// to a wall face near the raw pointer.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart'
    show
        HardwareKeyboard,
        KeyDownEvent,
        KeyEvent,
        KeyUpEvent,
        LogicalKeyboardKey,
        MouseCursor,
        SystemMouseCursors;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'symbol_box.dart';
import 'symbol_ghost.dart';
import 'symbol_library.dart';
import 'symbol_placer.dart';
import 'wall_attach.dart';

/// The half-size of the ghost's base-point cross, in screen pixels.
const double kGhostCrossPixels = 6.0;

/// Spec 09c D4, D6: how near a wall face, in screen pixels, the raw pointer
/// attaches a tagged symbol. Larger than the snap aperture: in placement
/// the pointer is often the symbol's centre, far from its back.
const double kWallAttachPixels = 16.0;

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
///   drops the press, looks up the new ghost path and notifies. The turns
///   and the mirror are kept (Ruling R-B6-2).
/// - Keys ([onKey]): R, Shift+R and M turn and mirror the next placement.
/// - Spec 09c D12: while [ghostVisible] it listens to the camera, and a
///   camera change (a wheel zoom, a pan) re-resolves the ghost from the last
///   pointer's **screen** point, as `PlacementTool` does (F-8). The listener
///   goes when the ghost hides, on [cancel], on a disarm and on [dispose]; a
///   re-arm while the ghost is shown listens again and re-resolves the ghost
///   under the pointer.
/// - Spec 09c D6: given the shell's [faces], an armed entry tagged
///   [againstWallTag] attaches, while object snap is on, to the wall face
///   [WallFaces.attach] finds for the **raw** pointer (capture
///   `kWallAttachPixels / scale`, edge snaps `kSnapAperturePixels /
///   scale`): the ghost and the release use the attached transform and the
///   marker is the nearest glyph at the face point `q`. While attached, `M`
///   mirrors in place and `R` / `Shift+R` change the turn count only (it
///   applies off the face). After its own commit the tool invalidates the
///   bands, so the next placement sees the one just made as a neighbour.
///   Without [faces], nothing attaches: 09b's behaviour.
class SymbolPlaceTool extends Tool {
  SymbolPlaceTool(this.armed, {this.faces, this.canRotate, this.canMirror}) {
    armed.addListener(_onArmed);
    _syncPath();
  }

  /// The armed symbol; owned by the shell (spec D8), read here.
  final ValueNotifier<SymbolEntry?> armed;

  /// The shell's wall faces (spec 09c D3, D6), or null: no attachment.
  final WallFaces? faces;

  /// Whether `R` and `Shift+R` turn the next placement (host embedding API
  /// spec S-9 b, the host's `rotate`), read at each key; null allows. A
  /// refused key is any other key: it bubbles while armed and is swallowed
  /// mid-press.
  final bool Function()? canRotate;

  /// Whether `M` mirrors the next placement (spec S-9 b, the host's
  /// `mirror`), read at each key as [canRotate]; null allows.
  final bool Function()? canMirror;

  final DragPoint _at = DragPoint();
  final SnapResult _scratch = SnapResult();
  final GhostMatrix _matrix = GhostMatrix();
  // Coloured from the overlay's paper set where they are drawn (dark theme
  // spec D5): the ghost `preview`, the marker `snap`.
  final ui.Paint _ghostPaint = ui.Paint()..style = ui.PaintingStyle.stroke;
  final ui.Paint _markerPaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = kSnapMarkerStrokePixels;

  ui.Path? _path;
  bool _ghostVisible = false;
  bool _pressed = false;
  int _pressPointer = -1;
  int _quarterTurns = 0;
  bool _mirrored = false;

  /// The ghost's placement transform, computed on pointer, key, arm and
  /// camera events ([_syncPlacement]), never in a paint (spec 09c D5, W-15).
  Transform2? _placement;

  /// Spec 09c D6: the wall attachment of the last recompute, or null (free
  /// placement). Computed by [_syncAttachment], never in a paint.
  WallAttachment? _attached;

  /// The inputs of the last attachment query, kept so a key (`M`) can ask
  /// again for the same pointer with the new mirror: the raw world point,
  /// whether object snap was on, the camera scale. [_hasRaw] is false until
  /// the first recompute with a context.
  final Vector2 _raw = Vector2.zero();
  bool _rawObjectSnap = true;
  double _rawScale = 1;
  bool _hasRaw = false;

  /// Spec 09c D12: the last pointer event's screen point and context, kept
  /// so a camera change re-resolves the ghost under the resting pointer. The
  /// context is a plain reference: the camera listener is [_listening].
  ui.Offset _lastScreen = ui.Offset.zero;
  ToolContext? _context;

  /// The context whose camera this tool listens to; non-null exactly while
  /// [ghostVisible] (after a pointer event brought a context).
  ToolContext? _listening;

  /// Spec D6 Commit: every capability a placement may need. The first
  /// placement of a symbol copies its definition (structure, geometry) and
  /// its `SymbolComponent` (components).
  static const Set<Capability> needs = {
    Capability.structure,
    Capability.geometry,
    Capability.components,
  };

  @override
  String get name => 'Symbol';

  @override
  ToolPhase get phase => _pressed ? ToolPhase.pressed : ToolPhase.idle;

  /// A down only classifies a press and `cancel` executes nothing, so a
  /// finger reaches this tool after the hold-back (spec 14t R-1).
  @override
  TouchPress get touchPress => TouchPress.press;

  /// Spec D6, 12a F-2: true while a press is down.
  @override
  bool get isMidShape => _pressed;

  @override
  MouseCursor get cursor =>
      armed.value == null ? MouseCursor.defer : SystemMouseCursors.precise;

  /// Whether the ghost (and its snap marker) is painted.
  bool get ghostVisible => _ghostVisible && armed.value != null;

  /// The resolved (snapped) point the ghost's base point sits on, and a
  /// release would place at, while it places freely (attached, spec 09c
  /// D6, [ghostAttachment] places it instead). Read only; reused.
  Vector2 get ghostAt => _at.point;

  /// The ghost's cached local path, or null while idle.
  @visibleForTesting
  ui.Path? get ghostPath => _path;

  /// The ghost's placement transform as last computed on an event, or null
  /// while idle or before the first pointer event.
  @visibleForTesting
  Transform2? get ghostPlacement => _placement;

  /// The ghost's reused matrix.
  @visibleForTesting
  GhostMatrix get ghostMatrix => _matrix;

  /// Spec 09c D6: the wall attachment the ghost (and a release) uses, or
  /// null while it places freely.
  @visibleForTesting
  WallAttachment? get ghostAttachment => _attached;

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
    _syncCamera();
    final ctx = _listening;
    // Re-armed with the ghost still shown (from a disarm or from another
    // entry): the ghost goes under the pointer again through the one
    // recompute path. The camera may have moved while nothing listened, and
    // the snap state or the document may have changed since the last
    // pointer event (Ruling R-C8b-1).
    if (ctx != null) {
      _update(ctx, _worldUnderPointer(ctx));
    } else {
      // Hidden or idle: the previous entry's attachment is not this one's;
      // the next pointer event asks again.
      _attached = null;
      _syncPlacement();
    }
    _pressed = false;
    _pressPointer = -1;
    notifyListeners();
  }

  /// The ghost's placement: the wall attachment's transform when attached
  /// (spec 09c D6), else from the armed entry's base point, the resolved
  /// point, the turns and the mirror. Called on every event that changes
  /// one of them, so a paint only passes the stored value on.
  void _syncPlacement() {
    final entry = armed.value;
    final attached = _attached;
    _placement = entry == null
        ? null
        : attached != null
            ? attached.transform
            : placementTransform(
                at: _at.point,
                basePoint: entry.definition.basePoint,
                quarterTurns: _quarterTurns,
                mirrored: _mirrored);
  }

  /// Spec 09c D6: [_attached] for the last query's raw point, object snap
  /// and scale ([_raw], [_rawObjectSnap], [_rawScale]) and the current
  /// entry and mirror. Null without [faces], before any query, for an
  /// entry not tagged [againstWallTag] or with no box (Ruling R-C2-2), with
  /// object snap off, or when no face takes the point.
  void _syncAttachment(ToolContext ctx) {
    _attached = null;
    final faces = this.faces;
    final entry = armed.value;
    if (faces == null || entry == null || !_hasRaw || !_rawObjectSnap) {
      return;
    }
    if (!entry.tags.contains(againstWallTag)) return;
    final box = boxOfEntry(entry);
    if (box == null) return;
    _attached = faces.attach(
        ctx.document, box, _raw, kWallAttachPixels / _rawScale,
        mirrored: _mirrored, edgeCaptureWorld: kSnapAperturePixels / _rawScale);
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

  /// The tool's one recompute path: every pointer event, every camera
  /// change and a re-arm while the ghost is shown resolve the raw point,
  /// then the wall attachment (spec 09c D6), then the placement through
  /// here.
  void _update(ToolContext ctx, Vector2 raw) {
    _resolve(ctx, raw);
    _raw.setFrom(raw);
    _rawObjectSnap = ctx.snap?.objectSnap ?? true;
    _rawScale = ctx.camera.value.scale;
    _hasRaw = true;
    _syncAttachment(ctx);
    _syncPlacement();
  }

  /// A pointer event's screen point and context, for [_onCamera].
  void _track(ToolPointerEvent e, ToolContext ctx) {
    _lastScreen = e.screen;
    _context = ctx;
  }

  Vector2 _worldUnderPointer(ToolContext ctx) =>
      ctx.camera.value.screenToWorld(Vector2(_lastScreen.dx, _lastScreen.dy));

  /// Spec 09c D12: listens to the camera exactly while [ghostVisible].
  void _syncCamera() {
    final want = ghostVisible ? _context : null;
    if (identical(want, _listening)) return;
    _listening?.camera.removeListener(_onCamera);
    _listening = want;
    want?.camera.addListener(_onCamera);
  }

  void _onCamera() {
    final ctx = _listening;
    if (ctx == null) return;
    _update(ctx, _worldUnderPointer(ctx));
    notifyListeners();
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    if (armed.value == null) return;
    if (e.buttons & kPrimaryButton == 0) return;
    _pressed = true;
    _pressPointer = e.pointer;
    _track(e, ctx);
    _update(ctx, e.world);
    _ghostVisible = true;
    _syncCamera();
    notifyListeners();
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    if (armed.value == null) return;
    final pressedMove = e.buttons & kPrimaryButton != 0;
    // A cancelled press's remaining moves (F-6), or another pointer's.
    if (pressedMove && (!_pressed || e.pointer != _pressPointer)) return;
    _track(e, ctx);
    _update(ctx, e.world);
    _ghostVisible = true;
    _syncCamera();
    notifyListeners();
  }

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {
    if (!_pressed || e.pointer != _pressPointer) return;
    _pressed = false;
    _pressPointer = -1;
    final entry = armed.value;
    if (entry != null) {
      _track(e, ctx);
      _update(ctx, e.world);
      _ghostVisible = true;
      _syncCamera();
      _place(ctx, entry);
    }
    notifyListeners();
  }

  @override
  void onPointerExit(ToolContext ctx) {
    if (!_ghostVisible) return;
    _ghostVisible = false;
    _syncCamera();
    notifyListeners();
  }

  /// Spec D6 Keys, F-12. Idle (nothing armed) every key bubbles.
  ///
  /// - `R` turns the next placement one quarter turn counter-clockwise,
  ///   `Shift+R` clockwise, `M` toggles the mirror; only with no Ctrl, Meta
  ///   or Alt held (Cmd/Ctrl+R is a browser reload, Ctrl+M passes through).
  ///   One step per key-down; a repeat is consumed with no effect. They work
  ///   armed idle and mid-press; the ghost repaints.
  /// - Mid-press: `Esc` cancels the press (its remaining moves and its up
  ///   place nothing, Ruling R-B6-1); F and F3 with no modifier bubble (the
  ///   drawing tools' rule, `placement_tool.dart`); every other key-down and
  ///   repeat is swallowed, so undo never lands mid-placement.
  /// - Armed, not pressed: every key but R and M bubbles (the shell's
  ///   letters, undo and `Esc` work).
  /// - A key-up always bubbles.
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    if (armed.value == null || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final modifier = _hasModifier();
    if (!modifier &&
        ((key == LogicalKeyboardKey.keyR && (canRotate?.call() ?? true)) ||
            (key == LogicalKeyboardKey.keyM && (canMirror?.call() ?? true)))) {
      if (event is KeyDownEvent) {
        if (key == LogicalKeyboardKey.keyR) {
          final step = HardwareKeyboard.instance.isShiftPressed ? -1 : 1;
          _quarterTurns = (_quarterTurns + step) % 4;
        } else {
          _mirrored = !_mirrored;
        }
        // Spec 09c D6, decision 5: the same pointer asks the faces again
        // with the new mirror (an attached `M` mirrors in place); the
        // attached transform ignores the turns, which apply off the face.
        _syncAttachment(ctx);
        _syncPlacement();
        notifyListeners();
      }
      return KeyEventResult.handled;
    }
    if (!_pressed) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.escape) {
        cancel(ctx);
        return KeyEventResult.handled;
      }
      if ((key == LogicalKeyboardKey.f3 || key == LogicalKeyboardKey.keyF) &&
          !modifier) {
        return KeyEventResult.ignored;
      }
    }
    return KeyEventResult.handled;
  }

  static bool _hasModifier() {
    final hw = HardwareKeyboard.instance;
    return hw.isControlPressed || hw.isMetaPressed || hw.isAltPressed;
  }

  /// Every cancel path: the press is dropped (its up places nothing) and the
  /// ghost hides; the document is never touched. Idempotent: an idle,
  /// hidden tool returns before notifying.
  @override
  void cancel(ToolContext ctx) {
    if (!_pressed && !_ghostVisible) return;
    _pressed = false;
    _pressPointer = -1;
    _ghostVisible = false;
    _syncCamera();
    notifyListeners();
  }

  /// The one commit path (spec D6): one command, one undo step. The
  /// instance is not selected. The permissions are checked **before**
  /// `placeSymbol` allocates a handle (Ruling 05-3): a refused placement
  /// allocates nothing and throws nothing (F-16: the dispatcher alone would
  /// throw after the allocation).
  ///
  /// Spec 09c D6: an attached placement commits the attached transform
  /// verbatim; then the bands are invalidated (W-5), so the next placement's
  /// faces see this one as a neighbour before the change stream delivers.
  void _place(ToolContext ctx, SymbolEntry entry) {
    if (!needs.every(ctx.document.commands.permissions.allows)) return;
    ctx.execute(placeSymbol(ctx.document, entry,
        at: _at.point,
        quarterTurns: _quarterTurns,
        mirrored: _mirrored,
        transform: _attached?.transform));
    faces?.bands.invalidate();
  }

  /// The snap marker, in screen space (`placement_tool.dart`'s pattern).
  /// Attached (spec 09c D6), the nearest glyph at the face point `q`.
  @override
  void paintOverlay(ui.Canvas canvas, ViewportTransform camera,
      ui.Size viewport, PaperPalette paper) {
    if (!ghostVisible) return;
    _markerPaint.color = paper.snap;
    final m = camera.worldToScreenMatrix;
    final attached = _attached;
    final p = attached?.q ?? _at.point;
    final at =
        ui.Offset(m.a * p.x + m.c * p.y + m.e, m.b * p.x + m.d * p.y + m.f);
    if (attached != null) {
      drawSnapMarker(canvas, at, SnapKind.nearest,
          grid: false, paint: _markerPaint);
      return;
    }
    drawSnapMarker(canvas, at, _at.objectKind,
        grid: _at.grid, paint: _markerPaint);
  }

  /// Spec D6: the cached local path under `translate(−origin) ∘ P`, then a
  /// cross at the local base point. Allocates no path, transform, matrix or
  /// paint: `P` is the transform stored on the last event (09c D5, W-15),
  /// and the matrix rewrites its linear part only when `P` changed.
  @override
  void paintWorldOverlay(
      ui.Canvas canvas, Vector2 origin, double scale, PaperPalette paper) {
    final entry = armed.value;
    final path = _path;
    final placement = _placement;
    if (!_ghostVisible || entry == null || path == null || placement == null) {
      return;
    }
    final base = entry.definition.basePoint;
    _matrix.update(placement: placement);
    final Float64List m = _matrix.forOrigin(origin);
    _ghostPaint.color = paper.preview;
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
    _listening?.camera.removeListener(_onCamera);
    _listening = null;
    _context = null;
    super.dispose();
  }
}
