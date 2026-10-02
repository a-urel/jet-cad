# Plan 09c-1 — final whole-branch review

**Reviewer:** a fresh agent that wrote none of this code. **Diff under review:**
`git diff 904970d..c1ea23c` (19 commits, 37 files, +7,946 / −234).
**Worktree:** `.worktrees/plan-09c1-final`, detached at `c1ea23c`, left in
place. `CI=true flutter pub get` rewrote `packages/jet_cad/analysis_options.yaml`
there (left unstaged; it is the only entry in `git status`). Nothing was
committed anywhere. Scratch: `scratchpad/final/` (gate logs in `logs/` and
`logs_ci/`, mutant logs in `mut/log_<n>.txt`, `mut/summary.tsv`).

## Verdict: **Ready**

No blocking, major or minor defect found. One optional nit (a stale comment)
is listed at the end; it needs no re-review. The merge and the human's look
remain the human's.

---

## 1. Gates, re-run by me, sequentially (one `flutter test` at a time)

Run twice: once without `CI=true` (my first script omitted it), then again
with `CI=true` exported for every command. Both runs gave the same results;
the `CI=true` run is the one of record.

| Gate | Result (`CI=true`) | Note's gate of record |
|---|---|---|
| engine `dart test` | `00:20 +1237 -2: Some tests failed.` The 2 are `generate_document_test.dart` ("the default document is the one Plan 2 measured, byte for byte", "both text fractions default to zero and change nothing") | 1,237 + 2 standing: **match** |
| engine `dart analyze` / format | `No issues found!` / `Formatted 168 files (0 changed)` | match |
| render `flutter test` | `01:07 +1187 ~1 -7: Some tests failed.` The 7 are `text_ladder_golden_test.dart` rungs 1–5 and `text_lod_ladder_golden_test.dart` rungs 1–2 (`RenderBackend.canvas`) | 1,187 + 1 skip + 7 standing: **match** |
| render `flutter analyze` / format | `No issues found!` / `Formatted 208 files (0 changed)` | match |
| app `flutter test` | `04:23 +1169: All tests passed!` | 1,169: **match** |
| app `flutter analyze` / format | `No issues found!` / `Formatted 184 files (0 changed)` | match |
| app `flutter build web --release` | `✓ Built build/web` (exit 0) | match |
| `apps/dev_harness_2d` `flutter analyze` | `No issues found!` | match |

The note's app count derivation (993 + per-task additions = 1,169) adds up.

## 2. Whole-branch correctness (every `lib/` change, against D2–D6 and D9–D13 as amended)

I read every changed `lib/` file in full: engine `component.dart`,
`commands.dart`; app `symbol_box.dart`, `wall_attach.dart`, `wall_bands.dart`,
`symbol_placer.dart`, `symbol_ghost.dart`, `symbol_place_tool.dart`,
`symbol_panel.dart`, `symbol_library.dart`, `main.dart`, `document_host.dart`
(the catalog through its tests and the mutant below).

**Per decision, no departure from the spec as amended:**

- **D11.** `RemoveDefinitionCommand.apply` takes the snapshot and detaches only
  after every refusal (`commands.dart:497-513`); the inverse
  `AddDefinitionCommand(definition, components:)` restores after its guards and
  before `addDefinition`; `restore` validates every type id before writing
  (all-or-nothing). Forward capabilities are static `{structure, components}`;
  the inverse's set depends on the snapshot. `capability` stays `structure`.
- **D2.** `boxOfLeaves`: `front = minY`, `back = maxY`; arcs by their true
  extents in both turning directions; returns null when nothing draws.
  `boxOfEntry` is memoised by an `Expando`. `boxOfDefinition` reads the live
  leaves; the per-document memo is `WallFaces._boxes`, cleared on rebuild.
- **D3.** The face lines come from the drawn caps. The direction comes from
  `toWorld.transformDirection(frame.d)`, normalised. `m` points away from the
  other face line, and `w` is measured by projection. The T side is decided in
  the host's local frame. An X is cut per face from that face's own crossings.
  `stretchesOf` and `lOff`/`rOff` are never used. I checked `obstaclesOf`: an L
  corner is neither a T nor an X (the crossing must be strictly inside both
  centrelines), so an L never cuts the outside face.
- **D4.** I checked steps 1–5 line by line: the candidate window
  (`−w/2 ≤ s ≤ capture`, the `u` window), the five-key ranking, `W ≤ L + tol`,
  `(cos, sin) = (t.x, t.y)`, the edge snaps (smallest shift, tie to the
  smaller `u`), the clamp (`u = L/2` when `W ≥ L`) and `placementTransform` at
  the back-centre. Local `+y` maps to `(−t.y, t.x) = −m`. The neighbour rule
  is the one D4 states, plus R-C6-5's closed overlap and front-centre test.
