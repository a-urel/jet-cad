// The opening's plan type (spec 3a C3.3, C1.1, C1.7): today's selection
// panel's Opening section (jet_cad_floor_plan/lib/src/selection_panel.dart:
// 405-433, 754-758, 1035-1059, 1332-1371) as property specs over the
// object, and its slide grip over the plan's services. Task 15 adds the
// three opening tools here.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ObjectGripProvider;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../ids.dart';
import '../live.dart';
import '../type_naming.dart';
import '../wall/wall.dart';
import 'opening.dart';
import 'opening_grips.dart';

/// An opening's section title: its kind's tool word (today's `_titleOf`).
String openingTitle(OpeningParams o) => switch (o.kind) {
      OpeningKind.door => 'tool:${ArchitectureTools.door}',
      OpeningKind.window => 'tool:${ArchitectureTools.window}',
      OpeningKind.gap => 'tool:${ArchitectureTools.gap}',
    };

/// [w] as the width of an opening of [kind] (spec 08 D6: `isOpeningWidth`,
/// strict; a gap's above `4 × wallJoin.linear`), else an [ArgumentError],
/// which the panel turns into a revert. The type's width and the tools'
/// settings both write through it.
double openingWidthOf(OpeningKind kind, double w) {
  if (!isOpeningWidth(kind, w)) {
    throw ArgumentError.value(w, 'width', 'is no width a ${kind.name} takes');
  }
  return w;
}

/// Where [o]'s position may be (spec 3a C1.1; today's `_valid`,
/// `selection_panel.dart:425-430`): `[0, L]`, `L` its host's centreline
/// length in the host's own group-local space, when the engine names the
/// host a wall; null, refusing every position, when it does not (a box, a
/// group a later type names, a missing handle).
(double, double)? openingPositionRange(OpeningParams o, PlanObject object) {
  final doc = object.document;
  if (kitTypeIdOf(doc, o.host) != ArchitectureTypes.wall) {
    return null;
  }
  final host = doc.components.get<WallParams>(o.host)!;
  return (0, (host.end - host.start).length);
}

OpeningParams _flipHinge(OpeningParams o) => o.copyWith(
    hinge: o.hinge == HingeEnd.start ? HingeEnd.end : HingeEnd.start);

OpeningParams _flipSwing(OpeningParams o) => o.copyWith(
    swing: o.swing == SwingSide.left ? SwingSide.right : SwingSide.left);

bool _isDoor(OpeningParams o) => o.kind == OpeningKind.door;

/// The slide grip over [services] (today's shell factory,
/// `planner_shell.dart:649-652`): edge snaps at the snap aperture in world
/// while object snap is on.
ObjectGripProvider openingGripsOf(PlanServices services) => OpeningGrips(
    live: liveTypesOf(services),
    edgeAperture: () => services.objectSnap
        ? kSnapAperturePixels / services.camera.value.scale
        : null);

/// The opening (spec 3a C3.3): fields width, position, Flip hinge and Flip
/// swing (a door's), each needing `reshape`; titled by its kind.
final PlanType<OpeningParams> openingPlanType = PlanType<OpeningParams>(
  id: ArchitectureTypes.opening,
  fromJson: OpeningParams.fromJson,
  parametric: const OpeningType(),
  grips: openingGripsOf,
  title: openingTitle,
  properties: [
    LengthProperty<OpeningParams>(
        id: 'width',
        read: (o) => o.width,
        write: (o, w) => o.copyWith(width: openingWidthOf(o.kind, w)),
        gate: PlanGate.reshape),
    LengthProperty<OpeningParams>(
        id: 'position',
        read: (o) => o.position,
        write: (o, v) => o.copyWith(position: v),
        range: openingPositionRange,
        gate: PlanGate.reshape),
    ActionProperty<OpeningParams>(
        id: 'flip-hinge',
        apply: _flipHinge,
        visible: _isDoor,
        gate: PlanGate.reshape),
    ActionProperty<OpeningParams>(
        id: 'flip-swing',
        apply: _flipSwing,
        visible: _isDoor,
        gate: PlanGate.reshape),
  ],
);
