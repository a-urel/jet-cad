# Task 4 report: the record grows to sixteen floats and reorders

Branch: `plan-c/shaded-dashes`.

## What changed and why

`lib/src/gpu/instance_record.dart`:

- `kFloatsPerInstance` 12 → 16.
- `InstanceFieldOffset` reordered and widened: `kind = 0, halfWidth = 1,
  x0 = 2 … a = 11, dashPeriod = 12, dashPhase = 13, dashFracStart = 14,
  dashFracEnd = 15` — exactly the brief's Step 3 values. `halfWidth` moved
  from slot 7 to slot 1, adjacent to `kind` (Ruling C6: the shader reads them
  as one `vec2` attribute so the eighth slot is free for the new `dash`
  quad).
- `writeStroke` and `writeJoin` each gained four optional named dash
  arguments (`dashPeriod`, `dashPhase`, `dashFracStart`, `dashFracEnd`,
  all defaulting to `0`), both now writing `halfWidth` into its new slot and
  calling a new `_writeDash` helper.
- `writePoint` gained **no** dash parameters (per the brief's own test and
  Ruling P5), but now calls `_writeDash(into, o, 0, 0, 0, 0)` explicitly
  rather than relying on the fresh `Float32List`'s zero-initialisation.
  `_writeDash` is the same helper all three writers share.
- The top-of-file doc comment was rewritten, not appended to: it now
  narrates the sixteen-float order (`[kind, halfWidth, x0, y0, x1, y1, x2,
  y2, r, g, b, a, dashPeriod, dashPhase, dashFracStart, dashFracEnd]`),
  states "64 bytes per record" instead of 48, and adds a paragraph
  explaining the Plan C widening and Ruling C6's reorder, right after the
  existing paragraph that narrates Plan B's ten→twelve widening. The old
  twelve-float prose is gone, not left stale beside the new offsets.

`lib/src/gpu/resident_geometry.dart` (vertex layout only, per the brief's
file scope):

- The instance buffer's six attributes were rewritten to the brief's Step 5
  shape: `kind_half` (`float32x2` at `InstanceFieldOffset.kind * 4`), `p0`,
  `p1`, `p2`, `color`, and a new `dash` (`float32x4` at
  `InstanceFieldOffset.dashPeriod * 4`) — `kind` and `half_width` are no
  longer separate attributes.
- The doc comment above `kInstanceVertexLayout` was updated: the bracketed
  field list now matches the sixteen-float order, and a new paragraph
  (Ruling P2) states plainly that this layout is ahead of the committed
  shader bundle — `shaders/cad_stroke.vert` and
  `assets/shaders/cad.shaderbundle` still declare `kind`/`half_width`
  separately and carry no `dash` attribute — that pipeline creation on a
  real GPU will fail between this task and Task 8 (which regenerates the
  bundle), and that this is accepted because `flutter test` never reaches
  pipeline creation and no device run happens in this window. Per the
  dispatch's explicit instruction, `shaders/cad_stroke.vert` and
  `assets/shaders/cad.shaderbundle` were **not touched**.
- `byteLengthFor`, `strideInBytes`, and the zero-instance `ByteData`
  allocation all already derived from `kFloatsPerInstance` rather than
  restating `12`/`48` as literals, so nothing there needed to change beyond
  the constant itself moving in `instance_record.dart`. Confirmed by grep
  (`kFloatsPerInstance`, `48 bytes`, `kind, x0, y0`) that no other literal
  in the file needed updating.

`packages/jet_cad_2d` was not touched (confirmed by `git status --short`
below — only `jet_cad_2d_flutter` files appear).

## Every test file repaired, and why

### `test/gpu/instance_record_test.dart` — repaired + widened

- **Repaired**: the "field offsets are contiguous" test's `offsets` list
  was reordered to `kind, halfWidth, x0, y0, x1, y1, x2, y2, r, g, b, a,
  dashPeriod, dashPhase, dashFracStart, dashFracEnd` and widened to sixteen
  entries — the old twelve-entry, old-order list no longer matched
  `List<int>.generate(kFloatsPerInstance, (i) => i)`.
- **Added** the brief's five new tests verbatim (Step 1): the sixteen-float
  / adjacency test, solid-stroke-zeros, dashed-stroke-carries-its-extent,
  negative-period-preserved, and point-is-never-dashed.
