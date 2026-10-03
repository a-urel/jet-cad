import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'room_inputs.dart';
import 'separator.dart';

/// A separator's end grips (spec 10 D21, D20), through the render layer's
/// object grip seam.
///
/// - **Grips:** two `stretch` grips at the separator's world ends, index 0
///   the start and 1 the end.
/// - **Drag:** the dragged end goes to the point the select tool has
///   already resolved through its snap chain (08's Ruling 08-15), then
///   through [trimSeparator] with the end that stays, over the shell's
///   [RoomInputs] and F3's object snap ([objectSnap]): the one function the
///   Separator tool calls (Ruling 10-9), so a dragged end is band-trimmed
///   as a drawn one is. The end that stays is stored as it was, bit for
///   bit: a drag moves one end. One `SetComponentCommand<SeparatorParams>`,
///   the moved end written back in the separator group's local space, or
///   null when [trimSeparator] makes nothing (both ends in one band, or too
///   short) or the drag stores what is stored (a drop on the end itself
///   included: the round trip through the group's transform is not exact).
/// - **Preview:** the segment as it would be stored, in world.
/// - **Movable:** the select tool moves and rotates a separator like any
///   line.
///
/// [inputs] is invalidated at each release, before the trim, as the
/// Separator tool does at its second click: the document's change stream
/// delivers after the task that made a change (Ruling 10-11).
final class SeparatorGrips implements ObjectGripProvider {
  SeparatorGrips({required this.inputs, required this.objectSnap});

  /// The shell's document adapter, shared with the Room and Separator
  /// tools. Never disposed here.
  final RoomInputs inputs;

  /// Whether object snap (F3) is on, read at each drag event: band trimming
  /// is object snapping (R-21).
  final bool Function() objectSnap;

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    final ends = _worldEnds(d, group);
    if (ends == null) return const [];
    final (s, e) = ends;
    return [
      Grip(GripRole.stretch, 0, s.x, s.y),
      Grip(GripRole.stretch, 1, e.x, e.y),
    ];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final ends = _worldEnds(d, group);
    if (ends == null) return null;
    // A drop on the end itself stores what is stored.
    final end = grip.index == 0 ? ends.$1 : ends.$2;
    if (world.x == end.x && world.y == end.y) return null;
    inputs.invalidate();
    final moved = _moved(d, group, grip, world);
    if (moved == null) return null;
    final (p, _) = moved;
    if (p == d.components.get<SeparatorParams>(group)) return null;
    return SetComponentCommand<SeparatorParams>(group, p);
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final moved = _moved(d, group, grip, world);
    if (moved == null) return const [];
    final (_, (s, e)) = moved;
    return [(EntityKind.line, linePayload(s, e))];
  }

  @override
  bool movable(DraftDocument d, Handle group) => true;

  /// [group]'s ends in world; null when it is not a separator or an end is
  /// not finite.
  static (Vector2, Vector2)? _worldEnds(DraftDocument d, Handle group) {
    final p = d.components.get<SeparatorParams>(group);
    if (p == null) return null;
    final t = d.tree.accumulatedTransform(group);
    final s = t.transformPoint(p.start), e = t.transformPoint(p.end);
    if (!s.x.isFinite || !s.y.isFinite || !e.x.isFinite || !e.y.isFinite) {
      return null;
    }
    return (s, e);
  }

  /// [grip]'s end of [group] dragged to [world]: the parameters to store
  /// and the world segment they draw; null when [trimSeparator] makes
  /// nothing of it.
  (SeparatorParams, (Vector2, Vector2))? _moved(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final ends = _worldEnds(d, group);
    if (ends == null) return null;
    final start = grip.index == 0;
    final kept = start ? ends.$2 : ends.$1;
    final trimmed = start
        ? trimSeparator(world, kept, inputs, objectSnap: objectSnap())
        : trimSeparator(kept, world, inputs, objectSnap: objectSnap());
    if (trimmed == null) return null;
    final w = start ? trimmed.$1 : trimmed.$2;
    final local = d.tree.accumulatedTransform(group).invert().transformPoint(w);
    final p = d.components.get<SeparatorParams>(group)!;
    return start
        ? (p.copyWith(start: local), (w, kept))
        : (p.copyWith(end: local), (kept, w));
  }
}
