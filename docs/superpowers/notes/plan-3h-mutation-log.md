# Plan 3h mutation log — the fallback walk

Five mutants are named for this plan (`docs/superpowers/specs/2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md`,
§5, plus M5, found by a reviewer after the narrowing landed and folded into
Task 5's fix round). **This log was started by Task 8a, the
machine-independent half of Task 8** — the device arm needed mains power and
the machine was on battery with Low Power Mode auto-enabled, so M4 could not
be fired there. Four of five mutants — M1, M2, M3 and M5 — live entirely in
the widget suite (`packages/jet_cad_2d_flutter`) and are recorded below in
full, each with the diff applied, the layer it was fired in, the verbatim
output, and the ruling. **M4 is now fired too, by Task 8b, the plan's
close-out**, once mains power was available for its device arm. It is listed
here so that a mutation log missing a named mutant does not read as a mutant
that was never planned.

Every figure below was produced by an implementer and independently
reproduced by a reviewer, both transcripts in
`.superpowers/sdd/2026-08-25-jet-cad-2d-plan-3h-pan-frame/task-4-report.md`
(M1) and `task-5-report.md` (M2, M3, and — under "Fix round 1" — M5), except
where a section says otherwise. **M4's figures are Task 8b's own** — fired
directly against today's tree, not read off an earlier report — and are also
independently cross-checked against
`docs/superpowers/notes/2026-08-25-plan-3h-results.md`, which fired the same
mutation in the same session that produced the device arm.

All commands below ran from `packages/jet_cad_2d_flutter`, prefixed
`CI=true`, against `lib/src/tile_cache.dart`.

---

## M1 — drop the clamp

**What it targets:** `stripFor`'s clamp to the viewport (decision D3 in the
spec). The pad can ask for a rectangle larger than the viewport when
`uncovered` (a bounding rectangle built with `expandToInclude`) spans most of
the frame; the clamp is what keeps the strip inside `[0, viewport]`.

**Layer fired in:** unit — `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`,
the `stripFor` group, via
`CI=true flutter test test/tile_cache_test.dart --plain-name "stripFor"`.
Also run and confirmed clean under the full widget suite
(`CI=true flutter test`, `flutter analyze`, `dart format`) both before and
after the mutant was applied and restored. The pure-Dart `jet_cad_2d` suite
is untouched by this change and was not run for this mutant specifically.

**Diff:**

```diff
 Rect stripFor(Rect uncovered, Size viewport) => Rect.fromLTRB(
-      math.max(0.0, uncovered.left - kTileSlack),
-      math.max(0.0, uncovered.top - kTileSlack),
-      math.min(viewport.width, uncovered.right + kTileSlack),
-      math.min(viewport.height, uncovered.bottom + kTileSlack),
+      uncovered.left - kTileSlack,
+      uncovered.top - kTileSlack,
+      uncovered.right + kTileSlack,
+      uncovered.bottom + kTileSlack,
     );
```

**Verbatim output (RED):**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: stripFor pads an interior rect on every side
00:00 +1: stripFor clamps to the viewport rather than growing past it
00:00 +1 -1: stripFor clamps to the viewport rather than growing past it [E]
  Expected: Rect:<Rect.fromLTRB(0.0, 0.0, 400.0, 300.0)>
    Actual: Rect:<Rect.fromLTRB(-32.0, -32.0, 432.0, 332.0)>
  ...
00:00 +1 -1: stripFor clamps one edge at a time
00:00 +1 -2: stripFor clamps one edge at a time [E]
  Expected: Rect:<Rect.fromLTRB(0.0, 0.0, 72.0, 300.0)>
    Actual: Rect:<Rect.fromLTRB(-32.0, -32.0, 72.0, 332.0)>
  ...
00:00 +1 -2: stripFor a strip touching the bottom-right clamps there and pads inward
00:00 +1 -3: stripFor a strip touching the bottom-right clamps there and pads inward [E]
  Expected: Rect:<Rect.fromLTRB(328.0, 228.0, 400.0, 300.0)>
    Actual: Rect:<Rect.fromLTRB(328.0, 228.0, 432.0, 332.0)>
  ...
