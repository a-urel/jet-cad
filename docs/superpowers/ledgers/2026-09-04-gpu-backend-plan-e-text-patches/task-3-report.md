# Task 3 report: The corpus — labels the spec names, and a guard that each overlap is real

## Summary

Implemented `textOverlapFixture` and `strokeInkInsideLabel` in
`packages/jet_cad_2d_flutter/test/support/fixtures.dart`, and the four guard
tests (verbatim from the brief, with the controller's `async`/`await`
amendment) in `packages/jet_cad_2d_flutter/test/support/fixtures_test.dart`.
Both new symbols follow the brief exactly; the only deviations are two
implementation details not pinned by the brief's signature (see "Deviations
from the brief" below), and no coordinate in the brief needed correction —
every measured overlap cleared its floor comfortably on the first try.

## Files changed

- `packages/jet_cad_2d_flutter/test/support/fixtures.dart` — added
  `kTextOverlapLabelHeight`, `textOverlapFixture`, `strokeInkInsideLabel`, and
  two private helpers (`_entityHandles`, `_paintAloneAlpha`); widened the
  `dart:ui` import to include `ImageByteFormat`.
- `packages/jet_cad_2d_flutter/test/support/fixtures_test.dart` — appended the
  `group('textOverlapFixture', ...)` block from the brief's Step 1.

## Measured overlap numbers (the actual integers)

Captured with a throwaway measurement test (`test/support/measure_test.dart`,
written, run, then deleted — never committed):

| pair | measured overlap | floor | result |
|---|---|---|---|
| stroke 903 / label 901 (COVERED, higher-handle patch) | **484** | > 200 | pass |
| stroke 900 / label 901 (COVERED, lower-handle, must also cross) | **486** | > 200 | pass |
| stroke 922 / label 921 (GRAZED, lineweight 400) | **603** | > 50 | pass |
| stroke 922 / label 921 (GRAZED, `grazeLineweight: 1`, hairline) | **0** | == 0 | pass |

None of the brief's coordinates needed adjustment — every number cleared its
floor with margin, and the hairline case landed at exactly 0 as required. No
correction to record in the ledger.

## TDD evidence

**RED** — `flutter test test/support/fixtures_test.dart` after Step 1 (guard
tests appended, `textOverlapFixture`/`strokeInkInsideLabel` not yet defined):

```
test/support/fixtures_test.dart:179:20: Error: Method not found: 'strokeInkInsideLabel'.
test/support/fixtures_test.dart:181:20: Error: Method not found: 'strokeInkInsideLabel'.
test/support/fixtures_test.dart:188:17: Error: Method not found: 'strokeInkInsideLabel'.
test/support/fixtures_test.dart:194:11: Error: Method not found: 'textOverlapFixture'.
test/support/fixtures_test.dart:196:17: Error: Method not found: 'strokeInkInsideLabel'.
00:00 +0 -1: loading .../fixtures_test.dart [E]
  Failed to load ".../fixtures_test.dart":
  Compilation failed ...
Some tests failed.
```

Compile error, exactly as the brief's Step 2 predicts.

**First GREEN attempt caught a real bug in the helper, not the fixture** —
after writing `textOverlapFixture` and a first cut of `strokeInkInsideLabel`
that painted onto a white-filled background (copying `fill_seam_test.dart`'s
`renderThrough` pattern), the hairline assertion failed:

```
00:00 +6: textOverlapFixture stroke 922's centerline misses label 921 but its width reaches it
00:00 +6 -1: textOverlapFixture stroke 922's centerline misses label 921 but its width reaches it [E]
  Expected: <0>
    Actual: <480000>
  at hairline width the same centerline touches no glyph
```

