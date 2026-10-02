# Wall-aware placement, slice 09c-1 — implementation plan

> **For agentic workers:** executed task by task, subagent-driven: a fresh
> implementer per task and an independent reviewer per task (in a detached
> worktree, re-running the gates and re-firing the mutants), then a final
> whole-branch review. Steps use checkbox (`- [ ]`) syntax.

**Goal:** a symbol the catalog tags `against-wall`, armed in the Symbols tab,
lands flush on the face of a visible, unlocked wall when the pointer comes
near it: its back on the face, turned to the wall, its sides snapping to the
face's drawn end and to other symbols against the same face, kept within the
face. The catalog grows to 41 symbols in six size families plus two
appliances. Four debts close: a removed definition takes its components, a
definition whose leaves differ is not reused, the ghost follows a wheel zoom,
the search text survives a tab switch.

**Spec:** [docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md](../specs/2026-10-02-wall-aware-symbols-design.md),
**revision 4** (`751755f`), **approved by the human on 2026-10-02** ("yaz").
Read it whole before Task 1. This plan is **09c-1**: spec D2–D6, D9–D13 and
the 09c-1 half of the Exit gate. **09c-2** (D7, D8: the Symbol section, the
wall-aware move, `SetInstanceDefinitionCommand`, the render seam) is a later
plan, cut after 09c-1 merges. The spec was reviewed three times (W-1–W-17,
S-1–S-10, T-1–T-7); its named mutants are M-09c-a … M-09c-be. The human's
decisions 1–11 are at its top.

**Architecture:**
- **Engine** (`packages/jet_cad_2d`): `ComponentRegistry.snapshotOf` /
  `restore`; `RemoveDefinitionCommand` takes the handle's components (Task 1).
  Frozen after Task 1.
- **Render layer** (`packages/jet_cad_2d_flutter`): **untouched** in 09c-1.
- **App** (`apps/floor_planner`): `lib/symbols/symbol_box.dart` (Task 2), the
  catalog, loader rule R03d and the regenerated asset (Task 3),
  `WallBands.liveWalls` and the face runs in `lib/symbols/wall_attach.dart`
  (Task 4), the generalised placement transform and ghost matrix (Task 5),
  `attachToWall` and `WallFaces` (Task 6), the tool's attachment and
  the shell wiring (Task 7), the wheel zoom (Task 8), leaf-equal reuse
  (Task 9), the search text in the shell (Task 10).

**Tech stack:** Dart, Flutter 3.47.2 at `/root/flutter` (installed in this
container on 2026-10-02 from `storage.googleapis.com/flutter_infra_release/
releases/stable/linux/flutter_linux_3.47.2-stable.tar.xz`; reinstall the
same if missing). **No new dependency.**

## Rulings made here rather than left to an implementer

- **P-1 (branch).** `plan-09c/wall-attach`, cut from
  `spec-09c/wall-aware-symbols` at the commit that adds this plan; worktree
  `.worktrees/plan-09c1` (git-ignored). Reviews in a detached worktree
  `.worktrees/plan-09c1-review` at the reviewed commit. Ledger, briefs and
  reports in `.superpowers/sdd/plan-09c1/` (git-ignored) inside the plan
  worktree. Reviewed commits are pushed to `origin/plan-09c/wall-attach`.
  The merge is the human's, `--no-ff`, from the main checkout. The proxy
  refuses remote branch deletion: name merged branches for the human.
- **P-2 (fixtures, the testing bar).** The spec's Testing section is
  binding. Every attachment fixture: a wall at **30°** and one at
  **−112.5°**, in a group with a non-identity transform, far from the
  origin (`(1e5, −7e4)`); every justification and both faces; a
  **mirrored** group (centre-justified, with a T) and a **scaled** group,
  each **joined** and **fallen back**; the toilet and an off-centre test
  symbol (base point off-centre in both axes); mirrored and not. The one
  named exception is M-09c-n's axis-aligned wall. A camera scale ≠ 1 and a
  pointer far from the origin in every tool test. A test is owed a named
  mutant that turns it red; the implementer fires it, the reviewer fires it
  again.
- **P-3 (shared fixtures).** `test/support/wall_fixture.dart` and
  `symbol_fixtures.dart` are reused and extended; a new
  `test/support/wall_attach_fixture.dart` builds the 30° / −112.5° /
  mirrored / scaled scenes once, for Tasks 4, 6, 7 and 11.
