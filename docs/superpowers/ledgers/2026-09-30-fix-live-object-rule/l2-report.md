# L2 report: every app spelling of "a live T" now goes through the engine's rule

**Commit:** `980947d` on `fix/live-object-rule`, on top of L1's `e0a56d0`. Not pushed.
`packages/jet_cad/analysis_options.yaml` is the standing pub-get rewrite. It is not committed.

## The module
`apps/floor_planner/lib/parametric/live_objects.dart` (new). It has no Flutter import.
- `bool isLiveObject<T>(DraftDocument doc, Handle h)` is `parametricCatalog.names<T>(doc, h)`.
- `List<Handle> liveObjectsOf<T>(DraftDocument doc)` is `parametricCatalog.objectsOf<T>(doc)`. It returns handles in ascending order, following the store's contract as L1 found it.
- It adds no caches. `ParametricView.objectsOf` (matching by `is`) is not used anywhere in the app.
- `liveObjectsOf` moved here from `room_inputs.dart`. Its callers now import the module: `room_inputs.dart`, `room_tool.dart`, and the tests `room_tool_test`, `separator_tool_test`, `dimension_tool_test`.

## The seven spellings (all converted)
| # | Site | Now |
|---|---|---|
| 1 | `opening_geometry.dart` `_isLiveGroup` | Removed. `wallsInDocument`: host `isLiveObject<WallParams>` (l.714), others `liveObjectsOf<WallParams>` (l.720). `openingsInDocument`: `liveObjectsOf<OpeningParams>` (l.752). |
| 2 | `dimension_attach.dart` `_isLiveGroup`, `_isLiveWall` | Removed. `thickestWall` uses `liveObjectsOf<WallParams>` (l.40). Walk 1 uses `isLiveObject<WallParams>(owner)` (l.124). Walk 2 asks for **a live opening**, `isLiveObject<OpeningParams>(owner)` (l.132), then the host `isLiveObject<WallParams>` (l.134). |
| 3 | `wall_grips.dart` `_keptPut` | `liveObjectsOf<OpeningParams>(d)` (l.85). |
| 4 | `wall_bands.dart` cache build | `liveObjectsOf<WallParams>(doc)` (l.130). |
| 5 | `room_inputs.dart` `liveObjectsOf` | Moved into the module. `RoomInputs._refresh` (l.300, l.311) and `room_tool.dart` (l.278, l.352) call it. |
| 6 | `selection_panel.dart` `_isObject<T>` | `isLiveObject<T>(widget.document, h)` (l.301). |
| 7 | `object_grips.dart` `_of` | `isLiveObject<…>` per type (l.81–85). At most one type names a group, so the order no longer matters. The provider is always the naming type's. |

## The grep of `apps/floor_planner/lib` (every other `get<…Params>` / `withComponent` / `paramsOf`)
**Converted (the read decided what a handle is):**
- `selection_panel.dart` `_valid` (Position): the old check was `get<WallParams>(o.host) == null`, which decides "is the host a wall". It is now `!_isObject<WallParams>(o.host)`.
  - This changes behaviour: before, an opening whose host was a shadowed group (an opening to the engine) accepted any position in `[0, L]` and wrote it. Now the field reverts.
  - This is killed by M-L2-6p (below).
- `dimension_attach.dart` walk 2: `get<OpeningParams>(owner)?.host` after a bare live-group check became `!` after `isLiveObject<OpeningParams>` (row 2).

