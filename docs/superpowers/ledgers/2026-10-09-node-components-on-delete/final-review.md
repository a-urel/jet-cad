# Final review: fix/node-components-on-delete (e2813721..a39a2906)

Reviewer: fresh, whole-branch. Code range 5a0af46..a39a2906 read from the
review package and from the tree. Gates and probes run in a scratch worktree
at a39a2906 (`git worktree add --detach`, one `flutter pub get`), removed
afterwards. The review worktree was not touched except for this file.

### Gates at the tip (pasted lines)

Flutter 3.47.6 (`/opt/homebrew/bin/flutter`), this machine, a39a2906:

- `packages/jet_cad_2d`
  - `dart test`: `00:06 +1280 -2: Some tests failed.` The two red tests are
    `both text fractions default to zero and change nothing [E]` and
    `the default document is the one Plan 2 measured, byte for byte [E]`.
    These are the two standing `generate_document_test` fingerprints.
  - `dart analyze --fatal-infos`: `No issues found!`
  - format: `Formatted 172 files (0 changed) in 0.38 seconds.`
- `packages/jet_cad_2d_flutter`
  - `flutter test`: `00:26 +1432 ~1 -5: Some tests failed.` The five red
    tests are `text ladder rung 1` to `rung 5 (RenderBackend.canvas)`, the
    standing text-ladder goldens.
  - `flutter analyze`: `No issues found! (ran in 3.9s)`
  - format: `Formatted 228 files (0 changed) in 0.44 seconds.`
- `packages/jet_cad_2d_gpu`
  - `flutter test`: `00:02 +20: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 2.6s)`
  - format: `Formatted 10 files (0 changed) in 0.01 seconds.`
- `packages/jet_cad_restaurant_symbols`
  - `flutter test`: `00:01 +97: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 3.0s)`
  - format: `Formatted 15 files (0 changed) in 0.03 seconds.`
- `apps/floor_planner`
  - `flutter test`: `00:32 +212: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 3.6s)`
  - format: `Formatted 47 files (0 changed) in 0.12 seconds.`
- `apps/restaurant_demo`
  - `flutter test`: `00:18 +68: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 3.4s)`
  - format: `Formatted 9 files (0 changed) in 0.06 seconds.`
- `packages/jet_cad_floor_plan`
  - `flutter test --enable-vmservice`: `01:52 +1915: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 6.6s)`
  - format: `Formatted 281 files (0 changed) in 1.06 seconds.`

Only the standing failures are red. Nothing else is red.

**Independent mutant probes.** Each mutant was applied alone with an
exact-match replace, run, and restored from a `cp` copy. `cmp` was clean
after each one, and `git status --short` was empty at the end.

- **M-17** (catch skips the derived inverses), TD10:
  `00:00 +0 -1: ... TD10 all or nothing: a stamp that throws after another stamp puts that one back with the edit [E]`.
  Killed.
- **M-3** (snapshot after `detachAll`), floor plan TD7 to TD7c: TD7, TD7b
  and TD7c red, `00:00 +0 -3: Some tests failed.` This settles the spec's
  "TD7 (review run)" claim on the plan's code, which no task had run.
- **M-12** (the cleanup put back, `before.objects[h]!.detach(h)` for each
  lost `h`, prepended to the plan):
  - PG1: `+0 -1: PG1 ... [E]`. Killed.
  - `delete_components_test.dart`: `00:00 +3: All tests passed!`. P-2 does
    not kill M-12, as ruled.
- **M-5** (`snapshot.unknown.reversed` in `restore`), `node_components_test.dart`:
  - N-2 `[E]` and N-5 `[E]`, ending `+8 -2: Some tests failed.`
  - N-6 stayed green, as ruled.
- **M-14** (rollback (A) in place of the check):
  `+4 -1: N-4 ... the same under a parent that already lists the handle, the raw list compared ... [E]`.
  Killed.
