# Task 1 review: Engine, a removed definition takes its components (spec D11)

Reviewer: independent; detached worktree `.worktrees/plan-09c1-review` at `48c8d57`.
Diff reviewed: `git diff 904970d..48c8d57` (5 files, +500 −12).

## Verdict: **Needs fixes** (3 minor; no blocking or major)

The implementation is correct against spec D11 / W-1 and plan Task 1. All gates
reproduce the implementer's counts exactly, and all five named mutants are red.
Two of my own mutants survive. Each one breaks a clause the code documents and
the plan names ("ordered by type id"; "all-or-nothing"). Both test fixes are
two-line fixture changes, and I checked each one against its mutant (see below).
There is also one stale comment in the app.

## Gates (run by me, this container, Flutter 3.47.2, `CI=true`)

| Gate | Mine | Implementer |
|---|---|---|
| engine `dart test` | `00:21 +1237 -2: Some tests failed.` The 2 are the standing `generate_document_test.dart` ("the default document is the one Plan 2 measured, byte for byte", "both text fractions default to zero and change nothing") | `+1237 -2`, same 2 |
| engine analyze / format | No issues found! / 168 files, 0 changed, exit 0 | same |
| render `flutter test` | `01:34 +1187 ~1 -7: Some tests failed.` The 7 are the standing canvas text ladders (`text_ladder_golden_test.dart` rungs 1–5, `text_lod_ladder_golden_test.dart` rungs 1–2) | `+1187 ~1 -7` |
| render analyze / format | No issues found! / 208 files, 0 changed, exit 0 | same |
| app `flutter test` | `04:40 +993: All tests passed!` | `+993` |
| app analyze / format | No issues found! / 175 files, 0 changed, exit 0 | same |
| `dev_harness_2d` analyze | No issues found! | same |

Protected files: `git diff --name-only 904970d..48c8d57` names no
`analysis_options.yaml` and nothing under either `test/invariants/`. pub get
rewrote `packages/jet_cad/analysis_options.yaml` in the review worktree as
expected, and nothing commits it. Purity: `wall_attach.dart` and
`symbol_box.dart` do not exist yet (Tasks 2/4). `component.dart` imports
`package:meta`, which is a declared dependency of `jet_cad_2d` (`pubspec.yaml:12`)
and already used in `node.dart` and `text_geometry.dart`.

## Mutants (each fired by cp backup, mutate, run, cp back, `diff` exit 0)

Engine runs use `test/document/definition_commands_test.dart` (26 tests). App
runs use `test/symbols/symbol_component_test.dart` plus `symbol_placer_test.dart`.

| Mutant | Site | Result | Red tests (mine) |
|---|---|---|---|
| **M-09c-q** restore skipped | commands.dart:451 | **red** | engine: #1 remove/undo/redo, #5 inverse empty/non-empty, #6 unknown-only undo, #7 all-or-nothing (4). app: SC12. The implementer listed #1 and #5 only. #6 and #7 were added in `48c8d57` after its table, so the gap is benign. |
| **M-09c-r** snapshot skips unknowns | component.dart:164 | **red** | #1, #5, #6, #8, #9 |
| **M-09c-aj** forward caps `{structure}` | commands.dart:487 | **red** | #3, #4 |
| **M-09c-ba** inverse non-empty `{structure}` | commands.dart:431 | **red** | #5, #6 |
| detach skipped | commands.dart:514 | **red** | engine #1, #6; app SC12 |
| P13's guard (`doc.tree.definition(h) != null` dropped) | symbol_placer.dart:83 | **red** | P13. The rewritten P13 still guards the placer. |
| own: snapshot taken after `detachAll` | commands.dart:513-514 | **red** | #1, #5, #6 |
| own: `detachAll` keeps unknowns | component.dart:176 | **red** | #1, #6, #8 |
| own: inverse caps test `components.components.isEmpty` (ignores unknowns) | commands.dart:429 | **red** | #6 |
| own: restore appends unknowns reversed | component.dart:202 | **red** | #8 |
| own: **no sort** (`registered.sort` deleted) | component.dart:166 | **SURVIVES** (`+26: All tests passed!`) | none. Finding 1. |
| own: **interleaved restore** (write each store as it is validated) | component.dart:189-201 | **SURVIVES** (`+26: All tests passed!`) | none. Finding 2. |

## Findings

