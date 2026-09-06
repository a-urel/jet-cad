import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/recording_frame_painter.dart';

void main() {
  late FlutterTextMeasurer measurer;
  late DraftDocument doc;
  late SpatialIndex index;
  late DraftPainter painter;
  late FakeUploader uploader;
  late ResidentRebuilder r;
  const centre = Offset(400, 300);

  setUp(() {
    measurer = FlutterTextMeasurer();
    doc = textOverlapFixture(measurer);
    index = SpatialIndex(doc);
    painter = DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        minTextCapPixels: 0);
    uploader = FakeUploader();
    r = ResidentRebuilder(
        document: doc,
        painter: painter,
        uploader: uploader.call,
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        lineweightScale: 1.0,
        measurer: measurer,
        textStyleOf: doc.textStyleOf);
  });
  tearDown(() {
    r.dispose();
    index.dispose();
    measurer.clear();
  });

  ViewportTransform fit() => ViewportTransform.fit(doc.extents, kViewport);
  int rev() => doc.tables.mutationRevision;

  /// The post-frame callback fires at the end of the first pump; the fake
  /// upload completes in a microtask; the second pump is the frame the
  /// landing asked for.
  Future<void> land(WidgetTester t) async {
    await t.pump();
    await t.pump();
  }

  testWidgets(
      'the first frame marks initial and does not walk; the post-frame '
      'callback does', (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    expect(r.pending, RebuildTrigger.initial);
    // MUTATION (M-F7): walk inside noteFrame -> rebuilds is already 1 here.
    expect(r.rebuilds, 0, reason: 'noteFrame never walks (Ruling F3)');
    expect(r.backend, isNull);
    await land(t);
    expect(r.rebuilds, 1);
    expect(r.landed, 1);
    expect(r.backend, isA<RecordingFramePainter>());
    expect(r.collection!.texts.length, 4);
    expect(r.pending, isNull);
    expect(r.lastTrigger, RebuildTrigger.initial);
    expect(r.lastTotalMicros, greaterThan(0));
  });

  testWidgets(
      'three marks before the frame ends are one rebuild, named for '
      'the first', (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    r.markDirty(RebuildTrigger.document);
    r.markDirty(RebuildTrigger.band);
    r.markDirty(RebuildTrigger.tables);
    expect(r.pending, RebuildTrigger.document);
    await land(t);
    // MUTATION (M-F6): drop markDirty's early return -> three callbacks are
    // registered and schedules reads 4; rebuilds stays 2 only because
    // _run's pending re-check absorbs the extra callbacks.
    expect(r.rebuilds, 2);
    expect(r.schedules, 2,
        reason: 'one schedule for initial, one for the three coalesced '
            'marks');
    expect(r.lastTrigger, RebuildTrigger.document);
  });

  testWidgets('a mark during an upload in flight queues exactly one more',
      (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    uploader.gate = Completer<void>();
    r.markDirty(RebuildTrigger.document);
    await t.pump();
    expect(r.inFlight, isTrue);
    expect(r.rebuilds, 2);
    r.markDirty(RebuildTrigger.tables);
    r.markDirty(RebuildTrigger.tables);
    expect(r.pending, RebuildTrigger.tables);
    uploader.gate!.complete();
    uploader.gate = null;
    await land(t);
    await land(t);
    // MUTATION (M-F13): drop the reschedule at the end of _run -> rebuilds 2.
    expect(r.rebuilds, 3);
    expect(r.landed, 3);
    expect(r.inFlight, isFalse);
    expect(r.pending, isNull);
    expect(uploader.painters[1].disposed, isTrue,
        reason: 'the superseded backend is disposed on the swap');
    expect(identical(r.backend, uploader.painters[2]), isTrue);
  });

  testWidgets('the band is read as live over collection', (t) async {
    final base = fit();
    r.noteFrame(base, kViewport, 1.0, rev());
    await land(t);
    for (final s in const [0.5, 0.8, 1.0, 1.6, 2.0]) {
      r.noteFrame(zoomedAbout(base, centre, s), kViewport, 1.0, rev());
      expect(r.pending, isNull, reason: 'ratio $s is inside [0.5, 2.0]');
    }
    expect(r.bandStaleFrames, 0);
    r.noteFrame(zoomedAbout(base, centre, 2.01), kViewport, 1.0, rev());
    // MUTATION (M-F3): ratio = collection.scale / collection.scale -> never.
    expect(r.pending, RebuildTrigger.band);
    await land(t);
    expect(r.rebuilds, 2);
    expect(r.lastTrigger, RebuildTrigger.band);
    // The new collection is at 2.01x. 1.1 / 2.01 = 0.547 is inside its band
    // (not 1.005: that is 0.5 exactly in real numbers and a coin toss in
    // doubles); 0.98 / 2.01 = 0.488 is outside.
    r.noteFrame(zoomedAbout(base, centre, 1.1), kViewport, 1.0, rev());
    expect(r.pending, isNull);
    r.noteFrame(zoomedAbout(base, centre, 0.98), kViewport, 1.0, rev());
    expect(r.pending, RebuildTrigger.band);
    expect(r.bandStaleFrames, 2, reason: 'the 2.01 frame and the 0.98 frame');
  });

  testWidgets(
      'the table revision counter triggers a rebuild, and the new '
      'collection carries the new revision', (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    final before = rev();
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
    expect(rev(), greaterThan(before));
    r.noteFrame(fit(), kViewport, 1.0, rev());
    // MUTATION (M-F1): drop the revision comparison -> pending stays null.
    expect(r.pending, RebuildTrigger.tables);
    await land(t);
    expect(r.collection!.tablesRevision, rev());
    r.noteFrame(fit(), kViewport, 1.0, rev());
    expect(r.pending, isNull, reason: 'settled: no second rebuild');
  });

  testWidgets(
      'a device pixel ratio change triggers a rebuild whose half-widths '
      'follow it', (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    final one = r.collection!;
    r.noteFrame(fit(), kViewport, 2.0, rev());
    // MUTATION (M-F2): drop the dpr comparison -> pending stays null.
    expect(r.pending, RebuildTrigger.devicePixelRatio);
    await land(t);
    final two = r.collection!;
    expect(two.devicePixelRatio, 2.0);
    // Same instance count, wider strokes: the same test Task 1 makes, on the
    // rebuilder's own output.
    expect(two.instanceCount, one.instanceCount);
    var wOne = 0.0, wTwo = 0.0;
    for (var i = 0; i < one.instanceCount; i++) {
      final o = i * 16 + 1; // InstanceFieldOffset.halfWidth, kFloatsPerInstance
      if (one.data[o] > wOne) wOne = one.data[o];
      if (two.data[o] > wTwo) wTwo = two.data[o];
    }
    expect(wTwo, closeTo(2 * wOne, 1e-3));
  });

  testWidgets(
      'an edited label draws the new string: the text list is not '
      'stale across a rebuild', (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    expect(r.collection!.texts.map((x) => x.text), contains('COVERED'));
    doc.commands.execute(SetEntityTextCommand(const Handle(901), 'EDITED', ''));
    r.markDirty(RebuildTrigger.document);
    await land(t);
    // MUTATION (M-F4): hand the previous collection's texts to the new one
    // -> 'COVERED' survives and 'EDITED' never appears.
    final texts = r.collection!.texts.map((x) => x.text).toList();
    expect(texts, contains('EDITED'));
    expect(texts, isNot(contains('COVERED')));
    expect(identical(r.backend, uploader.painters.last), isTrue);
    expect(uploader.painters.last.collection.texts.map((x) => x.text),
        contains('EDITED'),
        reason: 'the backend was built from the new collection');
  });

  testWidgets('a failed upload falls back for good: no backend, no retry',
      (t) async {
    uploader.failing = true;
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    expect(r.landed, 1);
    expect(r.backend, isNull);
    expect(r.uploadFailed, isTrue);
    r.markDirty(RebuildTrigger.document);
    r.noteFrame(zoomedAbout(fit(), centre, 3.0), kViewport, 1.0, rev());
    await land(t);
    expect(r.rebuilds, 1,
        reason: 'criterion 10: fall back once, not per frame');
    expect(r.pending, isNull);
  });

  testWidgets(
      'a throwing upload falls back for good, the same as a null upload',
      (t) async {
    uploader.throwing = true;
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    expect(r.uploadFailed, isTrue);
    expect(r.backend, isNull);
    final thrown = t.takeException();
    expect(thrown, isA<StateError>());
    expect((thrown as StateError).message, contains('upload exploded'));
    r.markDirty(RebuildTrigger.document);
    await land(t);
    expect(r.rebuilds, 1,
        reason: 'criterion 10: fall back once, not per frame');
  });

  testWidgets('a painter that lands after dispose is disposed, not installed',
      (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    uploader.gate = Completer<void>();
    await t.pump();
    expect(r.inFlight, isTrue);
    r.dispose();
    uploader.gate!.complete();
    uploader.gate = null;
    await t.pump();
    await t.pump();
    expect(uploader.painters.single.disposed, isTrue);
    expect(r.backend, isNull);
    expect(r.landed, 0);
    // tearDown disposes again; ChangeNotifier tolerates it only if we do not
    // notify after dispose -- which the assertion above already proves.
  });
}