480000 = 800×600 — the whole viewport. The white backdrop I'd copied from
`fill_seam_test.dart` (which reads RGB channel deltas, not alpha) left every
pixel's alpha at 255 regardless of content, so "both alphas exceed 128" was
true everywhere. Fixed by removing the background fill — the canvas starts
fully transparent, so alpha now reflects exactly what each isolated entity
inked. Documented the reasoning inline (`_paintAloneAlpha`'s comment) so a
future reader doesn't reintroduce the same copy-paste.

**GREEN** — `flutter test test/support/fixtures_test.dart` after the fix:

```
00:00 +0: loading .../fixtures_test.dart
00:00 +0: shadedDashFixture is not degenerate in any of the four ways that would make a dash test pass vacuously
00:00 +1: fillFixture is not degenerate in any of the four ways that would hide a defect
00:00 +2: fillFixture the fill and the higher-handle stroke actually overlap on screen
00:00 +3: textOverlapFixture has the handles the table names, and the strokes are thick
00:00 +4: textOverlapFixture the placement is mirrored, rotated and non-uniform
00:00 +5: textOverlapFixture stroke 903 actually crosses label 901 at the fitted camera
00:00 +6: textOverlapFixture stroke 922's centerline misses label 921 but its width reaches it
00:00 +7: All tests passed!
```

## Gate commands and output

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:07 +592 ~1: All tests passed!
EXIT:0
```
(591 pass, 1 pre-existing skip unrelated to this task — `~1` also appears in
the pre-task baseline shape of this suite's own summary lines.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
EXIT:0
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 96 files (0 changed) in 0.15 seconds.
EXIT:0
```
(First run reported `Changed test/support/fixtures.dart` and
`test/support/fixtures_test.dart` — exit 1 — because my hand-written additions
weren't already in `dart format`'s canonical layout; ran `dart format
test/support/fixtures.dart test/support/fixtures_test.dart` to fix, then
re-ran the check above to confirm 0 changed / exit 0.)

```
$ git status --short
(before staging)
 M test/support/fixtures.dart
 M test/support/fixtures_test.dart
```
No `analysis_options.yaml` touched.

## Commit

`5262150` — `test(gpu): a corpus of labels and what covers them`
(2 files changed, 286 insertions, 1 deletion)

## Deviations from the brief, and why

The brief's Step 4 prose (and the controller's amending notes) describe
`strokeInkInsideLabel`'s behavior but not its exact internal mechanics for two
things the signature doesn't pin down:

1. **How "every other entity" is discovered.** `EntityStore` has no public
   "all handles" accessor beyond `liveSlots` (an `Iterable<int>`) plus
   `handleAt(slot)`. `_entityHandles(doc)` snapshots that into a `List<Handle>`
   before any removal starts, so the helper works generically against
   whichever document it's given (including the hairline rebuild, and
   whatever fixture Task 5 hands it) rather than hardcoding this fixture's
   handle set.