**Fine: a read of a handle already known to be a live T:**
- `dimension_attach.dart` `_onALine` (l.174) and `_parallelMeasure` (l.265). Their handles are candidate walls from the two walks.
- `wall_grips.dart` `_keptPut`'s `old` (l.77) and `_moved`'s `base` (l.191). Their handles come from `_endsAt`, which reads `wallsInDocument`.
- `room_inputs.dart` l.300, l.311 and `room_tool.dart` l.279, l.353: reads right after `liveObjectsOf`.
- `selection_panel.dart` l.284, 287, 355, 362, 370, 374, 385, 395, 407, 418, 563, 609, 687, 706, 794, 802: reads of the target that `_selected`, `_read` or `_isObject` just found live, or of the tool-settings target.
- The providers' own reads. `ObjectGrips` constructs these providers, and nothing else in `lib` does, so `_of` has already asked the module before any of these runs:
  - `opening_grips.dart` l.100 (`movable`) and l.112 (`_Slide.of`, which also requires membership in `openingsInDocument`);
  - `room_grips.dart` l.95 and l.110;
  - `separator_grips.dart` l.64, l.83, l.108;
  - `dimension_grips.dart` l.186.
- `ParametricView.paramsOf` in `opening_geometry.dart` l.605/611/650, `opening.dart` l.195, `dimension.dart` l.294–295, `wall.dart` l.139, `room_inputs.dart` l.142 and `box.dart` l.61. Each reads the survey's snapshot of the **naming** registration's component, which is the engine's rule itself. These are not app spellings.
- `PageComponent` reads on the root (page_panel, dimension_grips, room_grips, dimension_tool). These are not object decisions.

No site was unclear. No `node.parent == …root` or `get<T>(h) != null` type decision is left in `lib` outside the module.

## Tests (all in `apps/floor_planner/test`)
**Fixture** (`wall_grips_test.dart`, `shadowDoc`). The L is A 1300, B 2600 and C 3900, each in its own rotated group far from the origin.
- **`shadow`** (0x157C): a real door on C, regenerated through the dispatcher. `WallParams` is then attached through the store: 400 thick, from the L's corner (on the joint, in world) to a point of the door's own children.
  - With `dangling: true`, its `OpeningParams` is then rewritten to name host 0x7777 (PR2d).
- **`sep`** (0x15E0): a real separator, then `OpeningParams` (host B) attached.
- Both groups are translated and rotated. Neither handle is the lowest.

**Tests:**
- **EG7 (PR2d, end to end through the select tool):** the drag of A's corner throws nothing (`tester.takeException()` is null). It lands one undo step, A and B follow, the shadow's two components are `==` their loaded values, and undo restores `canon`.
- **EG8 (PR2):**
  - `WallGrips.drag`'s children are `[wa, wb]` (neither the shadow nor `sep`). The preview is exactly A's and B's two lines.
  - Through the select tool: no exception, one step, and every component of `shadow` and `sep` is `==` its loaded value. Undo restores `canon`.
- **EG9 (opening everywhere, wall nowhere):**
  - `wallsInDocument(shadow)` is null, `wallsInDocument(C).walls` is `[A, B]`, `openingsInDocument(C)` is `[shadow]` and `openingsInDocument(B)` is empty.
  - `WallBands.hostAt` at a point in the shadow's band only is null (control: A).
  - `thickestWall` is 200, not 400. `attachCandidates` at the shadow's tip has no shadow entry (control: A's end).
  - `RoomInputs.inputOf(shadow)` is null, while `inputOf(sep)` and `inputOf(A)` are not.
  - `ObjectGrips` gives the shadow `OpeningGrips`' grips (non-empty) and `movable` false. It gives `sep` the separator's two grips and `movable` true.
  - Panel: the shadow shows the Opening section and not the Wall section. `sep` shows neither.
  - Panel Position: an opening (0x1644, attached as a file) hosted on the shadow refuses 50 (unchanged, undo depth 0). The shadow's own position 650 commits one step.
- **AM7** (`dimension_attach_test.dart`, all six placements): AM6's flush free door gets `SeparatorParams` through the store. Before the attach, `A/0/centre` is a candidate (premise). After it, A is not a candidate at that point. Only walk 2 reached it.

**Red before the fix** (the new tests run against the tree before the fix, `l2-red-before.txt`): `+6 -3`.
- EG7 at l.596: `Expected: null  Actual: DanglingReferenceError: 157C references 7777, which is not a live …`
- EG8 at l.626: `Actual: [1300, 2600, 5500, 5600]`
- EG9 at l.665 (before the orphan lines were added): `wallsInDocument(shadow)` was not null.

