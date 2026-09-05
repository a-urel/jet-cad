import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/recording_frame_painter.dart';

const Size kCanvas = Size(400, 300);
const Offset kCentre = Offset(200, 150);

void main() {
  late FlutterTextMeasurer measurer;
  late DraftDocument doc;
  late SpatialIndex index;
  late CameraController camera;
  late FakeUploader uploader;
  var paints = 0;

  setUp(() {
    debugSetGpuAvailable(true);
    addTearDown(() => debugSetGpuAvailable(null));
    DraftCanvas.debugResetResidentFallbackReport();
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    doc = textOverlapFixture(measurer);
    index = SpatialIndex(doc);
    addTearDown(index.dispose);
    camera = CameraController(ViewportTransform.fit(doc.extents, kCanvas));
    addTearDown(camera.dispose);
    uploader = FakeUploader();
    paints = 0;
  });

  Widget wrap(Widget child, {double dpr = 1.0, Size size = kCanvas}) =>
      MediaQuery(
          data: MediaQueryData(devicePixelRatio: dpr),
          child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                  child: SizedBox(
                      width: size.width, height: size.height, child: child))));

  Widget canvas({double dpr = 1.0, Size size = kCanvas, bool tiles = false}) =>
      wrap(
          DraftCanvas(
              document: doc,
              index: index,
              camera: camera,
              backend: RenderBackend.residentGpu,
              minTextCapPixels: 0,
              tiles: tiles,
              residentUploader: uploader.call,
              onPaintForTest: () => paints++),
          dpr: dpr,
          size: size);

  DraftCanvasState state(WidgetTester t) =>
      t.state<DraftCanvasState>(find.byType(DraftCanvas));

  /// The post-frame callback fires at the end of the first pump, the fake
  /// upload completes in a microtask, the landing's notify is the second
  /// pump's frame.
  Future<void> land(WidgetTester t) async {
    await t.pump();
    await t.pump();
  }

  testWidgets(
      'the first frame paints through vertices; the landed rebuild '
      'paints through the backend', (t) async {
    await t.pumpWidget(canvas());
    final s = state(t);
    expect(s.resolvedBackend, RenderBackend.residentGpu);
    expect(s.resident, isNotNull);
    expect(s.vertices, isNotNull,
        reason: 'the pre-Plan-F path is still built: it draws before the '
            'first landing (Ruling F5)');
    expect(s.tileCache, isNull);
    expect(paints, 1);
    // The first paint's noteFrame registered a post-frame callback; it fired
    // inside this same frame, and the ungated fake upload completed
    // synchronously, so the rebuild has already LANDED here -- but the frame
    // itself drew before that, through the vertices sink, and the landing
    // only asked for a frame that has not been pumped yet. That is Ruling F3:
    // the frame never waits, and the rebuild runs after the paint.
    expect(s.resident!.landed, 1);
    expect(uploader.painters.single.paints, 0,
        reason: 'the landed backend has not been asked to paint yet: the '
            'first frame went through vertices');
    expect(() => s.vertices!.canvas, returnsNormally,
        reason: 'the vertices sink is what drew the first frame');
    await land(t);
    final r = s.resident!;
    expect(r.landed, 1);
    expect(r.lastTrigger, RebuildTrigger.initial);
    final p = uploader.painters.single;
    expect(p.paints, greaterThanOrEqualTo(1),
        reason: 'the landing asked for a frame, and that frame went through '
            'the backend');
    expect(p.lastDpr, 1.0);
    expect(p.lastViewport, kCanvas);
    expect(uploader.collections.single.collectionCamera.scale,
        closeTo(camera.value.scale, 1e-12));
  });

  testWidgets('every DocChange is a rebuild; a pan and a resize are not',
      (t) async {
    await t.pumpWidget(canvas());
    await land(t);
    final r = state(t).resident!;
    expect(r.landed, 1);

    Future<void> expectRebuild(String what, void Function() fire) async {
      final before = r.landed;
      fire();
      await land(t);
      await t.pump();
      expect(r.landed, before + 1,
          reason: '$what must cause exactly one rebuild');
      expect(r.lastTrigger, RebuildTrigger.document);
    }

    Future<void> expectNoRebuild(
        String what, Future<void> Function() act) async {
      final before = r.landed;
      await act();
      await land(t);
      expect(r.landed, before, reason: '$what must not rebuild');
    }

    await expectRebuild('CommandApplied', () {
      addLine(doc, doc.rootHandle, doc.handleSeed.next(), 100, 100, 900, 700);
    });
    await expectRebuild('CommandUndone', doc.commands.undo);
    await expectRebuild('CommandRedone', doc.commands.redo);
    await expectRebuild('DocumentLoaded', doc.commands.notifyLoaded);
    await expectRebuild('DocumentPurged', doc.purge);
    await expectNoRebuild('a pan', () async {
      camera.panBy(const Offset(40, 0));
      await t.pump();
    });
    await expectNoRebuild('a resize', () async {
      await t.pumpWidget(canvas(size: const Size(500, 350)));
    });
    expect(uploader.painters.last.lastViewport, const Size(500, 350),
        reason: 'the resized frame still painted through the same backend');
    expect(paints, greaterThan(7));
  });

  testWidgets('a layer edit rebuilds, through the revision counter', (t) async {
    await t.pumpWidget(canvas());
    await land(t);
    final r = state(t).resident!;
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    doc.tables.layers.remove(zero.handle);
    doc.tables.layers.add(LayerRecord(
        handle: zero.handle,
        name: zero.name,
        color: const IndexedColor(1),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency,
        visible: zero.visible,
        locked: zero.locked));
    // The table listenable causes the frame; the frame's noteFrame reads the
    // counter (Ruling F4). MUTATION (M-F1): drop the comparison -> landed 1.
    await land(t);
    await t.pump();
    expect(r.landed, 2);
    expect(r.lastTrigger, RebuildTrigger.tables);
    expect(r.collection!.tablesRevision, doc.tables.mutationRevision);
  });

  testWidgets('a device pixel ratio change rebuilds, with the new ratio',
      (t) async {
    await t.pumpWidget(canvas(dpr: 1.0));
    await land(t);
    final r = state(t).resident!;
    await t.pumpWidget(canvas(dpr: 2.0));
    await land(t);
    // MUTATION (M-F2): drop the comparison -> landed 1, dpr still 1.0.
    expect(r.landed, 2);
    expect(r.lastTrigger, RebuildTrigger.devicePixelRatio);
    expect(r.collection!.devicePixelRatio, 2.0);
    expect(uploader.painters.last.lastDpr, 2.0);
  });

  testWidgets(
      'leaving the band rebuilds at the live scale; staying inside '
      'does not', (t) async {
    await t.pumpWidget(canvas());
    await land(t);
    final r = state(t).resident!;
    camera.zoomAt(kCentre, 1.9);
    await land(t);
    expect(r.landed, 1, reason: '1.9 is inside [0.5, 2.0]');
    expect(r.bandStaleFrames, 0);
    camera.zoomAt(kCentre, 1.2); // 2.28 overall
    await land(t);
    await t.pump();
    // MUTATION (M-F3): ratio against the collection's own scale -> landed 1.
    expect(r.landed, 2);
    expect(r.lastTrigger, RebuildTrigger.band);
    expect(r.collection!.collectionCamera.scale,
        closeTo(camera.value.scale, 1e-12),
        reason: 'Ruling F1: the new reference scale is the live scale');
    expect(r.bandStaleFrames, greaterThanOrEqualTo(1),
        reason: 'the frame that fired the trigger was drawn out of band');
  });

  testWidgets(
      'a re-attach replaces the rebuilder and leaves one table '
      'listener; an unmount leaves none', (t) async {
    await t.pumpWidget(canvas());
    await land(t);
    final first = state(t).resident!;
    expect(doc.tables.debugListenerCount, 1);
    await t.pumpWidget(canvas(tiles: true));
    final s = state(t);
    expect(first.disposed, isTrue);
    expect(s.resident, isNot(same(first)));
    expect(s.tileCache, isNull,
        reason: 'the resident path owns gestures; no tile cache beside it');
    expect(doc.tables.debugListenerCount, 1);
    await land(t);
    expect(s.resident!.landed, 1);
    final second = s.resident!;
    await t.pumpWidget(wrap(const SizedBox()));
    expect(second.disposed, isTrue);
    expect(doc.tables.debugListenerCount, 0);
    expect(uploader.painters.every((p) => p.disposed), isTrue,
        reason: 'every backend the canvas ever installed is disposed with it');
  });
}
