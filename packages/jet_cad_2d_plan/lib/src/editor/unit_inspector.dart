// The host's unit inspector (spec 2b S4 "The unit inspector"; today's
// _TableInspector, jet_cad_floor_plan/lib/src/planner_shell.dart:1626-1700,
// and FloorPlanView._inspect, host/floor_plan_view.dart:622-643): built under
// the property panel for exactly one selected placed unit whose label no
// other unit has; again when the unit shown changes (a selection change,
// frame-safe), at each change of the plan while one is shown (the detail is
// read fresh), and at each host rebuild. A hover, the camera and a selection
// change that keeps the unit build nothing.
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Handle;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show SelectionController;

import '../controller/plan_controller.dart';
import '../panels/frame_safe_relay.dart';
import '../units/unit_detail.dart';

/// The host's inspector under the property panel: [builder] for the one
/// selected placed unit whose label no other unit has, nothing otherwise.
class UnitInspector extends StatefulWidget {
  const UnitInspector(
      {super.key, required this.controller, required this.builder});

  final PlanController controller;
  final Widget? Function(BuildContext context, PlanUnitDetail unit) builder;

  @override
  State<UnitInspector> createState() => _UnitInspectorState();
}

class _UnitInspectorState extends State<UnitInspector> {
  /// The unit shown; null for none.
  Handle? _shown;
  SelectionController? _selection;
  FrameSafeRelay? _relay;

  @override
  void initState() {
    super.initState();
    _bind();
    widget.controller.revision.addListener(_onDocument);
    _shown = _inspected();
  }

  @override
  void didUpdateWidget(UnitInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.revision.removeListener(_onDocument);
      widget.controller.revision.addListener(_onDocument);
    }
    _bind();
    _shown = _inspected();
  }

  @override
  void dispose() {
    widget.controller.revision.removeListener(_onDocument);
    _unbind();
    super.dispose();
  }

  /// The relay over the controller's current selection (a new one per
  /// document).
  void _bind() {
    final selection = widget.controller.selection;
    if (identical(selection, _selection)) return;
    _unbind();
    _selection = selection;
    _relay = FrameSafeRelay(selection)..addListener(_onSelection);
  }

  void _unbind() {
    _relay
      ?..removeListener(_onSelection)
      ..dispose();
    _relay = null;
    _selection = null;
  }

  /// The selection's one key when it is a root key on a placed unit.
  Handle? _inspected() {
    final c = widget.controller;
    final keys = c.selection.keys;
    if (keys.length != 1) return null;
    final key = keys.single;
    if (key.chain.isNotEmpty) return null;
    return c.unitIndex[key.target]?.generated == false ? key.target : null;
  }

  void _onSelection() {
    final next = _inspected();
    if (next == _shown) return;
    setState(() => _shown = next);
  }

  void _onDocument() {
    _bind();
    final next = _inspected();
    if (next == null && _shown == null) return;
    setState(() => _shown = next);
  }

  /// [instance]'s fresh detail, or null for an unlabelled unit or a label
  /// another unit shares (today's _inspect: the label names no one unit,
  /// and setUnitData refuses it).
  PlanUnitDetail? _detail(Handle instance) {
    final c = widget.controller;
    final details = c.unitDetails;
    final i = c.unitDetailInstances.indexOf(instance);
    if (i < 0) return null;
    final detail = details[i];
    final label = detail.unit.label;
    if (label == null) return null;
    for (var j = 0; j < details.length; j++) {
      if (j != i && details[j].unit.label == label) return null;
    }
    return detail;
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final detail = shown == null ? null : _detail(shown);
    if (detail == null) return const SizedBox.shrink();
    return widget.builder(context, detail) ?? const SizedBox.shrink();
  }
}
