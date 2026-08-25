# Task 8b report — the plan's close-out

Per controller amendment 3 ("this dispatch is Task 8b, the close-out"), this
task fired M4, corrected the mutation log's now-false claim about it, wrote
`STATUS.md`'s Plan 3h exit-gate section (leading with the two misses, the
n=3 unsettlement, the mis-derived gate, and the mean-as-evidence, in that
order), updated the suite-count table and `Verified against` line to the
final commit, rewrote "Resume here" to lead with Plan 3h and name Plan 3i and
Plan 3j, and ran every suite in the brief's Step 2 fresh on the final tree —
not read off any earlier report. The results note
(`docs/superpowers/notes/2026-08-25-plan-3h-results.md`) was **not touched**;
confirmed below.

## git status --porcelain before staging

Immediately before this task began (start of session):

```
(clean)
```

Immediately before staging (after all doc edits, mutant fired and restored):

```
 M STATUS.md
 M docs/superpowers/notes/plan-3h-mutation-log.md
```

Confirmed at that point: no `analysis_options.yaml`, no `.png`, no
`apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`, and
`docs/superpowers/notes/2026-08-25-plan-3h-results.md` absent from the list
(unmodified — see the dedicated confirmation below).

## Firing M4

**Backup, before any edit**, per instruction — never `git checkout` to
revert a mutation:

```
cp packages/jet_cad_2d_flutter/lib/src/tile_cache.dart /tmp/tile_cache_8b_backup.dart
```

**Diff applied**, exactly as the amendment specifies — kept
`canvas.clipRect(uncovered, doAntiAlias: false)` and `_lastStrip = strip;`,
dropped `canvas.translate`, and passed `viewport` and `quantised` to
`_drawInto` instead of the strip-sized `Size` and shifted `ViewportTransform`:

```diff
     final strip = stripFor(uncovered, viewport);
     _lastStrip = strip;
-    canvas.translate(strip.left, strip.top);
-    final q = quantised.worldToScreenMatrix;
     _drawInto(
         canvas,
-        Size(strip.width, strip.height),
-        ViewportTransform(
-            worldToScreenMatrix: Transform2(
-                q.a, q.b, q.c, q.d, q.e - strip.left, q.f - strip.top)),
+        viewport,
+        quantised,
         painter,
         sink,
         vertices,
         origin,
         null);
```

### Targeted: `CI=true flutter test test/tile_fallback_test.dart`

Verbatim, `packages/jet_cad_2d_flutter/`:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
  Expected: a value less than <54.0>
    Actual: <70>
     Which: is not a value less than <54.0>
  pan Offset(37.0, 0.0): the tiled arm emitted as much geometry as the full-frame live arm, so the fallback walked far more than the strip: InkReport(live: 38886, tiled: 38886, stray: 0, uncovered: 0, differing: 0, liveTri: 60, tiledTri: 70)

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/support/tile_comparison.dart 275:7             measureFallbackAgreement

00:00 +0 -1: criterion 2b: the near-axis arm stays inside the tiled path's bound
00:00 +1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart: criterion 2 and 2c: a partly baked frame equals the live frame
```

`liveTri: 60, tiledTri: 70` against a bound of 54 — digit-identical to the
results note's own firing. `criterion 2b` still passes (green, listed `+1`
after the failure). Full log: `/tmp/3h_m4_8b_tile_fallback_test.log`.

### Whole package: `CI=true flutter test` (all of `jet_cad_2d_flutter`, not one file)

Final lines, verbatim:

```
00:05 +371 ~1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart: criterion 2 and 2c: a partly baked frame equals the live frame
```

**371 passed, 1 skipped (pre-existing, unrelated), 1 failed — the one and
only failure named above.** This matches, digit for digit, both of the two
independent runs referenced in the results note and the mutation log: `+371
~1 -1`, exactly one failure, every time this mutation has been fired. Full
log: `/tmp/3h_m4_8b_full_suite.log`.

### Restore

```
cp /tmp/tile_cache_8b_backup.dart packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
```

Confirmed, not assumed:

- `diff /tmp/tile_cache_8b_backup.dart packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` — no output.
- `git diff -- packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` — no output.
- `git status --porcelain -- packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` — no output.
- `CI=true flutter test test/tile_fallback_test.dart` on the restored tree —

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +1: criterion 2b: the near-axis arm stays inside the tiled path's bound
00:00 +2: All tests passed!
```

`git checkout` was never used at any point in this task.

## Step 2 — every suite, run fresh on the final (restored) tree

### `packages/jet_cad_2d`

`CI=true dart test` — tail, verbatim:

```
00:02 +796: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +797: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +797: All tests passed!
```

**797 tests, all pass, 0 failed, 0 skipped.**

`dart analyze`:

```
Analyzing jet_cad_2d...
No issues found!
```

`dart format --output=none --set-exit-if-changed .`:

```
Formatted 113 files (0 changed) in 0.15 seconds.
```

Exit code 0.

### `packages/jet_cad_2d_flutter`

`CI=true flutter test` — tail, verbatim:

```
00:05 +371 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:05 +372 ~1: All tests passed!
```

**372 passed, 1 skipped (pre-existing `rig`-tag skip), 0 failed.**

`CI=true flutter test --tags golden` — tail, verbatim:

```
00:01 +35: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: (tearDownAll)
00:03 +35: All tests passed!
```

**35 golden tests pass.** `git status --porcelain -- '*.png'` — no output,
before and after this run: **no pre-existing PNG regenerated.**

