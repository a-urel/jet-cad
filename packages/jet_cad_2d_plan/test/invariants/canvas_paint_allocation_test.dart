// What a steady-state frame of the plan library's canvas allocates
// (CLAUDE.md: "The frame path allocates nothing per entity in steady state,
// and O(1) per flush"; spec 2a "Tests": a paint-allocation test for the
// plan library's canvas).
//
// The drawing is the Flutter layer's DraftCanvas, whose own frame path
// jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart measures:
// once a frame has drawn its widest view, the vertices sink never gives
// capacity back, so `debugCapacityVertices` holds still across a later
// frame or it does not, and `flush` reuses one Paint. What the plan library
// adds is the composition around it: PlanCanvas rebuilds (a controller
// notification, a theme, a parent's build) must hand DraftCanvas the same
// resolver, document, index and camera, or DraftCanvas re-attaches
// (`draft_canvas.dart:443-462`): a new DraftPainter, a new sink, every
// cache made again, which is O(entities) per rebuild. So the frames below
// rebuild PlanCanvas every frame and pin: the same DraftCanvasState, the
// same painter, the same sink, a capacity that holds still and the same
// Paint. The plan library paints nothing per entity of its own: the
// overlay, the rulers and the page chrome are the Flutter layer's.
//
// The corpus is the Flutter layer's (4,000 entities, 400 instances nested
// two deep, mirrored and non-uniform placements, groups, eight layers,
// ByBlock and dashed styles), loaded through PlanController from its text,
// with 50 root entities selected so the overlay draws outlines and grips.
// The two cameras differ by one pixel of pan, off the origin.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/service/paint/unit_status_painter.dart';

import '../support/service_fixture.dart';
import '../support/service_paint.dart';
import '../support/test_kit.dart' show unitKit;

