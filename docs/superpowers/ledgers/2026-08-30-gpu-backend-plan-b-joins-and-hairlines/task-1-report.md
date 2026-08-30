# Task 1 report: the harness GPU arm moves out of `main.dart`

## Step 1: the arm's boundaries

```
$ cd apps/dev_harness_2d
$ grep -n 'RUN_GPU_SPIKE\|GSPIKE\|GeometryCollector\|ResidentGeometry\|GpuDrawBackend' lib/main.dart
```

hits ran from line 604 (a doc comment on `kRunGpuSpike`) through line 1634
(the closing `gpuReport('GSPIKE done: ...')` call). `wc -l lib/main.dart`
reported 1635 lines before the move.

I did not use the grep hits directly as the cut line, because two of them
(`kRunGpuSpike`'s declaration at line 616 and the `main()` dispatch at
614/681-709) are the shared entry-point wiring the brief's resolution #1 says
stays in `main.dart`. I read forward from the last `_HarnessAppState` member
(the widget the ordinary harness path uses) to find where GPU-only code
starts, and found a section-divider comment:

```
1097  }
1098
1099  // --- The GPU arm: painter vs. tiles vs. jet_cad_2d_flutter's resident-GPU
1100  // backend, interleaved. -----------------------------------------------
```

I took **lines 1099-1635** (537 lines) as the arm: the divider comment, the
`GpuSpikeArm` enum, `GpuPhaseReport`, `gpuReportLines`/`gpuReport`/`gpuStats`,
`GpuArmPainter`, `GpuArmView`, `GpuSpikeApp`/`GpuSpikeState`, and
`runGpuSpike`, all the way to EOF. I confirmed the cut by grepping every
GPU-only symbol (`GpuSpikeApp`, `GpuSpikeState`, `GpuSpikeArm`,
`GpuPhaseReport`, `GpuArmPainter`, `GpuArmView`, `runGpuSpike`, `gpuReport`,
`gpuReportLines`, `gpuStats`) across `lib/` and `test/`: every reference sits
either inside 1099-1635 or in `main()`'s dispatch block (614, 616, 681-709),
and no test file references any GPU-arm symbol at all. `kRunGpuSpike`, the
`main()` `if (kRunGpuSpike) { runApp(GpuSpikeApp(...)) }` branch,
`spikeDocument()`, the corpus knobs (`kSpikeDefs`/`kSpikeInstances`/
`kSpikeFrames`/`kSpikeRepeats`), the camera script (`_driveR2`) and the
frame-timing log (`measurement_rig.dart`, imported separately) all stay in
`main.dart` per the brief's resolution #1.

## Step 2: before/after test counts

Before (baseline, run before touching any file):

```
$ cd apps/dev_harness_2d && flutter test --concurrency=1 2>&1 | tail -5
...
00:18 +72: All tests passed!
exit=0
```
72 tests, exit=0.

After the move and the gate fixes below:

```
$ cd apps/dev_harness_2d && flutter test --concurrency=1
...
00:17 +72: All tests passed!
```
`TEST_EXIT=0` (captured separately, not through a piped `tail`, to get the
command's own exit code rather than `tail`'s).

Identical count (72), identical exit code (0).

## Step 3: the move

Created `apps/dev_harness_2d/lib/gpu_arm.dart`: a 13-line header (an
`ignore_for_file: avoid_print` directive plus the imports the block needs)
followed by the 537 lines from `main.dart` 1099-1635, byte-for-byte identical
except for the `_pumpFrame` → `pumpFrame` rename (verified with `diff` against
the original extracted block — see Step 4). No logic was rewritten.

Import direction: matched `widget_arm_rig.dart` in that `gpu_arm.dart` pulls
in the same shared files `main.dart` itself uses for the same symbols
(`measurement_rig.dart` for `FrameTimingLog`/`refuseDebugMode`,
`package:jet_cad_2d/jet_cad_2d.dart` and
`package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` for the document/camera/
GPU types) rather than trying to reach them indirectly through `main.dart`.
`main.dart` gained one new import, `import 'gpu_arm.dart';`, placed after
`import 'widget_arm_rig.dart';` (mirroring `main()`'s branch order: the
widget-spike branch is checked before the GPU-spike branch).

