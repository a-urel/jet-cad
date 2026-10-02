# Plan 09c-1 results — wall-aware placement

**Branch:** `plan-09c/wall-attach`, cut from `spec-09c/wall-aware-symbols`
at `904970d` (the commit after the plan's `7c81751`, recording the branch
point's gates; the spec branch was cut from `main` at `4d6b78f`, the merge
that records 12b). **Spec:**
[2026-10-02-wall-aware-symbols-design.md](../specs/2026-10-02-wall-aware-symbols-design.md),
revision 4 (`751755f`), approved by the human on 2026-10-02 ("yaz",
`4a6c33d`), amended at execution (its closing section). **Plan:**
[2026-10-02-wall-attach.md](../plans/2026-10-02-wall-attach.md) (09c-1:
spec D2–D6, D9–D13). **Ledger:**
[`ledgers/2026-10-02-plan-09c1/`](../ledgers/2026-10-02-plan-09c1/)
(`progress.md` carries every ruling with its cost-if-wrong; the directory is
created by a later commit, which archives the ledger, so the link resolves
only after that commit).

09c-1 is the first of the two plans of slice 09c. A symbol the catalog tags
`against-wall`, armed in the Symbols tab, lands flush on the face of a
visible, unlocked wall when the raw pointer comes within 16 px of it: its
back on the drawn face, turned to the wall (at any angle, not only quarter
turns), its sides snapping to the face's drawn end and to other symbols
against the same face, kept within the face; `M` mirrors it in place, `R`
waits until the ghost leaves the face, F3 off disables it. The catalog grows
from 27 to 41 symbols (six size families, a dishwasher and a washing
machine, the `against-wall` and `family:<id>` tags; loader rule R03d). Four
debts close: a removed definition takes its components (engine, D11), a
definition whose leaves differ from the library's is not reused (D10), the
ghost follows a wheel zoom (D12), the search text survives a tab switch and
a document change (D13). The engine changes in Task 1 only; the render
layer is untouched; everything else is in `apps/floor_planner`
(`symbol_box.dart` and `wall_attach.dart` new, both Flutter-free). No schema
change. 09c-2 (the Symbol section, the wall-aware move, D7, D8) is a later
plan.

Every task had a fresh implementer and an independent reviewer who re-ran
the gates and re-fired the mutants in a detached worktree. Task 6 ran in its
own worktree on `wip/09c1-t6` and Task 9b on `wip/09c1-t9b` while other
tasks used the plan worktree (C-2); their commits were cherry-picked (C-4).
**The final whole-branch review** (a fresh reviewer, a detached worktree,
on the tip after this note) **is still to come**; its verdict, its fixes
and its sample on the tip are recorded by the commit that applies them.

