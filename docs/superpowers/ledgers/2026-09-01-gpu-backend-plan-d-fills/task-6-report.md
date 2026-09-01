# Task 6 report: the pixel instrument learns colour

Branch `plan-d/fills`. Work confined to `packages/jet_cad_2d_flutter/test`, as instructed.

## Files touched

- `test/support/gpu_comparison.dart` — new `ResidentColorAgreement` class,
  new `measureResidentColor` function, `_colorAgreementOf` helper, one new
  import (`instance_record.dart`'s `kFloatsPerInstance`, for the `permute`
  path), and the two doc paragraphs rewritten (see below).
- `test/gpu/resident_pixel_differential_test.dart` — the two tests from the
  brief's Step 1, appended after the existing "seam join" test, using the
  file's own `_corpus`/`_size`/`_dpr`/`_ppmm`.

## Ruling D-P1 followed

`measureResidentColor`'s signature carries both `permute` (from the brief's
Interfaces block) and `debugTintResident` (from the brief's own sample test),
exactly as the ruling specifies. `debugTintResident` is documented the same
way `TriangleRasterizer.debugDisableDashTest` is — "test-only, and it stays
that way" — and does not appear in `lib/`.

## The two doc paragraphs rewritten

`gpu_comparison.dart`'s header used to say colour and draw order were things
"this file cannot gate" / "unmeasured … a repo non-negotiable, not a minor
gap." Both paragraphs are rewritten, in place, keeping the file's habit of
stating what used to be true before saying what changed:

- **Colour paragraph.** Now says `ResidentAgreement` is still coverage-only
  and stays a coverage instrument — that half of the old claim is
  unchanged — but that Task 6 makes the per-channel half of criterion 1
  something this file gates directly, via `ResidentColorAgreement` /
  `measureResidentColor`, which read `TriangleRasterizer.pixels` instead of
  `.inked`. It keeps the pointer to the record-level `argb` assertions in
  `geometry_collector_test.dart` / `collector_differential_test.dart`, now
  framed as "before rasterisation" against this file's "after rasterisation"
  check, rather than as the only place colour is checked at all.
- **Order paragraph.** Explains *why* order was unmeasured before (a
  coverage-only comparison, and a corpus with only overlapping strokes,
  cannot disagree in colour over ground both arms already inked the same
  way) and why a fill changes that (last-write-wins colour, no blending, so
  a fill painted over a stroke repaints that stroke's pixels without moving
  the ink union). It names `measureResidentColor` as the first instrument in
  this file able to see order, and `test/gpu/fill_order_test.dart` (Task 7)
  as the gate that exercises it, while keeping the record-order assertion
  (`collector_differential_test.dart`'s walk-order check) as the only thing
  that pins order **directly**, not as a colour side effect.

## `measureResidentColor`

Reuses `measureResidentAgreement`'s two arms verbatim (same identity-residual
split, same device-scale handling) and replaces `_agreementOf`'s
`inked`/`inked` comparison with a per-channel walk of both `pixels` buffers,
per the brief's Step 3 code, plus the `permute` and `debugTintResident`
handling:

- `permute`: builds `order = List<int>.generate(instanceCount, (i) => i)`,
  calls `permute(order)`, then copies each instance's 16
  (`kFloatsPerInstance`) floats from `data[order[i] * 16 ..]` into a fresh
  buffer at position `i` before handing it to `expandInstances`. `null` (the
  default) skips this entirely — every test in this file passes `null`.
- `debugTintResident`: when non-zero, copies `expanded.colors` into a fresh
  `Int32List` and adds the tint to every element before the resident
  rasterizer observes it. `0` (the default) skips the copy and mutation
  altogether, so the ordinary path allocates nothing extra beyond the
  colour copy already implied by the resident arm.

`_colorAgreementOf` is the brief's Step 3 loop exactly: `union` is pixels
either arm inked, `withinTwo` is worst-per-channel-distance `<= 2`,
`overEight` is worst-per-channel-distance `> 8`, `referenceInk` is the
anti-vacuity count. The shift loop reads all four packed bytes of
`0xAABBGGRR` — order doesn't matter for a worst-single-channel distance.

## Measured numbers on the existing stroke corpus

From `measureResidentColor(_corpus, size: _size, devicePixelRatio: _dpr,
pixelsPerPaperMm: _ppmm)` (captured via a temporary `print`, removed before
the final commit):

```
ResidentColorAgreement(union: 8183, withinTwo: 8183 (100.000%), overEight: 0, referenceInk: 8183)
```

union = 8183, withinTwoFraction = 100.000%, overEight = 0, referenceInk =
8183. Every inked pixel in this corpus is bit-identical between the two arms
— unsurprising since the same corpus's coverage differential
(`differing`) already measures 0, and every element in `_corpus` is one flat
colour (`_thick`/`_hairline` both `0xFF102030`), so a coverage match implies
a colour match here.

## Control arm: tint and measured fraction

Tint: `0x00202020` — the brief's own sample value, and (documented in the
test) chosen against this corpus's own colour `0xFF102030` (R=0x30, G=0x20,
B=0x10) so each channel's `+0x20` stays inside its byte with no carry:
R 0x30→0x50, G 0x20→0x40, B 0x10→0x30 — each a clean, uniform +32 distance,
16x past the `<= 2` threshold and 4x past `<= 8`.

