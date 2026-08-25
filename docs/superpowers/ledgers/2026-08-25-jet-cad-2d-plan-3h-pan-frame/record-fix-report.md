# Plan 3h — record-only correction report

Record-only correction at the close of Plan 3h. No production code and no
test logic changed; every check below confirms it. Base: `main` at `122b6e3`
(clean). Files touched: `STATUS.md`,
`docs/superpowers/notes/plan-3h-mutation-log.md`,
`packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`,
`packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`. Nothing else in
`git status --porcelain`.

---

## Item 1 — the anti-vacuity clause claims something it does not do

Fixed the four cited locations, plus two more spots carrying the identical
inaccurate phrase ("inside the band the fallback owes" applied to
`debugLastStrip`) found while implementing the ruling:
`tile_comparison.dart`'s `[minimumStripInk]` doc (near line 309, pre-edit)
and `plan-3h-mutation-log.md`'s "Three things changed" bullet 2 (near line
52, pre-edit). All are doc comments or `//` prose, never a `reason:` string
inside an `expect(...)` call — those are left untouched to keep this a
comments-only change (see "one deliberate non-change" below).

### `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart:71-72` (the `liveStripInk` field doc)

**Old:**
```
/// Non-transparent pixels of the **live** capture that lie inside the band
/// the fallback owes — `TileCache.debugLastStrip`, in device pixels.
///
/// **This is the anti-vacuity clause the other six could not supply, and it
/// was earned.** [liveInk] counts the whole frame, which at a fallback
/// sample is dominated by the tiles the frame blitted; a fallback that
/// walked the strip and found nothing in it still leaves [liveInk] in the
/// tens of thousands and every pixel count at zero. Two of the eight swept
/// offsets were exactly that until `fillingGrid`'s extent was widened —
/// see its doc comment. Zero here means the sample proves nothing about
/// the fallback, however green it reads.
```

**New:**
```
/// Non-transparent pixels of the **live** capture that lie inside
/// `TileCache.debugLastStrip`, in device pixels — [uncovered] padded
/// outward by `kTileSlack`, **not** `uncovered` itself. `uncovered` is the
/// band the fallback actually owes; the pad reaches back into area the
/// frame already blitted, so this field is weaker than its name might
/// suggest and does not prove the band owed carried any ink.
///
/// **A weaker anti-vacuity clause than the other six, and the gap is
/// named (gap H7 in STATUS.md).** [liveInk] counts the whole frame, which
/// at a fallback sample is dominated by the tiles the frame blitted; a
/// fallback that walked the strip and found nothing in it still leaves
/// [liveInk] in the tens of thousands and every pixel count at zero. What
/// actually closes that gap is `fillingGrid`'s extent, not this field: two
/// of the eight swept offsets carried no ink in the band owed until that
/// fixture was widened — see its doc comment — and a re-review confirmed
/// this clause alone would not have caught it: on the old, narrower
/// extent, with this clause live at a floor of 200, deleting
/// `canvas.translate` from `TileCache.paintFrame` still left the whole
/// widget suite green. The one place this field is demonstrably
/// load-bearing is under M3, where it reads `0` on the inverted rect
/// `Rect.fromLTRB(395.0, 52.0, 387.0, 300.0)` (`left > right`, so
/// `inkInside` returns `0` by construction) — see the mutation log.
```

### `tile_comparison.dart` — `measureFallbackAgreement`'s comment block (was lines ~350-359) and its `[minimumStripInk]` doc (was ~309)

Both rewritten the same way: "ink inside the band the fallback owes" →
"ink inside `strip`/`debugLastStrip` (`uncovered` padded outward by
`kTileSlack`)", with an explicit statement that this is weaker than the band
owed, and a pointer to gap H7 and to `fillingGrid`'s extent as the thing that
actually protects the sweep. Full diff in the working tree; see
`git diff packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`.

