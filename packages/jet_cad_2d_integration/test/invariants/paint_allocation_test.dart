// The plan library's paint-allocation invariant (CLAUDE.md: the frame path
// allocates nothing per entity in steady state, and O(1) per flush) with
// the architecture kit loaded, over the sample flat (spec C6, Tests "The
// non-negotiables"). The harness is jet_cad_2d_plan/test/invariants/
// canvas_paint_allocation_test.dart's CV-alloc (3a Task 28): ten rebuilt
// frames of PlanCanvas, the camera moving one pixel, 50 root entities
// selected so the overlay draws outlines and grips; the same canvas state,
// painter, sink and Paint, and a capacity that holds still.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

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

    final doc = c.document;
    final roots = [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == doc.rootHandle)
          doc.entities.handleAt(slot),
    ].take(50).toList();
    expect(roots, hasLength(50), reason: 'premise: root entities to select');
    c.activeSelection.replace([for (final h in roots) SelectionKey.root(h)]);

    final size = tester.getSize(find.byType(InteractionLayer));
    final a = ViewportTransform.fit(doc.extents, size);
    final b = ViewportTransform(
        worldToScreenMatrix:
            Transform2.translation(1, -1).multiply(a.worldToScreenMatrix));
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