- The four pre-existing writer tests (`writeStroke`, `writeJoin`,
  `writePoint`) needed no data changes — they read every field through
  `InstanceFieldOffset` by name, never by literal index, so the reorder is
  transparent to them. Left as-is.

### `test/gpu/resident_geometry_test.dart` — repaired + widened

- **Repaired** `'reports the byte length the instance count implies'`: the
  pinned literal `2874000` (59875 × 12 × 4) is wrong under sixteen floats;
  changed to `3832000` (59875 × 16 × 4) and the comment's "12
  floats/record"/"48-byte record" updated to "16 floats/record"/"64-byte
  record". This is an *expected-value* change, not a *meaning* change — the
  test still pins the literal rather than the production expression, for
  the same anti-tautology reason the original comment gives.
- **Repaired** `'slot 1 carries the instance record...'`: renamed
  "stride 48" → "stride 64" in the test name, updated the doc comment's
  field list and byte count, and rewrote the expected `offsetsByName` map
  from `{kind: 0, p0: 4, p1: 12, p2: 20, half_width: 28, color: 32}` to
  `{kind_half: 0, p0: 8, p1: 16, p2: 24, color: 32, dash: 48}` — `kind` and
  `half_width` no longer exist as separate attribute names, so the old map
  could not pass under any data; this is a genuine widening of what the
  test asserts, not a value tweak.
- **Repaired** `'writeStroke and the vertex layout agree on where every
  field lands'`: `byName('kind', 0)` / `byName('half_width', 0)` no longer
  resolve (no attribute named `kind` or `half_width` remains), so the test
  was rewritten to read `byName('kind_half', 0)` for kind and
  `byName('kind_half', 1)` for half-width, and four new `dash` assertions
  were added, with the `writeStroke` call in the fixture extended to pass
  non-zero, mutually-distinct dash values (`dashPeriod: 9.0, dashPhase: 1.5,
  dashFracStart: 0.25, dashFracEnd: 0.75`) so a dash field landing at the
  wrong offset reads a value belonging to a different field rather than
  coincidentally matching zero — same anti-degenerate-fixture reasoning the
  rest of the test already uses for colour.
- **Added** the brief's three new tests (Step 1): the eight-attributes
  test, the derived-offset test, and the sixteen-floats byte-length test.

### `test/gpu/geometry_collector_test.dart` — repaired, no new tests

Three tests used **literal** float offsets (`sublist(1, 5)`,
`sublist(o + 1, o + 5)`) to read a stroke's `(x0, y0, x1, y1)` quadruple,
relying on the pre-Task-4 fact that `x0` sat at float offset 1. Under the
reorder `x0` moved to offset 2, so these literal slices would have silently
read `(halfWidth, x0, y0, x1)` instead — one field short and one field
stale, with no compile error and a very plausible-looking wrong assertion.
Repaired by replacing every literal `1`/`+ 1`/`+ 5` in these three call
sites with `InstanceFieldOffset.x0` / `InstanceFieldOffset.x0 + 4`:

- `'applies the residual, and a transposed one is not the same residual'`
  (also changed `r[0]` → `r[InstanceFieldOffset.kind]` for consistency,
  though `kind` staying at offset 0 meant that particular line was not
  actually broken).
- `'emits one instance per segment, in walk order'`.
- `'closed: true emits a closing segment back to the first point'`.

No other test in this file needed a change: every other assertion already
reads through `InstanceFieldOffset` by name (`InstanceFieldOffset.halfWidth`,
`.x0`, `.y0`, `.x1`, `.y1`, `.x2`, `.y2`, `.kind`, `.r/.g/.b/.a`), including
the join and seam tests that sit right next to the repaired ones — those
were already immune to the reorder because they never restated an offset as
a bare number.

### Files the brief's Step 6 named that turned out **not** to need repair

Ran the full suite (below) after the three files above were fixed, and
`test/gpu/instance_expander_test.dart`, `test/gpu/collector_differential_test.dart`,
and `test/gpu/resident_pixel_differential_test.dart` **all passed without
modification**. Checked why, rather than assuming the brief was simply
wrong: all three read every field through `InstanceFieldOffset` (by name)
or through `kInstanceVertexLayout`'s own attribute lookup, and
`test/support/instance_expander.dart` — which two of the three exercise —
does the same, exactly as the brief's "facts you would otherwise have to
rediscover" said it would. None of the three ever restated a bare float
offset the way `geometry_collector_test.dart` did. See "Anything the brief
got wrong" below.

