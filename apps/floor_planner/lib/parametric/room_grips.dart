import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'room.dart';

/// A room's label grip (spec 10 D21, S-10, R-22, R-26), through the render
/// layer's object grip seam. Every step is in a named frame: `_w` world,
/// `_l` the room group's local space.
///
/// - **The grip:** one `stretch` grip at the labels' anchor, in world:
///   `anchor_w = toWorld(q) − (0, 0.7 · h_name_w)`, `q` the name TEXT's
///   stored insertion point (local) and `h_name_w` the name's **world**
///   height, [kRoomNamePaperMm] × the page's scale (D11; the app's opening
///   page when the root carries none, R-14). D10 offsets the two lines from
///   the anchor in world directions, so the offset is taken off in world,
///   after `toWorld`, never from `q` in local space.
/// - **The pole**, local: `pole_l = toLocal(anchor_w) − label`, `label`
///   `(0, 0)` when auto (or not finite, which the room draws as auto, D2).
/// - **The drag** takes the point the select tool has already resolved
///   through its snap chain (08's Ruling 08-15), `p_w`, and stores:
///   - `null` (auto) when `|p_w − toWorld(pole_l)|`, in world, is within
///     [aperture] (R-26: the one way back to auto). The shell's aperture is
///     the snap aperture at the camera's scale **whatever F3 says** (Ruling
///     10-17): a reset gesture, not a snap;
///   - otherwise `label = toLocal(p_w) − pole_l`.
///
///   One `SetComponentCommand<RoomParams>`, or null when the drop stores
///   what is stored (a drop on the grip itself included: the label stays
///   where it is, bit for bit).
/// - **The preview:** a line from the pole to the would-be anchor, in
///   world; nothing when the drop returns the label to auto.
/// - **Not movable** (R-22): the select tool neither moves nor rotates a
///   room. A group move would carry the seed into another face, silently
///   re-seating the room, or into a wall, deleting it.
///
/// The name TEXT is found among the room's own leaves at each call: grips
/// are built at selection-change and document-change rate, and a drag's
/// calls at pointer-move rate, never per frame. [preview] reuses the state
/// it computed for the grip being dragged.
final class RoomGrips implements ObjectGripProvider {
  RoomGrips({required this.aperture});

  /// The world radius about the pole within which a drop returns the label
  /// to auto, read at each drag event.
  final double Function() aperture;

  _Label? _dragging;
  DraftDocument? _draggingDocument;
  Grip? _draggingGrip;

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    final s = _Label.of(d, group);
    if (s == null) return const [];
    return [Grip(GripRole.stretch, 0, s.anchorW.x, s.anchorW.y)];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final s = _Label.of(d, group);
    if (s == null) return null;
    if (world.x == s.anchorW.x && world.y == s.anchorW.y) return null;
    final next = s.labelAt(world, aperture());
    if (next == s.params.label) return null;
    return SetComponentCommand<RoomParams>(
        group, s.params.copyWith(label: next));
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    if (!identical(d, _draggingDocument) || !identical(grip, _draggingGrip)) {
      _dragging = _Label.of(d, group);
      _draggingDocument = d;
      _draggingGrip = grip;
    }
    final s = _dragging;
    if (s == null) return const [];
    final next = s.labelAt(world, aperture());
    if (next == null) return const [];
    final (dx, dy) = next;
    return [
      (
        EntityKind.line,
        linePayload(
            s.poleW, s.toWorld.transformPoint(s.poleL + Vector2(dx, dy))),
      ),
    ];
  }

  /// False for a room (R-22); true for any other group.
  @override
  bool movable(DraftDocument d, Handle group) =>
      d.components.get<RoomParams>(group) == null;
}

/// One room's label frames, as the document draws it now.
final class _Label {
  _Label._(this.params, this.toWorld, this.anchorW)
      : toLocal = toWorld.invert() {
    poleL = toLocal.transformPoint(anchorW) - _offsetOf(params);
    poleW = toWorld.transformPoint(poleL);
  }

  /// [group]'s label frames; null when it is not a room, or has no name
  /// label (a room from a file that never regenerated), or its anchor is
  /// not finite.
  static _Label? of(DraftDocument d, Handle group) {
    final p = d.components.get<RoomParams>(group);
    if (p == null) return null;
    final q = _nameInsertion(d, group);
    if (q == null) return null;
    final toWorld = d.tree.accumulatedTransform(group);
    final hNameW = kRoomNamePaperMm * _pageOf(d).scaleDenominator;
    final anchorW =
        toWorld.transformPoint(q) - Vector2(0, kRoomLineOffset * hNameW);
    if (!anchorW.x.isFinite || !anchorW.y.isFinite) return null;
    return _Label._(p, toWorld, anchorW);
  }

  final RoomParams params;
  final Transform2 toWorld, toLocal;

  /// The grip: the labels' anchor, world.
  final Vector2 anchorW;

  /// The pole of inaccessibility the anchor is offset from, local and
  /// world.
  late final Vector2 poleL, poleW;

  /// The label offset a drop at [pW] stores: null within [apertureW] of
  /// the pole, in world; otherwise `toLocal(pW) − pole_l`.
  (double, double)? labelAt(Vector2 pW, double apertureW) {
    if ((pW - poleW).length <= apertureW) return null;
    final l = toLocal.transformPoint(pW) - poleL;
    return (l.x, l.y);
  }

  /// The name TEXT's stored insertion point, local: the first of the
  /// room's TEXT leaves in handle order (D9, D18: the name, then the area).
  static Vector2? _nameInsertion(DraftDocument d, Handle group) {
    final e = d.entities;
    Handle? best;
    int bestSlot = -1;
    for (final slot in e.liveSlots) {
      if (e.ownerAt(slot) != group || e.kindAt(slot) != EntityKind.text) {
        continue;
      }
      final h = e.handleAt(slot);
      if (best == null || h.value < best.value) {
        best = h;
        bestSlot = slot;
      }
    }
    if (best == null) return null;
    final c = d.geometry.read(e.geomIndexAt(bestSlot)).coords;
    return Vector2(c[0], c[1]);
  }

  /// The page the room reads: the root's, or the app's opening page (R-14).
  static PageComponent _pageOf(DraftDocument d) =>
      (d.components.isRegistered<PageComponent>()
          ? d.components.get<PageComponent>(d.rootHandle)
          : null) ??
      _defaultPage;

  static final PageComponent _defaultPage = PageComponent();

  /// [p]'s label offset, local: `(0, 0)` when auto or not finite, as the
  /// room draws it (D2).
  static Vector2 _offsetOf(RoomParams p) => switch (p.label) {
        (final dx, final dy) when dx.isFinite && dy.isFinite => Vector2(dx, dy),
        _ => Vector2.zero(),
      };
}