| Task | Commits | Review |
|---|---|---|
| 1 Engine: a removed definition takes its components (D11) | `a5a6b35`, `48c8d57`, `9414208` (1b, test and a placer comment) | Needs fixes (3 minor: the snapshot's type-id sort and restore's all-or-nothing unpinned, both survivors; a stale placer comment) -> 1b Approved |
| 2 The symbol's local box (D2) | `31d098d` | Approved (the reviewer's differential against the engine's `arcBounds`: 0 mismatches over the asset and 10,000 random arcs) |
| 3 Content, families, the wall tag (D2, D9) | `a6ef0bc`, `7dbfc88` (3b, test-only) | Needs fixes (major: the 27 old symbols' drawings unpinned, a wardrobe `<=` mutant survived the whole suite; minor: R03d's duplicate family tag untested) -> 3b Approved |
| 4 Wall faces (D3) | `e73621f`, `54eab37` (4b, test-only) | Needs fixes (major: the T side test's `toLocal` vs `toWorld` unkilled, every host group turned only 17°; minor: a face with two cuts untested); the reviewer's differential 7,634 runs, 0 failures of D3's own rule -> 4b Approved |
| 5 The generalised placement transform (D5) | `bb39637`, `274c780` (5b, test and a doc comment) | Needs fixes (major: the press and release placement refreshes untested, both deletions survived); the reviewer's differential 1,860,000 doubles, 0 mismatches -> 5b Approved |
| 6 `attachToWall`, neighbours, `WallFaces` (D4) | `e188ef1` + `e9b0a52` (6b) on `wip/09c1-t6`, cherry-picked as `7b26eb7`, `b3284f1` | Needs fixes (4 minor: the both-ends neighbour rule, `isOrthonormal`'s orthogonality clause and the edge-snap tie untested; a closure in the snap step allocated per call); the reviewer's property check 22,500 queries over 75 scenes, 0 failures -> 6b Approved (bitwise-identical numbers on the new code) |
| 7 The placement tool attaches (D6) | `2a1f8c2` | Approved (no findings; 18 of 19 mutants red, the survivor is M-09c-ap at the shell level, R-C7-3) |
| 8 The ghost follows a wheel zoom (D12) | `7150bd1`, `bdff57d` (8b) | Needs fixes (major: the release's `_track` untested; minor: `_onArmed` re-resolved outside `_update`, a hazard once Task 7 adds the attachment there) -> 8b Approved |
| 9 Leaf-equal reuse (D10) | `a073fb5`, `5f4c235` (9b, test-only, on `wip/09c1-t9b`) cherry-picked as `90f0d97` | Needs fixes (major: the base point moved only in y; the ascending-handle pairing unguarded, the slot free list is LIFO and no fixture had holes; minor: "the first in ascending handle" unpinned) -> 9b Approved |
| 10 The search text survives a tab switch (D13) | `f424f9b` | Approved (no findings; 14 mutants red) |
| 11a End to end | `8f5f601` (test-only, and the stale `symbol_placer_test.dart` comment) | Covered by the final whole-branch review |

No `lib/` file changed after `2a1f8c2` (Task 11a is test-only); the engine's
`lib/` is unchanged since `a5a6b35`; the render package is unchanged since
the branch point (`git diff` checked when this note was written). The two
cherry-picks are byte-identical to their sources (C-4: the four files equal
`e9b0a52`; `90f0d97`'s test file equals `5f4c235`'s).

## What the execution found that the spec did not

Each ruling is in the ledger with its cost-if-wrong; the gist is below.

**Controller rulings and process.**

- **C-0:** Task 5 (the generalised transform) was swapped before Task 6
  (`attachToWall`) before the plan's commit, so Task 6 calls
  `placementTransform(rotation:)` directly. Cost if wrong: none.
- **C-1 (process, a real hazard):** two `flutter test` runs at once in one
  worktree share `build/unit_test_assets` and produce spurious
  `Asset 'shaders/ink_sparkle.frag' not found` failures (found by Task 10's
  implementer, confirmed by its review). From then on concurrent agents ran
  gates and mutants in their own scratch or detached worktrees, or the
  controller serialised them. Several reports' interim counts were taken in
  the shared worktree with other agents' uncommitted files and differ from
  their reviewers' committed-tree counts (Tasks 3, 3b, 4, 5b); the reviews'
  counts are the ones of record below. Task 10's implementer ran
  `git checkout --` in its own throwaway scratch worktree (forbidden by the
  rules; nothing in the plan worktree was touched): recorded as a process
  slip. Task 4's implementer once ran `dart format` over the whole `test/`
  directory (its report: no file outside Task 3's own set changed).
- **C-2:** Task 6 ran in `.worktrees/plan-09c1-t6` on `wip/09c1-t6`, cut
  from the plan tip, because Task 9 worked in the plan worktree at the same
  time. Cost if wrong: a cherry-pick conflict.
- **C-3:** Task 8 ran before Task 7; the camera listener re-resolves through
  the tool's one recompute path (`_update`), and Task 7 added the attachment
  there, so M-09c-ak was fired in Task 7, not 8. Cost if wrong: one mutant
  moves task.
- **C-4:** Task 6's commits cherry-picked as `7b26eb7` (`e188ef1`) and
  `b3284f1` (`e9b0a52`); the combined tip passed the app gates
  (`+1152: All tests passed!`, analyze clean, format 0 changed). Task 9b's
  `5f4c235` cherry-picked as `90f0d97`.
- **C-5 (verified by the controller): the `SnapKind.nearest` glyph does not
  exist.** `drawSnapMarker` draws nothing for `SnapKind.nearest`
  (`snap_marker.dart:56-60`, "Not in kDragSnapMask"), so D6's and D8's "the
  `SnapKind.nearest` glyph" (S-10) rested on a false premise. R-C7-1 (an
  app-side hourglass) is the faithful fix while the render layer is frozen;
  the glyph is on the human's look list.

**Task 1 (engine).**

- **R-C1-1:** a snapshot's registered components are ordered by type id; its
  unknown payloads keep the registry's oldest-first order (sorting them would
  make `restore` reorder `unknownOf`). Cost if wrong: one sort and one
  expectation.
- **R-C1-2:** P13's setup writes its orphan after the removal (the orphan a
  pre-09c file may carry, which D11 leaves alone). Cost: setup order only.
- **R-C1-3:** a public `ComponentRegistry.detachAll(Handle)`; the inverse is
  the public `AddDefinitionCommand(definition, components: snapshot)`, whose
  restore runs after its guards and before `addDefinition`, all-or-nothing.
  Cost if wrong: a rename.
- **R-C1-4:** undoing a plain `AddDefinitionCommand` now needs `components`
  (its inverse is the static-capability Remove, W-1). Only
  `DraftPermissions(structure: true, components: false)` is affected; no
  preset, no app or harness code builds it (the review's grep).

**Task 2.**

- **R-C2-1:** point, text, attrib and fill leaves and malformed payloads are
  skipped by the box, as by the ghost path. Cost: one case.
- **R-C2-2:** the box functions return `SymbolBox?`; null means "does not
  attach" (Tasks 6 and 7 treat it so, never `!`).
- **R-C2-3:** clockwise arcs handled (a superset). **R-C2-4:** the plan's
  stale task number for `WallFaces`.
- **N-2:** the box's arc rule duplicates the engine's `arcBounds`; they agree
  exactly today (the review's differential); if one changes, the other must
  follow. **N-3:** `backCentre` allocates a `Vector2` per call; Task 6 never
  calls it per query.

**Task 3.**

- **R-C3-1:** new family members copy their family's plain tags (e.g.
  `couch` on `sofa.two`), so search expectations list whole families.
- **R-C3-2:** family members sit together in the catalog, ascending by width;
  the library's handles shift, which nothing depends on (gallery and
  thumbnail ids are `key@version`; the placer copies with fresh handles;
  checked by the review).
- **R-C3-3:** `againstWallTag` and `familyTagPrefix` live in
  `symbol_library.dart`; Task 7 reads the tag through the constant.
- **3b:** `test/fixtures/furniture_pre_09c.jetlib` is `main` `4d6b78f`'s
  asset byte for byte; a test pins each of the 27 old symbols' name,
  category, version, base point and every leaf (record and payload, exact)
  against it. A repeated `family:` tag counts twice (R03d refuses it).

**Task 4.**

- **R-C4-1..4:** `faceRunsOf(doc, wall, {accept})` (the document adapter)
  plus the pure `faceRunsAmong(host, walls)`; runs left face first then
  right, ascending along `d`, with a `FaceSide` enum; a T or X role
  recomputed with `strictlyInside` for the walls `obstaclesOf` names; B's
  frame among host and others, sorted by handle.
- **Found by the review's differential (inherited from 07 and 08, not D3):**
  runs extend into a neighbour under the mirrored fallback; 07 can store a T
  stem untrimmed through a left-justified host's body; 08 does not count a
  wall end poking into a band off the centreline as an obstacle; 08
  classifies a wall ending inside the band past the centreline as an X,
  over-cutting the far face by about 85 mm. **Confirmed pre-existing:**
  mirrored walls never draw joined corners (688 of 688 mirrored frames fell
  back), so P-2's "mirrored, joined" fixture cannot be built today.

**Task 5.**

- **R-C5-1:** `placeSymbol` keeps `at` required when `transform` is given
  (ignored). **R-C5-2:** an equal ghost update keeps the earlier
  `Transform2` object (the W-15 identity check relies on it). **R-C5-3:** no
  unit-length check on `rotation` (Task 6 passes a normalised `t`).
  **R-C5-4:** two `@visibleForTesting` getters on the tool. **R-C5-5:** the
  09b ghost tests moved in Task 5, not 6.

**Task 6.**

- **R-C6-1:** neighbours are lists parallel to the runs, each entry with its
  instance handle; `attachToWall` takes `Handle? exclude` (for 09c-2).
- **R-C6-2:** step 1's `|s|` and distance keys tie within `wallJoin.linear`
  (a geometric decision): the two pieces of one face line give `|s|` equal
  only within rounding at 1e5, and an exact comparison turns the property
  check red (O16). The edge snap compares exactly.
- **R-C6-3:** `-0.0` is cleaned only in `placementTransform`; a second clean
  in `attachToWall` was a provably equivalent mutant and was removed.
- **R-C6-4:** `wall_attach.dart` imports `symbol_placer.dart`
  (`show placementTransform`), Flutter-free.
- **R-C6-5:** the overlap with `[0, L]` is closed; "front on the room side"
  is the transformed front-centre's `(f − a)·m > 0`; the picking rule is the
  engine's `FilterEvaluator.acceptsNode(…, QueryFilter.picking())`.
- **R-C6-6:** the `WallFaces` API (`runsOf`, `neighboursOf`, `boxOf`,
  `attach`, a public `builds` counter).
- **Notes:** the tolerant ranking is not transitive within 1e-6 mm (N-a);
  `WallFaces` is stale until another tool's change is delivered (N-b; Task 7
  invalidates on its own commit); a rebuild is O(walls²) (N-c).

