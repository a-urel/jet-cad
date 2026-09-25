# F2F3c brief — the second review's follow-ups on the Scale field

You are the implementer for F2F3c on branch `fix/post-07`, worktree
`/home/user/jet-cad/.claude/worktrees/fix-post-07` (HEAD 159ee7d). Work only
there. Read `CLAUDE.md`, then `apps/floor_planner/lib/page_panel.dart`,
`lib/panel_focus.dart`, tests A18, A23 (`test/planner_draw_test.dart`) and
SE11–SE15 (`test/selection_panel_test.dart`). The reviewer's probe file is
parked at `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/rv4-f2f3b-probe_test.dart.parked`
— read it for PA, PB and PZ; do not commit it.

## I1 (Important) — the re-sync must read the model, and the comments must be true
On Enter: `onEditingComplete` (handBack) queues the focus microtask, then
`onSubmitted` commits. `document.changes` is an async broadcast stream, so
`PageNotifier` updates in a LATER microtask than the focus change. Today
`_onScaleFocus` reads `widget.page.value` (still 20) and writes "20", then
the page listener writes "75" (probe PA: `seq=[20, 75]`). The comment at
`page_panel.dart:58-61`, 159ee7d's commit message and A18's comment (~:488)
claim the opposite. Ruling: `_onScaleFocus` reads the page from the document
(`widget.document.components.get<PageComponent>(widget.document.rootHandle)`
or whatever the panel already has access to — check), which the command has
already updated synchronously; then correct the comments so they say
exactly what happens. Your commit message states that it corrects 159ee7d's
message. Add a test that the scale field follows an **undo** of a scale
commit (field shows the old value), so the page listener stays pinned
(reviewer's R2 — drop `widget.page.addListener(_syncScale)` — must go red
somewhere other than only A18). If PA's `seq` can be pinned cheaply (the
field never shows the old value on Enter), do it.

## m-a — pin "nothing to hand back"
Land the reviewer's PB as a test: select a box, tap Width, pump; mouse-click
empty paper (canvas) with NO pump; mouse-click the Page title; pump → the
canvas keeps the focus (and a letter switches the tool). Mutant R1 (after
the start line in `handBack`: `if (node is! PanelFieldFocusNode) {
node?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild); return; }`)
must go red.

## m-b — a window blur must not drop the typed text
On web/desktop a window blur becomes `AppLifecycleState.inactive` and the
FocusManager moves the primary focus to the root scope; `_onScaleFocus`
then re-syncs and the typed text is lost (probe PZ). Ruling: the re-sync is
for focus moving inside the app, not for the window losing focus. Skip it
when the app is not resumed (e.g. check
`WidgetsBinding.instance.lifecycleState`) — or an equivalent you can justify
from Flutter's source. Verify the ordering (is the lifecycle state already
non-resumed when the focus listener fires?) from source or a probe, not by
assumption. PZ becomes a test; the mutant "no lifecycle guard" must go red.
On resume the field keeps the typed text and focus.

## Mutant procedure (binding)
`cp` the file to a backup in the scratchpad above, mutate, run, `cp` back,
`diff` (exit 0). NEVER `git checkout --` a .dart file. `CI=true` on every
test command. Flutter at `/root/flutter/bin`. Re-fire M1, M2a and M2b
(F2F3b's) after your change too and report them.

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
Stage only your own files. Restore any modified `analysis_options.yaml`
(yaml only); never commit one. Do not push.

## Report
Commit hash; files; what the ordering evidence showed; gate lines verbatim
from real output; each mutant: edit, command, red test and line (or
survived, honestly), restore + diff; deviations and why.
