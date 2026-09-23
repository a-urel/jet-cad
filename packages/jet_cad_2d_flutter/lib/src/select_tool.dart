import 'dart:math' as math;
import 'dart:ui' show Canvas, Offset, Paint, Path, PaintingStyle, Rect, Size;

import 'package:flutter/services.dart'
    show
        KeyDownEvent,
        KeyEvent,
        KeyRepeatEvent,
        LogicalKeyboardKey,
        MouseCursor,
        SystemMouseCursors;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'grip_drag.dart';
import 'selection.dart';
import 'selection_style.dart';
import 'tool.dart';
import 'viewport_transform.dart';

/// A press that moves less than this many screen pixels stays a click
/// (M-02f); past it, a press becomes the drag its class names (spec 03 D2).
const double kBandSlopPixels = 4.0;

/// What a press landed on (spec 03 D2). The first class that hits wins.
enum PressClass { rotationGrip, grip, selectedBody, unselectedBody, empty }

/// Hover, click, shift-click and rubber-band selection (spec 02 D1, D2, D7,
/// D8), Escape and Delete/Backspace (02 D3, D10) — and, since 03, grips:
/// - press classes;
/// - move, rotate and reshape drags with object and grid snap;
/// - one command on release (spec 03 D2, D4, D5).
class SelectTool extends Tool {
  SelectTool();

  @override
  String get name => 'Select';
  ToolPhase _phase = ToolPhase.idle;
  @override
  ToolPhase get phase => _phase;

  final HitPath _hit = HitPath();
  Offset _start = Offset.zero;
  final Vector2 _pressWorld = Vector2.zero();
  bool _pressShift = false;
  PressClass _class = PressClass.empty;
  SelectionKey? _downKey;
  int _pressGrip = -1;

  /// Set when a drag was refused at the slop (Ruling 03-6): the press stays
  /// a click, and later moves do nothing.
  bool _clickOnly = false;
  Offset _end = Offset.zero;
  BandMode? _bandMode;
  int _pointer = -1;

  DragKind? _dragKind;
  GripDrag? _drag;
  ToolContext? _dragCtx;
  Offset _lastScreen = Offset.zero;
  bool _lastShift = false;
  final DragPoint _dragPoint = DragPoint();
  final SnapResult _snapScratch = SnapResult();
  MouseCursor _cursor = MouseCursor.defer;

  /// What the press landed on; null while idle.
  PressClass? get pressClass => _phase == ToolPhase.idle ? null : _class;

  /// The live drag's kind; null unless dragging.
  DragKind? get dragKind => _phase == ToolPhase.dragging ? _dragKind : null;

  /// Non-null only while a band drag is in progress, for the overlay.
  BandMode? get bandMode => dragKind == DragKind.band ? _bandMode : null;

  /// The band rectangle in screen space, for the overlay test.
  Rect? get bandScreen =>
      dragKind == DragKind.band ? Rect.fromPoints(_start, _end) : null;

  /// The band's drag-start corner, for the overlay.
  Offset? get bandStart => dragKind == DragKind.band ? _start : null;

  @override
  MouseCursor get cursor => _cursor;

  @override
  Transform2? get selectionPreviewTransform {
    final kind = dragKind;
    return kind == DragKind.move || kind == DragKind.rotate
        ? _drag?.transform
        : null;
  }

  SelectionKey? _pick(ToolPointerEvent e, ToolContext ctx) {
    if (!ctx.index.pickInto(
        e.world, e.pickRadiusWorld, const QueryFilter.picking(), _hit)) {
      return null;
    }
    return resolveHit(_hit, ctx.document);
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    if (_phase != ToolPhase.idle) return;
    _phase = ToolPhase.pressed;
    _pointer = e.pointer;
    _start = e.screen;
    _pressWorld.setFrom(e.world);
    _pressShift = e.shift;
    _class = _classify(e, ctx);
    notifyListeners();
  }

