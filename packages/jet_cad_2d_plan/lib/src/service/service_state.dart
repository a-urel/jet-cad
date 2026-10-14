// Service state (spec 2b S3 "Service state"): a unit's status, a group of
// units, the validation of a host's groups, and the group rules the
// controller, the service tool, the painters and the service bar share, so
// each applies one rule. Ported from jet_cad_floor_plan's
// lib/src/host/floor_plan_types.dart (TableStatus :128-159, TableGroup
// :244-300) and lib/src/service/table_groups.dart (whole file), keyed by
// label instead of number; a unit's lock is `isLockedUnit` (spec S2
// "Locked units"), not its layer's alone.
import 'package:flutter/foundation.dart' show immutable, setEquals;
import 'package:flutter/widgets.dart' show Color, StringCharacters;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Handle;

import '../units/unit_index.dart';

/// A unit's status as the host colours it in service (spec S3): a fill
/// under the drafting and an optional short caption. Not document state:
/// never saved, exported, printed or undone.
@immutable
final class UnitStatus {
  /// [caption] is cut to [maxCaption] characters (grapheme clusters).
  UnitStatus({required this.color, String? caption})
      : caption = caption?.characters.take(maxCaption).toString();

  /// The longest caption, in characters.
  static const int maxCaption = 12;

  /// The fill, drawn as given: a translucent colour lets the paper show.
  final Color color;

  final String? caption;

  @override
  bool operator ==(Object other) =>
      other is UnitStatus && other.color == color && other.caption == caption;

  @override
  int get hashCode => Object.hash(color, caption);

  @override
  String toString() => 'UnitStatus($color, $caption)';
}

/// A group of units the host merged (spec S3): in service its members are
/// framed, labelled, selected and moved as one. Addressed by the host's
/// group id. Not document state.
@immutable
final class UnitGroup {
  /// [members] are unit labels, each trimmed, a blank one dropped. [label]
  /// is trimmed, a blank one meaning none, then cut to [maxLabel]
  /// characters (grapheme clusters).
  UnitGroup({required Set<String> members, String? label})
      : members = Set.unmodifiable(<String>{
          for (final m in members)
            if (m.trim().isNotEmpty) m.trim()
        }),
        label = switch (label?.trim()) {
          null || '' => null,
          final l => l.characters.take(maxLabel).toString(),
        };

  /// The longest label, in characters.
  static const int maxLabel = 24;

  /// The member labels, trimmed, none blank; unmodifiable. A label with no
  /// live unit is kept and resolves once such a unit exists.
  final Set<String> members;

  /// The host's text for the group's chip, or null for its labels.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is UnitGroup &&
      other.label == label &&
      setEquals(other.members, members);

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(members), label);

  @override
  String toString() => 'UnitGroup($members, $label)';
}

/// [groups] with their ids trimmed, in their given order, unmodifiable.
///
/// Throws an [ArgumentError], before anything is returned, for an empty or
/// blank id, for two ids that are the same after trimming, for a group
/// with no member (a [UnitGroup] drops blank members), and for a label in
/// two groups; the message names the label and both ids.
Map<String, UnitGroup> validateUnitGroups(Map<String, UnitGroup> groups) {
  final out = <String, UnitGroup>{};
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
    for (final l in group.members) {
      final other = owner[l];
      if (other != null) {
        throw ArgumentError.value(raw, 'groups',
            'Unit label "$l" is in two groups, "$other" and "$id"');
      }
      owner[l] = id;
    }
    out[id] = group;
  }
  return Map.unmodifiable(out);
}

/// The id of the group each member label of [groups] belongs to; [groups]
/// as [validateUnitGroups] returns them, so a label has one group.
Map<String, String> groupIdsByLabel(Map<String, UnitGroup> groups) => {
      for (final MapEntry(key: id, value: g) in groups.entries)
        for (final l in g.members) l: id,
    };

/// One unit as the group rules see it.
final class GroupUnit {
  const GroupUnit(
      {required this.handle,
      required this.label,
      required this.visible,
      required this.locked,
      this.generated = false});

  /// The unit's instance.
  final Handle handle;

  /// Its label, trimmed, or null while it has none.
  final String? label;

  /// On a shown layer (a hidden unit counts for nothing).
  final bool visible;

  /// `isLockedUnit`: shown and tapped, never selected (spec S2).
  final bool locked;

  /// Made by its object's type: never dragged (spec S4).
  final bool generated;

  /// Visible and unlocked: what a selection may hold.
  bool get selectable => visible && !locked;

  @override
  String toString() => 'GroupUnit(${handle.toHex()}, $label'
      '${visible ? '' : ', hidden'}${locked ? ', locked' : ''}'
      '${generated ? ', generated' : ''})';
}

/// [index]'s units as the group rules see them.
List<GroupUnit> groupUnitsOf(UnitIndex index) => [
      for (final u in index.units)
        GroupUnit(
            handle: u.instance,
            label: u.text,
            visible: u.visible,
            locked: u.locked,
            generated: u.generated),
    ];