- **Unnamed probe X-0** (the inverse's index forced to 0):
  - `node_components_test.dart` stays green under it, because N-2's node
    sits at index 0.
  - `node_index_undo_test.dart` kills it: N2, N3b, N4, N6 and N7 red,
    `+17 -7`.
  - See Minor 5.

### Strengths

- **The production change is small, and it is spec D-1/D-2 exactly**
  (`commands.dart:384-490`, `component.dart:179-215`).
  - Every refusal comes before the first write: the duplicate check, then
    `checkRestorable`, then `addNode`'s cycle and index checks. No
    compensation is needed, so the dangling-entry hazard of (A) cannot
    arise (M-14 probe above).
  - `restore` is now `checkRestorable` followed by the writes, and behaves
    as before.
  - The engine now owns the invariant.
- **Callers checked, nothing broken.**
  - **Undo and redo** (`undo.dart:204-260`) check the inverse's
    `capabilities` and keep a refused entry on its stack. Inverses do not
    pass through the expander, so `_written` never sees the snapshot's
    restore.
  - **`CompoundCommand` rollback** replays the new inverse (N-5).
  - **`ParametricEdit`.**
    - `_cascade` and `_plan` apply `RemoveNodeCommand` directly, and their
      inverses carry the snapshot.
    - `ParametricReplay` declares `inner.capabilities`, so a dissolve
      inherits the move's authority as before (the DV1 ruled tail is
      green).
    - `lost` still seeds the closure, and `lost ⊆ seeds` keeps
      `if (seeds.isEmpty) return r` equivalent.
    - `_written` reads `null` now where it read an unchanged value before,
      and it `continue`s on both.
  - **`TableLabelEdit`.** With the expander gone, a delete has no derived
    command and returns `r` as it is. `capabilities` is still
    `inner.capabilities`.
  - **The select tool's preflight** reads the set per key, and
    **`deleteSelection`** runs the select tool's own delete.
  - **Permission profiles.** `all` allows the change. `runtime` and
    `readOnly` already deny `structure`.
  - **`SpatialIndex` and `TileCache`** read `capability`, which is
    unchanged.
  - A grep of `packages/*/lib` and `apps/*/lib` found no production
    re-parent, and no other `snapshotOf`, `detachAll` or `tree.removeNode`
    caller.
- **D-4 and D-7 are clean deletions** with honest doc rewrites.
  `_detachFor`, `_detachLayer` and `cleanup` are gone, the now-unused
  imports were dropped, and the analyzer is clean with `--fatal-infos`.
- **The test fixtures are non-degenerate where it counts.**
  - The node is not the first handle and sits under a turned, far-off
    parent.
  - It carries two registered and two unknown components, the unknown ones
    out of type-id order.
  - N-4's unmapped case puts the mapped type first (M-16), and N-4 asserts
    the raw `children` list (M-14).
  - TD10's rewrite is a real all-or-nothing pin: `refused` is a premise,
    and the refusal is one-shot so the rollback reads pass.
- **Schema 9 is unchanged**, and N-7 pins I-5 against a load-time sweep
  (M-13).
- **The record is honest.**
  - The results note quotes the reports and says it re-ran nothing.
  - It corrects the spec's M-5 and M-12 killer claims and the "byte for
    byte" reading instead of glossing over them.
  - It records M-3's TD7 kill as not run, which this review has now run.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

None.

#### Minor (Nice to Have)

1. **DV1's title and one comment name the removed mechanism.**
   - Where: `packages/jet_cad_2d/test/parametric/dissolve_test.dart:147-149`,
     the title "...its component detached in the edit... the guard and the
     cleanup are untouched...", and `:312`, the comment "...the detach
     components".
   - Why: the test now pins that no detach exists, and there is no cleanup.
   - Fix: retitle to "...its component taken with its node in the
     edit...; the guard is untouched...". Reword `:312` to "the removals
     need geometry, structure and components".
2. **P-2's title claims a mechanism the test does not check.**
   - Where: `packages/jet_cad_floor_plan/test/delete_components_test.dart:79-80`
     says the replay restores "through the node's snapshot". The test
     checks only the outcome, and the M-12 probe shows that a separate
     restore passes too.
   - Fix: reword the title to the outcome, for example "...undo restores
     them; the plan as before".
