# L2 review: independent review of `980947d`

**Verdict: Approved.** There are no Important findings. The five minor findings below are about test coverage and documentation. None of them is a defect in `lib`.

**Where it was reviewed:** the detached worktree `fix-live-object-rule-review` at HEAD `980947d`, on top of L1's `e0a56d0`. I committed nothing and pushed nothing. After my runs, the only tracked change is the standing pub-get rewrite of `packages/jet_cad/analysis_options.yaml`. The web build's `build/` directory is git-ignored. My scratch files are under `…/scratchpad/l2r-*`.

## 1. Completeness: every type or liveness decision in `apps/floor_planner/lib`

I ran my own greps over all of `lib`, not only `lib/parametric/`:
- `parent ==` / `parent !=` / `GroupNode` / `rootHandle` / `.root`;
- every `get<…Params>(`, `withComponent<`, `objectsOf<` and `paramsOf<`;
- every other `components.` or `tree[` use.

`main.dart`, `planner_view.dart`, `page_panel.dart`, `tool_palette.dart` and `startup_plan.dart` contain no type or liveness decision:
- `startup_plan.dart` and the tools only *construct* groups.
- The root reads (`page_panel`, `room_grips:164`, `dimension_grips:178`, `dimension_tool:444`) read `PageComponent`.
- No `node.parent == …root` or type-deciding `get<T> != null` is left outside `live_objects.dart`.

Verdicts per site, checked by reading each one:
- **The seven spellings:**
  - All seven are converted as the report's table says.
  - The line numbers match: `opening_geometry` 714/720/752, `dimension_attach` 40/124/132/134, `wall_grips` 85, `wall_bands` 130, `room_inputs` 300/311, `room_tool` 278/352, `selection_panel` 301, `object_grips` 81–85.
  - The module is exactly `parametricCatalog.names<T>` and `objectsOf<T>`. I read both in L1's `parametric_system.dart:506,517`.
- **Walk 2 in `dimension_attach`:** it now asks "is this a live opening" (`isLiveObject<OpeningParams>`), then "is its host a live wall". This is correct.
- **`selection_panel`:** `_valid` Position is converted. The `_read` and `_write` reads (l.285–421) and the build reads (l.790–800) follow `_selected` or `_isObject`, or read the tool-settings target. They are fine.
- **Dimension ends resolve through `wallsInDocument`:** `dimension_grips._pointOf` (l.212) and `dimension_tool` (l.479). Both go through the module.
- **Provider reads** (`opening_grips` 100/112, `room_grips` 95/110, `separator_grips` 64/83/108, `dimension_grips` 186):
  - These are fine. `ObjectGrips` is the only constructor of the providers in `lib`: `main.dart:272` builds `ObjectGrips`, and nothing else calls `WallGrips(`, `OpeningGrips(` and so on.
  - Every public entry point goes through `_of`.
- **`ParametricView.paramsOf` and `ParametricView.objectsOf`** read the survey's naming component, which is the engine's rule. See minor finding m3.

**Behaviour for app-made documents (one type per group):**
- `isLiveObject<T>` is the old "root-level group carrying `T`" whenever the group carries one registered type. `liveObjectsOf` keeps ascending order, the store's contract, the same as the old sort.
- **`_of`:** before, it did not check liveness. The groups the select tool asks about are root-level, and the app puts components nowhere else. So the provider is the same for every group the app can make, and `movable` is too.
- **Position:** for an app-made opening, the host is a live wall, or it was deleted and 06 D8 detached its `WallParams`. The old and new checks agree in both cases.
- The full app suite passes: 503 existing tests and the 9 new ones.

## 2. The shadow is the later type's object everywhere

**The fixture is not degenerate:**
- Every group is translated and rotated (`shadow` −0.4 rad, `sep` 0.9, `orphan` 1.3) and sits far from the origin.
- The handles 0x157C, 0x15E0 and 0x1644 are not the lowest.
- The shadow's `WallParams` is attached through the store onto the joint. EG7 and EG8 assert that premise, and EG9 asserts its tip.

**Red before the fix** (my own run):
- I wrote `e0a56d0`'s version of every changed `lib` file over a copy of the tree (a `cp -a` backup of `lib`, restored afterwards, `diff -r` exit 0).
- `wall_grips_test` + `dimension_attach_test`: `+25 -9`.
  - EG7 l.596: `DanglingReferenceError: 157C references 7777`.
  - EG8 l.626: `[1300, 2600, 5500, 5600]`.
  - EG9 l.676: `wallsInDocument(shadow)` is not null.
  - AM7 997:7, six times: `Actual: [18]`.