/// The groups resolved against one document's units. Built at
/// document-change or groups-change rate, never per frame or per pointer
/// event.
final class UnitGroupLookup {
  /// [groups] as [validateUnitGroups] returns them; [units] in any order.
  factory UnitGroupLookup(
      Map<String, UnitGroup> groups, Iterable<GroupUnit> units) {
    final byLabel = groupIdsByLabel(groups);
    final sorted = units.toList()
      ..sort((a, b) => a.handle.value.compareTo(b.handle.value));
    final visible = <String, List<GroupUnit>>{};
    for (final u in sorted) {
      final l = u.label;
      if (l == null || !u.visible) continue;
      final id = byLabel[l];
      if (id != null) (visible[id] ??= []).add(u);
    }
    return UnitGroupLookup._(
      groups,
      Map.unmodifiable(byLabel),
      {
        for (final MapEntry(key: id, value: list) in visible.entries)
          id: List.unmodifiable(list),
      },
      {
        for (final MapEntry(key: id, value: list) in visible.entries)
          id: List.unmodifiable([
            for (final u in list)
              if (u.selectable) u
          ]),
      },
      {
        for (final MapEntry(key: id, value: list) in visible.entries)
          if (list.any((u) => u.locked)) id,
      },
      {
        for (final MapEntry(key: id, value: list) in visible.entries)
          if (list.any((u) => u.generated)) id,
      },
    );
  }

  UnitGroupLookup._(this.groups, this.byLabel, this._visible, this._selectable,
      this._locked, this._generated);

  /// The groups this lookup resolves.
  final Map<String, UnitGroup> groups;

  /// The id of each member label's group; unmodifiable.
  final Map<String, String> byLabel;

  final Map<String, List<GroupUnit>> _visible;
  final Map<String, List<GroupUnit>> _selectable;
  final Set<String> _locked;
  final Set<String> _generated;

  /// The id of the group [label] (trimmed) belongs to, or null.
  String? groupOf(String label) => byLabel[label.trim()];

  /// The group's members on a shown layer, a locked one included,
  /// ascending by handle; every unit carrying a member label counts (a
  /// shared label gives several). Empty for an unknown id.
  List<GroupUnit> visibleMembers(String id) => _visible[id] ?? const [];

  /// The group's visible, unlocked members, ascending by handle: what a
  /// tap, a drag or a selection by label may select.
  List<GroupUnit> selectableMembers(String id) => _selectable[id] ?? const [];

  /// Whether a visible member of the group is locked: the group is then
  /// never dragged. A locked member on a hidden layer does not count.
  bool hasLockedVisibleMember(String id) => _locked.contains(id);

  /// Whether a visible member of the group is generated (a seat): the
  /// group is then never dragged (spec S4 "A drag").
  bool hasGeneratedVisibleMember(String id) => _generated.contains(id);

  /// The Split rule, the id `PlanController.selectedGroup` holds: the group
  /// whose selectable members' labels are exactly [selectedLabels], when
  /// that set is not empty and no unlabelled unit is selected
  /// ([unlabelledSelected]); else null.
  String? splitGroup(Set<String> selectedLabels,
      {required bool unlabelledSelected}) {
    if (unlabelledSelected || selectedLabels.isEmpty) return null;
    // A label is in one group at most, so only the first's can match.
    final id = groupOf(selectedLabels.first);
    if (id == null) return null;
    final labels = <String>{
      for (final u in selectableMembers(id)) u.label!,
    };
    final selected = <String>{for (final l in selectedLabels) l.trim()};
    if (labels.length != selected.length || !labels.containsAll(selected)) {
      return null;
    }
    return id;
  }
}

/// The Merge rule: whether [selectedLabels] span two or more units of
/// merging, each a group of [groups] or a selected label in no group. One
/// unit, two units sharing one label, and exactly one group do not;
/// unlabelled units carry no label and count for nothing.
bool mergeQualifies(Set<String> selectedLabels, Map<String, UnitGroup> groups) {
  final byLabel = groupIdsByLabel(groups);
  final parts = <(bool, String)>{};
  for (final raw in selectedLabels) {
    final l = raw.trim();
    if (l.isEmpty) continue;
    final id = byLabel[l];
    parts.add(id == null ? (false, l) : (true, id));
    if (parts.length >= 2) return true;
  }
  return false;
}

/// The lead order over [labels]: numeric when every one is all ASCII
/// digits -- (length after stripping leading zeros, then that string,
/// then the label as written), never `int.parse`, so any length compares
/// -- else plain string order.
Comparator<String> unitLabelOrder(Iterable<String> labels) {
  if (labels.isNotEmpty && labels.every(_digits.hasMatch)) return _numeric;
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

/// The labelled units of [members] in lead order: by [unitLabelOrder] over
/// their labels, ties (a shared label) to the lowest handle. The first is
/// the lead.
List<GroupUnit> inLeadOrder(Iterable<GroupUnit> members) {
  final list = [
    for (final u in members)
      if (u.label != null) u
  ];
  final order = unitLabelOrder([for (final u in list) u.label!]);
  list.sort((a, b) {
    final byLabel = order(a.label!, b.label!);
    if (byLabel != 0) return byLabel;
    return a.handle.value.compareTo(b.handle.value);
  });
  return list;
}

/// The status a unit labelled [label] shows: its group's when the group
/// has one, else its own; none for an unlabelled unit (today's
/// `TableStatusPainter` order, group over table).
UnitStatus? statusOfUnit(String? label,
    {required Map<String, UnitStatus> statuses,
    required Map<String, UnitStatus> groupStatuses,
    required Map<String, String> groupByLabel}) {
  if (label == null) return null;
  final id = groupByLabel[label];
  if (id != null) {
    final group = groupStatuses[id];
    if (group != null) return group;
  }
  return statuses[label];
}
