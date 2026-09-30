# Q1+Q2 review: 3ccb191 and 363efd0 (fix/post-11)

Reviewed in the detached worktree `.claude/worktrees/fix-post-11-review` at `363efd0`. Nothing was committed. The only change in `git status` is the standing pub-get rewrite of `packages/jet_cad/analysis_options.yaml`, which I did not touch. My probe file (`apps/floor_planner/test/q12r_probe_test.dart`) was removed before the gates ran. A copy is in scratchpad as `q12r_probe_test.dart`, and all transcripts are in scratchpad as `q12r-*.txt`.

## Verdict: **Approved**

Neither commit has an Important finding. Q2 closes (e): with Q3's guard in place, the wall-end drag through the select tool no longer throws on a file's stray `WallParams` at the joint, whether the stray is on a node-less handle or on a nested group. EG6 is non-degenerate and kills the filter's removal. A12b pins every palette entry by key. Both comment changes are true.

There are three Minor findings. m1 is a survivor on the shared predicate: a root-level instance holder is not pinned. m2 is a place where the adapter's rule differs from the engine's: a shadowed component. With a file's dangling reference, m2 can still throw out of a wall drag. The same throw happens at 47a7fcb, so it is not a regression. It is reported for a ruling. m3 is cosmetic.

## (1) Q2: the liveness filter

- **The adapter matches the engine's object rule except for shadowing.**
  - The engine's `_isObject` (regeneration.dart l.11–17) requires three things: `node is GroupNode`, `node.parent == root`, and a registered component.
  - `wallsInDocument` applies `_isLiveGroup` (opening_geometry.dart l.700–703), which checks the same node and parent. It runs over `withComponent<WallParams>()`, so the component condition holds too.
  - The difference: the engine's `_survey` lets the **later registration name the object**, and keeps an earlier registration's component as `stray`. The catalog registers Box, Wall, Opening, Separator, Room, Dimension in that order. So a root-level group carrying both `WallParams` and `OpeningParams` is an *opening* to the engine and a *wall* to the adapter. See m2.
  - All five spellings of the rule share this difference.
- **The dragged wall's own filter is harmless.**
  - `grip_cache.dart` l.353–360 asks the provider only about a selected root-level `GroupNode`. No other path in the render layer reaches `ObjectGripProvider.drag` or `preview` (`grip_drag.dart` l.237 and l.286 only use captured grips).
  - Probe PR3 calls the provider directly on a nested group's `WallParams`: `grips 2; drag null; preview 0`. At 47a7fcb the same call gave `drag Instance of 'CompoundCommand'; preview 1`, a command the engine would now refuse. So filtering the dragged wall turns an unreachable refusal into an unreachable no-op. That is fine.
- **The whole wall-end drag path tolerates both kinds of stray.**
  - **Preview:** `_endsAt` is cached per (document, grip).
  - **Commit:** through the select tool.
  - **`_keptPut`:** openings are filtered inline. `layoutInDocument`'s `moved` now holds live walls only.
  - **Undo:** EG6 checks each of these on both kinds of stray, and I re-ran it green.
  - **Red before:** see M-Q2a below. Pointer-up rethrows the `StateError` from `select_tool.dart:424`.
- **Other paths that gather walls.** None can throw through the select tool on a node-less or nested stray.
  - **Walls:** only end grips; there is no length or justification grip. The panel's length and justification edits write only the pinned live target (`selection_panel.dart` l.409 and l.694, `_isObject<WallParams>`).
  - **Openings:** `OpeningGrips` reads `wallsInDocument` and `openingsInDocument`, and writes only its own opening.
  - **Dimensions:** `DimensionGrips._pointOf` null-checks `wallsInDocument`. In `dimension_attach.attachCandidates`, the one `wallsInDocument(...)!` (l.159) runs only after `_isLiveWall`. The Dimension tool l.479 null-checks.
  - **Separators:** read `WallBands`, which is filtered.
  - **Rooms:** read `liveObjectsOf`.
  - **Move and rotate:** these touch only the selected root-level group.
  - The implementer's table of `withComponent` loops is correct. The one exception is the shadowed case (m2).

