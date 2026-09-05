# Task 8 report — Mutation testing

**Status: DONE.** 14 of 14 named mutations fired; 14 of 14 killed on the
first shot; zero survivors. Full transcripts (diff, command, verbatim
`flutter test` output, restore, green re-run) are in
`docs/superpowers/notes/plan-e-mutation-log.md`, committed at `fda4e04`
("docs: Plan E's mutation log").

Every mutation was applied via `cp <file> <file>.bak` before editing, and
restored via `cp <file>.bak <file>` + `rm <file>.bak` — never
`git checkout --`. `git status --short` was checked clean after every
restore before moving to the next mutation.

## The fourteen, killed / survived, and the killing test

| id | mutation | verdict | killed by |
|---|---|---|---|
| M-E1 | `classifyTextPatches` returns `[]` (source edit) | KILLED | `text_order_test.dart`: four scale rows + "the label nothing later reaches" (patchCount 2→0); agrees with the seam — no Task 5 defect |
| M-E2 | inner loop starts at `0` instead of `t.instanceIndex` | KILLED | `text_patches_test.dart`: "an instance emitted BEFORE"; `text_order_test.dart`: "the label nothing later reaches" (patchCount 2→3) |
| M-E3 | `reachDevice = 0` for every kind | KILLED | `text_patches_test.dart`: "a stroke whose centerline misses the box..." (+3 more) |
| M-E4 | `unitsPerDevicePixel = 1.0 / devicePixelRatio` | KILLED | `text_patches_test.dart`: "the reach is expanded at the band floor" |
| M-E5 | `_patchPaint.blendMode = BlendMode.srcOver` | KILLED | `text_compositor_test.dart`: "a translucent later fill..." (+2 more); `text_order_test.dart`: 5/7 rows |
| M-E6 | `hits.add(i)` unconditionally | KILLED | `text_order_test.dart`: "the label nothing later reaches" (patchCount 2→3); `text_patches_test.dart`: 8 assertions |
| M-E7 | join reach `half` instead of `half * kMiterLimit` | KILLED | `text_patches_test.dart`: "a join's reach is the miter bound" |
| M-E8 | `points = 3` for a point | KILLED | `text_patches_test.dart`: "a point's box is its one point" |
| M-E9 | `saveLayer` opened after `canvas.transform` | KILLED | `text_compositor_test.dart`: "a patch puts later geometry over the ink... (srcATop)" (+2 more); `text_order_test.dart`: 5/7 rows |
| M-E10 | baseline flip dropped in `_drawLabel` | KILLED | `text_order_test.dart`: all 5 agreement rows |
| M-E11 | box pad at `kBandUpperScale` instead of `kBandLowerScale` | KILLED | `resident_text_test.dart`: "the pad is one device pixel at the band floor, not at the ceiling" (+2 more) |
| M-E12 | compositor matches patches by position, not `textIndex` | KILLED | `text_compositor_test.dart`: "labels and patches walk in list order, with one cursor" |
| M-E13 | `patchRegionFor`'s `x0` unclamped | KILLED | `text_patches_test.dart`: "a label partly off the top-left edge is clamped, not negative" |
| M-E14 | `sub.setRange` copies `hits` in reverse | KILLED | `text_patches_test.dart`: "a sub-buffer keeps main-buffer order..." |

**No survivors.**

## Judgment calls, all logged in full in the mutation log

Several mutations (M-E3, M-E4, M-E6, M-E9, M-E10) name two tests in the
brief, and for each of these the second named test did not additionally go
red even though the primary named test killed the mutation outright. Each
is investigated and explained in the log, not papered over. M-E1 carries a
separate, explicit stop condition of its own, addressed first below:

- **M-E1 (the stop-condition check):** the brief's explicit concern —
  "if the seam goes red but the source edit does not, stop and report
  BLOCKED" — does NOT apply. The source edit and the seam agree: both break
  the same four scale rows and the patchCount row.
- **M-E3:** `text_order_test.dart`'s GRAZED row did not fire. Investigated:
  the fixture's own comment admits the grazing stroke's y-position is only
  "near" the box's top; with `FlutterTextMeasurer`'s real font metrics
  (rather than the fixed-metrics double `resident_text_test` uses), the
  ascent already pushes the padded box past the stroke's centerline, so
  removing the width-reach term doesn't flip that row's classification.
  The unit test (`text_patches_test.dart`) isolates the reach term
  precisely and kills it.
- **M-E4:** `text_order_test.dart`'s scale-0.5 row did not fire — the
  fixture's overlap margins are wide enough at that scale to absorb a 2x
  under-expansion of the reach. Killed cleanly by the unit test instead.
- **M-E6:** `text_order_test.dart` DID fire, but at patchCount 3, not the
  brief's predicted 4 — `TINY` has zero instances emitted after it in the
  fixture, so it never enters `hits` even unconditionally. Reported as
  observed, not adjusted.
- **M-E9:** the brief's second named test, "outer transform once", exercises
  the label compositor's non-patched path (`patches: const []`), where the
  mutation is a no-op (`layerBounds: null`). The patched path's own tests
  (srcATop, translucent-fill) kill it decisively instead.
- **M-E10:** `text_compositor_test.dart`'s own 7 tests all passed — that
  file's `samplePoints()` scans dynamically for ink/blank pixels rather
  than fixed coordinates, so it still finds valid sample points even with
  the glyph rendered upside-down. A coverage gap in that unit file, not a
  survivor: the differential test (`text_order_test.dart`) kills the
  mutation outright, on all 5 agreement rows, matching the brief's "every
  row."

None of these were treated as survivors and none prompted widening a
mutation or editing a test — each mutation already has a test that went
properly red, and the discrepancy from the brief's prediction is recorded
with a concrete, verified explanation in the log.

## Final gate

```
cd packages/jet_cad_2d_flutter && flutter test test/gpu/
```
→ `+182: All tests passed!` — same count (182) as the pre-mutation
baseline, confirming the tree is fully restored after all fourteen
mutations.

## Commit

`fda4e04` — "docs: Plan E's mutation log" (the log file only;
`git status --short` was clean of anything else at commit time).
