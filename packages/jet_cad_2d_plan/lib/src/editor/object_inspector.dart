// The host's inspector for any one selected object (spec D9): the same relay
// as UnitInspector (a frame-safe selection relay, a revision listener, the
// detail read fresh at each build), over the root objects
// PlanController.objectDetailOf answers for. A locked object shows nothing,
// as the property panel does.
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Handle;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show SelectionController;

import '../chrome/host_slot.dart';
import '../controller/plan_controller.dart';
import '../objects/object_detail.dart';
import '../objects/object_ref.dart';
import '../panels/frame_safe_relay.dart';

/// The host's inspector under the property panel: [builder] for the one
/// selected root object, nothing otherwise. With [unitsElsewhere] a placed
/// unit shows nothing here (the unit inspector has it).
class ObjectInspector extends StatefulWidget {
  const ObjectInspector({
    super.key,
    required this.controller,
    required this.builder,
    this.unitsElsewhere = false,
  });

  final PlanController controller;
  final Widget? Function(BuildContext context, PlanObjectDetail object) builder;
  final bool unitsElsewhere;

  @override
  State<ObjectInspector> createState() => _ObjectInspectorState();
}

class _ObjectInspectorState extends State<ObjectInspector> {
  /// The object shown; null for none.
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
  void didUpdateWidget(ObjectInspector oldWidget) {
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

  /// The selection's one key when it is a root key on an object the host
  /// may inspect.
  Handle? _inspected() {
    final c = widget.controller;
    final keys = c.selection.keys;
    if (keys.length != 1) return null;
    final key = keys.single;
    if (key.chain.isNotEmpty) return null;
    return _detail(key.target) == null ? null : key.target;
  }

  /// [h]'s fresh detail, or null when it is no object, is locked, or is a
  /// unit another inspector has.
  PlanObjectDetail? _detail(Handle h) {
    final c = widget.controller;
    final detail = c.objectDetailOf(PlanObjectRef.of(h));
    if (detail == null || c.isLocked(h)) return null;
    if (widget.unitsElsewhere && detail.kind == PlanObjectKind.unit) {
      return null;
    }
    return detail;
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

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final detail = shown == null ? null : _detail(shown);
    if (detail == null) return const SizedBox.shrink();
    final built = widget.builder(context, detail);
    return built == null ? const SizedBox.shrink() : PlanHostSlot(child: built);
  }
}