3. **TD9's title contradicts itself.**
   - Where: `packages/jet_cad_floor_plan/test/tables/table_data_test.dart:394-395`
     says "an edit that removes nothing" next to "a delete of another
     table".
   - Fix: "an edit that does not remove the table keeps its data: a turn,
     and a delete of another table".
4. **PG1's comment has a broken reflow.**
   `packages/jet_cad_2d/test/parametric/page_test.dart:216-218`
   ("Planned on a / copy through the / expander"). Reflow it.
5. **N-2's node sits at index 0.**
   - Where: `node_components_test.dart:152`. The premise is "not the
     append".
   - An index-forced-to-0 inverse survives the whole new file (probe X-0).
   - It is killed by `node_index_undo_test` (host spec O-10), so nothing
     escapes the suite.
   - Optional fix: place the node second of three (add `sibling` before
     `node` in `scene()`, and adjust the premise to 1). That would make the
     new file stand on its own for the index too.
6. **`_Registration.detach` is now dead in `lib`**
   (`packages/jet_cad_2d/lib/src/parametric/parametric_system.dart:793`).
   - Its only users are mutant templates, and a mutant can inline
     `SetComponentCommand<T>(h, null)`.
   - Leaving it does no harm, and the analyzer does not flag a public
     member of a private class. Delete it only if the fix round touches
     that file anyway.
7. **A cross-document snapshot can still break I-3.**
   - Where: `packages/jet_cad_2d/lib/src/document/component.dart:185-191`
     and `:209`.
   - What: a snapshot whose type id maps here to a different Dart class
     passes `checkRestorable`. `ComponentStore<T>.set` then throws a
     covariance `TypeError` after `addNode` has written.
   - Reachability: two registries would have to bind one id to two
     classes. No production code takes a snapshot from another document
     (grep: `snapshotOf` is called only by the two remove commands).
     `RemoveDefinitionCommand` had the same gap before this branch.
   - Fix: record it as an out-of-scope line (O-8) in the results note.
     Optionally, a `bool accepts(Component c) => c is T` on
     `ComponentStore`, checked in `checkRestorable`, closes it in two
     lines.

### Deferred minors triage

- **T1: DV1's title and comment**. Fix before merge, as text only (Minor 1).
  The test's name describes a mechanism the same test pins as absent. It is
  cheap, and the house treats test names as the record.
- **T1: `_Registration.detach` dead**. Leave (Minor 6). It is harmless and
  invisible to the API. Delete it only if `parametric_system.dart` is
  touched anyway.
- **T1: the cross-document snapshot, I-3**. Leave the code. Add one
  out-of-scope line to the results note (Minor 7). It is unreachable from
  production, and it predates this branch through `RemoveDefinitionCommand`.
- **T1: the sibling and S-1 share one `ObjectLayer` value and `a.earlier`**.
  Leave. `Mark` and `z.later` differ, and no wrong-handle mutant survives:
  N-1's sibling kills M-6.
- **T1: PG1's comment reflow**. Fix before merge, as cosmetic (Minor 4). It
  is one line and goes with the other text fixes.
- **T2: P-2's title**. Fix before merge (Minor 2). The title claims what the
  test does not check. The M-12 probe confirms the gap is real.
- **T2: P-1 to P-3 have no same-type sibling, and P-1 has one unknown
  payload**. Leave. I-4 and unknown order are pinned in the engine (N-1,
  N-2, N-5), and the table sibling is pinned by TD7. The fixtures are
  plan-mandated.
- **T2: TD9's title**. Fix before merge, as text only (Minor 3). It is
  self-contradictory and cheap.
- **T2: the leftover `derived` / `else continue` in `TableLabelEdit`**.
  Leave. The brief permits it, and it changes no behaviour. Simplify it
  only if the file is touched.
- **T3: the results note's "none changes behaviour; no named mutant
  survives" lead-in**. Fix before merge when the note is next edited. It
  will be edited anyway for Minor 7 and this review's probe results.
  Reword it to "none changes behaviour the tests pin".