The one place the arm needed something from `main.dart` itself is
`_pumpFrame` (defined at old line 937, used by `_driveR2`, `_settle` and
inside the moved `runGpuSpike`/`phase`/`setArm`). Because Dart privacy is
per-file, a `_`-prefixed top-level declaration in `main.dart` cannot be
referenced from `gpu_arm.dart` at all, and the brief's resolution #3
explicitly says to rename rather than duplicate. So `gpu_arm.dart` does
`import 'main.dart';` — the "other way" the brief's resolution #1 describes
— to reach it.

**Rename made:** `_pumpFrame` → `pumpFrame` (top-level function in
`main.dart`, was private, now public). Every one of its 9 call sites in the
retained part of `main.dart` (`_driveR2`'s own pump, its `runPanArm`/`runArm`
closures, `pumpFrame:` named-argument forwarding to `runR2Rig`/
`runTilePanArm`/`runTileZoomPhase`, `_settle`, one doc-comment mention) was
updated to the new name, and the 6 call sites that moved into `gpu_arm.dart`
now reference it through the `import 'main.dart';` above. No other private
declaration in `main.dart` was needed by the moved code — I grepped every
`_`-prefixed identifier referenced inside lines 1099-1635 and the only two
hits were `_buildResidentGeometry` (defined and used entirely inside the
moved block itself, so it travelled as-is) and a `_target` mention that turned
out to be inside a comment referring to a private field of a *different*
class in the package (`GpuDrawBackend._target`), not a `main.dart`
declaration.

Two import-hygiene fixes came out of the move itself, not out of rewriting
logic:
- `main.dart` no longer uses `kIsWeb` anywhere (its only use was inside the
  moved `phase` closure's web-alignment branch), so
  `import 'package:flutter/foundation.dart' show kIsWeb;` became dead and
  `flutter analyze` flagged it (`unused_import`) — removed.
- `gpu_arm.dart`'s own `print(line)` inside `gpuReport` needed the
  `ignore_for_file: avoid_print` directive that used to cover it as part of
  `main.dart`'s file-wide one; `main.dart` still has 12 other `print()` calls
  (the R2 diagnostics) so its own directive stays. Added a matching directive
  at the top of `gpu_arm.dart`, worded the same way as `widget_arm_rig.dart`'s.

Both are mechanical consequences of splitting the file, not logic changes;
`flutter analyze` was clean (0 issues) once they were made.

## Step 4: move-not-rewrite check

```
$ git add -N apps/dev_harness_2d/lib/gpu_arm.dart   # untracked new file, for --stat to see it
$ git diff --stat
 apps/dev_harness_2d/lib/gpu_arm.dart | 550 ++++++++++++++++++++++++++++++++++
 apps/dev_harness_2d/lib/main.dart    | 558 +----------------------------------
 2 files changed, 560 insertions(+), 548 deletions(-)
```

548 deletions in `main.dart` vs. 550 insertions in `gpu_arm.dart` — a
2-line asymmetry, fully accounted for once both sides are broken into the
537-line moved block plus what is not the moved block:

- `gpu_arm.dart`'s 550 insertions = 537 (the moved block) + **13** (the new
  file's header: the 2-line `ignore_for_file` comment, a blank, the 4
  package imports the block needs, another blank, `import 'main.dart';`,
  `import 'measurement_rig.dart';`, and the blank line before the moved
  content starts — corrected here from an earlier, wrong count of 3; 3 was
  the size of a sub-piece of the header, not the header itself).
