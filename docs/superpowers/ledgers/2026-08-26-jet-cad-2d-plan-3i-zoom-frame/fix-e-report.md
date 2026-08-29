# Fix wave E — the repaint guard could not see a composite-only frame

**Status:** done, gate green.
**Commits:** `d7ea068` (fix + test), `d8d1332` (mutation log). Branch `main`,
parent `d7dd24d`.
**Territory:** `apps/dev_harness_2d/` only, plus the plan's mutation log in
`docs/superpowers/notes/`. Neither `packages/jet_cad_2d_flutter/` nor
`packages/jet_cad_2d` was touched.

---

## 1. The defect

The controller's functional smoke run of the rig died in its first phase:

```
[ERROR] Unhandled Exception: Bad state: no repaint happened: the forced frame did not draw
  requireRepaint (measurement_rig.dart:133)
  runR2Rig (measurement_rig.dart:387)
```

at `--dart-define=TILES=on --dart-define=ENTITIES=5000 --dart-define=RUN_R2=true`,
while the same corpus with tiles off printed `R2 app-run: done`. The control is
what makes the pair decisive: with tiles off, the live walk feeds the vertices
sink, so the guard's sum is nonzero for that reason alone and the tiled arm was
the only one ever exercising the tiled terms.

Two faults, both in `apps/dev_harness_2d/lib/measurement_rig.dart`.

**Fault 1 — a dead parameter.** `requireRepaint`'s `tileCache` named parameter
was optional and was fed **from nowhere** in `measurement_rig.dart`.
`integration_test/frame_timing_test.dart` passes it at both of its call sites
(`:285`, `:346`); `runR2Rig` — the whole of the app-run script — called
`requireRepaint(sink, vertices)`. Under `TILES=on` the forced
`panBy(Offset.zero)` frame is served from the cache, the painter is never
walked, both sink counters read zero, and the guard threw on a frame that had
drawn correctly.

**Fault 2 — the sum was incomplete anyway.** `blitCount + liveDrawCount` is not
the whole of "drew". Plan 3i split the tiled frame into two regimes: a *moving*
frame, and the in-between frame at `_restGateSteps == 1`, draw the carry-over
composite **and nothing else** — no tile blit, no live walk, no painter call.
On such a frame both counters read zero while the frame genuinely painted, and
`TileCache.carryOverBlitCount` (`tile_cache.dart:819`, incremented at `:1130`,
zeroed by `resetCounters` at `:952`) is the only counter that saw it. Member
names verified against the current source.

**Fault 3, found while fixing the first two — the counters were never reset.**
The tile counters are per-frame: they count since the last `resetCounters`.
`runR2Rig` reset the two sinks before its forced frame and *not* the cache, so
wiring `tileCache` through without also resetting it would have handed the
guard four counters already in the thousands from the 240 frames of pan and
zoom above. The guard would then have been unable to fail **ever again** — the
exact opposite of the fix — and `printTileCounters` was, meanwhile, publishing
four cache-lifetime totals under a heading whose own doc comment says
per-frame. `tileCache?.resetCounters()` now sits beside `sink.resetCounters()`,
which is what the integration test's call sites already did.

**Why no recorded run hit any of this.** Every Plan 3h device run passed
`--dart-define=RIG=pan` (`2026-08-25-plan-3h-results.md:186`), a selection that
skipped this script — and `grep -rn "RIG" apps/dev_harness_2d/lib/` returns
nothing today. Plan 3i's Task 12 command line therefore drives `runR2Rig`'s
full script where Plan 3h drove a shorter one. See §6.

---

## 2. What changed

`apps/dev_harness_2d/lib/measurement_rig.dart`:

1. `requireRepaint`'s `tileCache` is now **`required TileCache? tileCache`** —
   required and nullable. An untiled caller writes `tileCache: null` and says
   so; a caller that forgets does not compile.
2. `(tileCache?.carryOverBlitCount ?? 0)` joins the sum.
3. `runR2Rig` passes `tileCache: tileCache` at its call site.
4. `tileCache?.resetCounters()` joins the two sink resets before the forced
   frame, with a comment saying what it is load-bearing for.
5. The doc comment records the observed failure, the two-regime frame, and why
   the parameter is required rather than optional.

`apps/dev_harness_2d/test/require_repaint_test.dart` is new (2 tests).

`docs/superpowers/notes/plan-3i-mutation-log.md` gains §M25 and §M26.

---

## 3. What still makes the guard throw

