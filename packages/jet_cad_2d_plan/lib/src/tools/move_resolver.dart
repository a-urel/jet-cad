// Spec P3 "Attachment" (Task 14): plan.select's move resolver, ported from
// jet_cad_floor_plan's symbol_move.dart (spec 09c D8) over the registry.
// A root-level symbol instance whose jetcad.symbol names attachment kinds,
// dragged by its body with object snap on, attaches as a placement does,
// anchored on its plain-moved back-centre.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show MoveResolver, ToolContext;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show
        Attachment,
        AttachmentQuery,
        AttachmentRegistry,
        SymbolBox,
        SymbolComponent,
        boxOfDefinition,
        footprintOf,
        isOrthonormal;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'plan_symbol_tool.dart' show kAttachPixels;

/// plan.select's [MoveResolver] over the current document's attachment
/// registry (spec P3; today's `SymbolMoveResolver`, spec 09c D8).
final class PlanMoveResolver implements MoveResolver {
  PlanMoveResolver({required this.attachments, this.canRotate});

  /// The current document's registry, read at each call.
  final AttachmentRegistry Function() attachments;

  /// Whether a move may turn the symbol (the permissions' rotate), read at
  /// each call; null allows.
  final bool Function()? canRotate;

  /// The document of the last call, weakly: the resolver lives as long as
  /// its controller and must not keep a replaced plan alive.
  WeakReference<DraftDocument>? _document;
  int _state = -1;
  Handle? _node;
  Attachment? _last;
  final Map<Handle, SymbolBox?> _boxes = <Handle, SymbolBox?>{};

  /// For a root-level instance of a live definition whose `SymbolComponent`
  /// names attachment kinds, with object snap on and an orthonormal
  /// transform (a scaled instance never attaches, so its scale is never
  /// dropped): the registry's answer for the plain move `delta · T`; else
  /// null.
  @override
  ({Transform2 transform, Vector2 marker})? resolveMove(
      ToolContext ctx, Handle node, Transform2 delta) {
    final doc = ctx.document;
    if (!(ctx.snap?.objectSnap ?? true)) return null;
    final n = doc.tree[node];
    if (n is! InstanceNode || n.parent != doc.rootHandle) return null;
    if (doc.tree.definition(n.definition) == null) return null;
    final symbol = doc.components.get<SymbolComponent>(n.definition);
    if (symbol == null || symbol.attachTo.isEmpty) return null;
    final t = n.transform;
    if (!isOrthonormal(t)) return null;
    _sync(doc, node);
    final box = _boxes.putIfAbsent(
        n.definition, () => boxOfDefinition(doc, n.definition));
    if (box == null) return null;
    final moved = delta.multiply(t);
    final scale = ctx.camera.value.scale;
    final a = attachments().attach(
        symbol.attachTo,
        AttachmentQuery(
          footprint: footprintOf(box),
          current: moved,
          pointer: moved.transformPoint(box.backCentre),
          capture: kAttachPixels / scale,
          edgeCapture: kSnapAperturePixels / scale,
          mirrored: t.a * t.d - t.b * t.c < 0,
          mayRotate: canRotate?.call() ?? true,
          exclude: {node},
          keep: _last,
        ));
    _last = a;
    if (a == null) return null;
    return (transform: a.transform, marker: a.marker);
  }

  /// One drag is one document state and one node: outside it the boxes
  /// and the keep start afresh.
  void _sync(DraftDocument doc, Handle node) {
    final state = doc.commands.stateId;
    if (identical(doc, _document?.target) && state == _state) {
      if (node != _node) {
        _node = node;
        _last = null;
      }
      return;
    }
    _document = WeakReference(doc);
    _state = state;
    _node = node;
    _last = null;
    _boxes.clear();
  }
}