  /// Spec D2: the rotation grip, then a grip, then the single pick
  /// (selected or not), then empty space.
  PressClass _classify(ToolPointerEvent e, ToolContext ctx) {
    _downKey = null;
    _pressGrip = -1;
    final grips = ctx.grips;
    if (grips != null) {
      final m = ctx.camera.value.worldToScreenMatrix;
      if (grips.hitsRotationGrip(e.screen, m)) return PressClass.rotationGrip;
      final i = grips.hitTest(e.screen, m);
      if (i >= 0) {
        _pressGrip = i;
        return PressClass.grip;
      }
    }
    final key = _pick(e, ctx);
    _downKey = key;
    if (key == null) return PressClass.empty;
    // The single pick decides: an unselected object drawn above a selected
    // one wins the press, exactly as it wins a click in 02.
    return ctx.selection.contains(key)
        ? PressClass.selectedBody
        : PressClass.unselectedBody;
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    switch (_phase) {
      case ToolPhase.idle:
        if (e.buttons != 0) return;
        _hoverAt(e, ctx);
      case ToolPhase.pressed:
        if (e.pointer != _pointer || _clickOnly) return;
        if ((e.screen - _start).distance < kBandSlopPixels) return;
        _beginDrag(e, ctx);
      case ToolPhase.dragging:
        if (e.pointer != _pointer) return;
        if (_dragKind == DragKind.band) {
          _end = e.screen;
          _bandMode =
              _end.dx >= _start.dx ? BandMode.window : BandMode.crossing;
        } else {
          _follow(e, ctx);
        }
        notifyListeners();
    }
  }

  /// 02's object hover, plus the hot grip and the cursor (spec 03 D5).
  /// Notifies only when the cursor or the hot grip changed.
  void _hoverAt(ToolPointerEvent e, ToolContext ctx) {
    final key = _pick(e, ctx);
    ctx.selection.setHover(key);
    var cursor = MouseCursor.defer;
    var hot = -1;
    final grips = ctx.grips;
    if (grips != null) {
      final m = ctx.camera.value.worldToScreenMatrix;
      if (grips.hitsRotationGrip(e.screen, m)) {
        cursor = SystemMouseCursors.grab;
      } else {
        hot = grips.hitTest(e.screen, m);
        if (hot >= 0) cursor = SystemMouseCursors.precise;
      }
    }
    if (cursor == MouseCursor.defer &&
        key != null &&
        ctx.selection.contains(key)) {
      cursor = SystemMouseCursors.move;
    }
    final hotChanged = grips != null && grips.hot != hot;
    if (grips != null) grips.hot = hot;
    if (cursor == _cursor && !hotChanged) return;
    _cursor = cursor;
    notifyListeners();
  }

  /// Spec D2, past the slop. A drag whose capability is refused never
  /// starts; the press stays a click (Ruling 03-6).
  void _beginDrag(ToolPointerEvent e, ToolContext ctx) {
    switch (_class) {
      case PressClass.empty:
        _phase = ToolPhase.dragging;
        _dragKind = DragKind.band;
        ctx.selection.setHover(null);
        _end = e.screen;
        _bandMode = _end.dx >= _start.dx ? BandMode.window : BandMode.crossing;
        notifyListeners();
      case PressClass.selectedBody:
        final drag = GripDrag.move(ctx.document, ctx.selection.keys);
        if (!_permitted(drag, ctx)) {
          _clickOnly = true;
          return;
        }
        _moveBase(ctx, drag!);
        _enter(drag, e, ctx);
      case PressClass.unselectedBody:
        final key = _downKey!;
        final next = _pressShift
            ? <SelectionKey>{...ctx.selection.keys, key}
            : <SelectionKey>{key};
        final drag = GripDrag.move(ctx.document, next);
        if (!_permitted(drag, ctx)) {
          _clickOnly = true;
          return;
        }
        // Class 3b: select (shift at the press toggles in), then move. The
        // selection change is selection state; it stands after a cancel.
        _pressShift
            ? ctx.selection.toggle([key])
            : ctx.selection.replace([key]);
        _moveBase(ctx, drag!);
        _enter(drag, e, ctx);
      case PressClass.grip:
        final grips = ctx.grips!;
        final ref = grips.grips[_pressGrip];
        // Ruling 03-9: a centre grip moves the whole selection.
        final drag = ref.grip.role == GripRole.move
            ? GripDrag.move(ctx.document, ctx.selection.keys)
            : GripDrag.reshape(ctx.document, ref.key, ref.grip);
        if (!_permitted(drag, ctx)) {
          _clickOnly = true;
          return;
        }
        // Spec D8: a grip's base is the grip's own world point, exactly.
        drag!.base.setValues(ref.grip.x, ref.grip.y);
        grips.hot = _pressGrip;
        _enter(drag, e, ctx);
      case PressClass.rotationGrip:
        final box = ctx.grips!.box!;
        final pivot =
            Vector2((box.minX + box.maxX) / 2, (box.minY + box.maxY) / 2);
        final drag = GripDrag.rotate(
            ctx.document, ctx.selection.keys, pivot, _pressWorld);
        if (!_permitted(drag, ctx)) {
          _clickOnly = true;
          return;
        }
        _enter(drag!, e, ctx);
    }
  }