**Task 7.**

- **R-C7-1:** the attached marker is an app-side hourglass
  (`drawNearestMarker` in `symbol_place_tool.dart`, AutoCAD's nearest glyph,
  `kSnapMarkerPixels` wide, the marker paint), since `drawSnapMarker` draws
  nothing for `nearest` (C-5). Cost if wrong: the function moves into the
  render layer's `nearest` case in 09c-2, or the glyph changes shape.
- **R-C7-2:** `R` and `M` re-ask the faces with the stored query (the raw
  point, the object-snap flag and the scale of the last recompute); they do
  not re-snap.
- **R-C7-3:** M-09c-ap (no `invalidate()` after the commit) is killed at the
  tool level only: in a widget test the gestures' awaits let the change
  stream deliver between two clicks (survivor, below).
- **R-C7-4:** a refused placement does not invalidate the bands.

**Task 8.**

- **R-C8-1:** a disarm removes the camera listener but keeps the ghost
  shown; a re-arm re-listens. **R-C8-2:** the "zoom brings a face within
  capture" test belongs to Task 7 (C-3). **R-C8-3:** the last event's
  context is kept apart from the listened one.
- **R-C8b-1:** a re-arm with a listened context always re-resolves through
  `_update`, including entry -> entry (so the attachment follows the new
  entry's tag and box); with none it only refreshes the placement.

**Task 9.**

- **R-C9-1:** records are compared by their own `EntityRecord.==` (all 15
  fields) after normalising `handle`, `owner` and `geomIndex` to the entry's,
  so a field added later is compared automatically. **R-C9-2:** the entry's
  leaves are paired in list order (`SymbolEntry`'s documented ascending
  order, not enforced by its constructor). **R-C9-3:** the text-style edit
  case does not assert `validate()`.

**Task 10.**

- **R-C10-1:** the **document host** owns the search controller and passes
  it through the shell to `SymbolPanel`; a bare shell owns its own. Reason:
  the host keys the shell by its document (12a D2), so a shell-owned
  controller cannot survive a document change as D13 requires. Cost if
  wrong: one field moves into the shell.
- **R-C10-2:** `SymbolPanel.didUpdateWidget` moves its listener to a new
  controller (nothing hands one in today).

**Task 11a.**

- **R-C11a-1:** one L scene covers both faces (the 30° wall's outside face
  for the bed, its inside face for the units from the drawn corner).
- **R-C11a-2:** flushness within `1e-9·|run.a|` (about 1.2e-4 mm at the
  scene's distance from the origin); the units' abutment within 1e-9
  absolute along `t`.
- **R-C11a-3:** the "plan saved before 09c" is built in the test with
  today's codec from the pre-09c fixture's entries (09c-1 changed no file
  schema), one instance per key; the whole file is asserted byte-identical
  after Open and Save.

## Gates of record (Linux container, Flutter 3.47.2, `CI=true`)

Branch point `4d6b78f` (measured on 2026-10-02 in this container, recorded
in `904970d`): engine 1,226 + 2 standing; render 1,187 + 1 skip + 7
standing; app 993.

Run for this note on the tip `8f5f601`, sequentially (one `flutter test` at
a time, C-1):

- **engine** `00:22 +1237 -2: Some tests failed.`: the 2 are the standing
  `test/testing/generate_document_test.dart` ("the default document is the
  one Plan 2 measured, byte for byte", "both text fractions default to zero
  and change nothing"). 1,226 + 11 (Task 1) = 1,237; 1b changed fixtures
  only. `dart analyze`: `No issues found!`; format:
  `Formatted 168 files (0 changed)`.
- **render** `01:11 +1187 ~1 -7: Some tests failed.`: the 7 are the standing
  canvas text ladders (`text_ladder_golden_test.dart` rungs 1–5,
  `text_lod_ladder_golden_test.dart` rungs 1–2, `RenderBackend.canvas`), the
  skip the `rig`-tagged test; unchanged from the branch point (no render
  file changed). `flutter analyze`: `No issues found!`; format:
  `Formatted 208 files (0 changed)`.
- **app** `04:58 +1169: All tests passed!`. 993 + 22 (2) + 51 (3) + 9 (4) + 9 (5) + 3 (3b) + 8
  (10) + 1 (5b) + 1 (4b) + 24 (9) + 6 (8) + 3 (9b) + 2 (8b) + 16 (6) + 4
  (6b) + 15 (7) + 2 (11a) = 1,169 (Task 1 rewrote SC12 and P13, adding
  none). `flutter analyze`: `No issues found!`; format: `Formatted 184 files (0 changed)`.
- **web** `CI=true flutter build web --release`: `✓ Built build/web`.
- **`apps/dev_harness_2d`** `flutter analyze`: `No issues found!`.
- **The two allocation invariant tests are unedited:** `git diff 904970d
  HEAD --stat` over `packages/jet_cad_2d/test/invariants` and
  `packages/jet_cad_2d_flutter/test/invariants` is empty; their green runs
  are inside the engine and render suites above. No
  `analysis_options.yaml` is in `git diff 904970d HEAD --stat` (pub get
  rewrites `packages/jet_cad/analysis_options.yaml` in the worktree; it was
  never staged).
- **Purity:** `wall_attach.dart` and `symbol_box.dart` import neither
  `package:flutter` nor `dart:ui` (an `import`/`export` grep finds none; the
  only text hits are the comments stating the rule); their transitive
  closures within the app's `lib/` are 20 and 17 files, none of which
  imports Flutter or `dart:ui` (a script, as Tasks 4, 6 and their reviews
  ran it).

## Mutants

The P-8 rule (09a's): this table is compiled from each task's report and
independent review, both of which fired real runs at the task commit; the
final whole-branch review re-fires a sample on the tip (to come). Line
numbers are at the task's commit. Every run restored its file by `cp`
(`diff` exit 0; for catalog mutants also `cmp` on the regenerated asset).
"R" marks a mutant the reviewer added; "(b)" a mutant fired at the b-round.

**Task 1 (engine, `definition_commands_test.dart` #1–#11; app SC12).**

| Id | Where | Red test |
|---|---|---|
| M-09c-q undo skips `restore` | `commands.dart:451` | #1, #5, #6, #7; app SC12 |
| M-09c-r the snapshot skips unknown payloads | `component.dart:164` | #1, #5, #6, #8, #9 |
| M-09c-aj forward capabilities `{structure}` | `commands.dart:488` | #3, #4 (`Expected: throws <Instance of 'PermissionDeniedError'>`) |
| M-09c-ba inverse of a non-empty snapshot `{structure}` | `commands.dart:431` | #5, #6 |
| detach skipped (the component survives) | `commands.dart:514` | #1, #6; app SC12 (`Expected: null Actual: SymbolComponent…`) |
| `isEmpty` ignores unknowns; `isEmpty => false`; the snapshot shares the live list; restore ignores the type id; restore after add; detach before the guards; unknowns sorted by type id | `component.dart:86, 86, 79, 192`; `commands.dart:451, 499`; `component.dart:167` | #6; #3, #5, #8, #10; #9; #1, #5, #7, #8, #11; #7; #1, #2, #5, #6; #8 |
| R: snapshot after `detachAll`; `detachAll` keeps unknowns; inverse capabilities ignore unknowns; restore appends unknowns reversed; P13's guard dropped | `commands.dart:513`; `component.dart:176`; `commands.dart:429`; `component.dart:202`; `symbol_placer.dart:83` | #1, #5, #6; #1, #6, #8; #6; #8; P13 |
| R, then (b): no sort of the registered components; an interleaved (non-atomic) restore | `component.dart:166`; `:189-201` | **survived at Task 1**; red after 1b: #8 (`(test.tally, …) instead of (jet_cad.object_layer, …)`), #7 (`Expected: '{}' Actual: '{"jet_cad.object_layer":…}'`) |

**Task 2 (`symbol_box_test.dart`, 22 tests).**

| Id | Where | Red test |
|---|---|---|
| M-09c-ai arc bounds from the end points only | `symbol_box.dart:98` | 13 incl. the toilet's front (`front: 199.99999999999994`) |
| an axis extreme off by one quadrant | `:99` | the four single-axis arc tests and five more |
| `back = minY` (M-09c-b's box half); `front = maxY` | `:111` | 17 (18 in the review) incl. every catalog literal and the toilet; 17 |
| back-centre `x = left`; depth from width; circle radius ignored / in x only; polyline end vertices only; other kinds counted; empty gives a box; no memo; owner filter dropped; definition check dropped; `==` ignores back; identity `hashCode`; counter-clockwise only; `end = sweep`; every extreme added; definition box memoised on the document | `:36, 32, 89, 90, 84, 103, 110, 125, 140, 136, 43, 47, 99, 95, 99, 135` | each red (the report's table); the identity-`hashCode` mutant first survived (the test compared two canonicalised `const` boxes), fixed before the commit |
| R: the 3π/2 extreme's sign; a line's last vertex dropped; clockwise end; every arc skipped; the extreme's y offset without `r` | `symbol_box.dart` | all red |

**Task 3 (catalog and loader; catalog mutants regenerate the asset).**

| Id | Where | Red test |
|---|---|---|
| M-09c-ac a second `family:` tag accepted | `symbol_library.dart:161` | "R03d a symbol with two family tags is refused" |
| M-09c-ar one member's depth (base 800 at 620), regenerated | `furniture_catalog.dart:266` | families share depth, front and back (W-16); "box is its D9 W x D"; the box literal |
| a new symbol's base point off its centre `x` (sofa.two; R: desk 1600) | `furniture_catalog.dart:499` | "every base point lies on its box's centre x" |
| `against-wall` dropped (the washer; R: the tub) | `furniture_catalog.dart:445` | "the against-wall set is D9's list exactly"; "behaviour tags come last" |
| the asset not regenerated | catalog edit only | "the committed bytes equal the built library" (`at location [59247]`) |
| R03d by `contains('family')`; a name; tag order; a new box (washer circle); family membership | `symbol_library.dart:159`; `furniture_catalog.dart:626, 278, 451, 498` | each red |
| R: R03d skips the last tag | `symbol_library.dart` | the R03d refusal |
| R, then (b): the wardrobe loop `x <= w` (a leaf added to `bed.wardrobe@1`, version kept) | `furniture_catalog.dart:233` | **survived the whole app suite at Task 3** (`+1066`); red after 3b: "each keeps its name, category, version, base point and leaves" (`Expected: <6> Actual: <7>`) |
| R, then (b): R03d `families.toSet().length > 1` | `symbol_library.dart:161` | **survived at Task 3**; red after 3b (the duplicate case) |
| (b): the double bed's pillow gap; the single bed's pillow; the old desk's drawer line; a tag removed from / prepended to an old symbol; an old name changed; R (b): an old member's scalar, base point y, a record style field | `furniture_catalog.dart`, `build_library.dart` | the pre-09c tests (each) |

**Task 4 (`wall_faces_test.dart` WF1–WF9, `wall_bands_test.dart` WB2).**

| Id | Where | Red test |
|---|---|---|
| M-09c-f the run is the centreline | `wall_attach.dart:141` | WF2, WF6 (`within 0.000001 of 3778.33 Actual: 3999.99`) |
| M-09c-g1 a T ignored; M-09c-g2 a T on both faces; M-09c-g3 an X on one face | `:132`; `:131`; `:137` | WF3, WF5, WF8; WF3, WF5; WF4 |
| M-09c-ag the wrong cap end (extent; line) | `:141`; `:157` | WF2, WF6; WF1–WF6, WF8 |
| M-09c-as a T's side from the world normal | `:130` | WF5 |
| M-09c-at the face line from `lOff`/`rOff` | `:157-160` | WF6 (`within 0.000001 of 100.0 Actual: 150.00000000000148`) |
| M-09c-ay an X cuts by the union | `:136` | WF4 (`Actual: 115.47005383792528`) |
| `liveWalls` without the refresh; a copy, not a view | `wall_bands.dart:60`; `:62` | WB2 |
| `m` the world left; `t` flipped; a drop at 0; `accept` dropped; `accept` before the live check | `wall_attach.dart:98, 169, 173, 62, 60` | WF1; WF1, WF3; WF8; WF7; WF7 |
| R: `w = (ls − rs).length`; `a` the other end; `mLeft = nd` | `wall_attach.dart` | WF2, WF6; WF1–WF6, WF8; WF1 |
| R, then (b): the T side via `toWorld` instead of `toLocal`; the cut merge `from = b`; (b) no sort of the cuts | `:130`; `:191`; `:187` | **survived at Task 4**; red after 4b: WF3 (host groups turned 1.0 and 1.7 rad); WF9; WF9 |
| R: the `end < 0` branch removed; B's frame without the host | `_pieces:185`; R-C4-4 | **survive, accepted**: unreachable (crossed caps make the ring non-simple, the frame falls back); near-equivalent (B's face lines do not depend on its joints) |

**Task 5 (`symbol_placer_test.dart` P20–P24, `symbol_ghost_test.dart`,
`symbol_place_tool_test.dart`).**

| Id | Where | Red test |
|---|---|---|
| M-09c-n `-0.0` not cleaned | `symbol_placer.dart:63` | P3, P14, P23 (the axis-aligned exception); R: on the rotation form alone, P23 only |
| M-09c-o the ghost recomputes on every update | `symbol_ghost.dart:126` | the count tests (`Expected: <1> Actual: <4>`), the tool's "computed on events" |
| the `transform` argument ignored | `symbol_placer.dart:157` | P24 |
| a `Transform2` built in `paintWorldOverlay` | `symbol_place_tool.dart:326` | "the placement is computed on events, never in a paint" (`identical`) |
| key / re-arm / move do not recompute; one double (`f`) not compared; a tolerance instead of `==`; the new placement not kept; both forms accepted; mirror after the turn; rotation ignored | `symbol_place_tool.dart:~249, 136, 192`; `symbol_ghost.dart:131, 127, 135`; `symbol_placer.dart:54, 59-61, 58` | each red (the report's table) |
| R: `e` not compared; `assert` instead of `throw`; a transposed rotation | | the count tests; P21; P1, P4, P20 |
| R, then (b): `_syncPlacement()` dropped from `onPointerDown` / `onPointerUp` | `symbol_place_tool.dart:182`; `:207` | **survived at Task 5**; red after 5b: "touch: the press and the release each set the placement" (R (b): the sync moved before `_resolve`, red) |

**Task 6 (`wall_attach_test.dart` WA1–WA18, `wall_attach_property_test.dart`
WP1, WP2).**

| Id | Where | Red test |
|---|---|---|
| M-09c-b the back is `front` | `wall_attach.dart:326` | WA1, 2, 4, 6, 7, 11, 13 (17 after 6b); WP1, WP2 |
| M-09c-c the rotation keeps the quarter turns | `:327` | WA1, 2, 4, 6, 7, 11, 13 |
| M-09c-d always the left face | `:267` | WA1–4, 11–15 (17 after 6b) |
| M-09c-h no neighbour edge snap | `:311-312` | WA7 (WA17 after 6b); WP2 |
| M-09c-i no clamp | `:317` | WA4, WA13; WP1 |
| M-09c-j the mirror dropped (at the function) | `:328` | WA1, WA6, WA7 |
| M-09c-m the `W ≤ L` test dropped | `:286` | WA11, WA12 |
| M-09c-n (at the function) | `symbol_placer.dart` `clean` | WA14 |
| M-09c-af no distance-to-`[0, L]` key | `:341-342` | WA4; WP1 |
| M-09c-ah `s ≥ −w`; `s ≥ 0` | `:267` | WA5 (the far host face won); WA2, WA5, WA16 |
| M-09c-aq a neighbour outside `[0, L]` | `:488` | WA8 (`Expected: [36] Actual: [36, 37]`) |
| M-09c-au the clamp without the `W ≥ L` case | `:315` | WA12 (`103924.980021921` vs `103924.98002192109`, 1e-10 off as T-6 predicted) |
| `WallFaces` not keyed on the generation | `:436` | WA9 |
| rebuild on every query; box memo not cleared; neighbour interval unsorted; picking filter dropped / `rendering()` / lock-only; orthonormal test dropped; `SymbolComponent` test dropped; front-side test dropped; back-on-line test dropped; all nodes, not root-level; overlap as containment; `exclude` ignored; first snap wins; run-end snaps removed; `s ≤ capture` dropped; `u` window dropped; `accept` not passed; exact `|s|`/gap ties; the handle / side / `a·t` key reversed | `wall_attach.dart` | each red (the report's table) |
| R: wrong side to a neighbour's end; `u < 0` window; `W > L − tol`; the gap ignores `u > L`; box memo not cleared; front-side `> −1e9`; O16 exact `|s|` | | WA7; WA3, WA12, WA13; WA12; WA4; WA9; WA8; the reviewer's property check (WP1 after 6b) |
| R, then (b): O7 / O7b one back-edge end checked; O6 `isOrthonormal` without `|ac + bd|`; O1 the edge-snap tie reversed (b: and the tie clause dropped) | `:485-486`; `:356`; `:298` | **survived at Task 6**; red after 6b: WA8 (`[36, 53]`); WA8, WA18; WA17 |
| `attachToWall`'s own `-0.0` normalisation removed | `:288-289` | **equivalent, removed** (R-C6-3): `placementTransform` cleans all six components |

**Task 7 (`symbol_place_tool_test.dart` "the wall attachment",
`symbol_shell_test.dart` SS16, SS17).**

| Id | Where | Red test |
|---|---|---|
| M-09c-a the tag ignored (the island attaches) | `symbol_place_tool.dart:243` | the island test; the re-arm test |
| M-09c-e `isUsableHost` dropped, through the shell | `main.dart:369` | SS17 (`Expected: <false> Actual: <true>`) |
| M-09c-j the mirror dropped (at the call; the key path's `_syncAttachment` deleted) | `:248`; `:390` | attach on hover and release, the M test; the M test |
| M-09c-k `R` turns the attached ghost | `:223` | attach; the R test (`<0.4999999999999974> instead of <-0.866…>`) |
| M-09c-l attachment with F3 off | `:240` | the F3 test |
| M-09c-ap no `invalidate()` after the commit | `:445` | the W-5 test (`within <0.000001> of <1600> Actual: <1720.000000000006>`) |
| M-09c-ak the camera re-resolve skips the attachment | `:303` | the zoom test (`Expected: not null`) |
| the re-arm re-resolve skips the attachment (owed by 8b) | `:200` | the re-arm test |
| the marker at the raw / the resolved point; `drawSnapMarker(…, SnapKind.nearest, …)` | `:456`; `:460` | the marker test (the last: `Expected: an object with length of <4> Actual: []`, C-5) |
| the release ignores the attached transform; the capture from the snap aperture; the edge capture from 16 px; `_hasRaw` never set; the permission check removed; the shell hands no faces; `liveWalls` without the refresh (fresh shell) | `:444, 247, 248, 278, 439`; `main.dart:371`; `wall_bands.dart:60` | 6 tests; the capture test; W-5; all attach tests; 4 permission tests; SS16, SS17; SS16, SS17 |
| a hidden re-arm keeps the attachment | `:205` | survived at first; red after the implementer added the hidden re-arm assertion, before the commit |
| R: O1 the attachment from the resolved point; O2 a stale stored scale; O3 a stale attachment on an early return; O4 the key path's order; O5 the mirror applied twice; O6 `invalidate()` before the permission check; O7 the hourglass and `drawSnapMarker` both | | 7 tests; zoom; re-arm; M; attach and M; permissions (the generation); the marker (`has length of <6>`) |

**Task 8 (`symbol_place_tool_test.dart` "the camera").**

| Id | Where | Red test |
|---|---|---|
| M-09c-s the listener not added; not removed on dispose (a live camera) | `symbol_place_tool.dart:220`; `:403-405` | all 6 camera tests; the dispose test (`Expected: <0> Actual: <1>`; with the counts removed, the ghost re-resolved after dispose) |
| M-09c-bb the listener not removed on hide / `cancel` / disarm | `:276`; `:343`; `:153` | the pointer-exit / cancel / disarm test (each also red by position with the count assertions removed) |
| the re-arm does not re-listen / re-resolve; the camera re-resolve skips the placement; the screen point not kept | `:153, 158, 226, 207` | the disarm test; the disarm test; the zoom test; tests 1, 3, 5 |
| R: the down's `_track` deleted; `notifyListeners` in `_onCamera` deleted; `ghostVisible` -> `_ghostVisible`; the re-arm from the world point; the down's `_syncCamera` deleted | `:236, 227, 216, 158, 239` | each red |
| R, then (b): R8-1 the up's `_track` deleted | `:263` (`:268` at 8b) | **survived at Task 8**; red after 8b: "a release with no move before it" (`Expected: <73675.3> Actual: <76600.3>`) |
| (b): K-1 the old `!wasListening` condition; K-2 a re-arm only syncs the placement; K-3 `_update` -> `_resolve`; K-4 the `else` dropped; K-5 the re-arm from the world point | `symbol_place_tool.dart:161-163` at `bdff57d` | the entry -> entry re-arm test; the disarm test (K-4 survived until 8b added `ghostPlacement` null after a disarm) |

**Task 9 (`symbol_placer_test.dart` "leaf-equal reuse" L1–L7).**

| Id | Where | Red test |
|---|---|---|
| M-09c-p a payload scalar ignored | `symbol_placer.dart:221` | L1 a payload scalar (arc sweep); L1 a text scalar (height) |
| M-09c-p a style field ignored (each of 12: colour, lineweight, transparency, flags, linetype scale, linetype, layer, kind, text, tag, text style, text attributes) | `:218` | exactly the matching L1 edit, each |
| M-09c-p the base point ignored | `:199` | L1 a moved base point |
| M-09c-bd child nodes ignored; the leaf count ignored | `:200`; `:208` | L1 a child node; L1 an extra leaf, a missing last leaf |
| coords ignored; no D10 at all; first match only; owner not normalised | `:221, 114-115, 114-119, 217` | L1 a leaf coordinate; all 20 L1; all 20 L1; 27 tests |
| R, then (b): the base point compared in y only; no sort (pair in slot order); the last leaf-equal match wins | `:199`; `:206-207`; `:117` | **survived at Task 9**; red after 9b: L1 "a base point moved in x"; L6 (out-of-order slots, its premise asserted); L7 (`Expected: <18> Actual: <26>`) |

**Task 10 (`symbol_panel_test.dart`, `symbol_shell_test.dart` SS12–SS15).**

| Id | Where | Red test |
|---|---|---|
| M-09c-t the panel creates its own controller again | `symbol_panel.dart:116` | 4 panel D13 tests, SS12–SS15 (`Expected: 'bed' Actual: ''`) |
| the shell recreates it per build (the plan's) | `main.dart` `_leftPanel` | SS12–SS15 |
| the panel disposes the given controller; leaves its listener; `didUpdateWidget` ignores a new one; the host recreates it per build; the shell ignores the host's; the host does not dispose it; a bare shell does not dispose its own | `symbol_panel.dart:147, 147`, `didUpdateWidget`; `document_host.dart`; `main.dart` | 31 tests; 3; 1; SS13, SS14; SS13, SS14; SS14; SS15 |
| R: the listener kept on the old controller / never on the new; the shell disposes the host's; `initState` never listens; each shell clears the text | | each red (SS13 for the last) |

**Task 11a (`wall_attach_end_to_end_test.dart` WE1, WE2).**

| Id | Where | Red test |
|---|---|---|
| M-09c-c | `wall_attach.dart:338` | WE1, WE2 (flushness: `Actual: <399.99999999999886>`) |
| M-09c-b at the attachment; at the box | `wall_attach.dart:334`; `symbol_box.dart:111` | WE1, WE2 (`Actual: <2000.0000000000068>`) |
| the release ignores the attached transform | `symbol_place_tool.dart:445` | WE1, WE2 |
| leaf-equality always false; `geomIndex` not exempted | `symbol_placer.dart:195`; `:218` | WE1 (`#2`, `#3` copies), WE2 (`bed.double reuses the pre-09c definition`) |
| M-09c-h; M-09c-j at the tool | `wall_attach.dart:307`; `symbol_place_tool.dart:249` | WE1; WE2 (the wardrobe's bytes) |

**Survivors recorded, and why accepted.**

- **M-09c-ap at the shell and end to end** (R-C7-3; re-fired by Task 7's
  review and by Task 11a): `+17` on `symbol_shell_test.dart`, `+2` on the
  end-to-end file. In a pumped widget test the change stream delivers
  between two clicks, so a missing `invalidate()` cannot show; it is red at
  the tool level, where the run is synchronous.
- **M-09c-p (a style field) end to end** (Task 11a): a more permissive
  equality cannot copy a definition that is equal; red in Task 9's placer
  tests (each of the 12 fields).
- **Equivalent:** `attachToWall`'s own `-0.0` normalisation (removed,
  R-C6-3); Task 4's `end < 0` branch (unreachable) and B's frame without the
  host (near-equivalent), both reviewer mutants, accepted by the review.
- **Not compiled or not counted:** Task 9's first "first match only" form
  (it kept the in-loop check, an equivalent edit; re-fired correctly).

Every survivor at a task commit other than these was closed by its b-round
and re-fired red by the same reviewer. Precondition guards ("the fixtures
are not degenerate", WF3's disagreement count of 48, L6's out-of-order
premise) have fixture mutants of their own where the review fired them
(L6: both red), no product mutant.

**The final whole-branch review's sample:** to be recorded by that review.

## Found, not fixed

- **Inherited wall geometry (Task 4 review's differential, 07 and 08):** a
  run can extend into a neighbour under the mirrored fallback, so a symbol
  can attach on the part of a stem's face that runs inside a mirrored host;
  07 can store a T stem untrimmed through a left-justified host's body; 08
  counts no wall end that pokes into a band off the centreline; 08 calls a
  wall ending inside the band past the centreline an X and cuts both faces,
  leaving an empty gap of about 85 mm on the face its body never reaches.
  D3 follows `obstaclesOf`'s classification (spec D14).
- **Mirrored walls never draw joined corners** (688 of 688 mirrored frames
  fell back; pre-existing 07 behaviour).
- **The tolerant face ranking is not transitive** within 1e-6 mm (Task 6
  N-a): bounded, invisible.
- **`WallFaces` rebuilds cost O(walls²)** (`wallsInDocument` per wall) and
  the neighbours O(instances × runs), on the first query after any document
  change; never per pointer move.
- **`WallFaces` is stale until a change is delivered** (Task 6 N-b): another
  tool's commit is seen after `DocChange` arrives; the placement tool
  invalidates on its own commit.
- **Two `Vector2` per camera change** (Task 8 note 3); each attached pointer
  event allocates the result record, a `Vector2` and a `Transform2`; the
  hourglass marker builds 8 `Offset`s per paint. All O(1), off the measured
  invariant paths.
- **F3 does not refresh the ghost** (8b, Task 7 note 3): after toggling F3 a
  key keeps the stored flag until the pointer moves; a release always
  recomputes, so the commit is never wrong.
- **No camera test brings an object-snap point into the aperture or uses the
  zoom-adaptive grid** (Task 8 note 4); both read the live scale in the
  shared `_resolve`.
- **The tool-level and end-to-end tests use no mirrored or scaled wall
  group** (Task 7 note 1); `wall_attach_test.dart` and the property test
  cover the geometry under both.
- **A re-arm after a disarm can show a stale ghost** until the next move
  (Task 8 note 5); the shell never disarms.
- **`SymbolEntry`'s ascending-handle order is not enforced** by its
  constructor (R-C9-2); an out-of-order entry would be copied on every
  placement (09c-2's D7 builds entries).
- **The new symbols' interior drawings are not pinned** (Task 3 note 3; the
  spec pins only their boxes); the 27 old symbols' are (3b).
- **Searching "wall" lists the 30 wall-standing symbols** (the spec's
  accepted cost, D2).
- **`ComponentSnapshot` has no `operator ==`**; `restore` is additive (it
  would duplicate unknown payloads on a handle that already carries some;
  the only caller restores onto a handle it just emptied).
- **The box's arc rule duplicates the engine's `arcBounds`** (Task 2 N-2).
- **`boxOfDefinition` counts the definition's own leaves only**, not nested
  instances (Task 2 N-5; none exist in the library).
- **`FaceRun` pieces of one face share their `t` and `m` vectors** (Task 4
  N5): read-only by contract.
- **`ghostAt` means the resolved point while attached**; the ghost's real
  position is `ghostAttachment` / `ghostPlacement`.
- **`invalidate()` also runs after a free placement** (harmless, D6's
  wording).
- **`isLeafEqual` costs O(entities × candidates) per placement**; not on the
  frame path.
- **`PlannerShell.symbolSearch` is read once, in `initState`** (Task 10
  N-4); SS13 does not assert the document clean before each replacement
  (N-2; a dirty one would time out, red).
- **`WallFaces.builds` is public, not `@visibleForTesting`** (optional, Task
  6 review).

## Owed to 09c-2

- **D7:** the Symbol section (name, size, rotation, mirror, the Size menu)
  and the size change, with **`SetInstanceDefinitionCommand`** (engine) and
  the render-cache test after a size change (W-13).
- **D8:** the wall-aware move: the render seam (`MoveResolver` on
  `SelectTool`, `GripDrag.singleNode`, `GripDrag.moveToTransform`) and the
  app's resolver in `symbol_move.dart`; `attachToWall`'s `exclude` and
  `WallFaces.attach(…, exclude:)` are ready for it.
- **The marker glyph (C-5, R-C7-1):** D8 also names the `SnapKind.nearest`
  glyph. Either `drawNearestMarker` moves into the render layer's
  `drawSnapMarker` `nearest` case (with the seam that 09c-2 opens anyway),
  or the move resolver's marker reuses the app's hourglass.
- **`SymbolEntry`'s order:** D7's size change must sort the entry side or
  assert the order (Task 9 review note 4).
- The named mutants of D7 and D8 (M-09c-u … -ax, -am, -az, -bc, -be) and
  09c-2's half of the look list.

## The human's look

Copied from the spec's 09c-1 Exit gate, plus the items execution added.
**Nothing is marked done for the human.** macOS and web (Chrome, Firefox),
light theme only:

- a bed, a wardrobe, a kitchen unit, a toilet dropped near a wall face lands
  flush, turned to it, on both faces, on a wall at an angle;
- an inside corner and an outside corner; a T; a run of kitchen units
  started at a corner, each snapping to the previous one;
- the ghost stays within the face; leaving the face frees it;
- `M` while attached; `R` while attached does nothing visible, then applies
  off the wall; F3 off disables attachment;
- a symbol not tagged (a dining table, the island) does not attach;
- a wheel zoom with the ghost visible: the ghost stays under the pointer;
- the search text kept across a tab switch;
- the 14 new symbols' thumbnails and drawings (the hob's 520 mm depth is
  shorter than the 600 mm units: a content point to judge);
- a plan saved before 09c opens, its symbols unchanged;
- **added at execution:** the attached marker is an **hourglass** (AutoCAD's
  nearest glyph, drawn by the app, R-C7-1; the spec's `SnapKind.nearest`
  glyph does not exist, C-5): its look and size beside the other snap
  markers;
- **added at execution:** the **2400 wardrobe** has handles only beside its
  first door division (doors 1–2; doors 3 and 4 have none, Task 3 review
  note 4): keep, or a handle pair per door pair;
- **added at execution:** the **hob's 520 mm depth** in a kitchen run:
  attached, its back is on the face like the 600 mm base units', so its
  front sits 80 mm behind theirs; judge it in a run.

**Points to judge (inherited, not 09c-1's):** a symbol may attach on the
part of a T stem's face that runs inside a mirrored host, and an X ending
inside a wall's band leaves an empty stretch on the far face (Found, not
fixed, the first item).