- **D5.** `placementTransform` cleans `-0.0` in both forms and throws when
  given both. `GhostMatrix.update(placement:)` compares the six doubles exactly.
  No `Transform2` is built in `paintWorldOverlay`.
- **D6.** The tool attaches only when the entry carries `againstWallTag`, the
  box is non-null, object snap is on and the result is non-null. The release
  always recomputes (`_update`) before `_place`, which commits
  `_attached?.transform` verbatim. `bands.invalidate()` runs only after a
  permitted commit. While attached, keys re-ask the faces with the stored query.
- **D9 / R03d.** The rule refuses more than one `family:` tag (duplicates
  count). The asset is the generator's output: the catalog mutant below
  regenerated the asset, and `cmp` against the backup was 0 after restoring.
- **D10.** `isLeafEqual` checks the base point (x and y), the absence of child
  nodes and the leaf count. It pairs leaves by ascending handle, compares
  `EntityRecord.==` after normalising `handle`, `owner` and `geomIndex`, and
  compares `GeometryPayload.==`, all exactly. `withComponent` returns handles
  in ascending order (`component.dart:46-49`), so "first in ascending handle"
  holds.
- **D12.** The tool listens exactly while `ghostVisible`, and every path calls
  `_syncCamera`. A camera change re-resolves through `_update` (snap, grid and
  attachment). `dispose` removes the listener.
- **D13 (R-C10-1).** The host owns the controller (`late final`, created in
  `initState`, disposed in `dispose`). A bare shell owns its own and disposes
  it. The panel only adds and removes its listener, and moves it in
  `didUpdateWidget`.

**Cross-task interactions checked (none defective):**

- **Task 6 × Task 7 (cache freshness).** `WallFaces._refresh` is keyed on the
  document's identity and `bands.generation`. Any `DocChange` invalidates the
  bands (`wall_bands.dart:141`), so undo, redo, a layer toggled through
  `SetLayerCommand`, another tool's edit and the tool's own `invalidate()` all
  rebuild runs, neighbours and boxes on the next query. `liveWalls` is called
  before the identity check, so the bands' subscription starts on the first
  query in a fresh shell (SS16).
- **Task 7 × Task 8.** `_onCamera`, `_onArmed` (with a context) and every
  pointer event go through `_update`, so the attachment follows a zoom and a
  re-arm. A hidden re-arm clears `_attached`.
- **Task 6 × Task 9 × Task 1 (undo of a copying placement).** The compound's
  inverse runs `SetComponentCommand(null)` before `RemoveDefinitionCommand`,
  so the snapshot is empty and the inverse needs only `structure`. A placement
  needs `components` anyway.
- **Document replacement.** The host keys the shell by its document, so a swap
  builds a new shell with a fresh `WallBands`, `WallFaces` and tool; the
  search controller survives (SS13). Dispose order: `_symbolTool.dispose()`
  (`main.dart:750`) runs before `_bands.dispose()` (`:762`), so no query can
  re-subscribe a disposed band cache.
- **Permissions.** The check precedes allocation; a refused placement neither
  places nor invalidates. A read-only document still shows the attached ghost
  and places nothing.
- **Save and load.** No schema change. WE1 checks Save As → Open → Save
  byte-identical; WE2 checks that a pre-09c plan round-trips byte-identical.

## 3. Task 11a's end-to-end test (not separately reviewed)

**Oracles.**
- **Not independent:** the placed transform is compared bytewise with
  `attachToWall`, computed in the test from `faceRunsOf`. The neighbours are
  the test's own (`backAlong` over `boxOfEntry`), so the tool's
  `WallFaces._neighboursAlong`, its capture radii (`16/scale`, `10/scale`) and
  the raw-point plumbing are checked against an independent build-up. The
  shared parts are `attachToWall`, `faceRunsOf` and `SymbolBox`.
- **Independent:** flushness is measured on the definition's **stored drawn
  vertices** through the instance transform, not on `SymbolBox`. The
  orientation is checked against `±t` and `−m`. Abutment of the three units is
  checked within 1e-9 along `t`, with the last ending at exactly 1,800.
- **Weakness (not a fix):** "the first unit starts at the drawn corner" is
  measured from `inside.a`, which itself comes from `faceRunsOf`. The premise
  only checks it against B's run, also from `faceRunsOf`. WF2 pins the L's
  inside and outside lengths at unit level, so the gap is covered. A stronger
  end-to-end premise would compare `inside.a` with the wall's stored outline
  vertex.

