import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

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

  testWidgets('each change reaches the leaf-owner map', (tester) async {
    // The map is what lets the painter draw a small container whole instead of
    // querying it. Fed by the canvas, because the document's only synchronous
    // channel belongs to the index — so a canvas that subscribes but forgets
    // to forward gives the painter a map that is right only until the first
    // edit.
    await tester.pumpWidget(
        wrap(DraftCanvas(document: doc, index: index, camera: camera)));
    final state = tester.state<DraftCanvasState>(find.byType(DraftCanvas));

    const inner = Handle(500);
    final before = state.ownerMap.slotsOf(inner).length;
    doc.commands.execute(lineAt(inner, const Handle(951), [0, 0, 1, 1]));
    await tester.idle();

    expect(state.ownerMap.slotsOf(inner), hasLength(before + 1));
  });

  testWidgets('disposing stops listening', (tester) async {
    // Two failures live here and neither announces itself. A subscription left
    // open keeps a dead canvas maintaining derived state for the life of the
    // document — no crash, just work and memory that nothing will ever read.
    // A subscription left open onto a *disposed* notifier does throw, on the
    // next edit, which is a user action far from the canvas that caused it.
    await tester.pumpWidget(
        wrap(DraftCanvas(document: doc, index: index, camera: camera)));
    final map =
        tester.state<DraftCanvasState>(find.byType(DraftCanvas)).ownerMap;
    final before = map.slotsOf(doc.rootHandle).length;

    await tester.pumpWidget(wrap(const SizedBox()));
    doc.commands
        .execute(lineAt(doc.rootHandle, const Handle(952), [0, 0, 1, 1]));
    await tester.idle();

    expect(map.slotsOf(doc.rootHandle), hasLength(before),
        reason: 'a disposed canvas must stop maintaining its derived state');
    expect(tester.takeException(), isNull);
  });

  testWidgets('one sink serves every paint', (tester) async {
    // `CanvasDrawSink` exists to own a `Paint`, a `Path` and two typed lists
    // across frames; constructing one per paint throws that away and puts four
    // allocations on the frame path, which is the one thing this render path
    // is built not to do. The `Canvas` is what changes per frame, so it is
    // what gets rebound.
    await tester.pumpWidget(
        wrap(DraftCanvas(document: doc, index: index, camera: camera)));
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
}