AM7 was written after the fix. Its red-before is M-L2-2o and M-L2-2 below: the pre-L2 walk code, 6 of 6 red.

## Mutants
Procedure for every mutant:
- `cp` the file to `…/scratchpad/l2-mut/<M><tag>-<file>.bak` (one backup per file per run), mutate, and run `CI=true flutter test --no-pub test/wall_grips_test.dart test/dimension_attach_test.dart`.
- `cp` back and `diff` against the backup. **Every diff exited 0.**
- Logs are `…/l2-mut/<M>-final.log`. Lines are those of the committed tests.

| Mutant | Change (that site alone, back to pre-L2) | Result |
|---|---|---|
| M-L2-1 | `opening_geometry` `_isLiveGroup` restored in `wallsInDocument` and `openingsInDocument` | red `+31 -3`: EG7 l.596 (DanglingReferenceError), EG8 l.626 `[1300, 2600, 5500]`, EG9 l.676 |
| M-L2-1b (own) | `openingsInDocument` alone | red `+33 -1`: EG9 l.680 (`openingsInDocument(B)` lists `sep`) |
| M-L2-2 | `dimension_attach` `_isLiveGroup`/`_isLiveWall` restored at all three sites | red `+27 -7`: EG9 l.692 (`Actual: <400.0>`), AM7 l.997 ×6 |
| M-L2-2t (own) | `thickestWall` alone | red: EG9 l.692 |
| M-L2-2w (own) | walk 1 alone | red: EG9 l.695. `_wallPointsOf` (dimension_attach.dart:159) null-checks the shadow's `wallsInDocument` and throws |
| M-L2-2o (own) | walk 2 alone (live group + `?.host`) | **survived** the first run (`+9`, EG7–EG9 only), a finding. The fixture was fixed with AM7: red `+28 -6`, AM7 l.997, `Actual: [18]` |
| M-L2-3 | `_keptPut` bare live-group opening walk | red `+33 -1`: EG8 l.626 `[1300, 2600, 5600]` |
| M-L2-4 | `wall_bands` bare live-group walk | red: EG9 l.687 `Actual: <5500>` |
| M-L2-5 | `RoomInputs._refresh` on the old `liveObjectsOf` body | red: EG9 l.705 `Actual: RoomInput(157C, band, …)` |
| M-L2-6 | `_isObject` old body | red: EG9 l.728 (`wall-section` found) |
| M-L2-6p (own) | `_valid`'s host check back to `get<WallParams> == null` | **survived** at first, a finding. The fixture was fixed with the orphan in EG9: red, l.750 `Actual: … window on 157C at 50.0` |
| M-L2-7 | `_of` first-match `get != null` order | red: EG9 l.715 `Actual: []` (the wall provider gives no grips) |
| M-Q2a (fix/post-11) | `_endsAt` over the unfiltered `withComponent<WallParams>()` | red `+31 -3`: EG6 l.527 (`Bad state: "Stretch": floor_planner.wall written on 13EC …`, undo depth 0), EG7 l.596, EG8 l.626 |
| M-R1 (fix/post-11, now in the engine) | `regeneration.dart` `_naming`: `node is! GroupNode` → `node == null` (engine file mutated temporarily, restored, diff 0) | red `+33 -1`: **EG6 l.536**. The root-level instance's stray `WallParams` is moved. The app still catches it, beside L1's LO3 |

## Cost
- `isLiveObject` is O(registered types = 6). `liveObjectsOf` is O(k · 6) plus the store's sort. No caches were added.
- None of it is on the frame path:
  - **The band cache** calls `liveObjectsOf` only in `_refresh`, past `if (!_stale) return;` at `wall_bands.dart:121`. `_stale` is set only by `invalidate()` (l.45), which the document's `changes` listener (l.118) and the tools call. A scan per pointer move reads the cached doubles.
  - **The dimension attach walk** runs on pointer moves, edits and grip drops (spec 11), never per frame. It calls `isLiveObject` once per owner slot found by the two rect queries.
  - **`ObjectGrips._of`** runs on grip-cache rebuilds and on drag/preview/movable, which are pointer events.
  - **The panel's `_isObject`** runs in widget rebuilds (selection and document changes).
