// The dimension as a plan type (3a spec C3.6, C1.1): today's Dimension
// section (jet_cad_floor_plan/lib/src/selection_panel.dart:846-976) as
// property specs over the object, and the grips over the plan's services.
//
// - Value: the TEXT child's string as drawn, '—' without one (a broken
//   dimension, D15), read once per dimension and history state (today:
//   once per document change, :232-236, :851-864).
// - Kind: a choice; a change keeps the ends and the offset (R-27). Gated
//   by `reshape` (today's `_dimensionEditable`, :870-875: the host's
//   reshape, then the document's `components` and the type's geometry,
//   which the plan's panel checks for every type).
// - Axes: a linear dimension's group's world rotation, rounded to tenths
//   and normalised to (−180°, 180°], in the UI language's words and
//   decimal separator; omitted for aligned and below 0.05° (:901-916).
// - End 1, End 2: `Wall <hex>, start|end, <side>` or `Fixed` (:918-931).
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart' show Icons;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../ids.dart';
import '../live.dart';
import 'dimension.dart';
import 'dimension_grips.dart';
import 'dimension_tool.dart';

/// The dimension's plan type (Shared interfaces, spec C3.6).
final PlanType<DimensionParams> dimensionPlanType = PlanType<DimensionParams>(
  id: ArchitectureTypes.dimension,
  fromJson: DimensionParams.fromJson,
  parametric: const DimensionType(),
  grips: (s) => DimensionGrips(
      index: s.index, objectSnap: () => s.objectSnap, live: liveTypesOf(s)),
  properties: [
    TextDisplay<DimensionParams>(id: 'value', read: dimensionValueOf),
    ChoiceProperty<DimensionParams, DimKind>(
        id: 'kind',
        values: DimKind.values,
        read: (p) => p.kind,
        write: (p, kind) => p.copyWith(kind: kind),
        gate: PlanGate.reshape),
    TextDisplay<DimensionParams>(id: 'axes', read: dimensionAxesOf),
    TextDisplay<DimensionParams>(
        id: 'end-1', read: (p, o) => dimensionEndLine(p.a, o.words)),
    TextDisplay<DimensionParams>(
        id: 'end-2', read: (p, o) => dimensionEndLine(p.b, o.words)),
  ],
);

/// The Dimension tool (Shared interfaces, spec C3.6): letter I (today's,
/// `planner_shell.dart:595-601`), no settings, three clicks per dimension
/// (spec 11 D12). Its commit adds a group, its parameters and its layer:
/// `structure`, `components`, `geometry` (`dimension_tool.dart:311-315`).
final PlanTool dimensionPlanTool = PlanTool(
  id: ArchitectureTools.dimension,
  icon: Icons.straighten,
  letter: 'I',
  needs: const {
    Capability.structure,
    Capability.components,
    Capability.geometry,
  },
  create: (s) => DimensionTool(live: liveTypesOf(s)),
);

/// Every scan [dimensionValueOf] made of a document's entities. Tests read
/// the difference across calls: one per dimension shown and history state.
@visibleForTesting
int debugDimensionValueScans = 0;

/// The last value read, per document.
final class _ValueMemo {
  Handle? handle;
  int state = 0;
  String? text;
}

final Expando<_ValueMemo> _valueMemo = Expando<_ValueMemo>('dimension value');

/// The Value line (spec 11 D14, decision 13): [object]'s TEXT child's
/// stored string, exactly as drawn, or '—' when it has none (a broken
/// dimension generates no child, D7, D15). Read once per dimension and
/// `document.commands.stateId` (spec 3a C1.1): a wall edit or a page change
/// is a command and rewrites the string in place.
String? dimensionValueOf(DimensionParams p, PlanObject object) {
  final doc = object.document;
  final state = doc.commands.stateId;
  final memo = _valueMemo[doc] ??= _ValueMemo();
  if (memo.handle != object.handle || memo.state != state) {
    debugDimensionValueScans++;
    final entities = doc.entities;
    String? text;
    for (final slot in entities.liveSlots) {
      if (entities.ownerAt(slot) == object.handle &&
          entities.kindAt(slot) == EntityKind.text) {
        text = entities.textAt(slot);
        break;
      }
    }
    memo
      ..handle = object.handle
      ..state = state
      ..text = text;
  }
  return memo.text ?? '—';
}

/// The axes line (spec 11 D11, R-18), or null: for a linear kind whose
/// group's world rotation, `atan2(M.b, M.a)` in degrees, is at least 0.05°
/// either way (the number, not its printed string, S-8). Rounded to tenths
/// first and then normalised to (−180°, 180°], so −179.96° reads `180.0°`,
/// in [object]'s words with their decimal separator (spec 3a C1.6).
String? dimensionAxesOf(DimensionParams p, PlanObject object) {
  if (p.kind == DimKind.aligned) return null;
  final m = object.world;
  final angle = math.atan2(m.b, m.a) * 180 / math.pi;
  if (angle.abs() < 0.05) return null;
  var shown = double.parse(angle.toStringAsFixed(1));
  if (shown <= -180) shown += 360;
  final words = object.words;
  return words.text('text:architecture.axes-turned', {
    'degrees': shown.toStringAsFixed(1).replaceAll('.', words.decimalSeparator),
  });
}

/// An end line (spec 11 D14, R-28): for an attached end, its wall's handle
/// in hex, the start or end word for its `k` and the side's word (`Wall 1A,
/// end, left face`); the fixed word for a fixed end.
String dimensionEndLine(DimEnd end, PlanWords words) => switch (end) {
      FixedEnd() => words.word('text:architecture.end-fixed'),
      AttachedEnd(:final wall, :final k, :final side) =>
        words.text('text:architecture.end-on-wall', {
          'wall': wall.toHex(),
          'end': words.word(k == 0
              ? 'text:architecture.end-start'
              : 'text:architecture.end-end'),
          'side': words.word(switch (side) {
            WallSide.left => 'text:architecture.face-left',
            WallSide.centre => 'text:architecture.face-centre',
            WallSide.right => 'text:architecture.face-right',
          }),
        }),
    };
