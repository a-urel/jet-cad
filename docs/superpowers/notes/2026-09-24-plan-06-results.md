# Plan 06 — the parametric layer: results

**Plan:** [2026-09-24-parametric-layer.md](../plans/2026-09-24-parametric-layer.md).
**Spec:** [2026-09-24-parametric-layer-design.md](../specs/2026-09-24-parametric-layer-design.md)
(revision 2, amended at execution — see "Spec amendments" below).
**Mutation log:** [plan-06-mutation-log.md](plan-06-mutation-log.md).
**Branch:** `plan-06/parametric-layer`, worktree
`.claude/worktrees/quizzical-jemison-7537de`, cut from local `main` at
`6a279b3` (`058918d`'s sole parent, `docs(plan): 06 the parametric layer,
eleven tasks`). **Correction:** an earlier draft of this note, of the
mutation log and of STATUS.md named the fork point as `6adf03d`, one commit
earlier — that is spec revision 2's own commit
(`docs(spec): 06 revision 2 applies the r1 review`), which the plan's own
constraints text mislabelled as the branch point. Both commits are
docs-only, so every count below is unaffected by the correction; only the
SHA is.
**Eleven tasks: Tasks 1–9 at `6a279b3..7b31030`; Task 10 (the mutation
sweep's invariants and greps, appended to the mutation log) at `fbc6fba`;
Task 11 runs in two parts (the controller's own ruling, following Plan 05's
Ruling T11-a) — Steps 1–4 land at this commit. The ledger archive is
deliberately withheld: it waits until after the final whole-branch review
and its fix wave, so the archive holds the final review.**
**Ledger (per-task briefs, reports, mutation backups, every ruling):**
`.superpowers/sdd/2026-09-24-parametric-layer/` (git-ignored while the plan
is in flight; archived to
`docs/superpowers/ledgers/2026-09-24-parametric-layer/` as a later commit,
after the final review).

---

## What was measured

### The four gate lines, pasted with exit codes

Run in full, with `CI=true`, on the tree of Tasks 1–10 (`git status --short`
clean before and after each line). Branch-point counts at `6a279b3`: engine
911; render layer 923 + 1 skip + the five goldens; harness 82; app 46.

**`packages/jet_cad_2d`**: `CI=true dart test`:

```
00:03 +950: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +950: All tests passed!
```

Exit 0. `dart analyze`:

```
Analyzing jet_cad_2d...
No issues found!
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 141
files (0 changed) in 0.26 seconds.` Exit 0.

**`packages/jet_cad_2d_flutter`**: `CI=true flutter test`:

```
00:13 +925: Some tests failed.

Failing tests:
  test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

Exit 1. **925 pass, 1 pre-existing skip, and exactly the five pre-existing
`text_ladder_golden_test.dart` failures named above (rungs 1–5,
`RenderBackend.canvas`), and nothing else.** This is the same standing
exception `CLAUDE.md` and every earlier plan's gate line have carried since
the goldens were recorded on 2026-08-24 on SDK 3.47.2 — pixel drift, not a
regression. `flutter analyze`:

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.7s)
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 176
files (0 changed) in 0.33 seconds.` Exit 0.

**`apps/dev_harness_2d`**: `CI=true flutter test --concurrency=1`:

```
00:22 +82: All tests passed!
```

Exit 0: **82 tests, unchanged from the branch point** (`git diff --stat
6a279b3..HEAD -- apps/dev_harness_2d` is empty — this plan touches nothing
under the harness). `flutter analyze`:

```
Analyzing dev_harness_2d...
No issues found! (ran in 1.6s)
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 22
files (0 changed) in 0.05 seconds.` Exit 0.

**`apps/floor_planner`**: `CI=true flutter test`:

```
00:04 +67: All tests passed!
```

Exit 0: **67 tests.** `flutter analyze`:

```
Analyzing floor_planner...
No issues found! (ran in 1.0s)
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 19
files (0 changed) in 0.05 seconds.` Exit 0. `flutter build macos --release`:

```
Building macOS application...
✓ Built build/macos/Build/Products/Release/floor_planner.app (51.4MB)
```

Exit 0. `flutter build web --release`:

```
Compiling lib/main.dart for the Web...                             26.0s
✓ Built build/web
```

Exit 0. **Both builds printed `✓ Built`.**

`git status --short` was clean before this run and clean after every one of
the six commands above; no `analysis_options.yaml` was rewritten by any
`flutter analyze` / `flutter pub get` step.

### Branch commit trailers

This count had to include the fix commit that corrects the fork point used
here, so it could not be measured before that commit existed. **Measured
immediately after that commit landed, against its own SHA** (not a bare
`HEAD`, since `HEAD` keeps moving and this figure must not):

```
$ git rev-list --count 6a279b3..01defe5
15
$ git log --format=%B 6a279b3..01defe5 | grep -c "Co-Authored-By: Claude Opus 5.5"
15
```

**Measured at `01defe5`** (`fix(docs): correct Plan 06's fork point to
6a279b3 (review r1)`, the commit that made this very correction): 15
commits from the branch's real fork point (`6a279b3`) through `01defe5`, 15
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` trailers — one
per commit. That is Tasks 1–10 (13, per the mutation log's own count at
`fbc6fba`) plus this note's own Task 11 commit (`7ce1e21`) plus this
fork-point fix commit itself: `13 + 1 + 1 = 15`. A later commit (the
ledger archive, or any further fix round) will raise this count again; it
is not re-measured retroactively here.

