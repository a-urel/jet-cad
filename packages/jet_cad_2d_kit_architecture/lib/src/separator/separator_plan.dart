// The separator as the kit declares it (spec 3a C3.4): its PlanType -- the
// type Task 16 ported, not exported (today's exportOmitOwners,
// jet_cad_floor_plan/lib/src/export/export_bytes.dart:28-29), its grips the
// two band-trimmed ends over the kit's one RoomInputs and the plan's F3 --
// and its PlanTool, S (planner_shell.dart:588-594), which band-trims
// through the same RoomInputs. No properties: today's panel has no
// separator section.
import 'package:flutter/material.dart' show Icons;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../ids.dart';
import '../room/room_inputs.dart';
import 'separator.dart';
import 'separator_grips.dart';
import 'separator_tool.dart';

/// The separator's type: drawn DASHED, an input to rooms, left out of
/// every export.
final PlanType<SeparatorParams> separatorPlanType = PlanType<SeparatorParams>(
  id: ArchitectureTypes.separator,
  fromJson: SeparatorParams.fromJson,
  parametric: const SeparatorType(),
  grips: (s) =>
      SeparatorGrips(inputs: roomInputsOf(s), objectSnap: () => s.objectSnap),
  exported: false,
);

/// The Separator tool: two clicks per separator, band-trimmed.
final PlanTool separatorPlanTool = PlanTool(
  id: ArchitectureTools.separator,
  icon: Icons.horizontal_rule,
  letter: 'S',
  needs: const {
    Capability.structure,
    Capability.components,
    Capability.geometry,
  },
  create: (s) => SeparatorTool(roomInputsOf(s)),
);