- This confirms the report.

**Mutants I fired myself:**
- Each one: `cp` a backup, mutate, run `CI=true flutter test --no-pub`, `cp` back, then `diff`. **Every restore diff exited 0.**
- Unless noted, the tests were `test/wall_grips_test.dart test/dimension_attach_test.dart`.

| Mutant | Change | Result | Red test, line |
|---|---|---|---|
| M-L2-1 | `opening_geometry`: `_isLiveGroup` restored in `wallsInDocument` (host + others) and `openingsInDocument` | `+31 -3` | EG7 l.596 (DanglingReferenceError), EG8 l.626 `[1300, 2600, 5500]`, EG9 l.676 |
| M-L2-2o | `dimension_attach` walk 2 alone: live group + `?.host` | `+28 -6` | AM7 997:7 ×6, `Actual: [18]` |
| M-L2-3 | `wall_grips` `_keptPut`: live-group walk over `withComponent<OpeningParams>` | `+33 -1` | EG8 l.626 `[1300, 2600, 5600]` |
| M-L2-4 | `wall_bands`: live-group walk (wall_grips_test only) | `+8 -1` | EG9 l.687 `Actual: <5500>` |
| M-L2-5 | `room_inputs`: both calls on the old `liveObjectsOf` body (wall_grips_test only) | `+8 -1` | EG9 l.705 `RoomInput(157C, band, …)` |
| M-L2-6 | `selection_panel` `_isObject`: old body (wall_grips_test only) | `+8 -1` | EG9 l.728 (`wall-section` found) |
| M-L2-6p | `_valid` Position: `get<WallParams>(o.host) == null` (+ selection_panel_test) | `+39 -1` | EG9 l.750 `window on 157C at 50.0` |
| M-L2-7 | `object_grips` `_of`: the five first-match `get != null` lines | `+33 -1` | EG9 l.715 `Actual: []` |
| M-Q2a | `_endsAt` over unfiltered `withComponent<WallParams>()` | `+31 -3` | EG6 l.527 (undo depth 0), EG7 l.596, EG8 l.626 |
| **M-L2-5t (mine)** | `room_tool` `_cacheFace` + `_nextName` on the old body (+ room_tool_test, room_inputs_test) | **survives**, `+22` | none: see m2 |
| **M-RV-narrowBands (mine)** | `wall_bands`: live group **and** skip a group carrying `OpeningParams` (a fix of the reported pair only) | EG9 green; red only with my scratch RV1 | RV1 l.794 `Actual: <6699>` |
| **M-RV-narrowAdapter (mine)** | `wallsInDocument`'s other walls: live group and no `OpeningParams` | EG9 green; red only with RV1 | RV1 l.788 `[2600, 3900, 6699]` |

**My scratch test RV1** (appended to `wall_grips_test.dart` for these runs only; the file was restored, `diff` 0):
- The group is a **dimension** (0x1A2B), rotated 0.7 rad and translated. It is regenerated through the dispatcher, then `WallParams` is attached through the store onto A–B's joint.
- On the committed code RV1 passes (`+1`):
  - `wallsInDocument(dim)` is null, and A's other walls are `[wb, wc]`;
  - the band cache's `hostAt` in its band is null;
  - `thickestWall` is 200;
  - `WallGrips.drag` of A's corner writes `[wa, wb]`;
  - `ObjectGrips` gives it the dimension's 3 grips;
  - the panel shows `dimension-section` and not `wall-section`.
- So the engine's rule holds for another pair too.

## 3. The `selection_panel` Position change

It is correct and intended.
- **Before:** an opening whose host is a shadowed group (an opening to the engine) accepted any value in `[0, L]` of the stray `WallParams`. It wrote a position for a host the engine regenerates as an orphan.
- **Now:** such an opening's field reverts.
- Only a file can make this case (§1). It is pinned by EG9 l.750 (M-L2-6p).

## 4. Deviation 1: `package:meta`

- **Why the switch was needed:** `catalog.dart` imports `dimension.dart` and `room.dart`. At `e0a56d0` both imported `package:flutter/foundation.dart` for `visibleForTesting`, so the switch was needed to keep Ruling 11-2's pure files pure.
- **Purity:** I computed the transitive import closure myself, with a script that follows relative imports. The roots were `dimension_geometry`, `dimension_attach`, `wall_geometry`, `opening_geometry`, `room_trace`, `room_label`, `room_inputs` and `live_objects`.
  - The closure has 15 files.
  - Its external imports are only `dart:async`, `dart:math`, `dart:typed_data`, `jet_cad_2d`, `meta` and `vector_math`. There is no `package:flutter` and no `dart:ui`.
