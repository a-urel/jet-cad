# Task 10 report — the mutation log

## What this task did

Collected every mutation transcript pasted into Tasks 3, 4, 5, 6, 8 and 9's
reports (and the fix-round entries embedded in `progress.md` for the ones
whose reports predate the fix round, e.g. M-B12) into one document of
record, fired the two mutations no earlier task had fired (M-B9, M-B10),
and wrote the whole set up with derivations for the survivor and the
equivalent mutation, per the brief.

Deliverable: `docs/superpowers/notes/plan-b-mutation-log.md`.

No production code changes land from this task — every mutation fired here
was applied with a `cp` backup, run once, and restored, verified
byte-identical. The only file this task adds to the tree is the mutation
log itself.

## M-B9 — sort the instance buffer by kind before upload

Not fired by any earlier task. Fired directly against
`packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart`.

Backup:

```
$ cd packages/jet_cad_2d_flutter
$ cp lib/src/gpu/geometry_collector.dart <scratch>/gc_t10.bak
$ md5 lib/src/gpu/geometry_collector.dart <scratch>/gc_t10.bak
MD5 (lib/src/gpu/geometry_collector.dart) = 83f77567826de4359b5e016c1418c7fc
MD5 (<scratch>/gc_t10.bak) = 83f77567826de4359b5e016c1418c7fc
```

Exact edit, in the `data` getter:

```diff
-  Float32List get data => _buffer.sublist(0, _instances * kFloatsPerInstance);
+  Float32List get data {
+    // M-B9: sort the instance buffer by kind before upload.
+    final flat = _buffer.sublist(0, _instances * kFloatsPerInstance);
+    final records = List<int>.generate(_instances, (i) => i)
+      ..sort((a, b) => flat[a * kFloatsPerInstance]
+          .compareTo(flat[b * kFloatsPerInstance]));
+    final out = Float32List(flat.length);
+    for (var i = 0; i < records.length; i++) {
+      out.setRange(i * kFloatsPerInstance, (i + 1) * kFloatsPerInstance, flat,
+          records[i] * kFloatsPerInstance);
+    }
+    return out;
+  }
```

Command:

```
$ flutter test test/gpu/geometry_collector_test.dart test/gpu/collector_differential_test.dart; echo "exit=$?"
```

Verbatim output (full transcript; nine tests went red):

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
00:00 +0: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: applies the residual, and a transposed one is not the same residual
00:00 +1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: emits one instance per segment, in walk order
00:00 +1 -1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: emits one instance per segment, in walk order [E]
  Expected: <1.0>
    Actual: <0.0>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 73:5          main.<fn>

00:00 +1 -1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: closed: true emits a closing segment back to the first point
00:00 +1 -2: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr
00:00 +1 -2: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: closed: true emits a closing segment back to the first point [E]
  Expected: [1.0, 0.0, 1.0, 1.0]
    Actual: [1.0, 1.0, 0.0, 0.0]
     Which: at location [1] is <1.0> instead of <0.0>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 102:5         main.<fn>

00:00 +2 -2: .../collector_differential_test.dart: emits every polyline segment...
00:00 +3 -2: .../collector_differential_test.dart: emits every polyline segment...
00:00 +4 -2: .../collector_differential_test.dart: emits every polyline segment...
00:00 +5 -2: .../collector_differential_test.dart: emits every polyline segment...
00:00 +6 -2: .../collector_differential_test.dart: emits every polyline segment...
00:00 +7 -2: .../collector_differential_test.dart: emits every polyline segment...
00:00 +8 -2: .../collector_differential_test.dart: emits every polyline segment...
00:00 +8 -3: .../collector_differential_test.dart: emits every polyline segment...
00:00 +8 -3: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: an open three-point run is join-before-segment, and nothing else [E]
  Expected: [0.0, 1.0, 0.0]
    Actual: [0.0, 0.0, 1.0]
     Which: at location [1] is <0.0> instead of <1.0>
  the join is written BEFORE the segment that follows it

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 267:5         main.<fn>

00:00 +8 -4: .../collector_differential_test.dart: emits every polyline segment...
00:00 +8 -4: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: the join carries the corner and both its neighbours [E]
  Expected: <0>
    Actual: <40.0>
  the previous point

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 293:5         main.<fn>

