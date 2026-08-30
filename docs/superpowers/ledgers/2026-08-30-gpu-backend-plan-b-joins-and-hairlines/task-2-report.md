# Task 2 report: the record grows to twelve floats and three kinds

Branch `plan-b/joins-and-hairlines`, base `35e6c90`.

## Summary

`instance_record.dart` now carries `kFloatsPerInstance = 12`, three kind tags
(`kKindStroke=0`, `kKindJoin=1`, `kKindPoint=2`), the renamed
`InstanceFieldOffset` class, and three writers (`writeStroke`, `writeJoin`,
`writePoint`). `resident_geometry.dart`'s corner buffer grew to six vertices
of six floats (`corner.xy` + `join_weight.xyzw`, `kFloatsPerCorner = 6`), its
vertex layout was renamed `kStrokeVertexLayout` → `kInstanceVertexLayout` and
gained a `p2` attribute. `gpu_draw_backend.dart` pins `CullMode.none`. Nothing
draws differently — the shader (`cad_stroke.vert`) is untouched this task, so
`GpuDrawBackend` still binds a pipeline whose vertex stage expects the old
attribute set; that recompilation is Task 7's job, and this task never
exercises a real GPU context in its tests (every test here either runs
`flutter test` against pure-Dart data or takes the "no GPU" fallback path).

## TDD evidence

### Step 2: the failing test (before `instance_record.dart` existed for
three kinds)

Command:
```
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart
```
Verbatim tail (full output captured; header is `pub get` noise):
```
test/gpu/instance_record_test.dart:13:7: Error: Undefined name 'InstanceFieldOffset'.
      InstanceFieldOffset.kind,
      ^^^^^^^^^^^^^^^^^^^
...
test/gpu/instance_record_test.dart:34:12: Error: Undefined name 'kKindJoin'.
    expect(kKindJoin, 1.0);
           ^^^^^^^^^
test/gpu/instance_record_test.dart:35:12: Error: Undefined name 'kKindPoint'.
    expect(kKindPoint, 2.0);
           ^^^^^^^^^^
...
test/gpu/instance_record_test.dart:68:5: Error: Method not found: 'writeJoin'.
    writeJoin(b, 0,
    ^^^^^^^^^
...
test/gpu/instance_record_test.dart:89:5: Error: Method not found: 'writePoint'.
    writePoint(b, 0, x: -7, y: 2.5, halfWidth: 0.5, argb: 0xFFFFFFFF);
    ^^^^^^^^^^
...
00:00 +0 -1: loading .../test/gpu/instance_record_test.dart [E]
  Failed to load "...test/gpu/instance_record_test.dart":
  Compilation failed for testPath=...
00:00 +0 -1: Some tests failed.
```
`echo "exit=$?"` → `exit=1`

Matches the brief's expectation exactly: compile errors on
`InstanceFieldOffset`, `kKindJoin`, `kKindPoint`, `writeJoin`, `writePoint`.

### Step 4: the record test passing (after rewriting `instance_record.dart`,
before `resident_geometry.dart` was touched)

Command:
```
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart
```
Verbatim tail:
```
00:00 +0: loading .../test/gpu/instance_record_test.dart
00:00 +0: the field offsets are contiguous and cover the stride
00:00 +1: the three kind tags are distinct and ordered for the shader
00:00 +2: writeStroke fills every slot and leaves p2 zeroed
00:00 +3: writeJoin puts the vertex first and the neighbours after it
00:00 +4: writePoint carries one position and zeroes the unused slots
00:00 +5: All tests passed!
```
`echo "exit=$?"` → `exit=0`

At this point `resident_geometry.dart` still referenced `StrokeFieldOffset`
and `kStrokeVertexLayout` and would not compile against the new
`instance_record.dart` — confirmed separately by
`flutter test test/gpu/resident_geometry_test.dart` failing with
`Undefined name 'StrokeFieldOffset'` before Step 5's edits (not re-pasted
here; same shape of error as Step 2's, superseded once Step 5 landed).

