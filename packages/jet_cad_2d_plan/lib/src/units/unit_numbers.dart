// The next number of a placed numbered unit (spec 2b S2 "Placed,
// numbered"), today's nextTableNumber (jet_cad_floor_plan/lib/src/tables/
// table_numbers.dart:48-73), skipping any unit's label.
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show UnitLabelling;

import 'unit_index.dart';

final RegExp _counted = RegExp(r'^[0-9]{1,8}$');

/// The largest number written: eight digits.
const int _kLargestCounted = 99999999;

/// The value of [label] when it counts: 1 to 8 ASCII digits, leading zeros
/// allowed (`"07"` is 7). Null otherwise.
int? countedUnitNumber(String label) =>
    _counted.hasMatch(label) ? int.parse(label) : null;

/// `max + 1` over the counted [numbers] (trimmed), written without leading
/// zeros, then up by one while that text is in [labels]; `"1"` when none
/// counts. When that would take nine digits, the smallest positive integer
/// that is neither a counted number nor in [labels]. With [labels] empty,
/// today's nextTableNumber.
String nextUnitNumberOf(Iterable<String> numbers,
    [Set<String> labels = const {}]) {
  final used = <int>{};
  var max = 0;
  for (final n in numbers) {
    final v = countedUnitNumber(n.trim());
    if (v == null) continue;
    used.add(v);
    if (v > max) max = v;
  }
  var candidate = max + 1;
  while (candidate <= _kLargestCounted && labels.contains('$candidate')) {
    candidate++;
  }
  if (candidate <= _kLargestCounted) return '$candidate';
  candidate = 1;
  while (used.contains(candidate) || labels.contains('$candidate')) {
    candidate++;
  }
  return '$candidate';
}

/// The next number for a placed `numbered` unit of [index]: over the
/// placed numbered units' labels, skipping every unit's label.
String nextUnitNumber(UnitIndex index) => nextUnitNumberOf([
      for (final u in index.units)
        if (!u.generated &&
            u.labelling == UnitLabelling.numbered &&
            u.text != null)
          u.text!,
    ], {
      for (final u in index.units)
        if (u.text != null) u.text!,
    });
