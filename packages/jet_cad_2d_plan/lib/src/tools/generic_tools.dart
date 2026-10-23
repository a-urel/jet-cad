// Spec P1 "Reserved ids" and P2 "The keyboard" (Task 12): the plan
// library's own tools. plan.symbol is reserved here and built by Task 14;
// a kit's tools follow in the palette (Task 16).
import 'package:flutter/foundation.dart' show ValueListenable, immutable;
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// The plan library's reserved tool ids (spec P1).
abstract final class PlanToolIds {
  static const String select = 'plan.select';
  static const String line = 'plan.line';
  static const String polyline = 'plan.polyline';
  static const String rectangle = 'plan.rectangle';
  static const String circle = 'plan.circle';
  static const String arc = 'plan.arc';
  static const String text = 'plan.text';
  static const String symbol = 'plan.symbol';

  static const List<String> all = [
    select,
    line,
    polyline,
    rectangle,
    circle,
    arc,
    text,
    symbol,
  ];

  /// What a symbol placement commits (today's `kSymbolPlacementNeeds`,
  /// `symbol_panel.dart:28-32`): the definition copy, its leaves, its
  /// `jetcad.symbol` component.
  static const Set<Capability> symbolNeeds = {
    Capability.structure,
    Capability.geometry,
    Capability.components,
  };
}

/// One generic tool as the palette and the keyboard see it.
@immutable
final class GenericTool {
  const GenericTool({
    required this.id,
    required this.icon,
    required this.letter,
    required this.needs,
    this.fills = false,
  });

  final String id;
  final IconData icon;

  /// Today's letter (spec P2: V L P R C A T).
  final String letter;

  /// What the tool's commits need (`PlanTool.needs`' meaning).
  final Set<Capability> needs;

  /// Whether the Fill toggle applies to it.
  final bool fills;
}

/// The generic tools in palette order (today's rows for them,
/// `planner_shell.dart:517-623`).
const List<GenericTool> genericTools = [
  GenericTool(
      id: PlanToolIds.select,
      icon: Icons.north_west,
      letter: 'V',
      needs: <Capability>{}),
  GenericTool(
      id: PlanToolIds.line,
      icon: Icons.horizontal_rule,
      letter: 'L',
      needs: {Capability.geometry}),
  GenericTool(
      id: PlanToolIds.polyline,
      icon: Icons.polyline,
      letter: 'P',
      needs: {Capability.geometry},
      fills: true),
  GenericTool(
      id: PlanToolIds.rectangle,
      icon: Icons.crop_square,
      letter: 'R',
      needs: {Capability.geometry},
      fills: true),
  GenericTool(
      id: PlanToolIds.circle,
      icon: Icons.circle_outlined,
      letter: 'C',
      needs: {Capability.geometry},
      fills: true),
  GenericTool(
      id: PlanToolIds.arc,
      icon: Icons.looks,
      letter: 'A',
      needs: {Capability.geometry}),
  GenericTool(
      id: PlanToolIds.text,
      icon: Icons.title,
      letter: 'T',
      needs: {Capability.geometry}),
];

/// One document's generic tools: [select] and every tool by id, in
/// [genericTools] order.
final class GenericToolSet {
  GenericToolSet._(this.select, this.byId);

  final SelectTool select;
  final Map<String, Tool> byId;

  void dispose() {
    for (final tool in byId.values) {
      tool.dispose();
    }
  }
}

/// Builds the generic tools over [gates] (the select tool's), [fill] (the
/// polyline's, the rectangle's and the circle's), [moveResolver] (null
/// until Task 14 injects plan.symbol's) and [moveAdjuster] (the alignment
/// guides' seam; null: today's move).
GenericToolSet buildGenericTools({
  required SelectGates gates,
  required ValueListenable<bool> fill,
  MoveResolver? moveResolver,
  MoveAdjuster? moveAdjuster,
}) {
  final select = SelectTool(
      moveResolver: moveResolver, gates: gates, moveAdjuster: moveAdjuster);
  return GenericToolSet._(select, {
    PlanToolIds.select: select,
    PlanToolIds.line: LineTool(),
    PlanToolIds.polyline: PolylineTool(fill: fill),
    PlanToolIds.rectangle: RectangleTool(fill: fill),
    PlanToolIds.circle: CircleTool(fill: fill),
    PlanToolIds.arc: ArcTool(),
    PlanToolIds.text: TextTool(),
  });
}