- `main.dart`'s 548 deletions = 537 (the moved block) + **11** lines outside
  it: the blank line that used to separate `_HarnessAppState` from the GPU
  section (no longer needed once nothing follows), the now-dead
  `import 'package:flutter/foundation.dart' show kIsWeb;`, and the
  pre-rename content of the 9 `_pumpFrame` call sites that stayed in
  `main.dart` (each rename is one deletion of the old line plus one
  insertion of the new one).

13 − 11 = 2, which is the observed gap. `main.dart`'s 10 insertions are
the 9 post-rename `pumpFrame` lines plus the new `import 'gpu_arm.dart';`
line.
I also diffed the moved body directly against the untouched original
extraction (`diff <(tail -n +14 lib/gpu_arm.dart) <extracted-1099-1635-with-rename>`)
and it is empty — the moved 537 lines are byte-identical to the original
apart from the rename. This is a move, not a rewrite.

## Step 5: gate

`apps/dev_harness_2d`:
```
$ flutter test --concurrency=1
...
00:17 +72: All tests passed!
TEST_EXIT=0

$ flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.1s)
ANALYZE_EXIT=0

$ dart format --output=none --set-exit-if-changed .
Formatted 17 files (0 changed) in 0.12 seconds.
FORMAT_EXIT=0
```

`packages/jet_cad_2d_flutter` (untouched by this task, gate run as required):
```
$ flutter test
...
00:07 +439 ~1: All tests passed!
TEST_EXIT=0

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
ANALYZE_EXIT=0

$ dart format --output=none --set-exit-if-changed .
Formatted 85 files (0 changed) in 0.15 seconds.
FORMAT_EXIT=0
```

(The `~1` in the `jet_cad_2d_flutter` test summary is a pre-existing skip in
that package's own suite, unrelated to this task — the package's files were
not touched.)

`git status --short` was checked after every gate run; no
`analysis_options.yaml` files appeared in either directory at any point.

## What stayed in `main.dart`, and why a reader might expect otherwise

- `kRunGpuSpike` (the `bool.fromEnvironment('RUN_GPU_SPIKE')` constant) and
  the `if (kRunGpuSpike) { runApp(GpuSpikeApp(...)) }` block inside `main()`
  (lines ~614-616, ~681-709 originally): this is the shared entry-point
  dispatch the brief's resolution #1 names explicitly. It calls into
  `GpuSpikeApp`/`runGpuSpike`, both now imported from `gpu_arm.dart`.
- `spikeDocument()` and its corpus knobs (`kSpikeDefs`, `kSpikeInstances`,
  `kSpikeFrames`, `kSpikeRepeats`): shared with the widget-spike arm, per
  resolution #1.
- `_pumpFrame` (renamed `pumpFrame`): shared plumbing used by `_driveR2`
  (the R2 camera script) and `_settle`, in addition to the GPU arm. It is
  exactly the kind of shared utility resolution #1 says stays in `main.dart`,
  now public so `gpu_arm.dart` can import and use it — the one rename this
  task made. **Superseded in Fix round 1 below**: this created an import
  cycle the reviewer caught, and `pumpFrame` moved again, out of `main.dart`
  entirely and into `measurement_rig.dart`, which both `main.dart` and
  `gpu_arm.dart` already imported for other reasons.

Nothing else looked like it belonged in `gpu_arm.dart` but was left behind.

## Fix round 1

Reviewer's Important 1: `gpu_arm.dart` importing `main.dart` (for `pumpFrame`)
while `main.dart` imports `gpu_arm.dart` (for `GpuSpikeApp`/`runGpuSpike`) is
a cycle, and neither `widget_arm.dart` nor `widget_arm_rig.dart` has one —
`widget_arm_rig.dart` keeps its own local `_pumpFrame` instead of reaching
into `main.dart`. The coordinator's resolution: give `pumpFrame` a home both
arms already import for other reasons, rather than either duplicating it or
having one arm file reach into `main.dart`.

