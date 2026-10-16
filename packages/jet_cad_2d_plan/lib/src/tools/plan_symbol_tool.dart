// Spec P3 "Attachment" (Task 14): plan.symbol, ported from
// jet_cad_floor_plan's symbol_place_tool.dart (spec 09b D6, F-5, F-6,
// F-12, F-14, F-16; 09c D5, D6, D12). A ghost of the armed symbol's
// outline follows the pointer, snapping like the drawing tools; press,
// drag, release places it at the release point; one undo step per
// placement; the tool stays armed. A symbol whose jetcad.symbol names
// attachment kinds attaches through the registry, while object snap is on.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show ValueListenable, visibleForTesting;
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
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show
        Attachment,
        AttachmentQuery,
        AttachmentRegistry,
        boxOfEntry,
        footprintOf,
        placementTransform;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../attach/attachment_painter.dart';
import '../symbols/plan_symbol.dart';
import '../symbols/symbol_ghost.dart';
import '../symbols/symbol_placer.dart';
import '../units/unit_index.dart' show UnitIndex;
import 'generic_tools.dart' show PlanToolIds;

/// The half-size of the ghost's base-point cross, in screen pixels.
const double kGhostCrossPixels = 6.0;

/// How near, in screen pixels, the raw pointer may be for an attachment
/// (today's kWallAttachPixels, spec 09c D4, D6): larger than the snap
/// aperture, since the pointer is often the symbol's centre.
const double kAttachPixels = 16.0;

/// Places the [armed] symbol on release (spec 09b D6; see the header).
///
/// - Nothing armed is idle: every pointer event is ignored, every key
///   bubbles, the cursor defers.
/// - A hover (mouse) moves the ghost; a primary press starts a placement
///   and shows the ghost at the press (touch has no hover, F-6); a move
///   while pressed follows; the release places at the **snapped release
///   point**. [cancel] drops the press and hides the ghost.
/// - It listens to [armed]: a re-arm drops the press, looks up the new
///   ghost path and notifies; the turns and the mirror are kept.
/// - R, Shift+R and M turn and mirror the next placement while
///   [canRotate] / [canMirror] allow (null allows); a refused turn or
///   mirror is not used (the stored one returns with the flag).
/// - Spec 09c D12: while the ghost is shown it listens to the camera, and
///   a camera change re-resolves the ghost from the last pointer's screen
///   point.
/// - Attachment (spec P3): for a symbol whose component's `attachTo` is not
///   empty, with object snap on and [attachments] given, each recompute
///   asks `attachments.attach(attachTo, query)` with the symbol's
///   footprint, the free placement as `current`, the raw pointer, the
///   captures `kAttachPixels / scale` and `kSnapAperturePixels / scale`,
///   the mirror, `mayRotate` ([canRotate]) and the last answer as `keep`.
///   Attached, the ghost and the release use the answer's transform
///   verbatim and the marker is drawn at its marker; M mirrors in place.
class PlanSymbolTool extends Tool {
  PlanSymbolTool(this.armed,
      {this.attachments, this.canRotate, this.canMirror, this.units}) {
    armed.addListener(_onArmed);
    _syncPath();
  }

  /// The armed symbol; the controller's, read here.
  final ValueListenable<PlanSymbol?> armed;

  /// The document's attachment registry, or null: nothing attaches.
  final AttachmentRegistry? attachments;

  /// Whether `R` and `Shift+R` turn the next placement (the permissions'
  /// `rotate`), read at each use; null allows.
  final bool Function()? canRotate;

  /// Whether `M` mirrors the next placement (the permissions' `mirror`),
  /// read at each use; null allows.
  final bool Function()? canMirror;

  /// The plan's units, read at each placement: a numbered unit takes the
  /// next number (spec 2b S2). Null places no label.
  final UnitIndex Function()? units;

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
  /// camera events, never in a paint (spec 09c D5, W-15).
  Transform2? _placement;

  /// The attachment of the last recompute, or null (free placement).
  Attachment? _attached;

  /// The inputs of the last attachment query, kept so a key (`M`) can ask
  /// again for the same pointer: the raw world point, whether object snap
  /// was on, the camera scale. [_hasRaw] is false until the first
  /// recompute with a context.
  final Vector2 _raw = Vector2.zero();
  bool _rawObjectSnap = true;
  double _rawScale = 1;
  bool _hasRaw = false;

  /// Spec 09c D12: the last pointer event's screen point and context.
  ui.Offset _lastScreen = ui.Offset.zero;
  ToolContext? _context;

  /// The context whose camera this tool listens to; non-null exactly while
  /// [ghostVisible] (after a pointer event brought a context).
  ToolContext? _listening;

  /// What a placement commits (spec D6: the definition copy, its leaves and
  /// its jetcad.symbol).
  static const Set<Capability> needs = PlanToolIds.symbolNeeds;

  @override
  String get name => 'Symbol';

  @override
  ToolPhase get phase => _pressed ? ToolPhase.pressed : ToolPhase.idle;

