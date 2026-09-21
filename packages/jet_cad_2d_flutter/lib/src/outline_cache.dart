import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Path, Rect;

import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'selection.dart';

/// One piece of a selected object's outline, in **world** doubles.
sealed class _Outline {
  const _Outline();
}

/// A polyline chain: `moveTo` the first point, `lineTo` the rest.
final class _Segments extends _Outline {
  const _Segments(this.coords);

  /// Interleaved world x, y pairs.
  final Float64List coords;
}

/// A circular arc; a whole circle is `sweep = 2π`.
final class _Arc extends _Outline {
  const _Arc(this.cx, this.cy, this.r, this.start, this.sweep);
  final double cx, cy, r, start, sweep;
}

/// A lone world position — a `point` entity.
///
/// Its own variant rather than a one-pair [_Segments], because a path of a
/// single `moveTo` draws nothing and is indistinguishable from a vanished
/// target. The overlay reads it through [OutlineCache.worldPointOf] and
/// draws its own screen-space marker; a world-space cache cannot hold one,
/// since a marker's size is in pixels.
final class _Point extends _Outline {
  const _Point(this.x, this.y);
  final double x, y;
}

/// The overlay's outlines: world geometry in `Float64List`s, `ui.Path`s in
/// the space rebased by the frame's origin (spec D9, review ruling B2).
///
/// **No absolute world coordinate ever reaches `dart:ui` from here.**
/// `ui.Path` stores float32; at the generated corpus's x = 4.5e6 the float32
/// spacing is about half a unit, so a world-space path would sit visibly off
/// the entity it outlines while the startup plan at x = 5e3 still looked
/// fine. The world record is therefore kept in `Float64List`s and each
/// `ui.Path` is built with the frame's rebase origin subtracted, tagged with
/// that origin, and rebuilt only when the tag changes — the painter draws it
/// under `worldToScreen ∘ translate(origin)`.
///
/// The document walk happens at selection-change, hover-change and
/// `DocChange` rate — never per frame.
///
/// **A [ChangeNotifier], and a member of the overlay's repaint merge.** A
/// `DocChange` rebuilds the outlines, and nothing else in that merge hears a
/// `DocChange`: without this the new outline would sit in the cache while the
/// stale one stayed on screen until the next selection, hover or camera
/// change. A *selection*-driven rebuild is deliberately silent — the
/// selection controller has already notified the same merge, and notifying
/// again would cost a second repaint for one change.
class OutlineCache extends ChangeNotifier {
  OutlineCache(this.document, this.selection) {
    _subscription = document.changes.listen(_onChange);
    selection.addListener(_onSelection);
    _onSelection();
  }

  final DraftDocument document;
  final SelectionController selection;
  late final StreamSubscription<DocChange> _subscription;

  final Map<SelectionKey, List<_Outline>> _world =
      <SelectionKey, List<_Outline>>{};
  final Map<SelectionKey, Path> _paths = <SelectionKey, Path>{};

  final Vector2 _origin = Vector2.zero();

  /// Set until the paths agree with both [_world] and [_origin].
  bool _stale = true;

  /// The origin the current paths are rebased by.
  ///
  /// **Do not mutate; a mutated tag desyncs the rebased paths.** The live
  /// field is handed out rather than a copy because the overlay reads it once
  /// per frame and a copy would allocate at frame rate.
  Vector2 get origin => _origin;

  int _debugRebuilds = 0;

  /// How many times every path has been rebuilt. Test-only: the point of the
  /// tag is that two `pathFor` calls at one origin cost one rebuild, not two.
  @visibleForTesting
  int get debugRebuilds => _debugRebuilds;

  /// The path for [key] in the space rebased by [origin], or null when [key]
  /// is neither selected nor hovered.
  ///
  /// Rebuilds every path — from the cached `Float64List`s, with no document
  /// access — when [origin] differs from the tag, and retags.
  Path? pathFor(SelectionKey key, Vector2 origin) {
    if (_stale || origin != _origin) {
      _origin.setFrom(origin);
      _rebuildPaths();
    }
    return _paths[key];
  }