**Fixtures.** The fixtures avoid the degenerate cases:
- walls at 30° and −112.5°, each in a turned and translated group near
  (1e5, −7e4);
- a camera at 0.1 px/mm, rotated 0.3 rad;
- an L of 100 and 240 mm walls with right and left justification, whose drawn
  corner is not the centrelines' meet (asserted, more than 100 mm away);
- a mirrored wardrobe;
- the back-centre off the base point (asserted).

Not covered end to end: mirrored and scaled wall groups (recorded in the note;
covered by `wall_attach_test` and the property test).

**Rulings.**
- **R-C11a-1:** accepted. The 30° wall's outside face (bed) and inside face
  (units) are both exercised.
- **R-C11a-2:** accepted. `1e-9·|run.a|` (about 1.2e-4 mm) is loose against
  1e-11 ulps at 1e5, but every product mutant moves the back by hundreds of
  mm (M-09c-c: 400, M-09c-b: 2,000).
- **R-C11a-3: verified independently.** I built WE2's "pre-09c" plan with
  the same code (same wall, groups, keys, turns, mirrors) twice:
  - in a scratch worktree at `main` `4d6b78f`, from its shipped asset;
  - at the tip, from `test/fixtures/furniture_pre_09c.jetlib`.

  The two files are **byte-identical** (`cmp` equal, 9,075 bytes). So the
  plan built in the test with today's code is exactly the file `main` would
  have saved. I also confirmed the fixture is `main`'s asset
  (`git show 4d6b78f:…/furniture.jetlib | cmp` equal). The scratch worktree
  and the temporary test file were removed afterwards.

**Mutants on the end-to-end file alone** (table below, rows 11a): 5 of 6 red.
The survivor (E2) was my mis-aimed half of M-09c-h: it removes only the
"right side to a neighbour's left end" snap, which WE1 never uses (its units
snap left side to right end). The other half (E2b) is red in WE1, and E2's
own half is red at unit level (F6c, WA7). This is not a test defect.

## 4. Mutant sample on the tip (P-8)

**48 mutants across Tasks 1–11a, 47 red, 1 survivor explained above.** Each
run followed the same steps: `cp` backup, exact single-match replacement
(the match count was asserted to be 1), the named test file(s) run with
`CI=true`, `cp` back, `diff` exit 0 for every one. The catalog mutant also
regenerated the asset and restored it (`cmp` 0). Line numbers are at
`c1ea23c`. Mutants marked "F…" or "E…" are my own; the rest are spec-named.
Full logs are in `scratchpad/final/mut/log_<n>.txt`.

