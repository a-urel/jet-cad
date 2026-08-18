import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'camera_controller.dart';
import 'draw_sink.dart';
import 'viewport_transform.dart';

/// Draws the document the slow, obvious way, so [DraftPainter] can be compared
/// against it.
///
/// **It uses no `SpatialIndex`.** No packed tree, no dirty overlay, no
/// container index, no scratch buffers, no cull floor, no anisotropy bypass —
/// it walks `doc.tree` from the root, reads leaves through `leavesByOwner`,
/// composes transforms with `Transform2.multiply`, and keeps an entity when its
/// world-space [entityBounds] meets the view. That independence is the whole
/// value: two implementations sharing a mistake agree, and a test comparing
/// them stays green.
///
/// It agrees with the painter on three things only, because all three are
/// inputs rather than answers: the document, the camera, and the rebase origin.
///
/// Group flattening is reproduced rather than avoided. A group's leaves belong
/// to the container that encloses the group and sort among that container's own
/// leaves by handle — which is what `ContainerIndex` does when it folds them
/// in, and what the draw order means. An instance is the recursion boundary.
void referenceWalk(
  DraftDocument doc,
  DrawSink sink,
  ViewportTransform camera,
  Size viewport,
  StyleResolver resolver,
) {
  final world = camera.visibleWorld(viewport);
  final origin = rebaseOriginFor(world);
  _ReferenceWalk(
          doc, sink, camera, resolver, world, origin, doc.leavesByOwner())
      .container(
          doc.rootHandle, Transform2.identity(), StyleContext.documentRoot, 0);
}

class _ReferenceWalk {
  _ReferenceWalk(this.doc, this.sink, this.camera, this.resolver, this.world,
      this.origin, this.leaves);

  final DraftDocument doc;
  final DrawSink sink;
  final ViewportTransform camera;
  final StyleResolver resolver;
  final Aabb2 world;
  final Vector2 origin;
  final Map<Handle, List<int>> leaves;

  /// Draws one container's contents in ascending handle order.
  void container(
      Handle handle, Transform2 accumulated, StyleContext ctx, int depth) {
    if (depth > 64) return;
    final items = <_Item>[];
    _collect(handle, accumulated, items);
    items.sort((a, b) => a.handle.value.compareTo(b.handle.value));
    for (final item in items) {
      if (item.slot != null) {
        _leaf(item.slot!, item.placement, ctx);
      } else {
        final node = doc.tree[item.handle];
        if (node is! InstanceNode) continue;
        container(node.definition, item.placement,
            resolver.contextFor(item.handle, ctx), depth + 1);
      }
    }
  }

  /// Everything [handle] contributes to the enclosing container: its own
  /// leaves, the leaves of every group beneath it, and the instances found
  /// along the way — each with its transform composed down from [accumulated].
  void _collect(Handle handle, Transform2 accumulated, List<_Item> into) {
    for (final slot in leaves[handle] ?? const <int>[]) {
      into.add(_Item(doc.entities.handleAt(slot), accumulated, slot: slot));
    }
    for (final child in _childNodesOf(handle)) {
      final node = doc.tree[child];
      if (node == null) continue;
      final composed = accumulated.multiply(node.transform);
      if (node is InstanceNode) {
        into.add(_Item(child, composed));
      } else {
        _collect(child, composed, into);
      }
    }
  }

  List<Handle> _childNodesOf(Handle container) {
    final node = doc.tree[container];
    if (node is GroupNode) return doc.tree.childNodesOf(node.children);
    final definition = doc.tree.definition(container);
    if (definition != null) return doc.tree.childNodesOf(definition.children);
    return const [];
  }

  void _leaf(int slot, Transform2 placement, StyleContext ctx) {
    final kind = doc.entities.kindAt(slot);
    final payload = doc.geometry.peek(doc.entities.geomIndexAt(slot));
    if (kind == EntityKind.text || kind == EntityKind.attrib) return;
    if (doc.entities.flagsAt(slot) & EntityFlags.invisible != 0) return;

    // textStyle/textAttrs/text are dead for this call: the early return above
    // already skips every TEXT and ATTRIB entity, so this always resolves a
    // non-text kind's defaults. They stay wired through so this expression
    // matches the other three `entityBounds` call sites exactly and cannot
    // silently drift from them; they start mattering once Task 10 stops
    // skipping text here.
    final box = entityBounds(
      kind: kind,
      payload: payload,
      measurer: doc.textMeasurer,
      textStyle: doc.textStyleOf(doc.entities.textStyleAt(slot)),
      textAttrs: doc.entities.textAttrsAt(slot),
      text: doc.entities.textAt(slot),
    ).transformedBy(placement);
    if (box.isEmpty || !box.intersects(world)) return;

    final det = placement.determinant;
    final localOrigin = det == 0.0 || !det.isFinite
        ? Vector2.zero()
        : placement.invert().transformPoint(origin);
    final chain = camera.worldToScreenMatrix
        .multiply(placement)
        .multiply(Transform2.translation(localOrigin.x, localOrigin.y));
    final style = resolver.styleFor(slot, ctx);
    final coords = payload.coords;
    final ox = localOrigin.x;
    final oy = localOrigin.y;

    sink.beginResidual(chain, debugHandle: doc.entities.handleAt(slot));
    switch (kind) {
      case EntityKind.point:
        sink.point(coords[0] - ox, coords[1] - oy, style);
      case EntityKind.line:
      case EntityKind.polyline:
        final count = payload.pointCount;
        final points = Float64List(count * 2);
        for (var i = 0; i < count; i++) {
          points[i * 2] = coords[i * 2] - ox;
          points[i * 2 + 1] = coords[i * 2 + 1] - oy;
        }
        sink.polyline(points, count, style, closed: false);
      case EntityKind.circle:
        sink.circle(coords[0] - ox, coords[1] - oy, payload.scalars[0], style);
      case EntityKind.arc:
        sink.arc(coords[0] - ox, coords[1] - oy, payload.scalars[0],
            payload.scalars[1], payload.scalars[2], style);
      case EntityKind.text:
      case EntityKind.attrib:
        break;
    }
    sink.endResidual();
  }
}

class _Item {
  _Item(this.handle, this.placement, {this.slot});
  final Handle handle;
  final Transform2 placement;
  final int? slot;
}