### Where the counts differ from the plan's arithmetic, and why

**Report what ran, not the plan's sums.** Three of the four suites landed
exactly on the branch point plus their planned additions; the engine did
not, and the difference is fully accounted for by a review-driven fix
round.

| suite | branch point (`6a279b3`) | planned additions | planned total | actual (`7b31030`/`fbc6fba`) | difference |
|---|---|---|---|---|---|
| `jet_cad_2d` | 911 | +37 (X4, P10, N14, G9) | 948 | **950** | **+2** |
| `jet_cad_2d_flutter` | 923 + 1 skip + 5 goldens | +2 (CN1, CN2) | 925 + 1 skip + 5 goldens | **925 + 1 skip + 5 goldens** | **0** |
| `dev_harness_2d` | 82 | 0 | 82 | **82** | **0** |
| `apps/floor_planner` | 46 | +6 (BT) +6 (BX) +1 (SP5) +8 (SE) = 21 | 67 | **67** | **0** |

- **Engine: +2 over the plan's own sum, exactly explained.** Task 2's
  review found a real gap in the wrapper's failure handling (the after-survey
  running outside the rollback `try`, spec D4 step 8) and a real gap in the
  D6 guard (refusing a touched generated child only while its owner is still
  "an object", not "still exists"). Both were fixed in the same fix round,
  each pinned by one new test — `P11` (the after-survey hardening, mutant
  `M-06w`) and `P12` (the D6 tightening, mutant `M-06x`) — landed at
  `9e5c2dd`. `948 + 2 = 950`, and this is recorded as a controller ruling in
  the ledger (`progress.md`), not a silent drift.
- **Render layer, harness, app: exact match.** Every other suite landed
  exactly on the plan's own prediction; no task's review round changed a
  count elsewhere. The app's four series (`BT`, `BX`, `SP5`, `SE`) total 21
  over the 46-test branch point, giving 67 — the same number Task 9's
  mutation sweep (`plan-06-mutation-log.md`) and Task 10's own gate run both
  already recorded.
- **The app series is `SE`, not the plan's own `SP`.** The plan's task text
  named Task 8's selection-panel tests `SP1`–`SP7`, but `startup_plan_test.dart`
  already uses `SP1`–`SP5` for a different feature (Task 7's sample-plan
  test). The pre-flight scan caught the collision before any code was
  written and ruled the panel's tests `SE1`–`SE8` instead — names only, no
  test lost or gained, recorded in `plan-rulings.md`'s pre-flight table and
  `progress.md`'s top-level ruling.

### Mutation tally

From [plan-06-mutation-log.md](plan-06-mutation-log.md): **26 fired, 26
killed, 0 survived, M-06e recorded N/A by construction** (spec D4 step 6 is
a fixed one-hop closure, not a loop — there is no "drop the loop" edit to
make). One mutant, `M-06b′`, first fired as a **survivor** against
`neighbourhood_test.dart`'s original `N6` fixture — a degenerate fixture
(only one side of the move ever reserved a new handle, so an unsorted
closure had nothing to disturb) — was fixed test-only (the fixture's
geometry changed to a cross overlap where both objects gain children at
once) and re-fired, killed. The reviewer independently re-fired it too.

