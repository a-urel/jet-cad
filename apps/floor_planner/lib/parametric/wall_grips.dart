import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'opening.dart';
import 'wall.dart';
import 'wall_geometry.dart';

/// A wall's end grips (spec 07 D11), through the render layer's object grip
/// seam.
///
/// - **Grips:** two `stretch` grips at the wall's world endpoints, index 0
///   the start and 1 the end, computed as `WorldWall` computes them, so they
///   sit bitwise where the geometry puts the ends.
/// - **Drag:** one [CompoundCommand] of `SetComponentCommand<WallParams>`:
///   the dragged end, and every other wall end within `wallJoin.linear` of
///   it in world, ascending by handle, each written back in its own group's
///   local space. Joined ends follow, in one undo step. A drag that would
///   leave any of those walls no longer than `wallJoin.linear` is refused.
/// - **Openings stay put** (spec 08 D13): in the same compound, after the
///   walls' own commands, one `SetComponentCommand<OpeningParams>` per
///   opening of each wall whose stored `start` moved and whose `end` did
///   not, keeping its distance from that end ([_keptPut]). Openings on a
///   wall whose end alone moved, or both ends, keep their positions.
/// - **Preview:** the moved centrelines, in world; openings regenerate on
///   release.
///
/// The dragged point is where the select tool's snap chain resolves it; it
/// is not band-joined onto another wall as the Wall tool's clicks are.
final class WallGrips implements ObjectGripProvider {
  /// The ends [preview] moves, per grip: computed once for the grip being
  /// dragged. The grip cache hands out new grips whenever the selected
  /// wall changes, and [drag] always computes them afresh.
  List<(Handle, int)>? _ends;
  DraftDocument? _endsDocument;
  Grip? _endsGrip;

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    final w = _world(d, group);
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
      ..._keptPut(d, moved),
    ], label: 'Move wall ends');
  }

  /// Spec 08 D13: for each wall of [moved] (ascending by handle) whose
  /// stored `start` changed and whose `end` did not (exact `==`, stored
  /// values), each of its live openings, ascending, rewritten to
  /// `p′ = L′ − (L − p)`: its distance from the end that did not move is
  /// kept. `L` and `L′` are the centreline's group-local lengths before
  /// and after. The document's openings are read once: O(openings).
  static List<DraftCommand> _keptPut(
      DraftDocument d, List<(Handle, WallParams, WorldWall)> moved) {
    final rewrite = <Handle, (double, double)>{};
    for (final (h, p, _) in moved) {
      final old = d.components.get<WallParams>(h)!;
      if (p.start != old.start && p.end == old.end) {
        rewrite[h] = ((old.end - old.start).length, (p.end - p.start).length);
      }
    }
    if (rewrite.isEmpty) return const [];
    final byHost = <Handle, List<(Handle, OpeningParams)>>{};
    for (final o in d.components.withComponent<OpeningParams>()) {
      final node = d.tree[o];
      if (node is! GroupNode || node.parent != d.tree.root) continue;
      final params = d.components.get<OpeningParams>(o)!;
      if (!rewrite.containsKey(params.host)) continue;
      byHost.putIfAbsent(params.host, () => []).add((o, params));
    }
    final out = <DraftCommand>[];
    for (final (h, _, _) in moved) {
      final lengths = rewrite[h];
      final openings = byHost[h];
      if (lengths == null || openings == null) continue;
      final (l, l2) = lengths;
      openings.sort((a, b) => a.$1.value.compareTo(b.$1.value));
      for (final (o, params) in openings) {
        out.add(SetComponentCommand<OpeningParams>(
            o, params.copyWith(position: l2 - (l - params.position))));
      }
    }
    return out;
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

  /// [h] as the geometry reads it; null when it is not a wall.
  static WorldWall? _world(DraftDocument d, Handle h) {
    final p = d.components.get<WallParams>(h);
    return p == null ? null : WorldWall(h, p, d.tree.accumulatedTransform(h));
  }

  /// [grip]'s end of [group], then every other wall end within
  /// `wallJoin.linear` of it (world), ascending by handle, then end index.
  /// A degenerate neighbour joins nothing (D2), so it is left where it is.
  static List<(Handle, int)> _endsAt(DraftDocument d, Handle group, Grip grip) {
    final self = _world(d, group);
    if (self == null) return const [];
    final at = self.endpoint(grip.index);
    final ends = <(Handle, int)>[(group, grip.index)];
    for (final h in d.components.withComponent<WallParams>()) {
      if (h == group) continue;
      final w = _world(d, h)!;
      if (w.degenerate) continue;
      for (var k = 0; k < 2; k++) {
        if ((w.endpoint(k) - at).length <= wallJoin.linear) ends.add((h, k));
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