- The invariant tests (`query_allocation_test`, `paint_allocation_test`) are untouched. Neither the engine nor the render layer changed.

## Gates (`export PATH=/root/flutter/bin:$PATH`, `CI=true`, at the committed tree)
- **Render** (`packages/jet_cad_2d_flutter`):
  - `flutter test` exit 1, `00:54 +940 ~1 -7: Some tests failed.` The seven are exactly the standing `text ladder rung 1–5` and `text lod ladder rung 1–2` (canvas).
  - `flutter analyze` exit 0, "No issues found!"
  - `dart format` exit 0, "Formatted 177 files (0 changed)".
- **App** (`apps/floor_planner`):
  - `flutter test` exit 0, `02:30 +512: All tests passed!` That is 503 + EG7–EG9 (3) + AM7 (6 placements).
  - `flutter analyze` exit 0, "No issues found!"
  - `dart format` exit 0, "Formatted 104 files (0 changed)".
  - `flutter build web --release` exit 0, "✓ Built build/web".
- **Engine:** no file changed (`git diff e0a56d0 HEAD --stat -- packages/` is empty), so it was not re-run.
- Transcripts are in the scratchpad as `l2-gate-*.txt`.

## Deviations
1. **Purity (Ruling 11-2) needed two import changes and a pubspec line.**
   - The problem: `catalog.dart` imports `dimension.dart` and `room.dart`, which imported `package:flutter/foundation.dart` only for `visibleForTesting`. So the pure files the brief routes through the module (`opening_geometry.dart`, `dimension_attach.dart`, `room_inputs.dart`) would have imported Flutter transitively. That breaks the dimensions plan's binding "pure, transitively" rule.
   - The fix: both files now take `visibleForTesting` from `package:meta/meta.dart`, and `meta: ^1.18.0` (already resolved, 1.19.0, a dependency of `jet_cad_2d`) is added to `apps/floor_planner/pubspec.yaml`. `pubspec.lock` is unchanged.
   - The whole import closure of `live_objects.dart` passes the plan's Part B grep (exit 1, no match).
   - If this is unwanted, the alternative is to move the catalog into a file of its own, or accept the transitive Flutter import. I chose the smallest change that keeps the invariant.
2. **Four extra mutants (M-L2-1b, -2t/-2w/-2o, -6p) and two extra tests (AM7, the Position check in EG9).**
   - Two sub-sites were uncovered by EG7–EG9: the attach's opening walk and the panel's Position host check. Both needed a group whose `OpeningParams` is shadowed by a *later* type, which the Wall+Opening shadow cannot give.
   - Per the testing bar, the fixture was fixed rather than the mutant accepted.
3. **The tests live in `wall_grips_test.dart`, as EG7–EG9.** They need its shell helpers (`gripDoc`, `pumpGrips`, `dragWorld`), and Ruling 11-22 forbids importing one test file from another. AM7 is in `dimension_attach_test.dart` beside AM6, whose fixture it reuses.

## Found outside scope (reported, not fixed)
- **Stored drawings go stale after a shadowing attach.** A file's shadowed group keeps the children generated for its earlier type until something regenerates it. Examples: AM7's door children after `SeparatorParams` is attached, and C's cut for a door that the engine now calls a separator. `drift()` would list them. This is L1's rule applied as designed, but the stale drawing and its snap points stay in the file until an edit touches the group.
- **L1's note on `ParametricView.objectsOf<U>` (`is` matching) still stands.** No app code calls it.
- **06 D8's cleanup** still detaches only the naming registration's component on delete (from fix/post-11's list, untouched).