The 26 fired mutants are the spec's own M-06a…M-06t (21 fired forms —
`M-06b` and `M-06b′` are counted separately, `M-06g` is fired once in the
engine and once, separately, in the app, and `M-06e` is recorded, not fired)
plus five added during execution: `M-06u` (Ruling 06-10,
`PlacementTool.commit` ignoring `needs`), `M-06v` (Ruling 06-13,
`registerInto` re-registering over a loaded store), `M-06w` and `M-06x`
(the two review-found hardenings above), and `M-06y` (`onTapOutside`
removed from the Selection section, D13). `21 + 5 = 26`. Full per-mutant
detail, including the exact edit, the failing assertion and the diff-empty
restore, is in the mutation log.

---

## Exit gate

The spec's fourteen criteria and where each is witnessed:

| # | criterion | witness |
|---|---|---|
| 1 | the four gate lines, the five goldens only, both builds | "The four gate lines" above |
| 2 | a parameter change regenerates, a neighbour's too | `P2`, `N2`, `SE3` |
| 3 | one undo step; undo and redo restore both, same handles | `P3`, `BX2` |
| 4 | load → save byte-identical, typed | `N8` |
| 5 | same state plus same edit gives the same bytes | `N5`, `N6` |
| 6 | a mutual dependency terminates, with no iteration | `N1`, `N2`; `M-06e` N/A by construction |
| 7 | no `QueryReentrancyError` from regeneration | `P4` (the guard is exercised elsewhere), `N12` |
| 8 | the allocation invariants unchanged | Task 10's greps: `query_allocation_test.dart` / `paint_allocation_test.dart` diff against `main` is empty |
| 9 | draw order: unchanged objects keep their child handles | `P2`, `P3` |
| 10 | a direct edit of a generated child is refused | `G1`, `G2` |
| 11 | delete detaches the component; undo restores it | `G3`, `BX5` |
| 12 | runtime inheritance, undo and redo included | `G4`, `G5`, `SE5` |
| 13 | every mutant killed, or recorded as N/A or covered | [plan-06-mutation-log.md](plan-06-mutation-log.md): 26 fired, 26 killed, `M-06e` N/A |
| 14 | the human's look | **OWED** (below) |

**13 of 14 PASS.** Criteria 1–13 are PASS, each with its witness above.
**Criterion 14 is OWED**, itemised per platform below, and this task does
not mark it done — nothing was simulated to fill it in.

### Review Focus items and their tests

Five inputs the plan's own text names but no exit criterion covers by
itself, each with the test in the task that owns the code:

1. **Rotating a box with the rotation grip while it overlaps a
   neighbour.** Expected: one undo step, the neighbour re-clipped, `drift()`
   empty. `N13` (Task 3, engine-level: a `TransformNodeCommand` wrapped in a
   labelled `CompoundCommand`, since 03's actual rotate grip is not exercised
   by this plan).
2. **Selecting a box with a click and pressing Delete in the app.**
   Expected: the box and its component are gone, the neighbour regrows, and
   cmd+Z brings both back. `BX5` (Task 7).
3. **A width edit that swallows a box whole inside its neighbour.**
   Expected: 0 children, and back to a full count on the next edit, with
   **new** handles. `N14` (Task 3).
4. **cmd+Z after a panel edit.** Expected: the field shows the old width
   again. `SE6` (Task 8; the plan's own text named this `SP6` before the
   pre-flight ruling renamed the whole series `SE`).
5. **Two boxes sharing an edge exactly.** They are not neighbours (D3's
   `Tolerance.standard.linear` margin), and both keep their full,
   unclipped child count. `BT4` (Task 6, engine-fixture style in the app)
   and its engine-level analogue is implied by D3's neighbour definition,
   not separately re-tested.

### Debt

Every `minor (deferred)` line and every controller `Ruling:` line from the
ledger (`.superpowers/sdd/2026-09-24-parametric-layer/progress.md`) that is
not already written into the spec as an amendment, plus the spec's own open
questions. One line each; none is fixed by this task.

**The most user-visible item, flagged for the look and for the final
review:**