- **T3: D-8 bullet mixes tasks / M-3 row "TD7 not run"**. Fix the M-3 row:
  this review ran it, so record "TD7, TD7b, TD7c (final review's run)".
  Leave the D-8 attribution.
- **T3: the long line in Gates; STATUS drops the Copilot-quota fact**.
  Leave. It is cosmetic, and the spec records the Copilot fact.

None of these blocks the merge on behaviour. The "fix before merge" items
are text edits to test titles, comments and the results note: one small
commit.

### Rulings

- **The ledger lives in the skill's workspace, not the plan's named
  directory.** Agree. Two live ledgers would split the record. At archive
  time, both `.superpowers/sdd/2026-10-09-…` (the spec review) and
  `2026-10-10-…` must land in
  `docs/superpowers/ledgers/2026-10-09-node-components-on-delete/`. Check
  that both are copied.
- **M-5's killers are N-2 and N-5, not N-6.** Agree, and confirmed by run.
  Under M-5, N-2 and N-5 are red and N-6 is green. The reasoning (the
  double reversal across the bare branch's undo and the carrying branch)
  is right.
- **The N-4 tests take `handleSeed.next()` before the baseline encoding.**
  Agree. The encoding includes the seed, so the plan's order compares an
  advanced seed against the baseline. Every assertion is intact (M-10,
  M-14 and M-16 are still killed; M-14 confirmed by run).
- **P-1 to P-3 compare `canon`.** Agree.
  - Entity slot order after undoing `RemoveEntityCommand`s is history,
    not state (06 D11). That predates this branch, and `canon` compares
    everything else, components and unknown payloads included, exactly.
  - Byte-for-byte undo is still pinned, with `encodeToString`, by N-2 and
    S-1 in the engine and by TD7 to TD7c and HD12 in the floor plan.
  - So I-2's encoding claim is not left unpinned. The note's "byte for
    byte, entities in handle order" reading is accurate.
- **P-2 is not a killer of M-12.** Agree, and confirmed by run: P-1 to P-3
  are all green under M-12, and PG1 is red.

### Declined to judge

- **A host command that calls `target.tree.removeNode` directly** loses
  0.4.0's parametric cleanup. The spec's Risks accepts this, and the
  invariant belongs to `RemoveNodeCommand` by design.
- **Components left on a removed leaf** (`RemoveEntityCommand`): O-1, out
  of scope.
- **No orphan sweep on load, save or purge, and no `validate()`
  diagnostic**: D-6 and O-2/O-3 decide this. I did not second-guess the
  preserve-unknown reasoning.
- **`loadJson` does not raise the seed past component handles**: O-4.
- **`rawData` is not dropped on delete**: O-6, not on `CommandTarget`.
- **A hand-built `SetComponentCommand<FloorPlanTableData>` onto a dead
  handle now persists**: O-7. No host API reaches it.
- **The host spec's text is not edited**: O-5, by decision.
- **Linux standing-failure lists and CI**: this machine cannot check them,
  and the branch's CI run is the check of record.
- **An undo or redo of a delete under a hypothetical structure-without-
  components profile** is refused. D-2 accepts this explicitly, and no
  production profile is such.
- **The cost of `snapshotOf` and `detachAll` per removal** is O(registered
  types) at command rate, not on the frame path. The allocation
  invariants are untouched (their files are not in the diff, and their
  suites are green).

### Assessment: Ready to merge? With fixes

- **Behaviour:** ready. Every gate is green apart from the standing set.
- **The engine owns the invariant** without breaking a caller: undo and
  redo, compound rollback, the parametric and table-label replays, the
  select tool's preflight, the host's `deleteSelection`, and the
  production permission profiles were all checked.
- **The mutants:** the named ones I re-ran die where the record says
  (M-3, M-5, M-12, M-14, M-17). The two killer-claim rulings hold.
- **The fixes are text only:** the DV1, P-2 and TD9 titles, the DV1 and
  PG1 comments, and the results note (its lead-in, the M-3 row, this
  review's probes, and an O-8 line for the cross-document snapshot). No
  code change is required. Minor 5 (N-2 at index 0) and the
  `checkRestorable` type check (Minor 7) are optional.