### Step 6: `resident_geometry_test.dart`, extended, after `resident_geometry.dart`
was rewritten

Command:
```
cd packages/jet_cad_2d_flutter && flutter test test/gpu/resident_geometry_test.dart
```
Verbatim tail:
```
00:00 +0: loading .../test/gpu/resident_geometry_test.dart
00:00 +0: returns null rather than throwing where there is no GPU
00:00 +1: reports the byte length the instance count implies
00:00 +2: kCornerVertices is six vertices -- two triangles, not a strip
00:00 +3: kCornerVertices covers exactly four distinct corners
00:00 +4: kCornerVertices the corner buffer is six vertices of six floats
00:00 +5: kCornerVertices every join weight selects exactly one of the four points
00:00 +6: kCornerVertices the two join triangles are (V, A, B) and (A, M, B)
00:00 +7: kInstanceVertexLayout slot 0 carries corner and join_weight, per vertex, stride 24
00:00 +8: kInstanceVertexLayout slot 1 carries the instance record at the record's own offsets, per instance, stride 48
00:00 +9: kInstanceVertexLayout writeStroke and the vertex layout agree on where every field lands -- a derivation, not a restatement
00:00 +10: All tests passed!
```
`echo "exit=$?"` → `exit=0`

### Ruling B5: `collector_differential_test.dart` before and after the offset fix

Before fixing the offsets (immediately after `instance_record.dart` widened,
literal offsets still `data[o]`..`data[o + 9]`), the differential test was not
separately re-run failing on its own — the offset breakage was diagnosed by
inspection against the new field order (`halfWidth` moved from slot 5 to slot
7, colour from 6-9 to 8-11) before editing, because running it against a
buffer still produced by the *old* `GeometryCollector`/`writeStroke` would
have been comparing against code not yet updated for this task's layout. The
concrete regression this ruling anticipates is proven instead on
`geometry_collector_test.dart` below, which has the exact same slot-5 defect
and was run both before and after the fix (see next section) — the identical
failure mode (`x2`, now zeroed, silently returned where `halfWidth` used to
live) applies to both files for the same reason.

After the fix (every literal `data[o + N]` replaced by
`data[o + InstanceFieldOffset.<field>]`):
```
cd packages/jet_cad_2d_flutter && flutter test test/gpu/collector_differential_test.dart
```
```
00:00 +0: loading .../test/gpu/collector_differential_test.dart
00:00 +0: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr
00:00 +1: All tests passed!
```
`echo "exit=$?"` → `exit=0`

### `geometry_collector_test.dart`: failing before, passing after

This file was not named in the brief's Step 8 discussion but hardcodes the
same stale slot-5 index for `halfWidth` that Ruling B5 flags in the
differential test. Run **before** fixing it (right after `instance_record.dart`
widened):
```
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```
Verbatim tail:
```
00:00 +0: applies the residual, and a transposed one is not the same residual
00:00 +0 -1: applies the residual, and a transposed one is not the same residual [E]
  Expected: <2.0>
    Actual: <0.0>
  test/gpu/geometry_collector_test.dart 52:5          main.<fn>

00:00 +0 -1: emits one instance per segment, in walk order
00:00 +1 -1: closed: true emits a closing segment back to the first point
00:00 +2 -1: drops a zero-length segment rather than handing the shader a NaN
00:00 +3 -1: counts the ops Plan A does not draw instead of dropping them silently
00:00 +4 -1: clamps to the device-pixel floor at a hairline lineweight
00:00 +4 -2: clamps to the device-pixel floor at a hairline lineweight [E]
  Expected: <0.5>
    Actual: <0.0>
  test/gpu/geometry_collector_test.dart 124:5         main.<fn>

00:00 +4 -2: lineweightScale multiplies the logical width before the clamp
00:00 +4 -3: lineweightScale multiplies the logical width before the clamp [E]
  Expected: <4.0>
    Actual: <0.0>
  test/gpu/geometry_collector_test.dart 142:5         main.<fn>

00:00 +4 -3: Some tests failed.
```
`echo "exit=$?"` → `exit=1`

