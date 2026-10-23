// The right column's switch on the selection (PlanEditor.contextualPanels):
// the same relay as ObjectInspector (a frame-safe selection relay, rebound
// at each change of the plan, since a plan opened anew brings a fresh
// selection), answering one bit: whether anything is selected.
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show SelectionController;

import '../controller/plan_controller.dart';
import '../panels/frame_safe_relay.dart';

/// [builder] with whether [controller]'s selection holds anything, built
/// again when that changes and never on pan, zoom or hover.
class SelectionGate extends StatefulWidget {
  const SelectionGate({
    super.key,
    required this.controller,
    required this.builder,
  });

  final PlanController controller;
  final Widget Function(BuildContext context, bool selected) builder;

  @override
  State<SelectionGate> createState() => _SelectionGateState();
}

class _SelectionGateState extends State<SelectionGate> {
  late bool _selected;
  SelectionController? _selection;
  FrameSafeRelay? _relay;

  @override
  void initState() {
    super.initState();
    _bind();
    widget.controller.revision.addListener(_onDocument);
    _selected = _now();
  }

  @override
  void didUpdateWidget(SelectionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.revision.removeListener(_onDocument);
      widget.controller.revision.addListener(_onDocument);
    }
    _bind();
    _selected = _now();
  }

  @override
  void dispose() {
    widget.controller.revision.removeListener(_onDocument);
    _unbind();
    super.dispose();
  }

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

  bool _now() => widget.controller.selection.keys.isNotEmpty;

  void _onSelection() {
    final next = _now();
    if (next == _selected) return;
    setState(() => _selected = next);
  }

  void _onDocument() {
    _bind();
    _onSelection();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _selected);
}