00:00 +1 -3: Some tests failed.
```

**Ruling: KILLED.** Exactly 3 of the 4 `stripFor` cases redden — `pads an
interior rect on every side` stays green because it never touches an edge
close enough for the clamp to bind, matching the brief's prediction exactly.
Restored and re-confirmed green (`+4` on the group, `+370 ~1` / later `+372 ~1`
on the full suite depending on which task's baseline is quoted), `flutter
analyze` clean, `dart format` clean.

---

## M2 — drop the pad (`kTileSlack` → `0.0`)

**What it targets:** decision D2 — the strip is padded by `kTileSlack` before
it is walked, because a stroke whose centreline sits just outside `uncovered`
still inks pixels inside it.

**Layer fired in:** unit — `packages/jet_cad_2d_flutter/test/tile_fallback_test.dart`,
`criterion 2 and 2c` (the `fillingGrid` sweep, eight offsets), via
`CI=true flutter test test/tile_fallback_test.dart --plain-name "criterion 2 and 2c"`.
Also run under the full widget suite before and after.

**Diff (all four call sites in `stripFor`):**

```diff
 Rect stripFor(Rect uncovered, Size viewport) => Rect.fromLTRB(
-      math.max(0.0, uncovered.left - kTileSlack),
-      math.max(0.0, uncovered.top - kTileSlack),
-      math.min(viewport.width, uncovered.right + kTileSlack),
-      math.min(viewport.height, uncovered.bottom + kTileSlack),
+      math.max(0.0, uncovered.left - 0.0),
+      math.max(0.0, uncovered.top - 0.0),
+      math.min(viewport.width, uncovered.right + 0.0),
+      math.min(viewport.height, uncovered.bottom + 0.0),
     );
```

**Verbatim output:**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +1: All tests passed!
```

**Ruling: SURVIVES. Recorded as gap H5, per the plan's own pre-commitment
(spec §5, H5): "M2 may not be killable... If criterion 1b cannot be made to
fail, M2 becomes gap H5 and D2's pad is retained on `_bake`'s argument rather
than on a gate."** `pad = 0` does not delete geometry the way M3's 20-pixel
shrink does — the query is a rect intersection on entity bounds, so dropping
the pad only loses entities lying wholly outside the strip whose half stroke
width bleeds into it, and `fillingGrid`'s axis-aligned thin lines swept over
*offsets* (not zoom) do not happen to exercise that geometry at the eight
offsets tested. No fixture was invented to force a kill, per the brief's
explicit instruction not to.

**H5's measured zeros.** `test/tile_fallback_test.dart` was temporarily
edited to print each `InkReport` right after `sweepFallbackAgreement`
returned (added, used, then reverted — verified byte-identical to the
pre-edit copy afterward; not part of any commit). With M2 in place:

```
TEMP-DEBUG Offset(37.0, 0.0): InkReport(live: 38886, tiled: 38886, stray: 0, uncovered: 0, differing: 0)
TEMP-DEBUG Offset(53.0, 0.0): InkReport(live: 36906, tiled: 36906, stray: 0, uncovered: 0, differing: 0)
TEMP-DEBUG Offset(71.0, 0.0): InkReport(live: 35970, tiled: 35970, stray: 0, uncovered: 0, differing: 0)
TEMP-DEBUG Offset(0.0, 37.0): InkReport(live: 38208, tiled: 38208, stray: 0, uncovered: 0, differing: 0)
TEMP-DEBUG Offset(0.0, 53.0): InkReport(live: 37056, tiled: 37056, stray: 0, uncovered: 0, differing: 0)
TEMP-DEBUG Offset(0.0, 71.0): InkReport(live: 34232, tiled: 34232, stray: 0, uncovered: 0, differing: 0)
TEMP-DEBUG Offset(-41.0, 0.0): InkReport(live: 37608, tiled: 37608, stray: 0, uncovered: 0, differing: 0)
TEMP-DEBUG Offset(0.0, -41.0): InkReport(live: 37668, tiled: 37668, stray: 0, uncovered: 0, differing: 0)
```

`stray`, `uncovered` and `differing` are all `0` at every one of the eight
swept offsets, `live` and `tiled` ink counts equal at each.

