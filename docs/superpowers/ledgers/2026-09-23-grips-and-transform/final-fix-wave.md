# Plan 03 — final fix wave (one dispatch, the complete list)

Source: the final whole-branch review (Opus, HEAD 136af89) and Task 12's review. Fix every item below. Tests first where a test is named: show each new test RED against its mutant (cp backup → edit → focused run → RED → restore → diff clean), then GREEN. Never `git checkout --` a .dart file. Commit in logical commits (tests / production / docs). Truthful trailer (Ruling T2-a).

## A. Code and tests

A1 (Important) — **grip draw positions are unguarded.** `selection_overlay.dart:244-255` projects stretch/radius/centre grips by an expression separate from `GripCache.hitTest`'s (`grip_cache.dart:129-130`); the reviewer changed `m.c`→`m.b` in the x projection and the render suite stayed green. In `test/selection_overlay_grips_test.dart` P2: assert every point pair in the stretch `drawRawPoints` list and in the move list equals `screenOf(camera, g.x, g.y)` for the corresponding `rig.grips.grips` entries (stretch/radius in order, then move), to 1e-3 px (float32). New mutant **M-03bh**: `m.c` → `m.b` in the x projection.

A2 (Important) — **rotation disc position unasserted.** Drawing the disc at `g.anchor` instead of `g.centre` (`selection_overlay.dart:275`) survived. In P4, assert the `drawCircle` centre equals `rotationGripOf(box, m).centre` (and its radius equals the spec's 4 px, i.e. 8 px diameter). New mutant **M-03bi**: disc at `g.anchor`.

A3 (Important) — **circle reshape preview untested.** Dropping the origin subtraction in `_reshapePath`'s circle branch (`select_tool.dart:766-767`) survived. Add the circle twin of M-03bg's arc test (radius-grip reshape of a circle under `gripCamera`, preview path bounds in rebased world within 1e-3). New mutant **M-03bj**.

A4 (Minor) — **grip-to-grip hover repaint unguarded.** `select_tool.dart:197-199` notifies on a hot-grip change; removing `&& !hotChanged` stayed green. Add a test: hover from one grip of a selected object to another grip of the same object (same cursor, same object hover) → the tool notifies exactly once for the move and `grips.hot` changes. New mutant **M-03bk**.

A5 (Minor, production) — **shift pressed/released mid-drag is ignored until the pointer moves.** `onKey` (`select_tool.dart:540-550`) swallows the shift key without re-resolving, and a later camera change re-resolves with a stale `_lastShift`. Fix: on a shift KeyDown/KeyUp while dragging (LogicalKeyboardKey.shiftLeft/shiftRight, or `HardwareKeyboard.instance.isShiftPressed` after the event), set `_lastShift` and re-target from the last screen point, notifying. Key-downs are still consumed (D5); key-ups may still pass. Test: a move drag, then shift down without moving the pointer → the target is ortho-constrained immediately; shift up → unconstrained again. New mutant **M-03bl** (drop the re-target). Keep it minimal.

A6 (Minor) — doc comment `grips.dart:226-227` "θ = 0 leaves every scalar bit for bit" is wrong for a height-only text (it gains a rotation scalar of 0). Qualify it.

A7 (Minor) — add a one-line doc comment at `SelectTool.onPointerExit` saying the host (`InteractionLayer`) never forwards an exit while a pointer is captured, so this cancel is unreachable mid-drag (02's amended rule).

## B. Docs

B1 (Important) — `STATUS.md` "Branch and worktree map" (~1246-1252) says "No worktrees. Nothing is in flight." Replace with the real state (verify each with `git worktree list` and `git log --oneline -1 <branch>` yourself):
- `plan-03/grips-and-transform` at `.claude/worktrees/plan-03-grips-and-transform` — this plan, executed, awaiting the human's merge decision.
- `fix/page-copywith-num` at `.claude/worktrees/focused-nightingale-510bd1`, head `8385753`, cut from `main` at `e376ced` — the `PageComponent.copyWith(gridStepMm: <int>)` fix, committed, not merged (another session's work).
- `fix/root-transform-identity` at `.claude/worktrees/hungry-haibt-cf67c0`, head `776f201`, cut from `main` at `c09b747` (before the plan commit) — pins the root's transform to the identity, committed, not merged (another session's work). It edits this plan's spec and STATUS.md, so it will conflict with this branch's docs: record that the merge order is the human's decision and that whichever merges second resolves the doc conflict (the root-transform fix closes this plan's "root transform" debt item).
B2 (Important) — STATUS (~271-272) and the results note's Debt section call both fixes "offered as a separate task". Correct them to "committed on `<branch>` at `<sha>`, not merged".
B3 (Minor) — `STATUS.md` ~1463-1464 still says Plan 04's "branch is NOT merged" — correct it (Plan 04 merged at `e4e3f80`), without rewriting other history.
B4 (Minor) — mutation log line 3's tally ("fired 60, killed 60, survived 1") does not add up. Recount with the new mutants: exercised = 62 + M-03bh..bl (5) = 67; killed = 65; survived 1 (M-03e, designed); equivalent 1 (M-03ai ordinal clause). Add a line logging GripDrag `_capture`'s read→peek as a further **equivalent** mutant if you fire it (GeometryStore.replace swaps objects, so a peek view never sees a later edit) — fire it to confirm, then equivalent = 2 and exercised 68. Make the head tally exactly consistent with the entries.
B5 (Minor) — results note: drop the stale debt line "barrel export order not alphabetical" (~line 599; both barrels are alphabetical now — verify); label the differential's residual-magnitude derivations as derived reasoning, not pasted output; add as **named debt** that the move/rotate preview's point crosses allocate four `Offset`s per selected point per frame (02's existing cross pattern; breaches the frame-path rule for point keys; not gated by paint_allocation_test).
B6 — record the new mutants M-03bh…M-03bl (and the read→peek equivalent) in the mutation log (full per-mutant entries), in the spec's "Amended at execution (Plan 03)" Testing paragraph (append — never rewrite), and in the results note's tally and criterion 13 witness. Criterion 13 / the tally must match the log exactly.

## Gates
Run all four gate lines at the end (engine; render layer — only the five standing goldens may fail; harness; app with both release builds) and paste real output into your report. `git status --short` clean at the end.