1. **minor: the snapshot's type-id order is not pinned.** `component.dart:166`.
   Evidence: deleting `registered.sort(...)` leaves all 26 tests green. Every
   fixture registers its types in type-id order, so the map's insertion order
   already matches the sorted order. `registerBuiltIns()` runs first
   (`jet_cad.object_layer`), then `Tally` (`test.tally`). This is the
   degenerate-fixture pattern. The plan says the value is "ordered by type id",
   and `ComponentSnapshot.components` is public. Fix: in
   `definition_commands_test.dart:601-603`, register `Tally` **before**
   `registerBuiltIns()`:
   `ComponentRegistry()..register<Tally>(Tally.id, Tally.fromJson)..registerBuiltIns()`.
   Checked: with this change the file passes (`+26`), and the no-sort mutant
   turns #8 red (`+25 -1`).

2. **minor: restore's all-or-nothing is not pinned.** Doc at
   `component.dart:187-188` and `commands.dart:412-415`; test #7 at
   `definition_commands_test.dart:577-597`. Evidence: a `restore` that writes
   each store while it validates leaves all 26 tests green. Test #7's snapshot
   holds one component, and it is the unregistered one, so nothing could be
   written before the throw whatever the restore does. In the
   `AddDefinitionCommand` path, a partial write followed by a throw would leave
   an orphan component with no history. That breaks `DraftCommand`'s
   "complete fully or leave the target unmutated" contract, which the doc
   comment claims to keep. Fix: give the source registry the built-ins too and
   attach a registered component that sorts before `test.tally`:
   `ComponentRegistry()..registerBuiltIns()..register<Tally>(...)`, then
   `source.attach(h, const ObjectLayer(kLayer))`. The target document has
   `ObjectLayer` but not `Tally`, and the existing
   `expect(componentBytes(doc), components)` then catches the partial write.
   Checked: green as is (`+26`), and red under the interleaved mutant (#7,
   `+25 -1`).

3. **minor: stale comment in the app.**
   `apps/floor_planner/lib/symbols/symbol_placer.dart:78-79` still says
   "A component can outlive its definition (purge and definition removal never
   clear one)". Since D11, definition removal does clear them. The guard itself
   is still needed for orphans in files saved before 09c (P13 pins it, and the
   mutant is red). Fix: reword to "A component can outlive its definition in a
   file saved before 09c (D11 leaves such orphans alone, and purge does not
   clear them), so the definition must still exist." Task 9 also edits this
   file, so the fix can wait for Task 9 if the controller prefers, but the
   comment should not survive the branch.

## Notes and rulings

