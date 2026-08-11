# Plan 3b results — every 3a row re-measured, with dashes on

## Machine and builds

Apple M3 Pro, macOS 26.5.1, Flutter 3.44.9, Dart SDK 3.12.2. **Impeller**, the
macOS default in 3.44, unchanged from every other note in this plan.

- **R1/R3**: `flutter test --tags rig --run-skipped`, debug JIT,
  `PictureRecorder` — records without rasterising. **A relative regression
  signal only. Cannot see raster**, same caveat as 3a's own note.
- **R2/R4a/R4b**: `flutter drive --profile -d macos`, release-mode AOT on a
  real window, real raster.
- **Web**: `flutter test --tags rig --run-skipped --platform chrome`.

Corpus and cameras exactly as 3a's and this plan's other notes describe:
`generateDocument(N, definitionCount: 200, instanceCount: 20000, nestingDepth:
2, mirroredFraction: 0.1, nonUniformFraction: 0.2, groupCount: 50,
layerCount: 8, byBlockFraction: 0.3, dashedFraction: 0.35)`, whole-drawing and
working-set cameras.

### A confound in every `flutter drive` number below, found and not fixable in this session

`pmset -g` shows `lowpowermode 1` — **Low Power Mode is on, system-wide**, for
the entire duration of every `flutter drive` run in this task. `pmset -a
lowpowermode 0` and `pmset -c lowpowermode 0` both require root; `sudo` was
attempted and blocked by this session's own permission classifier, which is
correct — a global power setting is out of scope for a worktree-isolated task
and this session has no path to change it. It was not possible to turn off.

