import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../live.dart';
import 'wall.dart';
import 'wall_geometry.dart';

/// A wall's end grips (spec 07 D11), through the render layer's object grip
/// seam.
///
/// - **Grips:** two `stretch` grips at the wall's world endpoints, index 0
///   the start and 1 the end, computed as `WorldWall` computes them, so they
///   sit bitwise where the geometry puts the ends. None on a holder that
///   is not a live wall object ([wallsInDocument], as [drag] and [preview]
///   read it): a file's stray `WallParams` offers no grips.
/// - **Drag:** one [CompoundCommand] of `SetComponentCommand<WallParams>`:
///   the dragged end, and every other live wall's end within
///   `wallJoin.linear` of it in world (a live wall's, by the engine's rule;
///   a file's stray `WallParams` does not follow), ascending by handle,
///   each written back in its own group's local space. Joined ends follow,
///   in one undo step.
///   A drag that would leave any of those walls no longer than
///   `wallJoin.linear` is refused.
/// - **Openings stay put** (spec 08 D13): joins with the opening type, in
///   3a's Task 14.
/// - **Preview:** the moved centrelines, in world; openings regenerate on
///   release.
///
/// The dragged point is where the select tool's snap chain resolves it; it
/// is not band-joined onto another wall as the Wall tool's clicks are.
///
/// A wall is [movable]: the select tool moves and rotates it (spec 08 D16).
final class WallGrips implements ObjectGripProvider {
  /// [live] names the live walls ([wallsInDocument]): a frozen wall offers
  /// no grips and does not follow a joined end (spec 3a C1.5).
  WallGrips({required LiveTypeOf live}) : _live = live;

  final LiveTypeOf _live;

  /// The ends [preview] moves, per grip: computed once for the grip being
  /// dragged. The grip cache hands out new grips whenever the selected
  /// wall changes, and [drag] always computes them afresh.
  List<(Handle, int)>? _ends;
  DraftDocument? _endsDocument;
  Grip? _endsGrip;

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    final w = wallsInDocument(d, group, _live)?.host;
    if (w == null) return const [];
    return [
      Grip(GripRole.stretch, 0, w.s.x, w.s.y),
      Grip(GripRole.stretch, 1, w.e.x, w.e.y),
    ];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final moved = _moved(d, _endsAt(d, group, grip), world);
    if (moved == null) return null;
    return CompoundCommand([
      for (final (h, p, _) in moved) SetComponentCommand<WallParams>(h, p),
    ], label: 'Move wall ends');
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    if (!identical(d, _endsDocument) || !identical(grip, _endsGrip)) {
      _ends = _endsAt(d, group, grip);
      _endsDocument = d;
      _endsGrip = grip;
    }
    final moved = _moved(d, _ends!, world);
    if (moved == null) return const [];
    return [
      for (final (_, _, w) in moved) (EntityKind.line, linePayload(w.s, w.e)),
    ];
  }

  @override
  bool movable(DraftDocument d, Handle group) => true;

  /// [grip]'s end of [group], then every other live wall's end within
  /// `wallJoin.linear` of it (world), ascending by handle, then end index.
  /// A degenerate neighbour joins nothing (D2), so it is left where it is.
  ///
  /// The walls are [wallsInDocument]'s: live walls only, by the engine's
  /// object rule through [_live]. A stray `WallParams` a file brings
  /// in (on any holder that is not a root-level group: a handle with no
  /// node, a nested group, a root-level instance; or shadowed on a group a
  /// later-registered type names, such as an opening) is not a wall, so it
  /// does not follow; writing it would be refused (spec 06 D5), or would
  /// regenerate the object it is not.
  List<(Handle, int)> _endsAt(DraftDocument d, Handle group, Grip grip) {
    final walls = wallsInDocument(d, group, _live);
    if (walls == null) return const [];
    final at = walls.host.endpoint(grip.index);
    final ends = <(Handle, int)>[(group, grip.index)];
    for (final w in walls.walls) {
      if (w.degenerate) continue;
      for (var k = 0; k < 2; k++) {
        if ((w.endpoint(k) - at).length <= wallJoin.linear) {
          ends.add((w.handle, k));
        }
      }
    }
    ends.sort((a, b) {
      final c = a.$1.value.compareTo(b.$1.value);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    return ends;
  }

  /// Each wall of [ends] with those ends at [world], in its own group's
  /// local space, and its moved world wall; ascending by handle. Null when
  /// there is nothing to move, or when a moved wall would be no longer than
  /// `wallJoin.linear` (D2's degenerate wall).
  static List<(Handle, WallParams, WorldWall)>? _moved(
      DraftDocument d, List<(Handle, int)> ends, Vector2 world) {
    if (ends.isEmpty) return null;
    final out = <(Handle, WallParams, WorldWall)>[];
    for (final (h, k) in ends) {
      final toWorld = d.tree.accumulatedTransform(h);
      final local = toWorld.invert().transformPoint(world);
      final i = out.length - 1;
      // Both ends of one wall: it follows the same point with both.
      final base = i >= 0 && out[i].$1 == h
          ? out.removeLast().$2
          : d.components.get<WallParams>(h);
      if (base == null) return null;
      final p =
          k == 0 ? base.copyWith(start: local) : base.copyWith(end: local);
      final w = WorldWall(h, p, toWorld);
      if (!((w.e - w.s).length > wallJoin.linear)) return null;
      out.add((h, p, w));
    }
    return out;
  }
}