  /// Spec D2: a drag needs its capability before it starts.
  static bool _permitted(GripDrag? drag, ToolContext ctx) =>
      drag != null && drag.permittedBy(ctx.document.commands.permissions);

  /// Spec D8: a body drag's base is the press point, resolved by the same
  /// chain as the target but without ortho. With grid snap on, a move from
  /// on-grid geometry is then a lattice vector (M-03s).
  void _moveBase(ToolContext ctx, GripDrag drag) {
    _resolve(ctx, _pressWorld, null);
    drag.base.setFrom(_dragPoint.point);
  }

  void _enter(GripDrag drag, ToolPointerEvent e, ToolContext ctx) {
    _drag = drag;
    _dragKind = drag.kind;
    _dragCtx = ctx;
    _phase = ToolPhase.dragging;
    ctx.selection.setHover(null);
    // Ruling 03-7: a trackpad zoom or a middle-button pan moves the camera
    // with no pointer event; the target follows from the last screen point.
    ctx.camera.addListener(_onCamera);
    _cursor = switch (drag.kind) {
      DragKind.move => SystemMouseCursors.move,
      DragKind.rotate => SystemMouseCursors.grabbing,
      DragKind.reshape || DragKind.band => SystemMouseCursors.precise,
    };
    _follow(e, ctx);
    notifyListeners();
  }

  /// Spec D5: world from screen, every event — `e.world` is the layer's
  /// inverse camera at this event, never a scaled screen delta.
  void _follow(ToolPointerEvent e, ToolContext ctx) {
    _lastScreen = e.screen;
    _lastShift = e.shift;
    _retarget(ctx, e.world, e.shift);
  }

  void _retarget(ToolContext ctx, Vector2 world, bool shift) {
    final drag = _drag!;
    if (drag.kind == DragKind.rotate) {
      // Spec D8: a rotate snaps to nothing; shift steps it by 15°.
      drag.rotateTo(world, step: shift);
      return;
    }
    _resolve(ctx, world, shift ? drag.base : null);
    drag.moveTo(_dragPoint.point);
  }

  void _resolve(ToolContext ctx, Vector2 raw, Vector2? orthoBase) {
    final cam = ctx.camera.value;
    final page = ctx.page?.value;
    resolveDragPoint(
      raw: raw,
      orthoBase: orthoBase,
      index: ctx.index,
      apertureWorld: kSnapAperturePixels / cam.scale,
      objectSnap: ctx.snap?.objectSnap ?? true,
      page: page,
      gridStepMm: dragGridStepMm(page, cam.scale),
      scratch: _snapScratch,
      out: _dragPoint,
    );
  }

