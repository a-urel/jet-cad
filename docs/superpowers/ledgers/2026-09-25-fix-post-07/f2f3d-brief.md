# F2F3d brief — the Scale field re-syncs on an in-app tap only

You are the implementer for F2F3d on branch `fix/post-07`, worktree
`/home/user/jet-cad/.claude/worktrees/fix-post-07` (HEAD f5920de). Work only
there. Read `CLAUDE.md`, then `apps/floor_planner/lib/page_panel.dart`,
`lib/panel_focus.dart`, tests A18, A23, A24, A25 (`test/planner_draw_test.dart`)
and SE13, SE15, SE16 (`test/selection_panel_test.dart`).

## Why
Spec 04: the scale is committed on submit only. We want the field never to
show a scale the page doesn't have after the user moves on inside the app —
but never to drop typed text because the WINDOW lost focus. f5920de did it
with a focus-loss listener plus a lifecycle guard. Its review showed that
on web the focused `<input>` blurs first and the engine closes the text
connection (`EditableText.connectionClosed` → `focusNode.unfocus()`) while
`lifecycleState` is still `resumed`, so the typed text is dropped on a plain
alt-tab (the reviewer reproduced it on the release build in Chromium).

## Ruling (binding)
- Remove the Scale focus-loss listener (`_onScaleFocus`, its add/remove) and
  the lifecycle guard.
- The Scale field's `onTapOutside` hands focus back (as now) **and then
  re-syncs** (`_syncScale`, which reads the page from the document). That is
  the "user clicked elsewhere in the app without Enter" case. A window blur
  or a text-connection close never fires `onTapOutside`.
- Enter is unchanged: `onEditingComplete` hands back, `onSubmitted` commits;
  the page listener shows the committed value.
- Accepted and to be stated in the comment: leaving Scale by clicking or
  Tabbing into another text field keeps the unsubmitted text visible (text
  fields share one tap group, so no `onTapOutside`).
- Comments must say exactly what happens, including the web order; no claim
  you have not verified.

## Tests
- A23 (tap on the Page title → field shows the page's scale, model and undo
  depth unchanged) stays and still passes.
- **A25 rewritten to the web order:** type 75 over 1:20, then make the field
  lose focus the way the web engine does on a window blur — WITHOUT a tap
  (e.g. `focusNode.unfocus()` / close the text-input connection, with
  lifecycle still resumed) → the field still shows 75, model 20, undo depth
  unchanged. The mutant "re-sync on any focus loss" (the f5920de listener
  without the guard) must turn it red. If you can drive the real path
  (`TextInputClient.connectionClosed` via the test text-input channel), prefer it.
- **A18:** replace `everyElement('75')` with `isEmpty` (the field's text
  never changes from Enter on).
- A24, SE13, SE15, SE16 unchanged and green.
Mutants to fire: (a) no re-sync in onTapOutside → A23 red; (b) re-sync on any
focus loss → A25 red; (c) re-sync BEFORE handBack in onTapOutside, if it
changes anything observable (say honestly if equivalent); (d) `_syncScale`
reads `widget.page.value` → A18 red? (report). Re-fire R1 (SE16) and M1 (SE15).
Mutant procedure (binding): `cp` the file to a backup in
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/`,
mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --` a .dart
file. `CI=true` on every test command. Flutter at `/root/flutter/bin`.

## Gate
```
cd apps/floor_planner && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build web --release
```

## Commit
One commit, English; its message says it replaces f5920de's focus-loss
re-sync and corrects that commit's web claim. End with exactly:
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```
Stage only your own files. Restore any modified `analysis_options.yaml`
(yaml only); never commit one. Do not push.

## Report
Commit hash; files; gate lines verbatim from real output; each mutant: edit,
command, red test and line (or survived/equivalent, honestly), restore +
diff; deviations and why.
