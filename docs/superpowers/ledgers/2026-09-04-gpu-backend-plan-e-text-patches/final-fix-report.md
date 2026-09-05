# Plan E — final whole-branch review, fix wave

Ruling RF-1 governs this wave (`progress.md`, "Final whole-branch review"
section). One dispatch, all findings below, addressed against
`plan-e/text-patches` at `d5d7517` (before this wave's commit). No
subagents spawned; worked directly in
`/Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-e-text-patches`.

---

## F1 — `.vscode/launch.json`: `SPIKE_FILLS=true` on criterion-11's two entries

Both criterion-11 launch entries — *"2d: GPU spike -- text ON (criterion 11,
DRAW_TEXT=true)"* and its `DRAW_TEXT=false` control — were missing
`--dart-define=SPIKE_FILLS=true`, so run as committed neither showed fills;
Plan D's five window checks would have nothing to look at through either
entry (the gap Task 9 found and deferred, per `progress.md`'s "Task 9:
concern" line).

**Fix**: added `"--dart-define=SPIKE_FILLS=true"` to `toolArgs` on both
entries, positioned right after `SPIKE_REPEATS=3` and before the
text-specific defines — matching where the fills-entries themselves place
it (`"2d: GPU spike -- fills ON, ..."` entries, `SPIKE_FILLS=true`
immediately after `SPIKE_REPEATS=3`).

Diff:
```diff
                 "--dart-define=SPIKE_REPEATS=3",
+                "--dart-define=SPIKE_FILLS=true",
                 "--dart-define=SPIKE_TEXT=true"
```
(and the same one line earlier in the `DRAW_TEXT=false` control entry,
before its own `"--dart-define=SPIKE_TEXT=true"`/`"--dart-define=DRAW_TEXT=false"` pair).

---

## F2 — invariant-1 accounting: hoist the two per-call scratches, and amend the record

### Code

**`text_patches.dart` `patchRegionFor`**: added an optional named
`Float64List? scratch` parameter; `final bound = Float64List(4);` became
`final bound = scratch ?? Float64List(4);`. Doc comment's last sentence —
*"The `Float64List(4)` scratch is local and allocated per call: invariant
1's per-patch exception (a patch is one per label per frame, not per
entity)."* — became *"The caller passes a reused scratch on the frame path;
a null scratch allocates one -- test callers."*

**`text_compositor.dart` `labelBoundsLogical`**: same shape — added
`{Float64List? scratch}`, `final bound = scratch ?? Float64List(4);`, same
doc-comment sentence swap.

**`gpu_draw_backend.dart`**: added two fields —

```dart
final Float64List _regionScratch = Float64List(4);
final Float64List _boundsScratch = Float64List(4);
```

— passed at both call sites in `render`: `patchRegionFor(..., scratch:
_regionScratch)` in the patch loop, `labelBoundsLogical(..., scratch:
_boundsScratch)` in the `_pendingRegions` drain loop that builds each
`PatchImage`. Both scratches are consumed synchronously inside their call
(the result is copied into a `PatchRegion`/`Rect` before the next loop
iteration reuses the same array), so reuse across patches in one frame is
safe.

**Class doc rewritten** to list exactly what a patch still allocates per
frame, now that the two `Float64List(4)` scratches are off the list: a
`PatchRegion`, a `(ResidentPatch, PatchRegion)` record, a `PatchImage`,
three `Rect`s, the `Transform2` built for `toPatch`, the `ByteData(80)`
uniform block `buildFrameInfo` returns, one `saveLayer`, one `ui.Image`
handle — one of each per patch, never per entity or per plain label — and
names Plan F's two cheapest remaining reuse moves (a mutable `PatchRegion`;
a reused uniform `ByteData`), not taken here per Ruling RF-1.

### Spec (`docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md`)

Applied with a Python script asserting `s.count(old) == 1` before each
replace (prose file, exact-match discipline per the dispatch).

**Text-section bullet**, after the layer + `ui.Image` handle sentence —
before: `... — the same handle the main image already costs every frame
today). That is a per-*patch* allocation, ...` — after: inserted, between
those two sentences:

> Plan E's results measured the Dart-side cost beside the engine's own two,
> the same per-patch list: a `PatchRegion`, a `(ResidentPatch,
> PatchRegion)` record, a `PatchImage` carrying three `Rect`s, one
> `Transform2` and one 80-byte uniform block — all of it per patch.

**`## Invariants` item 1**, the "one stated exception" sentence — before:
*"...a patch costs the engine one layer and one image handle per frame, and
a patch is a label. That allocation is per label later geometry
reaches..."* — after: *"...a patch costs the engine one layer and one image
handle per frame, and a patch is a label, plus the small per-patch Dart
objects Plan E's results note enumerates. That allocation is per label
later geometry reaches..."*

### Plan (`docs/superpowers/plans/2026-09-04-gpu-backend-plan-e-text-patches.md`)

Same script/exact-match discipline. `## Global Constraints`, first bullet —
before: *"...per label later geometry reaches. Nothing else per label, and
nothing per instance. The compositor's matrix buffer..."* — after:
*"...per label later geometry reaches. The remaining per-patch Dart
allocations are enumerated in `GpuDrawBackend`'s class doc and the spec's
exception; nothing per instance, nothing per plain label. The compositor's
matrix buffer..."*

---

## F3 — `textsDropped` counter

**`gpu_draw_backend.dart`**: added a public `int textsDropped = 0;` counter
beside `patchesRendered`/`patchesClipped`/`patchesOffscreen`, with a doc
comment stating Ruling E2's discipline in its own words — *"a backend wired
without a measurer shows as a number, not a missing picture"* — and
recording the reset choice: reset to 0 at the top of every `paint()` call
(not `render()`), because the `_compositor == null` check this counter
reports on lives in `paint`, not `render`. In `paint`, when `_compositor ==
null && geometry.texts.isNotEmpty`, `textsDropped += geometry.texts.length;`.

**No unit test**: as anticipated by the dispatch, `GpuDrawBackend`'s
constructor takes a `ResidentGeometry`, and `ResidentGeometry.create` needs
a live `gpu.gpuContext` (unavailable off a device/simulator run) — nothing
in `flutter test` can construct a `GpuDrawBackend` at all, so no unit test
exercises `textsDropped`. Recorded in the field's own doc comment
("**Untested by `flutter test`.**...") and here, per the dispatch's
instruction to say so in both places.

**`apps/dev_harness_2d/lib/gpu_arm.dart`**: one block added just before the
existing `gpuReport('GSPIKE done: ...')` line, printing
`state.backend?.textsDropped` once, only when non-zero. This harness always
builds `state.backend` WITH a measurer (`_buildResidentGeometry`'s
`GpuDrawBackend(...)` call always supplies `measurer:`/`textStyleOf:`), so
the count is always 0 in this harness's own runs today — the print exists
for a future caller that omits the measurer, per the counter's own purpose.
The rig's loop structure was not touched.

---

## F4 — cheap doc/test fixes

- **`text_patches.dart:11-14`**: doc previously claimed *"Every
  classification function in this file (`classifyTextPatches`, and Task 4's
  region and size functions) takes them as parameters"* — false for
  `patchRegionFor`, which takes neither `bandLowerScale` nor
  `bandUpperScale`. Reworded to name only `classifyTextPatches` (the floor)
  and `patchTargetSizeFor` (the ceiling), with `patchRegionFor` called out
  as taking neither.
- **`text_compositor.dart` `paint`**, at the `saveLayer` call: added a
  comment noting the layer clips a patched label's paragraph to
  `patch.layerBounds` (the padded box), so glyph overhang past ascent,
  descent or advance plus the pad would clip on a *patched* label only,
  never a plain one — and that nothing in this codebase's fixtures
  exercises that overhang.
- **`text_compositor_test.dart`**: added one sentence to the "outer
  transform" test's comment noting it runs with `patches: const []`
  throughout, so it cannot see a `saveLayer`-ordering bug (M-E9) itself —
  corrected during this wave's own gate pass to also credit this file's own
  `srcATop` test (which *does* patch and does kill M-E9), not just
  `text_order_test.dart` alone, matching `plan-e-mutation-log.md`'s M-E9 row
  exactly (`text_compositor_test.dart`'s srcATop test **and**
  `text_order_test.dart` both kill it; only *this specific test*, with no
  patches, cannot). Added one sentence to `samplePoints()`'s doc comment
  stating a baseline-flip bug (M-E10) is invisible to this file —
  `plan-e-mutation-log.md`'s M-E10 row confirms `text_compositor_test.dart`
  "did not fire" for that mutation at all, so this sentence needed no
  correction.