- **`onTapOutside` is not real focus-out (Task 8).** Flutter groups every
  plain `TextField` under the same shared `groupId`, so moving focus from
  Width to Height fires no tap-outside at all — nothing commits. A
  document change that lands while the user is mid-keystroke (from an
  unrelated edit, undo, or another user in a future multi-client setting)
  then runs `_sync`, which reloads Width from the model and silently drops
  the typed value. A real `FocusNode` listener would give true focus-out
  and close this gap. Not fixed in this plan; flagged for the final review
  to triage.

**Every other deferred item, one line each:**

- Task 1: the expander's "one slot, one owner" rule is doc-only in the
  dispatcher; the owner-side guard is `ParametricSystem.install()` throwing
  when the slot is already taken (Task 2, `P8`).
- Task 2: `found[h]` keeps one registration per handle, so a holder with two
  parametric components would get only one detached on delete.
- Task 2: `drift()` does not set `_applying`, so a `generate()` that calls
  `execute` during a dry run would mutate the document instead of being
  refused.
- Task 2: the fast path sorts every store via `withComponent<T>()`; the spec
  asked for a store-length check instead (this is off the frame path either
  way).
- Task 2: the hand-rolled regeneration loop in `_run` duplicates
  `CompoundCommand.apply`'s own rollback logic; it deserves a comment
  explaining why (it must tell its own rollback failure apart from a
  child's `StateError`).
- Task 2: `P4` asserts A's child count after the edit but not B's.
- Task 2: `Trip.mode` / `Trip.document` are static test-fixture state; later
  tests must reset them in `tearDown` (Task 4's `guards_test.dart` does).
- Task 4: a refused or rolled-back delete of a group (the `G6` shape) leaves
  the root's own children list reordered — pre-existing `RemoveNodeCommand`
  inverse behaviour (now written into the spec's Testing-section amendment),
  parked here for the final review.
- Task 4: the root-order / `handleSeed` normalising helpers used by `G3` and
  `G6` live in `guards_test.dart` only; promote them to `support/fixture.dart`
  if a later test needs the same normalisation.
- Task 6: `BoxParams` does not itself enforce `width`/`height` > 0 (spec
  D13); the Box tool's own degenerate-size check and the Selection panel's
  "≤ 0 reverts" rule are the gatekeepers, and `fromJson` accepts anything.
- Task 6: `BT2`–`BT4` assert child counts only, with no endpoint oracle in
  the app — the engine's `P1`/`P2` already carry a world-coordinate oracle
  for the same algorithm.
- Task 6: the report described `_insideInterval` as a character-for-character
  copy of the engine's own helper; one token differs (`tol.linear` vs.
  `Tolerance.standard.linear`), same value either way.
- Task 7: RED was captured after the commit landed (`box_tool.dart` emptied,
  backed up with `cp` and restored via `git show HEAD:…`, tree verified
  clean) — not a `git checkout --`, which is forbidden, but not
  test-first order either.
- Task 7: `BX4` checks `drift()` with a fresh `ParametricSystem`, not the
  shell's own installed one — equivalent by Ruling 06-13's `isRegistered`
  guard, but worth a second look if that guard ever changes.
- Task 8: `_sync` reloads both fields on every document change, overwriting
  uncommitted keystrokes when an unrelated edit lands mid-typing.
- The naming ruling: Task 8's selection-panel tests are `SE1`–`SE8`, not the
  plan text's `SP1`–`SP7` — `SP1`–`SP5` already name `startup_plan_test.dart`
  tests, and the plan used `SP` for both. Names only; nothing lost.
- The ledger-archive ruling: Tasks 10 and 11 (Steps 1–4) run in one
  dispatch; the ledger archive is deliberately withheld until after the
  final whole-branch review and its fix wave, following Plan 05's Ruling
  T11-a — so the archive holds the final review, not a stale mid-review
  snapshot.

**The spec's own open questions, carried forward (not blocking, recorded for
07):**

- **Draw order of added children (D12).** A child added by a later
  regeneration takes a fresh, higher handle and draws above older content.
  A box's outline is lines on layer 0, so nothing visible depends on it
  here, but 07's walls with fills may need a per-object draw pass.
- **The O(n²) neighbour search.** `ParametricView.neighbours` compares every
  parametric object's `reach` against every other's. A broad phase is only
  needed past a few hundred parametric objects — this plan's scale (a
  handful of boxes) never approaches it.
