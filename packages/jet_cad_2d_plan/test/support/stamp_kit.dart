// Kits of tools only, for the keyboard and the palette (2a Task 16).
// stamp.star asks for B (free); stamp.clash for L (plan.line's); stamp.fill
// for "f" (F is Fill's: asked in lower case, so the check runs on the upper
// case); stamp.none for no letter. late.star, in a later kit, asks for B,
// which stamp.star already has. Turkish names one tool; German names none
// (the English fallback).
import 'package:flutter/material.dart' show Icons;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show LineTool;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

const Set<Capability> _draws = {Capability.geometry};

final PlanKit stampKit = PlanKit(
  id: 'stamp',
  version: '1.0.0',
  tools: [
    PlanTool(
        id: 'stamp.star',
        icon: Icons.star,
        letter: 'B',
        needs: _draws,
        create: (_) => LineTool()),
    PlanTool(
        id: 'stamp.clash',
        icon: Icons.warning_amber,
        letter: 'L',
        needs: _draws,
        create: (_) => LineTool()),
    PlanTool(
        id: 'stamp.fill',
        icon: Icons.format_color_fill,
        letter: 'f',
        needs: _draws,
        create: (_) => LineTool()),
    PlanTool(
        id: 'stamp.none',
        icon: Icons.circle_outlined,
        needs: _draws,
        create: (_) => LineTool()),
  ],
  names: const KitNames({
    'en': {
      'tool:stamp.star': 'Star',
      'tool:stamp.clash': 'Clash',
      'tool:stamp.fill': 'Filler',
      'tool:stamp.none': 'Plain',
    },
    'tr': {'tool:stamp.star': 'Yıldız'},
  }),
);

final PlanKit lateKit = PlanKit(
  id: 'late',
  version: '1.0.0',
  tools: [
    PlanTool(
        id: 'late.star',
        icon: Icons.star_border,
        letter: 'B',
        needs: _draws,
        create: (_) => LineTool()),
  ],
  names: const KitNames({
    'en': {'tool:late.star': 'Late star'},
  }),
);
