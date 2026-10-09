# Slice 1 — the whole range `85905bd..56be3fa`: independent final review

**Range reviewed:** `85905bd..56be3fa` on `claude/exciting-pasteur-9m22jv`
(19 commits: the spec, the plan, Tasks 1–5 with their review fixes, the
results note). `85905bd` is `main` at release 0.3.0 plus STATUS.

**Where:** my own clones only.
- `/tmp/s1-final/head` at `56be3fa`: the gates and both host probes.
- `/tmp/s1-final/mut` at `56be3fa`: the mutants, the API dump and the probes.
- `/tmp/s1-final/v030`, a worktree at `v0.3.0` (`1b0c37a`): the comparisons.

In `/home/user/jet-cad` I wrote this file and nothing else.

**Read:** CLAUDE.md; the spec (P-1 to P-9, Slice 1 as amended, invariants,
the Review section); the plan; the results note; the five task reports and
four task reviews; the guide's new section and § 4; CHANGELOG *Unreleased*;
the whole diff of `lib/` in both touched packages, the demo, the CI and the
test edits.

**Flutter:** `/root/sdk/flutter` 3.47.6, `CI=true`.

## Verdict: **Approve with fixes**

I found no correctness defect where the tasks meet. Here is what I checked:
- **The public API.** An analyzer dump of both host barrels, at v0.3.0 and
  at `56be3fa`, shows additions only, plus the documented `@internal camera`
  rename.
- **Behaviour against 0.3.0.** At v0.3.0 and at the tip, the cameras after
  start, switch, `fitToView`, `fitToTables`, `load`, `newPlan` and remount
  are byte-identical, for 3 plans at 4 canvas sizes.
- **The 0.3.0 host probe.** It analyses clean against the full SHA, locally
  and in CI.
- **Goldens.** None changed.
- **Existing tests.** Every edit is the mechanical rename or an allowed
  addition, verified mechanically.
- **The allocation invariants.** Both are green.
- **The gates.** All green, with the standing sets exact.
- **The demo.** The demo's badges, zones and group statuses compose
  correctly.
- **Cross-task probes.** All nine (X1–X9) hold on the committed code.

Of my 21 mutants, 17 are killed by the committed suite. The fixes:
- **F-1, a behaviour question (Low).** A `centerOn` without a scale, made
  before any view, uses an internal 1440×900 placeholder scale.
- **F-2 to F-4, three test gaps (Low).** Each has a surviving mutant, and my
  probes show that two of them guard real behaviour.
- **F-5, P-7 coverage (Low).**
- **F-6 to F-8, small corrections to the docs and the record (Nit).**

None of them blocks the merge on correctness grounds. F-1 to F-4 are cheap
to land first.

## Findings

### F-1 (Low): a `centerOn` without a scale, before any view, takes the nominal 1440×900 scale

The guide says to use `centerOn` (or `fitToTables`) to place the camera
before a view shows. A plan's own first fit then performs that `_Centre`
target. `_centred` uses the camera's current scale, and before any view that
scale is `_placeNominally`'s guess for a 1440×900 window.

Probe Y1 (the Salon, in the selection mode, `centerOn(Offset(5000, -3000))`
with no scale, then a view mounted):

| Canvas | Page fit | Scale after the pre-mount `centerOn` |
|---|---|---|
| 1300×900 | 0.07745 | 0.08143 |
| 600×450 | 0.03673 | 0.08143 (2.2× the fit) |