## (2) EG6 and the mutants

EG6's fixture is non-degenerate:
- A turned L far from the origin, with each wall in its own rotated group.
- A translated and rotated root group, with a translated and rotated nested group under it. The nested stray's stored end is more than 1000 mm from its world point, and the test asserts this.
- Both strays are asserted within `wallJoin.linear` of A's world end, so only liveness separates them from the joint.
- B is the live control.
- The test also checks `==` on the strays, drift, diagnostics, and `canon` after undo.

| Mutant | Change | Run | Result |
|---|---|---|---|
| M-Q2a | `wall_grips.dart` replaced by its 47a7fcb content (the unfiltered `_endsAt`) | `wall_grips_test.dart` | **red** `+5 -1`: EG6, `Bad state: "Stretch": floor_planner.wall written on 13EC …`. Thrown from `SelectTool.onPointerUp (select_tool.dart:424)`, then `Expected: <1> Actual: <0>` "the commit succeeds" |
| M-Q2b | `wallsInDocument`'s neighbour filter: `_isLiveGroup(doc, h)` → `doc.tree[h] != null` | same | **red** `+5 -1`: `Bad state … written on 13EC` (the nested stray) |
| M-R1 (own) | `_isLiveGroup`: `node is GroupNode && …` → `node != null && …` | `wall_grips_test.dart`; then the **whole app suite** | **survives**: `+6: All tests passed!`, then `+493: All tests passed!` Not equivalent: probe PR1 goes red under it (m1) |

Every mutant followed the same procedure:
- `cp` the file to a scratchpad `q12r-*.bak`, mutate it, and run with `CI=true`.
- `cp` it back and `diff` against the backup. Every diff exited 0.
- No `git checkout` was used.

## (3) Q1: A12b

- `drawing` is read in one place: `tool_palette.dart` l.63, `enabled: !e.drawing || geometryAllowed`.
- A12b's `const` table lists all 15 `keyName`s from `main.dart`, with Select false and the others true.
- It asserts the palette's keyed `ListTile`s `unorderedEquals` the table, both with every permission and under `DraftPermissions.runtime`. The permissions are asserted too.
- `CheckboxListTile('tool-fill')` is not a `ListTile`, and its inner tile has no key, so it is skipped correctly.

| Mutant | Result |
|---|---|
| Window (08) `drawing: false` (main.dart l.196) | **red** `+1 -1`: `Expected: <false> Actual: <true>` "tool-window draws: disabled" |
| Circle `drawing: false` (l.231) | **red** `+1 -1`: "tool-circle draws: disabled" |
| Missing key: `'tool-gap': true,` deleted from A12b's table | **red** `+0 -1`: `Which: has too many elements (15 > 14)` |

I ran these with `--plain-name A12` for the flips and `--plain-name A12b` for the missing key.

## (4) The two comments

- **`wall_bands.dart` l.124–128:** "no tool makes one, but a file can bring either in" is true.
  - `ComponentStore.loadJson` (component.dart l.178–197) attaches every component by handle without checking its holder.
  - No engine command re-parents a node: `commands.dart` has Add/Remove/Transform node only. No app tool groups objects.
- **Render layer, `select_tool.dart` `_everyLeafIn` (l.483–490):** true.
  - `QueryFilter.picking()` sets `excludeUnpickable = true`.
  - `FilterEvaluator.acceptsEntity` rejects `EntityFlags.unpickable` first.
  - `_everyLeafIn` skips on `!acceptsEntity(slot, picking())`.
  - The engine's `_bandDescend` applies `acceptsEntity` (spatial_index.dart l.568).

## Minor