This is the question the brief asks to be answered explicitly: widening the
guard to count composite blits must not widen it into something that can no
longer fail.

All five terms in the sum are **per-frame**, and all five are zeroed
immediately before the forced repaint at every call site:

* `sink.canvasCallCount` — `CanvasDrawSink.resetCounters()`
* `vertices.totalFlushCount` — `VerticesDrawSink.resetCounters()`
* `tileCache.blitCount`, `carryOverBlitCount`, `liveDrawCount` —
  `TileCache.resetCounters()`, which zeroes all three (`tile_cache.dart:948`)

So the state the guard exists to catch — the `panBy(Offset.zero)` no-op failing
to force a frame, because something upstream grew an `operator==` and
`ValueNotifier` deduped the assignment — still leaves every one of the five at
zero and still throws. Nothing about `carryOverBlitCount` is a lifetime total,
and nothing about it is incremented outside `paintFrame`.

The failure mode the fix *does* remove is the opposite one: a healthy frame
that drew only the composite is no longer reported as a dead frame.

The test `a frame that never ran throws, on a warm cache` is the direct gate on
this. It is deliberately **not** run against a virgin cache — a cache fresh
from its constructor throws for a reason no rig can reach. It warms a real
cache to `viewportCovered` (baking, blitting, the lot), then resets every
counter and pumps no frame, which is exactly the state a rig occupies between
its `resetCounters()` and its forced repaint. It stays green under M26, in the
same transcript in which the other test fails.

The one thing that is now weaker and worth naming: `bakeCount` is deliberately
**not** in the sum. A bake without a blit puts nothing on screen, so counting
it would be the widening this section is about.

---

## 4. The test

`apps/dev_harness_2d/test/require_repaint_test.dart`, two tests, plain `test()`
(no widget tree needed):

* `a frame that never ran throws, on a warm cache` — §3 above.
* `a carry-over composite alone counts as a repaint` — the new behaviour.

**The fixture is a real `TileCache` driven into the composite-only state, never
a hand-set counter.** The claim under test is about what the cache actually
leaves on its counters after a moving frame; a stub would assert the author's
belief about that instead. The rig is the smallest thing that reaches it:

* `seamCorpus()` from the harness's own `lib/seam_corpus.dart` — ~60 entities,
  sitting six million world units out at `kDefaultOriginX`, so nothing here can
  pass at the origin.
* 64-device-pixel tiles on a 400x300 logical / dpr 2 viewport = 130 tiles, so
  no coverage claim is one tile's claim (anti-degenerate clause 1).
* A hand-built camera at scale 0.1 with the y axis flipped — **not**
  `ViewportTransform.fit`, and not the identity (clause 2).
* Warm until `viewportCovered`, assert it, reset the sink and cache counters,
  then one `zoomBy(1.4)` about the viewport centre. Zooming *in* by that much
  makes the magnified composite run past all four edges, so no ring is left for
  the live fallback to owe. Scaling `a`/`d` alone would pin a world point
  outside the viewport and slide the composite off an edge — the "no live
  fallback" reading would then be a fact about the rig.

Before the guard is asked anything, the test asserts the fixture's own state:
`carryOverBlitCount > 0`, `blitCount == 0`, `liveDrawCount == 0`,
`canvasCallCount == 0`. Without those four lines the test would pass equally
well on a frame that blitted tiles, and M26 would survive.

---

## 5. Mutants

Both real, both `cp` aside → mutate → run → `cp` back → `diff` (never
`git checkout`). Full transcripts are in
`docs/superpowers/notes/plan-3i-mutation-log.md` §M25 and §M26; both restores
diffed clean.

### M25 — revert the call site to `requireRepaint(sink, vertices)` — **DEAD**

**The unit test cannot see this call site, and the entry says so plainly.**
`runR2Rig` opens with `refuseDebugMode()` — correctly, since a debug frame time
means nothing — and `flutter test` is a debug build, so no unit test in this
package can execute line 420. Rather than claim a kill that was not got, the
call site is **gated a different way**: `tileCache` is a required named
parameter, so the mutant is a compilation failure. That reddens
`CI=true flutter test` (every test in the harness fails to load, because they
all import a library that no longer compiles) *and* `CI=true flutter analyze`
(`missing_required_argument`, 1 issue). It is a stronger gate than an
assertion: an assertion fails only on the call site it exercises, this fails on
any call site in the package that forgets the argument.

