// The wall as the kit declares it (spec 3a C3.2): its plan type (the
// engine type, its grips, its thickness and justification fields) and its
// tool (letter W, the settings the panel edits while the tool is active).
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' show LucideIcons;

import '../ids.dart';
import '../live.dart';
import 'wall.dart';
import 'wall_bands.dart';
import 'wall_grips.dart';
import 'wall_tool.dart';

/// [t], when a wall may have it ([isWallThickness]: strict above
/// `wallJoin.linear`, at most [kWallMaxThickness]); else an
/// [ArgumentError], which the panel takes as a refusal (today's
/// `selection_panel.dart:412-414`).
double _thickness(double t) => isWallThickness(t)
    ? t
    : throw ArgumentError.value(t, 'thickness', 'is not a wall thickness');

/// The wall's plan type: thickness and justification, each needing the
/// `reshape` permission (today's `_capable`, `selection_panel.dart:380-389`).
final PlanType<WallParams> wallPlanType = PlanType<WallParams>(
  id: ArchitectureTypes.wall,
  fromJson: WallParams.fromJson,
  parametric: const WallType(),
  grips: (services) => WallGrips(live: liveTypesOf(services)),
  properties: [
    LengthProperty<WallParams>(
        id: 'thickness',
        read: (p) => p.thickness,
        write: (p, t) => p.copyWith(thickness: _thickness(t)),
        gate: PlanGate.reshape),
    ChoiceProperty<WallParams, Justification>(
        id: 'justification',
        values: Justification.values,
        read: (p) => p.justification,
        write: (p, j) => p.copyWith(justification: j),
        gate: PlanGate.reshape),
  ],
);

/// The Wall tool, W: a chain of walls drawn with its settings, which the
/// panel edits while it is active (no gate: a tool's settings are always
/// editable, today's `_capable`). It consults no lock and no layer rule
/// (today's).
final PlanTool wallPlanTool = PlanTool(
  id: ArchitectureTools.wall,
  icon: LucideIcons.brickWall,
  letter: 'W',
  needs: const {
    Capability.structure,
    Capability.components,
    Capability.geometry,
  },
  settings: PlanToolSettings<WallSettings>(
    initial: const WallSettings(),
    specs: [
      LengthProperty<WallSettings>(
          id: 'thickness',
          read: (s) => s.thickness,
          write: (s, t) => s.copyWith(thickness: _thickness(t))),
      ChoiceProperty<WallSettings, Justification>(
          id: 'justification',
          values: Justification.values,
          read: (s) => s.justification,
          write: (s, j) => s.copyWith(justification: j)),
    ],
  ),
  create: (services) => WallTool(
      () => services.settingsOf<WallSettings>(ArchitectureTools.wall),
      wallBandsOf(services)),
);
