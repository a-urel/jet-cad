// A unit kind's word (spec 2b S4 "Words"): the kit's own, as
// `unit:<kit id>/<kind>` in its KitNames (a host's word first, through the
// kit's KitWords, Task 4); else the contract's word in PlanStrings (table,
// seat); else the kind as stored. The kit id is the unit's symbol key's
// first segment; a unit with no symbol key skips the kit's word.
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show kitOfKey;

import '../controller/plan_controller.dart';
import 'unit_index.dart';

/// [unit]'s kind in the controller's language.
String unitKindWord(PlanController c, UnitInfo unit) {
  final key = unit.symbolKey;
  if (key != null) {
    final kit = kitOfKey(key);
    if (c.kits.kitOf(kit) != null) {
      final word = c.servicesOf(kit).words.maybe('unit:$kit/${unit.kind}');
      if (word != null) return word;
    }
  }
  return c.planStrings.unitKind(unit.kind) ?? unit.kind;
}
