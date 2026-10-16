// The editor's profiles the side panel offers, as `PlanPermissions` and the
// editor's options, and the table inspector that links a table to the POS's
// id through the host data (`setUnitData`).
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'demo_strings.dart';

/// The editor's profiles: the full editor, a floor whose staff place and
/// arrange tables only, and a plan only looked at.
enum DemoEditor {
  full(PlanPermissions.full),
  tables(PlanPermissions.unitsOnly),
  readOnly(PlanPermissions.readOnly);

  const DemoEditor(this.permissions);

  /// What the profile lets the editor's user do, before the Moves switch.
  final PlanPermissions permissions;

  /// The permissions the controller gets: the profile's, with the service
  /// moves as the Moves switch says. `readOnly` keeps the service flags: a
  /// plan only looked at in the design can still be arranged in the service.
  PlanPermissions compose({required bool moves}) =>
      permissions.copyWith(serviceMove: moves);

  /// Whether the Layers and Page sections show.
  bool get showsLayersAndPage => this == full;

  /// The gallery's filter: only the units under [tables].
  bool Function(PlanSymbol)? get symbolFilter =>
      this == tables ? isUnitSymbol : null;

  /// The editor's top bar: Print, Export, then the zoom under [readOnly]
  /// (no object snap's read-out, since nothing is drawn).
  PlanEditorBar get bar => this == readOnly
      ? const PlanEditorBar(actions: [
          PlanEditorAction.print,
          PlanEditorAction.export,
          PlanEditorAction.zoom,
        ])
      : const PlanEditorBar();
}

/// The demo's table inspector: the POS's id of the one table selected in
/// the editor, written by `PlanController.setUnitData` on Enter (an empty
/// field unlinks).
class PosIdField extends StatefulWidget {
  const PosIdField({super.key, required this.id, required this.onSubmitted});

  /// The table's `data['id']`, null when it has none.
  final String? id;
  final void Function(String id) onSubmitted;

  @override
  State<PosIdField> createState() => _PosIdFieldState();
}

class _PosIdFieldState extends State<PosIdField> {
  late final TextEditingController _text =
      TextEditingController(text: widget.id ?? '');

  @override
  void didUpdateWidget(PosIdField old) {
    super.didUpdateWidget(old);
    // Linked elsewhere (an undo): shown at once.
    if (widget.id != old.id) _text.text = widget.id ?? '';
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: TextField(
          key: const Key('pos-id'),
          controller: _text,
          decoration: InputDecoration(
              labelText: DemoStrings.of(context).posId, isDense: true),
          onSubmitted: widget.onSubmitted,
        ),
      );
}
