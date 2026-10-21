// The demo's own records: what a POS's database would hold, here fakes. The
// plan's objects are linked to them by id as host data (`setObjectData`);
// the plan never learns what a record is. Tables, bar counters and sections
// each have their own list, and the inspector offers the list that fits the
// selected object.
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart'
    show ArchitectureTypes;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

/// One record of the demo's fake database: its [id] (what the plan keeps on
/// the linked object) and the [name] a person reads.
final class FakeRecord {
  const FakeRecord(this.id, this.name);

  final String id;
  final String name;

  @override
  String toString() => '$id $name';
}

/// The tables `T-01` to `T-13`: the Salon's eleven, and two spare records
/// no table is linked to yet.
final List<FakeRecord> kFakeTables = [
  for (var n = 1; n <= 13; n++)
    FakeRecord('T-${n.toString().padLeft(2, '0')}', 'Table $n'),
];

/// The bars `B-01` and `B-02`.
const List<FakeRecord> kFakeBars = [
  FakeRecord('B-01', 'Main bar'),
  FakeRecord('B-02', 'Terrace bar'),
];

/// The sections `S-SALON`, `S-VIP` and `S-GARDEN`.
const List<FakeRecord> kFakeSections = [
  FakeRecord('S-SALON', 'Salon'),
  FakeRecord('S-VIP', 'VIP'),
  FakeRecord('S-GARDEN', 'Garden'),
];

/// The records [object] may be linked to: the tables for a table, the bars
/// for a bar counter, the sections for a room; none for any other object.
List<FakeRecord> recordsFor(PlanObjectDetail object) {
  switch (object.kind) {
    case PlanObjectKind.unit:
      return kFakeTables;
    case PlanObjectKind.type:
      return object.typeId == ArchitectureTypes.room ? kFakeSections : const [];
    case PlanObjectKind.symbol:
      return object.symbolKey?.startsWith('restaurant.bar.counter') ?? false
          ? kFakeBars
          : const [];
  }
}

/// The record named [id] in [records], or null.
FakeRecord? recordOf(List<FakeRecord> records, String? id) {
  for (final r in records) {
    if (r.id == id) return r;
  }
  return null;
}

/// The name of the section [section] is, by the record it is linked to:
/// null for no record (an unlinked room, or an id this list does not hold).
String? sectionRecordName(PlanObjectDetail section) =>
    recordOf(kFakeSections, section.data['id'])?.name;
