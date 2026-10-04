import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'dimension.dart';
import 'dimension_grips.dart';
import 'live_objects.dart';
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
/// type that names the group's object ([_of]).
///
/// - `WallParams` → [walls] (07 D11's end grips, 08 D13);
/// - `OpeningParams` → [openings] (the slide grip);
/// - `RoomParams` → [rooms] (spec 10 D21's label grip);
/// - `SeparatorParams` → [separators] (spec 10 D21's end grips), when the
///   shell handed over its `RoomInputs`;
/// - `DimensionParams` → [dimensions] (spec 11 D13's offset grip and end
///   grips), when the shell handed over its `SpatialIndex`;
/// - anything else → no grips, no drag and no preview.
///
/// [movable] is the dispatched provider's answer: [openings] says false
/// for an opening and [rooms] for a room, which the select tool neither
/// moves nor rotates, and [walls], [separators] and [dimensions] true; a
/// group with none of these components is movable. One rule per provider,
/// not a copy of it here (Task 14 F2).
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
  ///
  /// [index] and [objectSnap] drive a dimension's end grips, which attach by
  /// position while F3 is on (spec 11 D13, D10); without [index] a
  /// dimension has no grips.
  ObjectGrips(
      {required double? Function() edgeAperture,
      double Function()? labelAperture,
      RoomInputs? roomInputs,
      SpatialIndex? index,
      bool Function()? objectSnap})
      : openings = OpeningGrips(edgeAperture: edgeAperture),
        rooms = RoomGrips(aperture: labelAperture ?? _noAperture),
        separators = roomInputs == null
            ? null
            : SeparatorGrips(
                inputs: roomInputs, objectSnap: objectSnap ?? _snapOn),
        dimensions = index == null
            ? null
            : DimensionGrips(index: index, objectSnap: objectSnap ?? _snapOn);

  static double _noAperture() => 0;
  static bool _snapOn() => true;

  final WallGrips walls = WallGrips();
  final OpeningGrips openings;
  final RoomGrips rooms;
  final SeparatorGrips? separators;
  final DimensionGrips? dimensions;

  /// The provider of the type that names [group]'s object (the engine's
  /// rule, `live_objects.dart`): a file's group carrying `WallParams` and
  /// `OpeningParams` is an opening, so it gets [openings]. At most one
  /// type names a group, so the order below does not matter. Null for a
  /// group that is no live object of these types.
  ObjectGripProvider? _of(DraftDocument d, Handle group) {
    if (isLiveObject<WallParams>(d, group)) return walls;
    if (isLiveObject<OpeningParams>(d, group)) return openings;
    if (isLiveObject<RoomParams>(d, group)) return rooms;
    if (isLiveObject<SeparatorParams>(d, group)) return separators;
    if (isLiveObject<DimensionParams>(d, group)) return dimensions;
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
