import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/fixtures.dart';

Widget wrap(Widget child) =>
    Center(child: SizedBox(width: 400, height: 300, child: child));

/// The one render object the damage model acts on.
RenderCustomPaint paintBoxOf(WidgetTester tester) =>
    tester.renderObject<RenderCustomPaint>(find.descendant(
        of: find.byType(DraftCanvas), matching: find.byType(CustomPaint)));

AddEntityCommand lineAt(Handle owner, Handle handle, List<double> coords) =>
    AddEntityCommand(
      record: EntityRecord(
        handle: handle,
        owner: owner,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: 25,
        transparency: 0,
        flags: 0,
      ),
      payload: GeometryPayload(
          coords: Float64List.fromList(coords), scalars: Float64List(0)),
    );

void addLine(DraftDocument doc) => doc.commands
    .execute(lineAt(doc.rootHandle, doc.handleSeed.next(), [0, 0, 1, 1]));

void main() {
  late DraftDocument doc;
  late SpatialIndex index;
  late CameraController camera;

  setUp(() {
    doc = differentialFixture();
    index = SpatialIndex(doc);
    addTearDown(index.dispose);
    camera = CameraController(ViewportTransform.fit(doc.extents, kViewport));
    addTearDown(camera.dispose);
  });

  testWidgets('repaints on a camera change without rebuilding', (tester) async {
    var builds = 0;
    await tester.pumpWidget(wrap(Builder(builder: (_) {
      builds++;
      return DraftCanvas(document: doc, index: index, camera: camera);
    })));
    final buildsAfterFirst = builds;

    camera.panBy(const Offset(10, 0));

    expect(builds, buildsAfterFirst,
        reason: 'a ValueNotifier passed as CustomPainter.repaint repaints '
            'inside the RepaintBoundary; rebuilding would defeat it');
    expect(paintBoxOf(tester).debugNeedsPaint, isTrue,
        reason: 'and the repaint must actually have been scheduled — no '
            'rebuild AND no repaint is a frozen canvas, which this test would '
            'otherwise pass');
    await tester.pump();
  });

  testWidgets('does not claim commands.onAfterMutate', (tester) async {
    // That field is a single slot and SpatialIndex takes it in its
    // constructor. A canvas that assigns it silently disables the index's
    // invalidation, and every query from then on answers from a stale tree.
    final before = doc.commands.onAfterMutate;
    expect(before, isNotNull, reason: 'the index holds it before we start');

    await tester.pumpWidget(
        wrap(DraftCanvas(document: doc, index: index, camera: camera)));

    expect(identical(doc.commands.onAfterMutate, before), isTrue);
  });

  testWidgets('repaints after a document change', (tester) async {
    await tester.pumpWidget(
        wrap(DraftCanvas(document: doc, index: index, camera: camera)));
    expect(paintBoxOf(tester).debugNeedsPaint, isFalse);

    doc.commands
        .execute(lineAt(doc.rootHandle, const Handle(950), [0, 0, 5, 5]));
    await tester.idle(); // the broadcast is asynchronous by design

    expect(paintBoxOf(tester).debugNeedsPaint, isTrue);
    await tester.pump();
  });

  testWidgets('the painter never repaints per vsync', (tester) async {
    // `shouldRepaint` is asked on every rebuild; answering true there would
    // make the canvas repaint for reasons that have nothing to do with the
    // drawing having changed. The `repaint` listenable is the only trigger.
    await tester.pumpWidget(
        wrap(DraftCanvas(document: doc, index: index, camera: camera)));
    final painter = paintBoxOf(tester).painter!;
    expect(painter.shouldRepaint(painter), isFalse);
  });

  testWidgets('disposing stops listening', (tester) async {
    final doc = DraftDocument.empty();
    var changes = 0;
    final notifier = DocChangeNotifier(doc, onChange: (_) => changes++);
    addLine(doc);
    await tester.pump();
    final afterFirst = changes;
    expect(afterFirst, greaterThan(0),
        reason: 'the listener must be live '
            'before disposal, or the assertion below proves nothing');

    notifier.dispose();
    addLine(doc);
    await tester.pump();
    expect(changes, afterFirst,
        reason: 'a disposed notifier that still receives changes leaks; '
            'it does not throw, so "no exception" would not catch it');
  });

  testWidgets('one sink serves every paint', (tester) async {
    // `CanvasDrawSink` exists to own a `Paint`, a `Path` and two typed lists
    // across frames; constructing one per paint throws that away and puts four
    // allocations on the frame path, which is the one thing this render path
    // is built not to do. The `Canvas` is what changes per frame, so it is
    // what gets rebound.
    // Pinned to the canvas backend explicitly: this is a claim about
    // `CanvasDrawSink`'s identity and lifetime, and under the vertices
    // backend `CanvasDrawSink` is the fallback that takes only text —
    // `state.sink.canvas` would still read back normally there because
    // `_DraftCustomPainter.paint` binds it before branching on the backend,
    // which would make this test pass while asserting the wrong thing about
    // the fallback rather than about the sink that actually paints.
    await tester.pumpWidget(wrap(DraftCanvas(
        document: doc,
        index: index,
        camera: camera,
        backend: RenderBackend.canvas)));
    final state = tester.state<DraftCanvasState>(find.byType(DraftCanvas));
    final first = state.sink;

    camera.panBy(const Offset(10, 0));
    await tester.pump();
    camera.zoomAt(const Offset(200, 150), 1.5);
    await tester.pump();

    expect(identical(state.sink, first), isTrue);
    // Identity alone proves only that the field was left alone. `canvas` is
    // `late` and set by the paint, so reading it is what says this sink is the
    // one that reached `Canvas` rather than one kept beside a fresh sink built
    // per frame.
    expect(() => state.sink.canvas, returnsNormally,
        reason: 'the sink the widget owns must be the sink that paints');
  });

  testWidgets('does not dispose what it was handed', (tester) async {
    // The index and the camera outlive any one canvas — two canvases over one
    // document is the split-view case — so ownership stays with the caller.
    await tester.pumpWidget(
        wrap(DraftCanvas(document: doc, index: index, camera: camera)));
    await tester.pumpWidget(wrap(const SizedBox()));

    expect(index.rootIndex.leafCount, greaterThan(0));
    camera.panBy(const Offset(1, 0)); // would throw on a disposed notifier
  });

  testWidgets('a small container does not draw its off-screen leaves',
      (tester) async {
    // Eight leaves — under the old kCullFloor of 32 — spread across a strip
    // far wider than the view. The camera sees the leftmost two.
    final doc = DraftDocument.empty();
    final def = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
        handle: def,
        name: 'strip',
        basePoint: Vector2.zero(),
        children: const []));
    for (var i = 0; i < 8; i++) {
      addEntity(doc, def, doc.handleSeed.next(), EntityKind.line,
          [i * 1000.0, 0, i * 1000.0 + 40, 30], const []);
    }
    final placed = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: placed,
      parent: doc.rootHandle,
      definition: def,
      layer: ReservedHandles.layerZero,
      transform: Transform2(1.3, 0.2, -0.1, 1.7, 25, 40),
    )));

    final index = SpatialIndex(doc);
    final recording = RecordingDrawSink();
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    // A view over the first strip cell only.
    final camera = ViewportTransform.fit(
        Aabb2(Vector2(0, 0), Vector2(120, 90)), kViewport);
    painter.paint(recording, camera, kViewport);

    final drawn = recording.ops.whereType<PolylineOp>().length;
    // Not an exact count: index boxes carry narrow-phase slack, so the culled
    // number is "fewer than all of them", not a number this test may pin. The
    // two bounds together are the property — 8 means the shortcut is live, 0
    // means the fixture is wrong and the assertion above it proves nothing.
    expect(drawn, greaterThan(0),
        reason: 'the view holds part of the strip; drawing nothing means the '
            'fixture, not the cull floor, is what this test is measuring');
    expect(drawn, lessThan(8),
        reason: 'the container has eight leaves and the view holds one or two '
            'of them; drawing all eight is the cull-floor shortcut');
  });

  group('DocChangeNotifier', () {
    test('notifies after a change, and forwards it', () async {
      final doc = differentialFixture();
      var notifications = 0;
      final seen = <DocChange>[];
      final notifier = DocChangeNotifier(doc, onChange: seen.add)
        ..addListener(() {
          notifications++;
        });
      addTearDown(notifier.dispose);

      doc.commands
          .execute(lineAt(doc.rootHandle, const Handle(953), [0, 0, 1, 1]));
      expect(notifications, 0, reason: 'the stream is asynchronous');

      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1);
      expect(seen.single, isA<CommandApplied>());
      expect(seen.single.touched, contains(const Handle(953)));
    });

    test('forwards before it notifies', () async {
      // The listener repaints, and a repaint reads the map. Notifying first
      // would paint one frame against a map that does not know about the edit.
      final doc = differentialFixture();
      final order = <String>[];
      final notifier = DocChangeNotifier(doc, onChange: (_) => order.add('map'))
        ..addListener(() => order.add('listener'));
      addTearDown(notifier.dispose);

      doc.commands
          .execute(lineAt(doc.rootHandle, const Handle(954), [0, 0, 1, 1]));
      await Future<void>.delayed(Duration.zero);

      expect(order, ['map', 'listener']);
    });

    test('dispose cancels the subscription', () async {
      final doc = differentialFixture();
      var notifications = 0;
      DocChangeNotifier(doc)
        ..addListener(() => notifications++)
        ..dispose();

      doc.commands
          .execute(lineAt(doc.rootHandle, const Handle(955), [0, 0, 1, 1]));
      await Future<void>.delayed(Duration.zero);

      expect(notifications, 0);
    });
  });

  testWidgets('drawText reaches the painter, and a change to it rebuilds one',
      (tester) async {
    // `drawText` is measurement-only, so nothing in the product reads it and
    // nothing else would notice if the forward were dropped. What *does* read
    // it is `apps/dev_harness_2d`'s `DRAW_TEXT=0` define, and a dropped
    // forward there does not fail — it prints a text-off row identical to the
    // text-on row, which is the plausible-looking number this file's other
    // guard already exists to refuse.
    final textDoc = DraftDocument.empty(measurer: MetricModelMeasurer());
    textDoc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: textDoc.handleSeed.next(),
        owner: textDoc.rootHandle,
        kind: EntityKind.text,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: 25,
        transparency: 0,
        flags: 0,
        text: 'STAIR',
        textStyle: ReservedHandles.standardTextStyle,
        textAttrs: packTextAttrs(),
      ),
      payload: GeometryPayload(
          coords: Float64List.fromList([12, 7]),
          scalars: Float64List.fromList([8, 0, 1, 0])),
    ));
    final textIndex = SpatialIndex(textDoc);
    addTearDown(textIndex.dispose);
    final textCamera =
        CameraController(ViewportTransform.fit(textDoc.extents, kViewport));
    addTearDown(textCamera.dispose);

    final key = GlobalKey<DraftCanvasState>();
    Widget canvas({required bool drawText}) => wrap(DraftCanvas(
        key: key,
        document: textDoc,
        index: textIndex,
        camera: textCamera,
        drawText: drawText));

    await tester.pumpWidget(canvas(drawText: true));
    expect(key.currentState!.painter.drawText, isTrue);
    expect(key.currentState!.painter.textOpCount, 1,
        reason: 'the fixture must actually draw text, or neither half of '
            'this test means anything');

    // A prop change has to rebuild the painter: `drawText` is final on
    // `DraftPainter`, so a `didUpdateWidget` that ignored it would leave the
    // old painter in place and the flag would be silently one frame — or one
    // whole run — behind.
    await tester.pumpWidget(canvas(drawText: false));
    expect(key.currentState!.painter.drawText, isFalse);
    textCamera.panBy(Offset.zero);
    await tester.pump();
    expect(key.currentState!.painter.textOpCount, 0);
  });
}
