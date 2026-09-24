# SDD ledger — plan: docs/superpowers/plans/2026-09-24-parametric-layer.md

Branch plan-06/parametric-layer, cut from local main at 6a279b3 inside the session worktree.
Spec: docs/superpowers/specs/2026-09-24-parametric-layer-design.md (revision 2). Merge is the human's; never push.

## Pre-flight scan

| rows | produces / consumes | found |
|---|---|---|
| T1 -> T2 | T1 `CommandDispatcher.expander`; T2 `_expand` takes it | agrees |
| T1 -> T9 | M-06n edits `undo()` to call expander; X2 counts calls | agrees |
| T2 -> T3, T4 | support/clients.dart, support/fixture.dart (paramDoc, create, pair, kids, worldSegments, enc, canon, reload, catalog, Trip.mode/document) | agrees; T3/T4 build a second `ParametricSystem` on a live doc for drift(): safe only because of Ruling 06-13 (registerInto idempotent) — T2 must land it |
| T2 -> T9 | mutant identifiers `_survey`, `_closure`, `_plan`, `_run`, `_worldOf`, `_expand`, `ParametricReplay.apply`, `registerInto`, `ParametricEdit.capability` | all exist in T2's code |
| T5 -> T7 | `commit(ctx, build, {needs})`; BoxTool passes needs | agrees |
| T6 -> T7, T8 | `BoxParams`, `BoxType`, `boxCatalog`, `installBoxes` | agrees |
| T7 -> T8 | `test/support/box_rig.dart` (T7 creates; T8 adds `drawTwoBoxes`); main.dart edited by both, sequentially | agrees |
| T7 x T8 test ids | T7 adds `SP5` to startup_plan_test.dart; T8's selection_panel_test.dart also names tests SP1–SP7 | COLLISION -> Ruling below |
| T11 counts | engine 948, render 925, harness 82, app 66 | consistent with T1–T8 test counts |
| T1 self | X1–X4 vs the slot code | agrees |
| T2 self | P1–P10 vs code; P4 uses forEachInRect on group children (spike Q7 found them) | agrees |
| T3 self | N1–N14; N5 asserts raw bytes (reload keeps slot order) | agrees |
| T4 self | G1–G9 traced against `_run` | agrees |
| T5 self | CN1–CN2 adapt to draw fixture names | fallback stated |
| T6 self | BT1–BT6 | agrees |
| T7 self | BX1–BX6, SP5; BX4 counts derived (4 and 4), fallback stated | agrees |
| T8 self | tests vs SelectionPanel; `_load` in initState (no setState in initState) | agrees |
| T9–T11 | docs only | agrees |

Ruling: T8's selection-panel tests are named SE1–SE7, not SP1–SP7 — SP1–SP5 already name startup-plan tests, and the plan text used SP for both — cost if wrong: none (names only).

