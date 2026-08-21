// R2 — frame timing under a scripted camera. R4a — a leaf edit per frame.
// R4b — an instance drag per frame.
//
// Profile mode only:
//   flutter test integration_test/frame_timing_test.dart --profile -d macos
//
// Debug numbers are meaningless here; the harness refuses to record them.

// ignore_for_file: avoid_print — printing the numbers is what a rig is for.

import 'dart:typed_data';

import 'package:dev_harness_2d/main.dart';
import 'package:dev_harness_2d/measurement_rig.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

/// Entity count for one run of the whole file, so both corpus sizes are
/// measured by running it twice rather than by doubling every rig.
const int kEntities = int.fromEnvironment('ENTITIES', defaultValue: 50000);

/// Which rig to run: `all`, `pan` (R2), `leaf` (R4a) or `instance` (R4b).
///
/// One at a time matters at 500,000 entities. A `flutter drive` run that takes
/// longer than a few minutes has to be started in the background, and a
/// backgrounded run on macOS stalls: the app blocks on its first
/// `pumpWidget`, at 0% CPU, waiting for a frame the windowing system never
/// asks it for. Both foreground runs completed; both background runs hung.
const String kRig = String.fromEnvironment('RIG', defaultValue: 'all');

/// Gesture samples for R4a and R4b.
///
/// R4b costs a full index rebuild per step, so 200 of them at 500,000 entities
/// is minutes of wall clock for one number. The number wanted is the per-step
/// cost, and that does not need 200 samples.
const int kSteps = int.fromEnvironment('STEPS', defaultValue: 200);

bool runs(String rig) => kRig == 'all' || kRig == rig;

// `refuseDebugMode`, `report`, `printBackend` and `printTextCounters` live in
// `package:dev_harness_2d/measurement_rig.dart` now, shared with `main.dart`'s
// `RUN_R2` app-run mode — see that file's header comment for why this file
// no longer defines its own copies.

/// Wall clock for the command itself, which no `FrameTiming` can see.
///
/// A command runs synchronously in the gesture handler, before the frame it
/// causes. Its cost — including the index invalidation it triggers — lands
/// outside `buildDuration` entirely, so reporting frame times alone would put
/// "200 full index rebuilds" and "build p50 5.4 ms" side by side and read as
/// "rebuilds are free".
class CommandClock {
  final List<double> _ms = [];

  void time(void Function() body) {
    final sw = Stopwatch()..start();
    body();
    sw.stop();
    _ms.add(sw.elapsedMicroseconds / 1000.0);
  }

  String get summary {
    if (_ms.isEmpty) return 'no commands';
    final sorted = [..._ms]..sort();
    return 'p50=${sorted[(sorted.length * 0.5).floor()].toStringAsFixed(2)}ms '
        'p95=${sorted[(sorted.length * 0.95).floor()].toStringAsFixed(2)}ms '
        'max=${sorted.last.toStringAsFixed(2)}ms';
  }
}