**One deliberate non-change.** The `expect(report.liveStripInk, ...)`
call's `reason:` string (~line 363-365) still reads "the live frame carries
no ink inside the band the fallback owes ($strip)" — the same imprecise
phrase. Left alone on purpose: the task's non-negotiable is "change no test
logic... comments and doc comments only, in the test tree," and a `reason:`
string is a string literal inside an `expect(...)` call, not a `//` or `///`
comment. I judged rewriting it to be outside the authorized scope even though
it carries the same inaccuracy. Flagging this for the controller in case the
ruling intended reason strings to be in scope too.

### `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart` (was line ~297-303, the `fillingGrid` doc comment)

**Old:**
```
/// **What the predecessor extent (20..320 by 10..240) did.** It contained the
/// resting visible box on all four edges, but by only about 9 to 13 *screen*
/// pixels, against a sweep that pans 37 to 71. At `Offset(-41, 0)` and
/// `Offset(0, -41)` the entering strip therefore landed on bare canvas: the
/// live fallback drew **nothing** there and the sweep's zero-differing-pixel
/// assertions were satisfied vacuously. Those two offsets are also precisely
/// the ones whose strip does not start at (0, 0) -- the only ones where
/// `TileCache.paintFrame`'s `canvas.translate(strip.left, strip.top)` is not
/// a no-op -- so deleting that line left the whole widget suite green. The
/// extent above is what gives that line a witness.
```

**New:** (adds a disambiguation of "strip" → "`uncovered` region" and a new
closing sentence naming what does *not* supply the witness)
```
/// **What the predecessor extent (20..320 by 10..240) did.** It contained the
/// resting visible box on all four edges, but by only about 9 to 13 *screen*
/// pixels, against a sweep that pans 37 to 71. At `Offset(-41, 0)` and
/// `Offset(0, -41)` the entering `uncovered` region therefore landed on bare
/// canvas: the live fallback drew **nothing** there and the sweep's
/// zero-differing-pixel assertions were satisfied vacuously. Those two
/// offsets are also precisely the ones whose strip does not start at (0, 0)
/// -- the only ones where `TileCache.paintFrame`'s
/// `canvas.translate(strip.left, strip.top)` is not a no-op -- so deleting
/// that line left the whole widget suite green. The extent above is what
/// gives that line a witness -- **not** the ink-inside-the-strip clause
/// added alongside it (`InkReport.liveStripInk` in `tile_comparison.dart`):
/// that clause measures `TileCache.debugLastStrip`, which pads `uncovered`
/// outward, so it can find ink in already-blitted area even when the band
/// the fallback owes is itself bare. A re-review confirmed that clause could
/// not have supplied this witness on its own: restoring the predecessor
/// extent with that clause live still lets `canvas.translate`'s deletion
/// pass the whole suite. See gap H7 in STATUS.md.
```

### `docs/superpowers/notes/plan-3h-mutation-log.md` (was line ~258-262, the "band-ink column" paragraph) plus the "Three things changed" bullet 2 (was ~50-52)

**Old (bullet 2, "Three things changed"):**
```
2. **A seventh anti-vacuity clause**, `InkReport.liveStripInk`: the live frame
   must carry ink **inside the band the fallback owes**
   (`TileCache.debugLastStrip`), not merely somewhere in the frame. The six
   existing clauses all passed on the two vacuous samples.
```

**New:**
```
2. **A seventh anti-vacuity clause**, `InkReport.liveStripInk`: the live frame
   must carry ink **inside `TileCache.debugLastStrip`** -- `uncovered` padded
   outward by `kTileSlack`, a weaker region than the band the fallback
   actually owes, since the pad reaches into area the frame already
   blitted -- not merely somewhere in the frame. The six existing clauses all
   passed on the two vacuous samples. **This clause did not, by itself, give
   the fixture widening its witness**: what actually closes the vacuous-band
   case is the widened extent below, not this clause -- see gap H7 in
   STATUS.md.
```

**Old (band-ink column paragraph):**
```
`stray`, `uncovered` and `differing` are all `0` at every one of the eight
swept offsets, and `live` equals `tiled` at each (41464, except 42992 at the
two `(0, 37)`/`(0, 53)` offsets). **The band-ink column is what makes this a
result rather than an artefact**: every one of the eight bands the fallback
owes carries between 2224 and 9696 device pixels of live ink, so the sweep had
something to lose at every offset and did not lose it. Under the *old*
fixture two of these bands were empty and the zeros there meant nothing.
```

