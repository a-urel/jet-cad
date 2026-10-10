# SDD ledger — plan: docs/superpowers/plans/2026-10-10-node-components-on-delete.md

Spec: docs/superpowers/specs/2026-10-09-node-components-on-delete-design.md, revision 3 (approved 2026-10-10).
Branch: fix/node-components-on-delete, cut from spec/node-components-on-delete at 5a0af46 (main e281372 + spec + plan).
Execution: subagent-driven, chosen by the human 2026-10-10 ("start subagent driven").

Ruling: the ledger lives in the skill's workspace `.superpowers/sdd/2026-10-10-node-components-on-delete/`, not the plan's named `2026-10-09-node-components-on-delete/` (which holds the spec review and its prompts) — the skill's scripts write briefs and review packages here, and two live ledgers would split the record — on merge both directories are archived together into docs/superpowers/ledgers/2026-10-09-node-components-on-delete/ as the plan says; cost if wrong: one rename at archive time.

## Pre-flight scan

| Pair / task | Produces vs consumes | Found |
|---|---|---|
| T1 -> T2 | T1: `AddNodeCommand(node, {index, components})`, `RemoveNodeCommand` takes components, static caps. T2 consumes them (P-1..P-3, TD7 kills, D-7 rests on D-1) | consistent; T2's Step 7 re-applies T1 mutants M-1, M-2, M-15 to commands.dart and restores them — touches T1's file only transiently |
| T1 -> T3 | T3 documents T1/T2 (CHANGELOG, results note: mutant table from both reports) | consistent |
| T2 -> T3 | T3's results note needs T2's M-17 and re-check lines | consistent |
| T1 self | Step 1 test code vs Steps 3-4 code: names `checkRestorable`, `components:`, `CycleDetectedError`, `RangeError`, `StateError` agree; N-4 snapshots non-empty; M-1..M-16 each named with a killer in this task's tests | Step 2 expects compile errors (no red run before impl) — TDD red comes from the mutants (Step 9); accepted, plan says so |
| T1 self | Step 10 gate runs floor plan with the expander still installed (old TD10) | spike at e281372 saw 1912 pass with D-1 only; consistent |
| T2 self | Step 1 imports helpers from `tables/table_data_test.dart` (a test file with `main`); fallback move to table_fixture.dart allowed by the plan | consistent with Global "existing tests pass unedited" since a move is permitted by the plan text |
| T2 self | Step 3 TD10 relies on stamp order A then B (touched order) — plan gives the swap fallback | consistent |
| T3 self | docs only | consistent |
| Rubric | no test asserting nothing; no mandated duplication | clean |