  void _onCamera() {
    final ctx = _dragCtx;
    if (ctx == null || _drag == null) return;
    final world =
        ctx.camera.value.screenToWorld(Vector2(_lastScreen.dx, _lastScreen.dy));
    _retarget(ctx, world, _lastShift);
    notifyListeners();
  }

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {
    if (e.pointer != _pointer) return;
    switch (_phase) {
      case ToolPhase.idle:
        return;
      case ToolPhase.pressed:
        // A press that never left the slop is a click. On a grip or on the
        // rotation grip it does nothing (spec 03 D2, D12).
        switch (_class) {
          case PressClass.selectedBody:
          case PressClass.unselectedBody:
            final key = _downKey!;
            e.shift
                ? ctx.selection.toggle([key])
                : ctx.selection.replace([key]);
          case PressClass.empty:
            if (!e.shift) ctx.selection.clear();
          case PressClass.grip:
          case PressClass.rotationGrip:
            break;
        }
      case ToolPhase.dragging:
        if (_dragKind == DragKind.band) {
          final keys = _bandKeys(ctx, e);
          e.shift ? ctx.selection.toggle(keys) : ctx.selection.replace(keys);
        } else {
          // Ruling 03-13: the up carries the final position.
          _follow(e, ctx);
          final command = _drag!.command(ctx.document.commands.permissions);
          _endDrag(ctx);
          _reset();
          notifyListeners();
          // Spec D4: one command or none — never one per move
          // (invariant 1).
          if (command != null) ctx.execute(command);
          return;
        }
    }
    _reset();
    notifyListeners();
  }

  /// Every root-level key the band selects: root entities, groups (spec D8,
  /// Ruling 02-2 — decided here from the passing-slot set, once per band)
  /// and instances.
  ///
  /// **Both corners are converted here, at release** (spec D8): the camera
  /// may have moved between the press and the up — a trackpad zoom during a
  /// band drag — and the band the user is looking at is the one their two
  /// *screen* corners name under the camera they are looking through now.
  List<SelectionKey> _bandKeys(ToolContext ctx, ToolPointerEvent e) {
    final mode = _bandMode!;
    final a = ctx.camera.value.screenToWorld(Vector2(_start.dx, _start.dy));
    final b = e.world;
    final band = Aabb2.raw(math.min(a.x, b.x), math.min(a.y, b.y),
        math.max(a.x, b.x), math.max(a.y, b.y));
    final passing = <int>{};
    ctx.index.forEachLeafInBand(
        band, mode, const QueryFilter.picking(), passing.add);
    final keys = <SelectionKey>[];
    final seenGroups = <Handle>{};
    final doc = ctx.document;
    Map<Handle, List<int>>? byOwner;
    FilterEvaluator? evaluator;
    for (final slot in passing) {
      final owner = doc.entities.ownerAt(slot);
      if (owner == doc.rootHandle) {
        keys.add(SelectionKey.root(doc.entities.handleAt(slot)));
        continue;
      }
      final top = _topmostGroup(doc, owner);
      if (top == null || !seenGroups.add(top)) continue;
      byOwner ??= doc.leavesByOwner();
      evaluator ??= FilterEvaluator(doc);
      if (mode == BandMode.crossing ||
          _everyLeafIn(doc, top, byOwner, passing, evaluator)) {
        keys.add(SelectionKey.root(top));
      }
    }
    ctx.index.forEachInstanceInBand(band, mode, const QueryFilter.picking(),
        (h) => keys.add(SelectionKey.root(h)));
    return keys;
  }

  /// Ledger Ruling P-1: every leaf owned by [group] or a group nested in it
  /// is in [passing], and there is at least one. A child *instance*'s leaves
  /// do not enter this rule — the stack only ever pushes nested groups.
  ///
  /// A leaf the picking filter rejects — hidden, or on a locked layer — is
  /// **skipped**, not failed on: `leavesByOwner()` is unfiltered while
  /// [passing] only ever holds accepted slots, so counting such a leaf as a
  /// member would make a group with one locked leaf unselectable by any
  /// window band. This matches the engine's own `_bandDescend`, which applies
  /// `acceptsEntity` before it counts a member. A group whose leaves are all
  /// rejected has no members at all and is not selected.
  bool _everyLeafIn(DraftDocument doc, Handle group,
      Map<Handle, List<int>> byOwner, Set<int> passing, FilterEvaluator f) {
    var any = false;
    final stack = <Handle>[group];
    while (stack.isNotEmpty) {
      final g = stack.removeLast();
      for (final slot in byOwner[g] ?? const <int>[]) {
        if (doc.entities.kindAt(slot) == EntityKind.fill) continue;
        if (!f.acceptsEntity(slot, const QueryFilter.picking())) continue;
        any = true;
        if (!passing.contains(slot)) return false;
      }
      final node = doc.tree[g];
      if (node is GroupNode) {
        for (final child in doc.tree.childNodesOf(node.children)) {
          if (doc.tree[child] is GroupNode) stack.add(child);
        }
      }
    }
    return any;
  }