**New:**
```
`stray`, `uncovered` and `differing` are all `0` at every one of the eight
swept offsets, and `live` equals `tiled` at each (41464, except 42992 at the
two `(0, 37)`/`(0, 53)` offsets). **The band-ink column is what makes this a
result rather than an artefact, and it is weaker than it sounds**: it
measures ink inside the `strip` column above (`TileCache.debugLastStrip`,
`uncovered` padded outward by `kTileSlack`), not inside `uncovered` itself --
the band the fallback actually owes -- so a nonzero reading here does not by
itself prove the band owed carried ink. On this fixture it did not need to:
every one of the eight padded strips carries between 2224 and 9696 device
pixels of live ink, so the sweep had something to lose at every offset and
did not lose it. Under the *old* fixture two of these strips were empty and
the zeros there meant nothing. What actually protects this sweep from a
vacuous band is `fillingGrid`'s extent, not the band-ink column -- see gap H7
in STATUS.md.
```

No historical verbatim test transcript was altered — the quoted `[E]` block
at the old line ~379 ("the live frame carries no ink inside the band the
fallback owes...") is real recorded output from the actual `reason:` string
at the time it was captured, and is left as-is; only surrounding prose
changed.

### `STATUS.md` — new gap H7

Added after H6, in the existing gap list, continuing the lettering:

```
- **H7.** The anti-vacuity clause added alongside `fillingGrid`'s widening
  (`InkReport.liveStripInk`) measures ink inside `TileCache.debugLastStrip`
  — `uncovered` padded outward by `kTileSlack` — not inside `uncovered`
  itself, the band the fallback actually owes. The pad reaches back into
  area the frame already blitted, so the clause is weaker than its own
  comment claimed: a re-review showed that on the predecessor, too-narrow
  `fillingGrid` extent, with this clause live at a floor of 200, deleting
  `TileCache.paintFrame`'s `canvas.translate` still left the whole widget
  suite green. Measuring ink inside `uncovered` rather than the padded strip
  would need a debug accessor on `TileCache` that does not exist. Until
  then, the sweep's protection against a vacuous band rests on
  `fillingGrid` clearing the largest swept pan offset, not on this clause.
  Added 2026-08-26 by the final record re-review; not a gate this plan
  built.
```

Also updated: heading "Gaps H1–H6" → "Gaps H1–H7" (with an added clause
crediting H7 to "the final record re-review (2026-08-26)"), and the "Resume
here" section's "gaps H1–H6" cross-reference → "H1–H7".

---

## Item 2 — re-firing M2 and M3

Copied `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` aside to the
scratchpad before any mutation; restored from that copy after each run
(never `git checkout`). `lib/` verified byte-identical to `122b6e3` after
each restore (see "lib/ unchanged" below).

### M2 (`kTileSlack` → `0.0` at all four `stripFor` sites)

Command: `CI=true flutter test` (whole `packages/jet_cad_2d_flutter`
package), one run.

**Verbatim result:**
```
00:06 +369 ~1 -3: Some tests failed.

Failing tests:
  .../test/tile_cache_test.dart: stripFor a strip touching the bottom-right clamps there and pads inward
  .../test/tile_cache_test.dart: stripFor clamps one edge at a time
  .../test/tile_cache_test.dart: stripFor pads an interior rect on every side
```

Same three failing test names as the mutation log already recorded.
**`+369 ~1 -3` — matches the log's existing figure, not the re-reviewer's
claimed `+370 ~1 -3`.**

### M3 (`kTileSlack` → `-20.0` at all four `stripFor` sites)

Command: `CI=true flutter test` (whole `packages/jet_cad_2d_flutter`
package), one run.

**Verbatim result:**
```
00:05 +365 ~1 -7: Some tests failed.

Failing tests:
  .../test/invariants/tile_budget_test.dart: criterion 12: a frame at the cap still equals the live frame
  .../test/tile_cache_test.dart: stripFor a strip touching the bottom-right clamps there and pads inward
  .../test/tile_cache_test.dart: stripFor clamps one edge at a time
  .../test/tile_cache_test.dart: stripFor clamps to the viewport rather than growing past it
  .../test/tile_cache_test.dart: stripFor pads an interior rect on every side
  .../test/tile_fallback_test.dart: criterion 2 and 2c: a partly baked frame equals the live frame
  .../test/tile_fallback_test.dart: criterion 2b: the near-axis arm stays inside the tiled path's bound
```

Same seven failing test names as the mutation log already recorded.
**`+365 ~1 -7` — matches the log's existing figure, not the re-reviewer's
claimed `+366 ~1 -7`.**

### What this means for the log

My own two re-fires — done independently, one run each, file copied aside
and restored from the copy both times — reproduce the mutation log's
existing numbers exactly (`+369 ~1 -3` and `+365 ~1 -7`), not the
re-reviewer's (`+370 ~1 -3` / `+366 ~1 -7`). Per "never synthesize test
output," I did not overwrite the log's numbers with the re-reviewer's
figures; instead I added a dated note under each mutant's verbatim block in
`plan-3h-mutation-log.md` recording that this re-fire reproduced the
original number, not the re-review's, so the discrepancy is on the record
rather than silently resolved. The controller may want a further,
independent tie-breaking run — three different measurements now exist for
each mutant (369/370, 365/366) with 2-of-3 agreeing with the log as
originally written.

---

## Item 3 — stale branch range

**Grep before any edit** (`grep -n "838c454\|f642202" STATUS.md`):
```
4:**Verified against:** `main` at `838c454` — Plan 3h's fix round 1, the last
6:on `main`, `f642202..838c454`, eight tasks (the eighth split into 8a and 8b),
116:| Suite | State (on `main` at `838c454`, run, not read off a report) |
406:`main` at `f642202..838c454`, eight tasks (the eighth split into 8a and 8b),
1251:**Done, worked directly on `main`, `f642202..838c454`, eight tasks (the eighth
```
Five occurrences, matching the task's count.

**Grep after all edits** (`grep -n "838c454" STATUS.md` — zero matches;
`grep -n "f642202" STATUS.md`):
```
7:`f642202..122b6e3`, eight tasks (the eighth split into 8a and 8b), nothing in
407:`main` at `f642202..122b6e3`, eight tasks (the eighth split into 8a and 8b),
1252:**Done, worked directly on `main`, `f642202..122b6e3`, eight tasks (the eighth
```
All five updated to end at `122b6e3`; `f642202` (the range start) correctly
retained. Line numbers shifted (+1, +1, +1) because gap H7's addition earlier
in the file pushed line 1251 to 1252, and the "Verified against" paragraph
gained a line from rewording.

**`Verified against` line** also updated, per the task's instruction to
check it: now reads `main` at `122b6e3`, described as "Plan 3h's fixture
widening and full mutant re-measurement, the last code commit before this
file's own record-only correction commit." `Last updated` bumped from
2026-08-25 to 2026-08-26 to match (this session's date), since the file now
records 2026-08-26 work.

---

## Item 4 — `kTriangleBudgetRatio`

Not touched. `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`
still declares `const double kTriangleBudgetRatio = 0.97;`, unchanged, and
none of my wording edits reference or imply a different bound. Confirmed via
`git diff` that the constant's own line and its surrounding doc comment are
untouched.

---

## `lib/` unchanged — proof

```
$ git diff --stat 122b6e3 -- packages/jet_cad_2d_flutter/lib/
(no output)
$ git status --porcelain
 M STATUS.md
 M docs/superpowers/notes/plan-3h-mutation-log.md
 M packages/jet_cad_2d_flutter/test/support/tile_comparison.dart
 M packages/jet_cad_2d_flutter/test/support/tile_fixture.dart
```
No file under `lib/` appears in either. After each mutant re-fire,
`tile_cache.dart` was restored from the pre-mutation copy and `diff`
against that copy reported no difference before moving on.

Also confirmed clean of the three named traps:
`analysis_options.yaml` — not in `git status`.
`apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj` — not in
`git status`.
No golden PNG appears in `git status` after the `--tags golden` run.

---

## Closing suite output

`packages/jet_cad_2d_flutter`, on the restored (unmutated) tree:

```
$ CI=true flutter test
...
00:06 +372 ~1: All tests passed!

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.4s)

$ dart format --output=none --set-exit-if-changed .
Formatted 65 files (0 changed) in 0.13 seconds.

$ CI=true flutter test --tags golden
...
00:03 +35: All tests passed!
```
`git status --porcelain | grep -i png` — no output; no golden PNG
regenerated.

`packages/jet_cad_2d` (untouched, checked for completeness per the repo's
own "every task ends green" rule):
```
$ dart test
...
00:03 +797: All tests passed!
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.19 seconds.
```

---

## Summary

- Status: complete, tree green, `lib/` byte-identical to `122b6e3`.
- Commit: `bbb83e0328e45f50f6654d573092039c7bedeba0` ("docs: Plan 3h's record
  correction -- the padded strip is not the band owed"), on `main`.
- Files changed: `STATUS.md`, `docs/superpowers/notes/plan-3h-mutation-log.md`,
  `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`,
  `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`.
- M2 re-fire: `+369 ~1 -3` (matches the log, not the re-reviewer's `+370`).
- M3 re-fire: `+365 ~1 -7` (matches the log, not the re-reviewer's `+366`).
- Concerns for the controller:
  1. My re-fires (one run each) agree with the log as originally written,
     not with the re-reviewer's two-runs-each figures. Recorded both in the
     log rather than resolved; a tie-breaking run may be worth requesting.
  2. The `reason:` string in `measureFallbackAgreement`'s
     `expect(report.liveStripInk, ...)` call still says "the band the
     fallback owes" — left alone as a string literal rather than a comment,
     under the "comments and doc comments only" constraint. Flagging in
     case that was meant to be in scope.
  3. This session created one commit (`bbb83e0`) since the task's own
     report format asked for a commit SHA; the repo's general rule is to
     commit only when asked, and this is read as that request.

---

## Follow-up (2026-08-26, addressing coordinator feedback on `bbb83e0`)

Two more record-only fixes, both requested by the coordinator after `bbb83e0`. No production code, no test logic. Files touched this round: `docs/superpowers/notes/plan-3h-mutation-log.md`, `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`, `packages/jet_cad_2d_flutter/test/tile_fallback_test.dart`.

### Follow-up 1 — M2/M3 count discrepancy: resolved, not merely re-flagged

The coordinator ran their own tie-break re-fire of M2 (copy-aside, `kTileSlack → 0.0`, one run, restore, confirmed `+372 ~1` afterwards) and got `+369 ~1 -3`, matching this log and my own re-fire, not the re-review's `+370 ~1 -3`. They also pointed out the total-count identity settles both mutants without any further run: this suite is exactly 373 tests (`372 pass + 1 skip` at baseline), so `+369 ~1 -3` sums to 373 and `+370 ~1 -3` sums to 374 — one test that does not exist. Same for M3: `+365 ~1 -7` sums to 373, `+366 ~1 -7` sums to 374.

Replaced the dated "discrepancy, not resolved" notes under both mutants in `plan-3h-mutation-log.md` with resolution text.

**M2 (was, added last round):**
```
**Re-fired again 2026-08-26 for the final record re-review**, which had
measured `+370 ~1 -3` twice and flagged the `+369 ~1 -3` above as possibly
off by one. This re-fire copied `lib/src/tile_cache.dart` aside, applied the
same four-site `kTileSlack → 0.0` edit, ran `CI=true flutter test` (whole
`packages/jet_cad_2d_flutter` package) once, and restored the file from the
copy (never `git checkout`). Result: **`+369 ~1 -3: Some tests failed.`**,
digit-identical to the transcript above, same three failing test names. This
matches what this log already recorded, not the re-reviewer's `+370 ~1 -3`;
recorded per "never synthesize test output" rather than silently adopting
either prior figure.
```

**M2 (now):**
```
**Settled 2026-08-26: `+369 ~1 -3` is confirmed, `+370 ~1 -3` is ruled
out.** Three independent sources agree on `+369 ~1 -3`: this log's original
transcript above, a re-fire for the final record re-review (copied
`lib/src/tile_cache.dart` aside, applied the same four-site
`kTileSlack → 0.0` edit, ran `CI=true flutter test` once, restored from the
copy — never `git checkout`), and a second, independent re-fire by the
controller using the same method. A fourth measurement read `+370 ~1 -3`
twice; the total-count identity rules it out rather than a majority vote:
`369 passed + 3 failed + 1 skipped = 373`, this suite's exact size, while
`370 + 3 + 1 = 374` implies one test more than exists.
```

**M3 (was, added last round):**
```
**Re-fired again 2026-08-26 for the final record re-review**, which had
measured `+366 ~1 -7` twice and flagged the `+365 ~1 -7` above as possibly
off by one. This re-fire copied `lib/src/tile_cache.dart` aside, applied the
same four-site `kTileSlack → -20.0` edit, ran `CI=true flutter test` (whole
`packages/jet_cad_2d_flutter` package) once, and restored the file from the
copy (never `git checkout`). Result: **`+365 ~1 -7: Some tests failed.`**,
the same seven failing test names as above. This matches what this log
already recorded, not the re-reviewer's `+366 ~1 -7`; recorded per "never
synthesize test output" rather than silently adopting either prior figure.
```

**M3 (now):** unlike M2, the coordinator did not personally re-fire M3 — their message only re-ran M2 and applied the counting identity to M3 — so the M3 resolution names two run-based sources (the log's transcript and my re-fire) plus the identity, not three re-fires:
```
**Settled 2026-08-26: `+365 ~1 -7` is confirmed, `+366 ~1 -7` is ruled
out.** This log's original transcript above and a second, independent re-fire
for the final record re-review (copied `lib/src/tile_cache.dart` aside,
applied the same four-site `kTileSlack → -20.0` edit, ran
`CI=true flutter test` once, restored from the copy — never `git checkout`)
both read `+365 ~1 -7`, the same seven failing test names each time. A third
source, the total-count identity, rules out the `+366 ~1 -7` a fourth
measurement read twice, rather than a majority vote deciding it:
`365 passed + 7 failed + 1 skipped = 373`, this suite's exact size, while
`366 + 7 + 1 = 374` implies one test more than exists.
```

Nothing in the log now implies either count is unsettled.

### Follow-up 2 — the `reason:` string, and a grep for siblings

**Grep before fixing** (`grep -rn "band the fallback owes" packages/jet_cad_2d_flutter/test/`):
```
test/tile_fallback_test.dart:51:    // requiring the live frame to carry ink inside the band the fallback
test/support/tile_comparison.dart:74:  /// band the fallback actually owes; the pad reaches back into area the
test/support/tile_comparison.dart:364:    // and weaker than ink inside the band the fallback owes.** The two
test/support/tile_comparison.dart:382:            'fallback owes ($strip), so every pixel assertion below is '
```
Line 74 and 364 were already correct (they say the padded strip is *weaker than* the band owed — that's the accurate framing this whole correction is arguing for). Two carried the false claim outright: `tile_comparison.dart:382`, the flagged `reason:` string, and `tile_fallback_test.dart:51`, a `//` comment not caught in the previous round because that file wasn't among the four originally-cited locations.

Also grepped every `reason:` argument in both files (`grep -n "reason:" test/support/tile_comparison.dart test/tile_fallback_test.dart`) to confirm no other failure message carries the claim — the rest either interpolate `$report`/`$pan` directly or state unrelated facts (e.g. "the live arm must actually draw", "pan $pan recorded no strip"). None of `tile_fallback_test.dart`'s `reason:` strings mention the band at all.

**`tile_comparison.dart`'s `reason:` string — old:**
```dart
    expect(report.liveStripInk, greaterThanOrEqualTo(minimumStripInk),
        reason: 'pan $pan: the live frame carries no ink inside the band the '
            'fallback owes ($strip), so every pixel assertion below is '
            'satisfied by a fallback that could have drawn nothing: $report');
```

**New:**
```dart
    expect(report.liveStripInk, greaterThanOrEqualTo(minimumStripInk),
        reason: 'pan $pan: the live frame carries no ink inside the padded '
            'strip ($strip) -- weaker than the band the fallback owes -- so '
            'every pixel assertion below is satisfied by a fallback that '
            'could have drawn nothing: $report');
```

**`tile_fallback_test.dart`'s comment — old:**
```dart
    // Both gates default to on, and this call takes them as they come: the
    // triangle-count ratio is criterion 1's other half -- the pixel
    // assertions below prove the fallback lands the right pixels, and the
    // ratio proves it did not re-tessellate the whole viewport to do it (see
    // `kTriangleBudgetRatio`'s doc comment for the bracket behind the bound)
    // -- and `minimumStripInk` is what makes each sample non-vacuous, by
    // requiring the live frame to carry ink inside the band the fallback
    // owes. `criterion 2b` below is the one caller that opts out of either,
    // and says why.
```

**New:**
```dart
    // Both gates default to on, and this call takes them as they come: the
    // triangle-count ratio is criterion 1's other half -- the pixel
    // assertions below prove the fallback lands the right pixels, and the
    // ratio proves it did not re-tessellate the whole viewport to do it (see
    // `kTriangleBudgetRatio`'s doc comment for the bracket behind the bound)
    // -- and `minimumStripInk` is what makes each sample non-vacuous, by
    // requiring the live frame to carry ink inside the padded strip
    // (`TileCache.debugLastStrip`), weaker than the band the fallback
    // actually owes -- see `InkReport.liveStripInk`'s doc comment and gap H7
    // in STATUS.md. `criterion 2b` below is the one caller that opts out of
    // either, and says why.
```

Fixed the `tile_fallback_test.dart` comment too, even though the coordinator's ask named only `reason:`/failure-message text: it carries the identical false claim, and comments are squarely in scope under the standing "comments and doc comments only" constraint — this file just wasn't among the four locations originally cited.

**Grep after fixing** (`grep -rn "band the fallback owes" packages/jet_cad_2d_flutter/test/`):
```
test/support/tile_comparison.dart:364:    // and weaker than ink inside the band the fallback owes.** The two
test/support/tile_comparison.dart:382:            'strip ($strip) -- weaker than the band the fallback owes -- so '
```
Both remaining hits read "weaker than the band the fallback owes" — accurate, not the false claim.

### `lib/` unchanged — proof

```
$ git status --porcelain
 M docs/superpowers/notes/plan-3h-mutation-log.md
 M packages/jet_cad_2d_flutter/test/support/tile_comparison.dart
 M packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
$ git diff --stat 122b6e3 -- packages/jet_cad_2d_flutter/lib/
(no output)
```
No `analysis_options.yaml` or `.pbxproj` in `git status`.

### Closing suite output

```
$ CI=true flutter test
...
00:07 +372 ~1: All tests passed!

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.7s)

$ dart format --output=none --set-exit-if-changed .
Formatted 65 files (0 changed) in 0.14 seconds.
```
The golden tag was **not** re-run this round: nothing touched in this
follow-up (mutation-log prose, one `reason:` string, one comment) can reach
golden-tagged tests, so re-running `--tags golden` would add nothing beyond
what the previous round already confirmed (35/35 pass, no PNG regenerated).
Stating that rather than implying a fresh golden run happened.

### Summary

- Status: complete, tree green, `lib/` still byte-identical to `122b6e3`.
- Commit: `5829a206ad92a4f8b44b2c21ff0c9c2b7a835e51` ("docs: Plan 3h's record correction, follow-up -- counts settled, reason string fixed"), on `main`.
- Concerns: none outstanding. The M2/M3 counts are now recorded as settled (`+369 ~1 -3`, `+365 ~1 -7`), and the grep confirms no other `reason:`/failure-message string in `tile_comparison.dart` or `tile_fallback_test.dart` carries the false claim.
