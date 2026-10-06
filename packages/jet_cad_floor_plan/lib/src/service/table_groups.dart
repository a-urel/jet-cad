// Table groups as the selection mode reads them (table-groups spec G2, G4,
// G5): the validation of a host's groups, the number-to-group lookup, each
// group's visible and selectable members, the lead order, and the Merge and
// Split rules. Shared by the controller, the select tool, the painters and
// the service bar, so each applies the same rule.
//
// No Flutter import of its own: Dart over `package:jet_cad_2d`, and
// [TableGroup] from the host types.
import 'package:jet_cad_2d/jet_cad_2d.dart' show Handle;

import '../host/floor_plan_types.dart' show TableGroup;

/// [groups] with their ids trimmed, in their given order, unmodifiable (G2).
///
/// Throws an [ArgumentError], before anything is returned, for an empty or
/// blank id, for two ids that are the same after trimming, for a group
/// with no member (a [TableGroup] drops blank members), and for a number in
/// two groups (members are trimmed by [TableGroup], so `'5'` and `' 5 '`
/// overlap); the message names the number and both ids.
Map<String, TableGroup> validateTableGroups(Map<String, TableGroup> groups) {
  final out = <String, TableGroup>{};
  final owner = <String, String>{};
  for (final MapEntry(key: raw, value: group) in groups.entries) {
    final id = raw.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(raw, 'groups', 'A group id is blank');
    }
    if (out.containsKey(id)) {
      throw ArgumentError.value(
          raw, 'groups', 'Two group ids are "$id" after trimming');
    }
    if (group.members.isEmpty) {
      throw ArgumentError.value(raw, 'groups', 'Group "$id" has no member');
    }
    for (final n in group.members) {
      final other = owner[n];
      if (other != null) {
        throw ArgumentError.value(raw, 'groups',
            'Table number "$n" is in two groups, "$other" and "$id"');
      }
      owner[n] = id;
    }
    out[id] = group;
  }
  return Map.unmodifiable(out);
}

/// The id of the group each member number of [groups] belongs to. [groups]
/// as [validateTableGroups] returns them, so a number has one group.
Map<String, String> groupIdsByNumber(Map<String, TableGroup> groups) => {
      for (final MapEntry(key: id, value: g) in groups.entries)
        for (final n in g.members) n: id,
    };

/// One table as the group rules see it: the facts a caller already holds
/// (the controller's survey and layers, the picker's candidates).
final class GroupTable {
  const GroupTable(
      {required this.handle,
      required this.number,
      required this.visible,
      required this.locked});

  /// The table's instance.
  final Handle handle;

  /// Its number, trimmed, or null while it has none.
  final String? number;

  /// On a visible layer (G2: a hidden table counts for nothing).
  final bool visible;

  /// On a locked layer (14c R-1: shown and tapped, never selected).
  final bool locked;

  /// Visible and unlocked: what a selection may hold.
  bool get selectable => visible && !locked;

  @override
  String toString() => 'GroupTable(${handle.toHex()}, $number'
      '${visible ? '' : ', hidden'}${locked ? ', locked' : ''})';
}

/// The groups resolved against one plan's tables (G2, G4). Built at
/// document-change or groups-change rate, never per frame or per pointer
/// event.
final class TableGroupLookup {
  /// [groups] as [validateTableGroups] returns them; [tables] in any order.
  factory TableGroupLookup(
      Map<String, TableGroup> groups, Iterable<GroupTable> tables) {
    final byNumber = groupIdsByNumber(groups);
    final sorted = tables.toList()
      ..sort((a, b) => a.handle.value.compareTo(b.handle.value));
    final visible = <String, List<GroupTable>>{};
    for (final t in sorted) {
      final n = t.number;
      if (n == null || !t.visible) continue;
      final id = byNumber[n];
      if (id != null) (visible[id] ??= []).add(t);
    }
    return TableGroupLookup._(groups, byNumber, {
      for (final MapEntry(key: id, value: list) in visible.entries)
        id: List.unmodifiable(list),
    }, {
      for (final MapEntry(key: id, value: list) in visible.entries)
        id: List.unmodifiable([
          for (final t in list)
            if (t.selectable) t
        ]),
    }, {
      for (final MapEntry(key: id, value: list) in visible.entries)
        if (list.any((t) => t.locked)) id,
    });
  }

