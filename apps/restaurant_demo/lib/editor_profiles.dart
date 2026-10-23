// The editor's profiles the side panel offers, as `PlanPermissions` and the
// editor's options, and the inspector that links a table, a bar counter or a
// room to a record of the demo's database through the host data
// (`setObjectData`).
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'demo_strings.dart';
import 'fake_records.dart';

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

/// The demo's inspector: a combo over the fake records that fit the one
/// selected object, written as the object's `data['id']` by
/// `PlanController.setObjectData` (the object's other data kept). Choosing
/// the empty entry unlinks the object.
class RecordPicker extends StatelessWidget {
  const RecordPicker(
      {super.key,
      required this.id,
      required this.records,
      required this.onChanged});

  /// The object's `data['id']`, null when it has none.
  final String? id;

  /// What the object may be linked to.
  final List<FakeRecord> records;

  /// The chosen record's id; empty for none.
  final void Function(String id) onChanged;

  @override
  Widget build(BuildContext context) {
    final words = DemoStrings.of(context);
    // An id the list does not hold (written by "Link tables", say) is shown
    // as it is: a select shows only what it has an option for.
    final known = recordOf(records, id) != null;
    final shownId = id ?? '';
    final options = <String, String>{
      '': words.none,
      if (id != null && !known) id!: id!,
      for (final r in records) r.id: '${r.id}  ${r.name}',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(words.posId, style: ShadTheme.of(context).textTheme.muted),
          const SizedBox(height: 4),
          ShadSelect<String>(
            key: const Key('pos-id'),
            initialValue: shownId,
            selectedOptionBuilder: (_, v) => Text(options[v] ?? v),
            options: [
              ShadOption(
                  key: const Key('pos-id-none'),
                  value: '',
                  child: Text(words.none)),
              if (id != null && !known)
                ShadOption(value: id!, child: Text(id!)),
              for (final r in records)
                ShadOption(
                    key: Key('pos-id-${r.id}'),
                    value: r.id,
                    child: Text('${r.id}  ${r.name}')),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
