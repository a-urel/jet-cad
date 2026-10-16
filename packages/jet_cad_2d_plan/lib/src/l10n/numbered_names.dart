// Names the planner writes once and counts (spec 14d L7): a new layer's
// `Layer n`, in the language of the moment, the lowest free `n` counted
// over the names of every built-in language, so a plan edited in two
// languages never gets `Layer 3` and `Katman 3`. Ported from
// jet_cad_floor_plan (2a Task 9); the counting is the contract's since 3a
// Task 3 (spec C1.6), this file only hands it the plan's languages.
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' as kit
    show numberedNameIndex;

import 'strings.dart';
import 'strings_de.dart';
import 'strings_en.dart';
import 'strings_tr.dart';

/// The `n` of [name] when [name] is [pattern]`(n)` in [current] or in a
/// built-in language, compared by [fold]; otherwise null.
int? numberedNameIndex(String name,
        String Function(PlanStrings s, int n) pattern, PlanStrings current,
        {String Function(String s) fold = _same}) =>
    kit.numberedNameIndex(
        name,
        [
          for (final s in <PlanStrings>[
            current,
            const PlanStringsEn(),
            const PlanStringsDe(),
            const PlanStringsTr(),
          ])
            (int n) => pattern(s, n),
        ],
        fold: fold);

String _same(String s) => s;