  /// A down only classifies a press and `cancel` executes nothing, so a
  /// finger reaches this tool after the hold-back (spec 14t R-1).
  @override
  TouchPress get touchPress => TouchPress.press;

  /// True while a press is down.
  @override
  bool get isMidShape => _pressed;

  @override
  MouseCursor get cursor =>
      armed.value == null ? MouseCursor.defer : SystemMouseCursors.precise;

  /// Whether the ghost (and its marker) is painted.
  bool get ghostVisible => _ghostVisible && armed.value != null;

  /// The resolved (snapped) point the ghost's base point sits on while it
  /// places freely. Read only; reused.
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

  /// The attachment the ghost (and a release) uses, or null.
  @visibleForTesting
  Attachment? get ghostAttachment => _attached;

  /// The rotation, in counter-clockwise quarter turns, of the next
  /// placement as stored; a placement uses it only while [canRotate]
  /// allows.
  int get quarterTurns => _quarterTurns;

  /// Whether the next placement is mirrored, as stored; a placement uses it
  /// only while [canMirror] allows.
  bool get mirrored => _mirrored;

  int get _turns => (canRotate?.call() ?? true) ? _quarterTurns : 0;
  bool get _mirror => _mirrored && (canMirror?.call() ?? true);

  /// The permissions may have changed: the ghost and its attachment are
  /// computed again with the turn and the mirror now allowed.
  void gatesChanged() {
    if (armed.value == null) return;
    final ctx = _listening ?? _context;
    if (ctx != null) _syncAttachment(ctx);
    _syncPlacement();
    notifyListeners();
  }

  void _syncPath() {
    final symbol = armed.value;
    _path = symbol == null ? null : ghostPathFor(symbol.entry);
  }

  void _onArmed() {
    _syncPath();
    _syncCamera();
    // The previous symbol's answer is no keep for this one.
    _attached = null;
    final ctx = _listening;
    if (ctx != null) {
      _update(ctx, _worldUnderPointer(ctx));
    } else {
      _syncPlacement();
    }
    _pressed = false;
    _pressPointer = -1;
    notifyListeners();
  }

  /// The free placement: the resolved point, the turns, the mirror.
  Transform2? _free() {
    final symbol = armed.value;
    return symbol == null
        ? null
        : placementTransform(
            at: _at.point,
            basePoint: symbol.entry.definition.basePoint,
            quarterTurns: _turns,
            mirrored: _mirror);
  }

  void _syncPlacement() => _placement = _attached?.transform ?? _free();

  void _syncAttachment(ToolContext ctx) {
    final previous = _attached;
    _attached = null;
    final registry = attachments;
    final symbol = armed.value;
    if (registry == null || symbol == null || !_hasRaw || !_rawObjectSnap) {
      return;
    }
    final kinds = symbol.component.attachTo;
    if (kinds.isEmpty) return;
    final box = boxOfEntry(symbol.entry);
    if (box == null) return;
    _attached = registry.attach(
        kinds,
        AttachmentQuery(
          footprint: footprintOf(box),
          current: _free()!,
          pointer: _raw.clone(),
          capture: kAttachPixels / _rawScale,
          edgeCapture: kSnapAperturePixels / _rawScale,
          mirrored: _mirror,
          mayRotate: canRotate?.call() ?? true,
          exclude: const {},
          keep: previous,
        ));
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

  /// The tool's one recompute path: the raw point resolved, then the
  /// attachment, then the placement.
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
    final symbol = armed.value;
    if (symbol != null) {
      _track(e, ctx);
      _update(ctx, e.world);
      _ghostVisible = true;
      _syncCamera();
      _place(ctx, symbol);
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
        // Spec 09c D6, decision 5: the same pointer asks the registry again
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

  /// The one commit path: one command, one undo step; the permissions are
  /// checked before placeSymbol allocates a handle (Ruling 05-3, F-16). An
  /// attached placement commits the attachment's transform verbatim.
  void _place(ToolContext ctx, PlanSymbol symbol) {
    if (!needs.every(ctx.document.commands.permissions.allows)) return;
    ctx.execute(placeSymbol(ctx.document, symbol.entry,
        at: _at.point,
        quarterTurns: _turns,
        mirrored: _mirror,
        transform: _attached?.transform,
        units: units?.call()));
  }

  /// The snap marker, in screen space; attached, the nearest glyph at the
  /// attachment's marker.
  @override
  void paintOverlay(ui.Canvas canvas, ViewportTransform camera,
      ui.Size viewport, PaperPalette paper) {
    if (!ghostVisible) return;
    _markerPaint.color = paper.snap;
    final attached = _attached;
    if (attached != null) {
      paintAttachmentMarker(canvas, camera, attached.marker, _markerPaint);
      return;
    }
    final m = camera.worldToScreenMatrix;
    final p = _at.point;
    final at =
        ui.Offset(m.a * p.x + m.c * p.y + m.e, m.b * p.x + m.d * p.y + m.f);
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
    final entry = armed.value?.entry;
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
