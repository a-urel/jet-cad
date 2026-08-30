### Task 9: The pixel differential against `VerticesDrawSink`

**Files:**
- Create: `test/support/gpu_comparison.dart`
- Create: `test/gpu/resident_pixel_differential_test.dart`
- Modify: `test/gpu/collector_differential_test.dart`

**Interfaces:**
- Consumes: `expandInstances` (Task 8), `TriangleRasterizer`
  (`test/support/triangle_rasterizer.dart`), `GeometryCollector`,
  `VerticesDrawSink`.
- Produces: `ResidentAgreement measureResidentAgreement(...)` and the gate that
  spec criterion 1 is measured by.

**This is the task the plan exists to reach.** Everything before it is
geometry that nothing compares against a picture. Read
`test/support/sink_comparison.dart` first: it already does this shape of work
for `CanvasDrawSink` versus `VerticesDrawSink`, including the ink floor and the
permitted-divergence table, and this file should look like its sibling rather
than like a new invention.

- [ ] **Step 1: Read the existing machinery**

```bash
cd packages/jet_cad_2d_flutter
sed -n '1,140p' test/support/sink_comparison.dart
sed -n '1,80p' test/support/triangle_rasterizer.dart
```

Report, in one paragraph, what `AgreementReport` counts and what
`TriangleRasterizer.observe` expects. If either does something this task's
sample code below assumes wrongly, **follow the code, not the sample**, and say
so.

- [ ] **Step 2: Write the comparison helper**

`test/support/gpu_comparison.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'instance_expander.dart';
import 'triangle_rasterizer.dart';

/// What a resident-versus-reference comparison counted.
class ResidentAgreement {
  ResidentAgreement({
    required this.referenceInk,
    required this.residentInk,
    required this.differing,
    required this.overEight,
  });

  /// Pixels the reference inked.
  final int referenceInk;

  /// Pixels the resident arm inked.
  final int residentInk;

  /// Pixels differing by more than 2 on any channel.
  final int differing;

  /// Pixels differing by more than 8 on any channel.
  final int overEight;

  @override
  String toString() => 'ResidentAgreement(referenceInk: $referenceInk, '
      'residentInk: $residentInk, differing: $differing, '
      'overEight: $overEight)';
}

/// Draws [draw] through both arms at [size] and counts their disagreement.
///
/// **Both arms go through the same rasterizer.** The question this answers is
/// whether the collector plus the vertex shader produce the same triangles as
/// `VerticesDrawSink`, not whether two rasterizers agree — so the rasterizer
/// is held fixed and only the triangle source changes. A GPU comparison is
/// Task 11's device run; this is what `flutter test` can gate.
ResidentAgreement measureResidentAgreement(
  void Function(DrawSink sink) draw, {
  required Size size,
  required double devicePixelRatio,
  required double pixelsPerPaperMm,
}) {
  final w = (size.width * devicePixelRatio).round();
  final h = (size.height * devicePixelRatio).round();

  // The reference arm: `VerticesDrawSink`'s own triangles.
  final referenceRaster = TriangleRasterizer(w, h);
  final recorder = PictureRecorder();
  final sink = VerticesDrawSink(
    canvas: Canvas(recorder),
    pixelsPerPaperMm: pixelsPerPaperMm,
    devicePixelRatio: devicePixelRatio,
  )..observer = referenceRaster.observe;
  // The sink works in logical pixels and the rasterizer in device ones, so
  // the drawing is scaled into device space before it starts. This mirrors
  // what `sink_comparison.dart` does for the canvas arm.
  sink.beginResidual(Transform2.scale(devicePixelRatio, devicePixelRatio));
  draw(sink);
  sink.endResidual();
  sink.flush();
  recorder.endRecording().dispose();

  // The resident arm: the collector's buffer, expanded by the Dart copy of
  // the vertex shader. The collector already emits device-pixel half-widths,
  // so its geometry is scaled into device space by the same transform and
  // the expander is handed the identity.
  final collector = GeometryCollector(
      pixelsPerPaperMm: pixelsPerPaperMm, devicePixelRatio: devicePixelRatio);
  collector.beginResidual(Transform2.scale(devicePixelRatio, devicePixelRatio));
  draw(collector);
  collector.endResidual();
  final expanded = expandInstances(
      collector.data, collector.instanceCount, Transform2.identity());
  final residentRaster = TriangleRasterizer(w, h)
    ..observe(expanded.positions, expanded.colors);

  var referenceInk = 0, residentInk = 0, differing = 0, overEight = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final a = referenceRaster.inked(x, y);
      final b = residentRaster.inked(x, y);
      if (a) referenceInk++;
      if (b) residentInk++;
      if (a != b) {
        differing++;
        overEight++;
      }
    }
  }
  return ResidentAgreement(
      referenceInk: referenceInk,
      residentInk: residentInk,
      differing: differing,
      overEight: overEight);
}
```

