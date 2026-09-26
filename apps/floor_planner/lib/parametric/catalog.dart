import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'box.dart';
import 'opening.dart';
import 'separator.dart';
import 'wall.dart';

/// The floor planner's parametric types (spec 07 D1, 08 D1, 10 D1): the
/// Box, the Wall, the Opening and the room Separator. A box and a wall may
/// be neighbours; each type's `generate` ignores the other's parameters. An
/// opening is nobody's neighbour: it relates to its host wall by reference
/// (08 D2). A separator is nobody's neighbour either (its reach is empty,
/// 10 D3): walls and separators relate to rooms by place (10 D16).
final ParametricCatalog parametricCatalog = ParametricCatalog()
  ..register<BoxParams>(
      BoxParams.componentTypeId, BoxParams.fromJson, const BoxType())
  ..register<WallParams>(
      WallParams.componentTypeId, WallParams.fromJson, const WallType())
  ..register<OpeningParams>(OpeningParams.componentTypeId,
      OpeningParams.fromJson, const OpeningType())
  ..register<SeparatorParams>(SeparatorParams.componentTypeId,
      SeparatorParams.fromJson, const SeparatorType());

/// Builds and installs the document's parametric system.
ParametricSystem installParametric(DraftDocument doc) =>
    ParametricSystem(doc, parametricCatalog)..install();
