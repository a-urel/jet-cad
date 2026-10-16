// Spec 3a C1.3, C3.4; Review Focus 1, the kit half (the plan half is Task
// 5's PB3-prepare-load): a plan the library makes holds the separators'
// DASHED record at handle 6, clean and with nothing to undo; a loaded file
// without it opens, and saves back, without it (today's R-3).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

/// The kit's kDashedLinetypeRecord, written out (it is not exported):
/// jet_cad_floor_plan/lib/src/parametric/separator.dart:128-133.
const LinetypeRecord dashed = LinetypeRecord(
  handle: ReservedHandles.dashedLinetype,
  name: 'DASHED',
  description: 'Dashed __ __ __',
  pattern: DashPattern(dashes: [200, -100], totalLength: 300),
);

void main() {
  testWidgets(
      'SC-prepare a new plan holds DASHED at handle 6, clean, with nothing to '
      'undo, and so does newPlan; a loaded file without it opens and saves '
      'back without it', (tester) async {
    final c = architectureController();
    addTearDown(c.dispose);
    // M-SC-1 (no prepare) and M-SC-2 (another pattern).
    expect(c.document.tables.linetypes[ReservedHandles.dashedLinetype], dashed);
    expect(c.dirty.value, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.document.commands.undoDepth, 0);

    c.newPlan(decimalSeparator: ',');
    expect(c.document.tables.linetypes[ReservedHandles.dashedLinetype], dashed);
    expect(c.dirty.value, isFalse);
    expect(c.canUndo.value, isFalse);

    // A plan with no kit, so no prepare: no record.
    final bare = PlanController(kits: const []);
    addTearDown(bare.dispose);
    expect(
        bare.document.tables.linetypes.contains(ReservedHandles.dashedLinetype),
        isFalse,
        reason: 'premise: no kit, no record');
    final file = bare.save();

    final opened = architectureController(json: file);
    addTearDown(opened.dispose);
    expect(
        opened.document.tables.linetypes
            .contains(ReservedHandles.dashedLinetype),
        isFalse,
        reason: 'open adds nothing');
    expect(opened.document.tables.linetypes.byName('DASHED'), isNull);
    expect(opened.dirty.value, isFalse);
    expect(opened.save(), file, reason: 'byte-identical');

    c.load(file);
    expect(c.document.tables.linetypes.contains(ReservedHandles.dashedLinetype),
        isFalse,
        reason: 'a load adds nothing either');
    expect(c.save(), file);
  });
}
