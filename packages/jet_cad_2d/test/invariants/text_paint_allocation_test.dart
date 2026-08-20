// Ruling 20's measurement: what one text leaf costs the frame path, against
// the cost every residual-path leaf already pays.
//
// **Why this lives in the engine suite and not beside the painter.** The
// painter is in `jet_cad_2d_flutter`, which has no `vm_service` dependency
// and no access to this directory's [AllocationMeter]. What it *does* have
// is nothing of its own: every object a text leaf allocates is allocated by
// an engine function, and the sequence below is the painter's
// `_drawText` line for line — the same composition, the same helpers, in the
// same order. Measuring it here measures the real cost of the real path; what
// it cannot see is a future painter-side allocation, which is why the
// sequence is spelled out rather than hidden behind a helper.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'vm_allocation_meter.dart';

/// Classes on the composition path, plus the ones a regression would show up
/// in. `_Float64List` is the VM's own name for a `Float64List` instance —
/// [TextLayout] carries one, so a per-leaf `TextLayout` is visible twice.
const Set<String> _watched = {
  'Transform2',
  'Vector2',
  'TextMetrics',
  'ResolvedTextAttributes',
  'TextLayout',
  '_Float64List',
};

const TextStyleRecord _style = TextStyleRecord(
    handle: ReservedHandles.standardTextStyle,
    name: 'Standard',
    fontFamily: 'Roboto');

final int _attrs = packTextAttrs(
    h: TextJustifyH.centre,
    v: TextJustifyV.top,
    overrideWidthFactor: true,
    overrideOblique: true);

/// Below this, the norm loop did not measure what it measures.
///
/// `_norm` allocates exactly one `Transform2` per iteration and returns it, so
/// the honest reading is 1.00. Anything under this is the profiler's low-read
/// artefact — see the retry block in the test.
const double _kNormFloor = 0.9;

/// The same, for the wrappers loop, whose honest reading is 9.00.
///
/// Set well below nine rather than at it: this floor exists to reject a
/// *failed read*, not to re-assert the measurement the test already makes.
const double _kWrappedFloor = 6.0;

int _sum(Map<String, int> counts) => counts.values.fold(0, (a, b) => a + b);

String _report(Map<String, int> counts, int iters) => counts.entries
    .where((e) => e.value != 0)
    .map((e) => '${e.key} ${(e.value / iters).toStringAsFixed(2)}')
    .join(', ');