- **Lock:** `pubspec.lock` is git-ignored (`.gitignore:3`). A fresh `flutter pub get` left it byte-identical (`diff` exit 0). `meta` 1.19.0 was already resolved.
- **Web build:** passes (§6).

## 5. Cost

Nothing new is on the frame path:
- The band cache calls `liveObjectsOf` only in `_refresh`, past `if (!_stale) return;` (`wall_bands.dart:121`). `_stale` is set only by `invalidate()` (l.44–45), which the `doc.changes` listener (l.118) and the tools call.
- `thickestWall` and `attachCandidates` are called from the dimension tool (l.244/253/285/366/380, memoised) and the dimension grips (l.119/159/243). Those are pointer events and grip drops.
- `_of` runs on grip-cache rebuilds and pointer events. `_isObject` runs on panel rebuilds.
- Per call the cost is O(registered types = 6), and no cache was added.
- The invariant tests are unchanged, and no engine or render file changed (`git diff e0a56d0 HEAD --stat -- packages/` is empty).

## 6. Gates (run by me, `CI=true`, `PATH=/root/flutter/bin:$PATH`)

- **App:**
  - `flutter test` exit 0, `02:33 +512: All tests passed!`
  - `flutter analyze`: "No issues found!"
  - `dart format`: "Formatted 104 files (0 changed)", exit 0.
  - `flutter build web --release` exit 0, "✓ Built build/web".
- **Render:**
  - `flutter test` exit 1, `00:56 +940 ~1 -7: Some tests failed.` The seven failures are exactly `text ladder rung 1–5` and `text lod ladder rung 1–2` (canvas), the standing ones.
  - `flutter analyze`: "No issues found!"
  - `dart format`: 177 files, 0 changed, exit 0.
- **Engine** (unchanged since `e0a56d0`):
  - `dart test` exit 1, `+1095 -2`. The two failures are the standing `generate_document_test.dart` pair: l.59 "byte for byte" and "both text fractions default to zero". This matches L1.
  - `dart analyze`: "No issues found!"
  - `dart format`: 158 files, 0 changed, exit 0.

## 7. Spec amendments

The amendments in 06 (Box section), 07 (Wall section), 08 (the document adapter l.684, kept-put openings l.1090, the Opening section and Position l.1280, `ObjectGrips` dispatch l.1336), 10 (Room section) and 11 (candidate walls l.1025, Dimension section) are accurate. Each cites a test that exists and pins it: EG8, EG9 or AM7.
- The 08 dispatch note ("before, the first component found (the wall's) won") is true of the old `_of`.
- None of them over-claims. One sentence was missed: m4.

## Minor findings

- **m1: the suite pins only two shadow pairs.**
  - EG7–EG9 use Wall+Opening, and Separator+Opening for `sep`. A partial fix that special-cases `OpeningParams` survives the committed suite at the band cache and the document adapter (M-RV-narrowBands, M-RV-narrowAdapter). Only a shadow of another pair, such as my RV1 (a dimension carrying `WallParams`), kills them.
  - The committed code is right; this is a test gap. It would be worth landing an RV1-like case: a room or dimension group carrying `WallParams`.
- **m2: `room_tool.dart`'s two converted sites (`_cacheFace` l.278, `_nextName` l.352) are not pinned.**
  - M-L2-5t survived (`+22`, all pass). The brief's "one site per spelling" is met for spelling 5 through `room_inputs` (M-L2-5), so this is minor.
  - A Room+Dimension file group would pin them: it is a dimension, so it neither occupies a face nor reserves `Room N`.
- **m3: one claim in the report is wrong.**
  - The report says "`ParametricView.objectsOf` (matching by `is`) is not used anywhere in the app". `room.dart:404` (`_sharing`) calls `view.objectsOf<RoomParams>()`.
  - There is no defect: it reads the survey's naming component, and `RoomParams` is a `final class` (`room.dart:34`), so `is` is exact there. But the grep list omitted the site.
- **m4: `2026-09-25-openings-design.md` l.1196–1198 was not amended.**
  - It says the band cache "holds live walls only, root-level groups (Task 9 review m5)", which is now incomplete: a shadowed `WallParams` is excluded too.
  - The code comment at `wall_bands.dart` was updated, but the spec sentence was not.
- **m5: cosmetic.**
  - `wall_grips.dart` l.22's doc-comment line is 87 columns ("…ascending by handle, each written back").
  - The 11 amendment has one line over 80 columns ("as amended), asked through `live_objects.dart`: a file's group carrying `WallParams`").