- **P-4 (where the face code lives).** `wall_attach.dart` holds
  `FaceRun`, `faceRunsOf`, `attachToWall`, `WallFaces`; it imports
  `package:jet_cad_2d`, `../parametric/{wall,wall_geometry,
  opening_geometry,wall_bands}.dart` and `symbol_component.dart` /
  `symbol_box.dart` only — **no Flutter, no `dart:ui`** (spec D1, T-4). The
  host predicate (`isUsableHost`) is passed in by the shell. Task 4 checks
  that `opening_geometry.dart` and `wall_bands.dart` import no Flutter
  either (if one does, the predicate pattern applies to it too and the
  report says so).
- **P-5 (the asset).** Task 3 edits the catalog, then runs
  `dart run tool/generate_furniture_library.dart` (in `apps/floor_planner`);
  the committed `assets/library/furniture.jetlib` is the generator's output,
  byte for byte. No later task changes the catalog without regenerating.
- **P-6 (existing tests that change meaning).** SC12
  (`test/symbols/symbol_component_test.dart:257-274`) is rewritten by Task 1
  to the new behaviour; 09b's `GhostMatrix` tests move to the new signature
  in Task 6 with their counts kept; the library's "27 symbols" assertions
  (`furniture_library_test.dart:56` and any other) move to 41 in Task 3. A
  task that rewrites an existing assertion names it in its report with the
  old and new line.
- **P-7 (container restarts).** Every agent commits as soon as its gates are
  green, writes its report early and appends to it, and runs mutants in the
  foreground in small batches; a mutant's backup is restored by `cp` and
  checked by `diff`.
- **P-8 (mutant table at the end).** 09a's P-8 rule: the results note's
  table is compiled from each task's report and review (both fire real
  runs); the final whole-branch review re-fires a sample across every task
  on the tip.

## Global constraints

- CLAUDE.md's non-negotiables. The frame path: the ghost paints through the
  reused matrix with no `Transform2` built in a paint (D5, W-15); the face
  and neighbour caches are built on a document change, never on a paint.
  The two allocation invariant tests stay **unedited** and green.
- Draw order: a copied definition's leaves keep the library's ascending
  order; no task reorders handles.
- Tolerance for decisions (`wallJoin.linear` and `Tolerance.standard` as
  the spec names them), exact `==` for stored values (leaf equality, the
  ghost's recompute test, the snapshot round trip, transforms compared
  component-wise).
- `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
- Never `git checkout --` a `.dart` file; mutants by `cp` backup, mutate,
  run the named test file, `cp` back, `diff` exit 0.
- Never commit `analysis_options.yaml` (`flutter pub get` rewrites
  `packages/jet_cad/analysis_options.yaml`; stage files by explicit path).
- Never synthesize output. Code, comments, commit messages in English.
- Commit trailers:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_017Jpc94HDwBboPTaZBjjAFr
  ```
- Scratch: a per-agent directory under
  `/tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/`,
  named in its brief.

## Gates (every task)

```sh
export PATH=/root/flutter/bin:$PATH
(cd packages/jet_cad_2d         && CI=true dart test ; CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd packages/jet_cad_2d_flutter && CI=true flutter test ; CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd apps/floor_planner          && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
```
Plus `CI=true flutter build web --release` in the app from Task 3 on, and
`(cd apps/dev_harness_2d && CI=true flutter analyze)` after Task 1.
**Branch point** (`main` `4d6b78f`, measured on 2026-10-02 in this
container): engine 1,226 + 2 standing
(`test/testing/generate_document_test.dart`, as STATUS records); render 1,187 + 1 skip + 7
standing (`test/golden/text_ladder_golden_test.dart`, the canvas text
ladders); app 993, all passing. A task that touches only one package may state
the others unchanged rather than re-run them (say so in the report).

## File structure