**Why this is not a gate of this plan's own.** `kTileSlack`'s own history
says how conditional the miss is: it is the same constant `_bake` already
pads its arrival query by, and dropping that padding was Plan 3g's defect
**F1** — a whole stroke column lost at six of forty-one swept zoom factors on
a differently constructed fixture. **D2's pad rests on `_bake`'s argument and
on F1's history, not on a gate this plan built** — this plan inherited the
constant and the reasoning behind it rather than re-deriving a bound of its
own, and `fillingGrid` swept at the offsets this plan's criteria use does not
happen to reproduce F1's geometry.

---

## M3 — shrink the query 20 logical pixels (`kTileSlack` → `-20.0`)

**What it targets:** criterion 1, the mutation gate that proves the sweep
measures something real — a query shrunk below what the geometry needs must
be caught.

**Layer fired in:** unit — targeted first against
`test/tile_fallback_test.dart`'s `criterion 2 and 2c` alone, via the same
command as M2. Re-fired a second time in Task 5's fix round 1 with the
triangle-budget gate (below, M5) already in place, still targeted at
`criterion 2 and 2c`, to confirm the new gate did not change M3's kill path.
**Fired a third time in Task 8a's own fix round 1 (2026-08-25) against the
whole widget suite** — `CI=true flutter test`, all of
`packages/jet_cad_2d_flutter`, not one file — plus `flutter analyze` and
`dart format --output=none --set-exit-if-changed .` under the mutant. That
full-suite run is what the rest of this section is built from; see "Full
widget suite under M3" below.

**Diff (all four call sites in `stripFor`):**

```diff
 Rect stripFor(Rect uncovered, Size viewport) => Rect.fromLTRB(
-      math.max(0.0, uncovered.left - kTileSlack),
-      math.max(0.0, uncovered.top - kTileSlack),
-      math.min(viewport.width, uncovered.right + kTileSlack),
-      math.min(viewport.height, uncovered.bottom + kTileSlack),
+      math.max(0.0, uncovered.left - -20.0),
+      math.max(0.0, uncovered.top - -20.0),
+      math.min(viewport.width, uncovered.right + -20.0),
+      math.min(viewport.height, uncovered.bottom + -20.0),
     );
```

**Verbatim output (RED, before the triangle gate existed):**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
  Expected: <0>
    Actual: <1642>
  Offset(37.0, 0.0): InkReport(live: 38886, tiled: 37244, stray: 0, uncovered: 1642, differing: 1642)
  ...
00:00 +0 -1: Some tests failed.
```

**Verbatim output (RED, re-confirmed after the triangle gate landed, Task 5
fix round 1):**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
  Expected: <0>
    Actual: <1642>
  Offset(37.0, 0.0): InkReport(live: 38886, tiled: 37244, stray: 0, uncovered: 1642, differing: 1642, liveTri: 60, tiledTri: 10)
  ...
00:00 +0 -1: Some tests failed.
```

Same `uncoveredPixels: 1642` both times — the pixel assertion (which appears
earlier in the test body) fires first and identically; the triangle-budget
assertion added for M5 never gets a chance to run against this mutant.

**Ruling: KILLED**, targeted, before and after the triangle-budget gate
existed, and — see immediately below — under the whole widget suite on
today's tree.

### Full widget suite under M3 (Task 8a, fix round 1, today's tree)

**This subsection is a property of the tree as it stands today, reproduced
directly, not a historical record like M5's first-fired result below.** The
mutant was applied fresh to the current `lib/src/tile_cache.dart`, the whole
widget suite was run under it, and the mutant was then restored from a `/tmp`
copy (never `git checkout`) and the suite re-confirmed green before this
sentence was written.

Command: `CI=true flutter test` (whole package, from
`packages/jet_cad_2d_flutter`).

Final summary line: `+365 ~1 -7: Some tests failed.` — **365 passed, 1
skipped, 7 failed**, against the baseline's 372 passed / 1 skipped / 0
failed (373 total both times; 7 of the 373 flip from pass to fail under this
mutant).

**All seven failures by name, each confirmed by its own `[E]` block in the
transcript:**

