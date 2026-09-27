import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'opening.dart';
import 'opening_grips.dart';
import 'room.dart';
import 'room_grips.dart';
import 'room_inputs.dart';
import 'separator.dart';
import 'separator_grips.dart';
import 'wall.dart';
import 'wall_grips.dart';

/// The shell's one object grip provider (spec 08 D16): it dispatches by the
/// group's component.
///
/// - `WallParams` → [walls] (07 D11's end grips, 08 D13);
/// - `OpeningParams` → [openings] (the slide grip);
/// - `RoomParams` → [rooms] (spec 10 D21's label grip);
/// - `SeparatorParams` → [separators] (spec 10 D21's end grips), when the
///   shell handed over its `RoomInputs`;
/// - anything else → no grips, no drag and no preview.
///
/// [movable] is the dispatched provider's answer: [openings] says false
/// for an opening and [rooms] for a room, which the select tool neither
/// moves nor rotates, and [walls] and [separators] true; a group with none
/// of these components is movable. One rule per provider, not a copy of it
/// here (Task 14 F2).
final class ObjectGrips implements ObjectGripProvider {
  /// [edgeAperture] is the slide grip's edge-snap aperture in world, or null
  /// with object snap off (Ruling 08-15).
  ///
  /// [labelAperture] is the world radius about a room's pole within which
  /// its label grip returns the label to auto, whatever F3 says (Ruling
  /// 10-17); by default 0, a drop exactly on the pole.
  ///
  /// [roomInputs] and [objectSnap] drive the separator grips' band trimming
  /// (spec 10 D20, D21); without [roomInputs] a separator has no grips.
  /// [objectSnap] defaults to on.
  ObjectGrips(
      {required double? Function() edgeAperture,
      double Function()? labelAperture,
      RoomInputs? roomInputs,
      bool Function()? objectSnap})
      : openings = OpeningGrips(edgeAperture: edgeAperture),
        rooms = RoomGrips(aperture: labelAperture ?? _noAperture),
        separators = roomInputs == null
            ? null
            : SeparatorGrips(
                inputs: roomInputs, objectSnap: objectSnap ?? _snapOn);

  static double _noAperture() => 0;
  static bool _snapOn() => true;

  final WallGrips walls = WallGrips();
  final OpeningGrips openings;
  final RoomGrips rooms;
  final SeparatorGrips? separators;

  ObjectGripProvider? _of(DraftDocument d, Handle group) {
    final c = d.components;
    if (c.get<WallParams>(group) != null) return walls;
    if (c.get<OpeningParams>(group) != null) return openings;
    if (c.get<RoomParams>(group) != null) return rooms;
    if (c.get<SeparatorParams>(group) != null) return separators;
    return null;
  }

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
      _of(d, group)?.movable(d, group) ?? true;
}
