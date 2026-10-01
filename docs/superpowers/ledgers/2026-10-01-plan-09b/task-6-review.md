# Task 6 review (independent) — df916b7
Status: in progress
- Diff 8a44a5c..df916b7: 2 new app files only (lib/symbols/symbol_place_tool.dart, test/symbols/symbol_place_tool_test.dart).
- Delivery (interaction_layer.dart:128-190): one active pointer; a second primary down while one is active is dropped by the layer (:130); moves of the active pointer go to onPointerMove, a move losing the primary is an up (:144-146); hover only with no active pointer (:176); exit only with no active pointer (:188); pointer cancel -> tool.cancel (:169-172) and clears _activePointer; a tool-side cancel (tool switch, Esc) leaves _activePointer set, so the pointer's later moves (primary set) and up still arrive: the tool ignores them (symbol_place_tool.dart:148, :156). Second pointer / exit mid-press cannot reach the tool; a hover after a placement moves the ghost (buttons 0 passes :148).
- Snap args (symbol_place_tool.dart:116-130) match PlacementTool (placement_tool.dart:112-134) minus self-snap and ortho: aperture kSnapAperturePixels/scale, objectSnap ctx.snap?.objectSnap ?? true, gridStepMm dragGridStepMm(page, scale). Placement uses _at.point (:163), the same point the ghost and marker read.
- App gate (real): `03:33 +841: All tests passed!`; `No issues found!`; `Formatted 149 files (0 changed)` fmt=0; `✓ Built build/web`.
- M-09b1 (:161 no resolve at up): RED (Expected 81375.3 Actual 80125.3). M-09b16 (:163 raw): RED x2+ (Actual 81377.9). M-09b17 (:123): RED x2 (Expected 73250.5 Actual 73300.3). M-09m (:79): RED. restored diff=0 each
- M-09b18 exit (:171): RED. M-09b18 cancel (:188): RED x2. M-09b19 (:44): RED x2 (Expected [false] Actual []). extra cancelled moves followed (:148): RED. restored diff=0 each
- extra idle not inert on down (:134): RED (Expected empty Actual [true,false]). extra stroke not scaled (:229): RED (Expected 30.0 Actual 1.5). restored diff=0 each
- HUNT object snap toggle ignored (:124 `objectSnap: true`): SURVIVED `+14: All tests passed!` (the rig has no ctx.snap). restored diff=0 -> finding 1
- HUNT adaptive grid dropped (:126 `page?.gridStepMm`): SURVIVED +14 (the fixture page has a fixed 25 mm step, so dragGridStepMm returns it). restored diff=0 -> finding 1
- extra re-arm keeps the press (:109): RED (Expected [false] Actual [true]). hunt no notify on down (:140): RED (Expected [true] Actual []). hunt cursor basic (:83): RED. restored diff=0 each
- hunt paint guard without `entry == null` (:221): does not compile (entry nullable) — invalid; entry and path are null together (_syncPath), so equivalent anyway.
- Paint allocations read: no Path/Transform2/Float64List/Paint per paint; GhostMatrix.update with unchanged inputs is compare-and-return (symbol_ghost.dart:131-139); the cross allocates 4 ui.Offset per paint (O(1), not per entity; spec names Path/Transform2/matrix only) — note.
- Final git status --short: empty.

## Verdict: Needs fixes (test-only)
1. MAJOR test/symbols/symbol_place_tool_test.dart (code symbol_place_tool.dart:124,126): the snap wiring to the user's settings is untested. `objectSnap: true` (OSNAP toggle ignored) and `gridStepMm: page?.gridStepMm` (zoom-adaptive grid dropped) both survive, because the rig has no `ctx.snap` and its page has a fixed step. Fix: (a) a rig with `SnapSettings(objectSnap: false)` where the near release lands on gridOf(near), not E; (b) a page with no fixed gridStepMm where the release lands on the adaptive step dragGridStepMm(page, 0.05) computes (assert that step differs from 25 and from the raw point).
2. NOTE (:234-237): the cross allocates four Offsets per paint; O(1), within the non-negotiable; could be hoisted later.
Judgments: R-B6-1 (no cancelled flag; pressed moves/up with no live press ignored) is right given the layer keeps _activePointer after a tool-side cancel (interaction_layer.dart:169-172 vs a tool cancel); R-B6-2 (re-arm keeps turns/mirror) acceptable, spec silent, Task 7 owns the keys; R-B6-3 (ghost not re-resolved on wheel zoom) acceptable known limit, the next pointer event fixes it, same as PlacementTool when idle.

## Re-review (6b) — 76e5f8b (parent 67688a1)
- Diff: only apps/floor_planner/test/symbols/symbol_place_tool_test.dart (+42 -5): Rig gains objectSnap/step options (defaults unchanged), two new snap tests; no Task 7 test touched.
- App gate (real): `02:56 +859: All tests passed!`; `No issues found!`; `Formatted 149 files (0 changed)` fmt=0.
- Mutants (scratchpad/rb6b, restored diff=0 each):
  - `objectSnap: true` (:139): RED "with object snap off (F3), a release near E lands on the grid" (`Expected: <73300.3> Actual: <73250.5>` = E)
  - `gridStepMm: page?.gridStepMm` (:141): RED "with no fixed grid step ... zoom-adaptive step" (`Expected: <81500.3> Actual: <81377.9>` = raw)
- Fixtures honest: snap off asserts placed == gridOf(near), != e0, != near; adaptive: page.gridStepMm null asserted, step from dragGridStepMm asserted != 25, expected point asserted != raw and != the 25 mm grid point.
- git status --short: empty.
### Verdict (6b): Approved