1. `test/invariants/tile_budget_test.dart`: *criterion 12: a frame at the cap
   still equals the live frame* — `Expected: <0>`, `Actual: <1000>`,
   `InkReport(live: 19860, tiled: 18860, stray: 0, uncovered: 1000,
   differing: 1000, liveTri: 40, tiledTri: 36)`. **New relative to every
   prior record of M3** — neither `task-5-report.md` nor the ledger's M3
   entries mention `tile_budget_test.dart` reddening.
2. `test/tile_cache_test.dart`: *stripFor pads an interior rect on every
   side* — `Expected: Rect:<Rect.fromLTRB(68.0, 48.0, 232.0, 212.0)>`,
   `Actual: Rect:<Rect.fromLTRB(120.0, 100.0, 180.0, 160.0)>`. This is the
   one `stripFor` case M1 (drop the clamp) could **not** redden; M3 reddens
   it because M3 replaces the pad's *value*, not just its clamp, so even an
   interior rect far from every edge is padded by the wrong amount.
3. `test/tile_cache_test.dart`: *stripFor clamps to the viewport rather than
   growing past it* — `Expected: Rect:<Rect.fromLTRB(0.0, 0.0, 400.0,
   300.0)>`, `Actual: Rect:<Rect.fromLTRB(20.0, 20.0, 380.0, 280.0)>`.
4. `test/tile_cache_test.dart`: *stripFor clamps one edge at a time* —
   `Expected: Rect:<Rect.fromLTRB(0.0, 0.0, 72.0, 300.0)>`,
   `Actual: Rect:<Rect.fromLTRB(20.0, 20.0, 20.0, 280.0)>`.
5. `test/tile_cache_test.dart`: *stripFor a strip touching the bottom-right
   clamps there and pads inward* — `Expected: Rect:<Rect.fromLTRB(328.0,
   228.0, 400.0, 300.0)>`, `Actual: Rect:<Rect.fromLTRB(380.0, 280.0, 380.0,
   280.0)>`.
6. `test/tile_fallback_test.dart`: *criterion 2 and 2c: a partly baked frame
   equals the live frame* — `Expected: <0>`, `Actual: <1642>`,
   `Offset(37.0, 0.0): InkReport(live: 38886, tiled: 37244, stray: 0,
   uncovered: 1642, differing: 1642, liveTri: 60, tiledTri: 10)`. Digit-
   identical to every prior firing of M3 on this offset.
7. `test/tile_fallback_test.dart`: *criterion 2b: the near-axis arm stays
   inside the tiled path's bound* — `Expected: a value less than or equal to
   <60>`, `Actual: <417>`, `Offset(37.0, 0.0): InkReport(live: 10703, tiled:
   10344, stray: 29, uncovered: 388, differing: 417, liveTri: 20,
   tiledTri: 0)`.

**Failure 7 is the fuller kill amendment 1 asked to be recorded: under M3,
criterion 2b reddens with `differing: 417` against a bound of 60, not only
criteria 2 and 2c as the plan's own text claimed.** That figure was
previously known only from this plan's ledger
(`.superpowers/sdd/2026-08-25-jet-cad-2d-plan-3h-pan-frame/progress.md`, line
89) and restated in `task-8-brief.md`'s controller amendment 1, item 3 — **it
is now independently reproduced by Task 8a directly, digit-identical
(`differing: 417`)**, not merely read off the brief. See the "Figures"
section at the end of this log for the corrected status.

**`flutter analyze` and `dart format` under M3:** run rather than assumed.
Both clean —

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```

```
Formatted 65 files (0 changed) in 0.12 seconds.
```

— confirming M3 is a value change, not a structural one, exactly as
expected but not taken on faith.

**Restore, verified.** `lib/src/tile_cache.dart` was copied aside to `/tmp`
before the mutant was applied and copied back afterward (never `git
checkout`); `diff` against the pre-mutation copy produced no output. `git
status --porcelain` was clean immediately after restoring. `CI=true flutter
test` was re-run and returned to the baseline exactly: `+372 ~1: All tests
passed!`

---

## M4 — narrow the clip but not the query

