import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

import '../support/fixtures.dart';

void main() {
  late FlutterTextMeasurer measurer;
  late DraftDocument doc;
  late SpatialIndex index;
  late DraftPainter painter;

  setUp(() {
    measurer = FlutterTextMeasurer();
    doc = textOverlapFixture(measurer);
    index = SpatialIndex(doc);
    // Level of detail OFF: this fixture's TINY label sits at the culling
    // threshold on purpose, and a scale-dependent cull would make two
    // collections at two scales differ for a reason that is not culling to
    // the viewport. Ruling F6 measures that divergence in its own test.
    painter = DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        minTextCapPixels: 0);
  });
  tearDown(() {
    index.dispose();
    measurer.clear();
  });

  ResidentCollection collect(ViewportTransform live, {double dpr = 1.0}) =>
      ResidentCollection.collect(
          document: doc,
          painter: painter,
          live: live,
          devicePixelRatio: dpr,
          pixelsPerPaperMm: kLogicalPixelsPerMm,
          lineweightScale: 1.0,
          measurer: measurer,
          textStyleOf: doc.textStyleOf);

  ViewportTransform fit() => ViewportTransform.fit(doc.extents, kViewport);

  /// 8x the fit scale, with the drawing's top-left corner near the screen's
  /// origin: the live viewport sees roughly a sixty-fourth of the drawing.
  ViewportTransform corner() {
    final s = fit().scale * 8;
    final e = doc.extents;
    return ViewportTransform(
        worldToScreenMatrix:
            Transform2(s, 0, 0, -s, -s * e.minX + 5, s * e.maxY + 5));
  }

  test('the corner camera sees only part of the drawing', () {
    // Anti-vacuity for the test below.
    final vis = corner().visibleWorld(kViewport);
    expect(vis.intersects(doc.extents), isTrue);
    expect(vis.maxX < doc.extents.maxX || vis.minY > doc.extents.minY, isTrue,
        reason: 'the live viewport must see only part of the drawing, or '
            'culling to it would be invisible here');
  });

  test('a collection at the corner zoom holds everything the fit one holds',
      () {
    final a = collect(fit());
    final b = collect(corner());
    // MUTATION: collect under `live` and `kViewport` instead of the frame
    // -> b.instanceCount is a fraction of a.instanceCount, b.texts shorter.
    expect(b.instanceCount, a.instanceCount,
        reason: 'this fixture has no curve, so the instance count is scale-'
            'free; a difference is culling');
    expect(b.texts.map((t) => t.text), a.texts.map((t) => t.text));
    expect(a.instanceCount, greaterThan(5));
    expect(a.texts.length, 4, reason: 'COVERED, UNDER, GRAZED, TINY');
    expect(a.skippedOps, 0);
  });

  test('the collection camera differs from the live camera by a translation',
      () {
    final live = corner();
    final c = collect(live);
    final toLive = composeTransforms(live.worldToScreenMatrix,
        c.collectionCamera.worldToScreenMatrix.invert());
    expect(toLive.a, closeTo(1, 1e-12));
    expect(toLive.d, closeTo(1, 1e-12));
    expect(c.collectionCamera.scale, closeTo(live.scale, 1e-12));
    expect(c.collectionViewport.width, greaterThan(kViewport.width),
        reason: 'at 8x the extents are wider than the live viewport');
  });

  test('the table revision and the ratio are the ones the walk ran at', () {
    final before = doc.tables.mutationRevision;
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
    expect(doc.tables.mutationRevision, greaterThan(before));
    final c = collect(fit(), dpr: 2.0);
    expect(c.tablesRevision, doc.tables.mutationRevision);
    expect(c.devicePixelRatio, 2.0);
  });

  test('half-widths follow the device pixel ratio', () {
    double widest(ResidentCollection c) {
      var w = 0.0;
      for (var i = 0; i < c.instanceCount; i++) {
        final o = i * kFloatsPerInstance;
        if (c.data[o + InstanceFieldOffset.kind] != kKindStroke) continue;
        final h = c.data[o + InstanceFieldOffset.halfWidth];
        if (h > w) w = h;
      }
      return w;
    }

    final one = widest(collect(fit()));
    final two = widest(collect(fit(), dpr: 2.0));
    expect(one, greaterThan(GeometryCollector.kMinStrokeDevicePixels),
        reason: 'the widest stroke must be above the floor, or the floor '
            'clamps both and the ratio below is vacuous');
    expect(two, closeTo(2 * one, 1e-3));
  });

  test('the timings are read and the byte length counts the patches', () {
    final c = collect(fit());
    expect(c.walkMicros, greaterThanOrEqualTo(0));
    expect(c.classifyMicros, greaterThanOrEqualTo(0));
    expect(c.patches.length, 2, reason: 'COVERED and GRAZED (Plan E)');
    expect(
        c.byteLength,
        ResidentGeometry.byteLengthFor(c.instanceCount,
            patchInstances: c.patchInstanceCount));
    expect(c.patchInstanceCount, greaterThan(0));
  });
}