The point is centred correctly. The zoom, however, depends on an
undocumented placeholder. That is the trap Task 2's R-1 removed for `panBy`
("a command whose result depends on an undocumented guess is not one a host
can use"). No test pins the scale-less pre-mount case: CM9 and CM10 both
pass a scale.

**Fix, either of:**
- **Code.** In `framingFor`, when a `_Centre` has `scale == null` and is
  performed by the plan's own first fit, take the scale of the page fit
  (`fitToPage`, or `ViewportTransform.fit` of the extents) at `viewport`.
  Add a CM test at two canvas sizes.
- **Docs.** In `centerOn`'s dartdoc and the guide's "A plan's first fit is
  not a request" bullet, say that before a view shows you should pass
  `scale:`, because otherwise the scale is a placeholder.

### F-2 (Low, test gap): G-5's "clipped to the canvas" is unpinned

Mutant **I** removes the `ClipRect` in `PlannerView`
(`Positioned.fill(child: ClipRect(child: layer))` becomes
`Positioned.fill(child: layer)`). It survives the whole overlay suite.

The clip is load-bearing:
- A `natural` badge is shown while any part of it overlaps the canvas.
- The canvas `Stack` does not clip a `Positioned.fill` child that paints
  outside its own box.

So without the clip, a badge on a table near the top edge paints over the
service bar, or over the rulers and panels in the design mode.

My probe X9, an ancestor `ClipRect` check, kills mutant I. **Fix:** a TO
test with a badge straddling the canvas's top edge that asserts the clip,
either as a `ClipRectLayer` whose rect is the canvas or as the ancestor
check.

### F-3 (Low, test gap): `canvasPlaced`'s post-frame `_disposed` guard is unpinned

Mutant **S** drops the `if (_disposed) return;` inside the post-frame
callback of `canvasPlaced(view, null)`. It survives `camera_test`,
`view_test` and `table_overlay_test`.

It is the common host pattern that needs it: a `State` that owns the
controller and disposes it in its own `dispose()`.
- The view's state is disposed first, because children unmount before
  their parents.
- That schedules the null report.
- The controller is then disposed in the same frame.

My probe X8 (`_Owner` holds a controller; then `pumpWidget(SizedBox())` and
a pump) shows it. Under S it fails with `A ValueNotifier<Rect?> was used
after being disposed`, and it passes on the committed code.

**Fix:** land X8 (a host-owned controller and its view going in one frame,
then a pump, then no exception) in `camera_test`.

### F-4 (Low, test gap): overlays keyed by *instance* is not observed when a non-overlaid table precedes others

Mutant **Z** misaligns `tableDetailInstances`: it adds an instance only for
picker candidates. It survives the overlay suite.

This happens because the fixture's hidden `5` precedes `L`, `7` and ` 7 `,
so their keys shift by one slot, but no test observes it:
- The positions come from the values, so they stay right.
- The keys stay unique, so nothing throws.

The user-visible effect would be a badge's `State` jumping to another table
when a table's geometry appears or disappears, for example when a hidden
layer is shown in the design mode with design overlays.

**Fix:** assert that each slot's `ValueKey` equals its table's instance, or
pin `State` identity across a layer toggle with `tableOverlayModes`
including the design mode (`Badge.created` unchanged for `L` and the
`7`s).

### F-5 (Low, P-7): several new names are never used from outside the package

P-7 says every public addition goes into the barrel and `barrel_test`, gets
a guide snippet that is also in the probe, and is used by the demo.

B4 and B5 compile all of them through the barrel. The following names,
however, appear in no guide snippet or probe, and the demo does not use
them:
- `FloorPlanController(minScale:, maxScale:)`
- `panBy` and `globalToWorld`
- `FloorPlanView.userCamera` and `tableOverlayModes`
- `FloorPlanOverlayLayout.interactive`, `size: FloorPlanOverlaySize.box` and
  `hideBelowScale`
- `FloorPlanCamera.canvasToWorld` and `visibleWorld`
- `InputClaim`

The guide describes all of these in prose. The external-host compile (git
dependency, outside the workspace) is therefore not exercised for them.

**Fix, either of:**
- Add one guide and probe block, for example a kiosk
  `FloorPlanView(userCamera: false, tableOverlayModes: {...},
  tableOverlayLayout: FloorPlanOverlayLayout(interactive: true, size:
  FloorPlanOverlaySize.box, hideBelowScale: 0.01))`, a bounded controller
  and a `panBy` button.
- Or record the exemption in the results note and the spec's Review
  section.

### F-6 (Nit): the results note's numbers

- The gate table is "at `59eb206`". The tip adds `84ee8e9`, which changes
  `input_claim.dart` (dartdoc) and the render tests (IC10, IC11), so the
  render suite is **1374** at the tip, not 1372. Cite the tip: this
  review's runs are at `56be3fa`, and so is CI's green run, the 0.3.0 probe
  step included.
- The planner suite is "1436 at `85905bd`". I measured **1437** at `v0.3.0`.
  The worktree was clean, and `1b0c37a..85905bd` is docs only. The demo's
  39 is right.

### F-7 (Nit): STATUS's header still reads "Last updated: 2026-10-08"

STATUS was edited on 2026-10-09.

### F-8 (Nit): a few throws and false returns are undocumented

- `centerOn` throws `ArgumentError` for a world point that is not finite or
  a scale that is not finite and positive. `panBy` throws for a delta that
  is not finite. Neither the CHANGELOG nor the guide says so.
- The guide's `zoomBy` line omits the `false` returned for a focus that is
  not finite.
- The CHANGELOG omits the view's `ArgumentError` for a bad
  `FloorPlanOverlayLayout`. The guide has it.

### Recorded, no action

- **Mutant G** builds the overlay layer inside the controller's
  `ListenableBuilder`, so a new layer widget is made on every controller
  notification. It is near-equivalent. The controller notifies only on
  `setMode`, `load`/`newPlan`, `resetLayout` and `restoreServiceLayout`.
  Each of these remounts the keyed view anyway, with one exception:
  `restoreServiceLayout` while the design mode shows design overlays. There
  the mutant costs one extra build of every overlay, with no wrong output.
- **The design mode with two views also throws a `StateError`** (probe X7:
  `the dispatcher already has an expander`), so the guide's "one view per
  controller" holds in both modes.

## Item 1 — P-1 / invariant 1

**API dump.** I wrote an analyzer 13.3 script (`/tmp/s1-final/apidump/api_dump.dart`).
It resolves each barrel's export namespace and prints, for every exported
element:
- its supertype;
- its class modifiers;
- every public constructor, field, getter, setter and method, with its full
  signature, its default values and its annotations.

I diffed the v0.3.0 dump against the `56be3fa` dump:

| Barrel | v0.3.0 lines | `56be3fa` lines | Removed or changed lines |
|---|---|---|---|
| `jet_cad_floor_plan` | 1215 | 1330 | 4 lines, all explained below |
| `jet_cad_2d_flutter` | 1898 | 1912 | none (only `InputClaim` and `RenderInputClaim` added) |

The 4 floor-plan lines:
- The `FloorPlanController` constructor gains the named optional parameters
  `minScale = kMinScale` and `maxScale = kMaxScale` (0.001 and 100).
- `FloorPlanView`'s constructor gains named optional parameters at the end:
  `userCamera = true`, `tableOverlayBuilder`,
  `tableOverlayLayout = const FloorPlanOverlayLayout()` and
  `tableOverlayModes = const {FloorPlanMode.selection}`.
- The two `@internal final CameraController camera` lines become
  `cameraController`, as documented.

Everything else is an addition:
- the 6 new types;
- on the controller, the public members `camera`, `canvasRect`,
  `worldToGlobal`, `globalToWorld`, `tableDetails`, `tableAt`, `panBy`,
  `zoomBy` and `centerOn`;
- on the controller, the new `@internal` members `cameraEpoch`,
  `owesFirstFit`, `tableDetailInstances` and `canvasPlaced`.

No `==`, `hashCode` or `toString` of an existing type changed, and the
class modifiers did not change. `FloorPlanController` is still a non-final
class extending `ChangeNotifier`, so the CHANGELOG's line about implementers
is right.

**Default behaviour a 0.3.0 host sees.** My probe `zz_p1_probe_test.dart`
ran the same script at v0.3.0 (through `camera`) and at the tip (through
`cameraController`). It covers the Salon, the Teras and an empty plan, at
1300×900, 700×500, 300×200 and 120×90, and prints the camera's six
coefficients (9 decimals) after each of these steps:
- the design start;
- the switch to the selection mode;
- `fitToView`;
- `fitToTables({'7'})`;
- `fitToTables` then `fitToView` in one frame;
- `fitToView`, `fitToTables` and a switch in one frame;
- `load`;
- `newPlan`;
- a remount after `fitToTables({'3'})`.

**All 120 lines are identical**: `diff` exits 0. The 6 test failures at the
smallest sizes are the editor's own RenderFlex overflows, the same at both
commits. So the clamped fits, the first-fit rule and the epoch change no
camera a 0.3.0 host gets, down to a 120-pixel canvas.

The rest of the default behaviour:
- **Overlays.** None without a builder (TO14).
- **`canvasRect`.** Reporting is new state, and nothing a 0.3.0 host calls
  depends on it.
- **The per-frame `_check`.** It runs only for views given a reporter,
  which means `FloorPlanView`, and never requests a frame.

**The probes** (`~/.pub-cache/git/cache/jet-cad-*` cleared first):
```
+ jet_cad_floor_plan 0.3.0 from git ../../.. at 56be3f in packages/jet_cad_floor_plan
/tmp/s1-final/head/tool/ci/host_probe/pubspec.lock: 40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
Analyzing host_probe...
No issues found! (ran in 5.4s)
✓ Built build/web
host probe: no GPU renderer, no build hook; build/web is 42M
host_probe exit 0
```
```
Analyzing host_probe...
No issues found! (ran in 5.3s)
old host probe: v0.3.0's main.dart analyses against 56be3fabfb9ddcf6907bafb4c5cf66c35efe3cc5
old_host_probe exit 0
```
`git status` was clean afterwards, so `main.dart` was put back.

**CI** (`gh run list` / `gh run view`). The run on `56be3fa` succeeded.
Its job "an external host, by git" ran "The 0.3.0 host probe against this
commit", and that step succeeded. Every Slice 1 commit's run is green.

## Item 2 — P-6

- `git diff --stat 85905bd..56be3fa -- '*golden*' '*.png'` prints nothing.
- **The rename.** I took each of the 14 modified test files, mapped
  `cameraController` back to `camera` and stripped all whitespace. Eleven
  files plus the demo test are then **byte-identical** to `85905bd` (md5),
  so the only change is the rename and the formatter's line breaks.
- **The other three files:**
  - `barrel_test`: six names are added to B1's set, and B4 and B5 are
    appended.
  - `controller_test`: one prefixed import is added, CD1 is appended, and
    the rest is the rename.
  - `tool/ci/test/scripts_test.dart`: additions only.

## Item 3 — where the tasks meet (probes `zz_cross_probe_test.dart`, mut clone)

| Probe | What it checks | Result |
|---|---|---|
| X1 | `canvasRect` across `load`, `resetLayout`, a switch and `newPlan`, with a view mounted | No null blip. The new view's fit-and-report callback is registered at layout, before the old view's dispose callback (`finalizeTree`). The listener heard only the switch's rect. |
| X2 | Overlays after a service drop, then `undo`, `redo`, `resetLayout` and `restoreServiceLayout` | Each puts badge `1` at the right place (1e-6 px). |
| X3 | `centerOn(scale: 0.8)` across the breakpoint 0.5 | 7 builds (one per overlay) and the badge on its table. Then `centerOn` followed by `panBy` in one frame: the pan wins (epoch), with 0 builds. |
| X4 | `userCamera: false` with interactive overlays | A tap on a badge reaches only the badge's `onTap` (no `onTableTap`, no selection). A drag from the badge and a drag on the floor leave the camera identical and the history empty. |
| X5 | The controller disposed while a view with overlays is mounted, then unmounted | No exception. |
| X6 | A controller swap under one view with overlays | A's `canvasRect` becomes null, B's is set, and no exception. |
| X7 | Two views on one controller in the design mode | `StateError` (see the Recorded section). |
| X8 | A host-owned controller and its view going in one frame | Clean. Mutant S turns it red (F-3). |
| X9 | An ancestor `ClipRect` of a badge | Present. Mutant I turns it red (F-2). |
| Y1 | `centerOn` before a mount, without a scale | The nominal scale (F-1). |

Read in the code:
- **The overlay layer.** Its sources are `revision`, `selectedTables`,
  `tableFocus`, `tableStatuses`, `tableGroups` and `groupStatuses`.
  `tableDetails`' cache key is (document, `stateId`,
  `tables.mutationRevision`). Every edit that moves one of these goes
  through a command, so `revision` moves: the layer panel's toggles are
  `SetLayerCommand`s.
