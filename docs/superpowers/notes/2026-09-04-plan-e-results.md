# Plan E — text patches: results

**Plan:** [2026-09-04-gpu-backend-plan-e-text-patches.md](../plans/2026-09-04-gpu-backend-plan-e-text-patches.md).
**Spec:** [2026-08-29-gpu-resident-render-backend-design.md](../specs/2026-08-29-gpu-resident-render-backend-design.md)
(revision 5, `d2095e7`), the "Text: one render target, and a patch where
later geometry covers a label" section.
**Mutation log:** [plan-e-mutation-log.md](plan-e-mutation-log.md).
**Branch:** `plan-e/text-patches`, cut from `main` at `8dde4fb`. **Nine
tasks done, `8dde4fb..4af35bf`, not yet merged.**
**Ledger (per-task briefs, reports, review diffs, ten rulings):**
[.superpowers/sdd/2026-09-04-gpu-backend-plan-e-text-patches/](../../.superpowers/sdd/2026-09-04-gpu-backend-plan-e-text-patches/)
(git-ignored; archive it onto the branch before the workspace is deleted,
per every earlier plan's own recorded lesson).
**Raw device logs:** [2026-09-04-plan-e-raw/](2026-09-04-plan-e-raw/) —
`run1-text-on.log`, `run2-draw-text-off.log` (both post-fix, the runs this
note's numbers are taken from) and `run1-text-on-CRASH-pre-fix.log` (the
crash this task's own first attempt found, kept as evidence).

**What Plan E shipped**: the resident text list (Task 1: six floats flat,
string, style, resolved argb, instance index, the four-corner padded box);
`classifyTextPatches` — per-kind reach, the miter bound, the band floor,
the sub-buffer as a by-product (Task 2); the corpus's covered/grazed/clear
labels (Task 3); `TextCompositor` — one paragraph helper with the baseline
flip, `srcATop` (Task 4); the composited differential and the order gate,
seeing text for the first time (Task 5); `ResidentGeometry`'s patch
targets and sub-buffers, and `GpuDrawBackend.paint`'s main pass plus one
patch pass per covered label, composited (Task 6); the harness corpus
grows deliberate `ROOM n` labels a later stroke covers, by construction
(Task 7); fourteen mutations, 14/14 killed (Task 8); this task — the
device run, criterion 11's first number, and the window-check ledger.

---

## What this plan's own premises measured false

Five corrections, one of them a defect this task's own device run exists
to find and none of them a threshold moved:

1. **This task's own first device run crashed on arm C's very first
   frame** with a real GPU code path executing for the first time —
   exactly what Task 9 exists to find. Verbatim:

   ```
   -[AGXG15XFamilyCommandBuffer renderCommandEncoderWithDescriptor:]:967: failed assertion `A command encoder is already encoding to this command buffer'
   Lost connection to device.
   ```

   `GpuDrawBackend.render` (`gpu_draw_backend.dart`) opened one main
   `RenderPass` on a `CommandBuffer`, then — for each of this corpus's 87
   patches — a SECOND (and third, and…) `RenderPass` on the SAME
   `CommandBuffer`, never ending the previous one. `flutter_gpu`'s
   `RenderPassMTL` opens its live Metal encoder in its native
   *constructor* (`[buffer_ renderCommandEncoderWithDescriptor:desc_]`,
   confirmed by reading `render_pass_mtl.mm`) and the Dart `RenderPass`
   class exposes no `end()`/`dispose()` at all — the encoder closes only
   via `OnEncodeCommands` (once per `CommandBuffer`) or GC finalization of
   the native peer, neither reachable between two `createRenderPass` calls
   in one Dart frame. Metal refuses a second live encoder on one command
   buffer outright. The control run (`DRAW_TEXT=false`, `patches=0`, one
   render pass per frame) completed cleanly on the SAME crashing tree,
   isolating the defect to the patch-pass loop specifically. **Fixed at
   `4af35bf`, Ruling R6-3: one `CommandBuffer` per render pass, each
   submitted immediately after its own draw** — the main pass now submits
   before the patch loop begins, and every patch gets its own fresh
   `CommandBuffer`, submitted right after that patch's `draw`. Free on the
   web shim (`CommandBuffer` there is a no-op convenience wrapper). This
   was unreachable by any unit test in the suite — `render`'s own doc
   comment already said so ("`render` cannot run without a GPU, so this is
   the one call site nothing in `flutter test` can reach directly") — and
   is exactly the class of defect this project's third instrument (a
   device run) exists to catch that mutation and differential testing
   cannot.
2. Task 7's brief specified the harness corpus's `_textCount == 0` check
   at `SPIKE_TEXT`'s default as an achievable assertion; `generateDocument`
   adds roughly 16 baseline empty-string text entities unconditionally, so
   that literal check was impossible. Rewritten as default-vs-explicit-false.
3. Task 5's anti-vacuity floor of `referenceInk > 5000` was calibrated on
   the scale-1 picture; at scale 0.5 the same corpus is a quarter of the
   area and 2,383 inked pixels is not vacuous. Ruling R5-1 moved the
   `> 5000` floor to the scale-1 LOD-on row (where it was calibrated) and
   set the four-scale rows to `> 1000`.
4. Task 6's brief specified `setScissor` on the patch pass (Ruling E8's
   letter); `flutter_scene`'s web `RenderPass` has no such method at all.
   Ruling R6-1 dropped it — the pass's own `Viewport` already bounds the
   draw at the NDC clip stage, upstream of any per-fragment scissor test —
   rather than shipping a `NoSuchMethodError` for whichever plan first
   targets web.
5. Task 6's first review round found `_collectionToLogical`, `_patchImages`
   and the frame counters were reset only AFTER `render`'s early return, so
   a zero-instance document drew text at the identity transform and
   composited stale patches from a prior document. Fixed by hoisting every
   per-frame reset above both early returns.

**One thing measured, not corrected, because the plan named the correct
response in advance**: the `patches.length >= kPatchedLabelCount` harness
assertion passes without `_addPatchedLabels` running at all — 29 incidental
patches from the corpus's own vocabulary labels sit above the threshold of
8 on their own, so the raw count alone proves nothing about the eight
deliberate labels. Ruling R7-1 added the construction-level assertion
(every `'ROOM '`-prefixed label is a patch, exactly `kPatchedLabelCount` of
them) that a mutation deleting `_addPatchedLabels` turns red
(`Expected <8> Actual <0>`), keeping the raw-count assertion only as a
floor.

---

## What was measured in `flutter test` (Tasks 3–8, carried forward)

Not re-run for this task — these are Tasks 3, 5, 7 and 8's own measurements,
part of the ledger this note is required to report:

| quantity | value |
|---|---|
| `strokeInkInsideLabel` overlap guard (Task 3) | COVERED 903/901=484, 900/901=486, GRAZED 922/921=603, CLEAR hairline=0 — the isolated-paint guard truly alone (Ruling R3-1) |
| composited agreement, four band scales + LOD-on (Task 5) | **1.0 (100%) at all five rows** — `referenceInk` 2,383 / 5,128 / 11,071 / 21,891 (scales 0.5/0.8/1.25/2.0) and 7,398 (LOD-on), all above their row's own anti-vacuity floor (Ruling R5-1) |
| order gate, no patches (Task 5) | agreement **0.8723 (87.23%)**, `overEight = 941` — well below the 99.5% gate and the 200-pixel gate, proving order is load-bearing |
| `patchCount` on the fixture (Task 5) | **2** (COVERED, GRAZED), never 4 — criterion 3 |
| mutations (Task 8) | **14 of 14 fired, 14 of 14 killed on the first shot, zero survivors** |

Full transcripts: Task 5's own report in the ledger; mutation transcripts in
[plan-e-mutation-log.md](plan-e-mutation-log.md).

---

## The device run

**Method**: `apps/dev_harness_2d`, `flutter run -d macos --profile`, three
interleaved repeats (`SPIKE_REPEATS=3`, arms A/B/C run in turn within each
repeat — `runGpuSpike`'s own loop order), macOS Low Power Mode confirmed OFF
twice — once before the crashing first attempt, again before the post-fix
reruns (`pmset -g | grep lowpowermode` →
`lowpowermode 0` both times) — and `flutter devices` listed `macOS
(desktop)`. **`flutter run` does not exit on its own** (Plan B's own
lesson): each invocation ran in the background with output captured to a
log, polled for the `GSPIKE done` marker under a 20-minute timeout, then
`pkill -f dev_harness_2d` and `pkill -f "flutter run"` — verified with
`pgrep -fl "dev_harness_2d|flutter run"` after every run, this task's
included.

**Two attempts.** The first attempt (tree at `fda4e04`, before the fix)
crashed on arm C's first frame — see "What this plan's own premises
measured false" §1, and the raw log is kept at
`2026-09-04-plan-e-raw/run1-text-on-CRASH-pre-fix.log`. After the fix landed
at `4af35bf`, **both runs were redone from that tree** — the numbers below
are two runs of the SAME binary, which criterion 11's difference requires;
the crashed attempt's collect+upload line (`classify=27.7 ms`, cold) is
consistent with the rerun's `classify=27.4 ms` and is not used for any
gated number.

Command (Run 1, text on):

```sh
cd apps/dev_harness_2d
flutter run -d macos --profile --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 --dart-define=SPIKE_DEFS=20 \
  --dart-define=SPIKE_INSTANCES=150 --dart-define=SPIKE_FRAMES=30 \
  --dart-define=SPIKE_REPEATS=3 --dart-define=SPIKE_FILLS=true \
  --dart-define=SPIKE_TEXT=true
```

Run 2 (control): the same plus `--dart-define=DRAW_TEXT=false`.

### Collect+upload (Run 1, text on, post-fix)

```
GSPIKE collect+upload: walk 7.0 ms, total 36.5 ms, instances=106852, buffer=6.79 MB, skippedOps=0, textOps=165 patches=87 subBuffer=0.27 MB patchTargets=1.77 MB classify=27.4 ms
```

`instances=106852`, `skippedOps=0` — criterion 4 holds on this corpus too.
`textOps=165` labels, of which **`patches=87`** are covered by later
geometry — well above criterion 11's `patches ≥ 8` floor.

### Collect+upload (Run 2, control, post-fix)

```
GSPIKE collect+upload: walk 7.0 ms, total 8.9 ms, instances=106852, buffer=6.52 MB, skippedOps=0, textOps=0 patches=0 subBuffer=0.00 MB patchTargets=0.00 MB classify=0.4 ms
```

Same `instances=106852` (draw geometry is identical; `DRAW_TEXT=false`
suppresses only text ops), `buffer` reads 0.27 MB smaller — the resident
text list's own storage for 165 labels, absent when the painter emits none.

### Arm C, per-repeat p50 (ms), both runs

**Run 1 (text on):**

| repeat | hold build | hold raster | pan build | pan raster | zoom build | zoom raster |
|---|---|---|---|---|---|---|
| 1 | 0.05 | 3.38 | 2.53 | 3.30 | 2.27 | 2.95 |
| 2 | 0.03 | 2.89 | 2.46 | 3.15 | 2.17 | 2.92 |
| 3 | 0.04 | 3.00 | 2.57 | 2.88 | 2.19 | 2.94 |
| **median** | **0.04** | **3.00** | **2.53** | **3.15** | **2.19** | **2.94** |

**Run 2 (control):**

| repeat | hold build | hold raster | pan build | pan raster | zoom build | zoom raster |
|---|---|---|---|---|---|---|
| 1 | 0.21 | 0.90 | 0.60 | 0.77 | 0.53 | 0.74 |
| 2 | 0.26 | 0.99 | 0.65 | 0.86 | 0.41 | 0.53 |
| 3 | 0.27 | 1.02 | 0.48 | 0.89 | 0.52 | 0.68 |
| **median** | **0.26** | **0.99** | **0.60** | **0.86** | **0.52** | **0.68** |

Patch counters, read after each phase's last frame (identical across all
three repeats in both runs — the phase always restarts from the same base
camera): Run 1 — hold `rendered=87 clipped=0 offscreen=0`; pan `87/0/0`;
zoom `rendered=49 clipped=0 offscreen=38` (the zoomed-in camera at the end
of 30× 1.02 steps carries 38 of the 87 covered labels off the collection
viewport). Run 2 — `0/0/0` on every phase, every repeat.

Arm A (painter, untiled) and arm B (tiles, blit) — recorded for context,
the budgets criterion 11's ≤ 0.5 ms was set against, repeat 1 of Run 1:

```
GSPIKE A painter (untiled) | hold | build  p50=0.04 ... | raster p50=4.58 ...
GSPIKE A painter (untiled) | pan  | build  p50=7.67 ... | raster p50=3.57 ...
GSPIKE A painter (untiled) | zoom | build  p50=7.57 ... | raster p50=5.47 ...
GSPIKE B tiles (blit)      | hold | build  p50=0.27 ... | raster p50=1.14 ...
GSPIKE B tiles (blit)      | pan  | build  p50=0.47 ... | raster p50=1.17 ...
GSPIKE B tiles (blit)      | zoom | build  p50=0.38 ... | raster p50=0.97 ...
```

Full per-repeat lines for every arm: the raw logs.

### Criterion 11 — the computed difference table

Per phase: median of the three per-repeat p50s (build and raster
separately), summed, then Run 1 − Run 2:

| phase | Run 1 (text on), ms | Run 2 (control), ms | **difference** | vs. 0.5 ms |
|---|---|---|---|---|
| hold | 0.04 + 3.00 = 3.04 | 0.26 + 0.99 = 1.25 | **+1.79** | **MISS** |
| pan | 2.53 + 3.15 = 5.68 | 0.60 + 0.86 = 1.46 | **+4.22** | **MISS** |
| zoom (reported beside, not gated) | 2.19 + 2.94 = 5.13 | 0.52 + 0.68 = 1.20 | +3.93 | — |

**Criterion 11: MISS.** Drawing text through the compositor — the main
pass's per-frame uniform plus, on hold and pan, 87 patch passes each on
its own command buffer — costs **1.79 ms on hold and 4.22 ms on pan**
against the ≤ 0.5 ms budget, roughly **3.6×** and **8.4×** over. The
`patches ≥ 8` sub-condition passes (87); the timing does not. Zoom's +3.93
ms sits in between hold's and pan's, consistent with 49–87 patch passes
running on every frame of that phase too (`gpu submits=30 of 30` on arm C
throughout — every phase, including hold, submits a GPU frame here because
`_addPatchedLabels`' baseline labels make the very first post-switch frame
already differ from the prior arm's picture; a genuinely unchanging camera
after that submits nothing, which is why `submits=0 of 30` appears on
`hold` specifically once the arm has already painted once).

**Not a threshold moved.** The 87-patch corpus is not the eight deliberate
labels alone (Task 7's own finding: 29 incidental patches from vocabulary
labels, now 87 at this task's corpus size); a corpus at the spec's own
lower bound would cost less, but this run measures what
`--dart-define=SPIKE_INSTANCES=150` actually produces, which is the number
this note reports.

---

## Criterion 6 — the resident buffer, measured on the device

`buffer` (6.79 MB) + `subBuffer` (0.27 MB) = **7.06 MB against the 8 MB
budget — PASS**, 0.94 MB margin. Against Plan D's matched-parameter figure
(6.51 MB, fills and strokes, no text): text's 165 resident labels plus 87
patch sub-buffers add **0.55 MB**. `patchTargets` (1.77 MB) is device
texture memory for the patch render targets themselves — real GPU memory,
not counted in the spec's 8 MB buffer budget, reported here as its own
line rather than folded silently into the PASS above.

## Criterion 7's share — `classify` against the rebuild budget

`classify=27.4 ms` against the **16.67 ms** per-frame rebuild budget:
**classification alone consumes 164% of the entire budget**, before the
walk or the upload. This is recorded as its share, not as a pass —
criterion 7 is not a Plan E gate criterion on its own. It adds to Plan C's
already-recorded rebuild MISS (115.0 ms against 16.67 ms); this session's
own collect+upload `total` (walk + classify + upload) read 36.5 ms warm on
the successful rerun and 113.7 ms on the crashed first attempt's single
cold call — consistent with Plan B's cold-pipeline-creation hypothesis for
a process's first GPU call, reported here as an observation, not a new
measurement of that hypothesis.

---

## The window — eighteen of nineteen checks discharged 2026-09-05, one still OWED

**A human looked at the running window on 2026-09-05** — the eyeball run
below, on `main` at `b5b6131` (Plan E merged), macOS profile, three
interleaved repeats, `GSPIKE done: 27 phase reports`, no crash. The
`collect+upload` line read `instances=106852, buffer=6.80 MB,
skippedOps=0, textOps=165 patches=87 subBuffer=0.28 MB patchTargets=1.77
MB classify=27.7 ms`; arm C reported `patches rendered=87 clipped=0
offscreen=0` on hold and pan and `rendered=49 offscreen=38` on zoom, all
three repeats. Log:
[2026-09-04-plan-e-raw/eyeball-text-run.log](2026-09-04-plan-e-raw/eyeball-text-run.log).

```sh
cd apps/dev_harness_2d
flutter run -d macos --profile --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 --dart-define=SPIKE_DEFS=20 \
  --dart-define=SPIKE_INSTANCES=150 --dart-define=SPIKE_FRAMES=30 \
  --dart-define=SPIKE_REPEATS=3 --dart-define=SPIKE_FILLS=true \
  --dart-define=SPIKE_FILL_SCALE=20 --dart-define=SPIKE_TEXT=true
```

**How the verdict was taken, exactly.** The nineteen checks were put to
the human as an enumerated list (Plan E's five, Plan D's five, Plan C's
five, Plan B's four, each in its own words, one verdict asked per item:
yes / no / could not see). After looking, the human was offered two
recordings — "all nineteen seen, no problem" or "name the exceptions" —
and chose the first. **This is a blanket verdict over an enumerated list,
not eighteen separately spoken sentences**, and is recorded as that: every
item below was in front of the human when the answer was given, no item
was reported failed, and no item was reported unseen. It is stronger than
2026-09-01's "the drawing looks right" (which had no list in front of it),
and weaker than an item-by-item transcript would be.

**Check 5 is excluded from the verdict and stays OWED**: it needs a
`DRAW_TEXT=false` run of the same corpus, and that run did not happen on
2026-09-05. The human could not have seen it. Eighteen discharged, one
owed.

`SPIKE_FILL_SCALE=20` was on, as Plan D's note requires for the eye — the
timings in this run are therefore not comparable to any recorded number and
none was taken from it.

### Plan E's five — four discharged, one OWED

1. Labels are **drawn**, right way up, at the size and place arm A draws
   them. — **seen, no problem reported** (2026-09-05)
2. A `ROOM n` label's crossing stroke is visible **over** its glyphs — and
   the same stroke is **not** drawn over the empty space beside the glyphs
   any differently from arm A. — **seen, no problem reported** (2026-09-05)
3. Panning keeps the patched stroke over the label with no lag and no seam
   at the label's box edge. — **seen, no problem reported** (2026-09-05)
4. Zooming in to 2× and out to 0.5× keeps the label sharp (it is a
   paragraph, not a bitmap) and the stroke over it at every step. — **seen,
   no problem reported** (2026-09-05)
5. `DRAW_TEXT=false` shows the same drawing with no labels and no patches.
   — **OWED**: the control run was not made on 2026-09-05. Command: the one
   above with `--dart-define=DRAW_TEXT=false` appended (also in
   `.vscode/launch.json` as *"2d: GPU spike — text ON, DRAW_TEXT=false
   (criterion 11 control)"*).

### Plan D's five, Plan C's five and Plan B's four — discharged 2026-09-05

All fourteen were on the same list, in the same run, under the same blanket
verdict: seen, no problem reported. Listed in full in STATUS.md's "Resume
here" and in each plan's own results note, which now carry the pointer
back here. Plan D's five were made at `SPIKE_FILL_SCALE=20`, the only
scale at which they can be made (Plan D's note explains why).

**A `.vscode/launch.json` inconsistency, found while assembling this
section, corrected here rather than repeated uncorrected**: Task 7 added
two launch entries — *"2d: GPU spike — text ON (criterion 11,
DRAW_TEXT=true)"* and *"2d: GPU spike — text ON, DRAW_TEXT=false (criterion
11 control)"* — and neither passes `SPIKE_FILLS=true`. Run exactly as
committed, both entries draw the corpus's rooms as boundary-only (no
fills), so Plan D's five checks would have nothing to look at through
either launch entry — the same gap Plan D's own results note found in that
task's brief. **Use this note's command above (or add
`--dart-define=SPIKE_FILLS=true` to `toolArgs` in both entries) to look at
all nineteen checks in one run.** Not fixed in `.vscode/launch.json` here,
per the same reasoning Plan D's note gave: correcting the command in the
note that is actually read is enough, and editing a config file is outside
this task's own file list.

---

## Mutation summary

**14 of 14 pre-committed mutations fired; 14 of 14 killed on the first
shot; zero survivors.** Full transcripts:
[plan-e-mutation-log.md](plan-e-mutation-log.md).

| id | what it mutates | verdict |
|---|---|---|
| M-E1 | `classifyTextPatches` returns `[]` (source edit) | KILLED |
| M-E2 | inner loop starts at `0` instead of `t.instanceIndex` | KILLED |
| M-E3 | `reachDevice = 0` for every kind | KILLED |
| M-E4 | `unitsPerDevicePixel` drops `bandLowerScale` | KILLED |
| M-E5 | patch paint blend mode `srcOver` instead of `srcATop` | KILLED |
| M-E6 | `hits.add(i)` unconditionally | KILLED |
| M-E7 | join reach `half` instead of `half * kMiterLimit` | KILLED |
| M-E8 | `points = 3` for a point | KILLED |
| M-E9 | `saveLayer` opened after `canvas.transform` | KILLED |
| M-E10 | baseline flip dropped in `_drawLabel` | KILLED |
| M-E11 | box pad at the band ceiling instead of the floor | KILLED |
| M-E12 | compositor matches patches by position, not `textIndex` | KILLED |
| M-E13 | `patchRegionFor` clamp unclamped | KILLED |
| M-E14 | sub-buffer copy reversed | KILLED |

---

## Exit gate

| # | criterion | verdict |
|---|---|---|
| 1 | composited differential, text corpus, four band scales | **PASS** — 100% agreement at all five rows (Task 5) |
| 2 | the order gate | **PASS** — no-patch corpus 87.23% / `overEight=941`, patched corpus 100% (Task 5) |
| 3 | exactly the covered labels are patches | **PASS** — `patchCount == 2` on the fixture (Task 5) |
| 4 | `skippedOps == 0` | **PASS** — every corpus measured, this task's device corpus included |
| 5 | criterion 11: hold + pan ≤ 0.5 ms, `patches ≥ 8` | **MISS** — hold +1.79 ms, pan +4.22 ms; `patches=87 ≥ 8` (that sub-condition alone passes) |
| 6 | criterion 6: `buffer + subBuffer ≤ 8 MB` | **PASS** — 7.06 MB, 0.94 MB margin |
| 7 | 14/14 mutations fire, survivors declared | **PASS** — 14/14 killed on the first shot, zero survivors |
| 8 | no shader or bundle change | **PASS** — `git diff --stat 8dde4fb..HEAD -- packages/jet_cad_2d_flutter/shaders packages/jet_cad_2d_flutter/assets` empty |
| 9 | a human looks at the window | **18 of 19 discharged 2026-09-05** — Plan E's checks 1–4 and all fourteen older ones seen, no problem reported; check 5 (`DRAW_TEXT=false` control) still **OWED**, its run was not made |
| 10 | every gate green, all three packages | **PASS** — see below |

**8 of 10.** Criterion 5 (criterion 11) is a measured MISS, not adjusted;
criterion 9 is eighteen-nineteenths discharged by a human on 2026-09-05
and still formally open on its `DRAW_TEXT=false` control — not scored as
passed on eighteen.

### The gate commands, verbatim

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:08 +617 ~1: All tests passed!
$ flutter analyze
No issues found! (ran in 1.2s)
$ dart format --output=none --set-exit-if-changed .
Formatted 99 files (0 changed) in 0.16 seconds.
```

```
$ cd ../jet_cad_2d && dart test
...
00:02 +798: All tests passed!
$ dart analyze
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.14 seconds.
```

```
$ cd ../../apps/dev_harness_2d && flutter test --concurrency=1
...
00:14 +77: All tests passed!
$ flutter analyze
No issues found! (ran in 0.8s)
$ dart format --output=none --set-exit-if-changed .
Formatted 20 files (0 changed) in 0.04 seconds.
```

`+617 ~1` in `jet_cad_2d_flutter` and `+77` in `dev_harness_2d` are this
plan's own growth over Plan D's merged counts (565 → 617, 73 → 77) across
Tasks 1–8; `+798` in `jet_cad_2d` is unchanged from Plan D (this plan
touches nothing under `packages/jet_cad_2d`).

---

## Files this task touched

- `packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart` — the
  crash fix, `4af35bf` (one `CommandBuffer` per `RenderPass`, Ruling R6-3).
- `docs/superpowers/notes/2026-09-04-plan-e-results.md` — this file.
- `docs/superpowers/notes/2026-09-04-plan-e-raw/` — `run1-text-on.log`,
  `run2-draw-text-off.log` (post-fix, the numbers above), and
  `run1-text-on-CRASH-pre-fix.log` (the crash evidence).
- `STATUS.md` — head and "Resume here" rewritten; see the commit.
