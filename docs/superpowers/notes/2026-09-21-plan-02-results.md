# Plan 02 — interaction core: results

**Plan:** [2026-09-21-interaction-core.md](../plans/2026-09-21-interaction-core.md).
**Spec:** [2026-09-21-interaction-core-design.md](../specs/2026-09-21-interaction-core-design.md)
(revision 2, amended at execution 2026-09-22 — see "Spec amendments" below).
**Mutation log:** [plan-02-mutation-log.md](plan-02-mutation-log.md).
**Branch:** `plan-02/interaction-core`, worktree
`.claude/worktrees/plan-02-interaction-core`, cut from `main` at `3fedeb9`.
**Twelve tasks done, `3fedeb9..afe7d64` (Tasks 1–11); Task 12 (the results
note, spec amendments, STATUS and the roadmap) landed on top at `b02410a`,
and a **final fix wave** — every open finding of the whole-branch review and
of Task 12's own review, items A1-A7 (code) and B1-B8 (docs) — on top of
that. NOT merged — the merge is the human's decision, after the look this
note leaves OWED.**
**Ledger (per-task briefs, reports, review diffs, every ruling):**
`.superpowers/sdd/2026-09-21-interaction-core/`.

---

## What was measured

### The four gate lines, pasted

**Re-run in full after the final fix wave** (items A1-A7), on the tree that
commit leaves behind; these summaries replace the ones Task 12 recorded.

**`packages/jet_cad_2d`** — `CI=true dart test`:

```
00:03 +820: All tests passed!
```
Exit 0. `dart analyze`: `Analyzing jet_cad_2d... No issues found!` Exit 0.
`dart format --output=none --set-exit-if-changed .`: `Formatted 116 files (0
changed) in 0.21 seconds.` Exit 0. `git status --short` clean after the line.

**`packages/jet_cad_2d_flutter`** — `CI=true flutter test`:

```
00:11 +769 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

Exit 1 — **769 pass, 1 pre-existing skip, and exactly the same five
pre-existing `text_ladder_golden_test.dart` failures named above (`text
ladder rung 1..5`, `RenderBackend.canvas`) and nothing else** — the Plan 01
baseline ruling stands (goldens recorded 2026-08-24, SDK 3.47.2; pixel drift,
not a regression this plan introduced). `flutter analyze`: `Analyzing
jet_cad_2d_flutter... No issues found!` Exit 0. `dart format --output=none
--set-exit-if-changed .`: `Formatted 136 files (0 changed) in 0.26 seconds.`
Exit 0. `git status --short` clean after the line; no `analysis_options.yaml`
rewrite this run.

**`apps/dev_harness_2d`** — `CI=true flutter test --concurrency=1`:

```
00:20 +82: All tests passed!
```

Exit 0 — **82 tests**, matching the branch-point count (`git diff --stat
main..HEAD -- apps/dev_harness_2d` empty, spec criterion 11). `flutter
analyze`: `Analyzing dev_harness_2d... No issues found!` Exit 0. `dart format
--output=none --set-exit-if-changed .`: `Formatted 22 files (0 changed) in
0.05 seconds.` Exit 0. `git status --short` clean after the line.

**`apps/floor_planner`** — `CI=true flutter test`:

```
00:00 +12: All tests passed!
```

**12 tests** — eleven before this wave, plus A5's
`planner_shell_test.dart`: `cmd+Z undoes a Delete through the command log`.
(Task 12's note read the old `+11` as twelve; `+N` counts tests **passed**,
so the app had eleven then and has twelve now.) Including
`startup_plan_test.dart`'s clamp line, pasted again below. `flutter analyze`:
`Analyzing floor_planner... No issues found!` Exit 0. `dart format
--output=none --set-exit-if-changed .`: `Formatted 5 files (0 changed) in
0.02 seconds.` Exit 0. `flutter build macos --debug`:

```
Building macOS application...
✓ Built build/macos/Build/Products/Debug/floor_planner.app
```

`flutter build web`:

```
Compiling lib/main.dart for the Web...
Wasm dry run succeeded. Consider building and testing your application with the `--wasm` flag.
...
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 7736 bytes (99.5% reduction).
Compiling lib/main.dart for the Web...                             24.2s
✓ Built build/web
```

Both `✓ Built`. `git status --short` clean after every line in this block,
throughout Step 1 — no rewritten `analysis_options.yaml` at any point; none
needed restoring.

The startup clamp line, verbatim, unchanged from Plan 01 and re-asserted by
this plan's `planner_shell_test.dart`:

```
STARTUP fit scale 0.095 px/mm; min 0.001 (95.0x out), max 100.0 (1052.6315789473683x in)
```

### The Plan 01 baseline, recorded again

The five `text_ladder_golden_test.dart` failures (`text ladder rung 1..5`,
`RenderBackend.canvas`) are the same pre-existing Skia/SDK drift Plan 01
recorded (goldens from 2026-08-24, SDK 3.47.2) — measured again in this task,
identically named, nothing added and nothing healed. This plan's
`jet_cad_2d_flutter` bar is therefore "769 pass, 1 skip, those same five
failures and no other," exactly as Plan 01's was "702 pass, 1 skip, those
same five failures."

### Mutation summary

**Thirty named mutants (M-02a … M-02p, M-02r … M-02ac, plus M-02c′ and
M-02e′; there is no M-02q). 28 fired, 28 killed, 0 survived, 2 declared
equivalent by construction** (M-02c — key equality by bare handle, every
chain is empty under this task's D2; M-02e — `shouldRepaint` specified
`false`, no alternate boolean could differ under the contract). One fix round
on the ledger's own review: M-02b was re-fired against
`forEachInstanceInBand`'s root-level composition after round 0 found it had
only exercised the nested recursion — now killed at the spec-named fixture
(instance at `(300, −200)`, 30°, ×1.5). Full transcripts:
[plan-02-mutation-log.md](plan-02-mutation-log.md). Both allocation gates
(`query_allocation_test.dart`, `paint_allocation_test.dart`) are green,
pasted in the mutation log's own "Allocation gates" section.

### The differential (criterion 9)

`band_query_test.dart`'s `'crossing and window agree with the brute-force arm
on the generated corpus'`: corpus `generateDocument(400, definitionCount: 8,
instanceCount: 40, nestingDepth: 2, mirroredFraction: 0.2,
nonUniformFraction: 0.3, groupCount: 6)`. **52 bands** — 12 random (uniform in
`doc.extents`, half-sizes 5–205) plus one per root instance at
0.35/0.9/1.05/1.6 of that instance's own world box, cycling — each run in
**both** `BandMode.window` and `BandMode.crossing`, **104 comparisons total**,
each asserting set equality for leaves, set equality for instances, ascending
handle order and no duplicate slot. Three non-vacuity counters guard the
corpus (some leaves selected, some instances selected, some window trials
selected no instance). The brute-force arm re-derives the container walk
independently (groups flattened, instances kept) but shares the same leaf
predicates, so what it checks is the broad phase, the descent and the dedupe,
not a second geometry implementation (Task 2 report).

---

## Exit gate

The spec's fifteen criteria, each with its witness.

| # | criterion | verdict | witness |
|---|---|---|---|
| 1 | Click selects exactly one; empty-space click clears; both from a non-identity camera | **PASS** | `interaction_layer_test.dart`: `a click selects; the layer took focus`; `select_tool_test.dart`: `click on empty space clears; shift-click on empty space does nothing` — camera at scale 1.5, non-zero translation |
| 2 | Window/crossing select the D8 sets; the straddling fixture distinguishes them; both drag directions and a vertical drag tested | **PASS** | `select_tool_test.dart`: `left-to-right encloses, right-to-left touches`, `a group is window-selected only when every leaf is enclosed`; `interaction_layer_test.dart`: `drag direction selects the mode; a vertical drag is a window` (M-02g's discriminating fixture) |
| 3 | The same leaf under two instances yields two keys; two leaves of one instance yield one | **PASS** | `selection_test.dart`: `two instances of one definition are two keys; two leaves of one instance are one` |
| 4 | Hover follows the pointer, clears on exit, never drawn for an already-selected key | **PASS** | `select_tool_test.dart`: `hover sets the controller's hover and clears on a miss`; `interaction_layer_test.dart`: `exiting the layer clears hover`; `selection_overlay_test.dart`: `hover on a selected key draws once` |
| 5 | Shift toggles; Escape cancels a band or clears; Delete removes through the command log on one key-down; undo restores geometry, not selection | **PASS** | `select_tool_test.dart`: `Delete removes a leaf and an instance through the log; undo restores geometry, not selection`; `planner_shell_test.dart`: `cmd+Z undoes a Delete through the command log` (A5 — the shell's own binding, driven end to end); `interaction_layer_test.dart`: `one Delete press is one remove` |
| 6 | Selection change repaints the overlay and not the canvas | **PASS** | `selection_overlay_test.dart`: `a selection change repaints the overlay and not the canvas` — `DraftCanvas.onPaintForTest` unchanged, overlay count +1 |
| 7 | `SelectTool` implements `Tool`; `ToolController.activate` cancels the outgoing tool and re-points its listener; a second tool proves the interface is not `SelectTool`-shaped | **PASS** | `tool_controller_test.dart`: `ToolController forwards the active tool, swaps on activate, and stops forwarding the outgoing tool`, `activate notifies exactly once even when the outgoing tool notifies its own listeners from cancel` (uses `_CountingTool`, a second, trivial `Tool`) |
| 8 | All thirty mutants killed or declared equivalent, in the mutation log | **PASS** | [plan-02-mutation-log.md](plan-02-mutation-log.md) — 28 fired/28 killed, 2 equivalent, thirty accounted for |
| 9 | The differential band test passes on the generated corpus | **PASS** | `band_query_test.dart`: `crossing and window agree with the brute-force arm on the generated corpus` — 52 bands, 104 comparisons, pasted above |
| 10 | `query_allocation_test` and `paint_allocation_test` pass unchanged | **PASS** | mutation log's "Allocation gates" section, pasted transcripts, both green |
| 11 | Harness untouched; its 82 tests pass | **PASS** | `git diff --stat main..HEAD -- apps/dev_harness_2d` empty (verified in this task); 82 tests, gate line 3 above |
| 12 | All eleven gate commands exit 0, except `jet_cad_2d_flutter`'s `flutter test` on the same five pre-existing golden failures and nothing else; no `analysis_options.yaml` in the diff | **PASS with the one recorded exception** | re-run in full after the final fix wave and pasted above: `jet_cad_2d` **820**; `jet_cad_2d_flutter` **769 pass, 1 skip, the same five `text_ladder_golden_test.dart` failures and nothing else**; `dev_harness_2d` **82**; `floor_planner` **12** and both `✓ Built`. Every `analyze` and `format` exits 0; the short status after every line showed only the wave's own source files, and no `analysis_options.yaml` was rewritten at any point |
| 13 | The top bar shows the tool name and selection count; a widget test drives it | **PASS** | `planner_shell_test.dart`: `the status text shows the tool name and follows the selection` |
| 14 | The overlay outline coincides with the drawn entity at `kDefaultOriginX` to 0.01 px | **PASS** | `selection_overlay_test.dart`: `the outline coincides with the drawn line at 4.5e6`, `the outline coincides under a rotated, non-uniform camera` |
| 15 | A human looked, on macOS, in Chrome and in Firefox from `build/web`: click, shift-click, both bands, hover, Escape, Delete, undo; each recorded seen/not seen/could not judge | **OWED — not looked at; the human looks after this branch is presented** | this note |

**14 of 15 PASS.** No criterion is a MISS. Criterion 15 is OWED, itemised
below.

---

## The look — OWED, itemised

**No human looked at the running app in this session.** This task ran in a
headless sandbox, as a subagent, with no display, no `flutter run`, no
browser. Every item below is listed from the spec's criterion 15 and the
task brief's Step 2, and marked as its controller ruled: **OWED — not looked
at; the human looks after this branch is presented.**

### macOS

`cd apps/floor_planner && flutter run -d macos --profile` (or `--debug`,
matching this task's build).

1. Click selects exactly one entity. **OWED — not looked at; the human looks
   after this branch is presented.**
2. Shift-click toggles a second entity into the selection without
   dropping the first. **OWED — not looked at; the human looks after this
   branch is presented.**
3. Both bands: a left-to-right drag (window) selects only what is fully
   enclosed; a right-to-left drag (crossing) also selects what the band only
   touches. **OWED — not looked at; the human looks after this branch is
   presented.**
4. Hover highlights what the pointer is over, and follows it. **OWED — not
   looked at; the human looks after this branch is presented.**
5. Escape cancels a band in progress, or clears the selection when idle.
   **OWED — not looked at; the human looks after this branch is presented.**
6. Delete removes the selection, and undo — **cmd+Z (macOS) / ctrl+Z
   (browsers)** — brings the geometry back. **OWED — not looked at; the
   human looks after this branch is presented.**
7. Undo after Delete — **cmd+Z (macOS) / ctrl+Z (browsers)** — restores what
   was removed, not what was selected. **OWED — not looked at; the human
   looks after this branch is presented.**

### Browser — Chrome, then Firefox from `build/web`

`cd apps/floor_planner && flutter run -d chrome --release`, then the same
`flutter build web` served from `build/web` and opened in Firefox.

1. Click selects exactly one entity, in both browsers. **OWED — not looked
   at; the human looks after this branch is presented.**
2. Shift-click toggles a second entity, in both browsers. **OWED — not
   looked at; the human looks after this branch is presented.**
3. Both bands (window and crossing), in both browsers. **OWED — not looked
   at; the human looks after this branch is presented.**
4. Hover follows the pointer, in both browsers. **OWED — not looked at; the
   human looks after this branch is presented.**
5. Escape cancels a band or clears, in both browsers. **OWED — not looked
   at; the human looks after this branch is presented.**
6. Delete removes and undo — **ctrl+Z (browsers), cmd+Z on macOS** —
   restores the geometry, in both browsers. **OWED — not looked at; the
   human looks after this branch is presented.**
7. Undo — **ctrl+Z (browsers), cmd+Z on macOS** — restores geometry, not
   selection, in both browsers. **OWED — not looked at; the human looks
   after this branch is presented.**

Exit-gate criterion 15 is therefore **OWED**, not PASS — fourteen items in
total (seven per platform, macOS and the two browsers sharing the same seven
kinds of check), none looked at.

---

## Debt and rulings the human should know

- **A delete of N objects is N undo steps** (more for a group, D10). A
  partial undo of a group's cascade restores leaves under an owner that is
  still gone — the concrete problem statement 06's compound undo inherits.
  Neither is a defect in 02's own scope; both are recorded here because the
  human will meet them the first time they undo a group delete.
- **The group band rule counts leaves only.** An instance placed inside a
  group never enters the group's every/any band verdict (Ruling P-1) — a
  group made only of instances cannot be band-selected until a later plan
  decides instances-in-groups. Meanwhile a group's **outline** (D9's overlay)
  does descend into its child instances, because the outline shows what
  Delete would remove (Task 6's cascade) — an asymmetry between what a band
  selects and what the outline draws, both intentional, recorded together so
  neither reads as an oversight of the other.
- **Four walks over a container's members, and they differ on two axes** —
  whether a child *instance* is followed, and which `QueryFilter` is applied.
  All four are intentional; the table is here so no reader has to rediscover
  which is which:

  | walk | child instances | query filter |
  |---|---|---|
  | engine band walk (`forEachLeafInBand` / `forEachInstanceInBand`) | descend | applied — `_bandDescend` calls `acceptsEntity` before it counts a member |
  | tool group every/any rule (`SelectTool._everyLeafIn`) | **excluded** — the stack only pushes nested groups (Ruling P-1) | applied after A1 — a rejected leaf is skipped, not failed on |
  | outline cache (`OutlineCache._addContainer`) | descend — the outline shows what Delete would remove | applied after A2, but `rendering()`: hidden out, **locked still drawn**, as the canvas does |
  | delete cascade (`SelectTool._groupCascade`) | descend — each child instance gets its own `RemoveNodeCommand` | **none** — hidden and locked leaves are deleted with their group, which mirrors what `RemoveNodeCommand` would otherwise orphan: the node goes and its leaves would be left owned by a handle that no longer exists |
- **In window mode `forEachInstanceInBand` enumerates and descends every
  root-level instance** (`_kAllBox` at the root, plan-mandated), which the
  spec's "must not walk the whole document" did not anticipate; a band-box
  prefilter at the root is safe (an instance whose box misses the band fails
  window) and is left for 03 with a measurement.
- **A band dragged past the viewport edge is clipped at the edge** (Task 8's
  screen-space paint pass is clipped to the overlay's own bounds), not drawn
  past it.
- **Exiting the layer during a drag no longer cancels it** (Task 9 ruling,
  spec row amended). Exit with no active pointer still clears hover, but the
  layer's edge no longer cancels the drag; the band continues (Flutter keeps
  delivering the captured pointer's moves and up) and the drag's own `up`
  event ends it, not `onExit`.
- **A selected point key allocates one `Vector2` and four `Offset`s per
  frame** — `worldPointOf` returns a fresh `Vector2`, and `_drawPointCross`
  builds two `Offset`s per `drawLine` for the cross's two strokes (accepted,
  Task 8 ruling) — points are rare in a floor plan and the per-entity
  allocation rule is about entities walked, not keys selected.
- **The painter class is `SelectionOverlayPainter`, not the spec's
  `SelectionOverlay`** — Flutter's widgets library already exports a
  `SelectionOverlay`, and the spec's name would force a `hide` at every app
  import (Task 8 ruling; spec amended).
- **M-02c and M-02e are equivalent by construction**, not merely hard to
  reach: M-02c because every `SelectionKey` chain is empty under this task's
  D2, so a bare-handle comparison cannot be distinguished from the real
  `(chain, target)` comparison by any input this scope can construct; M-02e
  because `shouldRepaint` is specified `false` and the merged `repaint`
  listenable already drives every repaint regardless of its answer.
- **The Plan 01 baseline (five text-golden failures) stands, recorded again
  above** — pre-existing Skia/SDK drift from goldens recorded 2026-08-24,
  SDK 3.47.2, not a regression this plan introduced.

---

## Spec amendments

Recorded where each applies, in
[2026-09-21-interaction-core-design.md](../specs/2026-09-21-interaction-core-design.md),
each as a short "**Amended at execution (Plan 02, 2026-09-22):**" sentence
appended after the original text (nothing original was rewritten):

- D8 gains the group-membership rule (Ruling P-1): a group's member leaves
  are its own and its nested groups'; an instance inside a group does not
  enter the group's every/any rule.
- D8's band-walk allocation paragraph gains: a singular instance transform is
  judged forward rather than refused; crossing falls back to the container's
  all box for that instance (Task 2 ruling).
- D9 gains the painter's actual class name, `SelectionOverlayPainter`, with
  the reason (Flutter's own `SelectionOverlay` export), and the Files list
  entry for `selection_overlay.dart` is corrected the same way.
- D9 gains the point-key paint rule: a screen-space cross of half-length 3 ×
  the stroke width at `worldToScreen(worldPointOf(key))` (Task 7/8 ruling).
- D9 gains the `ui.Path.getBounds` note: it returns the conic control-point
  hull, not the curve's own bound, so arc and circle outlines are pinned on
  the cache's world record and only a containment bound is asserted on the
  `ui.Path` itself (Task 7 ruling).
- The `SelectTool` table's "exit while dragging" clause is superseded: exit
  with no active pointer clears hover; a band drag past the layer's edge
  continues and its own `up` ends it, not `onExit` (Task 9 ruling).

Four more were appended by the final fix wave (A1-A5), the same way:

- D8 gains the picking-filter rule: the tool's group every-rule **skips** a
  leaf the picking filter rejects rather than failing the group on it (A1).
- D8 gains the band-corner rule: **both** corners are converted from screen
  to world at release, so a camera move mid-drag cannot leave the band behind
  the cursor (A3).
- D9 gains two: the outline skips a leaf the **rendering** filter rejects
  (A2), and `OutlineCache` is a `ChangeNotifier` in the overlay's repaint
  merge, notifying on a `DocChange` rebuild and a load/purge clear and silent
  on a selection-driven one (A4).
- D12 gains the undo binding: cmd/ctrl+Z undoes through the command log from
  a `CallbackShortcuts` above the interaction layer's `Focus`; **no redo in
  02**, and the look checklist stands as written (A5).

---

## Files this task touched

- `docs/superpowers/notes/2026-09-21-plan-02-results.md` — this file.
- `docs/superpowers/specs/2026-09-21-interaction-core-design.md` — the six
  amendments above.
- `STATUS.md` — a Plan 02 section and the header/Resume-here update.
- `roadmap/02-interaction-core.md` — the status line.
- `roadmap/00-README.md` — the 02 row.

The final fix wave on top of it touched
`packages/jet_cad_2d_flutter/lib/src/select_tool.dart` and
`outline_cache.dart`, `apps/floor_planner/lib/main.dart` and
`planner_view.dart`, four test files and `test/support/selection_fixture.dart`,
then this note, the spec and `STATUS.md` again.