The evidence this is a real, GPU-specific throttle and not a general slow
machine: the **native R1/R3 rig**, re-measured mid-session, still lands within
1–2% of this plan's own earlier recordings (500k working set R1 paint
p50 = 58.158–58.233 ms here against Task 10's 59.192 ms). **`R4a`/`R4b`'s
command times — pure CPU, no window, no GPU — also match history closely**
(R4b 500k command p50 = 904.03 ms here against 3a's 957.98 ms, −5.6%; R4a
command p50 = 0.07 ms here against 3a's 0.10 ms). Only the numbers that
touch the real window — `R2`/`R4a`/`R4b`'s **build** and **raster** columns at
500,000 entities — are elevated, by roughly 4–12x over every prior recording
in this plan. That split (CPU-only paths unaffected, GPU/window paths
heavily affected) is consistent with Low Power Mode's known behaviour on
Apple Silicon, which caps GPU clocks harder than CPU, but this session did
not instrument the GPU directly to confirm the mechanism — it is named as the
best-supported candidate, not a proven cause.

Three mitigations were tried before accepting the numbers as measured:
retrying (four plain retries of the same 500k `RIG=pan` command, all either
stalled — see below — or, once they ran, landed at the same elevated
figure); `caffeinate -dimsu` (prevents sleep/App Nap-style throttling, and is
in fact what let the 500k runs complete at all — see the stall note below —
but did not change the elevated raster figure, reproduced twice: 753.47 ms
and 750.29 ms raster p50, back to back); and the `sudo pmset` attempt above.
**None of the three changed the 500k raster number.** The 50,000-entity runs,
by contrast, land close to this plan's own prior dashed measurements (Task
10's R4a: 126.60 ms; here, across all three rigs: 124.72–142.23 ms) — small
enough that either Low Power Mode doesn't bind at that workload size, or
today's number is simply consistent with a state Task 10 was already
measured in. Either way, **the 50k figures are corroborated by an earlier
session's numbers and the 500k figures are not corroborated by anything**,
so the two are given different weight in the sections below, and the raw
500k `flutter drive` numbers are reported with this caveat attached rather
than folded silently into a clean before/after story.

### The macOS `flutter drive` stall, again, and one addition to the operational note

Every plain 500k `RIG=pan` attempt in this task exceeded this environment's
own hard synchronous-execution ceiling (600 s, tighter than the 20-minute
budget this task was given to ask for) and was moved to the background by
the tool itself — exactly the "a tooling timeout reparents the command" case
the brief warns about. Four times, `ps -o pid,pcpu,time,etime,stat` on the
resulting `dev_harness_2d` process showed `0.0% CPU`, a `TIME` value that did
not move between two checks seconds apart, and `STAT=S` — frozen, not merely
slow, exactly as documented. `pkill -9 -f dev_harness_2d.app` and an
identical retry were used each time, per the existing operational note.

**Addition for next time:** the identical-retry recovery, as written, is
tuned for short rigs (R4a's single `RIG=leaf` run in Task 10). A run long
enough to approach this environment's own ~600 s synchronous ceiling — the
500k `RIG=pan`/`RIG=leaf`/`RIG=instance` runs here — kept re-hitting that
ceiling on plain retries. Prefixing the command with `caffeinate -dimsu` is
what let all three 500k runs finish; every 500k figure in this note was
captured that way. This does not explain or fix the Low Power Mode finding
above — it only stopped the *process* from freezing once backgrounded, which
is a separate failure mode from the *raster figures* being elevated.

## What 3b delivered

Batching was measured and refuted before anything else in this plan shipped:
[`2026-08-11-plan-3b-batch-spike.md`](2026-08-11-plan-3b-batch-spike.md) found
that the most call-collapsed mode was 2.7x *slower* to rasterise than one
`save`/`transform`/`restore` triple per leaf, and the plan's own pre-declared
stop clause fired. What actually shipped is narrower:
[Task 0](../../../.superpowers/sdd/2026-08-10-jet-cad-2d-plan-3b-batching-and-dashes/task-0-report.md)
deleted the cull floor and the style memo, both measured losses in 3a's own
note; [Task 1](../../../.superpowers/sdd/2026-08-10-jet-cad-2d-plan-3b-batching-and-dashes/task-1-report.md)
carries every line-like leaf into screen space unconditionally, replacing the
old anisotropy-gated bypass; and Tasks 6–9 add an engine-side dasher (screen
space for polylines, arc-window-aware for circles and arcs) with a
human-reviewed collapse floor. Between the spike and the profiling task that
followed it — [`2026-08-11-plan-3b-raster-profile.md`](2026-08-11-plan-3b-raster-profile.md)
— the plan also has an answer to what the unexplained 179 ms actually was:
leaf-count-bound GPU vertex work, not fragment fill and not draw-call
dispatch. This note is the measurement that follows all of that: every row
3a recorded, re-measured on the tree those four things produced, with dashes
switched on.

## Every 3a row, before and after

"Before" is 3a's results note, unchanged. "After" is this task, same corpus,
same cameras, dashes on. Ops/frame (`NullDrawSink.opCount`, three per leaf —
`beginResidual`, geometry, `endResidual`) is included because 3a used it as
its leaf-count proxy; it is unchanged by dashing, since dash spans are a
sink-level concern the op counter never sees (see "Canvas calls against
painter ops" below).

### R1 paint and R3 query-only (debug JIT, relative signal)

```
cd packages/jet_cad_2d_flutter && flutter test --tags rig --run-skipped
```

| Corpus | Camera | R1 paint p50/p95 — before → after | R3 query p50/p95 — before → after | ops/frame |
|---|---|---|---|---|
| 50k | whole drawing | 614.8/628.1 → 638.96/648.82 ms | 133.5/135.9 → 169.67/177.16 ms | 2,055,300 |
| 50k | working set | 3.11/3.20 → **23.46/23.98 ms** | 0.725/0.794 → 1.861/1.996 ms | 64,981 |
| 500k | whole drawing | 1090.7/1114.0 → 1124.05/1167.70 ms | 311.8/321.5 → 362.68/376.84 ms | 3,405,300 |
| 500k | working set | 6.34/6.76 → **58.16/60.03 ms** | 1.619/1.859 → 4.495/6.266 ms | 152,648 |

R1's working-set numbers move the most (50k: 7.5x; 500k: 9.2x) because the
working-set camera is where dashes actually render as dashes rather than
collapsing to solid (see "Dash spans and collapses" below) — every dash span
is extra work R1's `PictureRecorder` records, even though it never
rasterises. The whole-drawing camera moves far less because almost every
dashed entity there is below the collapse floor and drawn solid, same as
before dashing existed. Ops/frame is unchanged from 3a at every row —
confirms dash spans are counted separately, not folded into the existing
leaf-op counter.

### R2 pan and zoom (macOS profile)

```
cd apps/dev_harness_2d && flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=ENTITIES=<N> --dart-define=RIG=pan [--dart-define=STEPS=60]
```

| Corpus | build p50/p95/max — before → after | raster p50/p95/max — before → after |
|---|---|---|
| 50k | 5.48/5.90/294.93 → 20.65/22.24/279.62 ms | 78.29/88.41/902.60 → 124.72/139.30/847.99 ms |
| 500k | 10.69/11.52/1518.91 → **58.04/62.83/1357.59 ms** † | 182.73/194.42/2264.51 → **753.47/849.80/2222.69 ms** † |

† 500k, under the Low Power Mode confound described above. Reproduced almost
exactly on a second back-to-back run (build 58.16/62.84/1353.31, raster
750.29/849.67/2230.21). `screenSpaceLeafCount=4,679`, matching the
raster-profile note's own count for this camera exactly (that note predates
dashing). The 50k row is not flagged — it matches Task 10's own already-dashed
50k measurement closely, and the elevation there over 3a's *pre-dash* 78.29 ms
is discussed under "The dash cost" below.

### R4a — a leaf edit per frame

| Corpus (steps) | build p50 — before → after | raster p50 — before → after | command p50/p95/max — before → after |
|---|---|---|---|
| 50k (200) | 5.45 → 19.50 ms | 74.40 → 128.13 ms | 0.12/0.17/0.21 → 0.07/0.10/0.15 ms |
| 500k (60) | 10.67 → **56.24 ms** † | 176.36 → **711.31 ms** † | 0.10/0.15/0.19 → 0.07/0.09/0.10 ms |

| Corpus | overlay reached | rebuild threshold | rebuilds | handles burned — before → after |
|---|---|---|---|---|
| 50k | 1 | 2,340 | 0 | 201 → 201 |
| 500k | 1 | 24,840 | 0 | 201 → 61 (60 steps here, per this task's ambiguity resolution 3, against 3a's 200; the burn rate — one handle and one slot per step, plus the rig's initial add — is identical) |

Command time — pure CPU, no window — is unaffected by both dashing and the
Low Power Mode confound at every row, as expected: nothing about a leaf
remove-then-add touches the render path.

### R4b — an instance drag per frame

| Corpus (steps) | build p50 — before → after | raster p50 — before → after | command p50/p95 — before → after | rebuilds |
|---|---|---|---|---|
| 50k (200) | 5.35 → 21.91 ms | 79.47 → 142.23 ms | 115.84/120.88 → 105.57/109.70 ms | 200/200 → 200/200 |
| 500k (60) | 13.08 → **58.38 ms** † | 176.47 → **712.11 ms** † | 957.98/999.80 → 904.03/928.84 ms | 60/60 → 60/60 |

500k's command p50 (904.03 ms, a full `rebuildAll()`) sits within 5.6% of
3a's original 957.98 ms — the cleanest confirmation in this note that the
Low Power Mode confound is specific to the GPU/window path and not a general
slowdown of this machine: the single most expensive CPU-only operation this
plan measures reproduces almost exactly, in the same run where raster is 4x
elevated.

### The anisotropy bypass no longer exists in 3a's shape

3a's "leaves drawn / bypassed / anisotropic curves" table doesn't have a
literal after-row: Task 1 replaced the anisotropy-gated bypass for lines
entirely (every point, line and polyline now takes the screen-space path
unconditionally — see `docs/superpowers/notes/`'s Task 1 report), so "leaves
drawn" and "bypassed" are no longer the same quantity 3a measured. What
survives unchanged is curve counting — `anisotropicCurveCount`, still gated
by `kAnisotropyThreshold` exactly as before, since Task 1 never touched
circles or arcs:

| Corpus, working set | 3a anisotropic curves | this task's anisotropicCurveCount |
|---|---|---|
| 50k | 766 (21%) | 766 |
| 500k | 794 (11%) | 794 |

Exact match at both sizes, confirming the curve-side logic really is
byte-for-byte unchanged. `screenSpaceLeafCount` (1,970 at 50k, 4,295 at 500k
working set) is the renamed, redefined successor — see the two-notes-ago
report for why it isn't comparable to 3a's `bypassed` count.

### Text and dashes — 3a's two declared optimisms, one closed

Text: unchanged, confirmed rather than assumed — `skippedTextCount` is 300 on
both whole-drawing frames and 0/2 on the two working sets, identical to 3a.
**Still 0.06% of the corpus, still a floor** — Plan 3c is what closes this
one.

Dashes: **no longer an optimism.** 3a recorded that 35.0% of the corpus
carried a non-continuous linetype and every one of them drew solid. This
task's `dashSpanCount`/`collapsedDashCount` numbers (next section) show real
dash generation happening on both corpora, at both cameras, with the
collapse floor doing exactly what Task 9's review chose it to do.

### Web

```
cd packages/jet_cad_2d_flutter && flutter test --tags rig --run-skipped --platform chrome
```

| Corpus | Camera | R1 paint p50 — before → after | R3 query p50 — before → after |
|---|---|---|---|
| 50k | whole drawing | 7,667.6 → 8,194.9 ms | 2,124.6 → 2,423.7 ms |
| 50k | working set | 42.4 → **294.3 ms** | 11.4 → 21.2 ms |

50k working set is the one row that moves sharply (7.0x) — `dashSpans=55,240`
there, so dash generation is genuinely expensive on dart2js/CanvasKit, same
direction as the native rig's finding, larger magnitude. The whole-drawing
row barely moves (+6.9%, likely ordinary dev-compile variance) because
`dashSpans=0` there — everything is below the collapse floor at that zoom,
same as native.

**500,000 entities, whole drawing: aborts.** `RuntimeError: Aborted()` inside
`finishRecordingAsPicture`, reproduced twice independently — once inside the
full `--tags rig --run-skipped --platform chrome` suite run, once again in a
`--plain-name "paint and query at 500000"` isolated re-run — both times at
the same call site 3a originally recorded. It did not reproduce at the batch
spike's run
([`2026-08-11-plan-3b-batch-spike.md`](2026-08-11-plan-3b-batch-spike.md)).

**What is established, and what is not.** `git log 56b8ec3..bcbb0f5`
confirms the batch spike (Task 4, commit `56b8ec3`, including its web
re-check) predates every dash-related commit; `bcbb0f5` (Task 8) is the one
that first wires dashing into the painter — so the two runs really are two
different trees, and the spike's own numbers are correct for what they
measured. Dashing is the only substantive code change between those two
trees (every non-documentation commit in the range is dash work). That is as
far as the evidence goes, and it is not far enough to call dashing the
cause:

- **At this exact camera, dashing provably produces the same call
  sequence.** Real `Canvas` calls (`canvasCallCount`) came back
  **identical**, 1,134,900, in both the batch spike's dash-free `off` mode
  and this task's own dashed native re-measurement (see "Every 3a row"
  above). `Dasher.dashArc`'s (and the sink-level polyline dasher's) collapse
  check runs *before* any window/span computation, so a collapsed dashed
  entity at this zoom falls back to exactly the same single
  `sink.circle`/`sink.arc`/`sink.polyline` call the pre-dash code already
  issued — confirmed both by reading `dasher.dart` (the early-return sits
  ahead of `_dashArcWindow`) and by this measurement. `CanvasDrawSink` is
  shared Dart code across native and web, so the same call sequence should
  reach CanvasKit too. **A code path that provably produces an identical
  picture is a poor candidate for why that picture's fate changed** — this
  is an argument against dashing being the cause, not a caveat on it being
  the cause.
- **The environment was not held constant between the two runs.** They ran
  hours apart, in different sessions; this task's own session had Low Power
  Mode forced on (see "The dash cost" below) and whatever browser/WASM heap
  state each run started from is unknown. `RuntimeError: Aborted()` inside
  `finishRecordingAsPicture` is not self-evidently a deterministic op
  ceiling — a WASM allocation failure under memory pressure produces exactly
  this signature and would be load- and session-dependent, not
  code-dependent. That alternative explains both observations (spike:
  completed; this task: aborted) with **no code change involved**, and
  nothing in this task's evidence excludes it.

**The trigger is unknown.** What is established: the abort reproduced here,
twice, and did not at the spike's run, on two trees that differ by dashing
and nothing else substantive. What is not established: that dashing is why —
the one mechanism this task could check (call count) argues against it, and
an unexcluded environmental explanation accounts for both results without
any code being at fault. **What would settle it:** run both trees back to
back in one session, on one machine, in one state — a scratch worktree
checked out at `56b8ec3` (not a `git stash`, which would still share this
worktree's toolchain/build cache state) alongside this tree — and see
whether the abort tracks the tree or the session. Not attempted here; out of
this task's scope once the coordinator's fix round identified it.

`flutter build web --release` succeeds; `build/web` is 40 MB, matching 3a.

### Style memo, cull floor, dirty overlay: not re-measured, and why

The style memo and the cull floor were both deleted in Task 0, on the
measured losses 3a's own note recorded — there is no "after" to measure
because the mechanisms no longer exist. The dirty overlay's option C
(incremental rebuild, chosen in 3a section 10) is a document/index decision
independent of paint style; dashing changes what a frame draws, not how the
index decides when to repack, so it was not re-run — the brief's Step 1 does
not ask for `benchmark/overlay_fill.dart` here, and nothing in this task's
work touches the code that benchmark measures.

## The dash cost, stated as a number

**Reported dash cost: +59.4% (1.59x), at a 50,000-entity working set —
`RIG=pan`, raster p50 124.72 ms against 3a's pre-dash 78.29 ms.** Named at
this corpus size specifically, not at the 500,000-entity size 3a's own
headline used, because this is the cleaner of the two available
measurements: this task's own evidence (the reasoning is kept in full below)
says the 50k row is not touched by the Low Power Mode confound documented
above, while the 500k row is. This is the number to carry forward as "what
dashing costs," with its scope named rather than left implicit.

**The 500k row, for the record and not as the headline: raster p50 753.47
ms against the unbatched, pre-dash 179.63 ms baseline
([`2026-08-11-plan-3b-batch-spike.md`](2026-08-11-plan-3b-batch-spike.md)'s
`off` mode, measured after Tasks 0 and 1) is +319.5% (4.2x). This figure is
contaminated and is not a second, independent read of the same question —
it answers "what does dashing cost under Low Power Mode," not "what does
dashing cost."** The confound: `pmset -g` showed `lowpowermode 1` for this
entire session, and it could not be turned off (`sudo pmset` requires root
and this session's own permission classifier correctly refused it). The
evidence ruling out a general slow machine rather than a GPU-specific
throttle: in the very same 500k runs, R4b's command p50 (a full,
CPU-only `SpatialIndex.rebuildAll()`, no window, no GPU) came back 904.03
ms against 3a's original 957.98 ms — within 5.6%; the native, non-windowed
R1/R3 rig, re-measured mid-session, stayed within 1–2% of this plan's own
prior recordings; and R4a's command p50 (0.07 ms) matched 3a's 0.10 ms.
Only the numbers that touch the real window — build and raster at 500,000
entities specifically — are elevated, by 4–12x. Nothing in that pattern is
consistent with "the whole machine is just slower right now"; all of it is
consistent with a throttle that binds on the GPU/window path and does not
bind on pure CPU work, which is what Low Power Mode does on Apple Silicon.

**Neither number is presented as the answer to the other's question, and
they are not averaged.** The 50k figure is clean but is not the corpus size
3a's own 179.63 ms baseline — or Plan 3e's own interest — was measured at.
The 500k figure is at the size that matters and is the one the brief's
comparison baseline was built for, but it is not trustworthy as a
measurement of dashing alone. **A clean 500k figure is owed to whichever
plan needs it next: re-run `RIG=pan` at `ENTITIES=500000` on a machine
without Low Power Mode forced on.** This note does not have that machine.

Per the gate's demotion in this plan's own design doc, this cost ships
either way — there is no batching win left to weigh it against.

## Dash spans and collapses per frame

All three counters below (`dashSpanCount`, `collapsedDashCount`,
`canvasCallCount`) are **per-frame** as of this plan's Task 10 fix rounds —
each resets at the top of `DraftPainter.paint()` (the first two) or is
explicitly reset and re-forced to a genuine repaint before being read (the
third, which otherwise accumulates since the sink is built once at attach
time). None of the three is a running total in any table in this note.

Both cameras are available only from the native R1/R3 rig — `flutter
drive`'s R2/R4a/R4b always zoom to the working set before their measured
loop starts (see `boot()` in `frame_timing_test.dart`), so they only ever
report working-set counters.

| Corpus | Camera | dashSpanCount | collapsedDashCount |
|---|---|---|---|
| 50k | whole drawing | 0 | 239,475 |
| 50k | working set | 55,240 | 6 |
| 500k | whole drawing | 0 | 396,975 |
| 500k | working set | 134,027 | 17 |

Whole-drawing frames collapse essentially everything — at that zoom every
dashed entity's on-screen pattern period is below `kDashCollapsePx`, so
`dashSpanCount=0` at both sizes and the entire dashed population shows up as
collapsed instead. Working-set frames are the reverse: the collapse floor
catches only a handful of entities (6 and 17) and the rest render as real
dash spans, tens of thousands of them.

From `flutter drive`'s working-set-only rigs, for cross-reference against
the build/raster tables above (500k rows carry the same Low Power Mode
caveat as their build/raster figures — dash and collapse *counts* are pure
CPU/geometry, not timings, so they are not expected to be affected by it,
and the fact that R2/R4a/R4b's 500k dash-span counts below all sit within a
few percent of each other and of R1/R3's own 500k working-set count above is
consistent with that):

| Rig | Corpus | dashSpanCount | collapsedDashCount |
|---|---|---|---|
| R2 (pan) | 50k | 51,163 | 334 |
| R2 (pan) | 500k | 149,745 | 357 |
| R4a (leaf) | 50k | 46,511 | 292 |
| R4a (leaf) | 500k | 131,636 | 293 |
| R4b (instance) | 50k | 46,696 | 241 |
| R4b (instance) | 500k | 131,472 | 266 |

The three rigs disagree with each other and with R1/R3 by a few percent at
each size — expected, since each rig's camera has panned or zoomed by a
different amount by the time it reads the counters (R2 has panned 120 times
and zoomed 120 times; R4a has panned 200/60 times; R4b hasn't panned at
all), so each is looking at a slightly different piece of the drawing.

## The `kDashCollapsePx` sweep

Recorded here in full because no separate published note holds it — only
Task 9's own report and `dasher.dart`'s doc comment do, and the brief asks
for it to appear here rather than only be linked.

The corpus's dashed linetype is an 18-unit cycle (`dashes: [12.0, -6.0]`).
`Dasher` collapses to solid when `period * screenScale < kDashCollapsePx`,
i.e. below `F / 18` px/world-unit for candidate `F`:

| Candidate `F` | Threshold (px/world-unit) |
|---:|---:|
| 1.0 | 0.055556 |
| 2.0 | 0.111111 |
| 3.0 | 0.166667 |
| 4.0 | 0.222222 |
| 6.0 | 0.333333 |

`dash_ladder_golden_test.dart` fits five box sizes into a fixed 400×300
viewport, giving five fixed rendered scales:

| Rung | Rendered scale (px/unit) |
|---:|---:|
| 1 | 2.375000 |
| 2 | 0.950000 |
| 3 | 0.356250 |
| 4 | 0.118750 |
| 5 | 0.035625 |

Cross-referencing scale against threshold, only **rung 4** changes state
anywhere in the tested range (rungs 1, 2, 3 and 5 are dashed at every
candidate; confirmed independently by MD5-hashing every candidate's PNGs —
those four rungs are byte-identical across all five candidates):

| Rung | F=1 | F=2 | F=3 | F=4 | F=6 |
|---|---|---|---|---|---|
| 4 (0.11875) | dashed | dashed (6.9% margin) | **collapsed** | collapsed | collapsed |

**Chosen: `F = 3.0`.** A human reviewer opened `dash_ladder_4.png` at `F=2.0`
(not yet collapsed) and `F=3.0` (collapsed) side by side. At `F=2.0` the
pattern renders at a 2.14px cycle with a 0.71px gap — too small to draw as a
gap, so antialiasing smears it across the line instead of interrupting it:
the rules and the circle rendered as a **stippled grey texture**, visibly
lighter than their true lineweight. At `F=3.0` the same shapes render
**solid black, crisp, at the correct weight**. The reviewer's judgement
overrode the numeric candidate a pure code-level reading would have picked
(`F=2.0`, "the largest value at which rung 4 stays dashed") on the grounds
that staying dashed stops being the goal once the pattern is too small to
resolve — a technical drawing's lineweight carries meaning, and a
too-light line is a line telling the reader something false. This is
recorded as a judgement, not a derivation, per this plan's design doc's own
framing of the risk it addresses.

Performance was measured before the review, at 500k working-set (debug
JIT): flat at 57–58 ms `min` through F=1–4 (`collapsedDashCount` 0, 0, 17, 52
— negligible next to ~134k spans and ~5,000 leaves), a real ~10% drop only at
F=6 (collapsedDashCount 266, dashSpanCount down 8.6%). **The chosen value,
3.0, sits inside the flat region — it cost nothing measurable over the
numeric candidate the arithmetic alone would have picked.** The floor exists
for legibility, not for the frame budget.

## Canvas calls against painter ops — a diagnostic, not a target

The batch spike established that collapsing this ratio makes the frame
*slower*, not faster (`bucketMapBakedCurves`: 10 canvas calls, 2.7x the
raster time of `off`'s 7,009). What follows is reported for the same reason
3a reported ops/frame in the first place — a number worth having on record —
not because a lower ratio is a goal.

| Corpus | Camera | ops/frame (painter, ×3/leaf) | canvasCallCount (real `Canvas` calls) | dashSpanCount |
|---|---|---|---|---|
| 50k | whole drawing | 2,055,300 | 684,900 | 0 |
| 50k | working set | 64,981 | 57,637 | 55,240 |
| 500k | whole drawing | 3,405,300 | 1,134,900 | 0 |
| 500k | working set | 152,648 | 138,626 | 134,027 |

Whole-drawing rows land at exactly ops/3 = canvasCallCount (684,900 =
2,055,300/3; 1,134,900 = 3,405,300/3) — every dashed entity collapses to one
solid draw there, so nothing multiplies. Working-set rows do not:
`canvasCallCount` exceeds `ops/3` (21,660 → 57,637 at 50k; 50,883 → 138,626 at
500k) by almost exactly `dashSpanCount`, because **the painter's op counter
is a sink-agnostic geometry-call count and never sees a dash span** — dash
generation happens inside `CanvasDrawSink`, downstream of the single
`DrawSink.polyline`/`.circle`/`.arc` call the painter issues. One dashed
polyline is one painter op and dozens of real `Canvas.drawPath` calls, all
invisible to `NullDrawSink.opCount`. This is the same mechanism the batch
spike's record/raster split already described in the other direction
(fewer canvas calls, more expensive raster) — dashing moves the ratio the
opposite way (more canvas calls) for an unrelated reason, and the spike's
own finding says this direction isn't free either, just for a different
reason (real per-span GPU work, not joint-path tessellation).

## Web: the whole-drawing frame

Covered above under "Web." Restated here only because the brief calls it out
as its own item: **the 500,000-entity whole-drawing frame aborts CanvasKit,
reproduced twice this task**, on the same finished, dashed tree; it did not
abort at [`2026-08-11-plan-3b-batch-spike.md`](2026-08-11-plan-3b-batch-spike.md)'s
earlier run, on a tree with nothing dashed yet (`git log 56b8ec3..bcbb0f5`
confirms the ordering). **What that establishes is narrower than "dashing
did it":** at this camera, dashing provably produces the same `Canvas` call
sequence as the pre-dash code (see "Web" above), and the two runs'
environments — hours apart, different sessions, this one with Low Power Mode
forced on — were never controlled to be the same. `RuntimeError: Aborted()`
inside `finishRecordingAsPicture` is consistent with a WASM allocation
failure under memory pressure, which would track the session rather than the
tree. **3a's results note item 5 is observed again, not re-established** —
the abort is real and reproduced, but its trigger is unknown, and this task
did not rule out an environmental cause that would make dashing irrelevant
to it. `docs/superpowers/specs/2026-08-10-jet-cad-2d-plan-3b-design.md` and
the batch spike note have both been corrected to the same open status.

## What this says about Plans 3c, 3d and 3e

**3c (text).** `skippedTextCount` is unchanged from 3a — 300 entities per
whole-drawing frame at both sizes, 0.06% of the corpus, still a floor. This
task adds nothing new here; it only confirms the floor didn't move.

**3d (fills).** The design doc's "flush contract" — the promise that a fill
would flush 3b's open draw buckets before it draws and open new ones after —
has nothing to attach to. Batching was reverted; there are no buckets.
**3d inherits no mechanism from 3b, only the ordinary one-call-per-primitive
`CanvasDrawSink` this task measured throughout.** Naming this now so a
future 3d task doesn't go looking for a caller-side hook that doesn't exist.

**3e (the definition/tile picture cache).** The raster-profile note already
answered the load-bearing question — the dominant cost is leaf-count-bound
GPU vertex work, not fragment fill, not draw-call dispatch — and said a
cache that reduces leaves walked and re-tessellated per frame is on the
table. This task adds three things to that picture:

1. **Dashing makes the leaf-count story stronger, not weaker.** Dashes
   multiply real `Canvas` calls (and, on the raster-profile note's own
   reading, the GPU vertex work behind them) per leaf without moving the
   painter's op count at all — one dashed polyline becomes dozens of drawn
   spans. A cache that amortises per-leaf tessellation has a bigger prize to
   claim now than when the raster-profile note was written, since dashed
   leaves are more expensive to re-walk than the note's own (undashed)
   measurements assumed.
2. **A cached definition picture is not scale-invariant the way it was before
   dashing existed.** Dash phase and the collapse floor are both functions
   of screen-space scale (`period * screenScale`). A solid stroke's `Picture`
   can be reused across zoom levels by re-transforming it; a dashed one
   cannot — zoom far enough and entities the cache baked in as dashed need to
   render solid instead (or vice versa), which is a real invalidation axis
   3e's design doesn't yet have a name for. This task did not design that
   axis; it is naming that it exists.
3. **The web whole-drawing abort is observed again, and its trigger is
   unknown.** This task's reproduction is real, and the commit-range check
   confirms the batch spike's non-abort measured a tree with nothing
   dashed. But this task's own numbers argue against dashing as the
   mechanism: a collapsed dashed picture has the *same* real `Canvas` call
   count as a non-dashed one at this camera (1,134,900, both trees), and the
   two runs' environments were never controlled to be the same session. A
   memory- or session-dependent CanvasKit failure is an unexcluded
   alternative that explains both results with no code at fault. **3e should
   not design against a fixed op-count ceiling on the strength of this
   task's evidence** — that would be designing against a specific cause
   this task did not establish. What 3e is owed instead is the back-to-back,
   same-session re-run described above, which would show whether the abort
   tracks the tree or the session before anyone designs around either
   answer.

## Verification

```
$ cd packages/jet_cad_2d && dart test
00:02 +667: All tests passed!
$ cd packages/jet_cad_2d && dart format --output=none --set-exit-if-changed . && dart analyze
Formatted 97 files (0 changed)
No issues found!

$ cd packages/jet_cad_2d_flutter && flutter test
00:02 +123 ~1: All tests passed!
$ cd packages/jet_cad_2d_flutter && flutter test --tags golden
00:02 +8: All tests passed!
$ cd packages/jet_cad_2d_flutter && dart format --output=none --set-exit-if-changed . && flutter analyze
Formatted 27 files (0 changed)
No issues found!

$ cd apps/dev_harness_2d && dart format --output=none --set-exit-if-changed . && flutter analyze
Formatted 3 files (0 changed)
No issues found!

$ git status --short
(clean before this note's own commit)
```

`packages/jet_cad_2d/benchmark/query_throughput.dart`, re-run unchanged so
Plan 2's gate row stays current: **GATE: PASS** — every gated row (count =
500,000: `forEachInRect`/`pick`/`snap`, fresh and at the dirty-overlay
rebuild threshold) under its threshold, values unchanged in shape from this
plan's earlier runs.

Full verbatim command transcripts, every retry and why, and the process of
finding the Low Power Mode confound are in this task's own report,
`task-12-report.md`, alongside the other tasks' reports in this plan's
`.superpowers/sdd/` directory.