**Fired by Task 8b, the plan's close-out.** M4 isolates the original defect
this plan fixes: keep the narrower clip `_bake` already uses, but hand the
fallback's *query* (what is walked, not what is drawn) the full viewport
instead of the strip — "narrow the clip, not the query," per the spec's
mutant table.

**The plan's own claim, and the log's earlier placeholder, said "no unit gate
can kill it" and that M4 "dies only on criterion 3's device ratio." That
claim is FALSE, and correcting it is the most important thing this section
records.** After the plan was written, a reviewer found M5 — grow the walk to
the viewport, leaving the clip narrow — and Task 5's fix round added a
triangle-count-ratio gate to `test/tile_fallback_test.dart`'s "criterion 2 and
2c" test specifically to kill it. M4 also ends up handing `_drawInto` the full
viewport (arrived at from a different starting mutation than M5: M4 keeps the
narrow clip and drops the strip-sized query, while M5 grows the query and
leaves the clip untouched — see M5's section below), and the triangle-count
gate counts geometry, not pixels, so it cannot distinguish the two routes to
the same end state. **The same gate that was built to kill M5 kills M4 as
well.** M4 dies **doubly**: in the widget suite, and on the device ratio.

**Diff**, applied to `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
(backed up first to `/tmp/tile_cache_8b_backup.dart`, restored from that copy
afterward — **never `git checkout`**): kept `canvas.clipRect(uncovered,
doAntiAlias: false)` and `_lastStrip = strip;`, dropped `canvas.translate`,
and passed `viewport` and `quantised` to `_drawInto` in place of the
strip-sized `Size` and the shifted `ViewportTransform`:

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

**Layer fired in: unit (targeted), unit (whole package), and device.** All
three are recorded below; the device figures are the M4 arm from
`docs/superpowers/notes/2026-08-25-plan-3h-results.md`, reproduced here as
the ratio's numerator rather than re-measured.

**Verbatim output, targeted** —
`CI=true flutter test test/tile_fallback_test.dart`, from
`packages/jet_cad_2d_flutter` — **RED**:

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

`criterion 2 and 2c` fails with `liveTri: 60, tiledTri: 70` against a bound of
54 — digit-identical to the results note's own firing. `criterion 2b` still
passes (listed `+1` after the failure, i.e. green). Full log:
`/tmp/3h_m4_8b_tile_fallback_test.log`.

**Verbatim output, whole package** — `CI=true flutter test`, all of
`packages/jet_cad_2d_flutter`, not one file — **RED, exactly one failure**:

```
00:05 +371 ~1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart: criterion 2 and 2c: a partly baked frame equals the live frame
```

**371 passed, 1 skipped (pre-existing, unrelated), 1 failed** — the same
"criterion 2 and 2c" test, the only failure anywhere in the package. This
matches, digit for digit, both of the two independent runs that preceded
this one (the results note's own firing, and the reviewer's prior
reproduction): `+371 ~1 -1` with exactly one failure, every time. Full log:
`/tmp/3h_m4_8b_full_suite.log`.

**Restore, verified.** `cp /tmp/tile_cache_8b_backup.dart
lib/src/tile_cache.dart` (not `git checkout` — the file was never staged or
committed during this mutation, so this copies the mutant's own pre-image
back). `diff /tmp/tile_cache_8b_backup.dart lib/src/tile_cache.dart` produced
no output; `git diff -- lib/src/tile_cache.dart` and `git status --porcelain
-- lib/src/tile_cache.dart` were both empty immediately after. `CI=true
flutter test test/tile_fallback_test.dart` on the restored tree: `+2: All
tests passed!` (both `criterion 2 and 2c` and `criterion 2b` green).

**Device arm** (from `docs/superpowers/notes/2026-08-25-plan-3h-results.md`,
Step 4, not re-measured here — Task 8b's own device time went to the widget
suite above, which is the new finding; the timing figures already exist and
rerunning `flutter drive` would not change what they say): `tile pan` p95
across three runs, {38.14, 36.14, 37.59} ms, median **37.59 ms**, against the
narrowed arm's median of **15.99 ms** — **ratio 2.35**, short of the ≥ 2.4
gate (see `STATUS.md`'s Plan 3h section and the results note for the full
discussion of that miss, including why n=3 cannot settle it and why the gate
itself was mis-derived). `capacityMiB=192.00` and peak `tileBytes=27262976`
(26.00 MiB) in all three runs, identical to the narrowed arm — M4 changes
only how much the fallback walks, not the vertex sink's capacity or the tile
geometry. `bakes=14 liveDraws=10` in the `tile pan` phase in all three,
identical to the narrowed arm too, confirming M4 changes *how much* each
fallback walks, not *how often* one happens.

**Ruling: DIES — doubly.** The widget suite kills M4 directly (RED above,
same gate M5's fix round added). The device ratio separates it too: 2.35× is
short of the 2.4 gate, but it is nowhere near 1.0×, which is what a true
non-regression would read (the mutated tree reads its own p95 against
itself, which is trivially 1.0 — the ratio that matters is the *shipped*
narrowed code's 2.35× over what M4 represents; see the results note's Step 4
for that framing). **An absolute 16.67 ms threshold could not have witnessed
M4 either**: the narrowed arm's own p95 figures (19.86, 15.99, 13.43 ms)
straddle 16.67 ms on the correct tree, while M4's p95 figures (38.14, 36.14,
37.59 ms) are more than double that — a single absolute gate would fail both
the correct tree and M4 on some runs and cannot tell them apart. Only the
ratio, read against the same-session narrowed arm, separates them.

---

## M5 — grow the walk instead of shrinking it (found by a reviewer)

**What it targets:** the sweep's blind side. M1–M3 all *shrink* what the
fallback queries; nothing in the plan as designed tested what happens if the
query is *grown* back toward the full viewport, which is exactly the
narrowing this plan exists to reverse.

**Layer fired in:** unit — the whole `test/tile_fallback_test.dart` file
(both `criterion 2 and 2c` and `criterion 2b`), via
`CI=true flutter test test/tile_fallback_test.dart`. **First fired against
the full package suite** (`CI=true flutter test`) before any gate existed for
it, per the plan's ledger
(`.superpowers/sdd/2026-08-25-jet-cad-2d-plan-3h-pan-frame/progress.md`, line
79): "The reviewer replaced `Size(strip.width, strip.height)` with
`viewport` — leaving the translate, the camera offset and `_lastStrip` alone
— and the whole package stayed green at `+372 ~1`."

**Diff (`paintFrame`'s fallback branch, the `_drawInto` call):**

```diff
     _drawInto(
         canvas,
-        Size(strip.width, strip.height),
+        viewport,
         ViewportTransform(
             worldToScreenMatrix: Transform2(
                 q.a, q.b, q.c, q.d, q.e - strip.left, q.f - strip.top)),
         painter,
         sink,
         vertices,
         origin,
         null);
```

The translate, the camera offset (`q.e - strip.left`, `q.f - strip.top`) and
`_lastStrip` are all left untouched — only the `Size` handed to `_drawInto`
grows back to the full viewport.

**Verbatim output, first fired (GREEN — the gap as found):** every pixel
comparison passes, because the mutant walks a *superset* of `uncovered` and
the unchanged `clipRect(uncovered)` absorbs the excess — the frame is
pixel-identical to the correct tree even though it tessellates the whole
viewport again, which is precisely the cost this plan exists to remove.
`debugLastStrip` still reports the (correct, narrow) strip, because
`_lastStrip = strip` is untouched — only the drawn extent grew, not the
recorded one.

**Verbatim output, after the fix round's triangle-budget gate (RED):**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
  Expected: a value less than <54.0>
    Actual: <70>
     Which: is not a value less than <54.0>
  pan Offset(37.0, 0.0): the tiled arm emitted as much geometry as the full-frame live arm, so the fallback walked far more than the strip: InkReport(live: 38886, tiled: 38886, stray: 0, uncovered: 0, differing: 0, liveTri: 60, tiledTri: 70)
  ...
00:00 +0 -1: criterion 2b: the near-axis arm stays inside the tiled path's bound
00:00 +1 -1: Some tests failed.
```

`criterion 2b` is unaffected (listed `+1`, i.e. passed) — confirming the
triangle-budget gate's opt-in scoping holds under this mutation too.

**Ruling: KILLED** by the triangle-count-ratio gate added in Task 5's fix
round (`kTriangleBudgetRatio = 0.9`, `VerticesDrawSink.frameTriangleCount`
compared per arm), which did not exist when M5 was found. **It was green
against the entire widget package when first fired.**

**What this records about the sweep's own shape.** The pixel-agreement sweep
(criteria 2, 2b, 2c) catches a fallback query *shrunk* (M3) but structurally
cannot catch one *grown*, because the unchanged `clipRect(uncovered)`
discards every extra pixel the larger query would have drawn — "the pixels
stay correct, so the sweep still reads zero, and the cost this whole change
exists to remove comes back silently" (`tile_cache.dart`'s own comment on the
clip warns of exactly this asymmetry, applied there to the clip; M5 is the
same asymmetry applied to the `Size` argument one line below it). The
asymmetry is inherent to a pixel-only oracle watching a cost-only change, not
a defect in how the pixel sweep was written.