No conflicts needing a ruling beyond the workspace one above.
Task 1: dispatched (base 5a0af46, implementer sonnet, agent a4d4beb9955b42e72)
Task 1: implementer DONE, commit 90044db (concerns: N-4 seed order fix; M-5 not killed by N-6; _Registration.detach kept unused; DV1 title stale)
Task 1: review (opus): spec ❌ (objectsOf doc at parametric_system.dart:443-449 not rewritten, brief Step 5 / spec D-8), quality Approved, no Critical/Important.
Task 1: minor (deferred): DV1 title and "the detach components" comment still name the cleanup/detach (dissolve_test.dart:146-148).
Task 1: minor (deferred): _Registration.detach (parametric_system.dart:791) dead in lib, kept only as M-11/M-12's template.
Task 1: minor (deferred): a cross-document snapshot whose type id maps to a different Dart class passes checkRestorable; ComponentStore.set would throw TypeError after addNode wrote (I-3), read not run — spec-level edge.
Task 1: minor (deferred): sibling and S-1's three handles share one ObjectLayer value and the a.earlier payload (plan-mandated fixture; no mutant survives).
Task 1: minor (deferred): PG1 comment reflow broken (page_test.dart:216-218).
Ruling: M-5's killers are N-2 and N-5, not N-6 as spec and plan say — N-6's bare branch undo reverses the unknown order and the carrying branch reverses it back (implementer saw N-6 green; reviewer confirmed by reading) — the results note records N-2, N-5; cost if wrong: one wrong row in the results table.
Ruling: the N-4 tests take handleSeed.next() before the baseline encoding — the encoding includes the seed, so the plan's order fails against a correct implementation; no assertion weakened — cost if wrong: none found.
Task 1: fix round 1/5 (1 addressed, 0 open — objectsOf doc; commits 90044db..d082640)
Task 1: complete (commits 5a0af46..d082640, review clean after fix round 1)
Task 2: dispatched (base d082640)
Task 2: implementer sonnet, agent ad78258182d274a58
Task 2: implementer DONE_WITH_CONCERNS, commit 391d967 (P-1..P-3 compare canon() not encodeToString: wall undo restores entities in another slot order, 06 D11; TD8 title untouched; helpers imported from table_data_test.dart)
Task 2: review (opus): spec ✅, quality Approved, no Critical/Important.
Ruling: P-1 to P-3 compare canon(doc) (entities sorted by handle, everything else exact) instead of encodeToString — undo of a wall's child-entity removals restores entity slot order differently (reviewer's run of P-2 at 391d967: enc equal false, canon equal true, only `entities` differs, [20,21,22] vs [21,20,22]); canon is the repo's existing comparison for delete-then-undo (opening_object_test.dart:111-140) — the results note states P-1's "byte for byte" as "byte for byte, entities in handle order (06 D11)"; cost if wrong: an entity-order regression on undo would not be caught by P-1..P-3 (TD7..TD7c and HD12 still compare encodeToString for tables).
Ruling: P-2 is not recorded as a killer of M-12 — under D-1 a re-added cleanup detaches nothing, so P-2 is expected green under M-12 (read, not run); PG1 is M-12's recorded killer (Task 1's run) — cost if wrong: one killer under-claimed.
Task 2: minor (deferred): P-2's title claims the restore travels "through the node's snapshot"; the test checks the outcome only (delete_components_test.dart:79-80, 96-101).
Task 2: minor (deferred): P-1..P-3 have no surviving sibling with the same types; P-1's table carries one unknown payload (plan-mandated fixtures; no named mutant survives).
Task 2: minor (deferred): TD9's title contradicts itself ("removes nothing" beside "a delete of another table", table_data_test.dart:380-381).
Task 2: minor (deferred): leftover `derived`/`else continue` in TableLabelEdit's loop (table_label_system.dart:93-99), brief-permitted.
Task 2: complete (commits d082640..391d967, review clean)
Task 3: dispatched (base 391d967)
Task 3: implementer DONE, commit a39a290 (concerns: M-3's TD7 kill not run, recorded N-2/N-5/N-6 only; no single all-package gate at tip)
Task 3: review (sonnet): spec ✅ with 3 ⚠️, quality Approved, no Critical/Important. ⚠️ resolved by the controller: standing set measured at e281372 by this session's baseline runs and at 90044db by Task 1's gates; no allocation/golden file in `git diff --name-only 5a0af46..HEAD`; paramsOf's doc rewritten in 90044db (parametric_system.dart diff).
Task 3: minor (deferred): results note's "no named mutant survives" lead-in sits against the cross-document-snapshot (I-3) bullet; D-8 bullet mixes tasks; M-3 row could say TD7 not run; one long line in Gates; STATUS drops the Copilot-quota fact.
Task 3: complete (commits 391d967..a39a290, review clean)
Final review: dispatched (opus, range e281372..a39a290, gates at the tip requested)
Final review (opus): Ready to merge with fixes; no Critical/Important. Gates at a39a290: only the standing failures red (2d +1280 -2, flutter +1432 ~1 -5, floor_plan +1915, gpu +20, symbols +97, floor_planner +212, demo +68; analyze/format clean). Reviewer re-ran M-17, M-3 (TD7, TD7b, TD7c red), M-12 (PG1 red, P-1..P-3 green), M-5 (N-2, N-5 red, N-6 green), M-14; a probe forcing undo to index 0 survives node_components_test (N-2's node is at index 0) but node_index_undo_test kills it. Agrees with all five rulings.
Ruling: the final fix wave also moves N-2's node off index 0 and adds a value-type check to checkRestorable (with an N-4 case and a named mutant M-18) — the reviewer's probe showed node_components_test does not pin the index alone, and a cross-document snapshot whose type id maps to another Dart class breaks I-3 today (TypeError after addNode wrote); both are small and serve invariants the spec states (I-2, I-3) — cost if wrong: two small additions beyond the plan's letter, reviewable in the fix diff.
Ruling: parked — `_Registration.detach` left in lib (dead since D-4; reviewer: optional), TableLabelEdit's leftover `derived`/`else continue`, P-1..P-3's fixture breadth, the note's long line and the STATUS wording — none changes behaviour or a test's power; cost if wrong: cosmetic debt.
Final fix wave: DONE, commit f1a9989 (11 items; checkRestorable type test via an is-T closure recorded in register — stores are ComponentStore<Component>, a wrong-class value would have failed later in get<T>, not in set)
Final fix re-review (opus): all 11 addressed; reran node_components_test (+11) and M-18 (red); 4 new Minor, no Critical/Important.
Controller check: jet_cad_restaurant_symbols at f1a9989 — `00:00 +97: All tests passed!`, analyze `No issues found!`, format `Formatted 15 files (0 changed)` (closes the re-review's gate-claim minor).
Ruling: parked — node_components_test's parent now lists its children in ascending handle order, so an undo re-inserting by handle value would leave N-2 green — node_index_undo_test (O-10's own fixtures, out of handle order, its mutant M5 "insert sorted by handle") already pins that, and N-2 pins the index against index 0 — cost if wrong: one more place an index regression must be caught by the other file.
Ruling: parked — the results note's line saying the old cross-document case "would fail after addNode wrote" is imprecise (the add went through and stored a wrong-class value that a later get<T> would fail to cast; the note's own M-18 row says the add did not throw) — no result is misreported, only the mechanism of a fixed bug — cost if wrong: a reader of the note misunderstands a bug that no longer exists; worth one sentence if the branch is touched again.
Ruling: parked — checkRestorable's doc says "only a snapshot from another document can fail either"; a registry binding two classes to one id would also refuse a same-document undo; production registers one class per id — cost if wrong: a misleading comment for an unsupported setup.
Ruling: parked — the spec's I-3 lists four refusals and not the new class check (f1a9989) — the spec is approved and binding as written; the check strengthens I-3's all-or-nothing rather than changing it, and the results note records it — cost if wrong: the spec under-describes one refusal until its next revision.
Final: complete (code 5a0af46..f1a9989; final review Ready with fixes, fix wave f1a9989 re-reviewed: all addressed; 4 minors parked with rulings)
