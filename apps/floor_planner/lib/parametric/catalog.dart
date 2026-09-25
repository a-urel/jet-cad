import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'box.dart';
import 'wall.dart';

/// The floor planner's parametric types (spec 07 D1): the Box and the
/// Wall. They may be neighbours; each type's `generate` ignores the other's
/// parameters.
final ParametricCatalog parametricCatalog = ParametricCatalog()
  ..register<BoxParams>(
      BoxParams.componentTypeId, BoxParams.fromJson, const BoxType())
  ..register<WallParams>(
      WallParams.componentTypeId, WallParams.fromJson, const WallType());

/// Builds and installs the document's parametric system.
ParametricSystem installParametric(DraftDocument doc) =>
    ParametricSystem(doc, parametricCatalog)..install();