  TableGroupLookup._(this.groups, this._byNumber, this._visible,
      this._selectable, this._locked);

  /// The groups this lookup resolves.
  final Map<String, TableGroup> groups;

  final Map<String, String> _byNumber;
  final Map<String, List<GroupTable>> _visible;
  final Map<String, List<GroupTable>> _selectable;
  final Set<String> _locked;

  /// The id of the group [number] (trimmed) belongs to, or null.
  String? groupOf(String number) => _byNumber[number.trim()];

  /// The group's members on a visible layer, a locked one included,
  /// ascending by handle; every table carrying a member number counts (a
  /// file duplicate gives several). Empty for an unknown id.
  List<GroupTable> visibleMembers(String id) => _visible[id] ?? const [];

  /// The group's visible, unlocked members, ascending by handle: what a tap,
  /// a drag or a selection by number may select (G2, 14c R-1).
  List<GroupTable> selectableMembers(String id) => _selectable[id] ?? const [];

  /// Whether a visible member of the group is on a locked layer: the group
  /// is then never dragged (G4). A locked member on a hidden layer does not
  /// count.
  bool hasLockedVisibleMember(String id) => _locked.contains(id);

  /// The Split rule (G5), the id `FloorPlanController.selectedGroup` holds:
  /// the group whose selectable members' numbers are exactly
  /// [selectedNumbers], when that set is not empty and no unnumbered table
  /// is selected ([unnumberedSelected]); else null.
  String? splitGroup(Set<String> selectedNumbers,
      {required bool unnumberedSelected}) {
    if (unnumberedSelected || selectedNumbers.isEmpty) return null;
    // A number is in one group at most, so only the first's can match.
    final id = groupOf(selectedNumbers.first);
    if (id == null) return null;
    final numbers = <String>{
      for (final t in selectableMembers(id)) t.number!,
    };
    final selected = <String>{for (final n in selectedNumbers) n.trim()};
    if (numbers.length != selected.length || !numbers.containsAll(selected)) {
      return null;
    }
    return id;
  }
}

/// The Merge rule (G5): whether [selectedNumbers] span two or more units,
/// a unit being a group of [groups] or a selected number in no group. One
/// table, two tables sharing one number, and exactly one group do not;
/// unnumbered tables carry no number and count for nothing.
bool mergeQualifies(
    Set<String> selectedNumbers, Map<String, TableGroup> groups) {
  final byNumber = groupIdsByNumber(groups);
  final units = <(bool, String)>{};
  for (final raw in selectedNumbers) {
    final n = raw.trim();
    if (n.isEmpty) continue;
    final id = byNumber[n];
    units.add(id == null ? (false, n) : (true, id));
    if (units.length >= 2) return true;
  }
  return false;
}

/// The lead order over [numbers] (G3): numeric when every one is all ASCII
/// digits -- (length after stripping leading zeros, then that string, then
/// the number as written), never `int.parse`, so any length compares --
/// else plain string order.
Comparator<String> tableNumberOrder(Iterable<String> numbers) {
  if (numbers.isNotEmpty && numbers.every(_digits.hasMatch)) {
    return _numeric;
  }
  return _plain;
}

final RegExp _digits = RegExp(r'^[0-9]+$');

int _plain(String a, String b) => a.compareTo(b);

int _numeric(String a, String b) {
  final sa = _stripZeros(a), sb = _stripZeros(b);
  final byLength = sa.length.compareTo(sb.length);
  if (byLength != 0) return byLength;
  final byValue = sa.compareTo(sb);
  if (byValue != 0) return byValue;
  return a.compareTo(b);
}

String _stripZeros(String s) {
  var i = 0;
  while (i < s.length && s.codeUnitAt(i) == 0x30) {
    i++;
  }
  return s.substring(i);
}

/// The numbered tables of [members] in lead order (G3): by
/// [tableNumberOrder] over their numbers, ties (a file duplicate) to the
/// lowest handle. The first is the lead.
List<GroupTable> inLeadOrder(Iterable<GroupTable> members) {
  final list = [
    for (final t in members)
      if (t.number != null) t
  ];
  final order = tableNumberOrder([for (final t in list) t.number!]);
  list.sort((a, b) {
    final byNumber = order(a.number!, b.number!);
    if (byNumber != 0) return byNumber;
    return a.handle.value.compareTo(b.handle.value);
  });
  return list;
}