  /// The world position of [key] when its whole outline is a single `point`
  /// entity; null for every other key, and for a key that is not cached.
  ///
  /// **The overlay's affordance for drawing a point key** (Task 8). A point
  /// has no extent, so its `ui.Path` would be a lone `moveTo` — it draws
  /// nothing, and an empty path cannot be told apart from a target that has
  /// vanished. The marker a point deserves is a screen-space cross, whose
  /// size is in pixels and therefore cannot live in a world-space cache; the
  /// painter reads the position here and sizes the cross itself. The value is
  /// an absolute world position; map it to screen with `worldToScreen` (or
  /// rebase it) before it reaches `dart:ui`.
  Vector2? worldPointOf(SelectionKey key) {
    final outlines = _world[key];
    if (outlines == null || outlines.length != 1) return null;
    final only = outlines.first;
    return only is _Point ? Vector2(only.x, only.y) : null;
  }

  /// **Test-only.** Every `_Segments` outline of [key], concatenated in
  /// order, in world doubles; null when [key] is not cached.
  @visibleForTesting
  Float64List? debugWorldSegmentsOf(SelectionKey key) {
    final outlines = _world[key];
    if (outlines == null) return null;
    var length = 0;
    for (final o in outlines) {
      if (o is _Segments) length += o.coords.length;
    }
    final out = Float64List(length);
    var at = 0;
    for (final o in outlines) {
      if (o is! _Segments) continue;
      out.setRange(at, at + o.coords.length, o.coords);
      at += o.coords.length;
    }
    return out;
  }

  /// **Test-only.** Every `_Arc` outline of [key] as five world doubles —
  /// `cx, cy, r, start, sweep` — in order; null when [key] is not cached.
  ///
  /// `ui.Path.getBounds` cannot stand in for this: it returns the bounds of
  /// the conic **control points**, which for a partial sweep lie outside the
  /// curve (measured: a 2.6 rad sweep of radius 7 reads `maxX = 19.1` where
  /// the arc's own bound is 17.0), so a bounds comparison can neither pin the
  /// start angle nor the sweep's sign.
  @visibleForTesting
  Float64List? debugWorldArcsOf(SelectionKey key) {
    final outlines = _world[key];
    if (outlines == null) return null;
    final arcs = outlines.whereType<_Arc>().toList();
    final out = Float64List(arcs.length * 5);
    for (var i = 0; i < arcs.length; i++) {
      final a = arcs[i];
      out[i * 5] = a.cx;
      out[i * 5 + 1] = a.cy;
      out[i * 5 + 2] = a.r;
      out[i * 5 + 3] = a.start;
      out[i * 5 + 4] = a.sweep;
    }
    return out;
  }

  @override
  void dispose() {
    _subscription.cancel();
    selection.removeListener(_onSelection);
    _world.clear();
    _paths.clear();
    super.dispose();
  }

  // --- keys in, keys out -------------------------------------------------

  /// Adds what entered the selection or the hover, drops what left.
  void _onSelection() {
    final live = <SelectionKey>{...selection.keys};
    final hover = selection.hover;
    if (hover != null) live.add(hover);
    var changed = _world.keys.toSet().difference(live).isNotEmpty;
    _world.removeWhere((k, _) => !live.contains(k));
    final entering = [
      for (final k in live)
        if (!_world.containsKey(k)) k
    ];
    if (entering.isNotEmpty) {
      _walk(entering);
      changed = true;
    }
    if (changed) _invalidatePaths();
  }

  /// Records the world outline of each of [keys], sharing one
  /// `leavesByOwner()` scan across the whole batch and never across batches —
  /// the document may have changed since the last one.
  void _walk(Iterable<SelectionKey> keys) {
    _byOwner = null;
    _filters = null;
    for (final key in keys) {
      _world[key] = _outlinesFor(key);
    }
    _byOwner = null;
    _filters = null;
  }

