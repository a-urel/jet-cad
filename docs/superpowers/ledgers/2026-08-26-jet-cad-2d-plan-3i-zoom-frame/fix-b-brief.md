# Fix wave B — the measurement rig measures the wrong frames

One Blocking and three Major findings from Plan 3i's final whole-branch review.
**Everything here is confined to `apps/dev_harness_2d/`.** A parallel wave is
working in `packages/jet_cad_2d_flutter/` — do not touch that package, and do
not touch `packages/jet_cad_2d` at all.

**Why this matters more than it looks.** Plan 3i's remaining work is to measure
criteria 2, 3, 4, 8 and 9 on the device and write the numbers into a document of
record. Those runs have not happened yet — they are blocked on machine power.
Every finding below means the rig, as it stands, would produce a number that
looks right and is not. Fixing them **before** the run is the whole value; after
the run it is a retraction.

All findings were independently verified from source by the controller. They are
real. Do not re-litigate whether they exist.

## Binding constraints

- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of
  them in this workspace. Stage named paths only; never `git add -A` at the repo
  root.
- **Never synthesize test output or measurement numbers.** Paste only what you
  actually ran. You will NOT run the device rig — it is blocked — so no
  measurement figure may appear anywhere in your work.
- **Never `git checkout` a file** — blocked here. Revert by `cp` from a backup.
- **Prefix every test command with `CI=true`.**
- `unused_import` and `unused_element` are **ERRORS**.
- The pinned script is **not yours to change**: `kZoomSteps = 40`,
  `kZoomFactor = 1.03`, focal point at 30%/70% of a **1600×1200** logical
  reference viewport at dpr 2. These are pinned by the design spec §5.
- Code and comments in English.

---

## BLOCKING — `settleMs` systematically names the wrong frame

`apps/dev_harness_2d/lib/measurement_rig.dart:826-846`.

The idle loop registers a fresh `collectIdle` at `:829` and removes it at
`:833`, wrapping a **single** `await pumpFrame()`. `pumpFrame` completes at
`SchedulerBinding.endOfFrame` — the frame's post-frame phase, **before the scene
rasterises**. A `FrameTiming` is delivered only *after* rasterisation. So
`idleTimings` for idle frame *i* can never contain frame *i*'s own timing: it
contains whatever arrived during that await, which is frame *i-1*'s, or nothing
(`idleTimings.isEmpty → 0.0` at `:835`).

On correct code, coverage first reads true at idle frame **2** (see Ruling 15 in
`.superpowers/sdd/2026-08-26-jet-cad-2d-plan-3i-zoom-frame/progress.md`). So
`settleMs` reports the **in-between frame** — a composite blit that draws
nothing, essentially free — under the label "the frame that covered the
viewport". `settleMs` is the only time value criteria 3 and 4 are read off.

**This file already states the hazard and prescribes the fix**, at `:346-352`
inside `runR2Rig`:

> the bucket the callback appends to, swapped between phases rather than
> re-registered: `addTimingsCallback` reports a frame *after* it rasterised, so
> removing and re-adding the callback around a phase boundary drops the tail of
> one phase instead of moving it. A swapped bucket keeps every frame …

`runTileZoomPhase` does exactly what that comment forbids. **Fix it the way the
comment prescribes**: one registration for the whole idle sequence, a swapped
bucket per frame, and attribute each `FrameTiming` to the frame it actually
belongs to — pump one extra frame at the end if that is what it takes to collect
the last real timing, and say so at the code.

**Prove it.** Write a test that fails under the old attribution. The named
mutation that must die: **make the settle frame arbitrarily expensive and show
`settleMs` moves.** Today it does not — the reported value is read off the
previous frame. Fire it as **M20**, paste the real RED and GREEN transcripts,
and add an M20 section to `docs/superpowers/notes/plan-3i-mutation-log.md` in
the format the existing entries use (read two first).

## MAJOR — the gesture window drops its tail and charges the gesture for the warm-up

Same file, `:788-808`. `addTimingsCallback(collectGesture)` at `:794` runs
*after* the two `panBy(Offset.zero)` warm-up pumps at `:788-791`. Those frames
rasterise before registration but are **reported after it**, so they land in
`gestureTimings`. `removeTimingsCallback` at `:808` runs immediately after the
80th pump, so the last one or two real gesture frames' timings are **dropped**.

The sample is shifted by ~2: padded at the head with the two cheapest frames in
the phase (a no-op repaint of a covered generation) and truncated at the tail.
`ZoomReport.gestureFrameMs`'s doc claims "80 entries at the pinned script"; the
count is right only by coincidence. **Both effects push p95 down — the direction
that makes criterion 2 pass.**

Fix with the same swapped-bucket discipline, and make the 80-entry claim
something the code enforces rather than something the doc asserts.

## MAJOR — criterion 4's numerator is never computed

The spec pins criterion 4 as **"wall clock to a covered viewport, from the first
frame after the gesture ends to the frame that covers it."**

