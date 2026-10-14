// Names the planner writes once and counts (spec 14d L7): a new layer's
// `Layer n`, in the language of the moment, the lowest free `n` counted
// over the names of every built-in language, so a plan edited in two
// languages never gets `Layer 3` and `Katman 3`.
// Ported from jet_cad_floor_plan (2a Task 9).
import 'strings.dart';
import 'strings_de.dart';
import 'strings_en.dart';
import 'strings_tr.dart';

final RegExp _numbered = RegExp(r'^(.*) ([1-9][0-9]*)$');

/// The `n` of [name] when [name] is [pattern]`(n)` in [current] or in a
/// built-in language, compared by [fold]; otherwise null.
int? numberedNameIndex(String name,
    String Function(PlanStrings s, int n) pattern, PlanStrings current,
    {String Function(String s) fold = _same}) {
  final m = _numbered.firstMatch(name);
  if (m == null) return null;
  final n = int.tryParse(m[2]!);
  if (n == null) return null;
  final folded = fold(name);
  for (final s in <PlanStrings>[
    current,
    const PlanStringsEn(),
    const PlanStringsDe(),
    const PlanStringsTr(),
  ]) {
    if (fold(pattern(s, n)) == folded) return n;
  }
  return null;
}

String _same(String s) => s;
