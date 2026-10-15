// The engine's naming rule (ParametricCatalog.typeIdOf) over the kit's own
// raw parametric types, registered in today's order
// (jet_cad_floor_plan/lib/src/parametric/catalog.dart:27-39), for a hook
// that sees a document but no services (spec 3a C1.1: the opening's
// position range asks "is the host a wall"). Built from the raw
// registrations, not from `architectureKit.types`, so `kit.dart` is not
// imported (ruling R-P19). Only the naming rule is read: no hook of a type
// runs. Each type task appends its registration in today's order (Task 16
// the separator, 18 the room, 20 the dimension).
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'box/box.dart';
import 'opening/opening.dart';
import 'room/room.dart';
import 'separator/separator.dart';
import 'wall/wall.dart';

/// The kit's raw types, built at the first read.
final ParametricCatalog _naming = ParametricCatalog()
  ..register<BoxParams>(
      BoxParams.componentTypeId, BoxParams.fromJson, const BoxType())
  ..register<WallParams>(
      WallParams.componentTypeId, WallParams.fromJson, const WallType())
  ..register<OpeningParams>(OpeningParams.componentTypeId,
      OpeningParams.fromJson, const OpeningType())
  ..register<SeparatorParams>(SeparatorParams.componentTypeId,
      SeparatorParams.fromJson, const SeparatorType())
  ..register<RoomParams>(
      RoomParams.componentTypeId, RoomParams.fromJson, const RoomType());

/// The type id that names [group]'s object in [target] by the engine's own
/// rule over the kit's types (a root-level group, named by the last
/// registered type whose component it carries), or null when it names no
/// object of the kit. A frozen object still answers its id, as the plan's
/// catalog does (spec 3a C1.5).
String? kitTypeIdOf(CommandTarget target, Handle group) =>
    _naming.typeIdOf(target, group);
