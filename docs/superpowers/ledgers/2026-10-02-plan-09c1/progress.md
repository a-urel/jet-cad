# Plan 09c-1 — progress ledger

**Plan:** docs/superpowers/plans/2026-10-02-wall-attach.md (cut at `904970d`).
**Spec:** docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md rev 4 (`751755f`), approved 2026-10-02.
**Branch:** `plan-09c/wall-attach`, worktree `.worktrees/plan-09c1`.
**Branch point gates** (main `4d6b78f`, this container, Flutter 3.47.2): engine 1,226 + 2 standing; render 1,187 + 1 skip + 7 standing; app 993.

## Tasks

| Task | Implementer commits | Review | Status |
|---|---|---|---|
| 1 Engine: definition removal takes components (D11) | `a5a6b35`, `48c8d57`, `9414208` (1b) | Needs fixes (3 minor: sort order and restore atomicity untested; stale placer comment) -> 1b Approved | done |
| 2 Symbol box (D2) | `31d098d` | Approved (differential vs engine arcBounds: 0 mismatches over the asset and 10,000 arcs) | done |
| 3 Content, families, wall tag (D2, D9) | `a6ef0bc`, `7dbfc88` (3b) | Needs fixes (major: the 27 old symbols' drawings unpinned — a wardrobe `<=` mutant survives the suite; minor: R03d duplicate family tag untested) -> 3b Approved | done |
| 4 Wall faces (D3) | `e73621f` | Needs fixes (major: the T side test's local-vs-world unkilled — fixtures rotate the host only 17°; minor: a face with two cuts untested); differential 7,634 runs, 0 failures -> 4b `54eab37` Approved | done |
| 5 Generalised placement transform (D5) | `bb39637`, `274c780` (5b) | Needs fixes (major: the press and release placement refreshes untested — both deletions survive); differential 1,860,000 doubles, 0 mismatches -> 5b Approved | done |
| 6 attachToWall, neighbours, WallFaces (D4) | `e188ef1` (on wip/09c1-t6) | Needs fixes (4 minor: both-ends neighbour rule, isOrthonormal's orthogonality clause, edge-snap tie untested; a closure in the edge-snap step allocates per call); property check 22,500 queries / 75 scenes, 0 failures -> 6b `e9b0a52` Approved; cherry-picked as `7b26eb7`, `b3284f1` | done |
| 7 Tool attaches (D6) | `2a1f8c2` | Approved (no findings; 18 of 19 mutants red, the survivor is R-C7-3's accepted shell-level M-09c-ap) | done |
| 8 Wheel zoom (D12) | `7150bd1` | Needs fixes (major: the release's `_track` untested; minor: `_onArmed` re-resolves around `_update`, a hazard once Task 7 adds the attachment there) -> 8b `bdff57d` Approved | done |
| 9 Leaf-equal reuse (D10) | `a073fb5` | Needs fixes (major: base point moved only in y; ascending-handle pairing unguarded — slot free list is LIFO, fixtures have no holes; minor: 'first in ascending handle' unpinned) -> 9b `5f4c235` (cherry-picked as `90f0d97`) Approved | done |
| 10 Search text (D13) | `f424f9b` | Approved (no findings; 14 mutants red) | done |
| 11 End to end, results, ledger | `8f5f601` (11a, end to end) | covered by the final whole-branch review + `c1ea23c` (11b, results note, spec amendment, roadmap) | final whole-branch review: Ready (48 mutants, 47 red, 1 mis-aimed survivor red at unit level); its nit fixed in `e322811` | done |

## Rulings (with cost-if-wrong)

- **C-0 (controller):** Task 5 (generalised transform) precedes Task 6 (attachToWall), swapped before the plan's commit so Task 6 calls `placementTransform(rotation:)` directly. Cost if wrong: none.
- **R-C1-1 (accepted by the Task 1 review):** a snapshot's unknown payloads keep the registry's oldest-first order (registered components by type id). Cost if wrong: one sort and one expectation. Spec wording amendment at execution.
- **R-C1-2 (accepted):** P13's setup writes the orphan after the removal (the orphan a pre-09c file may carry). Cost if wrong: setup order only.
- **R-C1-3 (accepted):** public `ComponentRegistry.detachAll(Handle)`; the inverse is `AddDefinitionCommand(definition, components: snapshot)`. Cost if wrong: a rename.
- **R-C1-4 (accepted):** undoing a plain `AddDefinitionCommand` now needs `components` (its inverse is the static-capability Remove). Only `structure: true, components: false` is affected; no preset or app code builds it (review). Record in the spec's "Amended at execution".
- **R-C2-1 (accepted):** point, text, attrib, fill leaves and malformed payloads are skipped by the box. Cost: one case.
- **R-C2-2 (accepted):** box functions return `SymbolBox?`; null means "does not attach" (Task 6 must treat it so, never `!`).
- **R-C2-3 (accepted):** clockwise arcs handled (superset).
- **R-C2-4 (accepted):** stale task number in the plan note (WallFaces is Task 6).
- **N-2 (Task 2 review):** the box's arc rule duplicates the engine's `arcBounds`; they agree exactly today (differential). If one changes, the other must follow.
- **N-3 (Task 2 review):** `backCentre` allocates a Vector2 per call: Task 6 must not call it per neighbour per pointer move.
- **R-C3-1 (accepted):** new family members copy their family's plain tags (search expectations moved accordingly).
- **R-C3-2 (accepted):** family members sit together in the catalog, ascending by width; library handles shift; nothing depends on them (gallery/thumbnail ids are key@version; placer copies with fresh handles) — checked by the Task 3 review.
- **R-C3-3 (accepted):** `againstWallTag` and `familyTagPrefix` consts live in `symbol_library.dart`; Tasks 6, 7 and 09c-2 must use them, not literals.
- **Look item (Task 3 review note 4):** the 2400 wardrobe has handles only beside its first door division (doors 3 and 4 have none): for the human's look list.
- **Note (Task 3 review):** the new symbols' interior drawings are not pinned (only boxes, per spec); accepted.
- **R-C4-1..4 (accepted by the Task 4 review):** `faceRunsOf(doc, wall, {accept})` + pure `faceRunsAmong(host, walls)`; runs left face first then right, ascending along d, `FaceSide` enum; T/X role recomputed with `strictlyInside` for walls `obstaclesOf` names; B's frame among host + others sorted by handle.
- **Found (Task 4 review differential, inherited from 07/08, not D3):** runs extending into a neighbour under the mirrored fallback; an untrimmed T stem drawn by 07; a wall end poking into a band off the centreline not counted as an obstacle by 08; a wall ending inside the band past the centreline classified as an X by 08, over-cutting a face by ~85 mm. Candidates for the results note's found-not-fixed and the human's look (Task 11).
- **Confirmed pre-existing (Task 4 review):** mirrored walls never draw joined corners (688/688 mirrored frames fell back); wall_geometry/opening_geometry identical to main.
- **R-C5-1..5 (accepted by the Task 5 review):** `at` stays required when `transform` is given (ignored); the ghost keeps the earlier Transform2 on equal doubles; no unit-length check on `rotation` (Task 6 must pass a normalised t); two @visibleForTesting getters on the tool; the ghost tests moved in Task 5, not 6.
- **Fixture (Task 3b):** `apps/floor_planner/test/fixtures/furniture_pre_09c.jetlib` = main `4d6b78f`'s asset byte for byte; Task 11's pre-09c plan test uses it (`pre09cLibrary()` in furniture_library_test.dart).
- **C-1 (controller, process):** two `flutter test` runs at once in one worktree share `build/unit_test_assets` and produce spurious `Asset 'shaders/ink_sparkle.frag' not found` failures (Task 10 report). From now on, concurrent agents run gates and mutants in their own detached scratch worktrees, or the controller serialises them. Task 10's implementer ran `git checkout --` in its own throwaway scratch worktree (forbidden by the rules); nothing in the plan worktree was touched; recorded as a process slip.
- **R-C10-1 (accepted by the Task 10 review; spec D13 amendment owed at Task 11):** the document host (not the shell) owns the search controller, passing it through the shell; a bare shell owns its own. Reason: the host keys the shell by its document (12a D2), so a shell-owned controller cannot survive a document change as D13 requires. Cost if wrong: one field moves into the shell. Spec wording amendment at execution if accepted.
- **C-2 (controller, process):** Task 6 runs in its own worktree `.worktrees/plan-09c1-t6` on a temporary branch `wip/09c1-t6` cut from the plan tip, because Task 9 is working in the plan worktree at the same time; its commits are cherry-picked onto `plan-09c/wall-attach` by the controller (disjoint files). Cost if wrong: a cherry-pick conflict, resolved by hand.
- **R-C10-2 (accepted):** SymbolPanel.didUpdateWidget moves its listener to a new controller.
- **C-3 (controller):** Task 8 runs before Task 7 (Task 6 is still in progress, Task 8 does not need it). The camera listener re-resolves through the tool's one recompute path; Task 7 adds the attachment to that path, so M-09c-ak (zoom re-resolve skips the attachment) is fired in Task 7, not 8. Cost if wrong: one mutant moves task.
- **R-C9-1..3 (accepted by the Task 9 review):** records compared by their own `==` after normalising handle/owner/geomIndex (EntityRecord.== covers all 15 fields); entry leaves paired in list order; the text-style case does not assert validate().
- **Note for 09c-2 (Task 9 review):** `SymbolEntry`'s ascending-handle order is not enforced by its constructor; D7's size change must sort the entry side or assert the order.
- **Note for Task 11:** stale comment at `symbol_placer_test.dart:891-892` ("a record has no ==, a payload compares by identity").
- **R-C8-1..3 (accepted by the Task 8 review):** a disarm removes the listener but keeps the ghost; a re-arm re-listens (and, after 8b, re-resolves through `_update`); `_context` kept apart from `_listening`.
- **Note (Task 8 review):** each camera change allocates two Vector2 (screenToWorld); off the paint path. No camera test brings an object-snap point into the aperture or uses the zoom-adaptive grid; Task 7 or 11 may add such fixtures.
- **R-C6-1..6 (accepted by the Task 6 review):** neighbours as lists parallel to runs with per-entry handles; the |s| and distance keys tie within wallJoin.linear (a geometric decision, O16 shows it is needed); -0.0 cleaned only in placementTransform; wall_attach imports symbol_placer (Flutter-free); closed overlap, front-centre test, engine picking filter; WallFaces API names.
- **Notes (Task 6 review):** the tolerant ranking is not transitive within 1e-6 mm; WallFaces is stale until another tool's change is delivered (Task 7 invalidates on its own commit); a rebuild is O(walls²).
- **R-C8b-1 (accepted by the Task 8 re-review):** a re-arm with a listened context always re-resolves through `_update`, including entry->entry; with none it only refreshes the placement.
- **Owed to Task 7 (from 8b):** the mutant "the re-arm re-resolve skips the attachment" (symbol_place_tool.dart ~l.161), fired with a re-arm between a tagged and an untagged entry near a face, next to M-09c-ak. F3 does not refresh the ghost today (8b's re-arm test relies on it); if Task 7 makes F3 refresh it, that fixture assertion changes.
- **C-4 (controller):** Task 6's commits cherry-picked onto the plan branch as `7b26eb7` (e188ef1) and `b3284f1` (e9b0a52); the four files are byte-identical to e9b0a52; the combined tip passes the app gates (`+1152: All tests passed!`, analyze clean, format 0 changed). Task 9b's `5f4c235` was cherry-picked as `90f0d97` (byte-identical test file).
- **C-5 (controller, verified):** `drawSnapMarker` draws nothing for `SnapKind.nearest` (`snap_marker.dart:56-60`, "Not in kDragSnapMask"), so spec D6/D8's "the SnapKind.nearest glyph" (S-10) rested on a false premise. R-C7-1 (an app-side hourglass `drawNearestMarker`) is the faithful fix while the render layer is frozen; spec amendment at execution owed (Task 11); the glyph goes on the human's look list.
- **R-C7-1..4 (accepted by the Task 7 review):** app-side hourglass marker; keys re-ask the faces with the stored query (no re-snap); M-09c-ap killed at the tool level only; a refused placement does not invalidate the bands.
- **Notes (Task 7 review):** the tool tests do not use mirrored/scaled wall groups (Task 6 covers the geometry; the end-to-end test may add one); after toggling F3 a key press keeps the stored flag until the pointer moves (as 8b recorded), a release always recomputes.
- **R-C11a-1..3 (proposed, to the final review):** one L scene covers both faces (30° wall's outside for the bed, inside for the units); flushness within 1e-9·|run.a| (~1.2e-4 mm), abutment 1e-9 absolute; the pre-09c plan is built in the test with today's codec (09c-1 changed no file schema), one instance per key.

## Close

Final whole-branch review on `c1ea23c`: **Ready**. Nit fixed in `e322811`. Ledger archived to `docs/superpowers/ledgers/2026-10-02-plan-09c1/` as the branch's last commit. Merge, the human's look, STATUS and the roadmap's merged state are the human's word.