**m1: the `GroupNode` type check in the shared predicate is unpinned.**
- M-R1 survives the whole app suite. A file can carry `WallParams` on a **root-level `InstanceNode`**. The engine does not treat that as an object.
- **Repro (probe PR1):**
  - Instance 5300 at the root, translated and rotated. It carries `WallParams` whose start is on A's corner in world.
  - At HEAD: the select-tool drag commits, the stray stays `==`, and undo restores `canon`.
  - Under M-R1: `Bad state: "Stretch": floor_planner.wall written on 14B4, which is not a live root-level group …`, rethrown from pointer-up, undo depth 0.
- **At 47a7fcb:** PR1 fails the same way (`q12r-probe-47a.txt`).
- **Suggestion:** add a root-level-instance stray to EG6's fixture. It is a third holder kind next to the node-less and nested ones, and one more `attach` would kill M-R1 for all users of `_isLiveGroup`.

**m2: shadowing. The adapter's "live wall" is not exactly the engine's object rule.**
- **What happens:** a root-level group carrying `WallParams` and a later-registered component (`OpeningParams`) is an opening object to the engine. `wallsInDocument`, `WallBands`, `thickestWall` and `liveObjectsOf<WallParams>` treat it as a wall, and `ObjectGrips._of` gives it wall grips. Only a file makes this shape.
- **Probe PR2** (the opening regenerated on live wall C, then the `WallParams` attached as a file would):
  - The drag's command is `[1300, 2600, 5500]` and the preview has 3 lines. The shadowed `WallParams` follows the joint.
  - The commit succeeds: `_written` skips object handles. Undo restores `canon`. This is a phantom, not a throw.
- **Probe PR2d** (the same group, but the file's `OpeningParams` names a host that does not exist, 0x7777):
  - The select-tool drag of **wall A's** corner throws `DanglingReferenceError: 157C references 7777, which is not a live parametric object` from pointer dispatch (`tester.takeException()`).
  - Undo depth is 0 and nothing moves.
  - PR2 and PR2d behave identically with 47a7fcb's `_endsAt` (`q12r-probe-47a.txt`). This is **pre-existing, not a regression**, and it is the one throw I found on a user's drag after this fix.
- **Proposed ruling:** record it as found, not fixed. Only a file makes it, and it needs two parametric components on one group, one of them with a dangling reference. Fixing it means an app-side "which registration names this object" rule shared by all five spellings, which is the same refactor already recorded as debt.

**m3: `gripsOf` still reads the unfiltered `_world`.**
- On a non-live holder it offers two grips whose `drag` is null (PR3). This is unreachable, because the grip cache asks only root-level groups. Filtering it the same way would keep the provider self-consistent.
- Optional.

## Gates (`export PATH=/root/flutter/bin:$PATH`, at 363efd0, probe file removed)

- **Render** (`packages/jet_cad_2d_flutter`):
  - `CI=true flutter test`: exit 1, `01:05 +940 ~1 -7: Some tests failed.` The seven failures are exactly `text ladder rung 1–5` and `text lod ladder rung 1–2` (canvas), all standing.
  - `CI=true flutter analyze`: exit 0, "No issues found!"
  - `CI=true dart format --output=none --set-exit-if-changed .`: exit 0, "Formatted 177 files (0 changed)".
- **App** (`apps/floor_planner`):
  - `CI=true flutter test`: exit 0, `03:08 +493: All tests passed!`
  - `CI=true flutter analyze`: exit 0, "No issues found!"
  - `CI=true dart format --output=none --set-exit-if-changed .`: exit 0, "Formatted 102 files (0 changed)".
- Web build and engine were not run: no engine file changed, and web is outside this review's gate list.

## The report checked against evidence

- The hashes and the file lists match `git show`.
- The red-before, M-Q2a and M-Q2b claims reproduce, with the same stray (13EC) and the same line.
- The palette flips reproduce on entries the implementer did not flip (Window, Circle), and the missing-key claim holds.
- M-Q2c's equivalence argument holds (PR3 and grip_cache l.353–360).
- The claim "no other gap" holds for node-less and nested strays. It misses the shadowed case (m2), which is pre-existing.
