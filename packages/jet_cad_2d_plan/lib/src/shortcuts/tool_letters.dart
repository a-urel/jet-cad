// The palette's rows and the tool letters (spec 2a P2, "The keyboard" and
// "The widgets"): the generic tools first, with today's letters (V L P R C
// A T), then each kit's tools in load order. F is reserved for Fill. A
// kit's letter goes to the first tool that asks for it; a later tool that
// asks for a taken letter, for F, or for something that is no letter A-Z
// gets none and a letterTaken diagnostic (A3). plan.symbol has no row and
// no letter: the gallery arms it.
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show IconData;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:meta/meta.dart' show immutable;

import '../controller/plan_controller.dart';
import '../tools/generic_tools.dart';
import 'plan_shortcut_guard.dart' show letterKey;

/// The kit id the plan library's own tools stand under (a reserved id).
const String kPlanKitId = 'plan';

/// One palette row and its letter.
@immutable
final class PlanToolEntry {
  const PlanToolEntry({
    required this.id,
    required this.kitId,
    required this.icon,
    required this.needs,
    this.letter,
  });

  final String id;

  /// [kPlanKitId] for a generic tool, else its kit's id.
  final String kitId;
  final IconData icon;

  /// What the tool's commits need (`PlanTool.needs`' meaning).
  final Set<Capability> needs;

  /// The letter given, upper case, or null.
  final String? letter;

  /// [letter]'s key, or null.
  LogicalKeyboardKey? get key => switch (letter) {
        final l? => letterKey(l),
        null => null,
      };
}

final Expando<List<PlanToolEntry>> _entriesOf =
    Expando<List<PlanToolEntry>>('planToolEntries');

/// [controller]'s rows in palette order, computed once per controller: its
/// kit set is fixed at construction. The first call reports the refused
/// letters.
List<PlanToolEntry> planToolEntries(PlanController controller) =>
    _entriesOf[controller] ??= _assign(controller);

final RegExp _aLetter = RegExp(r'^[A-Z]$');

List<PlanToolEntry> _assign(PlanController c) {
  // The letter → the tool (or Fill) that has it.
  final taken = <String, String>{'F': 'Fill'};
  final out = <PlanToolEntry>[];
  for (final g in genericTools) {
    taken[g.letter] = g.id;
    out.add(PlanToolEntry(
        id: g.id,
        kitId: kPlanKitId,
        icon: g.icon,
        needs: g.needs,
        letter: g.letter));
  }
  for (final kit in c.kits.kits) {
    for (final t in kit.tools) {
      final asked = t.letter?.toUpperCase();
      String? letter;
      if (asked != null) {
        final owner = taken[asked];
        if (!_aLetter.hasMatch(asked)) {
          _refuse(c, kit, t, '"${t.letter}" is not a letter A-Z');
        } else if (owner != null) {
          _refuse(c, kit, t, 'the letter $asked is taken by $owner');
        } else {
          taken[asked] = t.id;
          letter = asked;
        }
      }
      out.add(PlanToolEntry(
          id: t.id,
          kitId: kit.id,
          icon: t.icon,
          needs: t.needs,
          letter: letter));
    }
  }
  return List<PlanToolEntry>.unmodifiable(out);
}

void _refuse(PlanController c, PlanKit kit, PlanTool tool, String why) =>
    c.diagnosticsLog.report(KitDiagnostic(
        kitId: kit.id,
        subject: tool.id,
        code: KitDiagnosticCode.letterTaken,
        message: '${tool.id} gets no letter: $why'));