- **Mode switch and lifetime.** The layer sits inside the view keyed by
  `ObjectKey(document)`, so a switch, a reset, a restore and a load remount
  it, as documented.
- **Notifications during build or layout.** The `_deferred` path moves them
  to the end of the frame.
- **Disposing.** `removeListener` on a disposed `ChangeNotifier` is allowed
  by Flutter (`change_notifier.dart:339-344`). `canvasPlaced` guards both
  of its paths.
- **The static claim record.** It is reviewed in Task 4. The claim sits
  below `InteractionLayer`, `CameraGestureDetector` and `ServiceView`'s
  `Listener` on every path. The design shell adds no raw pointer listener
  above the canvas.

## Item 4 — P-4, the frame path

- **The invariants.** Render `paint_allocation_test` has 2 tests and engine
  `query_allocation_test` has 6 (plus setUpAll and tearDownAll); all report
  `success` in this run's JSON.
- **The overlay layer's per-frame work:**
  - the state's camera listener: an indexed `overlayDetailLevel`, with no
    allocation and no build unless a breakpoint is crossed;
  - the render object's `_onCamera`: arithmetic into the reused
    `Float64List`s, then `markNeedsPaint`/`markNeedsLayout` and
    `markNeedsSemanticsUpdate`;
  - paint: one `Offset` per painted overlay that moved (the accepted R-2
    floor);
  - `box` mode: also a `Size`, a `BoxConstraints` and a relayout per shown
    overlay (documented);
  - TO10 and TO21 pin the counters.