Measured:

```
ResidentColorAgreement(union: 8183, withinTwo: 0 (0.000%), overEight: 8183, referenceInk: 8183)
```

withinTwoFraction drops from 100.000% to **0.000%**, and `overEight` goes
from 0 to **8183** (every unioned pixel). `expect(r.withinTwoFraction,
lessThan(0.995))` passes with maximum margin — not a threshold nudged to
scrape by.

## An independent, non-tint kill (beyond the brief's own control arm)

The testing-bar warning in the brief ("Three earlier tasks in this plan each
lost a review round to a test that killed nothing") is about the *primary*
assertion, not only the control arm, so I additionally verified the first
new test ("the two arms agree per channel, not merely on coverage") reddens
on a real defect, not only on the deliberately-broken control input. I
temporarily swapped the R/G channel read order in
`test/support/instance_expander.dart`'s `_argbOf` (R and G channels
exchanged in the packed word the expander hands the rasterizer), reran
`flutter test test/gpu/resident_pixel_differential_test.dart`, and got:

```
00:00 +2 -1: the two arms agree per channel, not merely on coverage [E]
  Expected: a value greater than or equal to <0.995>
    Actual: <0.0>
     Which: is not a value greater than or equal to <0.995>
  ResidentColorAgreement(union: 8183, withinTwo: 0 (0.000%), overEight: 8183, referenceInk: 8183)
```

Then reverted the file and confirmed `diff` against a saved-before copy was
empty and `git status --short` showed no change to it before committing.

## Gate commands, verbatim

### `flutter test` (global constraint gate 1)

Tail of the run (every line before this tail was `+N` or `+N ~1`, no `-`):

```
00:10 +553 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: the rest bake fires: the unflagged arm slices every visible tile
00:10 +554 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: the rest bake fires: the unflagged arm slices every visible tile
00:10 +555 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: tile boundaries carry no difference of their own
00:10 +556 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugRestBakeDisabled slices nothing and still covers
00:10 +557 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:10 +558 ~1: All tests passed!
EXIT: 0
```

558 tests, 1 pre-existing skip (unrelated to this task), 0 failures.

Targeted run, `flutter test test/gpu/resident_pixel_differential_test.dart`:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/resident_pixel_differential_test.dart
00:00 +0: the resident arm draws the reference drawing
00:00 +1: the seam join is load-bearing on the circle
00:00 +2: the two arms agree per channel, not merely on coverage
00:00 +3: the colour measurement can actually fail
00:00 +4: All tests passed!
EXIT: 0
```

### `flutter analyze` (global constraint gate 2)

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.9s)
EXIT: 0
```

### `dart format --output=none --set-exit-if-changed .` (global constraint gate 3)

```
Formatted 91 files (0 changed) in 0.19 seconds.
EXIT: 0
```

All three global gates green.

## Anything the plan did not anticipate

- **`kFloatsPerInstance` is not publicly exported** from
  `jet_cad_2d_flutter.dart` (the barrel explicitly keeps `instance_record.dart`
  unexported — it's the collector's own wire format, not something a caller
  writes). `instance_expander.dart` already imports it directly via
  `package:jet_cad_2d_flutter/src/gpu/instance_record.dart`, so
  `gpu_comparison.dart` does the same, importing only the one constant with a
  `show` clause rather than the whole file, since only the stride is needed
  for the `permute` reorder.
- **`permute` has no exercising test in this task**, by design — the brief
  states Task 7 is its only caller. I implemented it against
  `expandInstances`'s actual instance layout (copy `kFloatsPerInstance`
  floats per reordered index) rather than leaving it a stub, since an
  unusable stub would just move the untested-parameter problem one task
  later without fixing it, but I could not verify it beyond compiling and
  reasoning about the copy — flagging that for the reviewer and for Task 7's
  own tests to confirm.
- `debugTintResident`'s addition is done on the packed `0xAARRGGBB` `int`
  directly (`colors[i] + debugTintResident`, truncated back to a signed
  32-bit value), the same way the brief's own comment frames it ("adds its
  argument to the resident arm's every written colour") — this only stays a
  clean per-channel offset for tints and base colours that don't carry
  across a byte boundary, which is true of this corpus's `0xFF102030` +
  `0x00202020` but would not be true of every possible combination. Not a
  gap for this task (the only caller is this task's own control-arm test),
  but worth naming since the field is public API of a test-support file
  future tasks may reuse.
- `git status --short` before staging showed only the two intended files, no
  `analysis_options.yaml`.

## Commit

```
git add packages/jet_cad_2d_flutter/test/support/gpu_comparison.dart \
        packages/jet_cad_2d_flutter/test/gpu/resident_pixel_differential_test.dart
git commit -m "test(gpu): the pixel instrument compares colour, not only coverage"
```