This is exactly the widening's predicted breakage: slot 5 used to be
`halfWidth`, is now `x2` (always zeroed by `writeStroke`), so every assertion
reading `r[5]` / `c.data[5]` reads `0.0` instead of the half-width the test
means to check.

After fixing (`r[5]` → `r[InstanceFieldOffset.halfWidth]`, likewise for the
other two):
```
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```
```
00:00 +0: applies the residual, and a transposed one is not the same residual
00:00 +1: emits one instance per segment, in walk order
00:00 +2: closed: true emits a closing segment back to the first point
00:00 +3: drops a zero-length segment rather than handing the shader a NaN
00:00 +4: counts the ops Plan A does not draw instead of dropping them silently
00:00 +5: clamps to the device-pixel floor at a hairline lineweight
00:00 +6: lineweightScale multiplies the logical width before the clamp
00:00 +7: All tests passed!
```
`echo "exit=$?"` → `exit=0`

## `collector_differential_test.dart`: every change, classified

Ten `expect` calls changed. All ten are **(a) correctly following the
widening**: each was asserting the right *semantic* slot under the old
ten-float layout (kind@0, x0..y1@1-4, halfWidth@5, r/g/b/a@6-9), and the
widening moved everything from `halfWidth` onward two slots to the right
(halfWidth@7, r/g/b/a@8-11) to make room for `x2`/`y2`. None of them were
asserting the old layout "by accident" — every one was pinning a real,
still-true claim about the collector's output (kind tag, walk-order
coordinates, dpr-scaled half-width, colour channels), and every one would
have silently started reading the wrong field (the always-zero `x2`/`y2`
slots, for `halfWidth`, or the wrong colour byte) had the indices been left
as bare literals. Per Ruling B5, the literals were not renumbered — each is
now `data[o + InstanceFieldOffset.<field>]`:

| Old | New | Field | Classification |
|---|---|---|---|
| `data[o]` | `data[o + InstanceFieldOffset.kind]` | kind | (a) |
| `data[o + 1]` | `data[o + InstanceFieldOffset.x0]` | x0 | (a) |
| `data[o + 2]` | `data[o + InstanceFieldOffset.y0]` | y0 | (a) |
| `data[o + 3]` | `data[o + InstanceFieldOffset.x1]` | x1 | (a) |
| `data[o + 4]` | `data[o + InstanceFieldOffset.y1]` | y1 | (a) |
| `data[o + 5]` | `data[o + InstanceFieldOffset.halfWidth]` | halfWidth | (a) — this one *would* silently break (start reading `x2`, always 0) without the fix |
| `data[o + 6]` | `data[o + InstanceFieldOffset.r]` | r | (a) |
| `data[o + 7]` | `data[o + InstanceFieldOffset.g]` | g | (a) |
| `data[o + 8]` | `data[o + InstanceFieldOffset.b]` | b | (a) |
| `data[o + 9]` | `data[o + InstanceFieldOffset.a]` | a | (a) |

`x0`..`y1` (offsets 1-4) did not actually move under the widening — only
`halfWidth` and the colour channels shifted — but they were changed anyway
per the ruling's instruction to replace *every* hardcoded slot index in the
file with the named offset, not only the ones that moved. Their behaviour is
unchanged; only their spelling is.

## Every other test touched because of the widening, classified