2. **How the document is restored between the two isolated renders.** The
   brief's Step 4 doesn't say the two renders share one `doc` instance, but
   the guard tests do call `strokeInkInsideLabel(doc, ...)` twice in a row on
   the same `doc` (the 903/901 and 900/901 assertions in one test body), so
   the helper must leave `doc` exactly as it found it. I used
   `doc.commands.execute(RemoveEntityCommand(h))` for every non-kept,
   non-floor entity, then `doc.commands.undo()` the same number of times
   after reading the picture back — `CommandDispatcher`'s existing,
   already-tested undo stack, rather than inventing document cloning. A
   boundary's removal cascades onto its linked fill
   (`RemoveEntityCommand`'s own doc comment), so the removal loop guards each
   handle with `doc.entities.containsHandle(h)` before removing it, and only
   counts (for the matching number of undos) the removals that actually
   fired.

Both are additive implementation choices inside the one function the brief
specified by signature and behavior only; nothing outside Step 3/Step 4's
scope was touched.

One more deviation worth flagging explicitly: my first draft painted onto a
white background (copied from `fill_seam_test.dart`'s pattern, which this
file's own `strokeInkInsideFill` neighbor does not use). That was wrong for
an alpha-threshold instrument and is described above under "TDD evidence" —
the fix removes the background fill entirely; the final code has no
`Canvas.drawRect` call at all.

## Self-review

- **Completeness**: every handle in the brief's table (899, 900, 901, 903,
  904/905, 910, 911, 921, 922, 931, 990) is constructed by
  `textOverlapFixture`; the handle-table doc comment lists all of them
  (899 is described in the surrounding prose rather than the table, matching
  the brief's own table, which also omits 899). All four guard tests from
  Step 1 are present verbatim, with the controller's amendment (`async` on
  the third test, `await` throughout).
- **Quality**: the fixture's doc comment carries the full handle table and
  the reasoning paragraph, matching `fillFixture`'s style; `_paintAloneAlpha`
  and `strokeInkInsideLabel` each carry a reasoned comment explaining the
  non-obvious choices (why no background fill, why undo rather than clone,
  why the boundary/fill cascade needs a liveness guard).
- **Discipline**: no changes outside the two files the brief names; no
  refactor of `fillFixture` or any other existing fixture; `grazeLineweight`
  is the only new fixture parameter, exactly as specified.
- **Testing**: the guards measure, not assume — confirmed by the RED/GREEN
  transcript above, which caught a real defect (the white-background bug) in
  the helper itself, and by the four measured integers, none of which is a
  degenerate 0/max value except the one the brief predicts should be exactly
  0 (the hairline graze).

## Concerns

None. All four package-gate commands are green with real, non-fabricated
output; every guard's overlap number is comfortably clear of its floor; no
ledger correction is needed since no coordinate moved from the brief's
values.

## Fix round 1 (review finding R3-1)

**Finding (Important, plan-mandated):** `strokeInkInsideLabel`'s shared-pixel
count iterates the whole 800x600 frame, and its correctness depended on floor
entity 899 never producing alpha>128 anywhere in the frame — since 899 was
left unremoved in *both* isolated renders, any pixel where it crossed the
threshold would be double-counted as "shared" regardless of actual
stroke/label overlap, and nothing in the diff asserted that never happens.

**Controller ruling (R3-1):** paint the entity truly alone — remove 899 too in
`_paintAloneAlpha`, so only the placement instance 990 (a node, never a
removal candidate) and the one entity under measurement remain in each
isolated render. The camera is already fixed once, from the full document's
extents, before either isolated paint, so removing 899 moves no pixel.

**What changed** (`packages/jet_cad_2d_flutter/test/support/fixtures.dart`):

- `_paintAloneAlpha`: dropped the `floor`/`Handle(899)` exception from the
  removal filter — `toRemove` is now every live entity except `keep`, full
  stop. 899 is removed and undone exactly like every other entity.
- Rewrote `_paintAloneAlpha`'s doc comment to explain why 899 is removed now
  (the review's own reasoning) rather than the old "it's thin enough to be
  harmless" argument, and to spell out why 990 needs no special-casing (it's
  a node; `RemoveEntityCommand` only ever targets entities).
- Added the one-line comment `strokeInkInsideLabel`'s reviewer Minor asked
  for, directly above the whole-frame count loop, stating that the
  whole-frame count is safe now specifically because each byte array holds
  exactly one entity's ink.

No change to `textOverlapFixture`, to the guard tests, or to any coordinate —
this was a fix to `_paintAloneAlpha`'s removal set only.

**Covering tests:** the same four guard tests in
`test/support/fixtures_test.dart` (`textOverlapFixture` group) exercise this
code path directly — they call `strokeInkInsideLabel` for every named pair,
including the hairline rebuild, and would catch a regression to the shared
count. Re-ran them explicitly plus the throwaway measurement test (written,
run, deleted — not committed) to print the four integers.

**Command and output — focused test:**

```
$ cd packages/jet_cad_2d_flutter && flutter test test/support/fixtures_test.dart
...
00:00 +3: textOverlapFixture has the handles the table names, and the strokes are thick
00:00 +4: textOverlapFixture the placement is mirrored, rotated and non-uniform
00:00 +5: textOverlapFixture stroke 903 actually crosses label 901 at the fitted camera
00:00 +6: textOverlapFixture stroke 922's centerline misses label 921 but its width reaches it
00:00 +7: All tests passed!
```

**Re-measured overlap numbers** (unchanged from the pre-fix numbers — none of
the fixture's own geometry ever put 899's hairline inside any of these four
regions, so removing it from the isolated renders moved nothing here; it was
the general-case hazard the reviewer flagged, not one this specific corpus
happened to trigger):

| pair | measured overlap | floor | result |
|---|---|---|---|
| stroke 903 / label 901 | **484** | > 200 | pass |
| stroke 900 / label 901 | **486** | > 200 | pass |
| stroke 922 / label 921 (thick) | **603** | > 50 | pass |
| stroke 922 / label 921 (hairline) | **0** | == 0 | pass |

**Full package gate:**

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:07 +592 ~1: All tests passed!
TEST EXIT:0

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
ANALYZE EXIT:0

$ dart format --output=none --set-exit-if-changed .
Formatted 96 files (0 changed) in 0.14 seconds.
FORMAT EXIT:0
```

**`git status --short` before staging:**

```
 M packages/jet_cad_2d_flutter/test/support/fixtures.dart
```

No `analysis_options.yaml` touched.

**Commit:** `e16b5ba` — `test(gpu): the overlap guard paints one entity truly alone`
(1 file changed, 24 insertions, 8 deletions)