**`TriangleRasterizer` is coverage-only** — `inked(x, y)` is a boolean, not a
colour — so `differing` and `overEight` are the same number here and the
per-channel half of spec criterion 1 is **not** measured by this instrument.
State that in the file's doc comment and in the results note. Colour agreement
is gated separately, by the record-level assertions in Tasks 3-6 and by the
extended `collector_differential_test.dart` in Step 5 below. **Do not describe
this as a full criterion-1 measurement.** If `TriangleRasterizer` turns out to
carry colour after all, use it and say so.

- [ ] **Step 3: Write the differential test**

`test/gpu/resident_pixel_differential_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/gpu_comparison.dart';

const Size _size = Size(400, 300);
const double _dpr = 2.0;
const double _ppmm = 3.7795275590551185;

const ResolvedStyle _thick =
    ResolvedStyle(argb: 0xFF102030, lineweightHundredths: 50);
const ResolvedStyle _hairline =
    ResolvedStyle(argb: 0xFF102030, lineweightHundredths: 5);

/// Every shape Plan B draws, at a scale and an offset chosen so nothing sits
/// on the identity transform, the origin, or an axis.
///
/// **Each element is here because a named mutation needs it**, and the test
/// below says which:
///  - the zigzag has three corners, one left turn and one right, so a sign
///    error in `s` shows on one of them;
///  - the hairpin turns past the miter limit, so the bevel path runs;
///  - the circle is closed, so the seam join runs and its absence is a notch;
///  - the point is a `point()` op;
///  - the hairline is under one device pixel, so `_coveredArgb` runs.
void _corpus(DrawSink sink) {
  sink.polyline(
      Float64List.fromList(<double>[20, 40, 90, 40, 90, 110, 160, 110, 160, 40]),
      5,
      _thick,
      closed: false);
  sink.polyline(
      Float64List.fromList(<double>[30, 160, 120, 165, 32, 170]), 3, _thick,
      closed: false);
  sink.circle(260, 90, 55, _thick);
  sink.arc(120, 230, 45, 0.4, 2.1, _thick);
  sink.point(340, 210, _thick);
  sink.polyline(
      Float64List.fromList(<double>[20, 260, 380, 268]), 2, _hairline,
      closed: false);
}

void main() {
  test('the resident arm draws the reference drawing', () {
    final r = measureResidentAgreement(_corpus,
        size: _size, devicePixelRatio: _dpr, pixelsPerPaperMm: _ppmm);

    // The anti-vacuity floor, the same one `tile_cache_test.dart:958-959`
    // uses: a comparison of two blank frames agrees perfectly and measures
    // nothing. This corpus must actually put ink on the canvas.
    expect(r.referenceInk, greaterThan(5000), reason: r.toString());
    expect(r.residentInk, greaterThan(5000), reason: r.toString());

    // Spec criterion 1's ink threshold: differing pixels below 1% of live
    // ink. This instrument is coverage-only, so this is the whole of what it
    // can assert -- the per-channel half of criterion 1 is gated by the
    // record-level colour assertions in Tasks 3 to 6.
    expect(r.differing, lessThan(r.referenceInk ~/ 100), reason: r.toString());
  });

  test('the seam join is load-bearing on the circle', () {
    // Not a mutation run in a comment: this measures the notch the seam join
    // fills, by drawing the same circle as an OPEN run of the same chords.
    // If the numbers came out equal, the corpus test above could not see a
    // missing seam either.
    double inkOf(void Function(DrawSink) draw) => measureResidentAgreement(
          draw,
          size: _size,
          devicePixelRatio: _dpr,
          pixelsPerPaperMm: _ppmm,
        ).residentInk.toDouble();

    final closed = inkOf((s) => s.circle(200, 150, 90, _thick));
    // A 2*pi arc is the same chords, open: no closing chord and no seam.
    final open =
        inkOf((s) => s.arc(200, 150, 90, 0, 6.283185307179586, _thick));
    expect(closed, greaterThan(open),
        reason: 'the closed circle has the closing chord and the seam; '
            'closed=$closed open=$open');
  });
}
```