| File | Task |
|---|---|
| `packages/jet_cad_2d/lib/src/document/component.dart`, `commands.dart`; `test/document/definition_commands_test.dart`; `apps/floor_planner/test/symbols/symbol_component_test.dart` (SC12) | 1 |
| `apps/floor_planner/lib/symbols/symbol_box.dart` (new); `test/symbols/symbol_box_test.dart` (new) | 2 |
| `apps/floor_planner/lib/symbols/furniture_catalog.dart`, `symbol_library.dart` (R03d), `assets/library/furniture.jetlib`; `test/symbols/{furniture_library,symbol_library}_test.dart` | 3 |
| `apps/floor_planner/lib/parametric/wall_bands.dart` (`liveWalls`); `lib/symbols/wall_attach.dart` (new: `FaceRun`, `faceRunsOf`); `test/wall_bands_test.dart`, `test/symbols/wall_faces_test.dart` (new), `test/support/wall_attach_fixture.dart` (new) | 4 |
| `lib/symbols/symbol_placer.dart` (rotation vector, optional `transform`), `symbol_ghost.dart` (`GhostMatrix.update(placement:)`); `test/symbols/{symbol_placer,symbol_ghost}_test.dart` | 5 |
| `lib/symbols/wall_attach.dart` (`attachToWall`, neighbours, `WallFaces`); `test/symbols/wall_attach_test.dart` (new) | 6 |
| `lib/symbols/symbol_place_tool.dart`, `lib/main.dart` (bands, faces, predicate to the tool); `test/symbols/{symbol_place_tool,symbol_shell}_test.dart` | 7 |
| `lib/symbols/symbol_place_tool.dart` (camera); `test/symbols/symbol_place_tool_test.dart` | 8 |
| `lib/symbols/symbol_placer.dart` (leaf-equal reuse); `test/symbols/symbol_placer_test.dart` | 9 |
| `lib/main.dart`, `lib/symbols/symbol_panel.dart` (the shell's controller); `test/symbols/{symbol_panel,symbol_shell}_test.dart` | 10 |
| `test/symbols/wall_attach_end_to_end_test.dart` (new); `docs/superpowers/notes/2026-10-0x-plan-09c1-results.md` (new); the spec's "Amended at execution (Plan 09c-1)"; `roadmap/09-symbol-library.md`, `roadmap/00-README.md`; the ledger archive | 11 |

---

### Task 1: Engine — a removed definition takes its components (spec D11)

- [ ] `ComponentRegistry.snapshotOf(Handle h)`: an immutable value holding
  every **registered** component on `h` (type id and value) and every
  **unknown** payload (`unknownOf`), ordered by type id;
  `restore(Handle h, snapshot)` re-attaches each exactly. A component type
  registered after the snapshot was taken is not invented; an empty
  snapshot is a value with `isEmpty`.
- [ ] `RemoveDefinitionCommand`: on `apply`, takes the snapshot, detaches
  every component on the handle (registered and unknown), then removes the
  definition; its inverse re-adds the definition **and** restores the
  snapshot. **`capabilities` are static** `{structure, components}` (W-1);
  the summary `capability` stays `structure`; the inverse declares
  `{structure}` plus `components` when its snapshot is not empty. Every
  existing guard and `touched` is unchanged.
- [ ] Engine tests (`definition_commands_test.dart`): a definition carrying
  two registered components of different types and one unknown payload —
  remove: none left (`get` null, `unknownOf` empty), `toJson` of the
  registry differs; undo: `components.toJson()` byte-identical to before;
  redo: gone again. Capabilities: the forward set is `{structure,
  components}` even with nothing attached (the dispatcher checks before
  `apply`); a `DraftPermissions(structure: true, components: false)` refuses
  the forward command before anything changes; the inverse of an empty
  snapshot runs under the same permissions, the inverse of a non-empty one
  is refused. The existing `capability == structure` assertions
  (`:165-184`) stay.
- [ ] App: **SC12** rewritten (the component no longer survives
  `RemoveDefinitionCommand`; the old assertion and the new are in the
  report). The placer's undo tests P5, P9, P10, P17, P18 pass unchanged.
- [ ] Mutants: **M-09c-q** (undo skips `restore`), **M-09c-r** (the
  snapshot skips unknown payloads), **M-09c-aj** (forward capabilities
  without `components`), **M-09c-ba** (the inverse without `components` for
  a non-empty snapshot); plus: detach skipped (the component survives).
- [ ] Gates: engine, app; render unchanged (state it); `dev_harness_2d`
  analyze. Commit `feat(engine): a removed definition takes its components`.

### Task 2: App — the symbol's local box (spec D2)

- [ ] `symbol_box.dart` (pure): `SymbolBox {left, right, front, back}` with
  `width`, `depth`, `backCentre` (`((left+right)/2, back)`); `boxOfLeaves(
  Iterable<(EntityKind, GeometryPayload)>)` with lines and polylines by
  vertices, circles by centre ± r, **arcs by their true extents** (the end
  points plus each axis extreme the counter-clockwise sweep passes);
  `boxOfEntry(SymbolEntry)` memoised per entry (`Expando`);
  `boxOfDefinition(DraftDocument, Handle)` from the definition's live leaves.
  (The per-document memo cleared on change belongs to `WallFaces`, Task 5.)
- [ ] Tests: every catalog symbol's box equals a hand-derived literal for at
  least the toilet (its front is the bowl's arc at `y = 0`: `ArcShape(200,
  200, 200, π, π)` reaches `y = 0` only through its axis extreme), the hob
  (circles), the tub; an arc whose sweep crosses 0 rad, π/2, π and 3π/2
  separately; a sweep that crosses none; a negative-start arc. A definition
  in a document gives the same box as its entry.
- [ ] Mutants: **M-09c-ai** (arc bounds from the end points only), an axis
  extreme off by one quadrant, `back = minY` (the box's own test; M-09c-b's
  attachment half is Task 5's).
- [ ] App gate. Commit `feat(app): a symbol's local box`.

### Task 3: App — content, families, the wall tag (spec D2, D9)

- [ ] The catalog: the 14 new symbols of D9's table, code-drawn in the
  catalog's style (`_rect`, `_inset`, lines, circles, arcs), front on
  `y = 0`, base point on the box's centre `x` and off the origin; categories
  as their family's existing member (the dishwasher and the washer in
  Kitchen). Names: "Double bed 1400", "Double bed 1800", "Single bed 800",
  "Single bed 1000", "Wardrobe 1200", "Wardrobe 2400", "Base unit 300",
  "Base unit 400", "Base unit 800", "Desk 1200", "Desk 1600", "Two-seat
  sofa", "Dishwasher", "Washing machine". Existing names unchanged.
