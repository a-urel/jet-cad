# F2+F3 brief — panel fields hand focus back to the canvas

You are the implementer for fixes F2 and F3 on branch `fix/post-07`,
worktree `/home/user/jet-cad/.claude/worktrees/fix-post-07`. Work only there.
Read `CLAUDE.md` first. App only: `apps/floor_planner`.
F1 (ACI 7 foreground) is already committed on this branch by another
implementer; do not touch its files.

## F2 — the Page panel's Scale field keeps focus after Enter
`apps/floor_planner/lib/page_panel.dart`, the `page-scale` TextField:
commit is `onSubmitted` only; after Enter the field keeps focus, so the
shell's letter shortcuts (L, W, B…) and Escape are dead until the canvas
is clicked. Plan 07 fixed the Selection panel's fields (`dcbc831`) with
`onEditingComplete: () => focus.unfocus(disposition:
UnfocusDisposition.previouslyFocusedChild)` — read that code and its
comments in `selection_panel.dart` (`_field`), and `test/selection_panel_test.dart`
(WS6, WS7, WS9 and the Enter cases) for the test idiom. Enter must commit
the scale AND hand focus back so a following letter switches tools.

## F3 — Box m3: tapping the panel background after both Box fields refocuses Width
Repro (Plan 07 Task 8 reviewer, "B7"): select a box, type in Width, move to
Height, type, tap the "Box" section title. Both values commit correctly,
but Width regains focus and W does not switch tools. Cause:
`previouslyFocusedChild` walks the scope's focus history, and Width is still
in it. The reviewer's tried-and-passing suggestion for `onTapOutside`:
```dart
void _handBack(FocusNode n) {
  n.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
  final next = n.enclosingScope?.focusedChild;
  for (final g in _fields) {
    if (identical(g.focus, next)) return _handBack(g.focus);
  }
}
// onTapOutside: (_) => _handBack(f.focus),
```

## Check these too (the same mechanism) and fix if they reproduce
- **Enter in Height after Width**: `previouslyFocusedChild` may land on
  Width the same way. If it does, Enter uses the same walk.
- **Across panels**: edit a Box/Wall field, then the Page Scale field,
  then Enter — does focus land back on the Selection panel's field? If so,
  the walk must skip every panel text field, not only one panel's own. A
  small shared helper (one file both panels use) is welcome if it keeps the
  rule in one place; do not over-engineer.
- The walk must terminate (focus history is finite; guard it) and must not
  steal a focus a canvas click has just requested (07's reason for
  `previouslyFocusedChild`; WS/B8-style case: tap-outside on the canvas
  leaves the `InteractionLayer` primary).

## Tests (a test lands only if a named mutant turns it red)
Pin the end state by what the user sees: after the action, a letter key
switches the tool (and/or `primaryFocus` is the canvas's node), AND the
value committed (with a non-default value). Suggested mutants — fire each:
- M-F2a: remove the Page field's `onEditingComplete` hand-back.
- M-F2b: hand back with plain `unfocus()` (focus to the scope; letters
  may still fail — check which; if it survives, say so, don't fake it).
- M-F3a: `onTapOutside` back to a single `previouslyFocusedChild`.
- M-F3b: the walk stops after one step / skips only its own field.
- any mutant you need for the Enter/cross-panel findings.
Mutant procedure (binding): `cp` the file to a backup in
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/`,
mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --` a .dart
file. Prefix every test command with `CI=true`. Flutter at `/root/flutter/bin`.

## Gate
```
cd apps/floor_planner && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build web --release
```
(must end `All tests passed!`, `No issues found!`, format exit 0, `✓ Built`).
Also re-run `cd packages/jet_cad_2d_flutter && CI=true flutter test` only if
you touch that package (you should not need to).

## Commits
Two commits (F2, then F3 — or one if a shared helper makes them
inseparable; say so), each ending with exactly:
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```
Restore any modified `analysis_options.yaml` (`git checkout --` on the yaml
only) before committing; never commit one. Do not push.

## Report
Commit hash(es); what reproduced (Enter-in-Height, cross-panel) and what
did not, with evidence; gate lines verbatim from real output; each mutant:
edit, command, red test name and line (or survived, honestly), restore +
diff result; deviations and why.