**What moved.** `pumpFrame` (and its doc comment) moved from `main.dart` into
`measurement_rig.dart`, placed right after `refuseDebugMode()` — the only
other free function that file exports at its top level before the
frame-timing classes start. `measurement_rig.dart` already imports
`package:flutter/scheduler.dart`, so no new import was needed there.
`main.dart` reaches it through its existing `import 'measurement_rig.dart';`
(already present, used for `FrameTimingLog`/`refuseDebugMode`) — no new
import added. `gpu_arm.dart` dropped `import 'main.dart';` outright; it also
already imports `measurement_rig.dart`.

**`widget_arm_rig.dart`'s own `_pumpFrame` (lines 223-226 at FIX_BASE): same
function.** Byte-for-byte:

```dart
Future<void> _pumpFrame() {
  SchedulerBinding.instance.scheduleFrame();
  return SchedulerBinding.instance.endOfFrame;
}
```

against the body that was in `main.dart` (now in `measurement_rig.dart`):

```dart
Future<void> pumpFrame() {
  SchedulerBinding.instance.scheduleFrame();
  return SchedulerBinding.instance.endOfFrame;
}
```

Identical apart from the name/privacy. Per the coordinator's instruction I
deleted `widget_arm_rig.dart`'s local copy and repointed its 6 call sites
(the two `setArm`-style pumps, one phase-reset pump, and the three
`FrameTimingLog` callback references — `establishBaseline`, `pump`,
`drain`) at the shared `pumpFrame` from `measurement_rig.dart`, which that
file already imports. This did not change behaviour: both bodies scheduled a
frame and awaited `endOfFrame` the same way, so replacing the call target is
not an observable change to the widget arm — no test exercises the widget
arm at all (confirmed in the original Step 1 grep across `test/`).

Two dead imports fell out as a mechanical consequence and were removed, the
same way `kIsWeb` did in the original move:
- `widget_arm_rig.dart`'s `import 'package:flutter/scheduler.dart';` —
  `SchedulerBinding` was referenced only inside the now-deleted local
  `_pumpFrame`; the rest of the file's only remaining `SchedulerBinding`
  mention is inside a comment. `flutter analyze` flagged it
  (`unused_import`) and it was removed.
- `main.dart` needed no new import-hygiene fix here: it still calls
  `SchedulerBinding.instance.hasScheduledFrame` directly inside `_settle`,
  so its own `import 'package:flutter/scheduler.dart';` stays live.

**Cycle check:**

```
$ grep -rn "import 'main.dart'" apps/dev_harness_2d/lib/
exit=1
```

(grep prints nothing and exits 1 — no match — confirming no file under
`lib/` imports `main.dart`.)

**Gate**, `apps/dev_harness_2d`:

```
$ flutter test --concurrency=1
...
00:18 +72: All tests passed!
TEST_EXIT=0

$ flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.1s)
ANALYZE_EXIT=0

$ dart format --output=none --set-exit-if-changed .
Formatted 17 files (0 changed) in 0.12 seconds.
FORMAT_EXIT=0
```

72/72 — same count as both the original before-picture and the FIX_BASE
after-picture. This fix changed no behaviour, only where two names live.

**Gate**, `packages/jet_cad_2d_flutter` (still untouched by this task):

```
$ flutter test
...
00:08 +439 ~1: All tests passed!
TEST_EXIT=0

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)
ANALYZE_EXIT=0

$ dart format --output=none --set-exit-if-changed .
Formatted 85 files (0 changed) in 0.15 seconds.
FORMAT_EXIT=0
```

`git status --short` was checked before staging; no `analysis_options.yaml`
appeared in either package directory.

**Files touched this round:** `apps/dev_harness_2d/lib/measurement_rig.dart`
(gained `pumpFrame`), `apps/dev_harness_2d/lib/main.dart` (lost `pumpFrame`'s
definition, kept every call site unchanged since they already said
`pumpFrame`), `apps/dev_harness_2d/lib/gpu_arm.dart` (dropped
`import 'main.dart';`), `apps/dev_harness_2d/lib/widget_arm_rig.dart`
(dropped its local `_pumpFrame` and the now-dead scheduler import, repointed
6 call sites at the shared function).