- **Whether `reach` needs to be richer than an AABB.** A long diagonal
  object has a large AABB and produces spurious neighbours, which cost
  regeneration time, not correctness — `generate`'s own exact test still
  produces the right geometry (see `M-06g (app)`'s note in the mutation
  log's spec amendment). The per-axis tolerance rule in D3 is a placeholder
  that 07 must re-derive for mitred wall corners.

---

## Criterion 14: the human's look — OWED

**Not looked at. The human looks after this branch is presented.** No
device run and no visual judgement was simulated to fill it in. Run it on
each platform:

- **macOS:** `cd apps/floor_planner && flutter run -d macos --release`;
- **Chrome:** `cd apps/floor_planner && flutter run -d chrome --release`;
- **Firefox:** `build/web`, served statically (`cd
  apps/floor_planner/build/web && python3 -m http.server`).

Six items per platform, from the plan's own text. Record each as **seen /
not seen / could not judge**.

### macOS: `flutter run -d macos --release`

1. B draws a box. ☐ seen ☐ not seen ☐ could not judge
2. A second box overlapping the first: one merged outline. ☐ seen ☐ not
   seen ☐ could not judge
3. Select a box. Width and Height appear; set the width, press Enter, and
   the outline follows. cmd+Z undoes it in one step. ☐ seen ☐ not seen
   ☐ could not judge
4. Move and rotate a box over another. The outlines re-merge, and one undo
   restores. ☐ seen ☐ not seen ☐ could not judge
5. Delete a box. The other regrows, and cmd+Z brings it back. ☐ seen
   ☐ not seen ☐ could not judge
6. Typing B or V in the fields does not switch tools. ☐ seen ☐ not seen
   ☐ could not judge

### Chrome: `flutter run -d chrome --release`

1. B draws a box. ☐ seen ☐ not seen ☐ could not judge
2. A second box overlapping the first: one merged outline. ☐ seen ☐ not
   seen ☐ could not judge
3. Select a box. Width and Height appear; set the width, press Enter, and
   the outline follows. ctrl+Z undoes it in one step. ☐ seen ☐ not seen
   ☐ could not judge
4. Move and rotate a box over another. The outlines re-merge, and one undo
   restores. ☐ seen ☐ not seen ☐ could not judge
5. Delete a box. The other regrows, and ctrl+Z brings it back. ☐ seen
   ☐ not seen ☐ could not judge
6. Typing B or V in the fields does not switch tools. ☐ seen ☐ not seen
   ☐ could not judge

### Firefox: `build/web`, served statically

1. B draws a box. ☐ seen ☐ not seen ☐ could not judge
2. A second box overlapping the first: one merged outline. ☐ seen ☐ not
   seen ☐ could not judge
3. Select a box. Width and Height appear; set the width, press Enter, and
   the outline follows. ctrl+Z undoes it in one step. ☐ seen ☐ not seen
   ☐ could not judge
4. Move and rotate a box over another. The outlines re-merge, and one undo
   restores. ☐ seen ☐ not seen ☐ could not judge
5. Delete a box. The other regrows, and ctrl+Z brings it back. ☐ seen
   ☐ not seen ☐ could not judge
6. Typing B or V in the fields does not switch tools. ☐ seen ☐ not seen
   ☐ could not judge

**Nothing above is ticked on the human's behalf.** No finding, no verdict
and no `fix/` branch exist yet for Plan 06's look.

---

## Rulings

### The plan's rulings, 06-1…06-13 (06-14 not made)

Each ruling is one line, with what it costs if it is wrong. The ones marked
**(spec amended)** are written into the spec (see "Spec amendments" below).

- **06-1 (spec amended, D3 and D10):** types live in a document-free
  `ParametricCatalog`, not on `ParametricSystem`, because the codec creates
  the document and needs the factories before it loads components. Cost:
  one indirection.
- **06-2:** one library, two files — `parametric_system.dart` declares
  `part 'regeneration.dart';`, so the planner can use the private
  registration type without widening the public API. Cost: none.
- **06-3 (spec amended, D4 step 4):** the clean-up step detaches only
  components of objects that were live before the edit, not any component
  whose handle merely lacks a tree node (which would also catch a misplaced
  component on a leaf, D5). Cost if wrong: a misplaced component survives a
  delete; already reported by `diagnostics()`.
- **06-4 (spec amended, D4 step 5):** a touched handle that *was* an object
  is a seed too, so an explicit `SetComponentCommand<T>(h, null)`'s old
  neighbours regrow. Cost: none.
- **06-5 (spec amended, the mutant table):** M-06b is "every sort removed"
  (the survey's, the closure's, and `ComponentStore.handles`'), and M-06b′
  is the closure's sort alone. Cost: none.
- **06-6 (spec amended, the mutant table):** M-06p's observable is
  child-handle stability, not raw bytes, because a remove-then-add can reuse
  a freed slot (LIFO free list) and the raw bytes can coincidentally match
  even though the child's handle changed. Cost: none.
- **06-7 (spec amended, the mutant table):** M-06f is fired as
  `ParametricSystem.install()` regenerating everything on load; the
  stale-file test `N9` goes red, confirming the spike's answer that
  regeneration on load is a no-op on a clean file. Cost: none.
- **06-8 (spec amended, the mutant table):** the transform mutants split by
  layer — `M-06g` (engine) lives in `_worldOf`, killed by the engine's
  relational tests; `M-06g` (app) and `M-06o` live in `BoxType`, client
  code, killed by the app's rotated-pair tests. Cost: none.
- **06-9:** the test clients duplicate `BoxType`'s clipping on purpose,
  because the engine tests cannot import the app and the fixture must not
  share a bug with the code it checks. Cost: about sixty lines, twice.
- **06-10 (spec amended, the mutant table):** new mutant `M-06u` —
  `PlacementTool.commit` ignoring its `needs` argument — killed by `CN1`.
- **06-11:** `ParametricEdit`'s constructor is private, so a test obtains
  one only via `document.commands.expander!(command)`; "single-use" cannot
  be broken from outside.
- **06-12:** the shell installs its `ParametricSystem` in `initState` and
  disposes it in `dispose`; a second `install()` on the same document
  throws (spec D2).
- **06-13 (spec amended, D1):** `ComponentRegistry` gains
  `isRegistered<T>()`, and the catalog registers a type only when it is not
  already registered — otherwise a second `ParametricSystem` over a loaded
  document would wipe every live component of that type (`register<T>`
  replaces the store unconditionally). Pinned by `P10` and `M-06v`. Cost:
  one method.
- **06-14: NOT MADE.** Task 8's review found the class comment claiming
  "onSubmitted only" while `onTapOutside` still committed; the controller
  ruled to **keep** focus-out commit (spec D13 says "Enter or focus-out
  commits"), fix the comment, and add `SE8` to pin it — not to change the
  behaviour. No D13 amendment is written for this ruling, per the
  controller's instruction for this dispatch.

### The controller's rulings, from the ledger

- **The pre-flight naming collision:** Task 8's selection-panel tests are
  `SE1`–`SE8`, not `SP1`–`SP7` as the plan's own text has it —
  `startup_plan_test.dart` already uses `SP1`–`SP5`, and the plan used `SP`
  for both series. Cost if wrong: none, names only.
- **Task 2's after-survey hardening:** the `reach()`-throws hole is fixed,
  not parked, because spec D4 step 8 already says "in every failure case
  the dispatcher pushes nothing" and `DraftCommand.apply` is all-or-nothing.
  Cost if wrong: none (see the spec's D4 amendment).
- **Task 2's D6 tightening:** the guard is tightened to the spec's literal
  text and enters the fix loop although the reviewer graded the gap Minor,
  because the spec is binding and the looser rule let a bundled detach
  sidestep the backstop. Cost if wrong: a compound that detaches a box and
  edits its old child in one command is refused, though no tool in this
  plan issues one (see the spec's D6 amendment).
- **Task 2's two added mutants:** `M-06w` and `M-06x`, fired by Task 9,
  killed by `P11` and `P12` respectively. Cost: none.
- **Task 2's count shift:** the engine's expected total moves from the
  plan's 948 to **950** at Task 11, because of the two tests above. Cost:
  none (see "Where the counts differ" above).
- **Task 4's normalisation:** `G3` and `G6` compare state with the root's
  child order normalised (and `G3` without `handleSeed`), because
  `RemoveNodeCommand`'s inverse re-links a node at the end of its parent's
  children and `HandleSeed` never moves back — pre-existing engine
  behaviour the spec's own "bytes unchanged" wording for `G6` overstated.
  Cost if wrong: a real ordering regression in a rollback would hide behind
  the normalisation; the component/node/entity/geometry assertions still
  stand (see the spec's Testing-section amendment).
- **Task 6's mutant-kill location:** `M-06g` (app) is killed by `BT6` (the
  reach oracle), not `BT3` — with untransformed corners, every box's reach
  contains its own local-origin region, so every pair becomes a neighbour
  and `generate`'s exact test still yields the right outline. Cost: none;
  `BT6` pins `reach` directly (see the mutant-table amendment).
- **Task 8's focus-out ruling:** keep the focus-out commit (`onTapOutside`),
  since spec D13 says "Enter or focus-out commits"; Ruling 06-14 is **not**
  made; fix the doc comment and add `SE8` pinning the behaviour. Cost if
  wrong: a half-typed but parseable value commits when the user taps
  elsewhere — which is exactly what D13 asks for.
- **This dispatch's own scope:** Tasks 10 and 11 (Steps 1–4) run as one
  dispatch; the ledger archive is deliberately withheld until after the
  final whole-branch review and its fix wave (Plan 05's Ruling T11-a
  precedent). Cost: none.

---

## Spec amendments

Recorded where each applies, in
[2026-09-24-parametric-layer-design.md](../specs/2026-09-24-parametric-layer-design.md).
Each is a paragraph beginning "**Amended at execution (Plan 06):**",
appended at the end of the relevant section. Nothing original is rewritten.

- **D1:** Ruling 06-13 — `ComponentRegistry.isRegistered<T>()`, and why the
  catalog needs it before re-registering a type.
- **D3:** Ruling 06-1 — types live in a document-free `ParametricCatalog`,
  not on `ParametricSystem`, because `DraftDocumentCodec.decode` needs the
  factories before the document (and therefore any per-document system)
  exists.
- **D4:** Ruling 06-3 (step 4, narrowed to previously-live objects) and
  Ruling 06-4 (step 5, a handle that *was* an object seeds the closure too),
  plus the review-found hardening at step 8 (the after-survey, `lost`,
  `cleanup` and `seeds` moved inside the rollback `try`; `P11`, `M-06w`).
- **D6:** the guard tightened to the spec's literal text — refused whenever
  the touched handle still exists, not only while its owner is still "an
  object" — closing a bundled-detach loophole; `P12`, `M-06x`.
- **D10:** Ruling 06-1's consequence for load — `registerComponents` is on
  the catalog, and a test that decodes and then constructs a
  `ParametricSystem` over the same document relies on Ruling 06-13's
  `isRegistered` guard.
- **The mutant table:** `M-06u`, `M-06v`, `M-06w`, `M-06x` and `M-06y`
  added; `M-06g` (app)'s kill location clarified (`BT6`, not `BT3`); `M-06b′`'s
  survive-then-fixture-fix-then-kill history recorded.
- **The Testing section:** `G3` and `G6` compare state with the root's
  child order normalised, because `RemoveNodeCommand`'s inverse re-links at
  the end and `HandleSeed` never moves back (Task 4's ruling).

**D13 is not amended.** Ruling 06-14 was not made — the reviewer's finding
was a doc-comment slip, not a behaviour change, and the controller's
instruction for this dispatch is explicit that no D13 amendment is written
for it.

---

## Files this task touched

**Task 10 (`fbc6fba`):**
- `docs/superpowers/notes/plan-06-mutation-log.md`: the "Invariants and
  greps (Task 10)" section appended — the six greps, the four gate lines,
  the branch commit-trailer check.

**Task 11, Steps 1–4 (this commit):**
- `docs/superpowers/notes/2026-09-24-plan-06-results.md`: this file.
- `docs/superpowers/specs/2026-09-24-parametric-layer-design.md`: seven
  "Amended at execution" paragraphs, appended (D1, D3, D4, D6, D10, the
  mutant table, the Testing section). Nothing original was rewritten.
- `STATUS.md`: the header, a Plan 06 section, and the "Resume here"
  paragraph.
- `roadmap/06-parametric-layer.md`: the status line.
- `roadmap/00-README.md`: the 06 row in the status table.

Task 11 touched no code. The ledger archive is deferred to a later commit,
after the final whole-branch review and its fix wave (see "The controller's
rulings" above).