  static Handle? _topmostGroup(DraftDocument doc, Handle owner) {
    final List<Handle> ancestors;
    try {
      ancestors = doc.tree.ancestorsOf(owner);
    } on NodeCycleError {
      return null;
    }
    return topmostGroupOf(doc, owner, ancestors); // selection.dart
  }

  void _reset() {
    _phase = ToolPhase.idle;
    _pointer = -1;
    _class = PressClass.empty;
    _downKey = null;
    _pressGrip = -1;
    _clickOnly = false;
    _bandMode = null;
    _dragKind = null;
  }

  /// The single way out of a move, rotate or reshape (Ruling 03-7).
  void _endDrag(ToolContext ctx) {
    if (_drag == null) return;
    (_dragCtx ?? ctx).camera.removeListener(_onCamera);
    ctx.grips?.hot = -1;
    _drag = null;
    _dragCtx = null;
    _dragPoint.reset();
    _cursor = MouseCursor.defer;
  }

  @override
  void onPointerExit(ToolContext ctx) {
    ctx.selection.setHover(null);
    if (_phase == ToolPhase.dragging) cancel(ctx);
  }

  /// Every cancel path — Escape, pointer cancel, `ToolController.activate`,
  /// the layer's deactivate/dispose — leaves the document byte-identical
  /// (spec D5, invariant 2). A selection change made at drag start stands.
  @override
  void cancel(ToolContext ctx) {
    if (_phase == ToolPhase.idle) return;
    _endDrag(ctx);
    _reset();
    notifyListeners();
  }

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    if (_phase == ToolPhase.dragging &&
        (event is KeyDownEvent || event is KeyRepeatEvent)) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        cancel(ctx);
      }
      // Spec D5 and Ruling 03-8: every key-down and repeat is the drag's,
      // so the shell's cmd+Z never lands mid-drag.
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_phase == ToolPhase.idle) ctx.selection.clear();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      if (_phase != ToolPhase.idle) return KeyEventResult.ignored;
      _deleteSelection(ctx);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Per selected key, in ascending `target` order: builds the object's full
  /// command list, checks every command against [DraftPermissions] before
  /// executing any of them, and only removes the selection entry once the
  /// whole list has run. A refused object is skipped whole — it stays
  /// selected and untouched — never partially deleted.
  void _deleteSelection(ToolContext ctx) {
    final doc = ctx.document;
    final permissions = doc.commands.permissions;
    final keys = ctx.selection.keys.toList()
      ..sort((a, b) => a.target.value.compareTo(b.target.value));
    Map<Handle, List<int>>? byOwner;
    // Every key's commands are built first and executed together as one
    // `CompoundCommand`: a delete of N objects is one undo step, and a
    // failure anywhere in the cascade leaves the document as it was.
    // `named` is every handle the commands so far will remove — including
    // the fills a boundary's removal takes with it — so a key that an
    // earlier key's cascade already covers emits nothing; a second removal
    // would throw and roll the whole delete back. A key's own handles join
    // `named` only after its permission preflight passes, so a refused
    // group (which stays, spec D10) does not hide the keys inside it.
    final commands = <DraftCommand>[];
    final named = <Handle>{};
    final removed = <SelectionKey>[];
    for (final key in keys) {
      if (named.contains(key.target)) {
        // An earlier key's cascade removes it; deselect it with that key
        // rather than leaving it to the async prune (D11).
        removed.add(key);
        continue;
      }
      final List<DraftCommand> list;
      final Set<Handle> names;
      final node = doc.tree[key.target];
      if (node is GroupNode) {
        byOwner ??= doc.leavesByOwner();
        names = Set.of(named);
        list = _groupCascade(doc, node, byOwner, names);
      } else if (node is InstanceNode) {
        names = {key.target};
        list = [RemoveNodeCommand(key.target)];
      } else if (doc.entities.slotOf(key.target) != null) {
        names = {key.target, ...doc.fills.fillsOf(key.target)};
        list = [RemoveEntityCommand(key.target)];
      } else {
        continue;
      }
      // A refused key stays selected and untouched (spec D10); the others
      // still go. The set, not the summary capability: a compound member
      // is refused when any of its own is.
      if (!list.every((c) => c.capabilities.every(permissions.allows))) {
        continue;
      }
      commands.addAll(list);
      named.addAll(names);
      removed.add(key);
    }
    if (commands.isEmpty) return;
    ctx.execute(CompoundCommand(commands, label: 'Delete'));
    ctx.selection.remove(removed);
  }

  /// Leaves first (fills whose boundary is here skipped), child instances,
  /// nested groups recursively, the group last. Handles already in [named]
  /// are skipped, and every handle the returned commands will remove —
  /// including the fills that go with a boundary — is added to it.
  List<DraftCommand> _groupCascade(DraftDocument doc, GroupNode group,
      Map<Handle, List<int>> byOwner, Set<Handle> named) {
    final out = <DraftCommand>[];
    final leaves = byOwner[group.handle] ?? const <int>[];
    final boundaries = <Handle>{};
    for (final slot in leaves) {
      if (doc.entities.kindAt(slot) != EntityKind.fill) {
        boundaries.add(doc.entities.handleAt(slot));
      }
    }
    final skip = <Handle>{for (final b in boundaries) ...doc.fills.fillsOf(b)};
    for (final slot in leaves) {
      final h = doc.entities.handleAt(slot);
      if (skip.contains(h)) continue;
      if (!named.add(h)) continue;
      named.addAll(doc.fills.fillsOf(h));
      out.add(RemoveEntityCommand(h));
    }
    for (final child in doc.tree.childNodesOf(group.children)) {
      final n = doc.tree[child];
      if (n is GroupNode) {
        out.addAll(_groupCascade(doc, n, byOwner, named));
      } else if (n is InstanceNode) {
        if (named.add(child)) out.add(RemoveNodeCommand(child));
      }
    }
    if (named.add(group.handle)) out.add(RemoveNodeCommand(group.handle));
    return out;
  }

  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {
    final rect = bandScreen;
    if (rect == null) return;
    final crossing = _bandMode == BandMode.crossing;
    final color = crossing ? kCrossingBandColor : kWindowBandColor;
    canvas.drawRect(rect, Paint()..color = color.withAlpha(kBandFillAlpha));
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    if (!crossing) {
      canvas.drawRect(rect, stroke);
      return;
    }
    _drawDashedRect(canvas, rect, stroke);
  }

  /// 6-on/4-off dashes, screen pixels, walking the four edges clockwise from
  /// the top-left corner.
  void _drawDashedRect(Canvas canvas, Rect rect, Paint stroke) {
    const on = 6.0, off = 4.0;
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
      rect.topLeft,
    ];
    final path = Path();
    for (var i = 0; i < corners.length - 1; i++) {
      final start = corners[i];
      final end = corners[i + 1];
      final delta = end - start;
      final length = delta.distance;
      if (length == 0) continue;
      final direction = Offset(delta.dx / length, delta.dy / length);
      var travelled = 0.0;
      var drawing = true;
      while (travelled < length) {
        final step = math.min(drawing ? on : off, length - travelled);
        final segmentStart = start + direction * travelled;
        final segmentEnd = start + direction * (travelled + step);
        if (drawing) {
          path.moveTo(segmentStart.dx, segmentStart.dy);
          path.lineTo(segmentEnd.dx, segmentEnd.dy);
        }
        travelled += step;
        drawing = !drawing;
      }
    }
    canvas.drawPath(path, stroke);
  }
}
