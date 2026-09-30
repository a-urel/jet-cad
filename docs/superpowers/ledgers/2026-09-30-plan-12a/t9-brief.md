# Task 9 brief — the sweep: carried test gaps, small fixes, mutants, greps (plan 12a)

You are the implementer for **Task 9 (code part)** of plan 12a on branch
`plan-12a/document-lifecycle`, worktree
`/home/user/jet-cad/.claude/worktrees/plan-12a`. Work only there. Read
`CLAUDE.md`; the plan (`docs/superpowers/plans/2026-09-30-document-lifecycle.md`:
header, P-1–P-6, Global constraints, Gates, **Task 9**, Mutant assignment);
the spec (`docs/superpowers/specs/2026-09-30-document-lifecycle-design.md`,
its Named mutants); and in `.superpowers/sdd/plan-12a/` **`progress.md`
whole** (every "Task 9" ruling) and each task's report and review.

The controller writes the results note, the spec amendments, the roadmap
and STATUS afterwards: **you do not edit `docs/`, `roadmap/` or
`STATUS.md`.** You write code, tests, comments, and your report — which
must give the controller every fact the results note needs (per task: the
final mutant table with red test and line on the final tree).

## Carried items (each from a review; the ledger has the ruling)

1. `packages/jet_cad_2d/test/document/command_test.dart:365` comment names
   the removed `pushUndoOnly` — reword (Task 1).
2. Render `test/draw/mid_shape_test.dart` MS4: two `expect(...isMidShape,
   isFalse)` after typing, before Enter; the Task 2 review's R3 (`isPending
   && controller.text.isNotEmpty`) red (Task 2 m-1).
3. `apps/floor_planner/pubspec.yaml`: raise `environment` to `sdk: ^3.10.0`,
   `flutter: ">=3.38.0"` (Task 4); pub get; nothing else changes.
4. Fake order test (`failNextWrite` with `holdWrites`: throws, no held
   write; R7 red) and a VM selection test (`createDocumentFiles(...)` is
   not the stub and `writesInPlace` is true; dropping the `dart.library.io`
   export line red) (Task 4 m-1, m-2).
5. Status line takes the free width: `Expanded`, no `Spacer`; DC12
   re-checked at 800 × 600 and at 1440 × 900 (a room notice not cut when
   the bar has room) (Task 6 m1).
6. A listener-count assertion: after a swap, the host's busy notifiers
   have exactly the listeners they had before it (the shell's file-command
   flags disposed); the Task 6 review's R6 red (Task 6 m3).
7. Dartdoc on the host's `fileCommands`: not mid-shape-aware; bind through
   the shell (Task 6 m4).
8. Save As settle case (ST1 with Cmd+Shift+S: the typed value in the bytes,
   clean); Save As without settle red (Task 7 m1).
9. The platform rule's two unpinned cases: a mouse tap on Android ends the
   entry (ST6), a touch tap on macOS ends it (ST5); the Task 7 review's Y1,
   Y2 red (Task 7 m2).
10. Task 7 deviations 2 (unconditional scale re-sync) and 6 (an empty entry
    closed by the settle): pin each with a test, or say in the report why
    it is not observable (Task 7 m3).
11. `startup_plan.dart:28`-style stale comments: grep `lib/` for comments
    that still describe the pre-12a launch ("the fixture a human looks
    at", "no redo", "before sub-project 12") and fix them.

## The sweep

- **Re-fire all 32 named mutants** (M-12a-1 … 31 and 7b) on the final
  tree, plus the render mutant `TextTool.isMidShape => isPending`, M-12a-29
  through the `onBeforeMutate` spy. Record red test and line for each. A
  survivor is a finding: fix the test (never the mutant), re-fire, record.
- **Greps** (report each command and its output): `dart:io` only in
  `document_files_io.dart` in `apps/floor_planner/lib`; `package:web` only
  in `*_web.dart`; no direct `cross_file` dependency or import; the removed
  `UndoStack` primitives (`push(`, `takeUndo`, `pushRedo`, `takeRedo`,
  `pushUndoOnly`) nowhere in `packages/*/lib` or `packages/*/test` or the
  app; `startupPlan(` only in `startup_plan.dart`, the host's Open sample,
  and tests; `parametricCatalog.registerComponents` only inside
  `registerAppComponents` and test decodes; no `Future.delayed(Duration.zero)`
  in `lib/`; `debugOnSettle` nowhere.
- Stale spec citations the reviews found (for the controller's amendment,
  do not edit the spec): list each with its new line.

Procedure (binding): mutants by `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12t9-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0); a script that
restores in a `finally`. NEVER `git checkout --` a .dart file. `CI=true`
on every test command; `export PATH=/root/flutter/bin:$PATH`. Never
synthesize output. Never commit `analysis_options.yaml`. Commit (one or
two commits: `test: plan 12a sweep …`, `fix(app): …` for item 5); do NOT
push.

Gates: all three packages and `flutter build web --release`. Write
`.superpowers/sdd/plan-12a/t9-report.md` and return it.

## Added after the Task 8 review

12. A case where the **D10 replace dialog** is up (dirty, titled): each of
    Cmd and Ctrl with S, O, N and Shift+S is handled, no write, no open
    call, still one dialog; re-fire M-12a-24 against it (Task 8 m-1; the
    reviewer's probe P1 is in the ledger's t8-review.md).
13. DO6's description still ends "a cancel shows nothing" — reword (the
    replace dialog shows first; only the error dialog is absent) (Task 8
    n-4).
