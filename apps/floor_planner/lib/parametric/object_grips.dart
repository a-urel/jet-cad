import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'opening.dart';
import 'opening_grips.dart';
import 'wall.dart';
import 'wall_grips.dart';

/// The shell's one object grip provider (spec 08 D16): it dispatches by the
/// group's component.
///
/// - `WallParams` → [walls] (07 D11's end grips, 08 D13);
/// - `OpeningParams` → [openings] (the slide grip);
/// - anything else → no grips, no drag and no preview.
///
/// [movable] is false for an opening, which the select tool neither moves
/// nor rotates, and true for every other group.
final class ObjectGrips implements ObjectGripProvider {
  /// [edgeAperture] is the slide grip's edge-snap aperture in world, or null
  /// with object snap off (Ruling 08-15).
  ObjectGrips({required double? Function() edgeAperture})
      : openings = OpeningGrips(edgeAperture: edgeAperture);

  final WallGrips walls = WallGrips();
  final OpeningGrips openings;

  ObjectGripProvider? _of(DraftDocument d, Handle group) =>
      d.components.get<WallParams>(group) != null
          ? walls
          : d.components.get<OpeningParams>(group) != null
              ? openings
              : null;

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) =>
      _of(d, group)?.gripsOf(d, group) ?? const [];

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      _of(d, group)?.drag(d, group, grip, world);

  @override
  List<(EntityKind, GeometryPayload)> preview(
          DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      _of(d, group)?.preview(d, group, grip, world) ?? const [];

  @override
  bool movable(DraftDocument d, Handle group) =>
      d.components.get<OpeningParams>(group) == null;
}
