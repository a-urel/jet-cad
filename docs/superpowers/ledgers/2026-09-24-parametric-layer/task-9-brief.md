### Task 9: Mutation testing

**Files:**
- Create: `docs/superpowers/notes/plan-06-mutation-log.md`

For each mutant:
1. `cp` the file to
   `.superpowers/sdd/2026-09-24-parametric-layer/mutation-backups/<basename>.<id>`.
2. Apply the one edit.
3. Run **the named test file** with `CI=true`, and paste the failing names
   and the summary line.
4. Restore with `cp`.
5. `diff <backup> <file>`, and paste the empty output.

**Never `git checkout --` a `.dart` file.** Paths below are relative to
the repo root. `ps.dart` is
`packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`, and
`regen.dart` is `.../parametric/regeneration.dart`.

| ID | file | edit | test file |
|---|---|---|---|
| M-06a | `packages/jet_cad_2d/lib/src/document/commands.dart`, `CompoundCommand.apply` | `inverses.reversed.toList()` → `inverses.toList()` | `packages/jet_cad_2d/test/document/compound_command_test.dart` (covered there; spec) |
| M-06b | `regen.dart` `_survey` and `_closure`, and `document/component.dart` `ComponentStore.handles` | drop all three sorts: the survey's `..sort(_byValue)`, the closure's `..sort(_byValue)`, and the store's `..sort` (Ruling 06-5) | `test/parametric/neighbourhood_test.dart` (N5) |
| M-06b′ | `regen.dart`, `_closure` | drop `..sort(_byValue)` | `neighbourhood_test.dart` (N6) |
| M-06c | `regen.dart`, `_run` | drop the `if (inverses.isNotEmpty) CompoundCommand(…)` element from the replay | `test/parametric/regeneration_test.dart` (P3) |
| M-06d | `regen.dart`, `_closure` | return `seeds.where(after.objects.containsKey).toList()..sort(_byValue)` | `neighbourhood_test.dart` (N2, N3) |
| M-06e | — | N/A by construction (spec D4 step 6); record it | — |
| M-06f | `ps.dart`, `install` | after taking the slot, execute `regenerateAll`: a `CompoundCommand` of `_plan` over every object, if non-empty (Ruling 06-7) | `neighbourhood_test.dart` (N9) |
| M-06g | `regen.dart`, `_worldOf` | return `Transform2.identity()` | `neighbourhood_test.dart` (N1, N4), `regeneration_test.dart` (P3) |
| M-06g (app) | `apps/floor_planner/lib/parametric/box.dart`, `reach` | `toWorld.transformPoint(c)` → `c` | `apps/floor_planner/test/box_test.dart` (BT3) |
| M-06h | `ps.dart`, `ParametricEdit.capability` | return `inner.capability` | `regeneration_test.dart` (P4) |
| M-06i | `ps.dart`, `ParametricReplay.apply` | return `r` (a bare compound inverse) | `test/parametric/guards_test.dart` (G4) |
| M-06j | `regen.dart`, `_run` | delete the `_refused` block | `guards_test.dart` (G1, G2) |
| M-06k | `regen.dart`, `_run` | `final cleanup = <DraftCommand>[];` | `guards_test.dart` (G3) |
| M-06l | `regen.dart`, `_closure` | delete the `before.neighbours` line | `neighbourhood_test.dart` (N3) |
| M-06m | `regen.dart`, `_plan` | match by overall ordinal: one list of all children, ignoring kind | `regeneration_test.dart` (P5) |
| M-06n | `packages/jet_cad_2d/lib/src/document/undo.dart`, `undo` | `final inverse = _history.takeUndo();` → `final inverse = expander?.call(_history.takeUndo()) ?? …` (keep it compiling) | `test/document/expander_test.dart` (X2), `neighbourhood_test.dart` (N10) |
| M-06o | `box.dart`, `generate` | `view.toWorld(self).invert()` → `view.toWorld(self)` | `box_test.dart` (BT3) |
| M-06p | `regen.dart`, `_plan` | a changed payload becomes `RemoveEntityCommand(existing[i])` plus an `AddEntityCommand` with a reserved handle | `regeneration_test.dart` (P2) (Ruling 06-6) |
| M-06q | `ps.dart`, `_expand` | drop `&& !_setsParametric(command)` | `regeneration_test.dart` (P1) |
| M-06r | `regen.dart`, `_run` | apply `cleanup` right after computing it, and leave it out of the loop (revision 1's shape) | `guards_test.dart` (G6) |
| M-06s | `ps.dart`, `_expand` | delete the `_applying` check | `guards_test.dart` (G8) |
| M-06t | `regen.dart`, `_plan` | `Handle.checked(++reserved)` → `t.handleSeed.next()` | `guards_test.dart` (G7) |
| M-06u | `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`, `commit` | check `Capability.geometry` only | `packages/jet_cad_2d_flutter/test/draw/commit_needs_test.dart` (CN1) |
| M-06v | `ps.dart`, `_Registration.registerInto` | drop the `isRegistered` check | `regeneration_test.dart` (P10) |

- [ ] **Step 1: Fire each mutant.** Append each result to the log as it
  lands, formatted as in `plan-05-mutation-log.md`:
  - the heading `### M-06x — <title>`;
  - then `file:`, `edit:` and `test:`;
  - then `result: KILLED -- <names>; <summary>`.

  **A survivor** gets a fixture change in the owning test, a re-fire logged
  as `M-06x′`, and a ruling. The spec permits no designed survivor except
  M-06e (N/A) and M-06a (covered by the engine's own test).
- [ ] **Step 2: Tally.** Write "N fired: K killed, S survived, M-06e N/A".
- [ ] **Step 3:** `git status --short` lists only the log.
- [ ] **Step 4: Commit.**

```bash
git add docs/superpowers/notes/plan-06-mutation-log.md
git commit -m "$(cat <<'EOF'
docs: Plan 06 mutation log -- M-06a..v

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