  /// Spec D9: **every** `DocChange` rebuilds **every** cached outline. A leaf
  /// edited inside a selected instance's definition or group touches neither
  /// the instance nor the group handle, so an exact-handle rule never fires
  /// for it; selection is small and commands arrive at command rate.
  void _onChange(DocChange change) {
    if (change is DocumentLoaded || change is DocumentPurged) {
      // D11 drops the keys first; this clears whatever is left either way.
      _world.clear();
      _invalidatePaths();
      notifyListeners();
      return;
    }
    if (_world.isEmpty) return;
    _walk(_world.keys.toList());
    _invalidatePaths();
    notifyListeners();
  }

  void _invalidatePaths() {
    _paths.clear();
    _stale = true;
  }

  void _rebuildPaths() {
    _paths.clear();
    final ox = _origin.x, oy = _origin.y;
    for (final entry in _world.entries) {
      final path = Path();
      for (final outline in entry.value) {
        switch (outline) {
          case _Segments(:final coords):
            if (coords.length < 2) continue;
            path.moveTo(coords[0] - ox, coords[1] - oy);
            for (var i = 2; i < coords.length; i += 2) {
              path.lineTo(coords[i] - ox, coords[i + 1] - oy);
            }
          case _Arc(:final cx, :final cy, :final r, :final start, :final sweep):
            // The painter applies the world→screen matrix — y-flip included
            // — to the whole path, so the world angles go in unchanged.
            path.addArc(
              Rect.fromCircle(center: Offset(cx - ox, cy - oy), radius: r),
              start,
              sweep,
            );
          case _Point():
            // No extent, so nothing to stroke: the overlay draws a point key
            // from `worldPointOf` as a screen-space marker instead.
            continue;
        }
      }
      _paths[entry.key] = path;
    }
    _stale = false;
    _debugRebuilds++;
  }

  // --- the world record --------------------------------------------------

  /// [key] is a leaf, a group or an instance (02 never produces a chain).
  List<_Outline> _outlinesFor(SelectionKey key) {
    final out = <_Outline>[];
    final node = document.tree[key.target];
    switch (node) {
      case InstanceNode():
        _addInstance(
            out, node, document.tree.accumulatedTransform(key.target), null);
      case GroupNode():
        _addContainer(out, key.target, node.children,
            document.tree.accumulatedTransform(key.target), null);
      case null:
        final slot = document.entities.slotOf(key.target);
        if (slot == null) break;
        final owner = document.entities.ownerAt(slot);
        _addLeaf(
            out,
            slot,
            owner == document.rootHandle
                ? Transform2.identity()
                : document.tree.accumulatedTransform(owner));
    }
    return out;
  }

  /// An instance's contents: its definition's leaves and child nodes, each
  /// carried through [toWorld] (which already includes the instance's own
  /// transform).
  void _addInstance(List<_Outline> out, InstanceNode node, Transform2 toWorld,
      Set<Handle>? visiting) {
    final definition = document.tree.definition(node.definition);
    if (definition == null) return;
    final open = visiting ?? <Handle>{};
    // A definition that reaches itself is rejected by `addNode`, but an
    // imported document can carry one; an outline is not the place to throw.
    if (!open.add(node.definition)) return;
    _addContainer(out, node.definition, definition.children, toWorld, open);
    open.remove(node.definition);
  }

  /// Every leaf owned by [container], then its child groups and instances.
  ///
  /// [toWorld] maps [container]'s own space to world.
  void _addContainer(List<_Outline> out, Handle container,
      List<Handle> children, Transform2 toWorld, Set<Handle>? visiting) {
    final byOwner = _byOwner ??= document.leavesByOwner();
    for (final slot in byOwner[container] ?? const <int>[]) {
      _addLeaf(out, slot, toWorld);
    }
    for (final child in document.tree.childNodesOf(children)) {
      final node = document.tree[child];
      switch (node) {
        case GroupNode():
          _addContainer(out, child, node.children,
              toWorld.multiply(node.transform), visiting);
        case InstanceNode():
          _addInstance(out, node, toWorld.multiply(node.transform), visiting);
        case null:
          break;
      }
    }
  }

