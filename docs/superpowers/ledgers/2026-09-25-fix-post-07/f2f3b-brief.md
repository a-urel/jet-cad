# F2F3b brief — the review's follow-ups on the panel focus fixes

You are the implementer for F2F3b on branch `fix/post-07`, worktree
`/home/user/jet-cad/.claude/worktrees/fix-post-07`. Work only there. Read
`CLAUDE.md`, then `apps/floor_planner/lib/panel_focus.dart`, `page_panel.dart`,
`selection_panel.dart`, and the tests A18/A19 (`test/planner_draw_test.dart`)
and SE11–SE14 (`test/selection_panel_test.dart`). F2 (`e5c2a89`) and F3
(`e87f66c`) were reviewed Approved; these are the reviewer's minors, with the
controller's rulings. Other commits (F1, F1b) are on the branch; don't touch
their files.

## m1 — the walk must start from the node that has the focus
`EditableText` arms `onTapOutside` from `_hasFocus` at its **last build**, so
within one frame `handBack` can run on a node that is no longer focused: its
own `unfocus` returns early, the walk continues from the node that really has
focus, walks back to the caller, and `seen` stops ON the caller — a panel
field. Reviewer's repro (P10): select a box, tap Width, pump; `tester.tap`
the Scale field with **no pump**; mouse-click the "Page" title; pump →
Width is primary and W does not switch tools. A copy of the reviewer's probe
is at `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/rv2_probe_test.dart.keep`
(read it; don't commit it). Fix: start the walk from the focused node (e.g.
`hasFocus ? this : FocusManager.instance.primaryFocus`) — and if the focused
node is not a panel field, there is nothing to hand back. Correct the
docstring's "armed only while it has the focus" claim. Land P10 as a test
that a named mutant (the old start) turns red.

## m2 — the Scale field never shows a scale the page does not have
Spec 04 (`docs/superpowers/specs/2026-09-22-page-grid-rulers-design.md:530`):
the scale field is "committed on submit". Keep that. But today a tap outside
(or any focus loss without Enter) leaves the typed text: field "75" while
the page is 1:20. Ruling: when the Scale field loses focus, it re-syncs to
the model (`_syncScale` or equivalent). Mind the order on Enter:
`onEditingComplete` (handBack) runs, then `onSubmitted` commits
synchronously, and the focus change lands later — so after Enter the field
must show the committed value, not the old one. Tests: type 75 on 1:20,
mouse-click the Page title → field shows 20, model 20, undo depth unchanged;
Enter path still commits 75 in one step. Mutants: no re-sync on focus loss;
re-sync that runs before the commit on Enter (if you can separate it).

## nit
A18 and SE13 commit scale 50, which is `PageComponent`'s constructor default.
Use 75.

## Mutant procedure (binding)
`cp` the file to a backup in
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/`,
mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --` a .dart
file. Prefix every test command with `CI=true`. Flutter at `/root/flutter/bin`.

## Gate
```
cd apps/floor_planner && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build web --release
```

## Commit
One commit, English, ending with exactly:
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```
Stage only your own files (`git add <paths>`). Restore any modified
`analysis_options.yaml` (yaml only); never commit one. Do not push.

## Report
Commit hash; files; gate lines verbatim from real output; each mutant: edit,
command, red test and line (or survived, honestly), restore + diff;
deviations and why.