Handle addLineAt(
    DraftDocument doc, Handle owner, double x, double y, Handle linetype) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      // The corpus's dashed linetype, not ByLayer: layer 0 is continuous, so
      // a ByLayer line would measure an edit path that never dashes — which
      // is not the edit path this rig is for.
      linetype: linetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: 25,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList([x, y, x + 400, y + 250]),
        scalars: Float64List(0)),
  ));
  return handle;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Builds the app and hands back everything a rig drives.
  Future<
      ({
        DraftDocument doc,
        CameraController camera,
        SpatialIndex index,
        DraftPainter painter,
        CanvasDrawSink sink,
        VerticesDrawSink? vertices,
        RenderBackend resolvedBackend,
        Handle? dashedLinetype
      })> boot(WidgetTester tester) async {
    final doc = harnessDocument(kEntities);
    late CameraController camera;
    late SpatialIndex index;
    late DraftPainter painter;
    late CanvasDrawSink sink;
    VerticesDrawSink? vertices;
    late RenderBackend resolvedBackend;
    await tester.pumpWidget(HarnessApp(
      document: doc,
      onReady: (c, i, p, s, v, b) {
        camera = c;
        index = i;
        painter = p;
        sink = s;
        vertices = v;
        resolvedBackend = b;
      },
    ));
    // Zoom to the working set. Fitting the whole drawing measures a frame
    // nobody renders — R1 already reports that one, at a second per frame.
    final e = doc.extents;
    final cx = (e.minX + e.maxX) / 2;
    final cy = (e.minY + e.maxY) / 2;
    camera.value = ViewportTransform.fit(
        Aabb2(Vector2(cx - 1500, cy - 1125), Vector2(cx + 1500, cy + 1125)),
        tester.view.physicalSize / tester.view.devicePixelRatio);
    await tester.pump();

    // The corpus's dashed linetype: `harnessDocument` seeds exactly one via
    // `dashedFraction` (see `generateDocument`). Found by shape — the only
    // `LinetypeRecord` whose pattern carries dashes — not by name, so a
    // corpus change that renames it cannot make this silently pick the wrong
    // table row.
    final dashedLinetypes = doc.tables.linetypes.records
        .where((lt) => lt.pattern.dashes.isNotEmpty)
        .toList();
    // `kDashedFraction == 0` is the control arm of the dash/leaf separation
    // experiment, and `generateDocument` seeds no dashed `LinetypeRecord` at
    // all in that case -- so the count expected there is zero, not one. Any
    // other count still fails: two would mean the shape lookup below is
    // ambiguous, and one at a fraction of zero would mean the corpus stopped
    // honouring the define.
    final expectedDashedLinetypes = kDashedFraction > 0 ? 1 : 0;
    if (dashedLinetypes.length != expectedDashedLinetypes) {
      throw StateError('expected $expectedDashedLinetypes dashed linetype(s) '
          'in the corpus at DASHED=$kDashedFraction, found '
          '${dashedLinetypes.length}: '
          '${dashedLinetypes.map((lt) => lt.name).toList()}');
    }

    // Same footgun as the dashed-linetype check above, for `FILLS`: a corpus
    // that silently ignored the define would still print plausible-looking
    // frame times, and this is the one place that would notice before the
    // rig's own `fills=`/`skippedFills=` line does.
    if (kFillsEnabled && doc.fills.linkCount == 0) {
      throw StateError('FILLS=true but the corpus carries no fills');
    }
    if (!kFillsEnabled && doc.fills.linkCount != 0) {
      throw StateError('FILLS=false but the corpus carries '
          '${doc.fills.linkCount} fill(s)');
    }

    return (
      doc: doc,
      camera: camera,
      index: index,
      painter: painter,
      sink: sink,
      vertices: vertices,
      resolvedBackend: resolvedBackend,
      dashedLinetype: dashedLinetypes.singleOrNull?.handle
    );
  }

  testWidgets('R2 pan and zoom', (tester) async {
    if (!runs('pan')) return;
    final app = await boot(tester);
    // The measured rig itself — 120 frames of pan, 120 of zoom, one forced
    // repaint, then the block — lives in `measurement_rig.dart`'s
    // `runR2Rig`, shared with `main.dart`'s `RUN_R2` app-run mode so the
    // desktop and (Task 13) web rows come from one implementation. Only how
    // a frame gets pumped differs between the two call sites.
    await runR2Rig(
      entities: kEntities,
      lineweightScale: kLineweightScale,
      textCorpus: kTextCorpus,
      drawText: kDrawText,
      camera: app.camera,
      painter: app.painter,
      sink: app.sink,
      vertices: app.vertices,
      resolvedBackend: app.resolvedBackend,
      pumpFrame: () => tester.pump(const Duration(milliseconds: 16)),
      settle: tester.pumpAndSettle,
    );
  });

  testWidgets('R4a leaf edit per frame', (tester) async {
    if (!runs('leaf')) return;
    if (kDashedFraction == 0) {
      print('R4a skipped: DASHED=0 seeds no dashed linetype to edit with.');
      return;
    }
    refuseDebugMode();
    final app = await boot(tester);
    final timings = <FrameTiming>[];
    binding.addTimingsCallback(timings.addAll);

    // A drag is remove-then-add today: there is no in-place geometry command.
    // Each step burns a handle and leaves a dead slot, which is itself
    // recorded — the alternative is to report the frame cost of a gesture the
    // application cannot yet express and call it the cost of dragging.
    final e = app.doc.extents;
    final x = (e.minX + e.maxX) / 2;
    final y = (e.minY + e.maxY) / 2;
    final handlesBefore = app.doc.handleSeed.current.value;
    final rebuildsBefore = app.index.rebuildCount;
    // Non-null past the `kDashedFraction == 0` return above, which is the only
    // arm in which the corpus carries no dashed linetype.
    final dashed = app.dashedLinetype!;
    var dragged = addLineAt(app.doc, app.doc.rootHandle, x, y, dashed);

    final clock = CommandClock();
    for (var step = 1; step <= kSteps; step++) {
      clock.time(() {
        app.doc.commands.execute(RemoveEntityCommand(dragged));
        dragged = addLineAt(app.doc, app.doc.rootHandle, x + step * 2.0,
            y + step * 1.0, dashed);
      });
      app.camera.panBy(const Offset(-3, -1));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    // All three counters now mean the same thing: this frame. dashSpanCount
    // and collapsedDashCount reset themselves every paint; canvasCallCount
    // does not, because the sink outlives the frame. But pumpAndSettle
    // leaves nothing dirty, so a bare pump() would not repaint at all —
    // RenderCustomPaint only repaints when its `repaint` Listenable fires,
    // and nothing has changed since the last real frame. panBy(Offset.zero)
    // is a numeric no-op but still assigns a fresh ViewportTransform
    // (Transform2 and ViewportTransform both deliberately have no
    // operator==, so ValueNotifier's reference check always sees a
    // "change"), which fires the listener and forces the one real repaint
    // that makes resetCounters() meaningful. A running total beside two
    // per-frame figures is a wrong comparison waiting to be published.
    app.sink.resetCounters();
    app.vertices?.resetCounters();
    final layoutsBefore = app.sink.measurer.layoutCount;
    final evictionsBefore = app.sink.measurer.evictionCount;
    app.camera.panBy(Offset.zero);
    await tester.pump(const Duration(milliseconds: 16));
    report('R4a ($kEntities)', timings);
    print('  command ${clock.summary}');
    print('  overlay=${app.index.rootIndex.dirty.length} '
        'threshold=${app.index.rootIndex.rebuildThreshold} '
        'rebuilds=${app.index.rebuildCount - rebuildsBefore} '
        'handles burned=${app.doc.handleSeed.current.value - handlesBefore}');
    requireRepaint(app.sink, app.vertices);
    printInvariants(app.painter, app.sink);
    printBackend(app.resolvedBackend, app.vertices);
    printTextCounters(app.painter, app.sink,
        textCorpus: kTextCorpus,
        drawText: kDrawText,
        layoutsBefore: layoutsBefore,
        evictionsBefore: evictionsBefore);
  });

  testWidgets('R4b instance drag per frame', (tester) async {
    if (!runs('instance')) return;
    refuseDebugMode();
    final app = await boot(tester);
    final timings = <FrameTiming>[];
    binding.addTimingsCallback(timings.addAll);

    // `TransformNodeCommand` touches a node handle, which the index classifies
    // as structural and answers with a full rebuild. This rig measures that:
    // the cost of the application's defining gesture, once per frame.
    final instance = app.doc.tree.nodes
        .whereType<InstanceNode>()
        .firstWhere((n) => n.parent == app.doc.rootHandle);
    final before = app.index.rebuildCount;

    final clock = CommandClock();
    for (var step = 1; step <= kSteps; step++) {
      clock.time(() => app.doc.commands.execute(TransformNodeCommand(
          instance.handle,
          Transform2.translation(step * 2.0, step * 1.0)
              .multiply(Transform2.scale(1.0, -1.5)))));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    // All three counters now mean the same thing: this frame. dashSpanCount
    // and collapsedDashCount reset themselves every paint; canvasCallCount
    // does not, because the sink outlives the frame. But pumpAndSettle
    // leaves nothing dirty, so a bare pump() would not repaint at all —
    // RenderCustomPaint only repaints when its `repaint` Listenable fires,
    // and nothing has changed since the last real frame. panBy(Offset.zero)
    // is a numeric no-op but still assigns a fresh ViewportTransform
    // (Transform2 and ViewportTransform both deliberately have no
    // operator==, so ValueNotifier's reference check always sees a
    // "change"), which fires the listener and forces the one real repaint
    // that makes resetCounters() meaningful. A running total beside two
    // per-frame figures is a wrong comparison waiting to be published.
    app.sink.resetCounters();
    app.vertices?.resetCounters();
    final layoutsBefore = app.sink.measurer.layoutCount;
    final evictionsBefore = app.sink.measurer.evictionCount;
    app.camera.panBy(Offset.zero);
    await tester.pump(const Duration(milliseconds: 16));
    report('R4b ($kEntities)', timings);
    print('  command ${clock.summary}');
    print('  rebuilds=${app.index.rebuildCount - before} over $kSteps frames');
    requireRepaint(app.sink, app.vertices);
    printInvariants(app.painter, app.sink);
    printBackend(app.resolvedBackend, app.vertices);
    printTextCounters(app.painter, app.sink,
        textCorpus: kTextCorpus,
        drawText: kDrawText,
        layoutsBefore: layoutsBefore,
        evictionsBefore: evictionsBefore);
  });
}