  /// `document.leavesByOwner()` is a full entity-store scan; one per walk.
  Map<Handle, List<int>>? _byOwner;

  /// The filter's layer and container answers are memoised, and a layer
  /// record or a node's visibility may have changed since the last walk, so
  /// the evaluator is built once per walk and dropped with it.
  FilterEvaluator? _filters;

  void _addLeaf(List<_Outline> out, int slot, Transform2 t) {
    // Spec D9, amended at execution: the outline is a statement about what is
    // drawn, so it skips exactly what the canvas skips — `rendering()`, which
    // drops a hidden leaf and keeps a locked one.
    final filters = _filters ??= FilterEvaluator(document);
    if (!filters.acceptsEntity(slot, const QueryFilter.rendering())) return;
    final kind = document.entities.kindAt(slot);
    if (kind == EntityKind.fill) return; // a fill has no coordinates (D8)
    final payload = document.geometry.peek(document.entities.geomIndexAt(slot));
    switch (kind) {
      case EntityKind.point:
        if (payload.pointCount == 0) return;
        final p = t.transformPoint(payload.pointAt(0));
        out.add(_Point(p.x, p.y));
      case EntityKind.line:
      case EntityKind.polyline:
        final n = payload.pointCount;
        if (n == 0) return;
        final coords = Float64List(n * 2);
        final c = payload.coords;
        for (var i = 0; i < n; i++) {
          final x = c[i * 2], y = c[i * 2 + 1];
          coords[i * 2] = t.a * x + t.c * y + t.e;
          coords[i * 2 + 1] = t.b * x + t.d * y + t.f;
        }
        out.add(_Segments(coords));
      case EntityKind.circle:
        if (payload.pointCount == 0 || payload.scalars.isEmpty) return;
        final centre = t.transformPoint(payload.pointAt(0));
        out.add(_Arc(centre.x, centre.y, payload.scalars[0] * t.scaleMagnitude,
            0, 2 * math.pi));
      case EntityKind.arc:
        if (payload.pointCount == 0 || payload.scalars.length < 3) return;
        final r0 = payload.scalars[0];
        final centre = t.transformPoint(payload.pointAt(0));
        // The pick's rule (`spatial_index._considerLeaf`, `band_predicates`):
        // the world start angle comes from the transformed start *point*, and
        // a mirror — a negative determinant — flips the turning sense.
        final local = payload.pointAt(0);
        final start = t.transformPoint(Vector2(
          local.x + r0 * math.cos(payload.scalars[1]),
          local.y + r0 * math.sin(payload.scalars[1]),
        ));
        out.add(_Arc(
          centre.x,
          centre.y,
          r0 * t.scaleMagnitude,
          math.atan2(start.y - centre.y, start.x - centre.x),
          t.determinant < 0 ? -payload.scalars[2] : payload.scalars[2],
        ));
      case EntityKind.text:
      case EntityKind.attrib:
        final style = document.textStyleOf(document.entities.textStyleAt(slot));
        final box = textBoxOf(
          payload,
          document.entities.textAttrsAt(slot),
          style,
          document.textMeasurer
              .measure(text: document.entities.textAt(slot), style: style),
        );
        if (box == null) return;
        // Box space → leaf space → world, closed back on the first corner.
        final m = t.multiply(box.local);
        final xs = [box.minX, box.maxX, box.maxX, box.minX, box.minX];
        final ys = [box.minY, box.minY, box.maxY, box.maxY, box.minY];
        final coords = Float64List(10);
        for (var i = 0; i < 5; i++) {
          final p = m.transformPoint(Vector2(xs[i], ys[i]));
          coords[i * 2] = p.x;
          coords[i * 2 + 1] = p.y;
        }
        out.add(_Segments(coords));
      case EntityKind.fill:
        return;
    }
  }
}
