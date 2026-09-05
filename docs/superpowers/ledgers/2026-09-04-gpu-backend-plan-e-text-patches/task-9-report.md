# Task 9 report — the device run, criterion 11, the results note, and the resume point

**Status: DONE_WITH_CONCERNS.** Criterion 11 MISSES with a real, measured
number (not a threshold moved) and Task 9's own device run found a real
GPU-code defect on its first attempt, fixed within this task by the
controller/Task 6 loop before any criterion-11 number was recorded. Both
are reported, not smoothed over.

## Machine state

```
$ pmset -g | grep lowpowermode
 lowpowermode         0
$ flutter devices
Found 2 connected devices:
  macOS (desktop) • macos  • darwin-arm64   • macOS 26.5.1 25F80 darwin-arm64
  Chrome (web)    • chrome • web-javascript • Google Chrome 152.0.7977.82
```

Checked before the crashing first attempt and again before every rerun.

## The crash, and the fix

**First attempt (tree at `fda4e04`, before this task's fix), Run 1
(`SPIKE_TEXT=true`)** — collect+upload succeeded:

```
GSPIKE collect+upload: walk 7.5 ms, total 113.7 ms, instances=106852, buffer=6.79 MB, skippedOps=0, textOps=165 patches=87 subBuffer=0.27 MB patchTargets=1.77 MB classify=27.7 ms
```

Then the app crashed on arm C's very first frame:

```
-[AGXG15XFamilyCommandBuffer renderCommandEncoderWithDescriptor:]:967: failed assertion `A command encoder is already encoding to this command buffer'
Lost connection to device.
```

**Root cause, read from source, not guessed.** `GpuDrawBackend.render`
(`packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart`) created
one main `RenderPass` via `commandBuffer.createRenderPass(...)`, then — in
a loop over this corpus's 87 patches — created a SECOND (and Nth)
`RenderPass` on the SAME `CommandBuffer`, never ending the previous one.
Confirmed against the Flutter engine source
(`flutter/engine/.../impeller/renderer/backend/metal/render_pass_mtl.mm`):
`RenderPassMTL`'s constructor opens the live Metal encoder immediately
(`encoder_ = [buffer_ renderCommandEncoderWithDescriptor:desc_]`), and it
only closes via `OnEncodeCommands` (invoked once, when the owning
`CommandBuffer` is encoded) or native-peer GC finalization — neither
reachable between two `createRenderPass` calls inside one Dart frame. The
Dart `RenderPass` class (`flutter_gpu/lib/src/render_pass.dart`) exposes no
`end()`/`dispose()` at all. Metal refuses a second live encoder on one
command buffer outright — exactly the assertion above.

**Confirmed by isolation, not just by reading.** A control run
(`DRAW_TEXT=false`, so `patches=0` and only one render pass per frame)
completed cleanly on the SAME crashing tree — the crash is specific to the
patch-pass loop.

**Fixed at `4af35bf`** ("fix(gpu): one command buffer per render pass —
Metal refuses a second encoder on one buffer"), Ruling R6-3: one
`CommandBuffer` per render pass, each submitted immediately after its own
draw — the main pass now submits before the patch loop begins, and every
patch gets its own fresh `gpu.gpuContext.createCommandBuffer()`, submitted
right after that patch's `draw`. Free on the web shim (`CommandBuffer`
there is a no-op convenience wrapper per its own doc comment). This is
unreachable by any unit test — `render`'s own doc comment already said so
— and is exactly the class of defect a device run exists to catch that
mutation and differential testing cannot.

This was NOT patched by me — the controller routed it back through Task
6's implementer/reviewer loop (R6-3, fix round 3/5, re-reviewed
`aafbaacb34d295be0`) before handing Task 9 back with the fix landed.

## Both runs, redone on the fixed binary

Because the package code changed between the first (crashed) run 1 and the
first run 2, both were redone from the `4af35bf` tree so criterion 11's
difference is between two runs of the SAME binary. Verified before
redoing: `git log --oneline -1` → `4af35bf`; `pmset -g | grep lowpowermode`
→ `lowpowermode 0`; `pgrep -fl "dev_harness_2d|flutter run"` → empty.

**Method, both runs**: `cd apps/dev_harness_2d && flutter run -d macos
--profile ...` in the background, output to a scratchpad log, polled for
`GSPIKE done` under a 20-minute timeout (both landed well inside it —
first-run profile build plus 27 phase reports each), then `pkill -f
dev_harness_2d` and `pkill -f "flutter run"`, verified empty with `pgrep
-fl "dev_harness_2d|flutter run"` after every run, including the final one.

### Run 1 (text on) — verbatim collect+upload

```
GSPIKE collect+upload: walk 7.0 ms, total 36.5 ms, instances=106852, buffer=6.79 MB, skippedOps=0, textOps=165 patches=87 subBuffer=0.27 MB patchTargets=1.77 MB classify=27.4 ms
```

### Run 2 (control, `DRAW_TEXT=false`) — verbatim collect+upload

```
GSPIKE collect+upload: walk 7.0 ms, total 8.9 ms, instances=106852, buffer=6.52 MB, skippedOps=0, textOps=0 patches=0 subBuffer=0.00 MB patchTargets=0.00 MB classify=0.4 ms
```

### Arm C, per-repeat p50 (ms)

**Run 1:**

| repeat | hold build | hold raster | pan build | pan raster | zoom build | zoom raster |
|---|---|---|---|---|---|---|
| 1 | 0.05 | 3.38 | 2.53 | 3.30 | 2.27 | 2.95 |
| 2 | 0.03 | 2.89 | 2.46 | 3.15 | 2.17 | 2.92 |
| 3 | 0.04 | 3.00 | 2.57 | 2.88 | 2.19 | 2.94 |
| **median** | **0.04** | **3.00** | **2.53** | **3.15** | **2.19** | **2.94** |

**Run 2:**

| repeat | hold build | hold raster | pan build | pan raster | zoom build | zoom raster |
|---|---|---|---|---|---|---|
| 1 | 0.21 | 0.90 | 0.60 | 0.77 | 0.53 | 0.74 |
| 2 | 0.26 | 0.99 | 0.65 | 0.86 | 0.41 | 0.53 |
| 3 | 0.27 | 1.02 | 0.48 | 0.89 | 0.52 | 0.68 |
| **median** | **0.26** | **0.99** | **0.60** | **0.86** | **0.52** | **0.68** |

Patch counters (identical across all 3 repeats, both runs): Run 1 — hold
`87/0/0`, pan `87/0/0`, zoom `rendered=49 clipped=0 offscreen=38`. Run 2 —
`0/0/0` every phase.

Arm A (painter) and arm B (tiles), repeat 1 of Run 1, for context:

```
GSPIKE A painter (untiled) | hold | build p50=0.04 raster p50=4.58
GSPIKE A painter (untiled) | pan  | build p50=7.67 raster p50=3.57
GSPIKE A painter (untiled) | zoom | build p50=7.57 raster p50=5.47
GSPIKE B tiles (blit)      | hold | build p50=0.27 raster p50=1.14
GSPIKE B tiles (blit)      | pan  | build p50=0.47 raster p50=1.17
GSPIKE B tiles (blit)      | zoom | build p50=0.38 raster p50=0.97
```

## Criterion 11 — the computed table

| phase | Run 1, ms | Run 2, ms | **difference** | vs 0.5 ms |
|---|---|---|---|---|
| hold | 3.04 | 1.25 | **+1.79** | **MISS** |
| pan | 5.68 | 1.46 | **+4.22** | **MISS** |
| zoom (beside, not gated) | 5.13 | 1.20 | +3.93 | — |

**MISS.** `patches=87 ≥ 8` (that sub-condition passes); the timing does
not — roughly 3.6× and 8.4× over budget on hold and pan.

## Criterion 6 and criterion 7's share

- Criterion 6: `buffer + subBuffer` = 6.79 + 0.27 = **7.06 MB against 8 MB
  — PASS**, 0.94 MB margin. `patchTargets` (1.77 MB) is separate device
  texture memory, not counted in this budget, reported alongside.
- Criterion 7's share: `classify=27.4 ms` against the 16.67 ms rebuild
  budget — **164% of the budget from classification alone**, recorded as
  its share (not a pass), stacking on Plan C's already-recorded 115.0 ms
  rebuild MISS.

## The window — nineteen checks, none discharged

Plan E's five (labels drawn correctly; a `ROOM n` label's crossing stroke
visible over its glyphs, not over empty space differently from arm A;
panning keeps the patch aligned with no lag/seam; zoom keeps text sharp and
the stroke aligned; `DRAW_TEXT=false` shows no labels/patches) plus Plan
B's four, Plan C's five and Plan D's five — nineteen total, all still OWED.
No human looked at the window this session. Found and corrected in the
note: Task 7's two `.vscode/launch.json` entries for criterion 11 omit
`SPIKE_FILLS=true`, so as committed neither shows fills — same class of gap
Plan D's own results note found in that task's brief; not edited here
(outside this task's file list), corrected in the note's own command
instead.

## Gates, all three, fresh on the final tree

```
$ cd packages/jet_cad_2d_flutter && flutter test
00:07 +617 ~1: All tests passed!
$ flutter analyze
No issues found! (ran in 0.8s)
$ dart format --output=none --set-exit-if-changed .
Formatted 99 files (0 changed) in 0.15 seconds.
```

```
$ cd ../jet_cad_2d && dart test
00:02 +798: All tests passed!
$ dart analyze
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.14 seconds.
```

```
$ cd ../../apps/dev_harness_2d && flutter test --concurrency=1
00:13 +77: All tests passed!
$ flutter analyze
No issues found! (ran in 0.8s)
$ dart format --output=none --set-exit-if-changed .
Formatted 20 files (0 changed) in 0.04 seconds.
```

`git diff --stat main..HEAD -- packages/jet_cad_2d_flutter/shaders
packages/jet_cad_2d_flutter/assets` — empty (criterion 8 holds).

## Files changed (this task)

- Created `docs/superpowers/notes/2026-09-04-plan-e-results.md`.
- Created `docs/superpowers/notes/2026-09-04-plan-e-raw/run1-text-on.log`,
  `run2-draw-text-off.log` (post-fix, the numbers above) and
  `run1-text-on-CRASH-pre-fix.log` (crash evidence).
- Modified `STATUS.md` — "Resume here" opener rewritten for Plan E's state;
  new "## Plan E — text patches" section added before "## Plan C",
  mirroring Plan D's style.
- (Not this task's own commit, landed by the Task 6 loop this task's
  device run triggered:) `packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart`
  at `4af35bf` — the render-pass-per-command-buffer fix.

## Commit

`d5d7517` — "docs: Plan E's results, criterion 11's first number, and what
the window showed".

## Never left running

`pgrep -fl "dev_harness_2d|flutter run"` — empty, checked after every run
including the final one.