- [ ] Tags: `against-wall` and `family:<id>` exactly per D9 (the existing
  symbols gain them at `version: 1`, the spec's tag-only ruling; no
  existing key, name, shape or version changes). Order: the existing tags,
  then `against-wall`, then `family:…`.
- [ ] The loader: **R03d**, a symbol with two `family:` tags is refused
  (`SymbolLibraryError` naming the key).
- [ ] The asset regenerated (P-5); the pubspec unchanged.
- [ ] Tests: 41 symbols (the "27" assertions moved, P-6); every family's
  members share `depth`, `front` and `back` (D2 box, Task 2); every symbol's
  base point `x` equals its box's centre `x` (exact, D4 step 5); the
  `against-wall` set equals D9's list exactly (a literal set of keys);
  the families equal D9's table (literal); each new symbol's box `W × D`
  equals its table row; R03d refuses a hand-built two-family library;
  "the committed bytes equal the built library" passes; every new symbol
  placed at turns 1 and 3 mirrored validates empty (09a Task 5's loop
  covers them by iterating the library — confirm it iterates, do not copy
  it).
- [ ] Mutants: **M-09c-ac**, **M-09c-ar** (one family member's depth
  changed, regenerated), a new symbol's base point off its centre `x`,
  `against-wall` dropped from one symbol, the asset not regenerated after a
  catalog edit.
- [ ] Gates incl. web. Commit `feat(app): size families, two appliances and
  the wall tag`.

### Task 4: App — the wall faces (spec D3)

- [ ] `WallBands.liveWalls(DraftDocument doc)`: runs the private refresh
  (so the document subscription starts) and returns an unmodifiable view of
  the live walls' handles, ascending; `generation` moves as today.