- **`docs/superpowers/notes/2026-09-04-plan-e-results.md`**: exit-gate row 8
  `git diff --stat main..HEAD -- ...` → `git diff --stat 8dde4fb..HEAD --
  ...` (the branch's merge-base with `main`, per the ledger's own header
  line). The device-run **Method** paragraph gained "three interleaved
  repeats (`SPIKE_REPEATS=3`, arms A/B/C run in turn within each repeat --
  `runGpuSpike`'s own loop order)" before the Low-Power-Mode sentence.
- **`STATUS.md` "Resume here"**: removed the paragraph describing the
  `.vscode/launch.json` `SPIKE_FILLS=true` gap (fixed by F1 in this same
  wave) and replaced it with one sentence saying both entries now carry the
  define. Added a new **"Plan F inherits, with numbers"** bullet list right
  after the Plan F plan-link paragraph: `classify` 27.4 ms (no pruning —
  bucket by y or early-reject on a device box); the compositor walks all
  165 labels including off-viewport ones (viewport rejection named as the
  cheapest lever against criterion 11's MISS); R6-2's `1 + P` image handles
  per frame (`P = 87` measured, parked not fixed); the frozen-culling
  divergence left ungated at `minTextCapPixels: 0`; the spec's eighth text
  mutation ("leave the resident text list stale across a rebuild",
  confirmed present at spec line 660) as Plan F's to fire.

---

## Not taken (Ruling RF-1)

Per the controller ruling, NOT done in this wave: a band-floor parameter on
the collector; a `5000 × s²` anti-vacuity floor; a mutable `PatchRegion`;
disposing image handles (R6-2 stays parked).

---

## Gates — all three, run fresh after every edit landed

### `packages/jet_cad_2d_flutter`

```
$ flutter test
...
00:0x +617 ~1: All tests passed!
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)
$ dart format --output=none --set-exit-if-changed .
Formatted 99 files (0 changed) in 0.15 seconds.
```
Exit codes: `flutter test` 0, `flutter analyze` 0, `dart format` 0.
617 tests, matching Task 9's own recorded count (this wave adds no test).

### `packages/jet_cad_2d` (untouched by this wave; run per the dispatch's gate list)

```
$ dart test
...
00:02 +798: All tests passed!
$ dart analyze
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.14 seconds.
```
Exit codes: `dart test` 0, `dart analyze` 0, `dart format` 0. 798 tests,
matching Task 9's recorded count exactly (no file under `packages/jet_cad_2d`
changed).

### `apps/dev_harness_2d`

```
$ flutter test --concurrency=1
...
00:15 +77: All tests passed!
$ flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 0.8s)
$ dart format --output=none --set-exit-if-changed .
Formatted 20 files (0 changed) in 0.04 seconds.
```
Exit codes: `flutter test` 0, `flutter analyze` 0, `dart format` 0. 77
tests, matching Task 9's recorded count (`gpu_arm.dart`'s change is a
harness-glue print, not a test-visible behaviour change on this arm since
`textsDropped` is always 0 here).

`git status --short` before commit showed exactly the ten files this report
lists changed, no `analysis_options.yaml` among them.

---

## Files touched

- `.vscode/launch.json`
- `packages/jet_cad_2d_flutter/lib/src/gpu/text_patches.dart`
- `packages/jet_cad_2d_flutter/lib/src/gpu/text_compositor.dart`
- `packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart`
- `packages/jet_cad_2d_flutter/test/gpu/text_compositor_test.dart`
- `apps/dev_harness_2d/lib/gpu_arm.dart`
- `docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md`
- `docs/superpowers/plans/2026-09-04-gpu-backend-plan-e-text-patches.md`
- `docs/superpowers/notes/2026-09-04-plan-e-results.md`
- `STATUS.md`

Commit: `fix(gpu): the final review's fixes -- launch defines, per-patch
scratches hoisted, dropped-text counter, records amended`.
