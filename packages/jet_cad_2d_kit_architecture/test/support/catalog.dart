// The kit tests' engine catalog (spec 3a "Tests": every type's generate
// through the engine's ParametricSystem): today's global parametricCatalog
// and installParametric (jet_cad_floor_plan/lib/src/parametric/
// catalog.dart:27-39, :64-65) for the kit's own tests. The kit's raw types
// (no plan guard), under their ArchitectureTypes ids, registered in
// today's order: box, wall, opening, separator, room, dimension (one line
// each, below).
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/src/box/box.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room.dart';
import 'package:jet_cad_2d_kit_architecture/src/separator/separator.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';

final ParametricCatalog _testCatalog = ParametricCatalog()
  ..register<BoxParams>(
      BoxParams.componentTypeId, BoxParams.fromJson, const BoxType())
  ..register<WallParams>(
      WallParams.componentTypeId, WallParams.fromJson, const WallType())
  ..register<OpeningParams>(OpeningParams.componentTypeId,
      OpeningParams.fromJson, const OpeningType())
  ..register<SeparatorParams>(SeparatorParams.componentTypeId,
      SeparatorParams.fromJson, const SeparatorType())
  ..register<RoomParams>(
      RoomParams.componentTypeId, RoomParams.fromJson, const RoomType())
  ..register<DimensionParams>(DimensionParams.componentTypeId,
      DimensionParams.fromJson, const DimensionType());

/// The kit tests' catalog (ruling R-P13): the one instance above, so every
/// call sees every registration the type tasks append to its cascade.
ParametricCatalog testCatalog() => _testCatalog;

/// Builds and installs [doc]'s parametric system over [testCatalog].
ParametricSystem installParametric(DraftDocument doc) =>
    ParametricSystem(doc, testCatalog())..install();