---

## Deferred minors (Task 5's fix round and Task 3)

Recorded here per this task's controller amendment, items 5 and 6, since
they concern the mutation apparatus above rather than the exit gate itself:

1. **The triangle gate is tight.** At its tightest offset on `fillingGrid`
   (`Offset(0.0, 37.0)`), correct code reads `tiledTri: 50` against
   `liveTri: 60` — a ratio of 0.8333, four triangles of headroom under the
   `kTriangleBudgetRatio = 0.9` bound (54 allowed). This is deterministic,
   not a flake — the re-reviewer bracketed it directly, `0.84` green and
   `0.83` red at that offset — but it is brittle to any future edit of
   `fillingGrid`'s fixture geometry or `kFallbackOffsets`'s swept offsets,
   either of which could shift the correct-code ratio without any change to
   `tile_cache.dart`.
2. **`checkTriangleBudget` defaults to `false`.** `measureFallbackAgreement`
   and `sweepFallbackAgreement` both take it as an opt-in parameter because
   it carries no signal on `nearAxisDiagonals` (ratios of exactly `1.0` or
   `0` under correct code). Only `criterion 2 and 2c` passes `true` today. A
   future third caller of either function gets no triangle-count gate unless
   it opts in explicitly and remembers to.
3. **Task 3's per-offset table has no in-tree provenance.** The per-offset
   figures in that task's report were produced with a throwaway, unstaged
   debug file, and nothing committed to the repository records how the table
   was generated or lets it be regenerated.