- [ ] `wall_attach.dart`: `FaceRun {a, t, m, length, thickness (w), wall,
  side}` in world; `faceRunsOf(DraftDocument doc, Handle wall, List<
  WorldWall> walls)` per D3 exactly: the faces from the frame's drawn cap
  points (left `startCap.first`/`endCap.last`, right
  `startCap.last`/`endCap.first`) mapped by `toWorld`; the direction from
  `toWorld.transformDirection(frame.d)` normalised; the extent by
  projection; `m` away from the other face line; `w` by projection; T cuts
  on the butted face only, the side by the **local** test
  `toLocal.transformDirection(End(B, k).a) · frame.n > 0`; X cuts per face
  from that face's two crossings with B's drawn face lines; pieces no longer
  than `wallJoin.linear` dropped; `Obstacle` unchanged; openings ignored.
  Uses `hostFrameOf`, `wallsInDocument`, `obstaclesOf`'s walls; never
  `stretchesOf`.
- [ ] Tests (`wall_faces_test.dart`, fixtures from
  `wall_attach_fixture.dart`): a free wall's two runs, both justifications'
  zero-offset face included, at 30° far from the origin, `m` and `t` per
  D3 (`t = (−m.y, m.x)`), `w` equal to the thickness; an L of 100 and 240
  mm: the inside face shorter than the centreline by the hand-derived
  amount, the outside longer; a T: only the butted face split, the cut
  equal to the stem's drawn faces' crossings; an X at 60°: each face cut by
  its own interval (not the union); a **mirrored** centre-justified group
  with a T (the local side test cuts the right face; the world test would
  not); a **scaled** group joined and fallen back (`w` = the drawn
  thickness, the face on the drawn outline: assert against the wall's
  stored outline vertices); a degenerate wall gives none; `liveWalls` in a
  fresh `WallBands` sees a wall added after construction.
- [ ] Mutants: **M-09c-f**, **M-09c-g1**, **M-09c-g2**, **M-09c-g3**,
  **M-09c-ag**, **M-09c-as**, **M-09c-at**, **M-09c-ay**; `liveWalls`
  without the refresh.
- [ ] App gate. Commit `feat(app): wall face runs`.

### Task 5: App — the generalised placement transform (spec D5)

- [ ] `placementTransform` gains `rotation: (double cos, double sin)?`
  (mutually exclusive with `quarterTurns`, asserted and thrown in release);
  the quarter-turn form uses the exact table through it; `-0.0`
  normalised in both. `placeSymbol` gains `Transform2? transform`, used
  verbatim instead of `placementTransform` when given.
- [ ] `GhostMatrix.update(placement: Transform2)`: compares the six
  doubles with the last exactly; `computations` counts recomputes. 09b's
  ghost tests move to the new signature with the same counts (P-6).
- [ ] Tests: a 30° rotation vector gives the hand-derived matrix; the
  quarter-turn form is bitwise unchanged (09b's P1–P4, P14 pass);
  `placeSymbol(transform:)` stores the transform's bytes exactly; equal
  placements recompute once, a change in any one of the six doubles
  recomputes.
- [ ] Mutants: **M-09c-n** (the generalised form), **M-09c-o**, the
  `transform` argument ignored.
- [ ] App gate. Commit `feat(app): a placement at any angle`.

### Task 6: App — `attachToWall`, neighbours, `WallFaces` (spec D4)

- [ ] `attachToWall(runs, box, p, captureWorld, {required bool mirrored,
  required List<(FaceRun-relative interval)> neighbours, required double
  edgeCaptureWorld})` → `({Transform2 transform, Vector2 q, FaceRun run})?`,
  D4 steps 1–5 exactly: candidates by `−w/2 ≤ s ≤ capture` and the `u`
  window; ranking `|s|`, then distance from `u` to `[0, L]`, then wall
  handle, then left face, then `a·t`; `W ≤ L + wallJoin.linear`; `R` from
  `t` with `-0.0` normalised; edge snaps (run ends, neighbours' ends; the
  smallest shift wins, a tie to the smaller `u`); the clamp, `u = L/2` when
  `W ≥ L`; the transform `placementTransform(at: q, basePoint: backCentre,
  rotation: (t.x, t.y), mirrored)` (Task 5's form).
- [ ] Neighbours (D4): root-level instances on a visible, unlocked layer
  whose definition has a `SymbolComponent`, orthonormal per the spec's
  definition, back edge on the run's line within `wallJoin.linear`, front
  on the room side, interval along `t` overlapping `[0, L]`; an `exclude`
  handle for 09c-2.
- [ ] `WallFaces` (shell-owned): built from `bands.liveWalls`, the host
  predicate and the document; caches runs and neighbours keyed on
  `bands.generation` and the boxes of documents' definitions; a pointer
  query over a cached set allocates O(1).
- [ ] Tests (`wall_attach_test.dart`): every D4 step and null case at 30°
  and −112.5°, mirrored and not; the toilet's back exactly on the face (the
  transformed back-edge points at distance ≤ 1e-9 from the face line) and
  its front in the room; the pointer inside the band attaching to its own
  half's face for each justification; the T tie (pointer 1 px right of a
  stem narrower than `captureWorld − 1 px`, nearer the host face than the
  stem's face: the right piece wins); edge snaps to a run end and to a
  neighbour rotated 180°; a back-to-back symbol on the opposite face is not
  a neighbour; a neighbour outside `[0, L]` is not one; the niche (`L = W −
  2e-10`: assert `L < W`, then `u == L/2` exactly); a run shorter than `W`
  → null; an axis-aligned wall's transform has no `-0.0` (M-09c-n's
  exception); the far face with no run at `p`'s `u` (M-09c-ah's `−w`
  variant).