### M26 — drop `carryOverBlitCount` from the sum — **DEAD**

Red, one test, `a carry-over composite alone counts as a repaint`, failing with
the guard's own message — the exact failure the device smoke run produced. `a
frame that never ran throws, on a warm cache` stays green in the same
transcript.

M25 and M26 were free; M24 was the highest taken.

---

## 6. The real-app confirmation

Run exactly as the smoke run did, from `apps/dev_harness_2d`:

```sh
CI=true caffeinate -dimsu flutter run -d macos --profile \
  --dart-define=TILES=on --dart-define=ENTITIES=5000 --dart-define=RUN_R2=true \
  > /tmp/jc-smoke-fixed.log 2>&1
```

backgrounded, watched for the closing line, then killed — the app has no
`exit()` after `R2 app-run: done` and `flutter run` stays attached.

**Result: it reached `R2 app-run: done`.** The whole script ran: the R2 block,
`tile warm`, `tile hold`, `tile pan` and `tile probe`. Nothing threw: a
case-insensitive scan of the log for `exception`, `error`, `abort`, `!!!` and
`stack trace` returned nothing, and `R2 app-run: done` appears exactly once.

**This was a functional check, not a measurement. No number from it is recorded
here, in the log, or in any note**, and none may be quoted.

---

## 7. Concerns

**1. The missing `RIG` define is a scope question for the controller.** Plan
3h's device runs all passed `--dart-define=RIG=pan`; nothing in
`apps/dev_harness_2d/lib/` reads `RIG` today. Task 12's command therefore runs
`runR2Rig`'s *full* script — pan phase, zoom phase, forced frame, then
`runTilePhases`' warm/hold/pan/probe — where Plan 3h ran a shorter one. Not
mine to change; naming it because every "this path has never been driven"
finding in this wave descends from it.

**2. `runR2Rig`'s own zoom phase anchors at a hardcoded `Offset(800, 600)`
(`measurement_rig.dart:362`), which is the viewport centre only at a 1600x1200
logical window.** At any other window size that phase zooms about a point that
is not the centre and can be outside the viewport entirely — and unlike the
`tile zoom` phase, **nothing warns**: `warnIfZoomViewportMismatch` is called
only inside the `tileCache != null && kZoomArms > 0` branch in `main.dart`, so
a plain `RUN_R2` run at a non-reference window prints its window size and no
warning at all. The 120 zoom frames R2 reports, and the cache state the forced
frame and every `runTilePhases` phase inherit from them, are all downstream of
that anchor. **Task 12 should confirm the real window is the pinned reference
before any number from a tiles-on `RUN_R2` run is published**, or the
mismatch warning should be hoisted out of the `ZOOM_ARMS` branch. I did not
change this: it is a measurement-semantics decision, not a defect fix, and it
sits at the boundary of this wave's brief.

**3. Examined and found *not* to be a hazard, recorded so the next reader does
not re-derive it.** `runTilePhases`' warm loop terminates when
`cache.bakeCount` stops changing between frames. Under Plan 3i's rest gate, "a
frame that baked nothing" is no longer synonymous with "covered" — the
in-between frame at `_restGateSteps == 1` bakes nothing by design and is
followed by one that bakes. In this call position the gate is already armed
(the forced frame is preceded by `settle()` and many unchanged-camera frames),
so the first warm frame is a resting frame and the loop cannot exit early. A
future caller that reaches `runTilePhases` from a *moving* camera would not
have that guarantee, and the phase's `maxWarmFrames` bound cannot see the
difference: it reports a premature exit as `frames=1`, which reads like a warm
cache.

**4. `printInvariants`' `screenSpaceLeafCount` caveat under `TILES=on` is
already documented in the source** and is unaffected by this fix; I mention it
only because the same forced frame carries both it and the counters this wave
changed, and a reader comparing the two lines needs to know one is a frame
total and the other is the last `paint()` call.

---

## 8. Gate

```
apps/dev_harness_2d       CI=true flutter test --concurrency=1   49 passed
                          CI=true flutter analyze                No issues found
                          dart format --set-exit-if-changed      12 files, 0 changed
packages/jet_cad_2d_flutter  CI=true flutter test                413 passed, 1 skipped
packages/jet_cad_2d          CI=true dart test                   797 passed
```

Baselines at `d7dd24d` were 47 / 413+1 skip / 797. The harness gains exactly
the two new tests. `git status` after the work shows no `analysis_options.yaml`
modification; both commits stage named paths only.
