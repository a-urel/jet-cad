# Q1+Q2 report: the liveness filter at a wall joint, the palette's drawing flag, two stale comments

**Commits on `fix/post-11`** (not pushed), on top of `47a7fcb`:

- `3ccb191` — `fix(app): a wall-end drag moves live walls only (post-11 (e))`
- `363efd0` — `test(app): pin every palette entry's drawing flag; fix a stale band-rule comment (post-11)`

No engine code changed (`packages/jet_cad_2d/lib` is untouched). `analysis_options.yaml` is not committed. No `.dart` file was checked out.

## Q2: (e), the liveness filter at a wall joint

### What changed
- **The fix, `apps/floor_planner/lib/parametric/wall_grips.dart`, `_endsAt`.**
  - It no longer loops over `withComponent<WallParams>()`. It takes the joint's walls from `wallsInDocument(d, group)` in `opening_geometry.dart`, which `wall_grips` already imports.
  - `wallsInDocument` is the document adapter that the tools, the grips and the panel already share. It returns the host plus every other live wall (`_isLiveGroup`: a root-level `GroupNode`, the engine survey's rule) as a `WorldWall`. `_endsAt` skips degenerate walls as before and still sorts the result.
  - The same predicate is reused, so there is no third spelling of the rule.
  - The class doc and the doc comment on `_endsAt` now say that only live walls follow.
- **Consequence for the dragged wall.** `wallsInDocument` returns null for a host that is not live, so the dragged wall is now filtered too. This is equivalent in practice: the render layer only asks an `ObjectGripProvider` about a root-level group (`grip_cache.dart` ~l.355–360). See M-Q2c below.
- **Comment, `wall_bands.dart:124-127`.** It said "(… on a handle with no node, which no tool or file path makes)". It now says "(… on a handle with no node: no tool makes one, but a file can bring either in)".

### Test: `EG6` in `apps/floor_planner/test/wall_grips_test.dart`
**Fixture.**
- The existing turned L: A, B and C at the far origin, each in its own rotated group, and the plan turned 23°.
- A plain root group 5000 (translated and rotated off the origin), with group 5100 nested under it (also translated and rotated).
- Two stray `WallParams` written straight into the store, as a file brings them in:
  - on handle 5200, which has no node: its start is the corner, in world;
  - on nested group 5100: its end is the corner in world, stored in local space. The test asserts it is more than 1000 mm from the world point, so the group is not at the identity.
- The test asserts that each stray's end lies within `wallJoin.linear` of A's dragged end in world. Only liveness can exclude them.

**What it checks.**
- **Through the select tool** (the real pointer path: `selectWall`, then a mouse `dragWorld`): the commit succeeds (undo depth 1).
  - A's and B's ends land on `q`. B is the live neighbour at the joint, which is the control.
  - A's start and B's end are unchanged.
  - Both strays are `==` to what they were.
  - The corner is still mitred, `drift` is empty, and `diagnostics()` is unchanged.
  - One undo gives `canon(doc) == before`, and the strays are still `==`.
- **The provider directly:** `drag` gives members `[A, B]`, and `preview` gives two lines, A's then B's, with the moved ends at `q`.
- **Limitation:** the select tool keeps `objectPreview` private, so the preview is asserted through the same `WallGrips` provider the shell uses, not read from the painter during the drag.

### Red before the fix
With the test added and `_endsAt` unchanged (at `47a7fcb`), `CI=true flutter test test/wall_grips_test.dart` exited 1 with `+5 -1`:

```
Bad state: "Stretch": floor_planner.wall written on 13EC, which is not a live root-level group after …
```

- 13EC is the nested stray. The select tool's pointer-up rethrows the error.
- After that, `Expected: <1> Actual: <0>` "the commit succeeds" at l.429.
- Transcript: scratchpad `q12-red-before.txt`.

### Mutants
Procedure:
- `cp` each file to scratchpad `q12-<file>.bak`, mutate it, and run `CI=true flutter test test/wall_grips_test.dart`.
- `cp` it back and `diff` against the backup. Every diff exited 0.
- Outputs: `q12-mut-<name>.txt`.

| Mutant | Change | Result |
|---|---|---|
| M-Q2a | `_endsAt` reverted to the unfiltered `withComponent<WallParams>()` loop, i.e. the fix removed | **red** `+5 -1`: `Bad state … written on 13EC`, then l.429 undo depth 0 |
| M-Q2a′ | The filter removed at the shared site (`wallsInDocument`'s walls loop: `if (h != host)`) | **red** `+5 -1`: same, 13EC |
| M-Q2b | Liveness only (`doc.tree[h] != null`), so the nested stray joins | **red** `+5 -1`: `Bad state … written on 13EC` |
| M-Q2d (own) | A node-less handle passes (`tree[h] == null ‖ live`), so the bare stray joins | **red** `+5 -1`: `Bad state … written on 1450` (the node-less stray) |
| M-Q2c | The dragged wall's own liveness check dropped (`wallsInDocument`: `if (p == null) return null;`) | **survives**, and is equivalent (see below) |

**Why M-Q2c is equivalent.** In this code the filter already applies to the dragged wall, because `wallsInDocument` returns null for a host that is not live. So the brief's mutant ("the filter applied to the dragged wall too") is the shipped code, and I ran its inverse. It survives because `grip_cache.dart` calls `gripsOf` only for a selected root-level `GroupNode`, and a drag only starts from one of those grips. The dragged wall is therefore always live.

### The other `withComponent<…Params>()` loops in `apps/floor_planner/lib`
`ComponentStore` has no other iterator the app uses, and `room.dart`'s `view.objectsOf` is the engine's live view. The loops:

| Loop | Filtered? | Path |
|---|---|---|
| `wall_grips.dart` `_endsAt` (`WallParams`) | **fixed here** | edit and preview |
| `wall_grips.dart` `_keptPut` (`OpeningParams`) | yes (inline root-level group check) | edit |
| `opening_geometry.dart` `wallsInDocument` (`WallParams`) | yes (`_isLiveGroup`, host and neighbours) | edit, preview, panel |
| `opening_geometry.dart` `openingsInDocument` (`OpeningParams`) | yes (`_isLiveGroup`) | edit, panel |
| `dimension_attach.dart` `thickestWall` (`WallParams`) | yes (`_isLiveGroup`) | snap and attach |
| `room_inputs.dart` `liveObjectsOf<T>` | yes | room inputs |
| `wall_bands.dart` `_refresh` (`WallParams`) | yes (inline); comment fixed | snap and band survey |

No other gap was found.

## Q1: the palette's drawing flag

**What `drawing` controls.** It is read in one place: `tool_palette.dart`, `ListTile.enabled: !e.drawing || geometryAllowed`. `main.dart`'s `_activate` gates shortcuts on `identical(tool, _select)`, not on the flag.

**Test: `A12b` in `apps/floor_planner/test/planner_draw_test.dart`.**
- A `const` table maps each key to its drawing flag: `tool-select` false, and all 14 others true.
- The palette's keyed `ListTile`s must be exactly the table's keys (`unorderedEquals`). A key missing from either side fails. The Fill toggle's inner `ListTile` has no key and is skipped.
- With every permission (geometry allowed, asserted), every entry is enabled.
- Under `DraftPermissions.runtime` (geometry denied, asserted), each entry is checked by key: drawing tools are disabled and Select is enabled.
- The test imports `package:floor_planner/tool_palette.dart`.

**Mutants.** Each flipped `drawing:` in `lib/main.dart` and ran `CI=true flutter test test/planner_draw_test.dart --plain-name A12`, then `cp` back. Every `diff` exited 0.

| Mutant | Result |
|---|---|
| Dimension `drawing: false` | **red** `+1 -1`: A12b l.375 "tool-dimension draws: disabled". A12 alone passes, which confirms the gap existed. |
| Wall (07) `drawing: false` | **red** `+1 -1`: A12b l.375 "tool-wall draws: disabled" |
| Door (08) `drawing: false` | **red** `+1 -1`: A12b l.375 "tool-door draws: disabled" |
| Separator (10) `drawing: false` | **red** `+1 -1`: A12b l.375 "tool-separator draws: disabled" |
| Select `drawing: true` | **red** `+0 -2`: A12 l.322 and A12b l.375 "tool-select: enabled" |

## The render layer's stale comment
`packages/jet_cad_2d_flutter/lib/src/select_tool.dart`, the doc of `_everyLeafIn` (~l.483–489). It now names the leaves the picking filter rejects as "hidden, on a locked layer, or not pickable (`EntityFlags.unpickable`, spec 11 D19)", and says "a group with one locked or not-pickable leaf". The change is to the comment only. I checked `QueryFilter.picking()` (`excludeUnpickable: true`) and `acceptsEntity` to confirm the new wording.

## Gates (`export PATH=/root/flutter/bin:$PATH`, at `363efd0`)
- **Render** (`packages/jet_cad_2d_flutter`):
  - `CI=true flutter test`: exit 1, `+940 ~1 -7`. The seven failures are exactly the standing `text ladder rung 1–5` and `text lod ladder rung 1–2` (canvas).
  - `flutter analyze`: exit 0, "No issues found!"
  - `dart format --set-exit-if-changed`: exit 0, "0 changed".
- **App** (`apps/floor_planner`):
  - `CI=true flutter test`: exit 0, `+493: All tests passed!` That is 491 plus EG6 plus A12b.
  - `flutter analyze`: exit 0, "No issues found!"
  - `format`: exit 0, "0 changed".
  - `flutter build web --release`: exit 0, "✓ Built build/web".
- **At the Q2 commit (`3ccb191`)**, before Q1: app `+492: All tests passed!` (exit 0), analyze exit 0, format exit 0.
- **Engine:** not run, because no engine file changed.

Transcripts: scratchpad `q12-gate-render.txt`, `q12-gate-app.txt`, `q12-gate-web.txt`, `q12-app-q2.txt`.

## Deviations
1. **Reuse through the adapter.** `_endsAt` reuses `wallsInDocument`, the shared document adapter, rather than calling a bare predicate. That adapter also filters the dragged wall itself. This is equivalent under the render layer's contract (M-Q2c).
2. **The preview assertion goes through the provider.** It is checked through `WallGrips.preview`, the same provider, not read from the select tool mid-drag. The tool keeps `objectPreview` private, and the render layer was to get a comment-only change.
3. **Mutant M-Q2c ran as its inverse**, because the brief's form is the shipped code. I also added M-Q2d (a node-less handle passes).

## Outside scope (reported, not fixed)
- `_keptPut` in `wall_grips.dart` and `wall_bands.dart` still spell the root-level-group check inline. That makes two more copies next to the private `_isLiveGroup` in both `opening_geometry.dart` and `dimension_attach.dart`, and the public `liveObjectsOf<T>` in `room_inputs.dart`. All agree today. Folding them into one public predicate would be a refactor and is not in this fix.
- `flutter test` ran `pub get` once ("Resolving dependencies…"). `git status` stayed clean apart from my edits, and no `analysis_options.yaml` shows as modified.