- [ ] Mutants: **M-09c-b**, **-c**, **-d**, **-h**, **-i**, **-j** (at the
  function), **-m**, **-n**, **-af**, **-ah** (both), **-aq**, **-au**;
  `WallFaces` not keyed on the generation.
- [ ] App gate. Commit `feat(app): attach a symbol to a wall face`.

### Task 7: App — the placement tool attaches (spec D6)

- [ ] The tool takes the shell's `WallFaces` (optional; without it, today's
  behaviour bit for bit). On each pointer event, after `_resolve`: when the
  armed entry's tags contain `against-wall`, `ctx.snap?.objectSnap` is on,
  and `attachToWall` with `p` = the raw pointer returns a result, the
  ghost's placement and the release use its transform and the marker is
  drawn at `q` with the `SnapKind.nearest` glyph; else today's path.
  `kWallAttachPixels = 16.0`.
- [ ] The transform is computed on pointer, key and camera events and kept
  in a field; `paintWorldOverlay` only passes it to `GhostMatrix.update`
  (W-15).
- [ ] Keys while attached: `M` toggles the mirror (the attached transform
  follows); `R` / `Shift+R` change the turn count only (the ghost does not
  turn); off the face, the count applies.
- [ ] After its own commit the tool calls `bands.invalidate()`.
- [ ] `main.dart`: one `WallFaces` built over the shell's `WallBands`, the
  document and `isUsableHost`, handed to the tool; disposed with the shell.
- [ ] Tests (`symbol_place_tool_test.dart`, `symbol_shell_test.dart`): a
  tagged symbol attaches on hover and on release at 30° far from the origin
  at scale ≠ 1, the placed instance's transform equals `attachToWall`'s
  bytes; an untagged one (the island) does not; F3 off does not; a hidden
  and a locked wall do not host; `M` while attached mirrors in place; `R`
  while attached changes nothing visible, then turns off the face; the
  marker at `q`; **a fresh shell** where no Wall or Opening tool ran: two
  units placed in a row, the second snaps to the first (W-5); one undo step
  per placement; the permission check still precedes allocation.