---

## Figures not independently reproduced by Task 8a

At initial writing, no mutant had been re-fired and no new measurement had
been taken for this log — every figure was read from
`.superpowers/sdd/2026-08-25-jet-cad-2d-plan-3h-pan-frame/task-4-report.md`,
`task-5-report.md`, or (for two figures) the plan's ledger, per the brief's
instruction to read rather than re-run. **Fix round 1 changed this for one
of the two:**

- **M3's criterion 2b figure, `differing: 417` against a bound of 60**, was
  not in `task-4-report.md` or `task-5-report.md` when this log was first
  written; it was recorded only in `progress.md` (line 89) and restated in
  `task-8-brief.md`'s controller amendment 1. **Fix round 1 (2026-08-25) has
  since fired M3 against the whole widget suite on today's tree and
  reproduced this figure directly, digit-identical** — see "Full widget
  suite under M3" in the M3 section above. It is no longer a figure taken on
  the brief's word alone; it is a property of today's tree, independently
  confirmed by both an implementer and, per the reviewer's fix-round-1
  message, a reviewer.
- **M5's first-fired result, `+372 ~1` green against the whole package**, is
  still from `progress.md` (line 79) rather than from either named task
  report — `task-5-report.md` documents M5 only from the point the
  triangle-budget gate already existed (Task 5's "Fix round 1"), not the
  reviewer's original discovery run. **Unlike M3's figure above, this one
  cannot be independently reproduced today**: the triangle-budget gate now
  exists in the committed tree, so firing M5 again reddens `criterion 2 and
  2c` (as shown in the M5 section above) rather than reproducing the
  historical all-green result. The `+372 ~1` figure remains a record of what
  the tree looked like before the fix round, not a claim about the tree as
  it stands now.

No other figure needed for this log was missing from the two named reports.