- **R-C1-4 (undoing a plain `AddDefinitionCommand` now needs `components`):
  accept.** `CommandDispatcher.undo`/`redo` call `_require(inverse)` before
  `apply` (`undo.dart:212`, `:243`), so the inverse's `capabilities`
  are checked. The inverse is a `RemoveDefinitionCommand`, and W-1 requires it
  to declare static `{structure, components}`, because a remove cannot know the
  handle's components before `apply`. The rule therefore follows from the spec
  and is not a defect. The shipped presets are `all`, `runtime`
  (`structure: false`, which already refuses the add's undo) and `readOnly`.
  None of them is the affected shape `{structure: true, components: false}`,
  and no app or harness code builds a custom `DraftPermissions`
  (`grep "DraftPermissions(" apps/*/lib packages/*/lib` finds only
  `command.dart`). The placer's undo is already a compound that needs
  `components`, as spec D11's last bullet says. Record the consequence in the
  spec's "Amended at execution" (Task 11).
- **Order guards → restore → addDefinition: correct.** After `restore` returns,
  neither `tree.addDefinition` (a map write plus `_relinkDefinition` on empty
  children) nor `handleSeed.raiseTo` can throw. Restore's own only throw comes
  before any write (but see Finding 2: that is not pinned). The forward
  `RemoveDefinitionCommand` takes the snapshot and detaches only after every
  existing guard; test #2 and the "detach before guards" mutant pin this.
  `CompoundCommand` rollback replays the inverse with its snapshot, so a
  compound whose later child throws still restores the components.
- **R-C1-2 (P13): accept.** The new order (add 905, remove, `SetComponent` on
  905) reaches the same state as the old one: an orphan `SymbolComponent` on a
  handle the seed has passed, with no definition. The assertions are unchanged,
  and the guard mutant turns P13 red.
- **R-C1-1 (unknown payloads oldest first rather than sorted): accept.** Within
  one handle, `toJson` is insensitive to the order of distinct-type unknowns.
  For duplicates of the same type id, the last one wins under either order,
  since a stable sort keeps their relative order. The only observable
  difference is `unknownOf`, which the implementer's order preserves exactly.
  The `own: unknowns reversed` mutant pins it. Record it as a wording amendment
  of D11's "in type-id order".
- **R-C1-3 (public `detachAll`, public `AddDefinitionCommand(components:)`):
  accept.** Both are minimal. `detachAll` removes only the given handle's
  entries (test #8 checks the neighbour `n`).
- `RemoveDefinitionCommand.capability` stays `structure`, so `SpatialIndex` and
  `TileCache` still rebuild on it. No app listener branches on a change's
  `capability` in a way the removal of components could slip past.
- Not defects (the implementer flagged both itself): `ComponentSnapshot` has no
  `operator ==`, and `restore` is additive for unknown payloads, so restoring
  onto a non-empty handle would duplicate them. Under linear history the only
  caller restores onto a handle it emptied itself.
- Fixtures: non-default component values (`Tally(7,'north')`,
  `ObjectLayer(0x2A1)`), a neighbour definition with different values, and
  unknown payloads attached out of type-id order. P-2's wall/mirror/scale rules
  do not apply to this engine task. The only degenerate fixtures are the
  registration-order and single-component ones behind Findings 1 and 2.

Every count, transcript line and verdict above comes from runs I made in the
review worktree. Mutant logs are in
`/tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/review1/mut_*.txt`
and gate logs are alongside them. After the fix checks the test file was
restored by `cp` (`diff` exit 0). `git status` in the review worktree shows only
`packages/jet_cad/analysis_options.yaml` (from pub get).

## Re-review of 1b (9414208)

Reviewed `git diff 31d098d..9414208` in the review worktree, detached at
`9414208`. Parent `31d098d` is Task 2 and is not reviewed here. The diff
changes two files and nothing else:
`packages/jet_cad_2d/test/document/definition_commands_test.dart` (+10 −3)
and a comment in `apps/floor_planner/lib/symbols/symbol_placer.dart` (+4 −2).
No library code changed, and no `analysis_options.yaml` or invariant test is
touched.

### Verdict: **Approved**

All three findings are fixed as proposed:

1. **Finding 1 fixed.** `registry()` now registers `Tally` before
   `registerBuiltIns()`, and a comment says why.
2. **Finding 2 fixed.** Test #7's source registry now has the built-ins.
   The handle carries both `ObjectLayer(kLayer)` and `Tally(7,'north')`.
   The target registers `ObjectLayer` but not `Tally`. The existing
   `componentBytes(doc)` assertion catches a partial write, and a comment
   explains it.
3. **Finding 3 fixed.** The placer comment now says that orphans come from
   files saved before 09c, that D11 takes components on removal but leaves
   those orphans alone, and that purge never clears one. All three claims
   are accurate. The code is unchanged: the diff touches only comment lines.

### Gates (my runs at `9414208`, `CI=true`)

| Package | Check | Result |
|---|---|---|
| Engine | `dart test` | `00:21 +1237 -2: Some tests failed.` The 2 are the standing `generate_document_test.dart` failures ("the default document is the one Plan 2 measured, byte for byte" and "both text fractions default to zero and change nothing"). This matches Task 1, as expected, since 1b only edits fixtures. |
| Engine | analyze | No issues found! |
| Engine | format | 168 files, 0 changed, exit 0. |
| App | `flutter test test/symbols/symbol_placer_test.dart` | `00:00 +25: All tests passed!` |
| App | analyze | No issues found! |
| App | format | 177 files, 0 changed, exit 0. |

All figures match the implementer's report. Render and the full app suite
were not re-run: the only app change is a comment, and render is untouched.

### Mutants (my runs at `9414208`; cp backup, mutate, run, cp back, `diff` exit 0 each)

| Mutant | Result | Red tests |
|---|---|---|
| **no sort** (component.dart:166), previously survived | **red** `+25 -1` | #8. `Which: at location [0] is (String, Tally):<(test.tally, …)> instead of (String, ObjectLayer):<(jet_cad.object_layer, ObjectLayer(2A1))>` |
| **interleaved restore** (component.dart:189-201), previously survived | **red** `+25 -1` | #7. `Expected: '{}'  Actual: '{"jet_cad.object_layer":{"20979":{"layer":673}}}'` |
| M-09c-q | **red** `+22 -4` | #1, #5, #6, #7 |
| M-09c-r | **red** `+21 -5` | #1, #5, #6, #8, #9 |
| M-09c-aj | **red** `+24 -2` | #3, #4 |
| M-09c-ba | **red** `+24 -2` | #5, #6 |
| detach skipped | **red** `+24 -2` | #1, #6 |
| P13 guard dropped (symbol_placer.dart:85) | **red** `+24 -1` | P13 |

No mutant survives. After the runs, `git status` in the review worktree shows
only the pub-get rewrite of `packages/jet_cad/analysis_options.yaml`. Logs:
`scratchpad/review1/rr_engine.txt` and `mut_rr_*.txt`.