00:00 +8 -5: .../collector_differential_test.dart: emits every polyline segment...
00:00 +8 -5: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: a closed run emits the closing segment and then the seam join [E]
  Expected: [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
    Actual: [0.0, 0.0, 0.0, 1.0, 1.0, 1.0]
     Which: at location [1] is <0.0> instead of <1.0>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 315:5         main.<fn>

00:00 +8 -6: .../collector_differential_test.dart: emits every polyline segment...
00:00 +8 -6: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: a repeated point is spanned by the join, not turned into one [E]
  Expected: <0>
    Actual: <40.0>
  the incoming neighbour is still the first point

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 354:5         main.<fn>

00:00 +9 -6: .../collector_differential_test.dart: emits every polyline segment...
00:00 +10 -6: .../collector_differential_test.dart: emits every polyline segment...
00:00 +11 -6: .../collector_differential_test.dart: emits every polyline segment...
00:00 +11 -7: .../collector_differential_test.dart: emits every polyline segment...
00:00 +11 -8: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: an arc is an open run and has no seam [E]
  Expected: <0.0>
    Actual: <1.0>
  an open run ends on a segment -- butt caps, no seam

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 469:5         main.<fn>

00:00 +11 -8: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: a non-uniform residual makes an ellipse, not a scaled circle
00:00 +12 -8: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: a negative sweep runs clockwise, not mirrored
00:00 +12 -9: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: a negative sweep runs clockwise, not mirrored [E]
  Expected: <0.0>
    Actual: <1.0>
  an open run ends on a segment

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 548:5         main.<fn>

00:00 +12 -9: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: a zero or negative radius draws nothing
00:00 +13 -9: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: a point is one instance of its own kind, at the transformed position
00:00 +14 -9: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: a point takes the hairline fade like a stroke
00:00 +14 -9: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr [E]
  Expected: a numeric value within <0.001> of <79.58204339388764>
    Actual: <503.868896484375>
     Which:  differs by <424.28685309048734>
  instance 0 x0

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/collector_differential_test.dart 210:5     _checkAgainstOracle
  test/gpu/collector_differential_test.dart 49:5      main.<fn>

00:00 +15 -9: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: after Plan B, only fills and text are skipped
00:00 +16 -9: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart: fades a hairline stroke exactly as the reference sink does, not just strokes above the floor
00:00 +17 -9: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: a closed run emits the closing segment and then the seam join
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: a negative sweep runs clockwise, not mirrored
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: a repeated point is spanned by the join, not turned into one
  ... and 5 more
exit=1
```

**Killed decisively.** The one line that matters most is
`collector_differential_test.dart:210`, `instance 0 x0` — the standing
differential's own walk-order assertion, which the brief specifically
named as the expected gate, failed directly and independently of the nine
record-level unit-test failures.

Restore:

```
$ cp <scratch>/gc_t10.bak lib/src/gpu/geometry_collector.dart
$ diff <scratch>/gc_t10.bak lib/src/gpu/geometry_collector.dart && echo "IDENTICAL - restored cleanly"
IDENTICAL - restored cleanly
$ md5 lib/src/gpu/geometry_collector.dart
MD5 (lib/src/gpu/geometry_collector.dart) = 83f77567826de4359b5e016c1418c7fc
```

Re-ran, confirmed green:

```
$ flutter test test/gpu/geometry_collector_test.dart test/gpu/collector_differential_test.dart
...
00:00 +26: All tests passed!
exit=0
```

## M-B10 — emit joins as collector geometry at the collection width

Not fired by any earlier task. Fired against
`packages/jet_cad_2d_flutter/test/support/instance_expander.dart`.

Backup:

```
$ cp test/support/instance_expander.dart <scratch>/ie_t10.bak
$ md5 test/support/instance_expander.dart <scratch>/ie_t10.bak
MD5 (test/support/instance_expander.dart) = 99dac061f228bfe680536ca5873d69e4
MD5 (<scratch>/ie_t10.bak) = 99dac061f228bfe680536ca5873d69e4
```

Exact edit — a join-local `halfWidth` shadowing the shared one, scoped to
the `kKindJoin` branch:

```diff
         final crossZ = d0x * d1y - d0y * d1x;
+        // M-B10: emit joins as collector geometry at the collection width --
+        // halfWidth is already a device-pixel quantity (GeometryCollector's
+        // own doc), so re-scaling it here by the transform's scale magnitude
+        // double-applies the collection-to-device scale for joins only.
+        final halfWidth = data[o + InstanceFieldOffset.halfWidth] * t.scaleMagnitude;
```

Command: `flutter test test/gpu/resident_pixel_differential_test.dart; echo "exit=$?"`

Verbatim output:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/resident_pixel_differential_test.dart
00:00 +0: the resident arm draws the reference drawing
00:00 +0 -1: the resident arm draws the reference drawing [E]
  Expected: a value less than <81>
    Actual: <95>
     Which: is not a value less than <81>
  ResidentAgreement(referenceInk: 8183, residentInk: 8278, differing: 95, overEight: 95)

  package:matcher                                       expect
  package:flutter_test/src/widget_tester.dart 473:18    expect
  test/gpu/resident_pixel_differential_test.dart 121:5  main.<fn>

00:00 +0 -1: the seam join is load-bearing on the circle
00:00 +0 -2: the seam join is load-bearing on the circle [E]
  Expected: a value less than <4>
    Actual: <552>
     Which: is not a value less than <4>
  the reference and resident arms must agree on the seam itself; ResidentAgreement(referenceInk: 1498, residentInk: 2050, differing: 552, overEight: 552)

  package:matcher                                       expect
  package:flutter_test/src/widget_tester.dart 473:18    expect
  test/gpu/resident_pixel_differential_test.dart 231:5  main.<fn>

00:00 +0 -2: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/resident_pixel_differential_test.dart: the resident arm draws the reference drawing
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/resident_pixel_differential_test.dart: the seam join is load-bearing on the circle
exit=1
```

**Killed decisively, on the first firing — no scaled arm was needed.**

### Why the brief's "unkillable at identity" caveat did not apply, and how that was confirmed rather than assumed

The brief's exact instruction: fire M-B10 against the pixel differential,
"then run the pixel differential with the comparison's transform set to
something other than the identity. If the existing comparison runs at the
identity, this mutant cannot die, which is itself the finding: add a scaled
arm... and re-fire. Report which of the two happened."

Read `gpu_comparison.dart`'s `measureResidentAgreement` before firing:
`expandInstances` is always called with `collectionToDevice =
Transform2.scale(devicePixelRatio, devicePixelRatio)`, and every call site
in `resident_pixel_differential_test.dart` passes `devicePixelRatio: 2.0`
(the file-level `_dpr` constant). `Transform2.scaleMagnitude` is
`sqrt(determinant.abs())`, and for a pure scale matrix
`scale(2, 2)` that determinant is `4`, so `scaleMagnitude == 2.0`, not
`1.0`. The comparison this suite actually runs is therefore **not** at the
identity — it is at `2x` already — which is exactly why the join-only
`halfWidth * t.scaleMagnitude` mutation moved something observable on the
very first run: joins came out roughly twice their correct half-width,
relative to the strokes either side of them, and the resulting excess ink
(95 and 552 differing pixels on the two tests) is far above both bounds.

So Case B applied ("dies already"), not Case A ("unkillable, needs a
scaled arm"). Rather than stop at that conclusion by arithmetic alone, the
"identity" claim was checked directly with a throwaway probe — a small,
never-committed test file, written to confirm the caveat is a genuine
property of this mutation class and not just an artifact of how the
argument reads:

```
$ cat > test/gpu/_scratch_mb10_probe_test.dart <<'EOF'
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import '../support/gpu_comparison.dart';

const ResolvedStyle _thick = ResolvedStyle(
    argb: 0xFF102030, lineweightHundredths: 200, linetype: Handle.none, linetypeScale: 1);

void main() {
  test('M-B10 probe at dpr=1.0 (scaleMagnitude=1, functionally identity)', () {
    final r = measureResidentAgreement((s) => s.circle(80, 80, 8, _thick),
        size: const Size(200, 200), devicePixelRatio: 1.0, pixelsPerPaperMm: 3.7795275590551185);
    print('PROBE dpr=1.0: $r');
  });
}
EOF
$ flutter test test/gpu/_scratch_mb10_probe_test.dart; echo "exit=$?"
```

Verbatim output (with the still-mutated `instance_expander.dart` in
place):

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/_scratch_mb10_probe_test.dart
00:00 +0: M-B10 probe at dpr=1.0 (scaleMagnitude=1, functionally identity)
PROBE dpr=1.0: ResidentAgreement(referenceInk: 382, residentInk: 382, differing: 0, overEight: 0)
00:00 +1: All tests passed!
exit=0
```

`differing: 0` — the mutation is a genuine no-op at `devicePixelRatio:
1.0`, confirming the brief's caveat describes this mutation class
correctly; it just is not the case the committed suite tests, since the
committed suite uses `devicePixelRatio: 2.0` for other reasons entirely
(matching a plausible device DPR, not chosen to defend against this
mutant).

**Decision: no scaled arm was added to `resident_pixel_differential_test.dart`.**
The brief's instruction to add one is explicitly conditional on the mutant
being unkillable at the comparison the suite actually runs, and it is not
— it died with a very large margin (`differing: 552` on the seam test is
the largest kill margin recorded anywhere in this plan's mutation log).
Adding a 3x arm anyway would not be wrong, but it is not what the task as
written called for once the "unkillable" premise turned out false, and
doing so was rejected as the safer default over silently expanding scope.
The dpr-dependence of this kill is recorded as a caveat in the mutation
log's M-B10 entry instead, so a future reader who changes
`resident_pixel_differential_test.dart`'s `devicePixelRatio` knows this
specific protection is not scale-independent.

Scratch file removed (never committed):

```
$ rm -f test/gpu/_scratch_mb10_probe_test.dart /tmp/_mb10_probe_test.dart
```

Restore of `instance_expander.dart`:

```
$ cp <scratch>/ie_t10.bak test/support/instance_expander.dart
$ diff <scratch>/ie_t10.bak test/support/instance_expander.dart && echo "IDENTICAL - restored cleanly"
IDENTICAL - restored cleanly
$ md5 test/support/instance_expander.dart
MD5 (test/support/instance_expander.dart) = 99dac061f228bfe680536ca5873d69e4
```

Re-ran, confirmed green:

```
$ flutter test test/gpu/resident_pixel_differential_test.dart test/gpu/instance_expander_test.dart
...
00:00 +11: All tests passed!
exit=0
```

## Collection of earlier transcripts

Every other mutation (M-B1, M-B1', M-B2, M-B3 and its guard-only equivalent
arm, M-B3', M-B4, M-B5, M-B6, M-B7, M-B8, M-B11, M-B12, M-B13, M-B14, M-B15)
was fired by an earlier task and its transcript already lives in that
task's own report (`task-3-report.md` through `task-9-report.md`) or, for
the fix-round-only ones whose reports predate the round (M-B12), in
`progress.md`'s own task-log entry and the fix-round commit message
(`733660f`). Nothing in this task re-fires any of them; per the brief,
that would be re-running a mutation that already has a transcript. All are
quoted verbatim, with their source cited, in
`docs/superpowers/notes/plan-b-mutation-log.md`.

## The three items requiring a derivation, not a shrug

Written up in full in the mutation log, not repeated here at length:

1. **M-B3's guard-only arm is an equivalent mutation.** `_runHasDirection`
   implies an accepted opening segment; reaching the guard with
   `_runSegments == 1` requires the closing step to be a zero-length skip,
   whose displacement is the exact negation of the opening step's, and
   `sqrt` is even in its argument's sign — so if the closing step skipped,
   the opening step's length was zero too, contradicting
   `_runHasDirection`. No input separates the guarded and unguarded arms.
2. **M-B1' survives the pixel differential, structurally.**
   `TriangleRasterizer.inked` is a `bool` — coverage only — and
   `_coveredArgb`'s effect is confined to the alpha channel at an
   already-correct footprint, so the instrument cannot register it by
   construction, for any corpus. Gate of record is the record level.
3. **The instrument's structural blind spot**, recorded in the log's own
   section: M-B7 and M-B15 read identically (26 / 178 differing pixels)
   because both satisfy `differing == referenceInk - residentInk` — the
   resident set is a pure subset of the reference's in both cases, since a
   wrong-side join wedge lands entirely inside the union of the adjacent
   segment quads and adds no new ink. The pixel instrument cannot see any
   defect that only adds triangles inside an already-inked footprint.

## Full gate output (this task)

```
$ cd packages/jet_cad_2d_flutter && flutter test; echo "TEST_EXIT=$?"
...
00:05 +475: All tests passed!
TEST_EXIT=0

$ flutter analyze; echo "ANALYZE_EXIT=$?"
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
ANALYZE_EXIT=0

$ dart format --output=none --set-exit-if-changed .; echo "FORMAT_EXIT=$?"
Formatted 89 files (0 changed) in 0.12 seconds.
FORMAT_EXIT=0
```

`git status --porcelain` was clean throughout — checked before, during
(after every mutation firing and restoration) and after this task's work.
No `analysis_options.yaml` ever appeared. `packages/jet_cad_2d` was not
touched by this task.

## Mutation tally

Eighteen firings across fifteen named mutants (M-B1 through M-B15, two of
them — M-B1 and M-B3 — fired a second time under a `'` suffix against the
pixel differential specifically). Sixteen firings killed. One survivor
(M-B1', structural — the pixel instrument is coverage-only). One equivalent
mutation, not a survivor (M-B3's guard-only arm, proved rather than
observed). M-B9 and M-B10, the two outstanding at the start of this task,
both died — M-B9 on the record-level order assertions the brief predicted,
M-B10 on the pixel differential directly, at the suite's own
`devicePixelRatio: 2.0`, with the "unkillable at identity" caveat confirmed
real but not triggered (verified with a `devicePixelRatio: 1.0` throwaway
probe showing `differing: 0` there).