`runTileZoomPhase` (`:818-846`) reports `settleFrames` (a count) and `settleMs`
(a **single** frame's `totalSpan`). Nothing accumulates elapsed time across the
settle. For the rest arm that is ~1 frame and the two nearly coincide; for the
tiled/denominator arm the settle is many frames, and `settleMs` is the last one
alone — so a ratio formed from `settleMs` compares one frame against one frame,
**not wall clock against wall clock**. That is the "two readings straddling the
gate" the spec's §4 exists to prevent.

**Add the wall-clock figure** the criterion actually names: elapsed time from
the first idle frame to the frame at which `viewportCovered` first reads true,
summed over the frames in between. Report it as its own field on `ZoomReport`
with a doc comment quoting the criterion, and keep `settleMs` as the per-frame
figure it is, relabelled so no reader mistakes one for the other. Print both.

## MAJOR — `ZOOM_ARMS` prints N arms that are not criterion 4's or 8's arms

`apps/dev_harness_2d/lib/main.dart:526-541`.

`runInterleaved` (`measurement_rig.dart:918`) has **no production caller** — the
only references are its own doc comment and `test/interleaved_arms_test.dart` —
and neither `debugRestBakeDisabled` nor `debugFullViewportQuery` is set anywhere
outside the tile cache and its own test.

So an operator running `ZOOM_ARMS=9` gets **nine identical repetitions of the
rest arm**, printed as `R2 tile zoom arm 0..8`, with nothing in the transcript
naming which arm is which. That is the n=9 interleaved transcript criteria 4 and
8 call for — in shape and in label — with the flag never flipped and every ratio
reading **1.00**. That degenerate number landing in a document of record is
exactly what Ruling 14 was written to prevent.

**The controller's earlier instruction not to wire `runInterleaved` is
superseded by this finding. Wire it.** Requirements:

- A define selects the mode. Follow the harness's existing
  `String.fromEnvironment`-with-explicit-throw rule — the one `kZoomArms` and
  `kEntities` follow, and the one Plan 3c lost a device run to by not following.
- In interleaved mode, `runInterleaved` drives the two arms, flipping the
  relevant flag between them, and **every printed line names its arm** — which
  flag was set, and which criterion the arm belongs to. A transcript a reader
  cannot attribute is the failure mode here.
- Criterion 4's arms: rest bake enabled vs `debugRestBakeDisabled`.
  Criterion 8's arms: narrow vs `debugFullViewportQuery` (Plan **3h**'s M4 —
  say "3h's M4" in the label, because mutant numbering is per-plan and M4/M5
  collide between the 3h and 3i logs).
- **The plain `ZOOM_ARMS` path must stop being mistakable for an interleaved
  run.** Either relabel its output so no reader can read it as criterion 4's or
  8's arms, or make it refuse when the interleaved criteria are what was asked
  for. Your call — say which you chose and why.
- Each arm must leave the cache in a state the next arm can start from. This was
  investigated and settled: a zoom round trip leaves **no** warm tiles (the
  excursion's first zoom frame already fails `TileGrid.matchesScale`, the
  generation is retired and its tiles disposed, and the trip lands on scale
  `1.4000000000000017` rather than `1.4`), so **no state reset between arms is
  required**. See `test/tile_zoom_warmth_test.dart` in the other package and
  `warmth-report.md` in the ledger directory. Do not add a reset; do not remove
  the property either.

**Test the wiring** in `apps/dev_harness_2d/test/` — that interleaved mode
alternates arms, that the flag is actually flipped on the arm it names, and that
each arm's label is distinguishable. You cannot run the device, so test the
driver and the labelling, not the numbers.

## MINOR — a doc comment that tells the operator the wrong target

`measurement_rig.dart:730-733`. `ZoomReport.settleFrames`'s doc says "1 if the
very first idle frame after the gesture already covers, **which is what
criterion 3 asserts**".

Ruling 15 settles that correct code always reads **2**: the last gesture frame
changes the camera, so idle frame 1 can only reach `_restGateSteps == 1` and
takes the moving-frame early return; idle frame 2 is the first that can bake.
`tile_zoom_warmth_test.dart:186` pins `armA.settleFrames == 2`. As written, the
doc tells the operator that the correct value is the one only broken code can
produce. Correct it, and cite Ruling 15's arithmetic briefly so the next reader
does not "fix" it back.

---

## Gate — run every command and paste the real tail of each

```sh
cd apps/dev_harness_2d && CI=true flutter test --concurrency=1 && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter && CI=true flutter test
```

Baselines at HEAD `9206743`: `apps/dev_harness_2d` **23**, `packages/jet_cad_2d_flutter`
**405** with **1 skip**. The other package is run only to prove you did not break
it — a parallel wave owns it, so if it is red because of *their* in-flight
change, say so rather than fixing it.

Note: bare `flutter test` under default concurrency silently under-reports which
test *names* ran in `dev_harness_2d`; pass counts are correct. Use
`--concurrency=1` when the named files matter.

Commit in logical pieces, each green on its own.
