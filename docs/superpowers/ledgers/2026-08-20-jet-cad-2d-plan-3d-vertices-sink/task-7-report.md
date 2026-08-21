# Task 7 report — the harness picks a backend

## What was implemented

`apps/dev_harness_2d/lib/main.dart`:

- Deleted `kVertices` (`const bool.fromEnvironment('VERTICES')`).
- Added `kBackend`, a `final RenderBackend? kBackend` resolved from
  `String.fromEnvironment('BACKEND', defaultValue: '')` via the exact switch
  expression the brief specifies (`''` → `null`, `'canvas'` →
  `RenderBackend.canvas`, `'vertices'` → `RenderBackend.vertices`, anything
  else → `StateError` at startup).
- `HarnessApp.onReady`'s signature grew a sixth positional parameter,
  `RenderBackend resolvedBackend`, so the app hands the rig what
  `DraftCanvasState` actually built, not what `kBackend` asked for. Wired
  from `canvasState.resolvedBackend` in `_HarnessAppState.initState`'s
  post-frame callback.
- `DraftCanvas(... useVertices: kVertices)` → `DraftCanvas(... backend:
  kBackend)`.

`apps/dev_harness_2d/integration_test/frame_timing_test.dart`:

- `boot`'s return record grew `RenderBackend resolvedBackend`, captured from
  the `onReady` callback's new sixth argument (`(c, i, p, s, v, b) { ...
  resolvedBackend = b; }`).
- `printVerticesCounters(VerticesDrawSink?)` replaced by
  `printBackend(RenderBackend backend, VerticesDrawSink? vertices)`, exactly
  as the brief's Step 2 gives it. This is also where item 2 of the
  accumulated work landed: the old body read `vertices.frameSegmentCount`
  (renamed to `frameTriangleCount` by Task 4) and printed a `segments=`
  label; the new body reads `frameTriangleCount` and prints `triangles=`.
  There was no separate `frameSegmentCount` reference left over to patch —
  replacing the whole function per the brief's Step 2 subsumed it.
- All three call sites (R2, R4a, R4b) changed from
  `printVerticesCounters(app.vertices)` to
  `printBackend(app.resolvedBackend, app.vertices)`.

No other file in `apps/dev_harness_2d` referenced `kVertices`, `useVertices`
or `printVerticesCounters` — confirmed by `grep -rn` before committing.

STATUS.md: untouched, as instructed — its "analyze/format clean" claim for
this app is true again as of this commit, and Phase C will regenerate rows
independently.

## Verification: two device runs, different `BACKEND`, different `backend=`

Ran on a real macOS device (`macOS (desktop) • macos • darwin-arm64`) in
profile mode via `flutter drive`, exactly per the brief's Step 4 command,
with `TEXT=true ENTITIES=10000 RIG=pan`:

### `BACKEND=canvas`

```
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (10000) frames=242
flutter:   build  p50=16.01ms p95=18.24ms max=370.27ms
flutter:   raster p50=58.71ms p95=79.12ms max=617.79ms
flutter:   screenSpaceLeafCount=1664 lineweightScale=1.0
flutter:   dashSpans=37376 collapsed=238 canvasCalls=39631
flutter:   backend=canvas
flutter:   text: corpus=on draw=on textOps=18 skippedText=0
flutter:   paragraphs: newLayouts=0 newEvictions=0 live=512 (totals layouts=1064 evictions=552)
flutter: 00:17 +4: All tests passed!
All tests passed.
```

### `BACKEND=vertices`

```
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (10000) frames=242
flutter:   build  p50=7.23ms p95=8.17ms max=360.20ms
flutter:   raster p50=9.77ms p95=32.20ms max=103.04ms
flutter:   screenSpaceLeafCount=1664 lineweightScale=1.0
flutter:   dashSpans=37376 collapsed=238 canvasCalls=18
flutter:   backend=vertices triangles=166279 drawVerticesCalls=19
flutter:   text: corpus=on draw=on textOps=18 skippedText=0
flutter:   paragraphs: newLayouts=0 newEvictions=0 live=512 (totals layouts=1064 evictions=552)
flutter: 00:09 +1: R4a leaf edit per frame
flutter: 00:09 +2: R4b instance drag per frame
flutter: 00:09 +3: (tearDownAll)
flutter: 00:09 +4: All tests passed!
All tests passed.
```

The `backend=` field differs between the two runs exactly as the brief
requires (`canvas` vs `vertices`), and the define reaches the app: this is
the check that would have caught Plan 3c's `TEXT` bug. As a bonus control,
`screenSpaceLeafCount` (1664) and `dashSpans` (37376) are identical across
both runs — the same document was drawn both times, only the sink differed
— and `canvasCalls` collapses from 39631 (canvas) to 18 (vertices, fallback
ops only), which is the batching the vertices backend exists for.

Both `flutter drive` invocations printed `All tests passed.` and exited 0.
No exceptions, no crash. The one warning line present in both logs
(`Failed to foreground app; open returned 1`) is a benign macOS `open`
window-focus message that appears identically before either app's Dart code
runs — unrelated to the backend or to `Vertices` disposal.

Full raw logs are on disk in the scratchpad used for this session
(`run_canvas.log`, `run_vertices.log`) if a reviewer wants to inspect beyond
the excerpts above; they are not part of the repo.

## Device verification of `Vertices` disposal (accumulated item 3)

Task 2 made `flush()` dispose the `Vertices` object it submits and verified
safety with a `PictureRecorder` + `toImage()` rasterisation test, but flagged
that a recorder may retain what a rasterisation does not, so wanted a real
device run as well. The harness did not compile until this task, so that run
could not happen until now.

The `BACKEND=vertices` run above exercised exactly that path on a real macOS
window compositor: R2 pans 120 frames, zooms 120 frames across three scale
bands, and forces one more repaint — 242 frames total, `drawVerticesCalls=19`
across the measured tail alone (more over the full 242-frame run, since
`totalFlushCount` is a running total and only the post-reset frame is
printed). Every one of those `drawVertices` calls submits a `Vertices` object
that `flush()` disposes immediately after. The app rendered the corpus
correctly across the whole pan/zoom sequence — nothing blank, no visible
corruption reported by the driver, `screenSpaceLeafCount` and `dashSpans`
matching the canvas run bit for bit — and the process completed with `All
tests passed.` and no crash, no `Failed assertion`, no `EXC_BAD_ACCESS` or
similar in the log. This is a real rasteriser on real macOS window
compositing (not just an offscreen `toImage()`), and it did not surface the
use-after-dispose hazard Task 2's brief was concerned about.

## Full three-package gate

All three green, run from a clean worktree state after the device runs (with
`macos/Runner.xcodeproj/project.pbxproj` reverted first — see below):

```
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
  → 720 tests, All tests passed. / Analyzing jet_cad_2d... No issues found! / Formatted 105 files (0 changed)

cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
  → 206 tests + 1 skipped, All tests passed. / Analyzing jet_cad_2d_flutter... No issues found! (ran in 1.1s) / Formatted 40 files (0 changed)

cd apps/dev_harness_2d && flutter analyze && dart format --output=none --set-exit-if-changed lib integration_test
  → Analyzing dev_harness_2d... No issues found! (ran in 0.9s) / Formatted 2 files (0 changed)
```

`jet_cad_2d_flutter` at 206 passing + 1 skipped matches the floor the
controller's ruling states; nothing below it.

## `project.pbxproj` handling

Before the first `flutter drive` run, `macos/Runner.xcodeproj/project.pbxproj`
was copied aside to the session scratchpad. Both `flutter drive` invocations
rewrote it (CocoaPods, as documented). After the second run,
`git checkout -- apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`
was used to revert it — the sanctioned exception named in the task brief. Its
MD5 after revert (`1d41324c086c075d29aa5d27f3de8322`) matches the pre-run
scratchpad copy's MD5 exactly, and `git status --porcelain` showed no diff on
that file afterward. It was never staged or committed.

## Files changed

- `apps/dev_harness_2d/lib/main.dart`
- `apps/dev_harness_2d/integration_test/frame_timing_test.dart`

Commit: `feat: the harness selects a backend rather than toggling a sink`
(short SHA `3351232`), body extended beyond the brief's given message with a
paragraph covering the `printVerticesCounters`→`printBackend` rename /
`triangles=` label change and a paragraph summarizing the device
verification, per the task instructions to extend the message where the
brief's own text doesn't cover the accumulated items.

## Self-review

Read the full diff (`git diff` before commit, then `git show` after) end to
end:

- `kBackend`'s switch matches the brief's code block verbatim, including the
  exact doc comment.
- `printBackend`'s body matches the brief's code block verbatim.
- All three `printVerticesCounters` call sites (R2, R4a, R4b) were updated —
  confirmed via `grep -n` that zero references to the old name remain.
- `onReady`'s new positional parameter was threaded through both the
  producer (`main.dart`'s `_HarnessAppState`) and the one consumer
  (`frame_timing_test.dart`'s `boot`); `grep` confirmed no other file
  constructs `HarnessApp` or reads `onReady`.
- No `analysis_options.yaml` changes at any point — checked `git status`
  before every gate run and before the commit.
- Only the two files the brief names are staged; `build/` under
  `dev_harness_2d` is gitignored and was never touched by `git add`.
- Draw order and per-entity allocation are unaffected — this task only
  threads a resolved-backend value through printing and constructor calls,
  it does not touch the frame path itself.

No findings to flag from the self-review.

## Concerns

None. The define reaches the app and is provably wired (two different
`backend=` values from two different `--dart-define=BACKEND=` values), the
vertices backend survived a real device run across 242 frames without
incident, and all three gates are green at the floor the controller
specified.
