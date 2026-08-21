// What a steady-state frame allocates through the vertices sink.
//
// `CLAUDE.md`: "The frame path allocates nothing in steady state."
// `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` measures the
// query path and stops there. This measures the paint path, which is the half
// the vertices sink changes.
//
// The property has an exact answer, so this needs no sampling profiler: once
// a frame has drawn its widest view, `_reserve` never gives capacity back, so
// [VerticesDrawSink.debugCapacityVertices] either holds still across a later
// frame or it does not. A profiler would only add noise to a question that
// reduces to reading a field. The warm-up runs the corpus three times so
// growth is behind the buffer before anything is measured; the subject
// frame's capacity is then read before and after and compared for equality.
// What is left once the buffer stops growing is the residue the sink's class
// comment states as a fact: three objects per flush -- the `Vertices` and the
// two `sublistView` wrappers -- and nothing per entity, `3 * (textOps + 1)`
// per frame.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/spy_canvas.dart';

const Size _viewport = Size(800, 600);

/// Fraction of [_addFillRegions]'s closed polylines that gain a region
/// partner (a fill); the rest are added as plain closed boundaries, stroked
/// but not filled. Mirrors `kFillFraction` in
/// `apps/dev_harness_2d/lib/main.dart` -- the same quota-accumulator shape,
/// applied independently here because this corpus lives in a different
/// package and cannot share that file's stream.
const double _fillFraction = 0.4;