- **Per frame and O(1), only with a `FloorPlanView` mounted:**
  - `PlannerView._check`: one method tear-off for `addPostFrameCallback`,
    plus one `localToGlobal` (a `Matrix4`) and one `Rect`;
  - the public camera wrapper: one `FloorPlanCamera` per camera value, made
    only when someone reads it.
- **Per table, nothing.** Nothing per frame per table remains outside the
  documented paint offset.

## Item 5 — the docs

- **The guide's new section and § 4** were checked claim by claim against
  the code and the probes above, and they hold: the decomposition wording,
  the `canvasRect` timing and the per-mode rule, the commands and bounds,
  the first-fit rule, `tableAt`'s 24 px (`kTouchPickRadiusPixels`), the
  builder's run rule (tear-off included, TO20), placement, detail levels,
  the pointer table, the wheel sentence (Task 4's R-4), lifetime and cost.
  The exceptions are F-1 (the pre-mount `centerOn`) and F-8.
- **`check_guide`:** `docs/host-guide.md: all 22 code blocks are in the host
  probe`.
- **The CHANGELOG** lists every new public name: the six types, the
  controller and view members, and `InputClaim`/`RenderInputClaim` in
  `jet_cad_2d_flutter`. It also gives the rename, the clamped fits with "no
  real plan affected" (supported by the P-1 probe), the 1e-6 floor, the
  first-fit rule and one view per controller. Missing: F-8 only.
- **The results note:** see F-6. Its smoke and cost figures match the Task 5
  report.

## Item 6 — gates (`56be3fa`, `/tmp/s1-final/head`, real tails)

```
packages/jet_cad_floor_plan  flutter test     05:19 +1510: All tests passed!          exit 0
                             flutter analyze  No issues found! (ran in 9.6s)          exit 0
                             format           Formatted 250 files (0 changed)         exit 0
apps/restaurant_demo         flutter test     00:25 +47: All tests passed!            exit 0
                             flutter analyze  No issues found! (ran in 4.7s)          exit 0
                             format           Formatted 5 files (0 changed)           exit 0
apps/floor_planner           flutter test     01:51 +212: All tests passed!           exit 0
                             flutter analyze  No issues found! (ran in 6.1s)          exit 0
                             format           Formatted 47 files (0 changed)          exit 0
packages/jet_cad_2d_flutter  flutter test     01:27 +1366 ~1 -7: Some tests failed.
  expect_failures (path form) packages/jet_cad_2d_flutter: 1374 tests; the standing failures and skips, exactly   exit 0
                             flutter analyze  No issues found! (ran in 7.7s)          exit 0
                             format           Formatted 223 files (0 changed)         exit 0
packages/jet_cad_2d          dart test        00:24 +1253 -2: Some tests failed.
  expect_failures (path form) packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly          exit 0
tool/ci                      dart test        00:06 +62: All tests passed!            exit 0
                             dart analyze --fatal-infos ...  No issues found!         exit 0
                             format (incl. host_probe/lib)  Formatted 11 files (0 changed)  exit 0
check_guide                  docs/host-guide.md: all 22 code blocks are in the host probe   exit 0
```
At `v0.3.0`: planner `04:32 +1437: All tests passed!`, demo
`00:24 +39: All tests passed!`.

## Item 7 — mutants (mine, across task boundaries)

Each mutant was applied by `/tmp/s1-final/mutrun/mutate.py`. The script
copies the file aside, replaces exactly one occurrence (and refuses
otherwise), runs `flutter test --no-pub` on the named tests, restores from
the copy and compares it with the original text. `restored=True` every
time, and I never used `git checkout`.

| # | Where (tasks) | Mutation | Tests run | Result | Killer(s) |
|---|---|---|---|---|---|
| A | controller (T2 × zones) | `_request` bumps the views before the epoch moves | camera, view | **killed** | CM7, CM8, CM11, V7a, V12, V17 |
| B | controller (T2 R-1) | `_command` keeps the dropped request's `_fitTarget` | camera, view, controller | **killed** | CM5 |
| C | view (T2 R-1) | `_fitIsRequest = true` (own first fit treated as a request) | camera | **killed** | CM13 |
| D | controller (T2 R-4) | `setMode` skips the per-mode `canvasRect` | camera | **killed** | CR4 |
| E | planner view (T2 R-3) | `_check` reports before the first fit | camera | **killed** | CM13, CR3 |
| F | planner view (T2 × T3) | `_report` measures the whole `PlannerView`, not the drawing area | camera, barrel | **killed** | CR1, B4, CR4, CR5 |
| G | view (T3 × view) | overlay layer made inside the controller's `ListenableBuilder` | overlay | survived | near-equivalent (see the Recorded section) |
| H | overlay (T3 R-1) | `didUpdateWidget` keeps `_built` | overlay | **killed** | TO15, TO19, TO20 |
| I | planner view (T3, G-5) | no `ClipRect` around the layer | overlay | **survived** | none; my X9 kills it (F-2) |
| J | overlay (T1 × T3, G-5) | the table's status over its group's | overlay | **killed** | TO5 |
| K | overlay (T3 × T4) | interactive children without `InputClaim` | overlay | **killed** | TO28, TO29, TO30, TO31 |
| L | service view (T4) | secondary click ignores the claim | overlay | **killed** | TO28 |
| M | overlay (T1 × T3) | children keyed by number, not instance | overlay | **killed** | TO1–TO6 (duplicate keys) |
| O | demo (T5) | the minutes ticker not cancelled on dispose | badges | **killed** | DB1–DB6 (a pending timer) |
| Q | controller (T2) | `zoomBy` does not move the epoch | camera | **killed** | CM8 |
| Q2 | controller (T2, guide) | `zoomBy` accepts a non-finite focus | camera, barrel | **killed** | CM6 |
| S | controller (T2 × dispose) | the post-frame `_disposed` guard in `canvasPlaced` removed | camera, view, overlay | **survived** | none; my X8 kills it (F-3) |
| U | overlay (T1 × T3) | `FloorPlanTableOverlay.==` ignores `detail` | overlay | **killed** | TO16, TO18, TO27 |
| V | overlay (T3 × groups) | the layer does not listen to `groupStatuses` | overlay | **killed** | TO5 |
| W | overlay (T3 × zones) | `focused` false when no focus is set | overlay | **killed** | TO6 |
| Z | controller (T1 × T3) | `tableDetailInstances` skips non-candidates (misaligned keys) | overlay | **survived** | none (F-4) |

**Score:** 17 of 21 killed by the committed suite. G is near-equivalent.
I and S are killed by my probes X9 and X8, which pass on the committed code.
Z needs F-4's test.

Probe files (not for commit): `/tmp/s1-final/mut/packages/jet_cad_floor_plan/test/zz_p1_probe_test.dart`,
`.../test/host/zz_cross_probe_test.dart`; outputs in `/tmp/s1-final/out/`
and `/tmp/s1-final/mutrun/`.

## Fixes (controller's)

Commit **`98c0c1d`** ("fix: Slice 1 final review findings F-1 to F-5, F-8"),
on `56be3fa`, not pushed. I did not edit any existing test: the four new
tests are appended (CM16 and CR6 in `camera_test`, TO32 and TO33 in
`table_overlay_test`, plus one `dart:ui` import). Each mutant was applied
by a copy-aside script, `scratchpad/mut/mutate.py`. The script replaces
exactly one occurrence, runs `flutter test --no-pub`, restores from the
copy and compares bytes. It printed `restored=True` every time, and I
never used `git checkout`. The working diff was byte-identical before and
after the final mutant run.

### F-1: `centerOn` without a scale, before any view (ruling: fix)

- **Change** (`floor_plan_controller.dart`):
  - `_Centre` carries `pageScale`, set in `centerOn` as
    `scale == null && _fitOnStart`. That means the request was made before
    the plan's own first fit, while the camera holds the 1440×900
    placeholder.
  - `framingFor` then takes the scale of `_pageFit(activeDocument,
    viewport)` at the real canvas. `_pageFit` is now shared with
    `_placeNominally`.
  - With `scale:`, the scale given is used. After the first fit, the
    camera's own scale is used, as before.
- **Docs.** I updated the `centerOn` and `framingFor` dartdoc, spec G-3
  (a new sentence, plus an "Amended by Slice 1's final review" line in the
  Review section), the guide's `centerOn` bullet and the CHANGELOG.
- **Test CM16.** At 600×450 and 1300×900:
  - A reference controller mounted with no request gives the page fit's
    scale. The test checks that it equals `fitToPage` at its canvas.
  - The premise checks that the placeholder scale differs.
  - Then `centerOn(table 7's centre)` is called before the mount, and the
    view is mounted. The test checks that the scale equals the page fit's
    within 1e-15, that `worldToCanvas(7)` is the canvas centre within
    1e-6 px, and that `canvasToWorld(centre)` is 7's centre within 1e-6 mm.
- **Mutant F1:** `pageScale ? _pageFit(…) : scale` becomes
  `false ? _pageFit(…) : scale`, which restores the placeholder scale.
  ```
  F1: KILLED (exit 1)
     red: 00:04 +26 -1: .../camera_test.dart: CM16 centerOn with no scale before the first mount takes the scale of the plan's own page fit at the real canvas, ...
      Expected: a numeric value within <1e-15> of <0.03673333333333333>
      Actual: <0.08142857142857142>
  F1: restored=True
  ```
  These are the review's Y1 numbers: 0.03673, the fit, against 0.08143.
- **Mutant F1b:** `pageScale: scale == null`, which ignores the first-fit
  condition. CM11 kills it: `Expected ... of <0.37>`,
  `Actual: <0.07744761904761904>`. So the branch after the first fit is
  pinned too.

### F-2: the canvas clip (ruling: test, kills I)

- **Test TO33.** The fixture camera is moved up so that table 1's 20 px
  badge spans canvas y from −6 to +14 across the top edge. The bar above
  the canvas is part of the premise. The test then checks two things:
  1. The nearest `ClipRect` above the badge clips (it is not
     `Clip.none`), and its global rect is the canvas's rect.
  2. The painted pixels, from a `RepaintBoundary` around the host captured
     by `OffsetLayer.toImage`, are the badge's blue `3060c0ff` 3 px below
     the edge and not blue 3 px above it.
- **Mutant I:** `ClipRect(child: layer)` becomes `layer`.
  ```
  I: KILLED (exit 1)
     red: 00:05 +32 -1: TO33 a badge straddling the canvas's top edge is clipped to the canvas: it does not paint over the service bar (G-5, final review F-2) [E]
  I: restored=True
  ```
  The red line is the structural check (`Bad state: No element`: no
  `ClipRect` ancestor).
- **What I found.** I removed the structural check and kept only the
  pixel check. Mutant I then **survived** (`I-pixel: SURVIVED`). The
  drawing area's `Flow` in `PlannerView._drawingArea` uses the default
  `Clip.hardEdge`, so it clips to the same rect. In today's tree, I is
  therefore paint-equivalent, so the review's "load-bearing" claim does
  not hold yet. The `ClipRect` still guards against a change of that
  `Flow`.
- **The pixel check is not vacuous.** With `Flow(clipBehavior: Clip.none)`
  and the `ClipRect` kept, TO33 passes. With both removed, it goes red:
  `Expected: not '3060c0ff'  Actual: '3060c0ff'`. The test's comment
  records this.

### F-3: `canvasPlaced`'s post-frame `_disposed` guard (ruling: land X8)

- **Test CR6** is the reviewer's X8. A host `_Owner` State owns the
  controller and disposes it. The premise checks that `canvasRect` was
  reported. Then `pumpWidget(SizedBox())` and a pump run, and
  `takeException()` must be null.
- **Mutant S:** `if (_disposed) return;` is dropped from the post-frame
  callback.
  ```
  S: KILLED (exit 1)
     red: 00:04 +28 -1: .../camera_test.dart: CR6 a host whose State owns the controller disposes it in the frame its view goes: ...
      Expected: null
      Actual: FlutterError:<A ValueNotifier<Rect?> was used after being disposed.
  S: restored=True
  ```

### F-4: overlays keyed by instance (ruling: test, kills Z)

- **Test TO32.** Design mode, with `tableOverlayModes: {design}`:
  1. It collects each badge's `State` by its table's centre, 7 badges with
     5 hidden.
  2. It shows the Hidden layer with `SetLayerCommand(...visible: true)`.
     There are now 8 badges, `Badge.created` rose by exactly 1, and every
     earlier `State` is `identical` at its own table.
  3. It hides the layer again. There are 7 badges, nothing new was
     created, and the same States are identical.
- **Mutant Z:** `instances.add(...)` becomes
  `if (candidates.containsKey(...)) instances.add(...)`.
  ```
  Z: KILLED (exit 1)
     red: 00:07 +31 -1: TO32 each overlay is keyed by its own table's instance: with the hidden 5 before L and the 7s, ... [E]
      Expected: <8>
      Actual: <9>
  Z: restored=True
  ```
  L's State was recreated, and 7's State took L's old one.

### F-5: P-7 coverage (ruling: one kiosk block)

- **The block.** "Your own widgets on the tables" ends with a new **A
  kiosk** block, `KioskFloor`. The same block is appended verbatim to
  `tool/ci/host_probe/lib/main.dart`. It uses:
  - `FloorPlanController(json:, minScale: 0.02, maxScale: 0.5)`;
  - two `panBy` arrows;
  - `globalToWorld` (`floorPointAt`);
  - `camera.value.canvasToWorld` (`middle`);
  - `camera.value.visibleWorld` (`tablesOutOfSight`, in a camera read-out);
  - `FloorPlanView(userCamera: false, tableOverlayModes: const
    {FloorPlanMode.selection}, ...)`;
  - `FloorPlanOverlayLayout(interactive: true, size:
    FloorPlanOverlaySize.box, hideBelowScale: 0.04)`, with an `InkWell`
    per table.
- **Bullets** after the block cover the read-out's rate, the default
  modes written out, the box buttons and `hideBelowScale`, and
  `visibleWorld`'s y-up `Rect`.
- **`InputClaim`.** One sentence in *Pointers* says the layer marks an
  interactive widget with `InputClaim`, a `jet_cad_2d_flutter` name, and
  that a host never needs it. It is exempt from a snippet.
- **Checks:**
  - `check_guide`: `docs/host-guide.md: all 23 code blocks are in the host
    probe`, exit 0.
  - `tool/ci/host_probe.sh file:///home/user/jet-cad 98c0c1d…`:
    ```
    + jet_cad_floor_plan 0.3.0 from git ../../.. at 98c0c1 in packages/jet_cad_floor_plan
    Analyzing host_probe...
    No issues found! (ran in 5.4s)
    ✓ Built build/web
    host probe: no GPU renderer, no build hook; build/web is 42M
    exit 0
    ```

### F-8: throws and false returns (ruling: document)

- **The CHANGELOG's camera bullet** now gives:
  - `panBy`'s `ArgumentError` for a delta that is not finite;
  - `zoomBy`'s `false` for no view, a factor that is not finite and above
    0, or a focus that is not finite;
  - `centerOn`'s `ArgumentError` for a point that is not finite or a
    scale that is not finite and above 0, and F-1's rule.
- **The overlay bullet** names the view's `ArgumentError` for a bad
  `FloorPlanOverlayLayout`: breakpoints that are not finite, positive and
  strictly ascending, or a `hideBelowScale` or `maxNaturalSize` that is
  negative or not finite.
- **The guide's command bullets** give the same throws and `zoomBy`'s
  focus case.

### F-6, F-7

These are the controller's. I did not touch the results note or STATUS.

### Gates (working tree = `98c0c1d`'s content, real tails)

```
packages/jet_cad_floor_plan  flutter test     04:35 +1514: All tests passed!                 exit 0
                             flutter analyze  No issues found! (ran in 5.4s)                 exit 0
                             format           Formatted 250 files (0 changed) in 1.40 seconds. exit 0
apps/restaurant_demo         flutter test     00:25 +47: All tests passed!                   exit 0
                             flutter analyze  No issues found! (ran in 4.2s)                 exit 0
                             format           Formatted 5 files (0 changed) in 0.07 seconds.  exit 0
apps/floor_planner           flutter test     01:35 +212: All tests passed!                  exit 0
                             flutter analyze  No issues found! (ran in 4.4s)                 exit 0
                             format           Formatted 47 files (0 changed) in 0.24 seconds. exit 0
tool/ci                      dart test        00:07 +62: All tests passed!                   exit 0
                             dart analyze --fatal-infos ...  No issues found!                exit 0
                             format (incl. host_probe/lib)  Formatted 11 files (0 changed) in 0.03 seconds.  exit 0
check_guide                  docs/host-guide.md: all 23 code blocks are in the host probe    exit 0
```

I did not touch render (`jet_cad_2d_flutter`) or the engine (`jet_cad_2d`),
so I did not run their standing comparison. No `analysis_options.yaml` is
in the commit, and the tree was clean after the gates.

**Final test counts:**

| Suite | Before | After | Added |
|---|---|---|---|
| Floor plan | 1510 | **1514** | CM16, CR6, TO32, TO33 |
| Demo | 47 | **47** | none |
| Planner | 212 | **212** | none |
| `tool/ci` | 62 | **62** | none |