| Task | Mutant | file:line | Result: red test(s) |
|---|---|---|---|
| 1 | M-09c-q undo skips `restore` | commands.dart:451 | RED `+22 -4`: "remove takes them all, undo restores…", "the inverse of an empty snapshot…", "a snapshot of unknown payloads alone…", "an add whose snapshot cannot be restored…" |
| 1 | M-09c-aj forward capabilities `{structure}` | commands.dart:487 | RED `+24 -2`: "the forward capabilities are {structure, components}…", "without components the forward command…" |
| 1 | M-09c-r snapshot skips unknown payloads | component.dart:164 | RED `+21 -5`: incl. "registered components by type id, unknown payloads…" |
| 1 | M-09c-ba inverse always `{structure}` | commands.dart:429 | RED `+24 -2`: "the inverse of an empty snapshot…", "a snapshot of unknown payloads alone is not empty: its undo…" |
| 1 | F1 `detachAll` keeps unknowns | component.dart:174 | RED `+23 -3` |
| 1 | F1b `restore` skips an unregistered type instead of throwing | component.dart:193 | RED `+25 -1`: "an add whose snapshot cannot be restored throws and adds nothing" |
| 2 | M-09c-ai arc bounds from the end points only | symbol_box.dart:99 | RED `+9 -13`: the single-axis arc tests, "each side set by a different kind of leaf" |
| 2 | `back = minY` | symbol_box.dart:111 | RED `+4 -18` |
| 3 | M-09c-ac R03d accepts two families | symbol_library.dart:161 | RED: "R03d a symbol with two family tags is refused" |
| 3 | F3 bookshelf loses `against-wall`, asset regenerated | furniture_catalog.dart:644 | RED `+149 -2`: "the against-wall set is D9's list exactly", "the behaviour tags come last" (asset `cmp` 0 after restore) |
| 4 | M-09c-g2 a T cuts both faces | wall_attach.dart:139 | RED: WF3, WF5, WF9 |
| 4 | M-09c-g3 an X cuts one face only | wall_attach.dart:142 | RED: WF4, WF9 |
| 4 | M-09c-as the T side via `toWorld` | wall_attach.dart:135 | RED: WF3 |
| 4 | M-09c-ag `startCap.last` for the left face | wall_attach.dart:162 | RED `+1 -8`: WF1–WF4 and more |
| 4 | F4 `liveWalls` without the refresh | wall_bands.dart:60 | RED: WB2 |
| 4 | F4b `forward = true` (a run starts at the d-lower end) | wall_attach.dart:175 | RED `+15 -12`: wall_faces and WA2, WA4, WA15 |
| 5 | M-09c-n `-0.0` not cleaned | symbol_placer.dart:63 | RED: P3, P14, P23 |
| 5 | M-09c-o the ghost recomputes on every update | symbol_ghost.dart:132 | RED `+62 -4`: the count tests, "the placement is computed on events, never in a paint" |
| 5 | F5 the `transform` argument ignored | symbol_placer.dart:163 | RED: P24 |
| 6 | M-09c-ah `s ≥ −w` | wall_attach.dart:268 | RED: WA5, WP1 |
| 6 | M-09c-i no clamp | wall_attach.dart:325 | RED: WA4, WA13, WP1 |
| 6 | M-09c-af no distance-to-`[0, L]` key | wall_attach.dart:363 | RED: WA4, WP1 |
| 6 | M-09c-aq a neighbour outside `[0, L]` counted | wall_attach.dart:510 | RED: WA8 |
| 6 | M-09c-au hand-written clamp, no `W ≥ L` case | wall_attach.dart:323 | RED: WA12 |
| 6 | F6 `WallFaces` not keyed on the generation | wall_attach.dart:458 | RED: WA9 |
| 6 | F6b neighbour front-side test dropped | wall_attach.dart:508 | RED: WA8 |
| 6 | F6c neighbour right-to-lo snap removed | wall_attach.dart:316 | RED: WA7 |
| 6 | F6d neighbours skip the orthonormal test | wall_attach.dart:492 | RED: WA8 |
| 7 | M-09c-a the tag ignored | symbol_place_tool.dart:244 | RED: "an untagged symbol (the island)…", "a re-arm between a tagged…" |
| 7 | M-09c-l attachment with F3 off | symbol_place_tool.dart:241 | RED: "with object snap off…" |
| 7 | M-09c-ap no `invalidate()` (tool level) | symbol_place_tool.dart:446 | RED: "W-5: a unit placed right…" |
| 7 | F7 the marker at the resolved point | symbol_place_tool.dart:457 | RED: "the marker is the nearest glyph…" |
| 7 | M-09c-e `isUsableHost` dropped, through the shell | main.dart:369 | RED: SS17 |
| 7 | M-09c-k `R` turns the attached ghost | symbol_place_tool.dart:223 | RED: "a tagged symbol attaches…", "R and Shift+R while attached…" |
| 8 | M-09c-s listener not added | symbol_place_tool.dart:299 | RED `+44 -9`: the camera tests |
| 8 | M-09c-bb not removed on hide (pointer exit) | symbol_place_tool.dart:354 | RED: "after the ghost hides (pointer exit)…" |
| 8 | M-09c-ak the camera re-resolve skips the attachment | symbol_place_tool.dart:304 | RED: "a camera zoom that brings a face within capture…" |
| 9 | M-09c-p base point compared in y only | symbol_placer.dart:199 | RED: L1 "a base point moved in x" |
| 9 | M-09c-bd child nodes ignored | symbol_placer.dart:200 | RED: L1 "a child node" |
| 9 | F9 no sort of the slots | symbol_placer.dart:206 | RED: L6 (leaves out of order) |
| 10 | M-09c-t the panel creates its own controller | symbol_panel.dart:116 | RED `+27 -8`: the panel D13 tests and SS12–SS15 |
| 10 | F10 the host passes a new controller per build | document_host.dart:643 | RED: SS13, SS14 |
| 11a | E1 the release ignores the attached transform | symbol_place_tool.dart:445 | RED: WE1, WE2 |
| 11a | E2b neighbour left-to-hi snap removed (M-09c-h's half WE1 uses) | wall_attach.dart:311 | RED: WE1 |
| 11a | E2 neighbour right-to-lo snap removed | wall_attach.dart:316 | **SURVIVED** on the end-to-end file (`+2`); mis-aimed (WE1 never snaps a right side to a neighbour); red at unit level (F6c, WA7) |
| 11a | E3 `geomIndex` not exempted in leaf-equality | symbol_placer.dart:218 | RED: WE1, WE2 |
| 11a | E4 M-09c-j the mirror dropped at the tool | symbol_place_tool.dart:249 | RED: WE2 |
| 11a | E5 `back = minY` | symbol_box.dart:111 | RED: WE1, WE2 |

## 5. Non-negotiables

- **The allocation invariant tests are unedited:**
  `git diff --stat 904970d c1ea23c` over
  `packages/jet_cad_2d/test/invariants` and
  `packages/jet_cad_2d_flutter/test/invariants` is empty. Both are green
  inside the engine and render runs above.
- **Frame path.** `paintWorldOverlay` builds no path, transform or matrix; it
  passes the event-time `Transform2` to `GhostMatrix.update`, which compares
  and rewrites in place. `paintOverlay` while attached allocates 9 `Offset`s
  per paint: O(1) per flush, nothing per entity, recorded in the note.
  `WallFaces` rebuilds only on a document or generation change, never in a
  paint. `attachToWall` allocates only its result (no closure since 6b).
- **Draw order.** A copied definition's leaves keep the library's ascending
  order (the placer is unchanged there). No handle is reordered.
- **Tolerance vs `==`.** Geometric decisions (capture, the run-length test,
  piece dropping, neighbour on-line, ranking ties, `isOrthonormal`) use
  `wallJoin.linear` or `Tolerance.standard`. Stored values (leaf equality,
  the ghost's six doubles, the snapshot round trip) use exact `==`. The edge
  snap's tie test is exact, by ruling R-C6-2. I accept it: an exact tie-break
  between two shifts is deterministic, and a near-tie resolves to the smaller
  shift.
- **No `analysis_options.yaml` in the diff** (`git diff --name-only` checked).
- **Purity.** `wall_attach.dart` and `symbol_box.dart` import neither
  `package:flutter` nor `dart:ui`. My own transitive-closure script over the
  app's `lib/` finds closures of 20 and 17 files, none Flutter-importing,
  matching the note.
- **Render package untouched; engine `lib/` touched only by `a5a6b35`; no
  `lib/` change after `2a1f8c2`** (`git log` per path). The four Task 6 files
  at the tip are byte-identical to `e9b0a52` (`git diff --stat` empty).

**Spot-check of the results note against the ledger and my own runs.** All
five agree:

1. Task 2's "10,000 random arcs, 0 mismatches" is `task-2-review.md:36`.
2. Task 4's "differential 7,634 runs" is `task-4-review.md:31` (6,228 +
   1,406).
3. Task 6's "22,500 queries over 75 scenes" is `task-6-review.md:14, :142,
   :149`.
4. Task 7's "18 of 19 mutants red, the survivor M-09c-ap at the shell" is
   `task-7-review.md:79`.
5. Task 10's "14 mutants red" is `task-10-review.md` §3 (14 rows, "All 14
   are red").

The gates of record (engine 1,237 + 2, render 1,187 + 1 skip + 7, app 1,169,
web, harness) equal my own runs, and the note's purity counts (20, 17) equal
my script's. No synthesized output found.

## 6. Docs

- **The results note** is accurate as far as I checked:
  - the task and commit table;
  - the rulings: R-C11a-3 is now independently confirmed;
  - the gates and the mutant table;
  - the survivors: M-09c-ap at the shell and end to end, consistent with my
    tool-level red;
  - found-not-fixed and owed-to-09c-2;
  - the look list: the spec's 09c-1 list copied whole, plus three
    execution items, with "Nothing is marked done for the human".

  It says the final review is still to come and claims no merge.
- **The spec's "Amended at execution (Plan 09c-1)"** records every departure I
  found in the code: D13's owner, the hourglass marker (C-5), the keys'
  stored query, D11's unknown order and `detachAll` and R-C1-4, D2's nullable
  box, D9's fixture, D3's API, D4's tolerant ties and `exclude`, D5's `at`,
  D10's record `==`, and D12's disarm. The header says "09c-1 executed …
  (not merged …)".
- **The roadmap rows** (`00-README.md`, `09-symbol-library.md`) say
  "executed on `plan-09c/wall-attach`, merge pending the human's word, macOS
  and web look OWED; 09c-2 unwritten". They claim no merge and no look.

## Fixes

None required.

**Optional nit** (no re-review needed):
- `apps/floor_planner/lib/symbols/symbol_ghost.dart:102`: the doc comment
  still says "(Task 8 will add camera events)", but Task 8 added them
  (`7150bd1`). Suggested wording: "computes it on pointer, key, arm and camera
  events".

**Observation, not a fix:** WE1's corner premise could compare `inside.a`
with the wall's stored outline vertex rather than with another `faceRunsOf`
run (§3). Unit-level WF2 already pins it.