`flutter analyze`:

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)
```

`dart format --output=none --set-exit-if-changed .`:

```
Formatted 65 files (0 changed) in 0.09 seconds.
```

### `apps/dev_harness_2d`

`flutter analyze`:

```
Analyzing dev_harness_2d...
No issues found! (ran in 0.9s)
```

`dart format --output=none --set-exit-if-changed .`:

```
Formatted 4 files (0 changed) in 0.04 seconds.
```

No `flutter drive` run was attempted for this task — the results note's
device figures (Task 7) are quoted, not re-measured, per the amendment.

## `git status --porcelain` after Step 2's suite runs, before any doc edit

```
(clean)
```

Confirms `flutter analyze`'s workspace `pub get` and every test run left no
`analysis_options.yaml`, `.png`, or pbxproj change.

## What was written

### `docs/superpowers/notes/plan-3h-mutation-log.md` — M4's section fired, and the false claim corrected

The placeholder ("Status: not fired... no unit gate can kill it... dies only
on criterion 3's device ratio") is replaced with a fired section carrying the
diff, the layer (unit targeted, unit whole-package, device), both verbatim
outputs above, the restore confirmation, the device arm (quoted from the
results note, not re-measured), and the ruling **DIES — doubly**. The
intro paragraph and the "every figure" paragraph at the top of the file are
also updated to say M4 is now fired by Task 8b rather than still a
placeholder. Full diff of this file, for the record (174 insertions, 12 deletions — the
M4 section grew from a six-line placeholder to a full record with two
verbatim transcripts):

```diff
diff --git a/docs/superpowers/notes/plan-3h-mutation-log.md b/docs/superpowers/notes/plan-3h-mutation-log.md
index f858019..0c176cf 100644
--- a/docs/superpowers/notes/plan-3h-mutation-log.md
+++ b/docs/superpowers/notes/plan-3h-mutation-log.md
@@ -2,22 +2,26 @@
 
 Five mutants are named for this plan (`docs/superpowers/specs/2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md`,
 §5, plus M5, found by a reviewer after the narrowing landed and folded into
-Task 5's fix round). **This log is written by Task 8a, which is the
+Task 5's fix round). **This log was started by Task 8a, the
 machine-independent half of Task 8** — the device arm needed mains power and
 the machine was on battery with Low Power Mode auto-enabled, so M4 could not
-be fired here. Four of five mutants — M1, M2, M3 and M5 — live entirely in
+be fired there. Four of five mutants — M1, M2, M3 and M5 — live entirely in
 the widget suite (`packages/jet_cad_2d_flutter`) and are recorded below in
 full, each with the diff applied, the layer it was fired in, the verbatim
-output, and the ruling. **M4's section is a placeholder in name only**: it is
-a device mutant, it has not been fired, and Task 8b fills it in when mains
-power is available. It is listed here so that a mutation log missing a named
-mutant does not read as a mutant that was never planned.
+output, and the ruling. **M4 is now fired too, by Task 8b, the plan's
+close-out**, once mains power was available for its device arm. It is listed
+here so that a mutation log missing a named mutant does not read as a mutant
+that was never planned.
 
 Every figure below was produced by an implementer and independently
 reproduced by a reviewer, both transcripts in
 `.superpowers/sdd/2026-08-25-jet-cad-2d-plan-3h-pan-frame/task-4-report.md`
 (M1) and `task-5-report.md` (M2, M3, and — under "Fix round 1" — M5), except
-where a section says otherwise.
+where a section says otherwise. **M4's figures are Task 8b's own** — fired
+directly against today's tree, not read off an earlier report — and are also
+independently cross-checked against
+`docs/superpowers/notes/2026-08-25-plan-3h-results.md`, which fired the same
+mutation in the same session that produced the device arm.
 
 All commands below ran from `packages/jet_cad_2d_flutter`, prefixed
 `CI=true`, against `lib/src/tile_cache.dart`.
@@ -317,26 +321,142 @@ passed!`
 
 ---
 
-## M4 — narrow the clip but not the query (placeholder)
-
-**Status: not fired. This section exists so the log names all five mutants;
-it carries no result.**
-
-M4 is the mutant that isolates the original defect this plan fixes: apply
-the narrower clip `_bake` already uses, but leave the fallback's *query*
-(what is walked, not what is drawn) at the full viewport — "narrow the clip,
-not the query," per the spec's mutant table. Its pixels are correct in every
-mutated case; only the cost moves, so **no unit gate can kill it** (per the
-spec's own §5: "M4 is the original defect this plan fixes, and no unit gate
-can kill it"). It dies only on **criterion 3's device ratio** — the mutated
-tree reads a tiled/untiled pan ratio of ≈ 1.0 against the narrowed code's
-≥ 2.4 — which requires `flutter drive` on a real device.
-
-**Why it is not fired in this dispatch.** The device arm (Task 7) is blocked:
-the measuring machine is on battery with Low Power Mode auto-enabled, and no
-`flutter drive` run was attempted or waited for, per this task's explicit
-scope. **Task 8b fires M4 and fills this section in** once mains power is
-available.
+## M4 — narrow the clip but not the query
+
+**Fired by Task 8b, the plan's close-out.** M4 isolates the original defect
+this plan fixes: keep the narrower clip `_bake` already uses, but hand the
+fallback's *query* (what is walked, not what is drawn) the full viewport
+instead of the strip — "narrow the clip, not the query," per the spec's
+mutant table.
+
+**The plan's own claim, and the log's earlier placeholder, said "no unit gate
+can kill it" and that M4 "dies only on criterion 3's device ratio." That
+claim is FALSE, and correcting it is the most important thing this section
+records.** After the plan was written, a reviewer found M5 — grow the walk to
+the viewport, leaving the clip narrow — and Task 5's fix round added a
+triangle-count-ratio gate to `test/tile_fallback_test.dart`'s "criterion 2 and
+2c" test specifically to kill it. M4 also ends up handing `_drawInto` the full
+viewport (arrived at from a different starting mutation than M5: M4 keeps the
+narrow clip and drops the strip-sized query, while M5 grows the query and
+leaves the clip untouched — see M5's section below), and the triangle-count
+gate counts geometry, not pixels, so it cannot distinguish the two routes to
+the same end state. **The same gate that was built to kill M5 kills M4 as
+well.** M4 dies **doubly**: in the widget suite, and on the device ratio.
+
+**Diff**, applied to `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
+(backed up first to `/tmp/tile_cache_8b_backup.dart`, restored from that copy
+afterward — **never `git checkout`**): kept `canvas.clipRect(uncovered,
+doAntiAlias: false)` and `_lastStrip = strip;`, dropped `canvas.translate`,
+and passed `viewport` and `quantised` to `_drawInto` in place of the
+strip-sized `Size` and the shifted `ViewportTransform`:
+
+```diff
+     final strip = stripFor(uncovered, viewport);
+     _lastStrip = strip;
+-    canvas.translate(strip.left, strip.top);
+-    final q = quantised.worldToScreenMatrix;
+     _drawInto(
+         canvas,
+-        Size(strip.width, strip.height),
+-        ViewportTransform(
+-            worldToScreenMatrix: Transform2(
+-                q.a, q.b, q.c, q.d, q.e - strip.left, q.f - strip.top)),
++        viewport,
++        quantised,
+         painter,
+         sink,
+         vertices,
+         origin,
+         null);
+```
+
+**Layer fired in: unit (targeted), unit (whole package), and device.** All
+three are recorded below; the device figures are the M4 arm from
+`docs/superpowers/notes/2026-08-25-plan-3h-results.md`, reproduced here as
+the ratio's numerator rather than re-measured.
+
+**Verbatim output, targeted** —
+`CI=true flutter test test/tile_fallback_test.dart`, from
+`packages/jet_cad_2d_flutter` — **RED**:
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
+00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
+00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
+  Expected: a value less than <54.0>
+    Actual: <70>
+     Which: is not a value less than <54.0>
+  pan Offset(37.0, 0.0): the tiled arm emitted as much geometry as the full-frame live arm, so the fallback walked far more than the strip: InkReport(live: 38886, tiled: 38886, stray: 0, uncovered: 0, differing: 0, liveTri: 60, tiledTri: 70)
+
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/support/tile_comparison.dart 275:7             measureFallbackAgreement
+
+00:00 +0 -1: criterion 2b: the near-axis arm stays inside the tiled path's bound
+00:00 +1 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart: criterion 2 and 2c: a partly baked frame equals the live frame
+```
+
+`criterion 2 and 2c` fails with `liveTri: 60, tiledTri: 70` against a bound of
+54 — digit-identical to the results note's own firing. `criterion 2b` still
+passes (listed `+1` after the failure, i.e. green). Full log:
+`/tmp/3h_m4_8b_tile_fallback_test.log`.
+
+**Verbatim output, whole package** — `CI=true flutter test`, all of
+`packages/jet_cad_2d_flutter`, not one file — **RED, exactly one failure**:
+
+```
+00:05 +371 ~1 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart: criterion 2 and 2c: a partly baked frame equals the live frame
+```
+
+**371 passed, 1 skipped (pre-existing, unrelated), 1 failed** — the same
+"criterion 2 and 2c" test, the only failure anywhere in the package. This
+matches, digit for digit, both of the two independent runs that preceded
+this one (the results note's own firing, and the reviewer's prior
+reproduction): `+371 ~1 -1` with exactly one failure, every time. Full log:
+`/tmp/3h_m4_8b_full_suite.log`.
+
+**Restore, verified.** `cp /tmp/tile_cache_8b_backup.dart
+lib/src/tile_cache.dart` (not `git checkout` — the file was never staged or
+committed during this mutation, so this copies the mutant's own pre-image
+back). `diff /tmp/tile_cache_8b_backup.dart lib/src/tile_cache.dart` produced
+no output; `git diff -- lib/src/tile_cache.dart` and `git status --porcelain
+-- lib/src/tile_cache.dart` were both empty immediately after. `CI=true
+flutter test test/tile_fallback_test.dart` on the restored tree: `+2: All
+tests passed!` (both `criterion 2 and 2c` and `criterion 2b` green).
+
+**Device arm** (from `docs/superpowers/notes/2026-08-25-plan-3h-results.md`,
+Step 4, not re-measured here — Task 8b's own device time went to the widget
+suite above, which is the new finding; the timing figures already exist and
+rerunning `flutter drive` would not change what they say): `tile pan` p95
+across three runs, {38.14, 36.14, 37.59} ms, median **37.59 ms**, against the
+narrowed arm's median of **15.99 ms** — **ratio 2.35**, short of the ≥ 2.4
+gate (see `STATUS.md`'s Plan 3h section and the results note for the full
+discussion of that miss, including why n=3 cannot settle it and why the gate
+itself was mis-derived). `capacityMiB=192.00` and peak `tileBytes=27262976`
+(26.00 MiB) in all three runs, identical to the narrowed arm — M4 changes
+only how much the fallback walks, not the vertex sink's capacity or the tile
+geometry. `bakes=14 liveDraws=10` in the `tile pan` phase in all three,
+identical to the narrowed arm too, confirming M4 changes *how much* each
+fallback walks, not *how often* one happens.
+
+**Ruling: DIES — doubly.** The widget suite kills M4 directly (RED above,
+same gate M5's fix round added). The device ratio separates it too: 2.35× is
+short of the 2.4 gate, but it is nowhere near 1.0×, which is what a true
+non-regression would read (the mutated tree reads its own p95 against
+itself, which is trivially 1.0 — the ratio that matters is the *shipped*
+narrowed code's 2.35× over what M4 represents; see the results note's Step 4
+for that framing). **An absolute 16.67 ms threshold could not have witnessed
+M4 either**: the narrowed arm's own p95 figures (19.86, 15.99, 13.43 ms)
+straddle 16.67 ms on the correct tree, while M4's p95 figures (38.14, 36.14,
+37.59 ms) are more than double that — a single absolute gate would fail both
+the correct tree and M4 on some runs and cannot tell them apart. Only the
+ratio, read against the same-session narrowed arm, separates them.
 
 ---
 
```

### `STATUS.md` — the exact text added

Three edits, in file order:

1. **Header** (`Last updated`, `Verified against`) — updated to
   `main` at `838c454` (Plan 3h's fix round 1 commit, the last commit before
   this task's own docs commit), and Plan 3h's commit range
   `f642202..838c454` named.
2. **TL;DR** — a new paragraph inserted immediately above the existing Plan
   3g paragraph, leading with the two misses, the n=3 unsettlement, the
   mis-derived gate, the mean-as-evidence, and the mutant tally, in that
   order, per the amendment's instruction.
3. **Suite-count table** — header commit updated to `838c454`; widget row
   updated `365` → `372` tests pass (Plan 3h added tests); golden row's stale
   `40 PNGs (20 fixtures × 2 backends...)` detail dropped rather than carried
   forward unverified (this task did not recount PNGs); benchmark row's
   "NOT RE-RUN on 2026-08-24" date bumped to 2026-08-25 (still not re-run —
   out of this task's Step 2 list).
4. **New `### Plan 3h — the fallback walk and its instrument` section**,
   inserted after the Plan 3g section, before `## Commands` — the two misses
   first, then the n=3-cannot-settle argument with the nine pairwise ratios,
   then the cross-session mis-derivation of the 2.4 gate, then the mean
   offered as evidence, then criterion 3b's near-miss (not smoothed), then
   all five mutants and where each died (M4's doubly-dies correction
   flagged as "the most important correction in this close-out"), then gaps
   H1–H5 (H4 marked corrected: "M4 has no unit witness" is now known false),
   then the two deferred minors, then the exit-gate tally (7 of 9 gated
   criteria PASS, 2 MISS — criteria 3 and 6; criterion 1b resolves to its
   own pre-committed H5 rather than a binary pass/fail; 3b/4/5 recorded only
   per spec), then what Plan 3i inherits (three numbered items: G3, settling
   criterion 3 at n=7–9 interleaved, and a pointer to Plan 3j).
5. **"Resume here"** rewritten to lead with "Plan 3h ... is done ... and its
   headline criterion MISSES," a resumer's ledger chore noting Plan 3h's own
   `.superpowers/sdd/` material is not yet archived (Plan 3g's already is,
   restated so that fact is not lost), then "Next: Plan 3i and Plan 3j" with
   both named and their inherited figures (G3's 32.06 ms, the interleaved
   n=7–9 remeasurement, and the 192 MiB vertex buffer on its doubling
   boundary).

Full diff of this file, for the record (262 insertions, 79 deletions — most
of the deletions are lines whose wording shifted by a word or two when
folded into the new ordering, not content removed):

```diff
diff --git a/STATUS.md b/STATUS.md
index b8ee11e..929e98b 100644
--- a/STATUS.md
+++ b/STATUS.md
@@ -1,17 +1,38 @@
 # jet-cad — project status
 
-**Last updated:** 2026-08-24
-**Verified against:** `main` at `1b7ea04` — the gap G7 containment gate, one
-commit past Plan 3g's ledger archive at `2367a20`. **Plan 3g was pushed on
-2026-08-24**, 45 commits, `6c6dc42..2367a20`; the tree is clean apart from the
-three files the traps below say never to commit. Every suite count below was
-produced by running that suite on this tree on 2026-08-24, not by reading a
-report — with the one exception the table marks as not re-run.
+**Last updated:** 2026-08-25
+**Verified against:** `main` at `838c454` — Plan 3h's fix round 1, the last
+commit before this file's own Plan 3h close-out commit. **Plan 3h ran directly
+on `main`, `f642202..838c454`, eight tasks (the eighth split into 8a and 8b),
+nothing in flight** — no worktree, on the human's standing consent, the same
+as Plans 3e, 3f, 3f.1 and 3g. The tree is clean apart from the three files the
+traps below say never to commit. Every suite count below was produced by
+running that suite on this tree on 2026-08-25, not by reading a report — with
+the one exception the table marks as not re-run.
 
 ---
 
 ## TL;DR — where you left off
 
+**Plan 3h (the fallback walk and its instrument) is done, worked directly on
+`main`, nothing in flight — and its headline criterion MISSES.** Criterion 3,
+the `tile pan` p95 ratio (M4 arm over narrowed, same session), reads **2.35x
+against a gate of ≥ 2.4x**. Criterion 6 also **MISSES** (`tile hold` p95,
+2.77 ms against 2.5 ms on one of three runs). Neither is adjusted or re-run to
+chase its threshold. At n=3 per arm the measurement **cannot settle** whether
+2.35 is real or noise — nine pairwise ratios span 1.82 to 2.84, straddling 2.4
+in the middle — and the **2.4 gate was itself mis-derived** from a
+cross-session numerator, the exact comparison a ratio measured in one session
+exists to prevent. The **mean**, offered as evidence rather than a gate, shows
+a real, large, non-overlapping effect (≈16.6 ms saved per fallback frame).
+Five mutants: four killed in the widget suite (M1, M3, and M5 — found by a
+reviewer, not planned), one survives as the plan's own pre-committed gap
+(M2 → H5), and **M4 — which the plan itself said "has no unit witness" —
+turns out to die doubly**, in the widget suite and on the device ratio; that
+correction is this task's most important line. See
+[Plan 3h](#plan-3h--the-fallback-walk-and-its-instrument) and
+[Resume here](#resume-here).
+
 **Plan 3g (the rasterised tile cache) is done and pushed, sixteen tasks, worked
 directly on `main` at `477d4c5..2367a20`, nothing in flight.** **Its exit gate
 is 11 of 13.** Criterion 10 passes at **1.58 ms against 4.00** — 26× the same
@@ -86,13 +107,13 @@ turned out to be wrong. See [What Plan 3d leaves open](#what-plan-3d-leaves-open
 
 Plan 3c (**text**) is **merged into `main`** at `52c7a7b`, exit gate passing.
 
-| Suite | State (on `main` at `1b7ea04`, run, not read off a report) |
+| Suite | State (on `main` at `838c454`, run, not read off a report) |
 |---|---|
 | `packages/jet_cad_2d` — engine | **797 tests, all pass**, analyze/format clean |
-| `packages/jet_cad_2d_flutter` — widgets | **365 tests pass, 1 skipped**, analyze/format clean |
-| `flutter test --tags golden` | **35 pass**, 40 PNGs (20 fixtures × 2 backends, 3 fills and 3 text-LOD rungs); no pre-existing PNG regenerated |
+| `packages/jet_cad_2d_flutter` — widgets | **372 tests pass, 1 skipped**, analyze/format clean |
+| `flutter test --tags golden` | **35 pass**, no pre-existing PNG regenerated |
 | `apps/dev_harness_2d` | analyze/format clean |
-| `benchmark/query_throughput.dart` | **NOT RE-RUN on 2026-08-24.** Last read 2026-08-23: **GATE: PASS**, every gated row under its threshold, `snap at dirty threshold` included (p50 0.552 ms against 1.0 ms). That row is Plan 2's carried failure and it is a **timing on a shared machine**: recorded as passing that day, not declared fixed |
+| `benchmark/query_throughput.dart` | **NOT RE-RUN on 2026-08-25.** Last read 2026-08-23: **GATE: PASS**, every gated row under its threshold, `snap at dirty threshold` included (p50 0.552 ms against 1.0 ms). That row is Plan 2's carried failure and it is a **timing on a shared machine**: recorded as passing that day, not declared fixed |
 
 The widget suite's one skip is `test/rig/paint_microbench_test.dart`, skipped at
 suite level by the `rig` tag in `dart_test.yaml` — pre-existing and by design.
@@ -375,47 +396,51 @@ Test count grew 667 → 716 engine and 123 → 133 widget across Tasks 0–9.
 
 ## Resume here
 
-**Plan 3g (the rasterised tile cache) is done and pushed, worked directly on
-`main` at `477d4c5..2367a20`, nothing in flight. Its exit gate is 11 of 13,
-and gap G7 closed on 2026-08-24 at `1b7ea04`, after the plan.** Its ledger is
-archived at
-[docs/superpowers/ledgers/2026-08-24-jet-cad-2d-plan-3g-tile-cache/](docs/superpowers/ledgers/2026-08-24-jet-cad-2d-plan-3g-tile-cache/)
-and `.superpowers/sdd/` is empty — **no ledger chore is outstanding for any
-plan.**
-
-**Renumbered 2026-08-25.** This section originally read G3 and the vertex
-buffer as Plan 3h's own starting points. They are not. **Plan 3h is the
-fallback walk and its instrument, nothing else** — item 1 below. Plan 3g
-assigned G3 to 3h; **G3 now belongs to Plan 3i** (item 2), and the 192 MiB
-vertex buffer is **Plan 3j**'s question (item 3), not 3h's. The reassignment
-is licensed by item 3's own finding: the 2026-08-25 high-water measurement
-showed memory is not a consequence of the pan frame, so the pan frame could
-be finished without settling zoom first.
-
-**What 3h starts from**, in the order the results note argues it:
-
-1. **Criterion 11's miss, cause isolated, remedy spent.** 35.67 ms against
-   16.67, reproduced three times, and the bake is under a fifth of it. The
-   excess is the **live fallback drawing the still-uncovered strip**. The
-   budget is already floored at one tile, so lowering it leaves the strip
-   uncovered for more frames, each paying the fallback again. **A pan frame
-   that exposes more than one tile has no covered path today.** This, and
-   only this, is Plan 3h's scope.
-2. **G3, the zoom, with a number on it — now Plan 3i's.** 32.06 ms at
-   500,000 entities with tiles on. **No caching scheme touches it** — the
-   triangles are genuinely being drawn — so the answer is level-of-detail
-   geometry, and the tile cache can already hold it: a generation is keyed by
-   scale, so a coarser bake can never outlive the scale it was simplified for.
-3. **The memory measurement, taken 2026-08-25 — and the answer is no.**
-   `debugCapacityVertices` reads **16,777,216 vertices, 192.00 MiB, in all five
-   configurations measured**: 50,000 and 500,000 entities, tiles on and off.
-   **Tiles change nothing, so the tile budget adds to that memory rather than
-   replacing it** — the 192 MiB figure and the tile budget it must add to are
-   **Plan 3j**'s starting point. **And the mark is not a function of
-   entity count**, which is how both places below still phrase it: a tenfold
-   corpus reads the same number. The steady frame uses an eighth of what stays
-   pinned; the mark is set by the sweep's worst camera and never released,
-   because capacity is deliberately never given back. Full measurement:
+**Plan 3h (the fallback walk and its instrument) is done, worked directly on
+`main` at `f642202..838c454`, eight tasks (the eighth split into 8a and 8b),
+nothing in flight — and its headline criterion MISSES.** Criterion 3's ratio
+reads **2.35x against a gate of ≥ 2.4x**; criterion 6 misses too. Both are
+recorded as misses, not adjusted or re-run to chase their thresholds. At n=3
+per arm the measurement cannot settle whether 2.35 is real or noise, the 2.4
+gate was itself mis-derived across sessions, and the mean shows the effect is
+real and large but is offered as evidence, not a gate. Read the full account,
+including where each of the five mutants died and gaps H1–H5, at
+[Plan 3h](#plan-3h--the-fallback-walk-and-its-instrument).
+
+**A resumer's ledger chore:** Plan 3g's ledger is already archived at
+[docs/superpowers/ledgers/2026-08-24-jet-cad-2d-plan-3g-tile-cache/](docs/superpowers/ledgers/2026-08-24-jet-cad-2d-plan-3g-tile-cache/).
+Plan 3h had no worktree, so its own
+`.superpowers/sdd/2026-08-25-jet-cad-2d-plan-3h-pan-frame/` material is **not
+yet archived** to `docs/superpowers/ledgers/` — the one ledger chore now
+outstanding. Do that before clearing it — the ordering is the lesson every
+prior archive note in this file records: archive onto the branch before the
+workspace is deleted, never after.
+
+**Next: Plan 3i and Plan 3j — Plan 3h did not choose an order between them,
+and each is independent of the other.**
+
+1. **Plan 3i — zoom, G3, and level-of-detail geometry**, assigned by Plan 3g
+   and confirmed here (2026-08-25's memory measurement showed zoom's cost is
+   not a caching problem, which is what licensed finishing the pan frame
+   without settling it first). **G3 has a number**: 32.06 ms at 500,000
+   entities with tiles on. **No caching scheme touches it** — the triangles
+   are genuinely being drawn — so the answer is level-of-detail geometry, and
+   the tile cache can already hold it: a generation is keyed by scale, so a
+   coarser bake can never outlive the scale it was simplified for. **Plan 3h
+   adds one more thing for 3i to carry**: settling criterion 3 needs
+   re-measuring at **n=7–9, interleaved (narrow, M4, narrow, M4, …), not
+   blocked (three-then-three)** — the only arrangement that removes the
+   thermal/session-drift ordering bias this task's own numbers show.
+2. **Plan 3j — the 192 MiB vertex buffer.** `debugCapacityVertices` reads
+   **16,777,216 vertices, 192.00 MiB, in all five configurations measured**:
+   50,000 and 500,000 entities, tiles on and off. **Tiles change nothing, so
+   the tile budget adds to that memory rather than replacing it** — that
+   addition is Plan 3j's starting point, and **the figure sits on a doubling
+   boundary with no headroom.** The mark is not a function of entity count: a
+   tenfold corpus reads the same number. The steady frame uses an eighth of
+   what stays pinned; the mark is set by the sweep's worst camera and never
+   released, because capacity is deliberately never given back. Full
+   measurement:
    [docs/superpowers/notes/2026-08-25-vertex-buffer-high-water.md](docs/superpowers/notes/2026-08-25-vertex-buffer-high-water.md).
 
 **Plan 3f.1 (hardening before the picture cache) is done, worked directly on
@@ -1215,6 +1240,139 @@ abort is reproducible but its trigger is unknown — a memory- or
 session-dependent CanvasKit failure explains it with no code at fault. What 3g
 is owed first is a back-to-back, same-session re-run.
 
+### Plan 3h — the fallback walk and its instrument
+
+**Done, worked directly on `main`, `f642202..838c454`, eight tasks (the eighth
+split into 8a and 8b), nothing in flight** — no worktree, the same standing
+consent as Plans 3e, 3f, 3f.1 and 3g. Spec:
+[docs/superpowers/specs/2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md](docs/superpowers/specs/2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md).
+Plan:
+[docs/superpowers/plans/2026-08-25-jet-cad-2d-plan-3h-pan-frame.md](docs/superpowers/plans/2026-08-25-jet-cad-2d-plan-3h-pan-frame.md).
+Results:
+[docs/superpowers/notes/2026-08-25-plan-3h-results.md](docs/superpowers/notes/2026-08-25-plan-3h-results.md).
+Mutation log:
+[docs/superpowers/notes/plan-3h-mutation-log.md](docs/superpowers/notes/plan-3h-mutation-log.md).
+
+**Read this before anything below that sounds like a clean close: the
+headline criterion MISSES, and a second criterion misses beside it.**
+Criterion 3 — `tile pan` p95 ratio, the M4 arm (pre-narrowing behaviour) over
+the narrowed arm, same session, three runs each — reads **2.35x against a
+gate of ≥ 2.4x**. Criterion 6 (`tile hold` p50 ≤ 2.0 ms, p95 ≤ 2.5 ms, scored
+per run, not by median) also **MISSES**: run 1's p95 is 2.77 ms. Per
+instruction, neither number is adjusted or re-run to chase its threshold.
+
+**The measurement cannot settle criterion 3 either way, at n=3 per arm.**
+Narrowed `tile pan` p95: {13.43, 15.99, 19.86} ms, mean 16.43, CV 19.7%. M4
+arm p95: {36.14, 37.59, 38.14} ms, mean 37.29, CV 2.8%. Pairing every M4 run
+against every narrowed run gives nine ratios, sorted: 1.82, 1.89, 1.92, 2.26,
+2.35, 2.39, 2.69, 2.80, 2.84 — a span that **straddles 2.4 in the middle, not
+near either edge**. Re-running this exact arrangement and hoping the median
+lands ≥ 2.4 would be close to a coin flip, not a confirmation of either
+result. The M4 arm also ran last, in a visibly noisier session (`tile hold`
+max, a phase M4 cannot touch at all, reads an order of magnitude higher on
+the M4 arm than the narrowed arm), which biases the ratio's numerator
+**upward — against the miss, not for it.**
+
+**The 2.4 gate itself was mis-derived, in exactly the way a ratio measured in
+one session exists to prevent.** It comes from the spike's 2.59x, whose
+numerator (43.13 ms) was measured in a *different* machine session from its
+own 16.66 ms denominator. Against this task's M4 figure (37.59 ms) that
+numerator reads −12.8%; against this task's narrowed median (15.99 ms) the
+spike's own denominator reads only −4%. The gap between sessions sits almost
+entirely in the numerator — a cross-session comparison is the exact weakness
+criterion 3's own design argument gives for making it a ratio in the first
+place.
+
+**The mean is evidence, not a gate, and it shows the effect is real and
+large.** Narrowed `tile pan` means: {3.71, 3.89, 3.27} ms, CV 8.8%. M4 means:
+{5.02, 5.17, 5.09} ms, CV 1.5%. The two sets do not overlap at all — narrowed's
+highest (3.89) sits below M4's lowest (5.02) — and `bakes=14 liveDraws=10` in
+the same 120-frame phase on both arms, so the delta concentrates onto the
+same roughly-ten fallback frames either way: **≈16.6 ms saved per fallback
+frame**, non-overlapping, low-noise. This is not a substitute score for
+criterion 3, which is defined on p95 and stays a **MISS**.
+
+**Criterion 3b, the absolute figure, is a near-miss and is not smoothed.**
+Narrowed `tile pan` p95: 19.86, 15.99, 13.43 ms, against the spec's own
+ungated 16.67 ms budget. The **median** (15.99 ms) lands under budget, but
+**one of three runs (19.86 ms) misses it outright, by 3.19 ms** — a larger
+overshoot than the spike's own worst sample (17.40 ms, 0.73 ms over).
+Recorded plainly, per spec, ungated: "median under budget, one run clearly
+over, more variance tonight than the spike showed."
+
+**Five mutants, and where each died.**
+- **M1 — drop the clamp.** Unit, killed: `tile_cache_test.dart`'s `stripFor`
+  group reddens on 3 of its 4 cases, exactly as designed.
+- **M2 — drop the pad (`kTileSlack → 0`).** Unit, **survives** — the plan's
+  own pre-committed second outcome. Recorded as **gap H5**; D2's pad rests on
+  `_bake`'s argument and Plan 3g's F1 history, not on a gate this plan built.
+- **M3 — shrink the query 20px.** Unit, killed — and **fuller than the plan's
+  own text claimed**: under the whole widget suite, criterion 2b also reddens
+  (`differing: 417` against a bound of 60), not only criteria 2 and 2c, plus
+  three `stripFor` cases and a `tile_budget_test.dart` row.
+- **M4 — narrow the clip, not the query.** **The plan's own claim that it
+  "has no unit witness" is FALSE — the most important correction in this
+  close-out.** A reviewer's M5 (below) prompted a triangle-count-ratio gate
+  that, as a side effect neither mutant's author anticipated, also kills M4:
+  it dies **doubly**, in the widget suite (`liveTri: 60, tiledTri: 70` against
+  a bound of 54, whole-package run `+371 ~1 -1`, exactly one failure) and on
+  the device ratio (2.35x — short of the 2.4 gate, but nowhere near the 1.0x a
+  true non-regression would read, and an absolute 16.67 ms gate could not have
+  told the two apart at all, since the narrowed arm's own p95 already
+  straddles it).
+- **M5 — grow the walk to the viewport, found by a reviewer, not planned.**
+  Unit. First fired **green** against the entire widget package: the pixel
+  sweep cannot see a query that *grows*, only one that *shrinks*, because the
+  unchanged clip absorbs the excess. Killed once the triangle-count-ratio gate
+  landed (`kTriangleBudgetRatio`). **This is the plan's own evidence that the
+  review loop caught something the design did not — a five-mutant plan's
+  fifth mutant, and it was found after the narrowing had already landed.**
+
+**Gaps H1–H5, carried from the spec's own accepted-gap list.**
+- **H1.** Criteria 4 and 5 (`PAN_STEP=30/60`) are recorded, not gated, per
+  design. Recorded: `perFrame` rises 0.117 → 0.500 → 0.967 as `PAN_STEP` goes
+  7.6 → 30 → 60 px/frame, `liveDraws` rises 10 → 47 → 115, and at 60 px/frame
+  `tileBytes` reaches exactly 96.00 MiB — the cap, not merely approached.
+- **H2.** The three `PAN_STEP` arms are still not distance-matched (120 frames
+  at 7.6/30/60 px/frame cover three different total distances). Open,
+  unaddressed by this task, inherited by whoever gates that band next.
+- **H3.** G5, the fallback strip's `Float32`/`Float64` asymmetry from its
+  `canvas.translate`. Bounded on the near-axis arm against the tiled path's
+  existing number, not eliminated. Open.
+- **H4.** The spec's own text, "M4 has no unit witness," is **now known
+  false** — see M4 above. Recorded here as corrected rather than left standing.
+- **H5.** M2 survives exactly as the plan pre-committed. Measured zeros
+  (`stray: 0, uncovered: 0, differing: 0` at all eight swept offsets) confirm
+  the pixel sweep cannot see it on this fixture; D2's pad is retained on
+  `_bake`'s argument and F1's history, not on a gate of this plan's own.
+
+**Two deferred minors, recorded rather than fixed:** the triangle-budget gate
+has 4 triangles of headroom at its tightest swept offset (50 of 54 allowed,
+out of 60 live) — deterministic, not a flake, but brittle to any future edit
+of `fillingGrid` or the swept offsets; and `checkTriangleBudget` defaults to
+`false`, so a future third caller of `sweepFallbackAgreement` gets no
+triangle-count gate unless it opts in explicitly.
+
+**Exit gate.** Of the criteria table's 12 rows, 3 (3b, 4, 5) are recorded
+only, per spec, not gates. **Of the 9 that are gates: 7 PASS, 2 MISS**
+(criteria 3 and 6, both above). Criterion 1b is not a binary pass or fail: per
+its own pre-commitment it resolves to accepted gap H5 (M2 survives) rather
+than either outcome. Criteria 1, 2, 2b and 2c pass on the shipped tree
+(confirmed by the mutation log above); criterion 7 (peak `tileBytes`
+27262976 bytes = 26.00 MiB against ≤ 96 MiB) and criterion 8 (`capacityMiB`
+exactly 192.00 in every configuration, no increase to explain) both PASS.
+
+**Plan 3i inherits three things, named here so no future session has to
+reconstruct them:**
+1. **G3 — zoom and level-of-detail geometry** — already renumbered onto 3i by
+   Task 8a; see [Resume here](#resume-here).
+2. **Settling criterion 3**, by re-measuring at **n=7–9, interleaved
+   (narrow, M4, narrow, M4, …), not blocked (three-then-three)** — the only
+   arrangement that removes the thermal/session-drift ordering bias this
+   task's own numbers show biased the ratio *against* the miss, not for it.
+3. **Plan 3j** owns the **192 MiB vertex buffer**, whose figure sits on a
+   doubling boundary with no headroom.
+
 ---
 
 ## Commands
```

## Confirmation: the results note is unmodified

```
$ git diff --stat -- docs/superpowers/notes/2026-08-25-plan-3h-results.md
(no output)
$ git status --porcelain -- docs/superpowers/notes/2026-08-25-plan-3h-results.md
(no output)
```

Not read into this task's own diffs, not touched, per the amendment's
explicit instruction ("Do not touch the results note. It is finished and was
reviewed twice.").

## Commit

```
git add -A docs/superpowers/notes STATUS.md
git status --porcelain
git commit -m "..."
```

`git status --porcelain` immediately before staging (repeated from the top
of this report for the reviewer's convenience):

```
 M STATUS.md
 M docs/superpowers/notes/plan-3h-mutation-log.md
```

No `analysis_options.yaml` in that list.

## Fix round 1

**Finding (verbatim, from the coordinator):**

> `STATUS.md:1356-1363` — the exit-gate tally is internally inconsistent. It
> states "**7 PASS, 2 MISS**" out of 9 gates, then two sentences later
> explicitly says criterion 1b "is not a binary pass or fail... resolves to
> accepted gap H5... rather than either outcome," then names only six
> criteria as PASS (1, 2, 2b, 2c, 7, 8). 6 PASS + 2 MISS + 1 (1b, neither) = 9
> — consistent — but the headline "7 PASS" silently folds 1b into the passing
> side, contradicting the very next sentence. In a section whose entire
> purpose is precise pass/fail accounting, this is a real internal
> contradiction, not a rounding choice.

**Denominator itself was reviewed and holds.** The reviewer independently
counted the spec's §4 criteria table — 12 rows, 3 recorded-only (3b, 4, 5),
9 gates — and confirmed it reproduces the spec's own recorded-versus-gated
distinction rather than an invented one. Nothing about the 9 changes; only
the 7/6 split inside it does.

**Check 1 — does the "7" figure repeat anywhere else?** Grepped the whole
file:

```
$ grep -n "7 PASS\|7 of 9\|PASS, 2 MISS" STATUS.md
1357:only, per spec, not gates. **Of the 9 that are gates: 7 PASS, 2 MISS**
```

One hit, in the one paragraph the finding names. Also checked more broadly
for any other place an exit-gate count for this plan might have been echoed:

```
$ grep -n "9 that are gates\|9 failable\|of 9\|Exit gate" STATUS.md
172:**Exit gate: 8 of 8.** ...                              # Plan 3d, unrelated
854:**Exit gate: 6 of 9 failable criteria PASS outright ...  # Plan 3e, unrelated
915:**Exit gate: 11 of 13 pass ...                           # Plan 3f, unrelated
1002:**Exit gate: 16 of 17 criteria PASS ...                 # Plan 3f.1, unrelated
1047:> Plan 3g is executed and pushed. Exit gate: 11 of 13 ... # Plan 3g, unrelated
1356:**Exit gate.** Of the criteria table's 12 rows, 3 (3b, 4, 5) ...
1357:only, per spec, not gates. **Of the 9 that are gates: ...
```

Every other "Exit gate" line belongs to a different, already-closed plan
(3d/3e/3f/3f.1/3g) and was not touched. The TL;DR and "Resume here" sections'
own Plan 3h paragraphs (grepped separately) never quote a PASS/MISS count at
all — they cite the two misses by criterion number and the mutant/gap tally,
not "7 of 9" or "6 of 9" — so nothing there needed to change either.

**Fix.** Only the headline sentence and its immediate follow-on were edited;
the body's own criterion list (1, 2, 2b, 2c, 7, 8 as PASS; 3 and 6 as MISS;
1b as neither) was already correct and is unchanged in substance. New text,
in full:

> **Exit gate.** Of the criteria table's 12 rows, 3 (3b, 4, 5) are recorded
> only, per spec, not gates. **Of the 9 that are gates: 6 PASS, 2 MISS, and
> criterion 1b resolves to accepted gap H5 rather than to either outcome** —
> per its own pre-commitment, it is not a binary pass or fail: M2 survives, so
> 1b lands on the plan's pre-declared third path, not on "pass" or "fail."
> The 2 MISS are criteria 3 and 6, both above. The 6 PASS are criteria 1, 2,
> 2b and 2c on the shipped tree (confirmed by the mutation log above),
> criterion 7 (peak `tileBytes` 27262976 bytes = 26.00 MiB against ≤ 96 MiB),
> and criterion 8 (`capacityMiB` exactly 192.00 in every configuration, no
> increase to explain).

**Check 2 — does the paragraph's prose survive the change?** Read through
after editing: the headline now states the three-way split (6/2/1) directly,
the next clause explains *why* 1b is the odd one out (referring back to its
own pre-commitment and to M2's survival, both already established earlier in
the section), and the two sentences after that enumerate the 2 MISS and then
the 6 PASS by criterion number — each count now matches the number just
stated in the headline (2 criteria named for MISS, 6 for PASS). No dangling
"both PASS" or similar leftover phrasing from the two-way version remains.

## git status --porcelain before staging (fix round 1)

```
 M STATUS.md
```

No `analysis_options.yaml`, no `.png`, no
`apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`. Staged only
`STATUS.md`, per instruction. No suite was re-run — a prose-only fix to
`STATUS.md`, and the counts already on record stand.

**Commit:** `ee61d86` — "docs: Plan 3h's exit-gate tally makes its three-way
split visible".