## Exact commands run, with output and exit codes

### 1. `flutter test` (full suite, after all repairs)

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:07 +490 ~1: .../test/tile_slice_differential_test.dart: and when a pan lands between the scale change and the bake
00:07 +491 ~1: .../test/tile_slice_differential_test.dart: tile boundaries carry no difference of their own
00:07 +492 ~1: All tests passed!
```
Exit code: 0. 492 passed, 1 skip. The skip is pre-existing and unrelated to
this task — confirmed by `flutter test --reporter expanded | grep -i skip`,
which shows it is `test/tile_regime_test.dart`'s `rig`-tagged test
("Skip: run explicitly: flutter test --tags rig --run-skipped"), the same
skip Task 1's report recorded (`484 ~1` before this task). The count is
consistent: Task 1 ended at 484; this task adds 5 new tests to
`instance_record_test.dart` and 3 to `resident_geometry_test.dart` (8 net
new), landing at 492.

### 2. `flutter analyze`

```
$ cd packages/jet_cad_2d_flutter && flutter analyze
...
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
```
Exit code: 0.

### 3. `dart format --output=none --set-exit-if-changed .`

First run, before formatting the three hand-edited test files:

```
$ dart format --output=none --set-exit-if-changed .
Changed test/gpu/geometry_collector_test.dart
Changed test/gpu/instance_record_test.dart
Changed test/gpu/resident_geometry_test.dart
Formatted 89 files (3 changed) in 0.17 seconds.
EXIT:1
```
A real failure, logged rather than glossed over. Fixed:

```
$ dart format test/gpu/geometry_collector_test.dart \
    test/gpu/instance_record_test.dart test/gpu/resident_geometry_test.dart
Formatted test/gpu/geometry_collector_test.dart
Formatted test/gpu/instance_record_test.dart
Formatted test/gpu/resident_geometry_test.dart
Formatted 3 files (3 changed) in 0.01 seconds.

$ dart format --output=none --set-exit-if-changed .
Formatted 89 files (0 changed) in 0.16 seconds.
EXIT:0
```

Re-ran the full suite after formatting, and `flutter analyze`, to confirm
the reformat changed nothing behaviourally — both green again (same 492/1
and "No issues found!" as above).

### 4. `analysis_options.yaml` trap

```
$ git status --short
 M packages/jet_cad_2d_flutter/lib/src/gpu/instance_record.dart
 M packages/jet_cad_2d_flutter/lib/src/gpu/resident_geometry.dart
 M packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
 M packages/jet_cad_2d_flutter/test/gpu/instance_record_test.dart
 M packages/jet_cad_2d_flutter/test/gpu/resident_geometry_test.dart
```
No `analysis_options.yaml` present, before or after `flutter pub get` ran
(twice, once per `flutter analyze` and once via `flutter test`). Nothing to
`git checkout --`.

## Anything the brief got wrong

1. **Step 6 overstates which files break.** The brief says
   `test/gpu/instance_expander_test.dart`, `test/gpu/collector_differential_test.dart`,
   `test/gpu/geometry_collector_test.dart` and
   `test/gpu/resident_pixel_differential_test.dart` **all** fail after the
   widening. In practice only `geometry_collector_test.dart` failed — the
   other three passed unmodified, because (as the brief's own "facts" section
   says of the expander) every one of them reads fields through
   `InstanceFieldOffset` by name or through `kInstanceVertexLayout`'s
   attribute lookup rather than a bare literal offset. Only
   `geometry_collector_test.dart` had literal `sublist(1, 5)`-style offsets
   baked in, which is exactly the kind of drift `InstanceFieldOffset`'s own
   doc comment warns a fourth, uncheckable copy (the GLSL) is exposed to —
   these three Dart copies just weren't exposed to it here. Not a blocker;
   noted per the dispatch's instruction to report a case where the brief's
   claim doesn't match what actually happened, rather than silently
   "fixing" three files that were never broken.
2. Everything else in the brief — the exact offset values, the writer
   signatures, the vertex layout shape, Ruling P5's `_writeDash` mechanics,
   and Ruling P2's "don't touch the shader" instruction — matched what was
   needed with no other deviation.

## Commit

```
git add packages/jet_cad_2d_flutter/lib packages/jet_cad_2d_flutter/test
git commit -m "feat(gpu): sixteen floats, and kind beside half-width for ES 100's eighth attribute"
```
SHA: `6e176f6` on `plan-c/shaded-dashes`, parent `436a416`.

## Fix round 1: `'a point is never dashed'` couldn't be killed by the mutation it exists to guard

**Finding (review):** `test/gpu/instance_record_test.dart`'s `'a point is
never dashed'` allocated `Float32List(kFloatsPerInstance)` — already all
zeros — then called `writePoint` and asserted `dashPeriod == 0.0`. Deleting
the explicit `_writeDash(into, o, 0, 0, 0, 0);` call in `writePoint`
(`lib/src/gpu/instance_record.dart:229`) left the test green, because the
buffer was zero before `writePoint` ever ran. The test was checking
`Float32List`'s zero-initialisation, not the writer — exactly what Ruling
P5 was written to prevent, and exactly the case `_writeDash`'s own doc
comment names: "a record reused across frames ... is not guaranteed to
already be zero there; only an explicit write is."