DraftDocument _corpus() {
  final doc = generateDocument(
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
  // Task 16: the allocation gate must run its two-flush comparison on a
  // corpus containing fills -- a cache *miss* on the frame path would show up
  // here immediately as a per-fill allocation, which is a second, independent
  // proof (alongside the load-cost row) that triangulations are materialised
  // eagerly at write time and never lazily on the frame path.
  _addFillRegions(doc, seed: 0xFEEDFACE, count: 200, fraction: _fillFraction);
  return doc;
}

/// Adds [count] closed-polyline rooms to [doc], scattered around
/// [kDefaultOriginX]/[kOriginY] the way `generateDocument`'s own floor
/// entities are. [fraction] of them are added as an [AddRegionCommand] pair
/// (a fill under a boundary), via the same quota-accumulator shape
/// `_Styling.linetypeFor` in `generate_document.dart` uses -- a fraction
/// specifies the corpus exactly, not on average; the rest are added as plain
/// closed [EntityKind.polyline] boundaries with no fill.
void _addFillRegions(DraftDocument doc,
    {required int seed, required int count, required double fraction}) {
  final random = math.Random(seed);
  var fillDue = 0.0;
  for (var i = 0; i < count; i++) {
    final x0 = kDefaultOriginX + random.nextDouble() * kFloorWidth;
    final y0 = kOriginY + random.nextDouble() * kFloorHeight;
    final w = 100.0 + random.nextDouble() * 400.0;
    final h = 100.0 + random.nextDouble() * 300.0;
    final coords = Float64List.fromList([
      x0, y0, //
      x0 + w, y0, //
      x0 + w, y0 + h, //
      x0, y0 + h, //
      x0, y0, // closing duplicate: first == last, exactly.
    ]);
    final payload = GeometryPayload(coords: coords, scalars: Float64List(0));

    fillDue += fraction;
    if (fillDue >= 1.0) {
      fillDue -= 1.0;
      doc.commands.execute(AddRegionCommand.allocate(
        seed: doc.handleSeed,
        owner: doc.rootHandle,
        boundaryKind: EntityKind.polyline,
        boundaryPayload: payload,
        layer: ReservedHandles.layerZero,
        fillColor: const TrueColor(0x3366CC),
        boundaryColor: const TrueColor(0x000000),
      ));
    } else {
      final handle = doc.handleSeed.next();
      doc.commands.execute(AddEntityCommand(
        record: EntityRecord(
          handle: handle,
          owner: doc.rootHandle,
          kind: EntityKind.polyline,
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.byLayerLinetype,
          linetypeScale: 1.0,
          geomIndex: 0,
          color: const ByLayerColor(),
          lineweight: kByLayer,
          transparency: kByLayer,
          flags: 0,
        ),
        payload: payload,
      ));
    }
  }
}

/// A document with many fills, for the load-cost row Task 16 owes: eager
/// materialisation at write time moves the triangulation cost to load time
/// rather than removing it, and that row must be measured and printed, with
/// no threshold.
DraftDocument fillHeavyCorpus() {
  final doc = DraftDocument.empty();
  // Every one of these is a region: `fraction: 1.0` so the count of fills
  // created is exactly `count`, not a quota's rounded outcome.
  _addFillRegions(doc, seed: 0xC0FFEE, count: 5000, fraction: 1.0);
  return doc;
}

void main() {
  testWidgets('a steady-state frame allocates O(1) per flush, not O(entities)',
      (tester) async {
    final doc = _corpus();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final camera = ViewportTransform.fit(doc.extents, _viewport);

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final sink =
        VerticesDrawSink(pixelsPerPaperMm: kLogicalPixelsPerMm, canvas: canvas);

    // Warm up: the first frame grows the buffers, and growth is exactly what
    // the steady state is defined as being past.
    for (var i = 0; i < 3; i++) {
      painter.paint(sink, camera, _viewport);
      sink.flush();
    }

    // The subject frame. Flushes are counted, not assumed: the assertion below
    // is in units of flushes, so a frame that stopped flushing would make it
    // vacuous.
    sink.resetCounters();
    painter.paint(sink, camera, _viewport);
    sink.flush();

    expect(sink.totalFlushCount, greaterThan(0),
        reason: 'nothing was flushed, so nothing was measured');
    expect(sink.frameTriangleCount, greaterThan(1000),
        reason: 'a degenerate corpus would make the bound meaningless');
    // Task 16: this corpus must actually contain fills, and every one of them
    // must draw -- an empty or all-skipped fill population would make the
    // gate below vacuous for the one path it exists to cover.
    expect(painter.fillCount, greaterThan(0),
        reason: 'the corpus carries no fills, so this gate proves nothing '
            'about fill triangulation being cached rather than allocated on '
            'the frame path');
    expect(painter.skippedFillCount, 0,
        reason: 'every fill this corpus adds is a valid, closed, simple '
            'rectangle -- none of them should be unresolvable');

    // The buffer must not have grown in the subject frame. Growth is the one
    // O(entities) allocation this sink can make, and it is the one the
    // steady-state claim is about.
    //
    // MUTATION: drop `_reserve`'s capacity-sufficiency guard and
    // unconditionally double, so every segment regrows the buffer instead of
    // only a call that needs more room. `debugCapacityVertices` no longer
    // holds still between the two reads -- it compounds every segment of the
    // frame and the run in fact throws an `OutOfMemoryError` from
    // `_reserve`'s `Float32List` allocation long before either `expect`
    // below runs, which is the steady-state property failing as loudly as
    // it can.
    final before = sink.debugCapacityVertices;
    final paintBefore = sink.debugPaint;
    painter.paint(sink, camera, _viewport);
    sink.flush();
    expect(sink.debugCapacityVertices, before,
        reason: 'the buffer grew in a steady-state frame, so the frame path '
            'allocates O(entities) and not O(1)');
    // MUTATION: reassign the `_paint` field to a fresh `Paint` inside
    // `flush()` instead of reusing the one built for the sink's life.
    // `debugCapacityVertices` cannot see this -- a `Paint` is not part of
    // either buffer -- so the field's identity is pinned directly. Confirmed
    // empirically: `_paint = Paint()..color = const Color(0xFFFFFFFF);`
    // right before `canvas.drawVertices` in `flush()` leaves the two prior
    // assertions green and fails only this one, `identical` reading false.
    //
    // **This assertion alone is narrower than the property's name.** It pins
    // that the *field* is not reassigned; it says nothing about what is
    // actually handed to `canvas.drawVertices`, because it never looks at
    // the call. A mutation that constructs a fresh, call-site-local `Paint`
    // and passes *that* to `drawVertices` -- `Paint()..color = const
    // Color(0xFFFFFFFF)` written inline, `_paint` never touched -- satisfies
    // this `identical` check (the field genuinely did not change) while
    // still allocating a `Paint` every flush. See the test below, which
    // reads what `dart:ui` actually received and is the one that closes A1.
    expect(identical(sink.debugPaint, paintBefore), isTrue,
        reason: 'flush() must reuse the one Paint built for the sink\'s '
            'life, not build a fresh one per call');

    recorder.endRecording().dispose();
  });

  test(
      'flush hands drawVertices the same Paint object every time, not a '
      'call-site-local one', () {
    // The test above pins that the `_paint` *field* is not reassigned, which
    // a mutation that builds a fresh, call-site-local `Paint` and passes it
    // straight to `drawVertices` -- never touching the field -- survives.
    // This reads what `dart:ui` actually received, through `SpyCanvas`,
    // which is the only way to see the difference: identity of the object
    // handed to the call, not of the field.
    final spy = SpyCanvas();
    final sink = VerticesDrawSink(pixelsPerPaperMm: kLogicalPixelsPerMm)
      ..canvas = spy;
    const style = ResolvedStyle(
      argb: 0xFF000000,
      lineweightHundredths: 25,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
    );
    for (var i = 0; i < 2; i++) {
      sink
        ..beginResidual(Transform2.identity())
        ..polyline(
            Float64List.fromList([0, i.toDouble(), 10, i.toDouble()]), 2, style,
            closed: false)
        ..endResidual()
        ..flush();
    }

    final calls = spy.named('drawVertices').toList();
    expect(calls.length, 2, reason: 'one drawVertices per flush');
    final paints = calls
        .map((c) => c.args.whereType<Paint>().single)
        .toList(growable: false);
    // MUTATION: replace `_paint` in the `drawVertices` call with a fresh,
    // call-site-local `Paint()..color = const Color(0xFFFFFFFF)`, never
    // touching the field -- confirmed empirically: the test above and every
    // other test in the suite stay green under this exact mutation, and
    // only this `identical` check goes red.
    expect(identical(paints[0], paints[1]), isTrue,
        reason: 'flush() must hand drawVertices the one Paint built for the '
            "sink's life, not a fresh one per call");
  });

  test('load-time triangulation cost, recorded', () {
    // The row eager materialisation owes: `AddRegionCommand` and the codec's
    // loader both triangulate at write/load time precisely so the frame path
    // never has to, per the allocation gate above. That work has to land
    // somewhere, and this is where -- no threshold, but no plan may skip the
    // row.
    final corpus = fillHeavyCorpus();
    const n = 5000;
    expect(corpus.fills.linkCount, n,
        reason: 'fillHeavyCorpus() must actually carry the fill count this '
            'row claims to measure the load cost of');
    final json = DraftDocumentCodec.encodeToString(corpus);
    final sw = Stopwatch()..start();
    DraftDocumentCodec.decodeString(json);
    sw.stop();
    // ignore: avoid_print
    print('LOAD fills=$n elapsed=${sw.elapsedMilliseconds}ms');
  });
}
