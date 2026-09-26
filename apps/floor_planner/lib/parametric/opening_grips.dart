import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'opening.dart';
import 'opening_geometry.dart';
import 'wall.dart';

/// An opening's slide grip (spec 08 D16, D15), through the render layer's
/// object grip seam.
///
/// - **The grip:** one `stretch` grip at the opening's **drawn** centre on
///   its host's centreline, in world: its cut's centre (D8), or its stored
///   centre when it is no-fit.
/// - **The drag** takes the point the select tool has already resolved
///   through its snap chain (Ruling 08-15) and:
///   1. projects it onto the host's centreline, in the host's local space;
///   2. applies the host's edge snaps ([edgeSnap]) while [edgeAperture]
///      gives an aperture (object snap on): the candidates are the host's
///      stretch ends and its other openings' drawn cuts, as the document
///      draws them now;
///   3. stores the centre of the cut the opening would get there (D8, D14's
///      interpretation): the projected centre where it fits,
///      [storedCentreOf] where it had to be clamped into a stretch, and the
///      projection clamped to `[0, L]` where it fits nowhere;
///   4. returns one `SetComponentCommand<OpeningParams>`, or null when the
///      centre to store is the stored one, or within `wallJoin.linear` of
///      it while the opening is not drawn clamped now. A clamped one (by an
///      ulp, from a file or an older rewrite) is re-seated where it is
///      drawn by any drag, even onto its own edge (Task 11 review I1).
/// - **The preview:** the would-be cut's two jamb lines across the band, in
///   world; nothing when it would be no-fit.
/// - **Not movable** (D16): the select tool neither moves nor rotates an
///   opening; the slide grip is how it moves.
///
/// The host's layout and openings come from the document adapter
/// ([wallsInDocument], Ruling 08-8), computed at each call: grips are built
/// at selection-change and document-change rate, and a drag's calls at
/// pointer-move rate, never per frame.
final class OpeningGrips implements ObjectGripProvider {
  /// [edgeAperture] returns the snap aperture in world, or null to turn edge
  /// snaps off (Ruling 08-15); by default they are off.
  OpeningGrips({double? Function()? edgeAperture})
      : edgeAperture = edgeAperture ?? _off;

  static double? _off() => null;

  /// The world aperture of D15's edge snaps, read at each drag event; null:
  /// no edge snap.
  final double? Function() edgeAperture;

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    final s = _Slide.of(d, group);
    if (s == null) return const [];
    final c = s.cut;
    final u = c == null ? s.params.position : (c.a + c.b) / 2;
    if (!u.isFinite) return const [];
    final w = s.world(u, 0);
    return [Grip(GripRole.stretch, 0, w.x, w.y)];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final s = _Slide.of(d, group);
    if (s == null) return null;
    final placed = s.place(world, edgeAperture());
    final p = s.params;
    if (placed.centre == p.position) return null;
    // Within the tolerance a drag changes nothing, unless the opening is
    // drawn clamped now: then the drag re-seats it where it is drawn.
    if ((placed.centre - p.position).abs() <= wallJoin.linear &&
        s.cut?.clamped != true) {
      return null;
    }
    return SetComponentCommand<OpeningParams>(
        group, p.copyWith(position: placed.centre));
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final s = _Slide.of(d, group);
    if (s == null) return const [];
    final cut = s.place(world, edgeAperture()).cut;
    if (cut == null) return const [];
    final f = s.layout.frame;
    return [
      for (final u in [cut.a, cut.b])
        (
          EntityKind.line,
          linePayload(s.world(u, f.lOff), s.world(u, f.rOff)),
        ),
    ];
  }

  /// False for an opening (spec 08 D16); true for any other group.
  @override
  bool movable(DraftDocument d, Handle group) =>
      d.components.get<OpeningParams>(group) == null;
}

/// One opening on its host, as the document draws it now.
final class _Slide {
  _Slide._(this.params, this.layout, this.toWorld, this.openings, this.index,
      this.cuts)
      : toLocal = toWorld.invert();

  /// [group]'s slide state; null when it is not a live opening on a live,
  /// non-degenerate wall.
  static _Slide? of(DraftDocument d, Handle group) {
    final p = d.components.get<OpeningParams>(group);
    if (p == null) return null;
    final walls = wallsInDocument(d, p.host);
    if (walls == null) return null;
    final layout = layoutOf(walls.host, walls.walls);
    if (layout == null) return null;
    final openings = openingsInDocument(d, p.host);
    final i = openings.indexWhere((o) => o.$1 == group);
    if (i < 0) return null;
    final placed = cutsOf(layout.frame, layout.stretches, [
      for (final (_, o) in openings) (o.position, o.width),
    ]);
    return _Slide._(p, layout, walls.host.toWorld, openings, i, placed.cuts);
  }

  final OpeningParams params;
  final HostLayout layout;
  final Transform2 toWorld, toLocal;

  /// The host's openings, ascending by handle; this one is at [index].
  final List<(Handle, OpeningParams)> openings;
  final int index;

  /// Each of [openings]' cuts as drawn now (null: no-fit, D8).
  final List<Cut?> cuts;

  /// This opening's cut as drawn now.
  Cut? get cut => cuts[index];

  /// The world point [u] along the host's centreline and [off] along its
  /// left normal.
  Vector2 world(double u, double off) =>
      toWorld.transformPoint(layout.frame.at(u, off));

  /// Where a drag to [world] puts this opening (spec 08 D16): the centre to
  /// store and the cut it gets there (null: no-fit). [apertureWorld] null:
  /// no edge snap.
  ({double centre, Cut? cut}) place(Vector2 world, double? apertureWorld) {
    final f = layout.frame;
    final w = params.width;
    var u = f.uOf(toLocal.transformPoint(world));
    if (apertureWorld != null) {
      final v = edgeSnap(
          layout.stretches,
          [
            for (final (j, c) in cuts.indexed)
              if (j != index && c != null) (c.a, c.b),
          ],
          u,
          w,
          // In the host's local units along its centreline (as the tools).
          apertureWorld / toWorld.transformDirection(f.d).length);
      if (v != null) u = v;
    }
    final cut = _cutAt(u);
    if (cut == null) {
      final c = u < 0 ? 0.0 : (u > f.len ? f.len : u);
      return (centre: c, cut: null);
    }
    if (!cut.clamped) return (centre: u, cut: cut);
    final c = storedCentreOf(layout.stretches, cut, w);
    return (centre: c, cut: _cutAt(c));
  }

  /// This opening's cut (D8) centred at [c], the host's other openings where
  /// they are, admitted in ascending handle order.
  Cut? _cutAt(double c) => cutsOf(layout.frame, layout.stretches, [
        for (final (j, (_, o)) in openings.indexed)
          j == index ? (c, o.width) : (o.position, o.width),
      ]).cuts[index];
}
