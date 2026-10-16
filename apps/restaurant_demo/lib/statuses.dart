// The statuses a POS would set on a table or a group: their colours, their
// captions in the app's language, and the host state that words them again
// when the language changes (a `UnitStatus.caption` is plain text the
// library never re-words, and cuts to 12 graphemes).
import 'dart:math' as math;

import 'package:flutter/painting.dart' show Color;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'area.dart';
import 'demo_strings.dart';

/// The statuses by name, as the old demo's; Free is no status. Only Bill
/// carries its name as the caption.
final Map<String, UnitStatus?> kStatuses = {
  'Free': null,
  'Ordered': UnitStatus(color: const Color(0x99FFB300)),
  'Eating': UnitStatus(color: const Color(0x9943A047)),
  'Bill': UnitStatus(color: const Color(0x99E53935), caption: 'Bill'),
};

/// [kStatuses]'s status [name], its caption in [words]' language.
UnitStatus? statusFor(String name, DemoStrings words) {
  final status = kStatuses[name];
  if (status == null || status.caption == null) return status;
  return UnitStatus(color: status.color, caption: words.statusName(name));
}

/// The name [kStatuses] gives [status], by its colour (a caption is
/// worded), or `status` for another one.
String statusNameOf(UnitStatus status) => kStatuses.entries
    .firstWhere((e) => e.value?.color == status.color,
        orElse: () => const MapEntry('status', null))
    .key;

/// Puts [a]'s table and group statuses on its controller, worded in
/// [words]' language. The whole maps are replaced, as the controller's are.
void applyStatuses(Area a, DemoStrings words) {
  a.controller.setUnitStatus({
    for (final e in a.statusNames.entries)
      if (statusFor(e.value, words) case final status?) e.key: status,
  });
  a.controller.setGroupStatus({
    for (final e in a.groupStatusNames.entries)
      if (statusFor(e.value, words) case final status?) e.key: status,
  });
}

/// Sets status [name] on [labels], or on the selected group when [labels]
/// is null and a group is selected (a group status overrides its members'
/// own; Free clears it), else on the selection. Returns the group the
/// status went to, if any, and the labels it went to otherwise.
({String? group, Set<String> labels}) setStatus(
    Area a, String name, DemoStrings words,
    [Set<String>? labels]) {
  final c = a.controller;
  final group = labels == null ? c.selectedGroup.value : null;
  if (group != null) {
    if (kStatuses[name] == null) {
      a.groupStatusNames.remove(group);
    } else {
      a.groupStatusNames[group] = name;
    }
    applyStatuses(a, words);
    return (group: group, labels: const {});
  }
  final targets = labels ?? c.selectedUnits.value;
  for (final n in targets) {
    if (kStatuses[name] == null) {
      a.statusNames.remove(n);
    } else {
      a.statusNames[n] = name;
    }
  }
  applyStatuses(a, words);
  return (group: null, labels: targets);
}

/// A random status for every labelled unit of [a], replacing the previous
/// ones; the number of units that got one.
int randomStatuses(Area a, math.Random random, DemoStrings words) {
  final names = kStatuses.keys.toList();
  a.statusNames.clear();
  for (final u in a.controller.units) {
    final n = u.label;
    if (n == null) continue;
    final name = names[random.nextInt(names.length)];
    if (kStatuses[name] != null) a.statusNames[n] = name;
  }
  applyStatuses(a, words);
  return a.controller.unitStatuses.value.length;
}