- [ ] Mutants: **M-09c-a**, **-e** (through the shell's predicate),
  **-j**, **-k**, **-l**, **-ap**; the marker at the raw point.
- [ ] Gates incl. web. Commit `feat(app): place a symbol against a wall`.

### Task 8: App — the ghost follows a wheel zoom (spec D12)

- [ ] The tool keeps the last pointer's screen point; while the ghost is
  visible it listens to the camera and re-resolves snap, grid **and
  attachment** from that screen point (`PlacementTool`'s pattern); the
  listener is removed when the ghost hides, on `cancel`, on a disarm and on
  `dispose`.
- [ ] Tests: a camera zoom about a point other than the pointer moves the
  ghost to the new world point under the same screen point; a zoom that
  brings a face within capture attaches; after hide, cancel, disarm and
  dispose, a camera change does nothing (and does not throw after
  dispose).
- [ ] Mutants: **M-09c-s** (not added; not removed on dispose, with a live
  camera), **M-09c-ak**, **M-09c-bb** (each of hide, cancel, disarm).
- [ ] App gate. Commit `fix(app): the symbol ghost follows a wheel zoom`.

### Task 9: App — leaf-equal reuse (spec D10)

- [ ] The placer's lookup reuses a found definition only when leaf-equal
  per D10: the base point; no child nodes; the live leaf count; pairwise,
  ascending handle, every `EntityRecord` field but `handle`, `owner` and
  `geomIndex`, and the payload's coordinates and scalars, exact `==`. A
  non-equal one is passed over; none left: a copy under the `#n` rule.
- [ ] Tests: an edited leaf coordinate, scalar, colour, lineweight, flags,
  text field, an extra leaf, a missing leaf, a child node and a moved base
  point each cause a copy (`#2` name, two definitions); an unedited one is
  reused (P7's count stays); `-0.0` vs `0.0` counts as equal (stated, not a
  mutant).
- [ ] Mutants: **M-09c-p** (payload scalar; a style field; the base point,
  each), **M-09c-bd** (child nodes; leaf count, each).
- [ ] App gate. Commit `fix(app): do not reuse an edited symbol definition`.

### Task 10: App — the search text survives a tab switch (spec D13)

- [ ] The shell owns the search `TextEditingController` (created in
  `initState`, disposed in `dispose`) and passes it to `SymbolPanel`, which
  no longer creates or disposes one. The panel is still removed on the
  Tools tab.
- [ ] Tests: type "bed", switch to Tools and back: the field reads "bed" and
  the gallery is filtered; a document replacement keeps it; the panel
  disposed does not dispose the controller (it stays usable).
- [ ] Mutants: **M-09c-t** (the panel creates its own controller again),
  the shell recreating it per build.
- [ ] App gate. Commit `fix(app): keep the symbol search across tab
  switches`.

### Task 11: End to end, sweep, results, the ledger (spec Exit gate)

- [ ] `wall_attach_end_to_end_test.dart`: the host with the real asset, a
  plan with a 30° wall far from the origin and an L corner: arm the double
  bed, hover near the face, release: the instance flush and turned; arm a
  base unit, place three along the inside face from the corner, each
  snapping to the previous; undo three times, redo; Save As (fake files) →
  Open → Save byte-identical; a plan saved before 09c (a fixture saved at
  `main` `4d6b78f`'s schema, the real 27-symbol definitions) opens and its
  symbols' bytes are unchanged.
- [ ] The P-8 rule: the mutant table from the task reports and reviews; the
  final whole-branch review re-fires a sample on the tip.
- [ ] The two allocation invariant tests unedited (empty `git diff` over
  both `test/invariants` directories since the branch point); no
  `analysis_options.yaml` in the diff; purity greps (`wall_attach.dart`,
  `symbol_box.dart`: no `package:flutter`, no `dart:ui`).
- [ ] `docs/superpowers/notes/<date>-plan-09c1-results.md` (the 09b form:
  tasks and commits, rulings found at execution, gates of record, mutants,
  found-not-fixed, **the human's look list** copied from the spec's 09c-1
  Exit gate, nothing marked done for the human); the spec's "Amended at
  execution (Plan 09c-1)"; `roadmap/09-symbol-library.md` and
  `roadmap/00-README.md` status rows.
- [ ] The final whole-branch review (a fresh reviewer, a detached worktree),
  its fixes, then the ledger archive to
  `docs/superpowers/ledgers/<date>-plan-09c1/` with a README row, as the
  branch's last commit.
- [ ] Gates (all three + web + harness). Commits `test(app): wall-aware
  placement end to end`, `docs: plan 09c-1 results`, `docs: archive the
  plan 09c-1 ledger`.

## Exit gate (09c-1)

- Engine, render layer, app: standing gates green with `CI=true`; the
  standing failures unchanged from the branch point; `flutter build web
  --release` builds; `dev_harness_2d` analyzes clean; the two allocation
  invariant tests unedited and green.
- Every named mutant of Tasks 1–10 fired red (any equivalent one recorded
  by experiment), re-fired by the task's reviewer; the final review's sample
  on the tip.
- **The human's look on macOS and web (Chrome, Firefox), light theme**, per
  the spec's 09c-1 Exit gate list; never marked done for the human.
- Merge on the human's word, `--no-ff`, from the main checkout; STATUS
  through a small docs branch merged `--no-ff`; the roadmap rows; `main`
  pushed; worktrees and local branches removed; merged remote branches
  named for the human. Then 09c-2's plan, cut from `main`.
