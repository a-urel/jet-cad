// Ported from jet_cad_floor_plan/test/new_document_test.dart (spec 12a D4,
// D8): ND1's and ND3's DASHED lines and ND4's "with registerAppComponents:
// a live page and live walls", assertions unchanged, over the plan library
// (spec 3a C1.3, C6). ND2's DASHED line is the kit's
// (test/separator/separator_plan_test.dart); ND1-ND4's page, unit,
// page-only and catalog-only lines are the plan library's (Task 5).
// registerAppComponents is the plan's own registration, which a
// controller's json load runs; the codec's text is the plan's save().
//
// And SP-dashed-open, Review Focus 1's kit half (the plan half is Task 5's
// PB3-prepare-load): a file without the record opens without it, its
// separator still names handle 6, where no record is, so it draws
// continuous (the painter's _patternFor answers null,
// jet_cad_2d_flutter/lib/src/draft_painter.dart:684-690), and it saves back
// byte-identical (today's R-3; the app's DO3, document_open_test.dart:
// 217-247).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/editor_rig.dart';
import 'separator_plans.dart';

PageComponent? pageOf(DraftDocument d) =>
    d.components.get<PageComponent>(d.rootHandle);

void main() {
  testWidgets('ND1 the new plan holds DASHED at handle 6 (spec 12a D4, T-11)',
      (tester) async {
    final c = architectureController();
    addTearDown(c.dispose);
    final doc = c.document;
    // M-SP-9: the kit without its prepare.
    expect(doc.tables.linetypes[ReservedHandles.dashedLinetype], dashed);
    expect(doc.tables.linetypes.byName('DASHED')!.handle,
        ReservedHandles.dashedLinetype);
  });

  testWidgets(
      'ND3 the new plan encodes, and decodes with the plan\'s registration '
      'to the same DASHED and bytes (spec 12a D4, D8)', (tester) async {
    final c = architectureController();
    addTearDown(c.dispose);
    final saved = c.save();
    final loaded = architectureController(json: saved);
    addTearDown(loaded.dispose);
    expect(loaded.document.tables.linetypes[ReservedHandles.dashedLinetype],
        dashed);
    expect(loaded.save(), saved);
  });

  testWidgets(
      'ND4 the sample\'s bytes, decoded with the plan\'s registration '
      '(registerAppComponents): a live page and live walls (spec 12a D8, '
      'S-1)', (tester) async {
    final sample =
        PlanController(kits: [architectureKit], build: buildTenWalls);
    addTearDown(sample.dispose);
    final bytes = sample.save();
    final sampleWalls = liveOf<WallParams>(sample, ArchitectureTypes.wall);
    // The group's premises (:92-95), unchanged: a page off the world
    // origin, not the new document's, and ten walls.
    expect(pageOf(sample.document), isNotNull);
    expect(pageOf(sample.document),
        isNot(PageComponent(originX: -7425, originY: -5250)));
    expect(sampleWalls, hasLength(10));

    final loaded = architectureController(json: bytes);
    addTearDown(loaded.dispose);
    expect(pageOf(loaded.document), pageOf(sample.document));
    expect(liveOf<WallParams>(loaded, ArchitectureTypes.wall), sampleWalls);
  });

  testWidgets(
      'SP-dashed-open a file without the DASHED record opens without it: its '
      'separator names handle 6, where no record is, so it draws '
      'continuous; the plan is clean and saves back byte-identical; a load '
      'does the same', (tester) async {
    final writer =
        PlanController(kits: [unpreparedKit], build: buildWallAndSeparator);
    addTearDown(writer.dispose);
    expect(
        writer.document.tables.linetypes
            .contains(ReservedHandles.dashedLinetype),
        isFalse,
        reason: 'premise: a writer that never had the record');
    final file = writer.save();

    final c = architectureController(json: file);
    addTearDown(c.dispose);
    final doc = c.document;
    final sep = liveOf<SeparatorParams>(c, ArchitectureTypes.separator).single;
    final leaves = [
      for (final slot in doc.leavesByOwner()[sep]!) doc.entities.read(slot),
    ];
    expect(leaves, hasLength(1), reason: 'premise: its polyline');
    expect(leaves.single.linetype, ReservedHandles.dashedLinetype,
        reason: 'premise: it names handle 6');
    // M-SP-8b, the open half: the constructor's json path runs the kits'
    // prepare (`made: true`). M-SP-8 is the load half, below.
    expect(doc.tables.linetypes[ReservedHandles.dashedLinetype], isNull,
        reason: 'no record there: it draws continuous');
    expect(doc.tables.linetypes.byName('DASHED'), isNull);
    expect(c.dirty.value, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.save(), file, reason: 'byte-identical');

    final other = architectureController();
    addTearDown(other.dispose);
    expect(
        other.document.tables.linetypes[ReservedHandles.dashedLinetype], dashed,
        reason: 'premise: a new plan has it');
    // M-SP-8, the load half: load runs the kits' prepare.
    other.load(file);
    expect(
        other.document.tables.linetypes[ReservedHandles.dashedLinetype], isNull,
        reason: 'a load adds nothing');
    expect(other.save(), file);
  });
}
