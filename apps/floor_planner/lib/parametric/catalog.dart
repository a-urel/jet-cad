import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'box.dart';
import 'opening.dart';
import 'room.dart';
import 'separator.dart';
import 'wall.dart';

/// The floor planner's parametric types (spec 07 D1, 08 D1): the Box, the
/// Wall and the Opening. A box and a wall may be neighbours; each type's
/// `generate` ignores the other's parameters. An opening is nobody's
/// neighbour: it relates to its host wall by reference (08 D2).
final ParametricCatalog parametricCatalog = ParametricCatalog()
  ..register<BoxParams>(
      BoxParams.componentTypeId, BoxParams.fromJson, const BoxType())
  ..register<WallParams>(
      WallParams.componentTypeId, WallParams.fromJson, const WallType())
  ..register<OpeningParams>(OpeningParams.componentTypeId,
      OpeningParams.fromJson, const OpeningType())
  // SPIKE 10: the separator and the room.
  ..register<SeparatorParams>(SeparatorParams.componentTypeId,
      SeparatorParams.fromJson, const SeparatorType())
  ..register<RoomParams>(
      RoomParams.componentTypeId, RoomParams.fromJson, const RoomType());

/// Builds and installs the document's parametric system.
ParametricSystem installParametric(DraftDocument doc) =>
    ParametricSystem(doc, parametricCatalog)..install();