void main() {
  AllocationMeter? meter;

  setUpAll(() async {
    meter = await AllocationMeter.connect();
  });

  tearDownAll(() async {
    await meter?.dispose();
  });

  test('a text leaf costs a bounded multiple of the residual-path norm',
      () async {
    final m = meter;
    if (m == null) {
      markTestSkipped(vmServiceUnavailableReason);
      return;
    }

    final payload = GeometryPayload(
      coords: Float64List.fromList([1234.5, 678.25]),
      scalars: Float64List.fromList([8.0, 0.4, 1.3, 0.2]),
    );
    final measurer = MetricModelMeasurer();
    final camera = Transform2(3.1, 0, 0, -3.1, 400, 300);
    final placement = Transform2.translation(120, 45)
        .multiply(Transform2.rotation(0.37))
        .multiply(Transform2.scale(1.7, 1.1));
    const ox = 1000.0, oy = 2000.0;

    final reused = TextLayout();

    // Warm every path past the JIT's first tier before anything is measured:
    // recompilation noise is not an allocation the frame path pays.
    for (var i = 0; i < 20000; i++) {
      _norm(camera, placement, ox, oy);
      _text(camera, placement, ox, oy, payload, measurer, reused);
      _textViaWrappers(camera, placement, ox, oy, payload, measurer);
    }

    const iters = 20000;

    // **Two of these three loops are controls with known answers, and that is
    // what makes retrying safe.** `_norm` returns one `Transform2` that
    // escapes into the result, so its true cost is exactly 1.00 per leaf;
    // `_textViaWrappers` allocates nine. Neither depends on anything the
    // subject of this test (`_text`) does. So a reading materially below
    // either is a **failed measurement, not a result**, and re-taking it
    // cannot hide a text regression — nothing `_drawText` could do would make
    // the norm loop under-report.
    //
    // It has to be guarded because the artefact is **not proportional**.
    // Ruling 31 recorded a full-suite run where all three loops read low
    // together, which a ratio absorbs. Task 14 caught the other kind: one run
    // in eleven where the norm read **0.60** while the text loop read a full
    // **1.00**, so the ratio assertion failed at 1.00035 against a bound of
    // 0.9482 — a green subject reported as a regression. That is the worst
    // failure a gate can have, because the number it prints looks like
    // evidence.
    Map<String, int> norm = const {}, text = const {}, wrapped = const {};
    var normPerLeaf = 0.0, textPerLeaf = 0.0, wrappedPerLeaf = 0.0;
    const attempts = 4;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      // (a) the composition every residual-path leaf already pays — the norm
      // circles and arcs establish, per `draft_painter.dart`.
      await m.reset();
      for (var i = 0; i < iters; i++) {
        _norm(camera, placement, ox, oy);
      }
      norm = await m.accumulatedInstances(_watched);

      // (b) what the painter does per text leaf.
      await m.reset();
      for (var i = 0; i < iters; i++) {
        _text(camera, placement, ox, oy, payload, measurer, reused);
      }
      text = await m.accumulatedInstances(_watched);

      // (c) the same answer through the immutable wrappers, so the number the
      // reduction is worth is measured rather than asserted.
      await m.reset();
      for (var i = 0; i < iters; i++) {
        _textViaWrappers(camera, placement, ox, oy, payload, measurer);
      }
      wrapped = await m.accumulatedInstances(_watched);

      normPerLeaf = _sum(norm) / iters;
      textPerLeaf = _sum(text) / iters;
      wrappedPerLeaf = _sum(wrapped) / iters;
      if (normPerLeaf >= _kNormFloor && wrappedPerLeaf >= _kWrappedFloor) break;
      printOnFailure('attempt $attempt discarded: norm '
          '${normPerLeaf.toStringAsFixed(2)}, wrappers '
          '${wrappedPerLeaf.toStringAsFixed(2)} — the profiler under-reported');
    }

    // Four bad reads in a row is the profiler, not the code. Failing here
    // rather than falling through keeps a broken measurement from being
    // published as a text regression.
    expect(normPerLeaf, greaterThanOrEqualTo(_kNormFloor),
        reason: 'the allocation profiler under-reported the control loop in '
            'all $attempts attempts (last: ${_report(norm, iters)} per leaf, '
            'true value one Transform2). This is a meter failure; nothing is '
            'known about the text path from this run.');
    expect(wrappedPerLeaf, greaterThanOrEqualTo(_kWrappedFloor),
        reason: 'the allocation profiler under-reported the wrappers loop in '
            'all $attempts attempts (last: ${_report(wrapped, iters)} per '
            'leaf, true value nine allocations)');
    printOnFailure('norm     ${normPerLeaf.toStringAsFixed(2)}/leaf: '
        '${_report(norm, iters)}');
    printOnFailure('text     ${textPerLeaf.toStringAsFixed(2)}/leaf: '
        '${_report(text, iters)}');
    printOnFailure('wrappers ${wrappedPerLeaf.toStringAsFixed(2)}/leaf: '
        '${_report(wrapped, iters)}');

    // **Every assertion below is a ratio against the norm, deliberately.**
    // An absolute count is not safe here: this profiler was observed once, in
    // a full concurrent suite run, to report 0.07 per leaf where two other
    // runs of the same code reported 1.00 — the low-read artefact
    // `vm_allocation_meter.dart` documents. That artefact scales all three
    // loops together, so a ratio survives it where a threshold does not.

    // **Ruling 20's recorded answer.** Measured here: the norm is 1.00
    // allocation per leaf (one `Transform2`; the VM scalar-replaces the two
    // intermediates), the painter's text leaf is **0.87** — below the norm,
    // because escape analysis reaches some of the residuals here too — and
    // the same answer through `resolveTextAttributes` +
    // `textLocalTransform` is **9.00**: two
    // `TextLayout`s and their `Float64List`s, a `ResolvedTextAttributes`, a
    // `Vector2` and its `Float64List`, and an intermediate `Transform2`.
    //
    // So text is **at or below** the per-leaf norm circles and arcs already
    // establish, and the spec's second reusable `Float64List(16)` in
    // `CanvasDrawSink` is not needed: under the plan's shape the sink
    // composes nothing, and the residual `Transform2` itself is the one
    // allocation neither path can avoid — `DrawSink.beginResidual` takes an
    // immutable `Transform2`, so the frame pays at most one per leaf that
    // pushes one, text or not.
    expect(textPerLeaf, lessThanOrEqualTo(normPerLeaf * 1.5 + 0.05),
        reason: 'a text leaf must cost no more than any other residual-path '
            'leaf: text ${_report(text, iters)} vs norm '
            '${_report(norm, iters)} per leaf');

    // The reduction is real and stays measured: if the wrappers ever became
    // allocation-free the reusable layout would be dead weight, and if the
    // painter ever went back through them this is what would say so.
    expect(wrappedPerLeaf, greaterThan(normPerLeaf * 3),
        reason: 'wrappers ${_report(wrapped, iters)} vs '
            'norm ${_report(norm, iters)} per leaf');
  });
}

/// The chain every residual-path leaf composes, per `_drawLeafComposed`.
Transform2 _norm(
        Transform2 camera, Transform2 placement, double ox, double oy) =>
    camera.multiply(placement).multiply(Transform2.translation(ox, oy));

/// The same chain, then everything `_drawText` adds to reach the residual it
/// pushes — through the painter's own long-lived [TextLayout].
Transform2 _text(Transform2 camera, Transform2 placement, double ox, double oy,
    GeometryPayload payload, TextMeasurer measurer, TextLayout reused) {
  final chain = _norm(camera, placement, ox, oy);
  final metrics = measurer.measure(text: 'KITCHEN', style: _style);
  final layout = reused
    ..resolve(payload, _attrs, _style)
    ..composeTransform(metrics, payload.coords[0] - ox, payload.coords[1] - oy);
  return chain.multiply(
      Transform2(layout.a, layout.b, layout.c, layout.d, layout.e, layout.f));
}

/// The same work through the immutable wrappers — what the reference walk
/// does, and what the painter did before Ruling 20's measurement.
Transform2 _textViaWrappers(Transform2 camera, Transform2 placement, double ox,
    double oy, GeometryPayload payload, TextMeasurer measurer) {
  final chain = _norm(camera, placement, ox, oy);
  final attrs = resolveTextAttributes(payload, _attrs, _style);
  final metrics = measurer.measure(text: 'KITCHEN', style: _style);
  final anchor = Vector2(payload.coords[0] - ox, payload.coords[1] - oy);
  return chain.multiply(textLocalTransform(attrs, metrics, anchor));
}
