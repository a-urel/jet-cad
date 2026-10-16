// The plan library's paint-allocation invariant (CLAUDE.md: the frame path
// allocates nothing per entity in steady state, and O(1) per flush) with
// the architecture kit loaded, over the sample flat (spec C6, Tests "The
// non-negotiables"). The harness is jet_cad_2d_plan/test/invariants/
// canvas_paint_allocation_test.dart's CV-alloc (3a Task 28): ten rebuilt
// frames of PlanCanvas, the camera moving between the fit and the fit
// turned 0.2 rad about the canvas's centre, 50 root entities and the placed
// furniture selected so the overlay draws outlines and grips; the same
// canvas state, painter, sink and Paint, and a capacity that holds still.
// The kit's furniture is placed first (armed and clicked, as a user places
// it: five `architecture.*` symbols, the base unit twice, so one definition
// is drawn by two instances), so the instance paint path is measured with
// the kit loaded (review fix 3).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_rig.dart' show globalAt, mouseClick, symbolsReady;

void main() {
  testWidgets(
      'IA-alloc a rebuilt steady-state PlanCanvas frame over the sample flat '
      'allocates O(1) per flush, the kit loaded (M-IA-alloc)', (tester) async {
    final c = sampleFlatController();
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PlanCanvas(controller: c))));
    await tester.pump();
    expect(await symbolsReady(tester, c), isTrue,
        reason: 'premise: the furniture library loaded');

    final doc = c.document;
    final size = tester.getSize(find.byType(InteractionLayer));
    final a = ViewportTransform.fit(doc.extents, size);
    c.camera.value = a;
    await tester.pump();
    final placed = <Handle>[];
    for (final (key, x, y) in const [
      ('architecture.bed.double', 15300.5, 11200.25),
      ('architecture.sofa.three', 18400.75, 14100.5),
      ('architecture.bath.toilet', 21250.25, 10300.75),
      ('architecture.kitchen.base.600', 23800.5, 12600.25),
      ('architecture.kitchen.base.600', 24600.25, 12600.75),
      ('architecture.dining.table.round', 19700.5, 11900.5),
    ]) {
      final before = {
        for (final n in doc.tree.nodes.whereType<InstanceNode>()) n.handle
      };
      expect(c.armSymbol(c.symbols.singleWhere((s) => s.component.key == key)),
          isTrue);
      await tester.pump();
      await mouseClick(tester, globalAt(tester, c, Vector2(x, y)));
      final added = [
        for (final n in doc.tree.nodes.whereType<InstanceNode>())
          if (!before.contains(n.handle)) n.handle
      ];
      expect(added, hasLength(1), reason: 'premise: $key placed');
      placed.add(added.single);
    }
    expect(c.selectTool('plan.select'), isTrue);
    await tester.pump();

    final roots = [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == doc.rootHandle)
          doc.entities.handleAt(slot),
    ].take(50).toList();
    expect(roots, hasLength(50), reason: 'premise: root entities to select');
    c.activeSelection.replace([
      for (final h in [...roots, ...placed]) SelectionKey.root(h)
    ]);

    // Turned about the canvas's centre, not only panned.
    final b = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(
                size.width / 2, size.height / 2)
            .multiply(Transform2.rotation(0.2))
            .multiply(Transform2.translation(-size.width / 2, -size.height / 2))
            .multiply(a.worldToScreenMatrix));
    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        c.camera.value = i.isEven ? a : b;
        tester.element(find.byType(PlanCanvas)).markNeedsBuild();
        await tester.pump();
      }
    }

    await frames(6);
    final state = tester.state<DraftCanvasState>(find.byType(DraftCanvas));
    final painter = state.painter;
    final sink = state.vertices!;
    final capacity = sink.debugCapacityVertices;
    final paint = sink.debugPaint;
    sink.resetCounters();

    await frames(10);

    expect(
        identical(
            tester.state<DraftCanvasState>(find.byType(DraftCanvas)), state),
        isTrue,
        reason: 'a rebuild remounted DraftCanvas');
    expect(identical(state.painter, painter), isTrue,
        reason: 'a rebuild handed DraftCanvas a new resolver');
    expect(identical(state.vertices, sink), isTrue);
    expect(sink.totalFlushCount, greaterThan(0),
        reason: 'nothing was flushed, so nothing was measured');
    expect(sink.frameTriangleCount, greaterThan(1000),
        reason: 'a degenerate plan would make the bound meaningless');
    expect(sink.debugCapacityVertices, capacity,
        reason: 'the buffer grew in a steady-state frame: O(entities)');
    expect(identical(sink.debugPaint, paint), isTrue,
        reason: 'flush() must reuse the one Paint of the sink\'s life');
  });
}
