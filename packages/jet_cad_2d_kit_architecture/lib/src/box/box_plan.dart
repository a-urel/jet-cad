// The box as the kit declares it (spec 3a C3.1): its PlanType, whose two
// properties are lengths above zero (today's panel rule,
// jet_cad_floor_plan/lib/src/selection_panel.dart:415-417), refused in
// write and gated by reshape (:384-390); and its PlanTool, B (today's
// palette entry, planner_shell.dart:546-552). No grips, as today.
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' show LucideIcons;

import '../ids.dart';
import 'box.dart';
import 'box_tool.dart';

/// [v] when it is above zero; otherwise an [ArgumentError], which the
/// property panel takes as a silent refusal (the field shows the stored
/// value). The field has already refused a value that is not finite.
double _positive(double v) =>
    v > 0 ? v : throw ArgumentError.value(v, 'length', 'must be above 0');

/// The box's type: width and height, each a length above zero.
final PlanType<BoxParams> boxPlanType = PlanType<BoxParams>(
  id: ArchitectureTypes.box,
  fromJson: BoxParams.fromJson,
  parametric: const BoxType(),
  properties: [
    LengthProperty<BoxParams>(
        id: 'width',
        read: (p) => p.width,
        write: (p, v) => p.copyWith(width: _positive(v)),
        gate: PlanGate.reshape),
    LengthProperty<BoxParams>(
        id: 'height',
        read: (p) => p.height,
        write: (p, v) => p.copyWith(height: _positive(v)),
        gate: PlanGate.reshape),
  ],
);

/// The Box tool: two opposite corners, one box.
final PlanTool boxPlanTool = PlanTool(
  id: ArchitectureTools.box,
  icon: LucideIcons.squareDashed,
  letter: 'B',
  needs: const {
    Capability.structure,
    Capability.components,
    Capability.geometry,
  },
  create: (_) => BoxTool(),
);
