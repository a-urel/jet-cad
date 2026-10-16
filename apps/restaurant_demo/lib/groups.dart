// Merging and splitting groups, as a POS would (table-groups spec G6, X2):
// the ids, the grow-or-new rule and the groups line. Pure functions over
// the controller's groups, plus the two actions that apply them.
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'area.dart';
import 'demo_strings.dart';
import 'statuses.dart';

/// Orders numbers and group ids as people read them: a shared prefix,
/// then the digits by value (`G2` before `G10`, `3` before `12`).
int byNumber(String a, String b) {
  final x = _tail.firstMatch(a), y = _tail.firstMatch(b);
  if (x != null && y != null && x[1] == y[1]) {
    final order = BigInt.parse(x[2]!).compareTo(BigInt.parse(y[2]!));
    if (order != 0) return order;
  }
  return a.compareTo(b);
}

final RegExp _tail = RegExp(r'^(\D*)(\d+)$');

/// The trailing digits of any group id, whatever its prefix: a POS's own
/// `VIP9` counts as 9, so the next id is `G10`.
final RegExp _idSuffix = RegExp(r'(\d+)$');

/// [numbers] sorted by [byNumber], joined.
String sortedNumbers(Iterable<String> numbers) =>
    (numbers.toList()..sort(byNumber)).join(', ');

/// `G<n>`, n the largest numeric suffix among [ids] plus one; `G1` when
/// none has one.
String nextGroupId(Iterable<String> ids) {
  var max = BigInt.zero;
  for (final id in ids) {
    final m = _idSuffix.firstMatch(id.trim());
    if (m == null) continue;
    final n = BigInt.parse(m[1]!);
    if (n > max) max = n;
  }
  return 'G${max + BigInt.one}';
}

/// G6's merge rule for the requested [numbers] over [groups]: the groups to
/// set and the id merged into. [selectable] gives a group's selectable
/// members' numbers over the same [groups] (`PlanController.selectableMembers`).
///
/// **Grow:** when exactly one group has selectable members and [numbers]
/// include all of them, that group grows by the other numbers under its id
/// and label. Those numbers leave any other group they were in; a group
/// left empty goes. A request of exactly that group's selectable members
/// grows it by nothing: the same groups again.
///
/// **New group:** otherwise [numbers] leave every group they are in (a
/// group left empty goes) and form [nextGroupId] of the groups before the
/// merge. [numbers] are not empty (a group needs a member).
({Map<String, UnitGroup> groups, String id}) mergeGroups(
    Map<String, UnitGroup> groups,
    Set<String> numbers,
    Set<String> Function(String id) selectable) {
  final whole = [
    for (final id in groups.keys)
      if (selectable(id) case final s
          when s.isNotEmpty && numbers.containsAll(s))
        id
  ];
  final id = whole.length == 1 ? whole.single : nextGroupId(groups.keys);
  final next = <String, UnitGroup>{};
  for (final e in groups.entries) {
    final rest = e.value.members.difference(numbers);
    if (e.key == id) {
      next[id] = UnitGroup(
          members: {...e.value.members, ...numbers}, label: e.value.label);
    } else if (rest.length == e.value.members.length) {
      next[e.key] = e.value;
    } else if (rest.isNotEmpty) {
      next[e.key] = UnitGroup(members: rest, label: e.value.label);
    }
  }
  next.putIfAbsent(id, () => UnitGroup(members: numbers));
  return (groups: next, id: id);
}

/// The service bar's Merge: any request is accepted, an empty one changes
/// nothing (null). A group the merge empties takes its group status with
/// it. Returns the id merged into.
String? mergeRequested(Area a, Set<String> numbers, DemoStrings words) {
  if (numbers.isEmpty) return null;
  final c = a.controller;
  final before = c.unitGroups.value;
  final merged = mergeGroups(before, numbers, c.selectableMembers);
  c.setUnitGroups(merged.groups);
  final gone = {
    for (final id in before.keys)
      if (!merged.groups.containsKey(id)) id
  };
  if (gone.any(a.groupStatusNames.containsKey)) {
    a.groupStatusNames.removeWhere((id, _) => gone.contains(id));
    applyStatuses(a, words);
  }
  return merged.id;
}

/// The service bar's Split: the group goes, and its status with it.
void splitRequested(Area a, String id, DemoStrings words) {
  final c = a.controller;
  c.setUnitGroups({...c.unitGroups.value}..remove(id));
  a.groupStatusNames.remove(id);
  applyStatuses(a, words);
}

/// The groups line: `G1: 3+7+12 (Bill)`, by id.
String groupsText(PlanController c, DemoStrings words) {
  final groups = c.unitGroups.value;
  if (groups.isEmpty) return words.none;
  final statuses = c.groupStatuses.value;
  return [
    for (final id in groups.keys.toList()..sort(byNumber))
      [
        '$id: ${(groups[id]!.members.toList()..sort(byNumber)).join('+')}',
        if (statuses[id] case final s?)
          ' (${words.statusName(statusNameOf(s))})',
      ].join()
  ].join(', ');
}