**Fix:** pre-fill all four dash slots with plausible non-zero, mutually
distinct dashed-record values before calling `writePoint`, then assert all
four come back zero (not just `dashPeriod`), so the test now reads as "this
index used to hold a dashed instance":

```dart
final into = Float32List(kFloatsPerInstance);
into[InstanceFieldOffset.dashPeriod] = 18.0;
into[InstanceFieldOffset.dashPhase] = 4.0;
into[InstanceFieldOffset.dashFracStart] = 0.1;
into[InstanceFieldOffset.dashFracEnd] = 0.6667;
writePoint(into, 0, x: 1, y: 2, halfWidth: 0.5, argb: 0xFF112233);
expect(into[InstanceFieldOffset.dashPeriod], 0.0);
expect(into[InstanceFieldOffset.dashPhase], 0.0);
expect(into[InstanceFieldOffset.dashFracStart], 0.0);
expect(into[InstanceFieldOffset.dashFracEnd], 0.0);
```

### Evidence the mutation is now actually killed

Backed up the production file with `cp` (not `git checkout --`, so the
working tree stays the single source of truth throughout):

```
$ cp packages/jet_cad_2d_flutter/lib/src/gpu/instance_record.dart /tmp/instance_record.dart.bak
```

Commented out the `_writeDash` call inside `writePoint`
(`lib/src/gpu/instance_record.dart:229`):

```dart
  _writeColor(into, o, argb);
  // _writeDash(into, o, 0, 0, 0, 0); // MUTATION: dropped for kill-test
}
```

Ran the test file — **it fails**, with the mutant leaving `dashPeriod` at
the pre-filled garbage value instead of zero:

```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart
...
00:00 +9: a point is never dashed
00:00 +9 -1: a point is never dashed [E]
  Expected: <0.0>
    Actual: <18.0>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/instance_record_test.dart 178:5            main.<fn>

00:00 +9 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/instance_record_test.dart: a point is never dashed
```
Exit code: 1 ("Some tests failed").

Restored the file from the `cp` backup:

```
$ cp /tmp/instance_record.dart.bak packages/jet_cad_2d_flutter/lib/src/gpu/instance_record.dart
$ git diff --stat packages/jet_cad_2d_flutter/lib/src/gpu/instance_record.dart
(no output -- byte-identical to the committed version)
```

Re-ran green:

```
$ flutter test test/gpu/instance_record_test.dart
...
00:00 +10: All tests passed!
```
Exit code: 0.

### Commands for this fix round, exact output, exit codes

```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart
...
00:00 +10: All tests passed!
```
Exit code: 0.

```
$ flutter analyze
...
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.3s)
```
Exit code: 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 89 files (0 changed) in 0.16 seconds.
```
Exit code: 0.

```
$ git status --short
 M packages/jet_cad_2d_flutter/test/gpu/instance_record_test.dart
```
No `analysis_options.yaml` present. Only the one test file changed for this
round.

### Note on the deferred Minor

The reviewer's other finding — `'a dashed stroke carries its element extent
and its phase'` passes `dashFracStart: 0.0` without asserting it — was
explicitly deferred by the coordinator ("do not act on it"). Not touched.

## Commit (fix round 1)

```
git add packages/jet_cad_2d_flutter/test/gpu/instance_record_test.dart
git commit -m "test(gpu): a point-is-never-dashed test that can actually die"
```
SHA: `13c92ca` on `plan-c/shaded-dashes`, parent `6e176f6`.
