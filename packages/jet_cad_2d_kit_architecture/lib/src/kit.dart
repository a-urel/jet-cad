// The architecture kit's descriptor (spec 3a C2): its types, tools,
// attachment providers, symbols, words and prepare. Each type task adds its
// own (Tasks 10-25); the tools keep today's palette order (box, wall, door,
// window, gap, room, separator, dimension; planner_shell.dart:546-601).
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import 'box/box_plan.dart';
import 'opening/opening_plan.dart';
import 'room/room_plan.dart';
import 'separator/separator_plan.dart';
import 'separator_linetype.dart';
import 'wall/wall_plan.dart';
import 'words/words.dart';

/// The architecture kit: a host passes it to the plan library,
/// `PlanController(kits: [architectureKit])`.
final PlanKit architectureKit = PlanKit(
  id: 'architecture',
  version: '0.1.0',
  types: [
    boxPlanType,
    wallPlanType,
    openingPlanType,
    separatorPlanType,
    roomPlanType,
  ],
  tools: [
    boxPlanTool,
    wallPlanTool,
    doorPlanTool,
    windowPlanTool,
    gapPlanTool,
    separatorPlanTool,
  ],
  names: architectureNames,
  prepare: ensureDashedLinetype,
);