## Tasks
Task 1: minor (deferred): expander's "one slot, one owner" is doc-only in the dispatcher; the owner-side guard is ParametricSystem.install() throwing when the slot is taken (Task 2, P8).
Task 1: complete (commits 6a279b3..058918d, review clean)
Task 2: review (opus) Needs fixes — Important: after-survey calls client reach() outside the rollback try (probe-confirmed, plan-mandated).
Task 2: Ruling: the reach()-throws hole is fixed, not parked — spec D4 step 8 says "in every failure case the dispatcher pushes nothing" and DraftCommand.apply is all-or-nothing — cost if wrong: none.
Task 2: Ruling: the D6 guard is tightened to the spec text (a touched handle in G that still exists is refused, whatever its owner now is) and enters the fix loop although the reviewer graded it Minor — the spec is binding and the looser rule lets a bundled detach sidestep the backstop — cost if wrong: a compound that detaches a box and edits its old child in one command is refused; no tool issues one.
Task 2: minor (deferred): found[h] keeps one registration per handle; a holder with two parametric components gets only one detached on delete.
Task 2: minor (deferred): drift() does not set _applying, so a generate() calling execute during a dry run would mutate.
Task 2: minor (deferred): the fast path sorts every store via withComponent<T>(); spec asked for a store-length check (not frame path).
Task 2: minor (deferred): the hand-rolled regeneration loop in _run duplicates CompoundCommand.apply; deserves a comment saying why (it tells its own rollback failure apart from a child's StateError).
Task 2: minor (deferred): P4 asserts A 5 but not B 3 after the edit.
Task 2: minor (deferred): Trip.mode/Trip.document are static; later tests must reset in tearDown (Task 4's G tests do).
Task 2: fix round 1/5 (2 addressed, 0 open — after-survey in the try (P11), D6 guard tightened to spec text (P12); commits d9eee9c..9e5c2dd)
Task 2: Ruling: Task 9 fires two added mutants — M-06w (after-survey, lost, cleanup and seeds moved back outside the try; killed by P11) and M-06x (guard refuses a surviving child only while its owner is still an object; killed by P12) — cost if wrong: none.
Task 2: Ruling: expected counts move by the two added tests — engine 950 at Task 11 (was 948) — cost if wrong: none.
Task 2: complete (commits 058918d..9e5c2dd, review clean after 1 fix round)
Task 3: complete (commits 9e5c2dd..7504ece, review clean; reviewer fired M-06b and saw N5 alone go red)
Task 4: Ruling: G3 and G6 compare with root-children order normalised (and G3 without handleSeed) — pre-existing engine behaviour: RemoveNodeCommand's inverse re-links a node at the END of its parent's children (tree.dart _link), and HandleSeed never moves back — so a rolled-back or undone delete is state-equal, not byte-equal; the plan's "bytes unchanged" wording for G6 overstated what the engine can give — cost if wrong: a real ordering regression in a rollback would hide behind the normalisation; the component, node, entity and geometry assertions still stand.
Task 4: minor (deferred): a refused/rolled-back delete of a group (G6 shape) leaves the root's children list reordered — pre-existing RemoveNodeCommand inverse behaviour, for the final review and the results note's debt.
Task 4: review Approved; its one Important ("record the helper deviation as a ruling") is already met by the Task 4 Ruling line above — the reviewer read plan-rulings.md, not this ledger. Reviewer fired M-06r: G3 and G6 red.
Task 4: minor (deferred): the root-order/handleSeed normalising helpers live in guards_test.dart only; promote to support/fixture.dart if a later test needs them.
Task 4: complete (commits 7504ece..ee7bd80, review clean)
Task 5: complete (commits ee7bd80..8676163, review clean; CN adapted to the real draw fixture — drawScene/drawRig, plain test(); M-06u fired by the implementer and killed)
Task 6: Ruling: M-06g (app) is killed by BT6 (the reach oracle), not BT3 — with untransformed corners every box's reach contains its local origin region, so every pair becomes a neighbour and generate's exact test still yields the right outline; the mutant costs time, not correctness (spec open question on reach) — cost if wrong: none; BT6 pins reach directly.
Task 6: review Needs fixes — Important: BT1 cannot kill a BoxParams.== that ignores height (or width).
Task 6: minor (deferred): BoxParams does not enforce width/height > 0 (D13); the tool (degenerate check) and the panel (<= 0 reverts) are the gatekeepers; fromJson accepts anything.
Task 6: minor (deferred): BT2–BT4 assert counts only; no endpoint oracle in the app (the engine's P1/P2 carry world oracles for the same algorithm).
Task 6: minor (deferred): the report called _insideInterval a character-for-character copy; one token differs (tol.linear vs Tolerance.standard.linear), same value.
Task 6: fix round 1/5 (1 addressed, 0 open — BT1 inequality on height and width, both == mutants killed; commits 73aed01..53b29a8)
Task 6: complete (commits 8676163..53b29a8, review clean after 1 fix round)
Task 7: minor (deferred): RED was captured after the commit (box_tool.dart emptied, backed up and restored through `git show HEAD:…`, tree verified clean) — not `git checkout --`, but not test-first order either.
Task 7: minor (deferred): BX4 checks drift with a fresh ParametricSystem, not the shell's installed one (equivalent by Ruling 06-13).
Task 7: complete (commits 53b29a8..dcced6a, review clean; app M-06g/M-06o stay with box_test.dart BT3/BT6, which plant rotated groups directly)
Task 8: review Needs fixes — Important: the class comment claims Ruling 06-14 (onSubmitted only) while onTapOutside still commits; Important: focus-out commit is unpinned.
Task 8: Ruling: keep focus-out commit (onTapOutside), as spec D13 says "Enter or focus-out commits"; Ruling 06-14 is NOT made; fix the comment and add SE8 pinning focus-out — cost if wrong: a half-typed but parseable value commits when the user taps elsewhere, which is what D13 asks for.
Task 8: minor (deferred): _sync reloads the fields on every document change, overwriting uncommitted keystrokes when an unrelated edit lands mid-typing.
Task 8: process note: the Task 8 reviewer spawned a helper subagent (a7eb5c3) against the no-subagents contract; its one relevant finding — a read-only field can still take focus and fire onTapOutside — is harmless because the text cannot change, so _submit's `next == p` returns before any execute.
Task 8: minor (deferred, flag for final review): onTapOutside is not focus-out — Flutter groups all plain TextFields (shared groupId), so moving from Width to Height commits nothing; a later document change then runs _sync and reloads Width from the model, silently dropping the typed value. A FocusNode listener would be true focus-out. For the final review to triage.
Task 8: fix round 1/5 (2 addressed, 0 open — comment states the real behaviour; SE8 pins tap-outside commit, onTapOutside mutant killed; commits 38af6db..563844b)
Task 8: complete (commits dcced6a..563844b, review clean after 1 fix round)
Task 9: M-06b' survived its first fire (N6 was degenerate: only one side reserved a handle); fixture-only fix, re-fired KILLED; reviewer re-fired it too.
Task 9: complete (commits 563844b..7b31030, review clean; 26 fired, 26 killed, M-06e N/A)
Ruling: Tasks 10 and 11 (Steps 1–4) go to one dispatch; Task 11's ledger archive waits until after the final whole-branch review and its fix wave, so the archive holds the final review — Plan 05's Ruling T11-a precedent — cost if wrong: none.
Task 10: complete (commit fbc6fba)
Task 11 (Steps 1-4): fix round 1/5 (2 addressed — fork point 6a279b3 not 6adf03d, trailer count re-measured at 01defe5; commits 7ce1e21..af4149d)
Task 11 (Steps 1-4): complete (commits fbc6fba..af4149d); ledger archive deferred to after the final review (Ruling above)
Final review (opus): With fixes — Important: hover notifications run _sync and wipe a typed value (reproduced); Important: onTapOutside is not focus-out, Width -> Height drops the width (reproduced); Minor: undo/redo index freshness only incidentally tested; Minor: guard removal arm still "owner is a box" not "owner node exists"; Minor: swallowed box becomes an unselectable ghost (07); Minor: neighbour search twice per edit once any box exists (0.7 ms/100, 16 ms/600; 07); Minor: drift() should set _applying.
Ruling: the final fix wave takes both Importants plus Minors 1, 2 and 5; Minors 3 and 4 go to the results note's debt for 07 — the reviewer's recommendation; each is small and in code this branch owns — cost if wrong: none.
Final fix wave: commits af4149d..81389ac (panel F1/F2 with SE8 re-pointed, SE9, SE10; engine F3 P13, F4 P14, F5 G10; docs F6). Gates: engine 953, render 925 + 1 skip + 5 goldens, harness 82, app 69, both builds ✓ Built.
Final re-review: all six findings ADDRESSED; reviewer fired the F4 mutant (P14 red, G3 green).
Final: parked — a focused field's uncommitted text commits onto whichever box is selected when focus is lost, so a selection change that does not itself take focus would write it to the wrong box — Ruling: parked as debt for 07/12, not fixed here — no shipped gesture reaches it (a canvas tap fires the panel's outside-tap unfocus first; the reviewer verified the real tap commits to the right box), and there is no second fix wave — cost if wrong: once keyboard selection-cycling or synced selection lands, a typed value can land on the wrong box; the fix is to pin the commit target at focus time.
Final: minor (deferred): after an undo that touches the box, a focused field keeps its (now stale) typed text by design of F1's never-overwrite-a-focused-field rule.
Ruling: the SDD workspace is archived into docs/superpowers/ledgers/ as the branch's last commit and NOT deleted — this repo's convention (a finished plan's ledger is archived, never rm -rf'd) overrides the skill's delete step — cost if wrong: none.
