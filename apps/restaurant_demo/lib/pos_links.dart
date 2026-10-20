// The POS's ids on the plan's tables, as host data: "Link tables" writes
// `<area>-<number>` into every numbered table without an id, the unlinked
// count says which POS tables the floor does not draw, and a double tap
// reads the id the table is linked by. Pure functions over an area's
// controller, plus the pointer line's value type.
import 'dart:ui' show Offset;

import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'area.dart';
import 'fake_records.dart';

/// The POS's own tables by area, by the id it links each to a table of the
/// plan with: `<area>-<number>`, lower case, as "Link tables" writes it.
/// Host data, the rows of a POS's database; the plan carries an id only
/// once a table is linked.
final Map<String, Set<String>> kDemoTableIds = {
  'Salon': {for (var n = 1; n <= 11; n++) 'salon-$n'},
  'Teras': {for (var n = 1; n <= 6; n++) 'teras-$n'},
};

/// What the service's pointer line shows: the table the mouse or stylus is
/// over ([table]), no table (both null), or the floor point a tap that
/// missed every table went down at ([floor], world millimetres, y up).
typedef PointerLine = ({String? table, Offset? floor});

/// "Link tables": every numbered table without an id gets
/// `<area>-<number>`, lower case, beside the data it carries, in one undo
/// step. A number two tables share is left out: the controller refuses an
/// ambiguous label, and the whole batch with it. Design mode only. Returns
/// how many tables were linked.
int linkTables(Area a) {
  final c = a.controller;
  final shared = {
    for (final w in c.labelWarnings)
      if (w is DuplicateLabel) w.label,
  };
  final byLabel = <String, Map<String, String>>{};
  for (final detail in c.unitDetails) {
    final n = detail.unit.label;
    if (n == null || shared.contains(n) || detail.data.containsKey('id')) {
      continue;
    }
    byLabel[n] = {...detail.data, 'id': '${a.name}-$n'.toLowerCase()};
  }
  c.setUnitsData(byLabel);
  return byLabel.length;
}

/// The POS's tables in [a] that its floor does not draw, by id: the ids no
/// visible table carries. A table on a hidden layer is not drawn, so its id
/// counts as unlinked.
Set<String> unlinkedTables(Area a) {
  final drawn = {
    for (final detail in a.controller.unitDetails)
      if (detail.unit.visible && detail.data['id'] != null) detail.data['id']!,
  };
  return a.tableIds.difference(drawn);
}

/// The id table [number] of [a] is linked by, read from the details, which
/// carry the design's data; null when it has none, and when two tables carry
/// the number, which names neither (an ambiguous link is refused on write
/// and read the same way).
String? idOf(Area a, String number) {
  final tables = [
    for (final detail in a.controller.unitDetails)
      if (detail.unit.label == number) detail,
  ];
  return tables.length == 1 ? tables.single.data['id'] : null;
}

/// "Link sections": every room that holds a probe table (`kSectionProbeTable`)
/// and is not linked yet gets that section's record id, beside the data it
/// carries, in one undo step. The room is found by the section of the probe
/// table, never by a handle. Design mode only. Returns how many were linked.
int linkSections(Area a) {
  final c = a.controller;
  final byRef = <PlanObjectRef, Map<String, String>>{};
  for (final MapEntry(key: id, value: probe) in kSectionProbeTable.entries) {
    final tables = [
      for (final d in c.unitDetails)
        if (d.unit.label == probe) d,
    ];
    if (tables.length != 1) continue;
    final section = tables.single.section;
    if (section == null || section.data.containsKey('id')) continue;
    byRef[section.ref] = {...section.data, 'id': id};
  }
  if (byRef.isNotEmpty) c.setObjectsData(byRef);
  return byRef.length;
}

/// Each table's section, by label in ascending numeric order: the name of
/// the record the section is linked to, [unlinked] for a room with none, and
/// null for a table in no section.
List<(String label, String? section)> tableSections(Area a, String unlinked) {
  final rows = <(String, String?)>[];
  for (final d in a.controller.unitDetails) {
    final s = d.section;
    rows.add((
      d.unit.label ?? '—',
      s == null ? null : sectionRecordName(s) ?? unlinked,
    ));
  }
  rows.sort((x, y) {
    final nx = int.tryParse(x.$1), ny = int.tryParse(y.$1);
    return nx != null && ny != null ? nx.compareTo(ny) : x.$1.compareTo(y.$1);
  });
  return rows;
}