- **`test/gpu/geometry_collector_test.dart`** — three assertions
  (`r[5]` → `r[InstanceFieldOffset.halfWidth]` at what is now line 52,
  `c.data[5]` → `c.data[InstanceFieldOffset.halfWidth]` at line 124, and
  again at line 142). **(a) correctly following the widening.** Each was
  pinning the record's half-width, a claim that is still true and still
  worth pinning; the widening moved `halfWidth` from slot 5 to slot 7, and
  without the fix each assertion would have silently started reading `x2`
  (always zero for a stroke record) instead, turning a real check into a
  vacuous one rather than a compile error. Confirmed failing before the fix
  (three failures, all "Expected: <N> / Actual: <0.0>") and passing after —
  transcripts above. The other assertions in that file (`r[0]` for kind,
  `r.sublist(1, 5)` / `c.data.sublist(...)` for x0/y0/x1/y1) were left as
  bare literals: those slots did not move under the widening (x0..y1 are
  still offsets 1-4), so touching them was not necessary. I left them
  unconverted to `InstanceFieldOffset` rather than sweeping the whole file
  for a symbolic rename the task did not ask for on this file (Ruling B5's
  instruction to replace *every* literal was scoped explicitly to
  `collector_differential_test.dart`).

- **`test/gpu/resident_geometry_test.dart`** — every assertion in the
  `kStrokeVertexLayout`/`kInstanceVertexLayout` group, plus
  `byteLengthFor`'s literal and the corner-buffer iteration stride. All
  **(a) correctly following the widening**, itemised:
  - `byteLengthFor(59875)` expected value `2395000` (= 59875 × 10 × 4) →
    `2874000` (= 59875 × 12 × 4). The old literal was correct for the old
    stride; the widening changed the stride, so the literal had to change to
    keep testing the same claim (this test's whole point, per its own
    comment, is to be a literal independent of `kFloatsPerInstance` so a
    broken constant cannot drag the expectation down with it).
  - `kCornerVertices` exact-list assertion: old 12-float list (2
    floats/vertex × 6) → new 36-float list (6 floats/vertex × 6), taken
    verbatim from the brief's Step 5 replacement. Necessary because the
    corner buffer itself grew; not a pre-existing bug.
  - `covers exactly four distinct corners`: the loop stepped `i += 2`
    (correct when each vertex was 2 floats); changed to
    `i += ResidentGeometry.kFloatsPerCorner` so it still walks vertex
    boundaries rather than corrupting pairs by reading into `join_weight`.
  - `kStrokeVertexLayout` → `kInstanceVertexLayout` renamed throughout (per
    the plan's explicit rename).
  - "slot 0 carries corner..." stride 8 → `kFloatsPerCorner * 4` (24), and
    the assertion was widened from "one attribute named corner" to "two
    attributes, corner@0 and join_weight@8" — the buffer itself grew, this
    is not tightening a loose test.
  - "slot 1 carries the instance record..." stride
    `kFloatsPerInstance * 4` — same expression, evaluates to 48 now instead
    of 40, no literal to change. The offsets map gained `'p2': 20` and
    `half_width`/`color` shifted from `20`/`24` to `28`/`32`.
  - The `writeStroke` cross-check test gained two assertions
    (`byName('p2', 0)`, `byName('p2', 1)`, both expected `0.0`) confirming
    `writeStroke` zeroes the new field, and its existing assertions were
    otherwise untouched (their byte offsets are read live through the
    layout's own `offsetInBytes`, so they moved automatically with the
    layout change rather than needing hand-editing).
  - Three tests were **added**, not fixed: "the corner buffer is six
    vertices of six floats", "every join weight selects exactly one of the
    four points", "the two join triangles are (V, A, B) and (A, M, B)" — new
    coverage per Step 6, not a repair.

- **`test/gpu/instance_record_test.dart`** — replaced wholesale per the
  brief's Step 1 (this is the file the brief hands over as a finished
  replacement, not an incremental edit); not classified (a)/(b) since it is
  a full rewrite to a new spec rather than a fix to an existing assertion.

No other test file in the package referenced `StrokeFieldOffset`,
`kStrokeVertexLayout`, or a bare slot literal tied to the old ten-float
layout — confirmed by `grep -rn "StrokeFieldOffset\|kStrokeVertexLayout"`
across the whole repo returning nothing after the edits, and by the full
`flutter test` run (446 passed, 1 skipped, 0 failed) below.