void main() {
  testWidgets(
      'CV-alloc a rebuilt steady-state PlanCanvas frame allocates O(1) per '
      'flush, not O(entities) (M-CV-alloc-1, M-CV-alloc-2)', (tester) async {
    final corpus = generateDocument(
      4000,
      definitionCount: 40,
      instanceCount: 400,
      nestingDepth: 2,
      mirroredFraction: 0.1,
      nonUniformFraction: 0.2,
      groupCount: 10,
      layerCount: 8,
      byBlockFraction: 0.3,
      dashedFraction: 0.35,
    );
    final json = ensureManifest(DraftDocumentCodec.encodeToString(corpus));
    final c = PlanController(kits: const [], json: json);
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
    c.selection.replace([for (final h in roots) SelectionKey.root(h)]);

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

    // Warm up: both views drawn, so the buffers are at their high water.
    await frames(6);
    final state = tester.state<DraftCanvasState>(find.byType(DraftCanvas));
    final painter = state.painter;
    final sink = state.vertices!;
    final capacity = sink.debugCapacityVertices;
    final paint = sink.debugPaint;
    sink.resetCounters();

    await frames(10);

    // First what a rebuild kept: a remounted canvas or a new painter flushes
    // into another sink, so the premise below would fail first and hide
    // which one it was.
    // M-CV-alloc-2: a key that changes per build remounts the canvas.
    expect(
        identical(
            tester.state<DraftCanvasState>(find.byType(DraftCanvas)), state),
        isTrue,
        reason: 'a rebuild remounted DraftCanvas');
    // M-CV-alloc-1: a resolver made per build rebuilds the painter.
    expect(identical(state.painter, painter), isTrue,
        reason: 'a rebuild handed DraftCanvas a new resolver: a new painter '
            'and every cache made again');
    expect(identical(state.vertices, sink), isTrue);
    expect(sink.totalFlushCount, greaterThan(0),
        reason: 'nothing was flushed, so nothing was measured');
    expect(sink.frameTriangleCount, greaterThan(1000),
        reason: 'a degenerate corpus would make the bound meaningless');
    expect(sink.debugCapacityVertices, capacity,
        reason: 'the buffer grew in a steady-state frame: O(entities)');
    expect(identical(sink.debugPaint, paint), isTrue,
        reason: 'flush() must reuse the one Paint of the sink\'s life');
  });

  testWidgets(
      'CV-alloc-colour the design canvas\'s unit colours: ten rebuilt '
      'frames, the camera moving, keep the painter and build and rebuild '
      'nothing (M-CV-colour-a, M-CV-colour-b)', (tester) async {
    final f = serviceFixture();
    final c = PlanController(kits: [unitKit()], json: f.json);
    addTearDown(c.dispose);
    final table = c.unitIndex[f.table]!.text!;
    expect(c.setUnitColour(table, PlanSwatch.teal), isTrue);
    expect(c.setUnitColour('A1', PlanSwatch.purple), isTrue);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PlanCanvas(controller: c))));
    await tester.pump();
    await tester.pump();
    UnitStatusPainter painter() => tester
        .widget<CustomPaint>(find.byKey(const Key('unit-colour-layer')))
        .painter! as UnitStatusPainter;
    final p = painter();
    final made = p.debugAllocations;
    final rebuilds = p.debugRebuilds;
    expect(made, greaterThanOrEqualTo(3),
        reason: 'premise: two paths and a paint at least');
    final size = tester.getSize(find.byType(InteractionLayer));
    final a = ViewportTransform.fit(c.document.extents, size);
    for (var i = 0; i < 10; i++) {
      c.camera.value = ViewportTransform(
          worldToScreenMatrix: Transform2.translation(1.0 + i, -1.0 - i)
              .multiply(a.worldToScreenMatrix));
      tester.element(find.byType(PlanCanvas)).markNeedsBuild();
      await tester.pump();
    }
    expect(identical(painter(), p), isTrue, reason: 'the painter is kept');
    expect(p.debugAllocations, made, reason: 'nothing per frame');
    expect(p.debugRebuilds, rebuilds, reason: 'no rebuild per frame');
  });

  testWidgets(
      'CV-alloc-service the service scene: statuses, a group, a group '
      'status and a focus over the table and the seats; ten frames, the '
      'camera moving, build and rebuild nothing in any painter '
      '(M-CV-service)', (tester) async {
    final f = serviceFixture();
    final c = PlanController(kits: [unitKit()], json: f.json);
    addTearDown(c.dispose);
    final table = c.unitIndex[f.table]!.text!;
    c.setMode(PlanMode.service);
    c.setUnitStatus({
      table: UnitStatus(color: const Color(0xFFE53935), caption: 'Bill'),
      'A1': UnitStatus(color: const Color(0xFF43A047)),
    });
    c.setUnitGroups({
      'g': UnitGroup(members: {'A2', 'A3'})
    });
    c.setGroupStatus({'g': UnitStatus(color: const Color(0xFF3949AB))});
    c.setUnitFocus({'A1', 'B1'});
    final layers = ServicePaintLayers(
        controller: c, session: c.serviceSession!, darkCanvas: () => false);
    addTearDown(layers.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(fit: StackFit.expand, children: [
          Positioned.fill(child: layers.underlay),
          Positioned.fill(child: layers.overlay),
        ])));
    final base = ViewportTransform.fit(
        c.serviceSession!.document.extents, const Size(1440, 900));
    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        c.camera.value = ViewportTransform(
            worldToScreenMatrix: Transform2.translation(1.0 + i, -1.0 - i)
                .multiply(base.worldToScreenMatrix));
        await tester.pump();
      }
    }

    await frames(3);
    List<int> made() => [
          layers.statuses.debugAllocations,
          layers.frames.debugAllocations,
          layers.chips.debugAllocations,
          layers.focus.debugAllocations,
        ];
    List<int> rebuilt() => [
          layers.statuses.debugRebuilds,
          layers.frames.debugRebuilds,
          layers.chips.debugRebuilds,
          layers.focus.debugRebuilds,
        ];
    final made0 = made(), rebuilt0 = rebuilt();
    expect(layers.statuses.debugAllocations, greaterThan(0),
        reason: 'premise: the fills built');
    // Each group painter counts its two paints and its matrix at birth.
    expect(layers.frames.debugAllocations, greaterThan(3),
        reason: 'premise: the frame built');
    expect(layers.chips.debugAllocations, greaterThan(3),
        reason: 'premise: the chip built');
    expect(layers.focus.debugAllocations, greaterThan(2),
        reason: 'premise: the veil built');
    await frames(10);
    expect(made(), made0, reason: 'nothing per frame');
    expect(rebuilt(), rebuilt0, reason: 'no rebuild per frame');
  });
}