- [ ] **Step 4: Run it**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/resident_pixel_differential_test.dart
```

**Expect this to fail the first time and treat the failure as information.**
Paste `r.toString()` from the failure. Likely causes, in the order to check
them:

1. The two arms are in different spaces — the sink works in logical pixels and
   the collector already carries device half-widths. Re-derive the scaling in
   `measureResidentAgreement` from what each class documents about its own
   space, rather than adjusting until the number falls.
2. The rasterizer's `observe` expects a different tuple than the expander
   produces.
3. A genuine geometry defect from Tasks 4-6.

**If the differing count is small but non-zero, do not raise the threshold.**
Report the number, say where the pixels are (a boundary sliver, a miter tip,
the hairline), and let the reviewer decide. A threshold moved to make a
criterion pass is the one thing this plan's gate forbids.

- [ ] **Step 5: Extend the Plan A collector differential**

`test/gpu/collector_differential_test.dart` rebuilds an expected segment list
from a `RecordingDrawSink` and compares it slot by slot. Joins now sit between
those segments, so it fails. Fix it by **teaching the oracle about joins**, not
by skipping them:

- Where the loop walks a `PolylineOp`'s points, mirror the run state machine:
  expect `join` before every interior segment, and on `closed` the closing
  segment then the seam.
- Assert the kind of every instance, not only the strokes. The Plan A ledger
  records that the old kind assertion *"would pass on a genuinely unwritten
  slot and cannot catch a wrong-kind-among-several defect. Resolves itself
  when Plan B adds a second kind"* — this is that resolution, and it must
  actually discriminate.
- The alpha comparison the Plan A ledger deferred is now live: compare the
  full `argb`, and add one hairline entity to `differentialFixture` (or, if
  changing the shared fixture would disturb other suites, build the hairline
  case as a second local fixture in this file and say which you chose and
  why).

- [ ] **Step 6: Fire the corpus mutations**

Each is fired against the **production** file, with a `cp` backup, and each
must go red on `resident_pixel_differential_test.dart`:

```bash
cd packages/jet_cad_2d_flutter
cp lib/src/gpu/geometry_collector.dart /tmp/gc.bak
cp test/support/instance_expander.dart /tmp/ie.bak

# M-B3' (seam) : delete the seam-join block in `_endRun`.
# M-B7 (join side) : flip `s` in the expander -- `crossZ > 0 ? halfWidth : -halfWidth`.
# M-B8 (point as stroke) : in `point()`, emit `writeStroke` from (x-half, y) to
#   (x+half, y) instead of `writePoint`.
# M-B1' (hairline) : drop `_coveredArgb` from `polyline`.
```

Run the differential test after each and restore from the backup. Paste all
four transcripts. **M-B1' may survive**, because the rasterizer is
coverage-only and a fade changes colour, not coverage. If it does, **record it
as a survivor with that reason** and point at the record-level test in Task 3
as its gate of record. Do not invent a coverage difference to kill it.

- [ ] **Step 7: Gate and commit**

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
git add packages/jet_cad_2d_flutter/test
git commit -m "test(gpu): the resident arm is compared against the reference in pixels"
```

---

