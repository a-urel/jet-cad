import 'dart:math' as math;
import 'dart:ui' show Canvas, Offset, Paint, Path, PaintingStyle, Rect, Size;

import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'selection.dart';
import 'selection_style.dart';
import 'tool.dart';
import 'viewport_transform.dart';

/// Pick radius in **screen** pixels (spec D7); `ToolPointerEvent.pickRadiusWorld`
/// is this converted per event. Moves to `interaction_style.dart` in Task 9.
const double kPickRadiusPixels = 6.0;

/// A press that moves less than this many screen pixels stays a click
/// (M-02f); past it, a press that started on empty space becomes a band.
const double kBandSlopPixels = 4.0;

/// Hover, click, shift-click and rubber-band selection (spec D1, D2, D7,
/// D8), plus Escape and Delete/Backspace (spec D3, D10).
class SelectTool extends Tool {
  SelectTool();

  @override
  String get name => 'Select';
  ToolPhase _phase = ToolPhase.idle;
  @override
  ToolPhase get phase => _phase;

  final HitPath _hit = HitPath();
  Offset _start = Offset.zero;
  final Vector2 _startWorld = Vector2.zero();
  SelectionKey? _downKey;
  bool _downHit = false;
  Offset _end = Offset.zero;
  BandMode? _bandMode;
  int _pointer = -1;

  /// Non-null only while a band drag is in progress, for the overlay.
  BandMode? get bandMode => _phase == ToolPhase.dragging ? _bandMode : null;

  /// The band rectangle in screen space, for the overlay test.
  Rect? get bandScreen =>
      _phase == ToolPhase.dragging ? Rect.fromPoints(_start, _end) : null;

  /// The band's drag-start corner, for the overlay.
  Offset? get bandStart => _phase == ToolPhase.dragging ? _start : null;

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
    _startWorld.setFrom(e.world);
    _downKey = _pick(e, ctx);
    _downHit = _downKey != null;
    notifyListeners();
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    switch (_phase) {
      case ToolPhase.idle:
        if (e.buttons != 0) return;
        ctx.selection.setHover(_pick(e, ctx));
      case ToolPhase.pressed:
        if (e.pointer != _pointer) return;
        if ((e.screen - _start).distance < kBandSlopPixels) return;
        if (_downHit) return;
        _phase = ToolPhase.dragging;
        ctx.selection.setHover(null);
        _end = e.screen;
        _bandMode = _end.dx >= _start.dx ? BandMode.window : BandMode.crossing;
        notifyListeners();
      case ToolPhase.dragging:
        if (e.pointer != _pointer) return;
        _end = e.screen;
        _bandMode = _end.dx >= _start.dx ? BandMode.window : BandMode.crossing;
        notifyListeners();
    }
  }

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {
    if (e.pointer != _pointer) return;
    switch (_phase) {
      case ToolPhase.idle:
        return;
      case ToolPhase.pressed:
        final key = _downKey;
        if (key != null) {
          e.shift ? ctx.selection.toggle([key]) : ctx.selection.replace([key]);
        } else if (!e.shift) {
          ctx.selection.clear();
        }
      case ToolPhase.dragging:
        final keys = _bandKeys(ctx, e);
        e.shift ? ctx.selection.toggle(keys) : ctx.selection.replace(keys);
    }
    _reset();
    notifyListeners();
  }

  /// Every root-level key the band selects: root entities, groups (spec D8,
  /// Ruling 02-2 — decided here from the passing-slot set, once per band)
  /// and instances.
  List<SelectionKey> _bandKeys(ToolContext ctx, ToolPointerEvent e) {
    final mode = _bandMode!;
    final a = _startWorld, b = e.world;
    final band = Aabb2.raw(math.min(a.x, b.x), math.min(a.y, b.y),
        math.max(a.x, b.x), math.max(a.y, b.y));
    final passing = <int>{};
    ctx.index.forEachLeafInBand(
        band, mode, const QueryFilter.picking(), passing.add);
    final keys = <SelectionKey>[];
    final seenGroups = <Handle>{};
    final doc = ctx.document;
    Map<Handle, List<int>>? byOwner;
    for (final slot in passing) {
      final owner = doc.entities.ownerAt(slot);
      if (owner == doc.rootHandle) {
        keys.add(SelectionKey.root(doc.entities.handleAt(slot)));
        continue;
      }
      final top = _topmostGroup(doc, owner);
      if (top == null || !seenGroups.add(top)) continue;
      byOwner ??= doc.leavesByOwner();
      if (mode == BandMode.crossing ||
          _everyLeafIn(doc, top, byOwner, passing)) {
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
  bool _everyLeafIn(DraftDocument doc, Handle group,
      Map<Handle, List<int>> byOwner, Set<int> passing) {
    var any = false;
    final stack = <Handle>[group];
    while (stack.isNotEmpty) {
      final g = stack.removeLast();
      for (final slot in byOwner[g] ?? const <int>[]) {
        if (doc.entities.kindAt(slot) == EntityKind.fill) continue;
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
    _downKey = null;
    _downHit = false;
    _bandMode = null;
  }

  @override
  void onPointerExit(ToolContext ctx) {
    ctx.selection.setHover(null);
    if (_phase == ToolPhase.dragging) cancel(ctx);
  }

  @override
  void cancel(ToolContext ctx) {
    if (_phase == ToolPhase.idle) return;
    _reset();
    notifyListeners();
  }

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_phase == ToolPhase.dragging) {
        cancel(ctx);
      } else if (_phase == ToolPhase.idle) {
        ctx.selection.clear();
      }
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
    for (final key in keys) {
      final List<DraftCommand> list;
      final node = doc.tree[key.target];
      if (node is GroupNode) {
        byOwner ??= doc.leavesByOwner();
        list = _groupCascade(doc, node, byOwner);
      } else if (node is InstanceNode) {
        list = [RemoveNodeCommand(key.target)];
      } else if (doc.entities.slotOf(key.target) != null) {
        list = [RemoveEntityCommand(key.target)];
      } else {
        continue;
      }
      if (!list.every((c) => permissions.allows(c.capability))) continue;
      for (final c in list) {
        ctx.execute(c);
      }
      ctx.selection.remove([key]);
    }
  }

  /// Leaves first (fills whose boundary is here skipped), child instances,
  /// nested groups recursively, the group last.
  List<DraftCommand> _groupCascade(
      DraftDocument doc, GroupNode group, Map<Handle, List<int>> byOwner) {
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
      out.add(RemoveEntityCommand(h));
    }
    for (final child in doc.tree.childNodesOf(group.children)) {
      final n = doc.tree[child];
      if (n is GroupNode) {
        out.addAll(_groupCascade(doc, n, byOwner));
      } else if (n is InstanceNode) {
        out.add(RemoveNodeCommand(child));
      }
    }
    out.add(RemoveNodeCommand(group.handle));
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