## Full gate output

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:06 +444 ~1: .../test/tile_measurement_seam_test.dart: debugRestBakeDisabled slices nothing and still covers
00:06 +445 ~1: .../test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:06 +446 ~1: All tests passed!
$ echo "exit=$?"
exit=0
```
(446 passed, 1 pre-existing skip unrelated to this task — present before
this task's changes too, not investigated further since the brief's scope is
the record widening.)

```
$ flutter analyze
...
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
$ echo "exit=$?"
exit=0
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 85 files (0 changed) in 0.16 seconds.
$ echo "exit=$?"
exit=0
```

**One intermediate format failure, caught and fixed before the final gate
run above:** the first `dart format --output=none --set-exit-if-changed .`
after finishing Step 6 printed `Changed test/gpu/resident_geometry_test.dart`
and exited 1 — my hand-written replacement for that file was not
`dart format`-clean (line-wrapping on the new `kInstanceVertexLayout` group's
assertions and the `for` loop in "covers exactly four distinct corners").
Fixed by running `dart format test/gpu/resident_geometry_test.dart` and
re-verified: the final `--set-exit-if-changed` run above shows `(0 changed)`
and `exit=0`.

`git status --short` after all edits shows only the eight files below
modified; no `analysis_options.yaml` appeared:
```
 M packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart
 M packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart
 M packages/jet_cad_2d_flutter/lib/src/gpu/instance_record.dart
 M packages/jet_cad_2d_flutter/lib/src/gpu/resident_geometry.dart
 M packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart
 M packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
 M packages/jet_cad_2d_flutter/test/gpu/instance_record_test.dart
 M packages/jet_cad_2d_flutter/test/gpu/resident_geometry_test.dart
```
(`lib/jet_cad_2d_flutter.dart` is a one-line comment fix, updating its
mention of `kStrokeVertexLayout` to `kInstanceVertexLayout` so the barrel
file's own doc does not go stale; not called out as a separate file in the
brief's Step 9 `git add` line, but part of the same rename and included in
the commit alongside `lib/src/gpu` and `test/gpu`.)

## Findings in the brief's sample code

None of the code blocks in this brief were wrong. Every block (Steps 3, 5,
6, 7) compiled and behaved exactly as documented once transcribed verbatim,
and every test derived from them passed on the first run after the
corresponding implementation step landed — no hidden defect surfaced by
running any of it.

One prose/code mismatch, not a functional defect: Step 6's heading says
"Add these two tests to the existing file," but the code block that follows
it contains **three** `test(...)` blocks ("the corner buffer is six vertices
of six floats", "every join weight selects exactly one of the four points",
and "the two join triangles are (V, A, B) and (A, M, B)"). I added all three,
since the code is unambiguous and matches Step 5's `kCornerVertices`
replacement (the third test needs to exist for the six-vertex role
assignment to be pinned at all — dropping it would leave the two-triangle
`(V,A,B)`/`(A,M,B)` structure asserted only by the weight-sum test, which
cannot distinguish a role reordering from a correct assignment). Flagging
this because the report's job is to say when something in the brief doesn't
match what actually happened, even a harmless miscount.

## Notes for the reviewer

- `geometry_collector.dart` itself needed no changes — confirmed by the
  brief's claim in Step 8 (it references `StrokeFieldOffset` only indirectly
  through `writeStroke`) and by the full test suite passing with the file
  untouched.
- The mutation-backup ritual in the task's global constraints ("back the
  file up with `cp` before firing any mutation") did not apply: this task's
  brief contains no mutation-testing step, only widening plus the TDD steps
  above. No mutations were fired.
- `writeJoin` and `writePoint` are implemented and unit-tested
  (`instance_record_test.dart`) but have no caller yet — `geometry_collector.dart`
  still only emits strokes. That is expected: Tasks 3-6 fill the collector's
  join/point emission; this task only widens the record format underneath it.
